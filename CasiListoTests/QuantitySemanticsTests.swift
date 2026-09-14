import XCTest
@testable import CasiListo

final class QuantitySemanticsTests: XCTestCase {

    func testQuantityMeaning() {
        let cases: [(String, QuantitySemantics.Meaning)] = [
            ("", .magnitude),
            ("   ", .magnitude),
            ("2", .count(2)),
            ("3", .count(3)),
            ("1", .count(1)),
            ("0", .count(1)),
            ("3 unidades", .count(3)),
            ("2 u", .count(2)),
            ("2 unidad", .count(2)),
            ("3 Unidades", .count(3)),
            ("2u", .count(2)),
            ("4 uds", .count(4)),
            ("500 g", .magnitude),
            ("500g", .magnitude),
            ("1 kg", .magnitude),
            ("1,5 kg", .magnitude),
            ("2.5 kg", .magnitude),
            ("250 ml", .magnitude),
            ("docena", .magnitude),
            ("un poco", .magnitude),
            ("6 pack", .magnitude),
            ("120", .count(99)) // tope de 99, igual que ReceiptPurchaseEntry.quantity
        ]
        for (input, expected) in cases {
            XCTAssertEqual(QuantitySemantics.meaning(of: input), expected, "cantidad «\(input)»")
        }
    }

    func testUnitCountIsNeverZero() {
        XCTAssertEqual(QuantitySemantics.unitCount(of: "0"), 1)
        XCTAssertEqual(QuantitySemantics.unitCount(of: ""), 1)
        XCTAssertEqual(QuantitySemantics.unitCount(of: "500 g"), 1)
        XCTAssertEqual(QuantitySemantics.unitCount(of: "3 unidades"), 3)
    }

    func testTextForCountOmitsTheOne() {
        XCTAssertEqual(QuantitySemantics.text(forCount: 1), "")
        XCTAssertEqual(QuantitySemantics.text(forCount: 0), "")
        XCTAssertEqual(QuantitySemantics.text(forCount: 3), "3")
        XCTAssertEqual(QuantitySemantics.text(forCount: 500), "99")
    }

    func testIsUnitWordRecognizesBothCountAndMagnitudeWords() {
        XCTAssertTrue(QuantitySemantics.isUnitWord("unidades"))
        XCTAssertTrue(QuantitySemantics.isUnitWord("kg"))
        XCTAssertFalse(QuantitySemantics.isUnitWord("docena"))
    }

    func testIsNumberWithUnitRecognizesGluedTokens() {
        XCTAssertTrue(QuantitySemantics.isNumberWithUnit("500g"))
        XCTAssertTrue(QuantitySemantics.isNumberWithUnit("2u"))
        XCTAssertFalse(QuantitySemantics.isNumberWithUnit("arroz"))
    }

    // MARK: - breakdown (CASI-007)

    func testBreakdownReportsExactMultipleWhenUnitPriceDividesEvenly() {
        XCTAssertEqual(
            QuantitySemantics.breakdown(unitPrice: 917, lineTotal: 2_751, count: 3),
            .exactMultiple(count: 3, unitPrice: 917)
        )
    }

    func testBreakdownFallsBackToCountWhenRoundingDoesNotDivideEvenly() {
        // $2.750 / 3 = $916,67: redondeado a $917, 3 × 917 = 2.751 ≠ 2.750.
        XCTAssertEqual(
            QuantitySemantics.breakdown(unitPrice: 916.666_7, lineTotal: 2_750, count: 3),
            .inexactMultiple(count: 3)
        )
    }

    func testBreakdownIsSingleForOneUnitOrAMagnitude() {
        XCTAssertEqual(QuantitySemantics.breakdown(unitPrice: 1_500, lineTotal: 1_500, count: 1), .single)
        // Una magnitud ("500 g") siempre llega con count 1 desde unitCount(of:).
        XCTAssertEqual(QuantitySemantics.breakdown(unitPrice: 990, lineTotal: 990, count: QuantitySemantics.unitCount(of: "500 g")), .single)
    }
}
