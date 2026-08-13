import XCTest

final class CasiListoUITests: XCTestCase {
    @MainActor
    private func launchFreshApp() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset"]
        app.launch()
        return app
    }

    @MainActor
    func testCreateMarkArchiveAndOpenHistory() throws {
        let app = launchFreshApp()

        let addProductButton = app.buttons["toolbar-add-product"]
        XCTAssertTrue(addProductButton.waitForExistence(timeout: 5))
        addProductButton.tap()

        let nameField = app.textFields["item-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Producto UI Test")

        app.buttons["Añadir"].tap()

        let createdItem = app.buttons.containing(.staticText, identifier: "Producto UI Test").firstMatch
        XCTAssertTrue(createdItem.waitForExistence(timeout: 5))
        createdItem.tap()

        app.buttons["toolbar-options-menu"].tap()
        app.buttons["Archivar comprados"].tap()
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Archivar'")).firstMatch.tap()

        app.buttons["toolbar-options-menu"].tap()
        app.buttons["Historial"].tap()

        XCTAssertTrue(app.navigationBars["Historial"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testListSupportsSkippedAndUnavailableActions() throws {
        let app = launchFreshApp()

        app.buttons["toolbar-add-product"].tap()
        let nameField = app.textFields["item-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.typeText("Producto con estados")
        app.buttons["Añadir"].tap()

        let item = app.buttons.containing(.staticText, identifier: "Producto con estados").firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.press(forDuration: 1)

        XCTAssertTrue(app.buttons["Posponer"].waitForExistence(timeout: 5))
        app.buttons["Posponer"].tap()

        item.press(forDuration: 1)
        XCTAssertTrue(app.buttons["No encontrado"].waitForExistence(timeout: 5))
        app.buttons["No encontrado"].tap()
    }
}
