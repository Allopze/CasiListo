import XCTest

final class CasiListoUITests: XCTestCase {
    /// Arranca con el fixture sembrado y entra a la lista: la raíz de la pestaña
    /// Compra es "Mis Listas", los productos viven un nivel más adentro.
    @MainActor
    private func launchFreshApp() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()

        let card = app.buttons["list-card-Compra actual"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        return app
    }

    @MainActor
    func testCreateMarkArchiveAndOpenHistory() throws {
        let app = launchFreshApp()

        let addProductButton = app.buttons["quick-add-product"]
        XCTAssertTrue(addProductButton.waitForExistence(timeout: 5))
        addProductButton.tap()

        let nameField = app.textFields["item-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Producto UI Test")

        app.buttons["Añadir"].tap()

        let createdItem = app.buttons["Marcar Producto UI Test como comprado"]
        XCTAssertTrue(createdItem.waitForExistence(timeout: 5))
        createdItem.tap()

        app.buttons["toolbar-options-menu"].tap()
        app.buttons["Archivar comprados"].tap()
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Archivar'")).firstMatch.tap()

        app.tabBars.buttons["Historial"].tap()

        XCTAssertTrue(app.navigationBars["Historial"].waitForExistence(timeout: 5))
    }

    /// Posponer y «no encontrado» viven solo en el menú contextual de la fila.
    ///
    /// Opera sobre una fila **ya materializada** de la lista sembrada. Antes
    /// creaba un producto nuevo y confiaba en que el desplazamiento automático
    /// hasta su categoría lo dejara en pantalla: en una lista de 363 productos
    /// eso fallaba de forma intermitente y era la causa real de la
    /// inestabilidad en CI, no el tipo de elemento consultado.
    @MainActor
    func testListSupportsSkippedAndUnavailableActions() throws {
        let app = launchFreshApp()

        let categoryCard = app.buttons["category-section-Aseo personal"]
        XCTAssertTrue(categoryCard.waitForExistence(timeout: 10), "No apareció la categoría sembrada")
        if (categoryCard.value as? String) == "Colapsada" {
            categoryCard.tap()
        }

        let row = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "item-row-"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No se materializó ninguna fila de producto")

        row.press(forDuration: 1)
        XCTAssertTrue(
            app.buttons["Posponer"].waitForExistence(timeout: 5),
            "El menú contextual no se abrió tras la primera pulsación larga"
        )
        app.buttons["Posponer"].tap()

        XCTAssertTrue(row.waitForExistence(timeout: 10), "La fila desapareció tras posponerla")
        row.press(forDuration: 1)
        XCTAssertTrue(
            app.buttons["No encontrado"].waitForExistence(timeout: 5),
            "El menú contextual no se abrió tras la segunda pulsación larga"
        )
        app.buttons["No encontrado"].tap()
    }

    /// "Posponer" y "No encontrado" no deben depender solo de la pulsación
    /// larga: el botón "…" de la fila los expone con un toque simple.
    @MainActor
    func testMoreActionsMenuExposesPosponerWithoutLongPress() throws {
        let app = launchFreshApp()

        let categoryCard = app.buttons["category-section-Aseo personal"]
        XCTAssertTrue(categoryCard.waitForExistence(timeout: 10), "No apareció la categoría sembrada")
        if (categoryCard.value as? String) == "Colapsada" {
            categoryCard.tap()
        }

        let menuButton = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "item-menu-"))
            .firstMatch
        XCTAssertTrue(menuButton.waitForExistence(timeout: 10), "No se materializó el botón de más acciones")
        menuButton.tap()

        XCTAssertTrue(
            app.buttons["Posponer"].waitForExistence(timeout: 5),
            "\"Posponer\" no apareció con un toque simple en el menú de más acciones"
        )
        app.buttons["Posponer"].tap()
    }

    /// Instalación limpia: no hay ninguna lista y el Catálogo ya muestra sus
    /// productos. Tocar «+» creaba un producto huérfano invisible en todas las
    /// pantallas; ahora crea la lista destino y el producto aparece en Compra.
    @MainActor
    func testCatalogAddOnFirstRunCreatesTheDestinationList() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset-empty"]
        app.launch()

        XCTAssertTrue(app.staticTexts["No tienes listas activas"].waitForExistence(timeout: 10))

        app.tabBars.buttons["Catálogo"].tap()
        XCTAssertTrue(app.navigationBars["Catálogo"].waitForExistence(timeout: 10))

        let header = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "catalog-section-"))
            .firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 10))
        header.tap()

        let addButton = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "catalog-add-"))
            .firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 10))
        addButton.tap()

        // El producto pasa a estar «en tu compra»: el «+» desaparece de esa fila.
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Quitar"))
                .firstMatch.waitForExistence(timeout: 10)
        )

        app.tabBars.buttons["Compra"].tap()
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "list-card-"))
                .firstMatch.waitForExistence(timeout: 10),
            "El producto añadido desde el Catálogo no llegó a ninguna lista"
        )
        XCTAssertFalse(app.staticTexts["No tienes listas activas"].exists)
    }

    @MainActor
    func testCategoryCardsCollapseAndExpand() throws {
        let app = launchFreshApp()
        let categoryCard = app.buttons["category-section-Aseo personal"]

        XCTAssertTrue(categoryCard.waitForExistence(timeout: 5))
        XCTAssertEqual(categoryCard.value as? String, "Colapsada")

        categoryCard.tap()
        XCTAssertEqual(categoryCard.value as? String, "Expandida")

        categoryCard.tap()
        XCTAssertEqual(categoryCard.value as? String, "Colapsada")
    }
}
