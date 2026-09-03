import Carbon
import Testing

/// Test-side enumeration of the keyboard layouts installed on this machine.
/// The app only ever asks for the handful the user enabled; these tests want all
/// of them, so they can prove the converter holds up on layouts nobody thought
/// to try -- Cherokee, Tibetan, Dvorak, the lot.
enum TestLayouts {
    static let allIDs: [String] = {
        let filter = [kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as Any] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() else { return [] }
        return (0..<CFArrayGetCount(list)).compactMap { index -> String? in
            guard let pointer = CFArrayGetValueAtIndex(list, index) else { return nil }
            let source = unsafeBitCast(pointer, to: TISInputSource.self)
            // Skip input methods: no key layout data means nothing to remap.
            guard TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) != nil,
                  let idPointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
            return Unmanaged<CFString>.fromOpaque(idPointer).takeUnretainedValue() as String
        }.sorted()
    }()

    static let englishID = "com.apple.keylayout.ABC"

    static func layout(_ id: String) -> KeyboardLayout? {
        InputSourceManager.installedLayout(withID: id)
    }

    /// Counts `needle` in `haystack` over unicode scalars. Character-based counting
    /// would miss a separator that a following combining mark has been glued onto.
    static func occurrences(of needle: String, in haystack: String) -> Int {
        let needleScalars = Array(needle.unicodeScalars)
        let scalars = Array(haystack.unicodeScalars)
        guard !needleScalars.isEmpty else { return 0 }
        var count = 0
        var index = 0
        while index + needleScalars.count <= scalars.count {
            if Array(scalars[index..<(index + needleScalars.count)]) == needleScalars {
                count += 1
                index += needleScalars.count
            } else {
                index += 1
            }
        }
        return count
    }

    /// Keys whose output another key also produces. A layout that reuses one of its
    /// letters for two keys cannot be converted back unambiguously -- which key was
    /// pressed is simply not recoverable -- so round-trip claims exclude them.
    static func collidingStrokes(in maps: LayoutMaps) -> Set<KeyStroke> {
        var strokesByOutput: [String: [KeyStroke]] = [:]
        for (stroke, output) in maps.forward {
            strokesByOutput[output, default: []].append(stroke)
        }
        return Set(strokesByOutput.values.filter { $0.count > 1 }.flatMap { $0 })
    }
}

/// One test case per installed layout, for each property below.
struct AllInstalledLayoutTests {
    private let converter = LayoutConverter()
    private let alphabet = "abcdefghijklmnopqrstuvwxyz"

    @Test("at least a hundred layouts are installed to test against")
    func thereAreEnoughLayoutsToBeWorthIt() {
        #expect(TestLayouts.allIDs.count > 100,
                "only \(TestLayouts.allIDs.count) layouts installed")
    }

    @Test(arguments: TestLayouts.allIDs)
    func layoutBuildsAUsableCharacterTable(id: String) throws {
        let layout = try #require(TestLayouts.layout(id), "\(id) is not installed")
        let maps = try #require(converter.maps(for: layout), "\(id) produced no character table")
        #expect(!maps.forward.isEmpty, "\(id) types nothing")
        #expect(!maps.reverse.isEmpty, "\(id) cannot be read back")
        #expect(maps.longestOutput >= 1)
    }

    /// The load-bearing guarantee: press the hotkey twice and you get your text
    /// back. Keys the layout reuses for two characters are excluded, because no
    /// converter could tell them apart -- see `collidingStrokes`.
    @Test(arguments: TestLayouts.allIDs)
    func roundTripPreservesEveryUnambiguousKey(id: String) throws {
        let english = try #require(TestLayouts.layout(TestLayouts.englishID))
        let target = try #require(TestLayouts.layout(id))
        let englishMaps = try #require(converter.maps(for: english))
        let targetMaps = try #require(converter.maps(for: target))
        let colliding = TestLayouts.collidingStrokes(in: targetMaps)

        for letter in alphabet {
            let text = String(letter)
            guard let stroke = englishMaps.reverse[text],
                  targetMaps.forward[stroke] != nil,
                  !colliding.contains(stroke) else { continue }
            let converted = converter.convert(text, from: english, to: target)
            let back = converter.convert(converted, from: target, to: english)
            #expect(back == text, "\(id): \(text) → \(converted) → \(back)")
        }
    }

    /// Conversion rewrites letters, never the shape of what you wrote -- the word
    /// breaks stay put. Counted in scalars, because scripts like Devanagari put a
    /// combining mark on its own key, and Swift glues one that follows a space onto
    /// that space as a single Character even though the space is still there.
    @Test(arguments: TestLayouts.allIDs)
    func wordBreaksSurviveConversion(id: String) throws {
        let english = try #require(TestLayouts.layout(TestLayouts.englishID))
        let target = try #require(TestLayouts.layout(id))
        let englishMaps = try #require(converter.maps(for: english))
        let targetMaps = try #require(converter.maps(for: target))
        let original = "the quick brown fox jumps over the lazy dog"
        let converted = converter.convert(original, from: english, to: target)

        // Not every layout types a space on the space bar: Tibetan and Dzongkha put
        // the tsheg ་ there, and turning the spaces into tshegs is precisely what
        // typing that text with Tibetan active would have done.
        let spaceStroke = try #require(englishMaps.reverse[" "])
        let separator = targetMaps.forward[spaceStroke] ?? " "
        let breaks = TestLayouts.occurrences(of: separator, in: converted)
        #expect(breaks == 8, "\(id): expected 8 word breaks of \(separator), got \(breaks) -- \(converted)")
    }

    /// What the first press depends on: text typed in a non-Latin layout has to look
    /// more like that layout than like English, or detection picks the wrong source
    /// and converts from it into nonsense. Latin-script layouts (Dvorak, French)
    /// are skipped -- English covers their output just as well, by definition.
    @Test(arguments: TestLayouts.allIDs)
    func detectionPrefersTheLayoutTextWasTypedIn(id: String) throws {
        let english = try #require(TestLayouts.layout(TestLayouts.englishID))
        let target = try #require(TestLayouts.layout(id))
        let typed = converter.convert(alphabet, from: english, to: target)

        let byTarget = converter.coverage(of: typed, by: target)
        let byEnglish = converter.coverage(of: typed, by: english)
        #expect(byTarget >= 0 && byTarget <= 1, "\(id): coverage out of bounds at \(byTarget)")
        #expect(byEnglish >= 0 && byEnglish <= 1, "\(id): coverage out of bounds at \(byEnglish)")

        let nonLatin = typed.unicodeScalars.filter { $0.value > 0x7F }.count
        guard nonLatin > typed.unicodeScalars.count / 2 else { return }
        #expect(byTarget > byEnglish,
                "\(id): its own text scored \(byTarget) against English's \(byEnglish) -- \(typed)")
    }

    /// Routing has to behave the same whatever the second layout is.
    @Test(arguments: TestLayouts.allIDs)
    func routingHonoursDestinationsAndIgnoresNonsense(id: String) throws {
        let english = try #require(TestLayouts.layout(TestLayouts.englishID))
        let other = try #require(TestLayouts.layout(id))
        guard other.id != english.id else { return }
        let pair = [english, other]

        #expect(ConversionRoute.target(from: english, among: pair, destinations: [english.id: other.id]) == other)
        #expect(ConversionRoute.target(from: english, among: pair, destinations: [:]) == other,
                "with no destination it should cycle to the only other layout")
        #expect(ConversionRoute.target(from: english, among: pair, destinations: [english.id: english.id]) == other,
                "a layout pointed at itself should be ignored")
        #expect(ConversionRoute.target(from: english, among: pair,
                                       destinations: [english.id: "com.apple.keylayout.NotInstalled"]) == other,
                "a destination that is gone should fall back to cycling")
        #expect(ConversionRoute.target(from: english, among: [english], destinations: [:]) == nil,
                "one layout has nowhere to convert to")
    }
}
