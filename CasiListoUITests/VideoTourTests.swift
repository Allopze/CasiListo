import XCTest

/// Suite de prueba automatizada diseñada específicamente para la grabación en video
/// de un recorrido completo por todas las pantallas y funcionalidades de CasiListo.
///
/// Mantiene una cadencia pausada y natural (ritmo humano), con transiciones suaves,
/// interacción con controles, filtros, hojas modales y scroll en cada vista.
final class VideoTourTests: XCTestCase {

    private func pause(_ seconds: TimeInterval = 1.0) {
        Thread.sleep(forTimeInterval: seconds)
    }

    @MainActor
    private func smoothScrollDown(_ app: XCUIApplication, times: Int = 3, delay: TimeInterval = 0.9) {
        for _ in 0..<times {
            app.swipeUp()
            pause(delay)
        }
    }

    @MainActor
    private func smoothScrollUp(_ app: XCUIApplication, times: Int = 3, delay: TimeInterval = 0.9) {
        for _ in 0..<times {
            app.swipeDown()
            pause(delay)
        }
    }

    @MainActor
    private func launchAppForTour() -> XCUIApplication {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait

        let app = XCUIApplication()
        var args = ["-ui-testing-reset"]

        let env = ProcessInfo.processInfo.environment
        if env["VIDEO_APPEARANCE"] == "dark" {
            args.append("-ui-testing-dark")
        } else {
            args.append("-ui-testing-light")
        }

        app.launchArguments = args
        app.launch()
        return app
    }

    @MainActor
    func testRecordFullTour() throws {
        let app = launchAppForTour()
        pause(2.0)

        // ==========================================
        // 1. MIS LISTAS (Pantalla de Inicio)
        // ==========================================
        let listCard = app.buttons["list-card-Compra actual"]
        XCTAssertTrue(listCard.waitForExistence(timeout: 10), "No apareció la tarjeta de lista principal")
        pause(1.5)

        // Menú contextual de la tarjeta
        let cardMenu = app.buttons["list-card-menu-Compra actual"]
        if cardMenu.waitForExistence(timeout: 3) {
            cardMenu.tap()
            pause(1.5)
            // Cerrar el menú tocando fuera
            app.tap()
            pause(1.0)
        }

        // Hoja de creación de nueva lista
        let newListButton = app.buttons["Crear nueva lista"]
        if newListButton.waitForExistence(timeout: 3) {
            newListButton.tap()
            pause(1.5)

            let nameField = app.textFields["list-name-field"]
            if nameField.waitForExistence(timeout: 5) {
                nameField.tap()
                pause(0.5)
                nameField.typeText("Asado")
                pause(1.5)
                // Scroll para mostrar la paleta de colores y catálogo de iconos
                app.swipeUp()
                pause(1.5)
            }

            let cancelButton = app.buttons["Cancelar"]
            if cancelButton.waitForExistence(timeout: 3) {
                cancelButton.tap()
                pause(1.0)
            }
        }

        // ==========================================
        // 2. DETALLE DE LISTA (Compra actual)
        // ==========================================
        listCard.tap()
        pause(2.0)

        // Interacción con los filtros de supermercado
        let liderFilter = app.buttons["Líder"]
        if liderFilter.waitForExistence(timeout: 3) {
            liderFilter.tap()
            pause(1.2)
        }

        let jumboFilter = app.buttons["Jumbo"]
        if jumboFilter.waitForExistence(timeout: 3) {
            jumboFilter.tap()
            pause(1.2)
        }

        let allFilter = app.buttons["Todos"]
        if allFilter.waitForExistence(timeout: 3) {
            allFilter.tap()
            pause(1.2)
        }

        // Desplegar categoría principal
        let categoryHeader = app.buttons["category-section-Aseo personal"]
        if categoryHeader.waitForExistence(timeout: 5) {
            if (categoryHeader.value as? String) == "Colapsada" {
                categoryHeader.tap()
                pause(1.0)
            }
        }

        // Marcar un producto como comprado (animación de tachado y actualización)
        let itemToggle = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'item-toggle-'")
        ).firstMatch
        if itemToggle.waitForExistence(timeout: 5) {
            itemToggle.tap()
            pause(1.5)
        }

        // Recorrido con scroll suave hacia abajo por la lista de compras
        smoothScrollDown(app, times: 3, delay: 1.0)
        pause(1.5)

        // Scroll de regreso hacia la parte superior
        smoothScrollUp(app, times: 3, delay: 1.0)
        pause(1.0)

        // Menú de opciones de la barra superior (Toolbar)
        let toolbarMenu = app.buttons["toolbar-options-menu"]
        if toolbarMenu.waitForExistence(timeout: 5) {
            toolbarMenu.tap()
            pause(1.2)

            // Abrir y recorrer la hoja de plantillas
            let templatesButton = app.buttons["Usar plantilla"]
            if templatesButton.waitForExistence(timeout: 3) {
                templatesButton.tap()
                pause(2.0)

                app.swipeUp()
                pause(1.2)

                let closeTemplates = app.buttons["Cerrar"]
                if closeTemplates.waitForExistence(timeout: 3) {
                    closeTemplates.tap()
                    pause(1.0)
                }
            }

            // Abrir y recorrer la hoja de registrar boleta OCR
            toolbarMenu.tap()
            pause(1.2)

            let receiptButton = app.buttons["Registrar boleta"]
            if receiptButton.waitForExistence(timeout: 3) {
                receiptButton.tap()
                pause(2.0)

                let cancelReceipt = app.buttons["Cancelar"]
                if cancelReceipt.waitForExistence(timeout: 3) {
                    cancelReceipt.tap()
                    pause(1.0)
                }
            }

            // Archivar el producto comprado para generar entrada en el Historial
            toolbarMenu.tap()
            pause(1.0)

            let archiveOption = app.buttons["Archivar comprados"]
            if archiveOption.waitForExistence(timeout: 3) {
                archiveOption.tap()
                pause(1.2)
                let confirmArchive = app.buttons.matching(
                    NSPredicate(format: "label CONTAINS 'Archivar'")
                ).firstMatch
                if confirmArchive.waitForExistence(timeout: 3) {
                    confirmArchive.tap()
                    pause(1.5)
                }
            }
        }

        // ==========================================
        // 3. PESTAÑA CATÁLOGO
        // ==========================================
        let catalogTab = app.tabBars.buttons["Catálogo"]
        if catalogTab.waitForExistence(timeout: 5) {
            catalogTab.tap()
            pause(2.0)

            // Desplegar categoría del catálogo
            let catalogCategory = app.buttons["catalog-section-Aseo personal"]
            if catalogCategory.waitForExistence(timeout: 5) {
                catalogCategory.tap()
                pause(1.2)
            }

            // Scroll suave por el catálogo
            smoothScrollDown(app, times: 3, delay: 1.0)
            pause(1.5)
            smoothScrollUp(app, times: 3, delay: 1.0)
            pause(1.0)

            // Interacción con búsqueda en catálogo
            let searchField = app.searchFields.firstMatch
            if searchField.waitForExistence(timeout: 3) {
                searchField.tap()
                pause(0.5)
                searchField.typeText("Leche")
                pause(2.0)

                // Limpiar búsqueda
                let clearSearch = app.buttons["Clear text"]
                if clearSearch.waitForExistence(timeout: 2) {
                    clearSearch.tap()
                } else {
                    let cancelSearch = app.buttons["Cancelar"]
                    if cancelSearch.waitForExistence(timeout: 2) {
                        cancelSearch.tap()
                    }
                }
                pause(1.0)
            }
        }

        // ==========================================
        // 4. PESTAÑA HISTORIAL
        // ==========================================
        let historyTab = app.tabBars.buttons["Historial"]
        if historyTab.waitForExistence(timeout: 5) {
            historyTab.tap()
            pause(2.0)

            // Como acabamos de archivar una compra, habrá una tarjeta en el historial
            let historyCard = app.buttons.matching(
                NSPredicate(format: "label CONTAINS 'Compra' OR label CONTAINS 'Supermercado' OR label CONTAINS 'Líder' OR label CONTAINS 'Jumbo'")
            ).firstMatch

            if historyCard.waitForExistence(timeout: 4) {
                historyCard.tap()
                pause(2.0)
                app.swipeUp()
                pause(1.2)

                // Botón volver
                let backButton = app.navigationBars.buttons.element(boundBy: 0)
                if backButton.waitForExistence(timeout: 3) {
                    backButton.tap()
                    pause(1.0)
                }
            } else {
                // Si no hay tarjeta navegable, mostramos la vista con una pausa
                pause(1.5)
            }
        }

        // ==========================================
        // 5. PESTAÑA AJUSTES
        // ==========================================
        let settingsTab = app.tabBars.buttons["Ajustes"]
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()
            pause(2.0)

            // Scroll suave hasta el pie de Ajustes (versión y créditos)
            smoothScrollDown(app, times: 3, delay: 1.0)
            pause(2.0)
            smoothScrollUp(app, times: 3, delay: 1.0)
            pause(1.0)
        }

        // ==========================================
        // 6. REGRESO A COMPRA (Cierre visual)
        // ==========================================
        let buyTab = app.tabBars.buttons["Compra"]
        if buyTab.waitForExistence(timeout: 5) {
            buyTab.tap()
            pause(2.5)
        }
    }
}
