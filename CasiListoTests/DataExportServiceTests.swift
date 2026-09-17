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

    func testAsyncExportWritesTheSameVersionedFormat() async throws {
        let container = try ModelContainer(
            for: ShoppingItem.self, ShoppingList.self, ProductCatalogItem.self, CasiListo.Category.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let url = try await DataExportService.exportFileAsync(context: container.mainContext)
        defer { try? FileManager.default.removeItem(at: url) }

        let export = try decodeExport(at: url)
        XCTAssertEqual(export.schemaVersion, DataExportService.currentExportSchemaVersion)
    }

    /// Ajustes cacheaba la URL de la primera exportación de la sesión y
    /// compartía ese archivo para siempre: exportar después de cambiar algo
    /// entregaba datos viejos sin avisar (CASI-002). El arreglo es estructural
    /// —se borró el `@State` que cacheaba—, así que este test cubre el
    /// servicio: dos llamadas sucesivas deben reflejar el estado en cada una.
    func testExportingAgainReflectsDataWrittenAfterThePreviousExport() throws {
        let container = try ModelContainer(
            for: ShoppingItem.self, ShoppingList.self, ProductCatalogItem.self, CasiListo.Category.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let firstURL = try DataExportService.exportFile(context: context)
        defer { try? FileManager.default.removeItem(at: firstURL) }
        XCTAssertEqual(try decodeExport(at: firstURL).items.count, 0)

        context.insert(ShoppingItem(name: "Pan"))
        try context.save()

        let secondURL = try DataExportService.exportFile(context: context)
        defer { try? FileManager.default.removeItem(at: secondURL) }
        let second = try decodeExport(at: secondURL)
        XCTAssertEqual(second.items.count, 1)
        XCTAssertEqual(second.items.first?.name, "Pan")
    }

    private func decodeExport(at url: URL) throws -> DataExportService.Export {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DataExportService.Export.self, from: data)
    }

    // MARK: - Import de respaldo

    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ShoppingItem.self, ShoppingList.self, ProductCatalogItem.self, CasiListo.Category.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Round-trip completo: exportar, borrar todo, importar, y recuperar las
    /// 4 entidades con sus relaciones resueltas por nombre.
    func testImportAllRebuildsEveryEntityAfterAWipe() throws {
        let sourceContainer = try makeInMemoryContainer()
        let sourceContext = sourceContainer.mainContext
        let category = Category(name: "Bebidas", sfSymbol: "cup.and.saucer.fill", sortIndex: 0)
        let list = ShoppingList(title: "Compra Jumbo", completedAt: .now, status: .completed, storeScope: .jumbo)
        let item = ShoppingItem(name: "Cerveza", listID: list.id, quantity: "6", category: category, status: .purchased, price: 1_200, store: .jumbo)
        let catalogItem = ProductCatalogItem(name: "Cerveza", category: category, store: .jumbo, timesAdded: 3)
        sourceContext.insert(category)
        sourceContext.insert(list)
        sourceContext.insert(item)
        sourceContext.insert(catalogItem)
        try sourceContext.save()
        let data = try DataExportService.exportAll(context: sourceContext)

        let destinationContainer = try makeInMemoryContainer()
        let destinationContext = destinationContainer.mainContext

        let outcome = try DataExportService.importAll(data: data, context: destinationContext)
        XCTAssertEqual(outcome.newCategories, 1)
        XCTAssertEqual(outcome.newLists, 1)
        XCTAssertEqual(outcome.newItems, 1)
        XCTAssertEqual(outcome.newCatalogItems, 1)

        let importedItems = try destinationContext.fetch(FetchDescriptor<ShoppingItem>())
        XCTAssertEqual(importedItems.count, 1)
        let importedItem = try XCTUnwrap(importedItems.first)
        XCTAssertEqual(importedItem.name, "Cerveza")
        XCTAssertEqual(importedItem.id, item.id)
        XCTAssertEqual(importedItem.category.name, "Bebidas")
        XCTAssertEqual(importedItem.listID, list.id)
        XCTAssertEqual(importedItem.lineTotal, item.lineTotal)
    }

    /// Importar el mismo archivo dos veces no duplica nada.
    func testImportAllRunTwiceDoesNotDuplicate() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        context.insert(ShoppingItem(name: "Pan"))
        try context.save()
        let data = try DataExportService.exportAll(context: context)

        let destination = try makeInMemoryContainer()
        let destinationContext = destination.mainContext
        try DataExportService.importAll(data: data, context: destinationContext)
        let secondOutcome = try DataExportService.importAll(data: data, context: destinationContext)

        XCTAssertEqual(secondOutcome.newItems, 0)
        XCTAssertEqual(secondOutcome.skippedItems, 1)
        XCTAssertEqual(try destinationContext.fetch(FetchDescriptor<ShoppingItem>()).count, 1)
    }

    /// "Lacteos y huevos" (sin tildes, del archivo) se fusiona con "Lácteos y
    /// huevos" (con tildes, ya en el dispositivo): una sola categoría, y el
    /// ítem importado cuelga de la existente.
    func testImportAllReusesExistingCategoryIgnoringAccentsAndCase() throws {
        let destination = try makeInMemoryContainer()
        let destinationContext = destination.mainContext
        let existingCategory = Category(name: "Lácteos y huevos", sfSymbol: "custom.symbol", sortIndex: 5)
        destinationContext.insert(existingCategory)
        try destinationContext.save()

        let sourceContainer = try makeInMemoryContainer()
        let sourceContext = sourceContainer.mainContext
        let sourceCategory = Category(name: "lacteos y huevos", sfSymbol: "oval.portrait.fill", sortIndex: 10)
        sourceContext.insert(sourceCategory)
        sourceContext.insert(ShoppingItem(name: "Leche", category: sourceCategory))
        try sourceContext.save()
        let data = try DataExportService.exportAll(context: sourceContext)

        let outcome = try DataExportService.importAll(data: data, context: destinationContext)
        XCTAssertEqual(outcome.newCategories, 0, "Debió reusar la categoría existente, no crear una nueva")

        let categories = try destinationContext.fetch(FetchDescriptor<CasiListo.Category>())
        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories.first?.sfSymbol, "custom.symbol", "No debía pisar el símbolo personalizado")

        let items = try destinationContext.fetch(FetchDescriptor<ShoppingItem>())
        XCTAssertEqual(items.first?.category.name, "Lácteos y huevos")
    }

    /// Colisión de `id`: el dispositivo gana, el título del archivo se descarta.
    func testImportAllKeepsDeviceRowsWhenIDsCollide() throws {
        let destination = try makeInMemoryContainer()
        let destinationContext = destination.mainContext
        let deviceList = ShoppingList(title: "Mi título", status: .active)
        destinationContext.insert(deviceList)
        try destinationContext.save()

        let sourceContainer = try makeInMemoryContainer()
        let sourceContext = sourceContainer.mainContext
        let sourceList = ShoppingList(title: "Título del archivo", status: .active)
        sourceList.id = deviceList.id
        sourceContext.insert(sourceList)
        try sourceContext.save()
        let data = try DataExportService.exportAll(context: sourceContext)

        let outcome = try DataExportService.importAll(data: data, context: destinationContext)
        XCTAssertEqual(outcome.newLists, 0)
        XCTAssertEqual(outcome.skippedLists, 1)

        let lists = try destinationContext.fetch(FetchDescriptor<ShoppingList>())
        XCTAssertEqual(lists.count, 1)
        XCTAssertEqual(lists.first?.title, "Mi título")
    }

    /// Un ítem cuyo `listID` no existe ni en el archivo ni en el dispositivo
    /// va a una lista de respaldo nueva, nunca con `listID == nil`.
    func testImportAllAttachesOrphanItemsToAnImportedHistoryList() throws {
        let sourceContainer = try makeInMemoryContainer()
        let sourceContext = sourceContainer.mainContext
        let orphan = ShoppingItem(name: "Producto huérfano", listID: UUID())
        sourceContext.insert(orphan)
        try sourceContext.save()
        let data = try DataExportService.exportAll(context: sourceContext)

        let destination = try makeInMemoryContainer()
        let destinationContext = destination.mainContext
        try DataExportService.importAll(data: data, context: destinationContext)

        let items = try destinationContext.fetch(FetchDescriptor<ShoppingItem>())
        let importedItem = try XCTUnwrap(items.first { $0.name == "Producto huérfano" })
        XCTAssertNotNil(importedItem.listID)

        let lists = try destinationContext.fetch(FetchDescriptor<ShoppingList>())
        let hostList = try XCTUnwrap(lists.first { $0.id == importedItem.listID })
        XCTAssertEqual(hostList.status, .completed)
        XCTAssertTrue(hostList.title.hasPrefix("Respaldo importado"))
    }

    /// Los blobs no viajan en el respaldo: nunca lo hicieron, y no deben
    /// llegar como nombres de archivo que apuntan a nada en este dispositivo.
    func testImportAllDropsBlobFilenames() throws {
        let sourceContainer = try makeInMemoryContainer()
        let sourceContext = sourceContainer.mainContext
        let list = ShoppingList(title: "Compra Jumbo", completedAt: .now, status: .completed, receiptImageFilename: "boleta.jpg")
        let item = ShoppingItem(name: "Producto", listID: list.id, voiceNoteFilename: "voice.m4a")
        sourceContext.insert(list)
        sourceContext.insert(item)
        try sourceContext.save()
        let data = try DataExportService.exportAll(context: sourceContext)

        let destination = try makeInMemoryContainer()
        let destinationContext = destination.mainContext
        try DataExportService.importAll(data: data, context: destinationContext)

        let importedList = try XCTUnwrap(try destinationContext.fetch(FetchDescriptor<ShoppingList>()).first)
        XCTAssertNil(importedList.receiptImageFilename)
        let importedItem = try XCTUnwrap(try destinationContext.fetch(FetchDescriptor<ShoppingItem>()).first)
        XCTAssertNil(importedItem.voiceNoteFilename)
    }

    /// Datos corruptos no deben tocar el contexto en absoluto.
    func testImportAllRejectsMalformedDataWithoutTouchingTheStore() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        context.insert(ShoppingItem(name: "Existente"))
        try context.save()

        XCTAssertThrowsError(try DataExportService.importAll(data: Data("{".utf8), context: context))

        XCTAssertEqual(try context.fetch(FetchDescriptor<ShoppingItem>()).count, 1)
    }

    /// El resumen que se le muestra a la persona antes de confirmar tiene que
    /// coincidir exactamente con lo que la importación real termina escribiendo.
    func testPlanImportMatchesWhatImportActuallyWrites() throws {
        let sourceContainer = try makeInMemoryContainer()
        let sourceContext = sourceContainer.mainContext
        sourceContext.insert(ShoppingItem(name: "Producto 1"))
        sourceContext.insert(ShoppingItem(name: "Producto 2"))
        try sourceContext.save()
        let data = try DataExportService.exportAll(context: sourceContext)

        let destination = try makeInMemoryContainer()
        let destinationContext = destination.mainContext
        let planned = try DataExportService.planImport(data: data, context: destinationContext)
        let actual = try DataExportService.importAll(data: data, context: destinationContext)

        XCTAssertEqual(planned, actual)
    }

    func testAsyncImportPlanningAndMutationRemainIdempotent() async throws {
        let source = try makeInMemoryContainer()
        source.mainContext.insert(ShoppingItem(name: "Pan"))
        try source.mainContext.save()
        let data = try DataExportService.exportAll(context: source.mainContext)

        let destination = try makeInMemoryContainer()
        let planned = try await DataExportService.planImportAsync(data: data, context: destination.mainContext)
        let applied = try await DataExportService.importAllAsync(data: data, context: destination.mainContext)
        let repeated = try await DataExportService.importAllAsync(data: data, context: destination.mainContext)

        XCTAssertEqual(planned, applied)
        XCTAssertTrue(repeated.addsNothing)
    }

    /// Los contadores de uso del catálogo se fusionan, nunca bajan.
    func testImportAllMergesCatalogUsageCounters() throws {
        let destination = try makeInMemoryContainer()
        let destinationContext = destination.mainContext
        let existingCatalogItem = ProductCatalogItem(name: "Pan", timesAdded: 10)
        destinationContext.insert(existingCatalogItem)
        try destinationContext.save()

        let sourceContainer = try makeInMemoryContainer()
        let sourceContext = sourceContainer.mainContext
        sourceContext.insert(ProductCatalogItem(name: "pan", timesAdded: 3))
        try sourceContext.save()
        let data = try DataExportService.exportAll(context: sourceContext)

        let outcome = try DataExportService.importAll(data: data, context: destinationContext)
        XCTAssertEqual(outcome.mergedCatalogItems, 1)
        XCTAssertEqual(outcome.newCatalogItems, 0)

        let catalogItems = try destinationContext.fetch(FetchDescriptor<ProductCatalogItem>())
        XCTAssertEqual(catalogItems.count, 1)
        XCTAssertEqual(catalogItems.first?.timesAdded, 10, "El contador no debía bajar")
    }

    /// CASI-008: el vínculo estable viaja en el respaldo y se restaura en una
    /// categoría nueva; sobre un dispositivo que ya tiene ese vínculo con
    /// otro nombre, no se duplica (el dispositivo gana).
    func testImportAllCarriesTheDefaultCategoryLinkWithoutDuplicatingIt() throws {
        // Los containers se retienen a propósito: soltarlos y quedarse solo con
        // el `mainContext` hace que SwiftData reviente con SIGTRAP al primer fetch.
        let sourceContainer = try makeInMemoryContainer()
        let sourceContext = sourceContainer.mainContext
        try CategoryBootstrapService.bootstrap(context: sourceContext)
        let data = try DataExportService.exportAll(context: sourceContext)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exported = try decoder.decode(DataExportService.Export.self, from: data)
        XCTAssertEqual(exported.categories.first { $0.name == "Carnes" }?.defaultCategoryRawValue, "Carnes")

        // Dispositivo vaciado: las categorías nuevas traen el vínculo.
        let wipedContainer = try makeInMemoryContainer()
        let wipedContext = wipedContainer.mainContext
        try DataExportService.importAll(data: data, context: wipedContext)
        let restored = try wipedContext.fetch(FetchDescriptor<CasiListo.Category>())
        XCTAssertEqual(restored.first { $0.name == "Carnes" }?.defaultCategory, .carnes)
        XCTAssertEqual(restored.filter { $0.defaultCategory != nil }.count, DefaultCategory.allCases.count)

        // Dispositivo con "Carnicería" ya vinculada a .carnes: la "Carnes" del
        // respaldo se crea sin vínculo, y `matching` sigue eligiendo la local.
        let busyContainer = try makeInMemoryContainer()
        let busyContext = busyContainer.mainContext
        busyContext.insert(Category(name: "Carnicería", sfSymbol: "fork.knife", sortIndex: 3, isSystem: true, defaultCategory: .carnes))
        try busyContext.save()
        try DataExportService.importAll(data: data, context: busyContext)
        let merged = try busyContext.fetch(FetchDescriptor<CasiListo.Category>())
        XCTAssertEqual(merged.filter { $0.defaultCategory == .carnes }.count, 1)
        XCTAssertEqual(Category.matching(.carnes, in: merged)?.name, "Carnicería")
        XCTAssertNil(merged.first { $0.name == "Carnes" }?.defaultCategory)
    }
}
