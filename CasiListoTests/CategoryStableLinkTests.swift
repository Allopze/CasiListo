import SwiftData
import SwiftUI
import XCTest
@testable import CasiListo

/// CASI-008: la categorización automática resuelve por el vínculo estable
/// `Category.defaultCategoryRawValue`, no por `name`. Renombrar "Carnes" a
/// "Carnicería" ya no manda "Bistec" a «Varios».
@MainActor
final class CategoryStableLinkTests: XCTestCase {

    /// El container tiene que sobrevivir al test: `try makeContainer().mainContext`
    /// a secas lo libera al instante y SwiftData revienta con SIGTRAP al primer
    /// fetch. Se retiene aquí y se suelta en `tearDown`.
    private var containers: [ModelContainer] = []

    override func tearDown() {
        containers.removeAll()
        super.tearDown()
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: CasiListoMigrationPlan.currentSchema)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        containers.append(container)
        return container.mainContext
    }

    private func fetchCategories(in context: ModelContext) throws -> [CasiListo.Category] {
        try context.fetch(FetchDescriptor<CasiListo.Category>())
    }

    func testFreshBootstrapLinksAllFifteenSystemCategories() throws {
        let context = try makeContext()
        try CategoryBootstrapService.bootstrap(context: context)

        let categories = try fetchCategories(in: context)
        XCTAssertEqual(categories.count, DefaultCategory.allCases.count)
        for defaultCat in DefaultCategory.allCases {
            let match = try XCTUnwrap(Category.matching(defaultCat, in: categories), defaultCat.rawValue)
            XCTAssertEqual(match.defaultCategory, defaultCat)
            XCTAssertTrue(match.isSystem)
        }
    }

    /// El bug original: "Carnes" → "Carnicería" y "Bistec" seguía cayendo en
    /// «Varios» porque los resolutores buscaban `name == "Carnes"`.
    func testRenamedSystemCategoryStillReceivesAutomaticSuggestions() throws {
        let context = try makeContext()
        try CategoryBootstrapService.bootstrap(context: context)

        let carnes = try XCTUnwrap(fetchCategories(in: context).first { $0.name == "Carnes" })
        carnes.name = "Carnicería"
        try context.save()

        let categories = try fetchCategories(in: context)
        XCTAssertNil(categories.first { $0.name == "Carnes" })
        XCTAssertEqual(SuggestedProducts.suggestedCategory(for: "Bistec", in: categories)?.name, "Carnicería")
        XCTAssertEqual(Category.matching(.carnes, in: categories)?.name, "Carnicería")
    }

    /// Simula un store de la 1.0 (las 15 sembradas sin vínculo) pasando por
    /// el primer arranque con V2.
    func testBackfillLinksSystemCategoriesByExactName() throws {
        let context = try makeContext()
        for defaultCat in DefaultCategory.allCases {
            context.insert(Category(name: defaultCat.rawValue, sfSymbol: defaultCat.sfSymbol, sortIndex: defaultCat.sortIndex, isSystem: true))
        }
        try context.save()
        XCTAssertTrue(try fetchCategories(in: context).allSatisfy { $0.defaultCategory == nil })

        try CategoryBootstrapService.bootstrap(context: context)

        let categories = try fetchCategories(in: context)
        XCTAssertEqual(categories.count, DefaultCategory.allCases.count, "No debe volver a sembrar")
        for defaultCat in DefaultCategory.allCases {
            XCTAssertEqual(categories.first { $0.name == defaultCat.rawValue }?.defaultCategory, defaultCat)
        }
    }

    /// Renombrada antes de V2 pero con su icono original: se recupera por
    /// `sfSymbol` porque es un candidato único entre las libres.
    func testBackfillRecoversARenamedCategoryByItsUniqueSymbol() throws {
        let context = try makeContext()
        context.insert(Category(name: "Carnicería", sfSymbol: DefaultCategory.carnes.sfSymbol, sortIndex: 3, isSystem: true))
        context.insert(Category(name: "Varios", sfSymbol: "bag.fill", sortIndex: 999, isSystem: true))
        try context.save()

        try CategoryBootstrapService.bootstrap(context: context)

        let categories = try fetchCategories(in: context)
        XCTAssertEqual(categories.first { $0.name == "Carnicería" }?.defaultCategory, .carnes)
        XCTAssertEqual(categories.first { $0.name == "Varios" }?.defaultCategory, .varios)
        // Y el icono no se pisa: el nombre ya no es el original.
        XCTAssertEqual(categories.first { $0.name == "Carnicería" }?.sfSymbol, DefaultCategory.carnes.sfSymbol)
    }

    /// Dos categorías del sistema sin vínculo con el mismo símbolo: no hay
    /// forma de saber cuál es cuál, así que ninguna se vincula.
    func testBackfillDoesNotGuessWhenTwoUnlinkedCategoriesShareASymbol() throws {
        let context = try makeContext()
        context.insert(Category(name: "Parrilla", sfSymbol: DefaultCategory.carnes.sfSymbol, sortIndex: 1, isSystem: true))
        context.insert(Category(name: "Asado", sfSymbol: DefaultCategory.carnes.sfSymbol, sortIndex: 2, isSystem: true))
        try context.save()

        try CategoryBootstrapService.bootstrap(context: context)

        let categories = try fetchCategories(in: context)
        XCTAssertNil(categories.first { $0.name == "Parrilla" }?.defaultCategory)
        XCTAssertNil(categories.first { $0.name == "Asado" }?.defaultCategory)
    }

    /// Una categoría creada por la persona nunca recibe vínculo, aunque se
    /// llame exactamente como una del sistema que borró antes.
    func testUserCreatedCategoryNeverReceivesALink() throws {
        let context = try makeContext()
        context.insert(Category(name: "Carnes", sfSymbol: "fork.knife", sortIndex: 0, isSystem: false))
        context.insert(Category(name: "Varios", sfSymbol: "bag.fill", sortIndex: 999, isSystem: true))
        try context.save()

        try CategoryBootstrapService.bootstrap(context: context)

        let carnes = try XCTUnwrap(fetchCategories(in: context).first { $0.name == "Carnes" })
        XCTAssertNil(carnes.defaultCategory)
        // …pero `matching` sigue encontrándola por nombre, como hasta ahora.
        XCTAssertEqual(Category.matching(.carnes, in: try fetchCategories(in: context))?.name, "Carnes")
    }

    func testBootstrapIsIdempotentAcrossLaunches() throws {
        let context = try makeContext()
        try CategoryBootstrapService.bootstrap(context: context)
        let carnes = try XCTUnwrap(fetchCategories(in: context).first { $0.name == "Carnes" })
        carnes.name = "Carnicería"
        carnes.sfSymbol = "flame.fill"
        try context.save()

        func snapshot() throws -> [String: String] {
            Dictionary(uniqueKeysWithValues: try fetchCategories(in: context).map {
                ($0.name, "\($0.defaultCategoryRawValue ?? "-")|\($0.sfSymbol)|\($0.sortIndex)")
            })
        }
        let before = try snapshot()
        try CategoryBootstrapService.bootstrap(context: context)
        try CategoryBootstrapService.bootstrap(context: context)
        XCTAssertEqual(try snapshot(), before)
        // Renombrada y re-simbolizada a propósito: el icono se respeta.
        XCTAssertEqual(before["Carnicería"], "Carnes|flame.fill|3")
    }

    /// La reconciliación de `sfSymbol` sí corrige el icono de una categoría
    /// que conserva su nombre original (es lo que arregló «egg.fill»).
    func testSymbolReconciliationStillRepairsCategoriesWithTheirOriginalName() throws {
        let context = try makeContext()
        context.insert(Category(name: "Lácteos y huevos", sfSymbol: "egg.fill", sortIndex: 10, isSystem: true))
        context.insert(Category(name: "Varios", sfSymbol: "bag.fill", sortIndex: 999, isSystem: true))
        try context.save()

        try CategoryBootstrapService.bootstrap(context: context)

        let lacteos = try XCTUnwrap(fetchCategories(in: context).first { $0.name == "Lácteos y huevos" })
        XCTAssertEqual(lacteos.defaultCategory, .lacteosHuevos)
        XCTAssertEqual(lacteos.sfSymbol, DefaultCategory.lacteosHuevos.sfSymbol)
    }

    /// Los dos sembradores de productos también siguen el vínculo.
    func testSeedersUseTheRenamedCategoryInsteadOfVarios() throws {
        let context = try makeContext()
        try CategoryBootstrapService.bootstrap(context: context)
        let carnes = try XCTUnwrap(fetchCategories(in: context).first { $0.name == "Carnes" })
        carnes.name = "Carnicería"
        try context.save()

        let list = try ShoppingListLifecycleService.createActiveList(in: context)
        try SuggestedProducts.seedDefaultItems(in: context, listID: list.id)
        let items = try context.fetch(FetchDescriptor<ShoppingItem>())
        XCTAssertTrue(items.contains { $0.categoryRawValue == "Carnicería" })
        XCTAssertFalse(items.contains { $0.categoryRawValue == "Carnes" })

        let suiteName = "test.stablelink.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removeSuite(named: suiteName) }
        try SuggestedProducts.seedCatalogItems(in: context, defaults: defaults)
        let catalog = try context.fetch(FetchDescriptor<ProductCatalogItem>())
        XCTAssertTrue(catalog.contains { $0.categoryRawValue == "Carnicería" })
        XCTAssertFalse(catalog.contains { $0.categoryRawValue == "Carnes" })
    }

    /// Colores e iconos también siguen al vínculo: "Carnicería" sigue siendo
    /// roja, no cae al amarillo genérico de las categorías personalizadas.
    func testAccentColorFollowsTheLinkAfterRename() throws {
        let renamed = Category(name: "Carnicería", sfSymbol: "fork.knife", sortIndex: 3, isSystem: true, defaultCategory: .carnes)
        XCTAssertEqual(UIColor(Category.accentColor(for: renamed)), UIColor(DefaultCategory.carnes.color))
        XCTAssertNotEqual(UIColor(Category.accentColor(forName: "Carnicería")), UIColor(DefaultCategory.carnes.color))
    }

    func testVariosStaysProtectedEvenIfRenamedThroughTheLink() {
        let varios = Category(name: "Miscelánea", sfSymbol: "bag.fill", sortIndex: 999, isSystem: true, defaultCategory: .varios)
        XCTAssertFalse(Category.isEditable(varios))
        XCTAssertFalse(Category.isEditable(Category.fallback))
        XCTAssertTrue(Category.isEditable(Category(name: "Carnes", sfSymbol: "fork.knife", sortIndex: 0, isSystem: true, defaultCategory: .carnes)))
    }
}
