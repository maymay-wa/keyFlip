import XCTest

/// Conversion has to hold up across scripts, not just the Hebrew pair it was built
/// against. These run against the layouts macOS ships, so they need no setup.
final class MajorLanguageTests: XCTestCase {
    private let converter = LayoutConverter()

    private struct Language {
        let id: String
        let name: String
        let script: ClosedRange<UInt32>
        /// False for phonetic layouts, which put several Latin letters on one of
        /// their own -- Hebrew – QWERTY types ו for o, u and v alike -- so nothing
        /// can tell afterwards which key was pressed. See the collision test below.
        var reversible = true
    }

    private static let languages = [
        Language(id: "com.apple.keylayout.Hebrew", name: "Hebrew", script: 0x0590...0x05FF),
        Language(id: "com.apple.keylayout.Hebrew-PC", name: "Hebrew PC", script: 0x0590...0x05FF),
        Language(id: "com.apple.keylayout.Hebrew-QWERTY", name: "Hebrew QWERTY", script: 0x0590...0x05FF, reversible: false),
        Language(id: "com.apple.keylayout.Russian", name: "Russian", script: 0x0400...0x04FF),
        Language(id: "com.apple.keylayout.RussianWin", name: "Russian PC", script: 0x0400...0x04FF),
        Language(id: "com.apple.keylayout.Ukrainian-PC", name: "Ukrainian", script: 0x0400...0x04FF),
        Language(id: "com.apple.keylayout.Bulgarian", name: "Bulgarian", script: 0x0400...0x04FF),
        Language(id: "com.apple.keylayout.Serbian", name: "Serbian", script: 0x0400...0x04FF),
        Language(id: "com.apple.keylayout.Byelorussian", name: "Belarusian", script: 0x0400...0x04FF),
        Language(id: "com.apple.keylayout.Greek", name: "Greek", script: 0x0370...0x03FF),
        Language(id: "com.apple.keylayout.Arabic", name: "Arabic", script: 0x0600...0x06FF),
        Language(id: "com.apple.keylayout.ArabicPC", name: "Arabic PC", script: 0x0600...0x06FF),
        Language(id: "com.apple.keylayout.Persian", name: "Persian", script: 0x0600...0x06FF),
        Language(id: "com.apple.keylayout.Thai", name: "Thai", script: 0x0E00...0x0E7F),
        Language(id: "com.apple.keylayout.Armenian-HMQWERTY", name: "Armenian", script: 0x0530...0x058F, reversible: false),
        Language(id: "com.apple.keylayout.Georgian-QWERTY", name: "Georgian", script: 0x10A0...0x10FF),
        Language(id: "com.apple.keylayout.Devanagari", name: "Hindi", script: 0x0900...0x097F),
    ]

    private func layout(_ id: String) throws -> KeyboardLayout {
        try XCTUnwrap(InputSourceManager.installedLayout(withID: id), "\(id) is not installed on this machine")
    }

    private func english() throws -> KeyboardLayout { try layout("com.apple.keylayout.ABC") }

    /// The core use case: you meant to type the other language, but the keyboard was
    /// still in English, so you got Latin gibberish. Converting has to land in that
    /// language's actual script -- not pass the text through untouched.
    func testConvertingLatinGibberishLandsInTheRightScript() throws {
        let english = try english()
        for language in Self.languages {
            let target = try layout(language.id)
            let converted = converter.convert("shalom", from: english, to: target)
            XCTAssertNotEqual(converted, "shalom", "\(language.name): nothing was converted")
            let letters = converted.unicodeScalars.filter { !$0.properties.isWhitespace }
            let inScript = letters.filter { language.script.contains($0.value) }
            XCTAssertEqual(inScript.count, letters.count,
                           "\(language.name): converted to \(converted), which is not all in its script")
        }
    }

    /// Converting there and back has to return the original, or the second press of
    /// the hotkey would not undo the first.
    func testRoundTripThroughEveryLanguage() throws {
        let english = try english()
        for language in Self.languages where language.reversible {
            let target = try layout(language.id)
            let original = "the quick brown fox jumps over the lazy dog"
            let converted = converter.convert(original, from: english, to: target)
            XCTAssertEqual(converter.convert(converted, from: target, to: english), original,
                           "\(language.name): round trip did not return the original")
        }
    }

    /// Detection has to pick the layout the text was really typed in, otherwise the
    /// first press converts from the wrong source and produces nonsense.
    func testCoverageIdentifiesTheScriptItWasTypedIn() throws {
        let english = try english()
        for language in Self.languages {
            let target = try layout(language.id)
            let native = converter.convert("hello there", from: english, to: target)
            XCTAssertGreaterThan(converter.coverage(of: native, by: target),
                                 converter.coverage(of: native, by: english),
                                 "\(language.name): its own text scored higher as English")
            XCTAssertGreaterThan(converter.coverage(of: "hello there", by: english),
                                 converter.coverage(of: "hello there", by: target),
                                 "\(language.name): English text scored higher as \(language.name)")
        }
    }

    /// Mistypings people actually make, checked against what the words really are
    /// rather than against whatever the converter happens to produce.
    func testKnownRealWorldMistypings() throws {
        let english = try english()
        // שלום typed with the keyboard left in English.
        XCTAssertEqual(converter.convert("akuo", from: english, to: try layout("com.apple.keylayout.Hebrew")),
                       "שלום")
        // привет on the standard ЙЦУКЕН layout.
        XCTAssertEqual(converter.convert("ghbdtn", from: english, to: try layout("com.apple.keylayout.Russian")),
                       "привет")
        // καλημερα on the Greek layout.
        XCTAssertEqual(converter.convert("kalhmera", from: english, to: try layout("com.apple.keylayout.Greek")),
                       "καλημερα")
    }

    /// Phonetic layouts put several Latin letters on one of their own, so the round
    /// trip above genuinely cannot hold for them. Pinned here so the loss stays a
    /// known property of the layout rather than something that quietly creeps in.
    func testPhoneticLayoutsCollideByDesign() throws {
        let english = try english()
        let hebrewQWERTY = try layout("com.apple.keylayout.Hebrew-QWERTY")
        let vav = converter.convert("v", from: english, to: hebrewQWERTY)
        XCTAssertEqual(vav, "ו")
        XCTAssertEqual(converter.convert("o", from: english, to: hebrewQWERTY), vav)
        XCTAssertEqual(converter.convert("u", from: english, to: hebrewQWERTY), vav)
        // So coming back can only pick one of the three, and o/u become v.
        XCTAssertEqual(converter.convert(vav, from: hebrewQWERTY, to: english), "v")
        // The direction people actually use is unaffected: gibberish still lands in
        // Hebrew, which is what the hotkey is for.
        XCTAssertEqual(converter.convert("akuo", from: english, to: hebrewQWERTY), "אכוו")
    }

    /// The reason destinations exist: two layouts for one language disagree about
    /// where the letters sit, so "convert to Hebrew" is not a single answer.
    func testHebrewLayoutsDisagreeSoTheDestinationMatters() throws {
        let english = try english()
        let qwerty = try layout("com.apple.keylayout.Hebrew-QWERTY")
        let standard = try layout("com.apple.keylayout.Hebrew")
        XCTAssertNotEqual(converter.convert("shalom", from: english, to: qwerty),
                          converter.convert("shalom", from: english, to: standard),
                          "if these agreed, picking between them would not matter")
    }
}
