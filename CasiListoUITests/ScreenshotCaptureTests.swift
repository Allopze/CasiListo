import XCTest

/// Test temporal de soporte para capturar el estado visual real de la app.
/// Escribe PNGs a la ruta indicada por la variable de entorno SCREENSHOT_DIR.
final class ScreenshotCaptureTests: XCTestCase {
    @MainActor
    func testCaptureMainListExpanded() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()

        let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? "/tmp"

        openSeededList(in: app)

        let categoryCard = app.buttons["category-section-Aseo personal"]
        XCTAssertTrue(categoryCard.waitForExistence(timeout: 10))

        save(screenshot: XCUIScreen.main.screenshot(), to: "\(dir)/capture-collapsed.png")

        categoryCard.tap()
        sleep(1)
        save(screenshot: XCUIScreen.main.screenshot(), to: "\(dir)/capture-expanded.png")

        // Marca un producto como comprado para capturar ese estado también.
        let firstToggle = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'item-toggle-'")
        ).firstMatch
        if firstToggle.waitForExistence(timeout: 5) {
            firstToggle.tap()
            sleep(1)
            save(screenshot: XCUIScreen.main.screenshot(), to: "\(dir)/capture-purchased.png")
        }
    }

    @MainActor
    func testCaptureReceiptClosingFlow() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()

        let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? "/tmp"

        openSeededList(in: app)

        let categoryCard = app.buttons["category-section-Aseo personal"]
        XCTAssertTrue(categoryCard.waitForExistence(timeout: 10))
        if (categoryCard.value as? String) == "Colapsada" {
            categoryCard.tap()
        }

        let firstToggle = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'item-toggle-'")
        ).firstMatch
        XCTAssertTrue(firstToggle.waitForExistence(timeout: 5))
        firstToggle.tap()
        sleep(1)

        let archiveButton = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Archivar'")
        ).firstMatch
        XCTAssertTrue(archiveButton.waitForExistence(timeout: 5))
        archiveButton.tap()
        sleep(1)
        save(screenshot: XCUIScreen.main.screenshot(), to: "\(dir)/capture-archive-dialog.png")

        let receiptOption = app.buttons["Añadir boleta y archivar"]
        XCTAssertTrue(receiptOption.waitForExistence(timeout: 5))
        receiptOption.tap()
        sleep(1)
        save(screenshot: XCUIScreen.main.screenshot(), to: "\(dir)/capture-receipt-closing.png")
    }

    @MainActor
    func testFirstRunStartsEmptyAndTemplatePopulatesList() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset-empty"]
        app.launch()

        let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? "/tmp"

        // Primer arranque real: "Mis Listas" sin ninguna lista todavía.
        let starter = app.buttons["list-starter-Supermercado"]
        XCTAssertTrue(starter.waitForExistence(timeout: 10))
        save(screenshot: XCUIScreen.main.screenshot(), to: "\(dir)/capture-empty-start.png")

        // El atajo crea la lista y entra directo a su detalle, todavía vacío.
        starter.tap()

        let templatesButton = app.buttons["empty-state-templates"]
        XCTAssertTrue(templatesButton.waitForExistence(timeout: 10))
        templatesButton.tap()

        // La primera tarjeta es "Catálogo completo"; aplicarla puebla la lista.
        let applyButton = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Añadir estos'")
        ).firstMatch
        XCTAssertTrue(applyButton.waitForExistence(timeout: 5))
        save(screenshot: XCUIScreen.main.screenshot(), to: "\(dir)/capture-templates.png")
        applyButton.tap()

        XCTAssertTrue(app.staticTexts["355 pendientes"].waitForExistence(timeout: 10))
        save(screenshot: XCUIScreen.main.screenshot(), to: "\(dir)/capture-template-applied.png")

        // El catálogo también quedó poblado.
        app.tabBars.buttons["Catálogo"].tap()
        let catalogSection = app.buttons["catalog-section-Aseo personal"]
        XCTAssertTrue(catalogSection.waitForExistence(timeout: 5))
        catalogSection.tap()
        sleep(1)
        save(screenshot: XCUIScreen.main.screenshot(), to: "\(dir)/capture-catalog.png")
    }

    @MainActor
    func testCaptureDarkModeSecondaryScreens() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-ui-testing-dark"]
        app.launch()

        let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? "/tmp"

        // Genera una compra en el historial: marca un producto y archívalo.
        openSeededList(in: app)

        let categoryCard = app.buttons["category-section-Aseo personal"]
        XCTAssertTrue(categoryCard.waitForExistence(timeout: 10))
        if (categoryCard.value as? String) == "Colapsada" {
            categoryCard.tap()
        }
        let firstToggle = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'item-toggle-'")
        ).firstMatch
        XCTAssertTrue(firstToggle.waitForExistence(timeout: 5))
        firstToggle.tap()
        sleep(1)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Archivar'")).firstMatch.tap()
        let archiveConfirm = app.buttons["Archivar 1 comprado"]
        XCTAssertTrue(archiveConfirm.waitForExistence(timeout: 5))
        archiveConfirm.tap()
        sleep(1)

        // Historial y su detalle.
        app.tabBars.buttons["Historial"].tap()
        XCTAssertTrue(app.navigationBars["Historial"].waitForExistence(timeout: 5))
        sleep(1)
        save(screenshot: XCUIScreen.main.screenshot(), to: "\(dir)/dark-historial.png")

        let historyRow = app.cells.firstMatch
        if historyRow.waitForExistence(timeout: 3) {
            historyRow.tap()
            sleep(1)
            save(screenshot: XCUIScreen.main.screenshot(), to: "\(dir)/dark-historial-detalle.png")
        }

        // Ajustes.
        app.tabBars.buttons["Ajustes"].tap()
        XCTAssertTrue(app.navigationBars["Ajustes"].waitForExistence(timeout: 5))
        sleep(1)
        save(screenshot: XCUIScreen.main.screenshot(), to: "\(dir)/dark-ajustes.png")

        // Plantillas e importador, desde el menú de la lista. Volver a la pestaña
        // Compra aterriza en "Mis Listas", así que hay que entrar de nuevo.
        app.tabBars.buttons["Compra"].tap()
        openSeededList(in: app)
        app.buttons["toolbar-options-menu"].tap()
        let templatesOption = app.buttons["Usar plantilla"]
        XCTAssertTrue(templatesOption.waitForExistence(timeout: 5))
        templatesOption.tap()
        sleep(1)
        save(screenshot: XCUIScreen.main.screenshot(), to: "\(dir)/dark-plantillas.png")
        app.buttons["Cerrar"].tap()

        app.buttons["toolbar-options-menu"].tap()
        let importerOption = app.buttons["Importar desde texto"]
        XCTAssertTrue(importerOption.waitForExistence(timeout: 5))
        importerOption.tap()
        sleep(1)
        save(screenshot: XCUIScreen.main.screenshot(), to: "\(dir)/dark-importador.png")
    }

    /// La raíz de la pestaña Compra es "Mis Listas": hay que entrar a la lista
    /// sembrada antes de poder tocar sus productos.
    @MainActor
    private func openSeededList(in app: XCUIApplication) {
        let card = app.buttons["list-card-Compra actual"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
    }

    @MainActor private func save(screenshot: XCUIScreenshot, to path: String) {
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
    }
}
