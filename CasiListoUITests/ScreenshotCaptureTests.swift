import XCTest

/// Arnés de captura del estado visual real de la app. No valida nada: recorre
/// las pantallas y escribe PNGs para revisarlas a ojo.
///
/// La apariencia y el tamaño de texto no se fijan aquí sino que llegan por
/// entorno, para que `ci/capture-screenshots.sh` pueda recorrer la matriz de
/// variantes sin duplicar tests. Por eso los nombres de archivo no dicen
/// "dark": la variante la codifica el directorio de salida.
///
/// Ojo con el entorno: `xcodebuild` NO propaga variables sueltas al proceso del
/// runner. Hay que prefijarlas con `TEST_RUNNER_` y él quita el prefijo, así que
/// se exporta `TEST_RUNNER_SCREENSHOT_DIR` y aquí se lee `SCREENSHOT_DIR`.
final class ScreenshotCaptureTests: XCTestCase {

    // MARK: - Configuración por entorno

    private var outputDirectory: String {
        ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? "/tmp"
    }

    /// Argumentos de arranque comunes a todas las capturas.
    /// - Parameter reset: `-ui-testing-reset` siembra el fixture de 363 productos;
    ///   `-ui-testing-reset-empty` reproduce el primer arranque sin ninguna lista.
    private func launchArguments(reset: String) -> [String] {
        var arguments = [reset]
        let environment = ProcessInfo.processInfo.environment

        switch environment["SCREENSHOT_APPEARANCE"] {
        case "dark": arguments.append("-ui-testing-dark")
        case "light": arguments.append("-ui-testing-light")
        default: break
        }

        if environment["SCREENSHOT_TEXT_SIZE"] == "xxl" {
            arguments += [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXXL"
            ]
        }

        return arguments
    }

    @MainActor
    private func launchApp(reset: String = "-ui-testing-reset") -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = launchArguments(reset: reset)
        app.launch()
        return app
    }

    // MARK: - Menú general de listas

    /// "Mis Listas" es la raíz de la app y hasta ahora no tenía ninguna captura.
    @MainActor
    func testCaptureListsOverview() throws {
        let app = launchApp()
        let dir = outputDirectory

        let card = app.buttons["list-card-Compra actual"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        capture(app, to: "\(dir)/listas-una.png")

        // Duplicar deja dos tarjetas: así se ve el menú general con varias listas.
        let menu = app.buttons["list-card-menu-Compra actual"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        sleep(1)
        capture(app, to: "\(dir)/listas-menu-tarjeta.png")

        let duplicate = app.buttons["Duplicar lista"]
        XCTAssertTrue(duplicate.waitForExistence(timeout: 5))
        duplicate.tap()
        sleep(2)
        capture(app, to: "\(dir)/listas-varias.png")
    }

    /// Creación y personalización de una lista: vista previa, paleta y iconos.
    @MainActor
    func testCaptureListCustomizationSheet() throws {
        let app = launchApp()
        let dir = outputDirectory

        XCTAssertTrue(app.buttons["list-card-Compra actual"].waitForExistence(timeout: 10))
        app.buttons["Crear nueva lista"].tap()

        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        // "Asado" dispara la apariencia sugerida: llama y coral.
        nameField.typeText("Asado")
        sleep(1)
        capture(app, to: "\(dir)/lista-nueva-sugerida.png")

        // El selector de iconos vive al final del formulario.
        app.swipeUp()
        sleep(1)
        capture(app, to: "\(dir)/lista-nueva-iconos.png")

        // Nombre repetido: el aviso explica por qué "Guardar" queda apagado.
        app.swipeDown()
        sleep(1)
        nameField.tap()
        nameField.typeText(XCUIKeyboardKey.delete.rawValue.repeated(10))
        nameField.typeText("Compra actual")
        sleep(1)
        capture(app, to: "\(dir)/lista-nueva-nombre-repetido.png")
    }

    // MARK: - Detalle de la lista

    @MainActor
    func testCaptureMainListExpanded() throws {
        let app = launchApp()
        let dir = outputDirectory

        openSeededList(in: app)

        let categoryCard = app.buttons["category-section-Aseo personal"]
        XCTAssertTrue(categoryCard.waitForExistence(timeout: 10))
        capture(app, to: "\(dir)/detalle-colapsado.png")

        categoryCard.tap()
        sleep(1)
        capture(app, to: "\(dir)/detalle-expandido.png")

        // Marca un producto como comprado para capturar ese estado también.
        let firstToggle = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'item-toggle-'")
        ).firstMatch
        if firstToggle.waitForExistence(timeout: 5) {
            firstToggle.tap()
            sleep(1)
            capture(app, to: "\(dir)/detalle-comprado.png")
        }
    }

    @MainActor
    func testCaptureReceiptClosingFlow() throws {
        let app = launchApp()
        let dir = outputDirectory

        openSeededList(in: app)
        expandFirstCategory(in: app)

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
        capture(app, to: "\(dir)/boleta-dialogo-archivar.png")

        let receiptOption = app.buttons["Añadir boleta y archivar"]
        XCTAssertTrue(receiptOption.waitForExistence(timeout: 5))
        receiptOption.tap()
        sleep(1)
        capture(app, to: "\(dir)/boleta-captura.png")
    }

    // MARK: - Primer arranque

    @MainActor
    func testFirstRunStartsEmptyAndTemplatePopulatesList() throws {
        let app = launchApp(reset: "-ui-testing-reset-empty")
        let dir = outputDirectory

        // Primer arranque real: "Mis Listas" sin ninguna lista todavía.
        let starter = app.buttons["list-starter-Supermercado"]
        XCTAssertTrue(starter.waitForExistence(timeout: 10))
        capture(app, to: "\(dir)/listas-vacio.png")

        // El atajo crea la lista y entra directo a su detalle, todavía vacío.
        starter.tap()

        let templatesButton = app.buttons["empty-state-templates"]
        XCTAssertTrue(templatesButton.waitForExistence(timeout: 10))
        capture(app, to: "\(dir)/detalle-vacio.png")
        templatesButton.tap()

        // La primera tarjeta es "Catálogo completo"; aplicarla puebla la lista.
        let applyButton = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Añadir estos'")
        ).firstMatch
        XCTAssertTrue(applyButton.waitForExistence(timeout: 5))
        capture(app, to: "\(dir)/plantillas.png")
        applyButton.tap()

        XCTAssertTrue(app.staticTexts["355 pendientes"].waitForExistence(timeout: 10))
        capture(app, to: "\(dir)/detalle-plantilla-aplicada.png")

        // El catálogo también quedó poblado.
        app.tabBars.buttons["Catálogo"].tap()
        let catalogSection = app.buttons["catalog-section-Aseo personal"]
        XCTAssertTrue(catalogSection.waitForExistence(timeout: 5))
        catalogSection.tap()
        sleep(1)
        capture(app, to: "\(dir)/catalogo.png")

        // Final del scroll: la última fila debe quedar por encima de la tab bar.
        for _ in 0..<8 { app.swipeUp() }
        sleep(1)
        capture(app, to: "\(dir)/catalogo-final.png")
    }

    // MARK: - Pestañas secundarias

    @MainActor
    func testCaptureSecondaryScreens() throws {
        let app = launchApp()
        let dir = outputDirectory

        // Genera una compra en el historial: marca un producto y archívalo.
        openSeededList(in: app)
        expandFirstCategory(in: app)

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
        capture(app, to: "\(dir)/historial.png")

        let historyRow = app.cells.firstMatch
        if historyRow.waitForExistence(timeout: 3) {
            historyRow.tap()
            sleep(1)
            capture(app, to: "\(dir)/historial-detalle.png")
        }

        // Ajustes.
        app.tabBars.buttons["Ajustes"].tap()
        XCTAssertTrue(app.navigationBars["Ajustes"].waitForExistence(timeout: 5))
        sleep(1)
        capture(app, to: "\(dir)/ajustes.png")

        // Final del scroll: comprueba que la tab bar flotante no deje contenido
        // inalcanzable debajo.
        for _ in 0..<4 { app.swipeUp() }
        sleep(1)
        capture(app, to: "\(dir)/ajustes-final.png")

        // Plantillas e importador, desde el menú de la lista. Volver a la pestaña
        // Compra aterriza en "Mis Listas", así que hay que entrar de nuevo.
        app.tabBars.buttons["Compra"].tap()
        openSeededList(in: app)
        app.buttons["toolbar-options-menu"].tap()
        let templatesOption = app.buttons["Usar plantilla"]
        XCTAssertTrue(templatesOption.waitForExistence(timeout: 5))
        templatesOption.tap()
        sleep(1)
        capture(app, to: "\(dir)/plantillas-desde-menu.png")
        app.buttons["Cerrar"].tap()

        app.buttons["toolbar-options-menu"].tap()
        let importerOption = app.buttons["Importar desde texto"]
        XCTAssertTrue(importerOption.waitForExistence(timeout: 5))
        importerOption.tap()
        sleep(1)
        capture(app, to: "\(dir)/importador.png")
    }

    // MARK: - Utilidades

    /// La raíz de la pestaña Compra es "Mis Listas": hay que entrar a la lista
    /// sembrada antes de poder tocar sus productos.
    @MainActor
    private func openSeededList(in app: XCUIApplication) {
        let card = app.buttons["list-card-Compra actual"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
    }

    @MainActor
    private func expandFirstCategory(in app: XCUIApplication) {
        let categoryCard = app.buttons["category-section-Aseo personal"]
        XCTAssertTrue(categoryCard.waitForExistence(timeout: 10))
        if (categoryCard.value as? String) == "Colapsada" {
            categoryCard.tap()
        }
    }

    /// Captura la ventana de la app, no la pantalla completa: así el PNG no
    /// arrastra el marco del simulador cuando la ventana no está a pantalla completa.
    @MainActor
    private func capture(_ app: XCUIApplication, to path: String) {
        let screenshot = app.windows.firstMatch.exists
            ? app.windows.firstMatch.screenshot()
            : XCUIScreen.main.screenshot()
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
    }
}

private extension String {
    func repeated(_ count: Int) -> String {
        String(repeating: self, count: count)
    }
}
