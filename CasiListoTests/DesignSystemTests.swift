import XCTest
import UIKit
import SwiftUI
@testable import CasiListo

/// Guardianes del sistema visual de DESIGN.md: la escala de frases del panel
/// y los contrastes que los tokens nuevos prometen en sus comentarios.
final class DesignSystemTests: XCTestCase {

    private let light = UITraitCollection(userInterfaceStyle: .light)
    private let dark = UITraitCollection(userInterfaceStyle: .dark)

    // MARK: - Escala de ListProgress

    func testProgressStagesFollowTheDesignScale() {
        XCTAssertEqual(ListProgress(pending: 0, purchased: 0).stage, .empty)
        XCTAssertEqual(ListProgress(pending: 355, purchased: 0).stage, .notStarted)
        XCTAssertEqual(ListProgress(pending: 26, purchased: 9).stage, .underway)
        XCTAssertEqual(ListProgress(pending: 3, purchased: 9).stage, .almostDone)
        XCTAssertEqual(ListProgress(pending: 0, purchased: 12).stage, .done)
    }

    /// «Casi listo» aparece justo en tres cuartos, no antes.
    func testAlmostDoneStartsExactlyAtThreeQuarters() {
        XCTAssertEqual(ListProgress(pending: 1, purchased: 3).stage, .almostDone)
        XCTAssertEqual(ListProgress(pending: 26, purchased: 74).stage, .underway)
        XCTAssertEqual(ListProgress(pending: 25, purchased: 75).stage, .almostDone)
    }

    func testPhrasesCarryTheVoiceAndCountLabelCarriesTheData() {
        XCTAssertEqual(ListProgress(pending: 355, purchased: 0).phrase, "Todo por comprar")
        XCTAssertEqual(ListProgress(pending: 26, purchased: 9).phrase, "Vas avanzando")
        XCTAssertEqual(ListProgress(pending: 2, purchased: 10).phrase, "Casi listo")
        XCTAssertEqual(ListProgress(pending: 0, purchased: 10).phrase, "Todo en el carro")

        for progress in [ListProgress(pending: 355, purchased: 0), ListProgress(pending: 26, purchased: 9)] {
            XCTAssertNil(progress.phrase.rangeOfCharacter(from: .decimalDigits), "La frase no lleva números")
        }
        XCTAssertEqual(ListProgress(pending: 362, purchased: 1).countLabel, "1 de 363")
    }

    func testFractionIsZeroForAnEmptyList() {
        XCTAssertEqual(ListProgress(pending: 0, purchased: 0).fraction, 0)
        XCTAssertEqual(ListProgress(pending: 1, purchased: 3).fraction, 0.75, accuracy: 0.0001)
    }

    // MARK: - Panel

    @MainActor
    func testPanelInkMeetsContrastInBothAppearances() {
        for (name, trait) in [("claro", light), ("oscuro", dark)] {
            let panel = UIColor(Theme.panel).resolvedColor(with: trait)
            let pairs: [(String, Color, Double)] = [
                ("onPanel", Theme.onPanel, 4.5),
                ("onPanelSecondary", Theme.onPanelSecondary, 4.5),
                ("accentYellow (numeral)", Theme.accentYellow, 4.5)
            ]
            for (token, color, minimum) in pairs {
                let ratio = Theme.contrastRatio(UIColor(color).resolvedColor(with: trait), panel)
                XCTAssertGreaterThanOrEqual(
                    ratio, minimum,
                    "\(token) sobre el panel en modo \(name): \(String(format: "%.2f", ratio)):1"
                )
            }
        }
    }

    /// El swipe «Editar» lleva etiqueta blanca del sistema.
    @MainActor
    func testSwipeEditFillCarriesAWhiteLabel() {
        let ratio = Theme.contrastRatio(.white, UIColor(Theme.swipeEditFill).resolvedColor(with: light))
        XCTAssertGreaterThanOrEqual(ratio, 4.5, "Blanco sobre swipeEditFill: \(String(format: "%.2f", ratio)):1")
    }

    // MARK: - Insignias de lista

    /// Toda la paleta de listas, en los dos modos: el ícono debe medir 3:1
    /// contra su propio tinte compuesto sobre la tarjeta.
    @MainActor
    func testListBadgeIconsMeetContrastForTheWholePalette() {
        let surfaces: [(String, UIColor)] = [("claro", UIColor(hex: "FFFFFF")), ("oscuro", UIColor(hex: "2A2928"))]

        for option in ListAppearanceCatalog.colors {
            let base = UIColor(hex: option.hex)
            let icons = ListBadgeView.iconColors(for: base)

            for (name, surface) in surfaces {
                let badge = base.blended(alpha: ListBadgeView.tintOpacity, over: surface)
                let icon = name == "claro" ? icons.light : icons.dark
                let ratio = Theme.contrastRatio(icon, badge)
                XCTAssertGreaterThanOrEqual(
                    ratio, 3.0,
                    "\(option.name) en modo \(name): \(String(format: "%.2f", ratio)):1"
                )
            }
        }
    }
}
