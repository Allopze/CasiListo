import XCTest
import SwiftData
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

        ShoppingListLifecycleService.archivePurchasedItems(
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

        ShoppingListLifecycleService.archivePurchasedItems(
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

        CategoryBootstrapService.bootstrap(context: context)

        var catDescriptor = FetchDescriptor<CasiListo.Category>()
        let fetched = try context.fetch(catDescriptor)
        let reconciled = fetched.first { $0.name == DefaultCategory.condimentos.rawValue }
        XCTAssertEqual(reconciled?.sfSymbol, DefaultCategory.condimentos.sfSymbol)
    }

    func testBootstrapCreatesDefaultCategoriesOnEmptyDB() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        CategoryBootstrapService.bootstrap(context: context)

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

    // MARK: - Helpers

    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ShoppingItem.self, ShoppingList.self, ProductCatalogItem.self, Category.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
