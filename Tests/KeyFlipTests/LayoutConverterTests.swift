import XCTest

final class LayoutConverterTests: XCTestCase {
    private let converter = LayoutConverter()

    private func layout(_ id: String) throws -> KeyboardLayout {
        try XCTUnwrap(InputSourceManager.installedLayout(withID: id), "\(id) is not installed on this machine")
    }

    func testEnglishGibberishBecomesHebrew() throws {
        let english = try layout("com.apple.keylayout.ABC")
        let hebrew = try layout("com.apple.keylayout.Hebrew")
        // "akuo" is what typing שלום looks like when the keyboard was left in English.
        XCTAssertEqual(converter.convert("akuo", from: english, to: hebrew), "שלום")
    }

    func testRoundTripBetweenEnglishAndHebrew() throws {
        let english = try layout("com.apple.keylayout.ABC")
        let hebrew = try layout("com.apple.keylayout.Hebrew")
        let original = "hello world"
        let converted = converter.convert(original, from: english, to: hebrew)
        XCTAssertNotEqual(converted, original)
        XCTAssertEqual(converter.convert(converted, from: hebrew, to: english), original)
    }

    func testDigitsAndWhitespacePassThrough() throws {
        let english = try layout("com.apple.keylayout.ABC")
        let hebrew = try layout("com.apple.keylayout.Hebrew")
        XCTAssertEqual(converter.convert("123 456", from: english, to: hebrew), "123 456")
    }

    func testCoverageDetectsTheTypedLayout() throws {
        let english = try layout("com.apple.keylayout.ABC")
        let hebrew = try layout("com.apple.keylayout.Hebrew")
        XCTAssertGreaterThan(converter.coverage(of: "hello", by: english),
                             converter.coverage(of: "hello", by: hebrew))
        XCTAssertGreaterThan(converter.coverage(of: "שלום", by: hebrew),
                             converter.coverage(of: "שלום", by: english))
    }
}
