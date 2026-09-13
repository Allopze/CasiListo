import SwiftData
import XCTest
@testable import CasiListo

@MainActor
final class DataExportServiceTests: XCTestCase {

    func testExportAllRoundTripsCountsAndFields() throws {
        let container = try ModelContainer(
            for: ShoppingItem.self, ShoppingList.self, ProductCatalogItem.self, CasiListo.Category.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let category = Category(name: "Bebidas", sfSymbol: "cup.and.saucer.fill", sortIndex: 0)
        let list = ShoppingList(title: "Compra actual")
        let item = ShoppingItem(name: "Cerveza", listID: list.id, quantity: "6", category: category, price: 1_200, store: .jumbo)
        let catalogItem = ProductCatalogItem(name: "Cerveza", category: category, store: .jumbo, timesAdded: 3)
        context.insert(category)
        context.insert(list)
        context.insert(item)
        context.insert(catalogItem)
        try context.save()

        let data = try DataExportService.exportAll(context: context)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(DataExportService.Export.self, from: data)

        XCTAssertEqual(export.categories.count, 1)
        XCTAssertEqual(export.categories.first?.name, "Bebidas")
        XCTAssertEqual(export.lists.count, 1)
        XCTAssertEqual(export.lists.first?.title, "Compra actual")
        XCTAssertEqual(export.items.count, 1)
        XCTAssertEqual(export.items.first?.name, "Cerveza")
        XCTAssertEqual(export.items.first?.category, "Bebidas")
        XCTAssertEqual(export.items.first?.price, 1_200)
        XCTAssertEqual(export.catalogItems.count, 1)
        XCTAssertEqual(export.catalogItems.first?.timesAdded, 3)
    }

    func testExportFileWritesReadableJSON() throws {
        let container = try ModelContainer(
            for: ShoppingItem.self, ShoppingList.self, ProductCatalogItem.self, CasiListo.Category.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let url = try DataExportService.exportFile(context: context)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(url.lastPathComponent.hasPrefix("CasiListo-"))
        XCTAssertEqual(url.pathExtension, "json")

        let data = try Data(contentsOf: url)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }
}
