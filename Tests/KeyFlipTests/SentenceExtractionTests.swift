import XCTest

final class SentenceExtractionTests: XCTestCase {
    private func sentence(in text: String, cursor: Int? = nil) -> (utf16Range: CFRange, text: String)? {
        SelectionService.sentenceBeforeCursor(in: text, cursorUTF16: cursor ?? text.utf16.count)
    }

    func testTakesEverythingWhenThereIsNoPeriod() throws {
        let result = try XCTUnwrap(sentence(in: "akuo"))
        XCTAssertEqual(result.text, "akuo")
        XCTAssertEqual(result.utf16Range.location, 0)
        XCTAssertEqual(result.utf16Range.length, 4)
    }

    func testStopsAtTheLastPeriod() throws {
        let result = try XCTUnwrap(sentence(in: "Hello there. akuo akuo"))
        XCTAssertEqual(result.text, "akuo akuo")
        XCTAssertEqual(result.utf16Range.location, 13)
        XCTAssertEqual(result.utf16Range.length, 9)
    }

    func testStopsAtLineBreaks() throws {
        let result = try XCTUnwrap(sentence(in: "first line\nakuo"))
        XCTAssertEqual(result.text, "akuo")
    }

    func testUsesTheCursorPositionNotTheEnd() throws {
        // Cursor placed right after "akuo", before " trailing".
        let result = try XCTUnwrap(sentence(in: "Done. akuo trailing", cursor: 10))
        XCTAssertEqual(result.text, "akuo")
        XCTAssertEqual(result.utf16Range.location, 6)
        XCTAssertEqual(result.utf16Range.length, 4)
    }

    func testNothingToConvertAfterAPeriod() {
        XCTAssertNil(sentence(in: "All done. "))
        XCTAssertNil(sentence(in: ""))
    }

    func testHebrewOffsetsAreUTF16Based() throws {
        let result = try XCTUnwrap(sentence(in: "שלום. hello"))
        XCTAssertEqual(result.text, "hello")
        XCTAssertEqual(result.utf16Range.location, 6)
        XCTAssertEqual(result.utf16Range.length, 5)
    }
}
