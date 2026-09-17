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

    /// El botón "+" de "Mis Listas" no tenía ningún test: los existentes
    /// creaban listas por los atajos del estado vacío o por "Duplicar", que no
    /// abren ninguna hoja (CASI-028). No usa `launchFreshApp()`: ese helper ya
    /// entra al detalle de "Compra actual", y "Crear nueva lista" solo vive en
    /// la toolbar de "Mis Listas".
    @MainActor
    func testCreateListFromToolbarButtonOpensSheetAndSaves() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()

        XCTAssertTrue(app.buttons["list-card-Compra actual"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Nueva"].exists, "La tarjeta-resumen no debe duplicar el CTA de la barra")
        app.buttons["Crear nueva lista"].tap()

        XCTAssertTrue(
            app.navigationBars["Nueva lista"].waitForExistence(timeout: 10),
            "La hoja de nueva lista no se presentó"
        )
        let nameField = app.textFields["list-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        nameField.typeText("Asado")

        app.buttons["Guardar"].tap()

        // Guardar entra directo al detalle de la lista recién creada
        // (ListsOverviewView pasa onListCreated → onSelectList).
        XCTAssertTrue(app.buttons["toolbar-options-menu"].waitForExistence(timeout: 10))

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["list-card-Asado"].waitForExistence(timeout: 10))
    }

    /// La guía de primer uso (CASI-011) debe aparecer una sola vez, al ver la
    /// primera lista con productos, y no volver a mostrarse después de
    /// cerrarla. `"-ui-testing-onboarding"` salta la supresión que aplica
    /// `-ui-testing-reset` por defecto (ver `ContentView.resetStorageForUITestsIfNeeded`).
    @MainActor
    func testOnboardingGuideAppearsOnceOnTheFirstPopulatedList() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset", "-ui-testing-onboarding"]
        app.launch()

        let card = app.buttons["list-card-Compra actual"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()

        XCTAssertTrue(
            app.otherElements["onboarding-guide"].waitForExistence(timeout: 10)
                || app.buttons["onboarding-dismiss"].waitForExistence(timeout: 10),
            "La guía de primer uso no apareció al entrar a una lista con productos"
        )
        app.buttons["onboarding-dismiss"].tap()

        // Volver a "Mis Listas" y reabrir la misma lista: la guía no vuelve.
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        XCTAssertFalse(app.buttons["onboarding-dismiss"].waitForExistence(timeout: 3))
    }

    /// Recorrido mínimo en Accessibility XXL: los CTA centrales deben seguir
    /// siendo utilizables y no quedar debajo de la tab bar ni fuera del frame.
    @MainActor
    func testCriticalControlsRemainHittableAtAccessibilityXXL() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset-empty",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXL"
        ]
        app.launch()

        let window = app.windows.firstMatch
        /// En horizontal la exigencia es total: nada puede salirse por los
        /// costados, que es como se ve el truncamiento. En vertical basta con
        /// que el control empiece dentro de la ventana —en XXL un control puede
        /// medir más que la pantalla y se termina de ver con scroll.
        func assertVisibleAndInsideWindow(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
            let frame = element.frame
            let message = "frame=\(frame) ventana=\(window.frame)"
            XCTAssertTrue(window.frame.intersects(frame), message, file: file, line: line)
            XCTAssertGreaterThanOrEqual(frame.minX, window.frame.minX, message, file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxX, window.frame.maxX, message, file: file, line: line)
            XCTAssertGreaterThanOrEqual(frame.minY, window.frame.minY, message, file: file, line: line)
            XCTAssertLessThanOrEqual(frame.minY, window.frame.maxY, message, file: file, line: line)
        }
        /// En XXL el contenido no cabe en una pantalla y todas estas vistas son
        /// scrollables: la garantía que importa es que el control se alcance con
        /// scroll y quede entero dentro de la ventana, no que nazca a la vista.
        /// Sin esto, «Supermercado» del estado vacío da `isHittable == false`
        /// solo por quedar bajo el pliegue.
        func bringIntoView(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
            guard element.waitForExistence(timeout: 10) else {
                XCTFail("No existe \(element)", file: file, line: line)
                return
            }
            // `app.swipeUp()` arranca en el centro de la pantalla, que en el
            // estado vacío cae sobre el carrusel horizontal de básicos y se
            // queda ahí: el arrastre explícito parte bajo él.
            func drag(from startY: CGFloat, to endY: CGFloat) {
                window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                    .press(
                        forDuration: 0.05,
                        thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY))
                    )
            }
            for _ in 0..<6 where !element.isHittable {
                drag(from: 0.85, to: 0.2)
            }
            for _ in 0..<6 where !element.isHittable {
                drag(from: 0.2, to: 0.85)
            }
            XCTAssertTrue(
                element.isHittable,
                "No alcanzable: frame=\(element.frame) ventana=\(window.frame)",
                file: file,
                line: line
            )
            assertVisibleAndInsideWindow(element, file: file, line: line)
        }
        let starter = app.buttons["list-starter-Supermercado"]
        bringIntoView(starter)
        starter.tap()

        let templates = app.buttons["empty-state-templates"]
        bringIntoView(templates)
        templates.tap()
        XCTAssertTrue(app.buttons["Cerrar"].waitForExistence(timeout: 10))
        app.buttons["Cerrar"].tap()

        app.tabBars.buttons["Ajustes"].tap()
        bringIntoView(app.buttons["settings-export-data"])
        bringIntoView(app.buttons["settings-import-data"])

        app.tabBars.buttons["Catálogo"].tap()
        let catalogSection = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "catalog-section-")).firstMatch
        bringIntoView(catalogSection)
    }
}
