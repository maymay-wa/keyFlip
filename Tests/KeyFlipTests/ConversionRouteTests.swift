import XCTest

final class ConversionRouteTests: XCTestCase {
    private func layout(_ id: String) throws -> KeyboardLayout {
        try XCTUnwrap(InputSourceManager.installedLayout(withID: id), "\(id) is not installed on this machine")
    }

    /// Hebrew (QWERTY), Hebrew (PC) and English enabled together -- the setup that
    /// makes plain cycling useless, because two of the three are the same language.
    private func threeLayouts() throws -> (qwerty: KeyboardLayout, pc: KeyboardLayout, english: KeyboardLayout) {
        (try layout("com.apple.keylayout.Hebrew-QWERTY"),
         try layout("com.apple.keylayout.Hebrew-PC"),
         try layout("com.apple.keylayout.ABC"))
    }

    func testCyclesToTheNextLayoutWhenNoDestinationIsSet() throws {
        let (qwerty, pc, english) = try threeLayouts()
        let layouts = [qwerty, pc, english]
        XCTAssertEqual(ConversionRoute.target(from: qwerty, among: layouts, destinations: [:]), pc)
        XCTAssertEqual(ConversionRoute.target(from: english, among: layouts, destinations: [:]), qwerty)
    }

    func testExplicitDestinationWinsOverTheCycle() throws {
        let (qwerty, pc, english) = try threeLayouts()
        let layouts = [qwerty, pc, english]
        let destinations = [qwerty.id: english.id, pc.id: english.id, english.id: qwerty.id]
        XCTAssertEqual(ConversionRoute.target(from: qwerty, among: layouts, destinations: destinations), english)
        XCTAssertEqual(ConversionRoute.target(from: pc, among: layouts, destinations: destinations), english)
        XCTAssertEqual(ConversionRoute.target(from: english, among: layouts, destinations: destinations), qwerty)
    }

    func testPairedDestinationsFlipBackAndForthInsteadOfCycling() throws {
        let (qwerty, pc, english) = try threeLayouts()
        let layouts = [qwerty, pc, english]
        let destinations = [english.id: qwerty.id, qwerty.id: english.id]
        let first = try XCTUnwrap(ConversionRoute.target(from: english, among: layouts, destinations: destinations))
        let second = try XCTUnwrap(ConversionRoute.target(from: first, among: layouts, destinations: destinations))
        XCTAssertEqual(first, qwerty)
        XCTAssertEqual(second, english, "a second press should return the text, not walk on to Hebrew (PC)")
    }

    func testDestinationPointingAtADisabledLayoutFallsBackToTheCycle() throws {
        let (qwerty, pc, english) = try threeLayouts()
        let layouts = [qwerty, english]   // Hebrew (PC) turned off in System Settings
        let destinations = [qwerty.id: pc.id]
        XCTAssertEqual(ConversionRoute.target(from: qwerty, among: layouts, destinations: destinations), english)
    }

    func testDestinationPointingAtItselfIsIgnored() throws {
        let (qwerty, _, english) = try threeLayouts()
        let layouts = [qwerty, english]
        XCTAssertEqual(ConversionRoute.target(from: qwerty, among: layouts, destinations: [qwerty.id: qwerty.id]),
                       english)
    }

    func testASingleLayoutHasNowhereToGo() throws {
        let (qwerty, _, _) = try threeLayouts()
        XCTAssertNil(ConversionRoute.target(from: qwerty, among: [qwerty], destinations: [:]))
    }
}
