import XCTest

/// Test temporal de soporte para capturar el estado visual real de la app.
/// Escribe PNGs a la ruta indicada por la variable de entorno SCREENSHOT_DIR.
final class ScreenshotCaptureTests: XCTestCase {
    @MainActor
    func testCaptureMainListExpanded() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()

        let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? "/tmp"

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
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()

        let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? "/tmp"

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

    private func save(screenshot: XCUIScreenshot, to path: String) {
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
    }
}
