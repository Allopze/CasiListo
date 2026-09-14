import SwiftData
import XCTest
@testable import CasiListo

@MainActor
final class HistoryCSVExportServiceTests: XCTestCase {

    func testDocumentIncludesHeaderAndOneRowPerItemOfCompletedLists() {
        let category = Category(name: "Bebidas", sfSymbol: "cup.and.saucer.fill", sortIndex: 0)
        let completedList = ShoppingList(title: "Compra Jumbo", completedAt: .now, status: .completed, storeScope: .jumbo)
        let item = ShoppingItem(name: "Cerveza", listID: completedList.id, quantity: "6", category: category, status: .purchased, price: 1_200, store: .jumbo)

        let rows = HistoryCSVExportService.rows(completedLists: [completedList], items: [item])

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0], HistoryCSVExportService.header)
        XCTAssertEqual(rows[1][1], "Compra Jumbo")
        XCTAssertEqual(rows[1][3], "Cerveza")
        XCTAssertEqual(rows[1][5], "Bebidas")
        XCTAssertEqual(rows[1][6], "Comprado")
        XCTAssertEqual(rows[1][7], "1200.0")
    }

    /// Solo listas completadas: una lista activa con ítems no debe aparecer,
    /// aunque su `id` no se pase en absoluto en `completedLists`.
    func testDocumentIgnoresActiveLists() {
        let activeList = ShoppingList(title: "Compra actual", status: .active)
        let item = ShoppingItem(name: "Pan", listID: activeList.id)

        let rows = HistoryCSVExportService.rows(completedLists: [], items: [item])

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0], HistoryCSVExportService.header)
    }

    func testDocumentEscapesTitlesWithCommasAndQuotes() {
        let list = ShoppingList(title: "Compra, \"especial\"", completedAt: .now, status: .completed)
        let item = ShoppingItem(name: "Producto", listID: list.id)

        let document = HistoryCSVExportService.document(completedLists: [list], items: [item])

        XCTAssertTrue(document.contains("\"Compra, \"\"especial\"\"\""))
    }

    func testExportFileWritesCSVWithDatedName() throws {
        let url = try HistoryCSVExportService.exportFile(completedLists: [], items: [])
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(url.lastPathComponent.hasPrefix("CasiListo-historial-"))
        XCTAssertEqual(url.pathExtension, "csv")
    }

    /// El bug que motiva el ítem: el `String` cacheado en `.task(id: allItems)`
    /// no se regeneraba al editar un precio, porque `@Query` compara identidad
    /// de array, no contenido (CASI-005). Con un servicio sin caché, dos
    /// llamadas sucesivas deben reflejar el precio de cada momento.
    func testExportingAgainReflectsAPriceEditedAfterThePreviousExport() throws {
        let list = ShoppingList(title: "Compra Jumbo", completedAt: .now, status: .completed)
        let item = ShoppingItem(name: "Cerveza", listID: list.id, price: 1_200)

        let firstURL = try HistoryCSVExportService.exportFile(completedLists: [list], items: [item])
        defer { try? FileManager.default.removeItem(at: firstURL) }
        XCTAssertTrue(try String(contentsOf: firstURL, encoding: .utf8).contains("1200.0"))

        item.price = 1_500

        let secondURL = try HistoryCSVExportService.exportFile(completedLists: [list], items: [item])
        defer { try? FileManager.default.removeItem(at: secondURL) }
        let secondContent = try String(contentsOf: secondURL, encoding: .utf8)
        XCTAssertTrue(secondContent.contains("1500.0"))
        XCTAssertFalse(secondContent.contains("1200.0"))
    }
}
