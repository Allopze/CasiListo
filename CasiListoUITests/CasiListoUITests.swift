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

    @MainActor
    func testListSupportsSkippedAndUnavailableActions() throws {
        let app = launchFreshApp()

        app.buttons["quick-add-product"].tap()
        let nameField = app.textFields["item-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.typeText("Producto con estados")
        app.buttons["Añadir"].tap()

        let item = app.staticTexts["Producto con estados"]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.press(forDuration: 1)

        XCTAssertTrue(app.buttons["Posponer"].waitForExistence(timeout: 5))
        app.buttons["Posponer"].tap()

        item.press(forDuration: 1)
        XCTAssertTrue(app.buttons["No encontrado"].waitForExistence(timeout: 5))
        app.buttons["No encontrado"].tap()
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
