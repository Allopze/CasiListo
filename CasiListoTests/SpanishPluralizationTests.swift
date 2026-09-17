import XCTest
@testable import CasiListo

final class SpanishPluralizationTests: XCTestCase {
    func testSingularAndPluralForms() {
        XCTAssertEqual(SpanishPluralization.count(0, singular: "lista"), "0 listas")
        XCTAssertEqual(SpanishPluralization.count(1, singular: "lista"), "1 lista")
        XCTAssertEqual(SpanishPluralization.count(2, singular: "lista"), "2 listas")
        XCTAssertEqual(SpanishPluralization.count(1, singular: "producto"), "1 producto")
        XCTAssertEqual(SpanishPluralization.count(0, singular: "producto"), "0 productos")
        XCTAssertEqual(SpanishPluralization.count(2, singular: "producto"), "2 productos")
    }
}
