import XCTest
import SwiftData
import SwiftUI
import UIKit
@testable import CasiListo

@MainActor
final class CasiListoTests: XCTestCase {

    // MARK: - quickAddDraft parsing

    func testQuickAddDraftParsesCommonQuantityPatterns() {
        let vm = ShoppingListViewModel()

        let leading = vm.quickAddDraft(from: "2 leche")
        XCTAssertEqual(leading.name, "leche")
        XCTAssertEqual(leading.quantity, "2")

        let trailingMultiplier = vm.quickAddDraft(from: "pan x3")
        XCTAssertEqual(trailingMultiplier.name, "pan")
        XCTAssertEqual(trailingMultiplier.quantity, "3")

        let trailingUnit = vm.quickAddDraft(from: "tomates 1 kg")
        XCTAssertEqual(trailingUnit.name, "tomates")
        XCTAssertEqual(trailingUnit.quantity, "1 kg")
    }

    func testQuickAddDraftSingleWordReturnsNameOnly() {
        let vm = ShoppingListViewModel()
        let draft = vm.quickAddDraft(from: "pan")
        XCTAssertEqual(draft.name, "pan")
        XCTAssertEqual(draft.quantity, "")
    }

    func testQuickAddDraftNormalizesCommaDecimalSeparator() {
        let vm = ShoppingListViewModel()
        let draft = vm.quickAddDraft(from: "2,5 aceite")
        XCTAssertEqual(draft.name, "aceite")
        XCTAssertEqual(draft.quantity, "2.5")
    }

    func testQuickAddDraftCompactUnitSuffix() {
        // "aceite 500ml" → quantity "500ml", name "aceite"
        let vm = ShoppingListViewModel()
        let draft = vm.quickAddDraft(from: "aceite 500ml")
        XCTAssertEqual(draft.name, "aceite")
        XCTAssertEqual(draft.quantity, "500ml")
    }

    func testQuickAddDraftXPrefixCapitalCaseMultiplier() {
        let vm = ShoppingListViewModel()
        let draft = vm.quickAddDraft(from: "yogur X4")
        XCTAssertEqual(draft.name, "yogur")
        XCTAssertEqual(draft.quantity, "4")
    }

    func testQuickAddDraftLeadingQuantityWithUnit() {
        let vm = ShoppingListViewModel()
        let draft = vm.quickAddDraft(from: "1 kg harina")
        XCTAssertEqual(draft.name, "harina")
        XCTAssertEqual(draft.quantity, "1 kg")
    }

    func testQuickAddDraftNoQuantityMultiWordName() {
        let vm = ShoppingListViewModel()
        let draft = vm.quickAddDraft(from: "leche sin lactosa")
        XCTAssertEqual(draft.name, "leche sin lactosa")
        XCTAssertEqual(draft.quantity, "")
    }

    /// La barra rápida y el archivado tienen que leer el mismo string igual:
    /// «3 unidades coca cola» se guardaba bien y se cobraba como una sola.
    func testQuickAddQuantitiesAreUnderstoodByTheSameRuleThatChargesThem() {
        let vm = ShoppingListViewModel()
        XCTAssertEqual(vm.quickAddDraft(from: "3 unidades coca cola").quantity, "3 unidades")
        XCTAssertEqual(QuantitySemantics.unitCount(of: "3 unidades"), 3)
        XCTAssertEqual(vm.quickAddDraft(from: "2 u coca cola").quantity, "2 u")
        XCTAssertEqual(QuantitySemantics.unitCount(of: "2 u"), 2)
        XCTAssertEqual(vm.quickAddDraft(from: "tomates 1 kg").quantity, "1 kg")
        XCTAssertEqual(QuantitySemantics.unitCount(of: "1 kg"), 1)
        XCTAssertEqual(vm.quickAddDraft(from: "aceite 500ml").quantity, "500ml")
        XCTAssertEqual(QuantitySemantics.unitCount(of: "500ml"), 1)
    }

    // MARK: - Counts and summary

    func testItemCounts() {
        let vm = ShoppingListViewModel()
        let items = [
            ShoppingItem(name: "Tomates", isPurchased: false),
            ShoppingItem(name: "Leche", isPurchased: false),
            ShoppingItem(name: "Pan", isPurchased: true)
        ]
        let counts = vm.itemCounts(from: items)
        XCTAssertEqual(counts.pending, 2)
        XCTAssertEqual(counts.purchased, 1)
    }

    func testSummaryTracksSkippedAndUnavailableStates() {
        let vm = ShoppingListViewModel()
        let items = [
            ShoppingItem(name: "Leche", status: .pending),
            ShoppingItem(name: "Pan", status: .purchased),
            ShoppingItem(name: "Tomates", status: .skipped),
            ShoppingItem(name: "Cafe", status: .unavailable)
        ]
        let summary = vm.summary(from: items)
        XCTAssertEqual(summary.pendingCount, 1)
        XCTAssertEqual(summary.purchasedCount, 1)
        XCTAssertEqual(summary.skippedCount, 1)
        XCTAssertEqual(summary.unavailableCount, 1)
    }

    func testSummaryFiltersItemsBySelectedStore() {
        let vm = ShoppingListViewModel()
        vm.selectedStore = .jumbo
        let items = [
            ShoppingItem(name: "Tomates", status: .pending, store: .jumbo),
            ShoppingItem(name: "Leche", status: .pending, store: .lider),
            ShoppingItem(name: "Pan", status: .purchased, store: .jumbo)
        ]
        let summary = vm.summary(from: items)
        XCTAssertEqual(summary.pendingCount, 1)
        XCTAssertEqual(summary.purchasedCount, 1)
    }

    // MARK: - nextSortOrder

    func testNextSortOrder() {
        let vm = ShoppingListViewModel()
        let catFrutas = Category(name: "Frutas y verduras", sfSymbol: "leaf.fill", sortIndex: 0)
        let catLacteos = Category(name: "Lácteos y huevos", sfSymbol: "egg.fill", sortIndex: 1)
        let catDespensa = Category(name: "Despensa", sfSymbol: "archivebox", sortIndex: 2)
        let items = [
            ShoppingItem(name: "Tomates", category: catFrutas, sortOrder: 0),
            ShoppingItem(name: "Lechuga", category: catFrutas, sortOrder: 2),
            ShoppingItem(name: "Leche", category: catLacteos, sortOrder: 1)
        ]
        XCTAssertEqual(vm.nextSortOrder(for: catFrutas, in: items), 3)
        XCTAssertEqual(vm.nextSortOrder(for: catLacteos, in: items), 2)
        XCTAssertEqual(vm.nextSortOrder(for: catDespensa, in: items), 0)
    }

    // MARK: - groupedItems

    func testGroupedItemsStoreFilters() {
        let vm = ShoppingListViewModel()
        let items = [
            ShoppingItem(name: "Tomates Jumbo", store: .jumbo),
            ShoppingItem(name: "Manzanas Lider", store: .lider),
            ShoppingItem(name: "Leche Jumbo", store: .jumbo)
        ]
        let catVarios = Category(name: "Varios", sfSymbol: "bag.fill", sortIndex: 0)
        let categories = [catVarios]

        vm.selectedStore = nil
        let allGroups = vm.groupedItems(from: items, categories: categories)
        XCTAssertEqual(allGroups.flatMap(\.items).count, 3)

        vm.selectedStore = .jumbo
        let jumboGroups = vm.groupedItems(from: items, categories: categories)
        XCTAssertEqual(jumboGroups.flatMap(\.items).count, 2)
        XCTAssertTrue(jumboGroups.flatMap(\.items).allSatisfy { $0.store == .jumbo })

        vm.selectedStore = .lider
        let liderGroups = vm.groupedItems(from: items, categories: categories)
        XCTAssertEqual(liderGroups.flatMap(\.items).count, 1)
    }

    func testGroupedItemsAlphabeticalOrder() {
        let vm = ShoppingListViewModel()
        let cat = Category(name: "Varios", sfSymbol: "bag.fill", sortIndex: 0)
        let items = [
            ShoppingItem(name: "Zanahorias", category: cat),
            ShoppingItem(name: "Aceite", category: cat),
            ShoppingItem(name: "Manzanas", category: cat)
        ]
        let groups = vm.groupedItems(from: items, categories: [cat])
        let names = groups.first!.items.map(\.name)
        XCTAssertEqual(names, ["Aceite", "Manzanas", "Zanahorias"])
    }

    func testGroupedItemsHidesPurchasedWhenFlagOff() {
        let vm = ShoppingListViewModel()
        vm.showPurchased = false
        let cat = Category(name: "Varios", sfSymbol: "bag.fill", sortIndex: 0)
        let items = [
            ShoppingItem(name: "Pan", category: cat, status: .pending),
            ShoppingItem(name: "Leche", category: cat, status: .purchased)
        ]
        let groups = vm.groupedItems(from: items, categories: [cat])
        XCTAssertEqual(groups.flatMap(\.items).count, 1)
        XCTAssertEqual(groups.first?.items.first?.name, "Pan")
    }

    func testCategoryCanBeCollapsedAndExpanded() {
        UserDefaults.standard.removeObject(forKey: "collapsedCategoryNames")
        defer { UserDefaults.standard.removeObject(forKey: "collapsedCategoryNames") }

        let viewModel = ShoppingListViewModel()
        let category = Category(name: "Varios", sfSymbol: "bag.fill", sortIndex: 0)
        let item = ShoppingItem(name: "Pan", category: category)

        // Una lista de 1 producto queda por debajo del umbral de auto-colapso.
        viewModel.updateDerivedState(items: [item], categories: [category])
        XCTAssertFalse(viewModel.isCategoryCollapsed(category))

        viewModel.toggleCategoryCollapse(category)
        XCTAssertTrue(viewModel.isCategoryCollapsed(category))

        viewModel.toggleCategoryCollapse(category)
        XCTAssertFalse(viewModel.isCategoryCollapsed(category))
    }

    /// Colapsa explícitamente (en vez de depender del umbral de auto-colapso)
    /// para probar solo lo que le compete a este test: que una carga masiva
    /// posterior no reabre sola una categoría ya colapsada.
    func testBulkUpdatesDoNotAutoExpandCategories() {
        UserDefaults.standard.removeObject(forKey: "collapsedCategoryNames")
        defer { UserDefaults.standard.removeObject(forKey: "collapsedCategoryNames") }

        let viewModel = ShoppingListViewModel()
        let category = Category(name: "Varios", sfSymbol: "bag.fill", sortIndex: 0)
        let existingItem = ShoppingItem(name: "Pan", category: category)

        viewModel.updateDerivedState(items: [existingItem], categories: [category])
        viewModel.toggleCategoryCollapse(category)
        XCTAssertTrue(viewModel.isCategoryCollapsed(category))

        // Las cargas masivas (plantillas, importador, boleta) no expanden nada:
        // la expansión es explícita vía revealCategory en los adds individuales.
        let newItem = ShoppingItem(name: "Leche", category: category)
        viewModel.updateDerivedState(items: [existingItem, newItem], categories: [category])
        XCTAssertTrue(viewModel.isCategoryCollapsed(category))

        viewModel.revealCategory(category)
        XCTAssertFalse(viewModel.isCategoryCollapsed(category))
    }

    /// Por encima del umbral de auto-colapso, la primera carga sigue
    /// arrancando colapsada — el fixture real de la app (355+ productos)
    /// sigue viéndose igual que antes de introducir el umbral.
    func testLargeListsStillAutoCollapseOnFirstLoad() {
        UserDefaults.standard.removeObject(forKey: "collapsedCategoryNames")
        defer { UserDefaults.standard.removeObject(forKey: "collapsedCategoryNames") }

        let viewModel = ShoppingListViewModel()
        let category = Category(name: "Varios", sfSymbol: "bag.fill", sortIndex: 0)
        let manyItems = (1...45).map { ShoppingItem(name: "Producto \($0)", category: category) }

        viewModel.updateDerivedState(items: manyItems, categories: [category])
        XCTAssertTrue(viewModel.isCategoryCollapsed(category))
    }

    /// Por debajo del umbral, la primera carga deja todo expandido: importar
    /// unos pocos productos no debe parecer una pantalla vacía.
    func testSmallListsDoNotAutoCollapseOnFirstLoad() {
        UserDefaults.standard.removeObject(forKey: "collapsedCategoryNames")
        defer { UserDefaults.standard.removeObject(forKey: "collapsedCategoryNames") }

        let viewModel = ShoppingListViewModel()
        let category = Category(name: "Varios", sfSymbol: "bag.fill", sortIndex: 0)
        let fewItems = (1...6).map { ShoppingItem(name: "Producto \($0)", category: category) }

        viewModel.updateDerivedState(items: fewItems, categories: [category])
        XCTAssertFalse(viewModel.isCategoryCollapsed(category))
    }

    // MARK: - duplicateItem

    func testDuplicateItemNormalizesNameAndRespectsStore() {
        let vm = ShoppingListViewModel()
        let items = [
            ShoppingItem(name: "Leche sin lactosa", store: .jumbo),
            ShoppingItem(name: "Leche sin lactosa", store: .lider)
        ]
        XCTAssertEqual(vm.duplicateItem(named: " leche SIN lactosa ", store: .jumbo, in: items)?.store, .jumbo)
        XCTAssertEqual(vm.duplicateItem(named: "Leche sin lactosa", store: .lider, in: items)?.store, .lider)
        XCTAssertNil(vm.duplicateItem(named: "Pan", store: .jumbo, in: items))
    }

    func testDuplicateItemExcludesSpecifiedID() {
        let vm = ShoppingListViewModel()
        let item = ShoppingItem(name: "Leche", store: .jumbo)
        let items = [item]
        XCTAssertNil(vm.duplicateItem(named: "Leche", store: .jumbo, in: items, excluding: item.id))
    }

    func testProductNameNormalizerAndDuplicatePolicyHandleSpacesAndTildes() {
        let item = ShoppingItem(name: "  Café molido  ", store: .jumbo)
        XCTAssertEqual(ProductNameNormalizer.normalize("Café molido"), "cafe molido")
        XCTAssertTrue(DuplicatePolicy.isDuplicate(named: "CAFE   MOLIDO", store: .jumbo, in: [item]))
        XCTAssertFalse(DuplicatePolicy.isDuplicate(named: "CAFE MOLIDO", store: .lider, in: [item]))
    }

    func testCSVSerializerEscapesRFC4180ValuesAndFormulaPrefixes() {
        let csv = CSVSerializer.document(rows: [["=SUM(A1:A2)", "A\"B", "Primera\nsegunda"]])
        XCTAssertEqual(csv, "\"'=SUM(A1:A2)\",\"A\"\"B\",\"Primera\nsegunda\"\r\n")
    }

    func testAppRouteAcceptsOnlyPublicListRoute() {
        XCTAssertEqual(AppRoute(url: URL(string: "casilisto://list")!), .list)
        XCTAssertEqual(AppRoute(url: URL(string: "casilisto://list/")!), .list)
        XCTAssertNil(AppRoute(url: URL(string: "casilisto://unsupported")!))
        XCTAssertNil(AppRoute(url: URL(string: "casilisto://list?screen=settings")!))
        XCTAssertNil(AppRoute(url: URL(string: "https://casilisto.example/list")!))
    }

    func testPublicSchemaBaselineContainsCurrentPersistentModels() {
        XCTAssertEqual(CasiListoSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
        XCTAssertEqual(CasiListoMigrationPlan.schemas.count, 1)
        XCTAssertTrue(CasiListoSchemaV1.models.contains { $0 == ShoppingItem.self })
    }

    // MARK: - Ventana de gracia al ocultar comprados

    func testGracePeriodKeepsJustPurchasedItemVisibleThenHides() async throws {
        let vm = ShoppingListViewModel()
        vm.graceDuration = .milliseconds(80)
        vm.showPurchased = false

        let category = Category(name: "Bebidas", sfSymbol: "cup.and.saucer.fill", sortIndex: 0)
        let item = ShoppingItem(name: "Cerveza", category: category)
        vm.updateDerivedState(items: [item], categories: [category])

        vm.togglePurchased(item)

        // Recién marcado: visible durante la ventana de gracia.
        XCTAssertTrue(vm.derivedGroups.contains { group in
            group.items.contains { $0.id == item.id }
        })

        try await Task.sleep(for: .milliseconds(400))

        // Expirada la ventana: oculto.
        XCTAssertFalse(vm.derivedGroups.contains { group in
            group.items.contains { $0.id == item.id }
        })
    }

    func testGracePeriodCancelsWhenUnmarkedDuringWindow() async throws {
        let vm = ShoppingListViewModel()
        vm.graceDuration = .milliseconds(80)
        vm.showPurchased = false

        let category = Category(name: "Bebidas", sfSymbol: "cup.and.saucer.fill", sortIndex: 0)
        let item = ShoppingItem(name: "Cerveza", category: category)
        vm.updateDerivedState(items: [item], categories: [category])

        vm.togglePurchased(item)
        vm.togglePurchased(item)

        try await Task.sleep(for: .milliseconds(400))

        // Se desmarcó dentro de la ventana: sigue visible como pendiente.
        XCTAssertEqual(item.status, .pending)
        XCTAssertTrue(vm.derivedGroups.contains { group in
            group.items.contains { $0.id == item.id }
        })
    }

    // MARK: - Persistencia del colapso de categorías

    func testCollapseStatePersistsAcrossViewModelInstances() {
        UserDefaults.standard.removeObject(forKey: "collapsedCategoryNames")
        defer { UserDefaults.standard.removeObject(forKey: "collapsedCategoryNames") }

        let category = Category(name: "Bebidas", sfSymbol: "cup.and.saucer.fill", sortIndex: 0)
        let item = ShoppingItem(name: "Cerveza", category: category)

        let first = ShoppingListViewModel()
        first.updateDerivedState(items: [item], categories: [category])
        XCTAssertFalse(first.isCategoryCollapsed(category), "Una lista pequeña no se colapsa en la primera carga")

        first.toggleCategoryCollapse(category)
        XCTAssertTrue(first.isCategoryCollapsed(category))

        let second = ShoppingListViewModel()
        second.updateDerivedState(items: [item], categories: [category])
        XCTAssertTrue(second.isCategoryCollapsed(category), "El estado colapsado sobrevive al relanzamiento")
    }

    func testRevealCategoryExpandsAndPersists() {
        UserDefaults.standard.removeObject(forKey: "collapsedCategoryNames")
        defer { UserDefaults.standard.removeObject(forKey: "collapsedCategoryNames") }

        let category = Category(name: "Bebidas", sfSymbol: "cup.and.saucer.fill", sortIndex: 0)
        let item = ShoppingItem(name: "Cerveza", category: category)

        let vm = ShoppingListViewModel()
        vm.updateDerivedState(items: [item], categories: [category])
        // Colapsada explícitamente: con una sola categoría por debajo del
        // umbral de auto-colapso, la primera carga ya no la deja colapsada.
        vm.toggleCategoryCollapse(category)
        XCTAssertTrue(vm.isCategoryCollapsed(category))

        vm.revealCategory(category)

        XCTAssertFalse(vm.isCategoryCollapsed(category))
        let stored = UserDefaults.standard.stringArray(forKey: "collapsedCategoryNames") ?? []
        XCTAssertFalse(stored.contains("Bebidas"))
    }

    /// Renombrar una categoría colapsada no debe dejarla huérfana: el nombre
    /// nuevo tiene que heredar el estado colapsado del nombre viejo, tanto en
    /// la clave por lista como en la global.
    func testRenameCollapsedCategoryMigratesEveryStoredKey() throws {
        let suiteName = "test.renameCollapsed.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        suite.set(["Bebidas", "Carnes"], forKey: "collapsedCategoryNames")
        suite.set(["Bebidas"], forKey: "collapsedCategoryNames-\(UUID().uuidString)")

        ShoppingListViewModel.renameCollapsedCategory(from: "Bebidas", to: "Líquidos", in: suite)

        XCTAssertEqual(Set(suite.stringArray(forKey: "collapsedCategoryNames") ?? []), ["Líquidos", "Carnes"])
        let perListKey = try XCTUnwrap(suite.dictionaryRepresentation().keys.first { $0.hasPrefix("collapsedCategoryNames-") })
        XCTAssertEqual(suite.stringArray(forKey: perListKey), ["Líquidos"])
    }

    func testRenameCollapsedCategoryMigratesTheCatalogKey() throws {
        let suiteName = "test.renameCollapsedCatalog.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        suite.set(["Bebidas", "Varios"], forKey: "catalogCollapsedCategoryNames")
        CatalogView.renameCollapsedCategory(from: "Bebidas", to: "Líquidos", in: suite)

        XCTAssertEqual(Set(suite.stringArray(forKey: "catalogCollapsedCategoryNames") ?? []), ["Líquidos", "Varios"])
    }

    // MARK: - CatalogService

    func testCatalogAddToActiveListCreatesItemAndCountsUsage() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let category = Category(name: "Bebidas", sfSymbol: "cup.and.saucer.fill", sortIndex: 0)
        let activeList = ShoppingList(title: "Compra actual")
        let catalogItem = ProductCatalogItem(name: "Cerveza", category: category, store: .jumbo)
        context.insert(category)
        context.insert(activeList)
        context.insert(catalogItem)

        let created = try CatalogService.addToActiveList(
            catalogItem,
            activeList: activeList,
            activeItems: [],
            context: context
        )

        XCTAssertEqual(created?.name, "Cerveza")
        XCTAssertEqual(created?.listID, activeList.id)
        XCTAssertEqual(created?.store, .jumbo)
        XCTAssertEqual(catalogItem.timesAdded, 1)
        XCTAssertNotNil(catalogItem.lastAddedAt)

        // Añadir de nuevo con el equivalente ya en la lista es un no-op.
        let again = try CatalogService.addToActiveList(
            catalogItem,
            activeList: activeList,
            activeItems: [created!],
            context: context
        )
        XCTAssertNil(again)
        XCTAssertEqual(catalogItem.timesAdded, 1)
    }

    /// En instalación limpia no existe ninguna lista y el Catálogo igual muestra
    /// sus 355 productos con un «+». Sin lista destino, cada toque insertaba un
    /// producto con `listID == nil`: invisible en todas las pantallas y en el
    /// widget, y sin quedar registrado en `activeItems`, así que el control de
    /// duplicados tampoco lo veía y admitía copias infinitas.
    func testCatalogAddWithoutActiveListDoesNotCreateOrphans() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let category = Category(name: "Bebidas", sfSymbol: "cup.and.saucer.fill", sortIndex: 0)
        let catalogItem = ProductCatalogItem(name: "Cerveza", category: category, store: .jumbo)
        context.insert(category)
        context.insert(catalogItem)

        for _ in 0..<3 {
            XCTAssertThrowsError(
                try CatalogService.addToActiveList(
                    catalogItem,
                    activeList: nil,
                    activeItems: [],
                    context: context
                ),
                "Sin lista activa el servicio debe negarse, no crear un huérfano"
            )
        }

        let orphans = try context.fetch(FetchDescriptor<ShoppingItem>())
        XCTAssertTrue(orphans.isEmpty, "Se crearon \(orphans.count) productos sin lista")
    }

    /// El sembrado corría en cada aparición de la vista y sin deduplicar: creaba
    /// 363 filas para 355 nombres —con la categoría ganadora variando entre
    /// instalaciones, porque itera un diccionario— y resucitaba lo que la
    /// persona había borrado a mano.
    func testCatalogSeedingIsIdempotentAndRespectsDeletions() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        try CategoryBootstrapService.bootstrap(context: context)

        // Suite propia: el esquema corre los tests en paralelo y este toca la
        // marca de «catálogo ya sembrado».
        let suiteName = "test.catalog.seeding.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        try SuggestedProducts.seedCatalogItems(in: context, defaults: defaults)
        let seeded = try context.fetch(FetchDescriptor<ProductCatalogItem>())
        let normalized = seeded.map { ProductNameNormalizer.normalize($0.name) }
        XCTAssertEqual(
            normalized.count,
            Set(normalized).count,
            "El catálogo sembrado trae nombres repetidos: " +
            "\(Dictionary(grouping: normalized, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted())"
        )

        guard let victim = seeded.first(where: { $0.name == "Doritos" }) else {
            return XCTFail("El fixture ya no incluye «Doritos»")
        }
        context.delete(victim)
        try context.save()

        // Segundo arranque de la app.
        try SuggestedProducts.seedCatalogItems(in: context, defaults: defaults)

        let afterRelaunch = try context.fetch(FetchDescriptor<ProductCatalogItem>())
        XCTAssertFalse(
            afterRelaunch.contains { $0.name == "Doritos" },
            "Un producto borrado por la persona volvió al relanzar"
        )
    }

    /// Reproduce una instalación de una versión anterior a la protección
    /// dentro del bucle: `existingNames` se calculaba una sola vez, fuera del
    /// bucle, así que los siete productos que aparecen en dos categorías
    /// (guisantes, albahaca, calamares...) se insertaban dos veces. El
    /// sembrado de hoy ya no lo hace, pero no repara lo que una instalación
    /// anterior dejó duplicado. `deduplicateCatalogItems` sí lo hace.
    func testSeedingDeduplicatesExistingCatalogEntries() throws {
        func seedLikeOldBuild(in context: ModelContext) throws {
            let existingCatalog = try context.fetch(FetchDescriptor<ProductCatalogItem>())
            let existingNames = Set(existingCatalog.map { ProductNameNormalizer.normalize($0.name) })
            let categories = try context.fetch(FetchDescriptor<CasiListo.Category>())
            for (defaultCat, products) in SuggestedProducts.byCategory {
                let realCategory = categories.first { $0.name == defaultCat.rawValue }
                for productName in products where !existingNames.contains(ProductNameNormalizer.normalize(productName)) {
                    context.insert(ProductCatalogItem(
                        name: productName,
                        category: realCategory,
                        store: SuggestedProducts.suggestedStore(for: productName)
                    ))
                }
            }
            try context.save()
        }

        let container = try makeInMemoryContainer()
        let context = container.mainContext
        try CategoryBootstrapService.bootstrap(context: context)

        let suiteName = "test.catalog.dedup.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removeSuite(named: suiteName) }

        // Instalación anterior: al menos un nombre queda repetido.
        try seedLikeOldBuild(in: context)
        let beforeNorm = try context.fetch(FetchDescriptor<ProductCatalogItem>()).map { ProductNameNormalizer.normalize($0.name) }
        let dupsBefore = Dictionary(grouping: beforeNorm, by: { $0 }).filter { $0.value.count > 1 }
        XCTAssertFalse(dupsBefore.isEmpty, "El fixture de sembrado antiguo debería producir al menos un duplicado")

        // Se instala la versión con el fix encima.
        try SuggestedProducts.seedCatalogItems(in: context, defaults: defaults)
        try SuggestedProducts.deduplicateCatalogItems(in: context, defaults: defaults)

        let afterNorm = try context.fetch(FetchDescriptor<ProductCatalogItem>()).map { ProductNameNormalizer.normalize($0.name) }
        let dupsAfter = Dictionary(grouping: afterNorm, by: { $0 }).filter { $0.value.count > 1 }
        XCTAssertTrue(dupsAfter.isEmpty, "Quedaron duplicados sin limpiar: \(dupsAfter.keys.sorted())")
        XCTAssertEqual(afterNorm.count, Set(afterNorm).count)

        // Arranques posteriores no vuelven a barrer nada (la clave lo apaga).
        try SuggestedProducts.deduplicateCatalogItems(in: context, defaults: defaults)
        let final = try context.fetch(FetchDescriptor<ProductCatalogItem>())
        XCTAssertEqual(final.count, afterNorm.count)
    }

    func testCatalogAddUsesNextSortOrderWithinCategory() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let category = Category(name: "Bebidas", sfSymbol: "cup.and.saucer.fill", sortIndex: 0)
        let activeList = ShoppingList(title: "Compra actual")
        let existing = ShoppingItem(name: "Jugo", listID: activeList.id, category: category, sortOrder: 5)
        let catalogItem = ProductCatalogItem(name: "Cerveza", category: category, store: .jumbo)
        context.insert(category)
        context.insert(activeList)
        context.insert(existing)
        context.insert(catalogItem)

        let created = try CatalogService.addToActiveList(
            catalogItem,
            activeList: activeList,
            activeItems: [existing],
            context: context
        )

        XCTAssertEqual(created?.sortOrder, 6)
    }

    func testCatalogRemoveFromActiveListDeletesPendingMatch() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let category = Category(name: "Bebidas", sfSymbol: "cup.and.saucer.fill", sortIndex: 0)
        let activeList = ShoppingList(title: "Compra actual")
        let pending = ShoppingItem(name: "Cerveza", listID: activeList.id, category: category, store: .jumbo)
        let catalogItem = ProductCatalogItem(name: "cerveza", category: category, store: .jumbo)
        context.insert(category)
        context.insert(activeList)
        context.insert(pending)
        context.insert(catalogItem)

        try CatalogService.removeFromActiveList(
            catalogItem,
            activeList: activeList,
            activeItems: [pending],
            context: context
        )

        let remaining = try context.fetch(FetchDescriptor<ShoppingItem>())
        XCTAssertTrue(remaining.isEmpty)
    }

    func testCatalogSuggestionsOrderByUsageThenName() {
        let occasional = ProductCatalogItem(name: "Cerveza artesanal", timesAdded: 1)
        let frequent = ProductCatalogItem(name: "Cerveza", timesAdded: 5)
        let unrelated = ProductCatalogItem(name: "Pan", timesAdded: 9)

        let names = CatalogService.suggestions(for: "cerv", in: [occasional, unrelated, frequent])

        XCTAssertEqual(names, ["Cerveza", "Cerveza artesanal"])
    }

    func testCatalogRecordAdditionUpsertsByNormalizedName() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let category = Category(name: "Bebidas", sfSymbol: "cup.and.saucer.fill", sortIndex: 0)
        context.insert(category)

        CatalogService.recordAddition(name: "Café Molido", category: category, store: .jumbo, context: context)
        CatalogService.recordAddition(name: "  cafe molido ", category: category, store: .lider, context: context)

        let entries = try context.fetch(FetchDescriptor<ProductCatalogItem>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.timesAdded, 2)
    }

    // MARK: - Archivado y ciclo de vida de lista

    func testArchivePurchasedItemsCreatesCompletedList() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let activeList = ShoppingList(title: "Compra actual")
        let purchased = ShoppingItem(name: "Pan", listID: activeList.id, status: .purchased)
        let pending = ShoppingItem(name: "Leche", listID: activeList.id, status: .pending)
        context.insert(activeList)
        context.insert(purchased)
        context.insert(pending)

        try ShoppingListLifecycleService.archivePurchasedItems(
            from: [purchased, pending],
            activeList: activeList,
            context: context
        )

        let lists = try context.fetch(FetchDescriptor<ShoppingList>())
        let completed = lists.first { $0.status == .completed }
        XCTAssertNotNil(completed)
        XCTAssertEqual(completed?.purchasedCount, 1)
        XCTAssertEqual(purchased.listID, completed?.id)
        XCTAssertEqual(pending.listID, activeList.id)
    }

    func testArchivePurchasedItemsCountersExcludeSkippedAndUnavailable() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let activeList = ShoppingList(title: "Compra actual")
        let p1 = ShoppingItem(name: "Tomates", listID: activeList.id, status: .purchased)
        let p2 = ShoppingItem(name: "Manzanas", listID: activeList.id, status: .purchased)
        let pending = ShoppingItem(name: "Leche", listID: activeList.id, status: .pending)
        let skipped = ShoppingItem(name: "Pan", listID: activeList.id, status: .skipped)
        let unavailable = ShoppingItem(name: "Jugo", listID: activeList.id, status: .unavailable)

        context.insert(activeList)
        [p1, p2, pending, skipped, unavailable].forEach { context.insert($0) }

        try ShoppingListLifecycleService.archivePurchasedItems(
            from: [p1, p2, pending, skipped, unavailable],
            activeList: activeList,
            context: context
        )

        let lists = try context.fetch(FetchDescriptor<ShoppingList>())
        let completed = lists.first { $0.status == .completed }
        XCTAssertNotNil(completed)
        XCTAssertEqual(completed?.purchasedCount, 2)
        XCTAssertEqual(completed?.pendingCount, 0)
        XCTAssertEqual(completed?.skippedCount, 0)
        XCTAssertEqual(completed?.unavailableCount, 0)
    }

    /// `price` es unitario: sumarlo sin la cantidad, como hacía este servicio
    /// antes de unificar `QuantitySemantics`, archivaba "3 panes a $1.500"
    /// como $1.500 en cuanto la compra se cerraba sin boleta — ni siquiera un
    /// entero desnudo multiplicaba aquí.
    func testClosingAListWithoutReceiptChargesEveryUnit() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let activeList = ShoppingList(title: "Compra actual")
        let purchased = ShoppingItem(
            name: "Coca Cola",
            listID: activeList.id,
            quantity: "3 unidades",
            status: .purchased,
            price: 1_500,
            store: .jumbo
        )
        context.insert(activeList)
        context.insert(purchased)

        try ShoppingListLifecycleService.archivePurchasedItems(
            from: [purchased],
            activeList: activeList,
            context: context
        )

        let lists = try context.fetch(FetchDescriptor<ShoppingList>())
        let completed = lists.first { $0.status == .completed }
        XCTAssertEqual(completed?.totalSpent, 4_500)
    }

    /// El total en vivo de la lista activa tenía el mismo bug que su archivado.
    func testActiveListRunningTotalChargesEveryUnit() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let activeList = ShoppingList(title: "Compra actual")
        let item = ShoppingItem(
            name: "Coca Cola",
            listID: activeList.id,
            quantity: "3 unidades",
            status: .purchased,
            price: 1_500,
            store: .jumbo
        )
        context.insert(activeList)
        context.insert(item)

        ShoppingListLifecycleService.updateActiveListCounters(activeList, items: [item])

        XCTAssertEqual(activeList.totalSpent, 4_500)
    }

    // MARK: - Category.isEditable

    /// "Varios" no se puede renombrar: hacerlo dejaba al bootstrap sin
    /// "Varios" que encontrar y creaba uno nuevo y vacío en el arranque
    /// siguiente, duplicándola.
    func testVariosCategoryIsNotEditable() {
        let varios = Category(name: "Varios", sfSymbol: "bag.fill", sortIndex: 999, isSystem: true)
        let otra = Category(name: "Bebidas", sfSymbol: "cup.and.saucer.fill", sortIndex: 0, isSystem: true)
        let personalizada = Category(name: "Mascotas", sfSymbol: "pawprint.fill", sortIndex: 10, isSystem: false)

        XCTAssertFalse(Category.isEditable(varios))
        XCTAssertTrue(Category.isEditable(otra))
        XCTAssertTrue(Category.isEditable(personalizada))
    }

    // MARK: - CategoryBootstrapService — reconciliación de sfSymbols

    func testBootstrapReconcilesSfSymbolsForExistingCategories() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        // Sembrar categoría con sfSymbol incorrecto
        let stale = Category(name: DefaultCategory.condimentos.rawValue, sfSymbol: "wrong.symbol", sortIndex: 0)
        let varios = Category(name: "Varios", sfSymbol: "bag.fill", sortIndex: 999)
        context.insert(stale)
        context.insert(varios)
        try context.save()

        try CategoryBootstrapService.bootstrap(context: context)

        let catDescriptor = FetchDescriptor<CasiListo.Category>()
        let fetched = try context.fetch(catDescriptor)
        let reconciled = fetched.first { $0.name == DefaultCategory.condimentos.rawValue }
        XCTAssertEqual(reconciled?.sfSymbol, DefaultCategory.condimentos.sfSymbol)
    }

    func testBootstrapCreatesDefaultCategoriesOnEmptyDB() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        try CategoryBootstrapService.bootstrap(context: context)

        let catDescriptor2 = FetchDescriptor<CasiListo.Category>()
        let categories = try context.fetch(catDescriptor2)
        XCTAssertEqual(categories.count, DefaultCategory.allCases.count)
    }

    // MARK: - CategoryIconMapper

    func testCategoryIconMapper() {
        XCTAssertEqual(CategoryIconMapper.suggestSymbol(for: "cerveza mistral"), "wineglass.fill")
        XCTAssertEqual(CategoryIconMapper.suggestSymbol(for: "Coca cola zero"), "cup.and.saucer.fill")
        XCTAssertEqual(CategoryIconMapper.suggestSymbol(for: "pechuga de pollo"), "fork.knife")
        XCTAssertEqual(CategoryIconMapper.suggestSymbol(for: "filete de salmon"), "fish.fill")
        XCTAssertEqual(CategoryIconMapper.suggestSymbol(for: "pan marraqueta"), "birthday.cake.fill")
        XCTAssertEqual(CategoryIconMapper.suggestSymbol(for: "manzanas rojas"), "leaf.fill")
        XCTAssertEqual(CategoryIconMapper.suggestSymbol(for: "detergente liquido"), "house.fill")
        XCTAssertEqual(CategoryIconMapper.suggestSymbol(for: "comida para gatos"), "pawprint.fill")
        XCTAssertEqual(CategoryIconMapper.suggestSymbol(for: "caja de clavos"), "tag.fill")
    }

    // MARK: - Undo delete functionality

    func testUndoDeleteRestoresItem() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let vm = ShoppingListViewModel()
        let item = ShoppingItem(name: "Manzanas", quantity: "1 kg", store: .jumbo)
        context.insert(item)
        try context.save()

        vm.deleteItem(item, context: context)
        XCTAssertTrue(vm.showUndoToast)
        XCTAssertNotNil(vm.deletedItemUndoBuffer)

        vm.undoLastDelete(context: context)
        XCTAssertFalse(vm.showUndoToast)
        XCTAssertNil(vm.deletedItemUndoBuffer)

        let items = try context.fetch(FetchDescriptor<ShoppingItem>())
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.name, "Manzanas")
    }

    func testSecondDeleteReplacesTheSingleUndoBuffer() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let first = ShoppingItem(name: "Pan")
        let second = ShoppingItem(name: "Leche")
        context.insert(first)
        context.insert(second)
        try context.save()

        let viewModel = ShoppingListViewModel()
        viewModel.updateDerivedState(items: [first, second], categories: [])
        viewModel.deleteItem(first, context: context)
        viewModel.deleteItem(second, context: context)

        XCTAssertEqual(viewModel.deletedItemUndoBuffer?.name, "Leche")
        viewModel.undoLastDelete(context: context)
        let remaining = try context.fetch(FetchDescriptor<ShoppingItem>())
        XCTAssertEqual(remaining.map(\.name).sorted(), ["Leche"])
    }

    func testListFilteringPerformanceAtReleaseDataVolumes() {
        let category = Category(name: "Varios", sfSymbol: "bag.fill", sortIndex: 0)
        let dataSets = [1_000, 5_000, 10_000].map { count in
            (0..<count).map { index in
                ShoppingItem(
                    name: "Producto \(index)",
                    category: category,
                    status: index.isMultiple(of: 4) ? .purchased : .pending,
                    store: index.isMultiple(of: 2) ? .jumbo : .lider
                )
            }
        }
        let viewModel = ShoppingListViewModel()

        measure(metrics: [XCTClockMetric()]) {
            for items in dataSets {
                viewModel.searchText = "producto"
                viewModel.updateDerivedState(items: items, categories: [category])
                _ = viewModel.derivedGroups
            }
        }
    }

    func testFileStoreFailureIsSurfacedDuringStartupCleanup() throws {
        let container = try makeInMemoryContainer()
        let coordinator = ShoppingPersistenceCoordinator(context: container.mainContext, fileStore: FailingFileStore())
        XCTAssertThrowsError(try coordinator.cleanUnreferencedFiles())
    }

    // MARK: - Price formatting (Double extension — field still in SwiftData model)

    func testPriceFormattingExtensions() {
        let whole: Double = 1500.0
        let decimal: Double = 3.50

        let formattedWhole = whole.formattedPrice.replacingOccurrences(of: "\u{00a0}", with: " ")
        XCTAssertTrue(
            formattedWhole == "1.500" || formattedWhole == "1,500" || formattedWhole == "1500",
            "Unexpected: \(formattedWhole)"
        )

        let formattedDecimal = decimal.formattedPrice.replacingOccurrences(of: "\u{00a0}", with: " ")
        XCTAssertTrue(
            formattedDecimal == "3,5" || formattedDecimal == "3.5",
            "Unexpected: \(formattedDecimal)"
        )
    }

    /// Editar un producto y volver a guardarlo no puede cambiarle el precio.
    /// El campo se rellenaba con el formato de presentación —«1.500», con
    /// separador de miles— y se releía con `Double(_:)`, que lee ese punto como
    /// decimal: cualquier precio de $1.000 o más perdía tres ceros en silencio.
    func testPriceSurvivesAnEditRoundTrip() {
        for original in [999.0, 1_500.0, 2_990.0, 12_990.0, 199_990.0] {
            let shown = PriceField.text(for: original)
            XCTAssertEqual(
                PriceField.value(from: shown),
                original,
                "El campo mostró «\(shown)» y se releyó como otro número"
            )
        }

        // Un campo vacío limpia el precio; el cero también, porque un producto
        // que costó $0 no es un dato que valga la pena guardar.
        XCTAssertNil(PriceField.value(from: ""))
        XCTAssertEqual(PriceField.text(for: nil), "")
    }

    /// Pegar una lista numerada desde WhatsApp es el caso de uso central del
    /// importador. La expresión era una clase de caracteres, no una alternancia:
    /// borraba un único carácter, así que «1. Leche» entraba como «. Leche».
    func testPastedListStripsBulletsAndNumbering() {
        let cases = [
            ("- Leche", "Leche"),
            ("* Pan", "Pan"),
            ("• Huevos", "Huevos"),
            ("1. Leche", "Leche"),
            ("10. Pan", "Pan"),
            ("2) Queso", "Queso"),
            ("Tomates", "Tomates")
        ]

        for (raw, expected) in cases {
            XCTAssertEqual(PastedListParser.stripBullet(raw), expected, "Entrada: «\(raw)»")
        }
    }

    /// Los productos sin categoría propia comparten la sección «Varios». Agrupar
    /// por identidad de objeto los partía en una sección por producto, porque
    /// `Category.fallback` devuelve una instancia nueva en cada acceso.
    func testHistoryGroupsUncategorizedItemsTogether() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let varios = Category(name: "Varios", sfSymbol: "bag.fill", sortIndex: 999, isSystem: true)
        context.insert(varios)

        let listID = UUID()
        let items = ["Cosa A", "Cosa B", "Cosa C"].map {
            ShoppingItem(name: $0, listID: listID, category: varios)
        }
        items.forEach { context.insert($0) }
        try context.save()

        let groups = PurchasedItemGrouping.byCategory(items)

        XCTAssertEqual(groups.count, 1, "«Varios» se partió en \(groups.count) secciones")
        XCTAssertEqual(groups.first?.items.count, 3)

        // El `ForEach` del historial usa el nombre como id: si se repite, SwiftUI
        // entra en comportamiento indefinido.
        let ids = groups.map(\.category.rawValue)
        XCTAssertEqual(ids.count, Set(ids).count, "Ids repetidos en el ForEach: \(ids)")
    }

    // MARK: - List Customization & Appearance Catalog

    func testShoppingListAppearanceDefaultsAndCustomization() {
        let defaultList = ShoppingList(title: "Compra actual")
        XCTAssertEqual(defaultList.iconName, "cart.fill")
        XCTAssertEqual(defaultList.colorHex, "F5C518")

        let customList = ShoppingList(
            title: "Asado",
            iconName: "flame.fill",
            colorHex: "FF5722"
        )
        XCTAssertEqual(customList.iconName, "flame.fill")
        XCTAssertEqual(customList.colorHex, "FF5722")

        customList.iconName = "party.popper.fill"
        customList.colorHex = "E91E63"
        XCTAssertEqual(customList.iconName, "party.popper.fill")
        XCTAssertEqual(customList.colorHex, "E91E63")
    }

    func testListAppearanceCatalogSuggestions() {
        let (asadoIcon, asadoColor) = ListAppearanceCatalog.suggestAppearance(for: "Asado familiar")
        XCTAssertEqual(asadoIcon, "flame.fill")
        XCTAssertEqual(asadoColor, "FF5722")

        let (farmaciaIcon, farmaciaColor) = ListAppearanceCatalog.suggestAppearance(for: "Farmacia Cruz Verde")
        XCTAssertEqual(farmaciaIcon, "pills.fill")
        XCTAssertEqual(farmaciaColor, "00BCD4")

        let (cumpleIcon, _) = ListAppearanceCatalog.suggestAppearance(for: "Cumpleaños")
        XCTAssertEqual(cumpleIcon, "party.popper.fill")

        let (feriaIcon, feriaColor) = ListAppearanceCatalog.suggestAppearance(for: "Feria de verduras")
        XCTAssertEqual(feriaIcon, "leaf.fill")
        XCTAssertEqual(feriaColor, "4CAF50")

        let (toolsIcon, _) = ListAppearanceCatalog.suggestAppearance(for: "Ferretería y taller")
        XCTAssertEqual(toolsIcon, "wrench.and.screwdriver.fill")
    }

    func testShoppingListLifecycleServiceCreateActiveListWithCustomAppearance() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let list = try ShoppingListLifecycleService.createActiveList(
            in: context,
            title: "Feria de Verduras",
            iconName: "leaf.fill",
            colorHex: "4CAF50"
        )

        XCTAssertEqual(list.title, "Feria de Verduras")
        XCTAssertEqual(list.iconName, "leaf.fill")
        XCTAssertEqual(list.colorHex, "4CAF50")
        XCTAssertEqual(list.status, .active)
    }

    func testMultiListItemsIsolation() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let listA = try ShoppingListLifecycleService.createActiveList(in: context, title: "Supermercado")
        let listB = try ShoppingListLifecycleService.createActiveList(in: context, title: "Feria", iconName: "leaf.fill", colorHex: "4CAF50")

        let itemA1 = ShoppingItem(name: "Leche", listID: listA.id)
        let itemA2 = ShoppingItem(name: "Pan", listID: listA.id)
        let itemB1 = ShoppingItem(name: "Tomates", listID: listB.id)

        [itemA1, itemA2, itemB1].forEach { context.insert($0) }
        try context.save()

        let allItems = try context.fetch(FetchDescriptor<ShoppingItem>())
        let itemsListA = allItems.filter { $0.listID == listA.id }
        let itemsListB = allItems.filter { $0.listID == listB.id }

        XCTAssertEqual(itemsListA.count, 2)
        XCTAssertEqual(itemsListB.count, 1)
        XCTAssertEqual(itemsListB.first?.name, "Tomates")
    }

    /// Un SF Symbol inexistente no falla: simplemente no dibuja nada y deja el
    /// badge vacío, que es exactamente como se ve un problema de contraste.
    @MainActor
    func testEverySFSymbolInTheAppExists() {
        for category in DefaultCategory.allCases {
            XCTAssertNotNil(
                UIImage(systemName: category.sfSymbol),
                "Categoría \(category.rawValue) usa «\(category.sfSymbol)», que no existe"
            )
        }

        for symbol in ListAppearanceCatalog.allSymbols {
            XCTAssertNotNil(
                UIImage(systemName: symbol),
                "El catálogo de iconos de lista ofrece «\(symbol)», que no existe"
            )
        }

        for store in Store.allCases {
            XCTAssertNotNil(
                UIImage(systemName: store.sfSymbol),
                "\(store.displayName) usa «\(store.sfSymbol)», que no existe"
            )
        }
    }

    // MARK: - Contraste (WCAG 2.2 AA)

    /// El icono del badge se pinta con el color de la categoría sobre ese mismo
    /// color al 14%. Con los colores crudos, ocho de quince categorías quedaban
    /// bajo 3:1 y «Lácteos y huevos» en 1.6:1 — invisible.
    @MainActor
    func testCategoryIconsMeetContrastOverTheirBadge() {
        let surfaces = [("claro", "FFFFFF"), ("oscuro", "2A2928")]

        for category in DefaultCategory.allCases {
            let accent = UIColor(Category.accentColor(forName: category.rawValue))
            let icon = UIColor(Category.iconColor(forName: category.rawValue))

            for (name, surfaceHex) in surfaces {
                let trait = UITraitCollection(
                    userInterfaceStyle: name == "claro" ? .light : .dark
                )
                let badge = accent
                    .resolvedColor(with: trait)
                    .blended(alpha: Category.badgeBackgroundOpacity, over: UIColor(hex: surfaceHex))
                let ratio = Theme.contrastRatio(icon.resolvedColor(with: trait), badge)

                XCTAssertGreaterThanOrEqual(
                    ratio, 3.0,
                    "\(category.rawValue) en modo \(name): \(String(format: "%.2f", ratio)):1"
                )
            }
        }
    }

    /// El amarillo de marca sirve para rellenar, no para escribir.
    @MainActor
    func testAccentTokensMeetContrastOnLightSurfaces() {
        let light = UITraitCollection(userInterfaceStyle: .light)
        let cream = UIColor(hex: "F5F1EB")

        for (name, surface) in [("crema", cream), ("tarjeta", UIColor(hex: "FFFFFF"))] {
            let ratio = Theme.contrastRatio(
                UIColor(Theme.accentInteractive).resolvedColor(with: light),
                surface
            )
            XCTAssertGreaterThanOrEqual(
                ratio, 4.5,
                "accentInteractive sobre \(name): \(String(format: "%.2f", ratio)):1"
            )
        }

        let labelOnFill = Theme.contrastRatio(
            UIColor(Theme.onAccent).resolvedColor(with: light),
            UIColor(Theme.accentYellow).resolvedColor(with: light)
        )
        XCTAssertGreaterThanOrEqual(labelOnFill, 4.5, "onAccent sobre el relleno amarillo")
    }

    // MARK: - Helpers

    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ShoppingItem.self, ShoppingList.self, ProductCatalogItem.self, Category.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}

private struct FailingFileStore: FileStore {
    private enum ForcedError: Error { case fileSystemUnavailable }

    func saveReceiptData(_ data: Data) throws -> String { throw ForcedError.fileSystemUnavailable }
    func receiptURL(named filename: String) throws -> URL { throw ForcedError.fileSystemUnavailable }
    func finalVoiceNoteURL(named filename: String) throws -> URL { throw ForcedError.fileSystemUnavailable }
    func temporaryVoiceNoteURL(named filename: String) throws -> URL { throw ForcedError.fileSystemUnavailable }
    func promoteTemporaryVoiceNote(named filename: String) throws -> String { throw ForcedError.fileSystemUnavailable }
    func deleteVoiceNote(named filename: String) throws { throw ForcedError.fileSystemUnavailable }
    func deleteReceipt(named filename: String) throws { throw ForcedError.fileSystemUnavailable }
    func cleanupUnreferencedFiles(voiceNoteFilenames: Set<String>, receiptFilenames: Set<String>) throws { throw ForcedError.fileSystemUnavailable }
    func resetAllFiles() throws { throw ForcedError.fileSystemUnavailable }
}
