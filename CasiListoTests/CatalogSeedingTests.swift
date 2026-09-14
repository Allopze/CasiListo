import SwiftData
import XCTest
@testable import CasiListo

/// Tests del sembrado versionado del catálogo (CASI-009). Archivo aparte de
/// `CasiListoTests.swift` a propósito: ese archivo ya excede con holgura el
/// umbral de tamaño calibrado en `.swiftlint.yml`.
@MainActor
final class CatalogSeedingTests: XCTestCase {

    /// El objetivo de la versión: un lote nuevo entra sin resucitar lo que la
    /// persona borró. No hay lote 2 todavía, así que se inyecta uno simulado.
    func testNewBatchSeedsOnlyTheDeltaAndRespectsDeletions() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        try CategoryBootstrapService.bootstrap(context: context)

        let suiteName = "test.catalog.batch.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        // Lote 1: el catálogo de la 1.0.
        try SuggestedProducts.seedCatalogItems(in: context, defaults: defaults)
        XCTAssertEqual(defaults.integer(forKey: SuggestedProducts.catalogSeedBatchKey), 1)

        guard let victim = try context.fetch(FetchDescriptor<ProductCatalogItem>())
            .first(where: { $0.name == "Doritos" }) else {
            return XCTFail("El fixture ya no incluye «Doritos»")
        }
        context.delete(victim)
        try context.save()

        // Lote 2 simulado: un producto nuevo en Despensa.
        try SuggestedProducts.seedCatalogItems(
            in: context,
            defaults: defaults,
            currentBatch: 2,
            batches: [2: [.despensa: ["Harina integral de prueba"]]]
        )

        let after = try context.fetch(FetchDescriptor<ProductCatalogItem>())
        XCTAssertFalse(after.contains { $0.name == "Doritos" }, "Un producto borrado volvió con el lote nuevo")
        XCTAssertTrue(after.contains { $0.name == "Harina integral de prueba" }, "El producto del lote nuevo no entró")
        XCTAssertEqual(defaults.integer(forKey: SuggestedProducts.catalogSeedBatchKey), 2)
    }

    /// Instalación de la 1.0: solo tiene la bandera booleana heredada. Debe
    /// contar como lote 1 y recibir el delta del lote 2, no el catálogo
    /// entero otra vez.
    func testLegacyBooleanFlagCountsAsBatchOne() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        try CategoryBootstrapService.bootstrap(context: context)

        let suiteName = "test.catalog.legacy.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        // Simula una instalación 1.0: solo la bandera vieja, sin la clave nueva.
        defaults.set(true, forKey: SuggestedProducts.hasSeededCatalogKey)
        XCTAssertEqual(SuggestedProducts.seededCatalogBatch(defaults: defaults), 1)

        try SuggestedProducts.seedCatalogItems(
            in: context,
            defaults: defaults,
            currentBatch: 2,
            batches: [2: [.despensa: ["Harina integral de prueba"]]]
        )

        let after = try context.fetch(FetchDescriptor<ProductCatalogItem>())
        // No se sembró el catálogo completo del lote 1 (la tabla seguía vacía
        // antes de esta llamada, y solo debe traer el delta del lote 2).
        XCTAssertEqual(after.count, 1)
        XCTAssertEqual(after.first?.name, "Harina integral de prueba")
        XCTAssertEqual(defaults.integer(forKey: SuggestedProducts.catalogSeedBatchKey), 2)
    }

    /// El lote nuevo no vuelve a correr en el siguiente arranque.
    func testSeedingIsANoOpOnceTheCurrentBatchIsRecorded() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        try CategoryBootstrapService.bootstrap(context: context)

        let suiteName = "test.catalog.noop.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        try SuggestedProducts.seedCatalogItems(in: context, defaults: defaults)
        let countAfterFirst = try context.fetch(FetchDescriptor<ProductCatalogItem>()).count

        try SuggestedProducts.seedCatalogItems(in: context, defaults: defaults)
        let countAfterSecond = try context.fetch(FetchDescriptor<ProductCatalogItem>()).count

        XCTAssertEqual(countAfterFirst, countAfterSecond)
    }

    /// Instalación limpia con el lote 2 ya publicado: un solo pase, desde
    /// `byCategory` (que ya trae todo, incluido lo del lote 2 — el
    /// procedimiento real de versionar un lote lo duplica ahí en el paso 1),
    /// sin duplicados, y con la marca de lote quedando en 2, no en 1.
    func testFreshInstallSeedsEverythingInOnePass() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        try CategoryBootstrapService.bootstrap(context: context)

        let suiteName = "test.catalog.fresh.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        // "Doritos" ya vive en `byCategory`: simula que un lote 2 real lo
        // trajo (el paso 1 de versionar un lote es duplicarlo ahí), a
        // diferencia de un producto inventado que solo existiera en el delta.
        try SuggestedProducts.seedCatalogItems(
            in: context,
            defaults: defaults,
            currentBatch: 2,
            batches: [2: [.despensa: ["Doritos"]]]
        )

        let all = try context.fetch(FetchDescriptor<ProductCatalogItem>())
        let normalized = all.map { ProductNameNormalizer.normalize($0.name) }
        XCTAssertEqual(normalized.count, Set(normalized).count, "El catálogo trae nombres repetidos")
        XCTAssertEqual(all.filter { $0.name == "Doritos" }.count, 1, "El delta duplicó un producto ya cubierto por byCategory")
        XCTAssertEqual(defaults.integer(forKey: SuggestedProducts.catalogSeedBatchKey), 2)
    }

    /// El libro mayor de deltas y `byCategory` no pueden divergir: si alguien
    /// añade un producto solo a `productsIntroducedIn`, las instalaciones
    /// limpias (que siembran desde `byCategory`) nunca lo verían.
    func testEveryBatchedProductAlsoLivesInByCategory() {
        for (batch, categories) in SuggestedProducts.productsIntroducedIn {
            for (category, products) in categories {
                for product in products {
                    XCTAssertTrue(
                        SuggestedProducts.byCategory[category]?.contains(product) ?? false,
                        "«\(product)» está en el lote \(batch) bajo \(category.rawValue) pero no en byCategory"
                    )
                }
            }
        }
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ShoppingItem.self, ShoppingList.self, ProductCatalogItem.self, CasiListo.Category.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
