import XCTest
import SwiftData
@testable import CasiListo

@MainActor
final class CasiListoTests: XCTestCase {

    func testPriceTotals() {
        let viewModel = ShoppingListViewModel()
        let items = [
            ShoppingItem(name: "Tomates", isPurchased: false, price: 1.50),
            ShoppingItem(name: "Leche", isPurchased: false, price: 2.00),
            ShoppingItem(name: "Pan", isPurchased: true, price: 1.20),
            ShoppingItem(name: "Galletas", isPurchased: true, price: nil)
        ]
        
        XCTAssertEqual(viewModel.pendingTotal(from: items), 3.50, accuracy: 0.001)
        XCTAssertEqual(viewModel.purchasedTotal(from: items), 1.20, accuracy: 0.001)
        XCTAssertEqual(viewModel.grandTotal(from: items), 4.70, accuracy: 0.001)
    }

    func testItemCounts() {
        let viewModel = ShoppingListViewModel()
        let items = [
            ShoppingItem(name: "Tomates", isPurchased: false),
            ShoppingItem(name: "Leche", isPurchased: false),
            ShoppingItem(name: "Pan", isPurchased: true)
        ]
        
        let counts = viewModel.itemCounts(from: items)
        XCTAssertEqual(counts.pending, 2)
        XCTAssertEqual(counts.purchased, 1)
    }

    func testListSummaryCalculatesCountsAndTotalsInOnePass() {
        let viewModel = ShoppingListViewModel()
        let items = [
            ShoppingItem(name: "Tomates", isPurchased: false, price: 1.50),
            ShoppingItem(name: "Leche", isPurchased: false, price: nil),
            ShoppingItem(name: "Pan", isPurchased: true, price: 1.20),
            ShoppingItem(name: "Cafe", isPurchased: true, price: 4.00)
        ]

        let summary = viewModel.summary(from: items)

        XCTAssertEqual(summary.pendingCount, 2)
        XCTAssertEqual(summary.purchasedCount, 2)
        XCTAssertEqual(summary.pendingTotal, 1.50, accuracy: 0.001)
        XCTAssertEqual(summary.purchasedTotal, 5.20, accuracy: 0.001)
    }

    func testNextSortOrder() {
        let viewModel = ShoppingListViewModel()
        let items = [
            ShoppingItem(name: "Tomates", category: .frutasVerduras, sortOrder: 0),
            ShoppingItem(name: "Lechuga", category: .frutasVerduras, sortOrder: 2),
            ShoppingItem(name: "Leche", category: .lacteosHuevos, sortOrder: 1)
        ]
        
        XCTAssertEqual(viewModel.nextSortOrder(for: .frutasVerduras, in: items), 3)
        XCTAssertEqual(viewModel.nextSortOrder(for: .lacteosHuevos, in: items), 2)
        XCTAssertEqual(viewModel.nextSortOrder(for: .despensa, in: items), 0)
    }

    func testQuickAddDraftParsesCommonQuantityPatterns() {
        let viewModel = ShoppingListViewModel()

        let leading = viewModel.quickAddDraft(from: "2 leche")
        XCTAssertEqual(leading.name, "leche")
        XCTAssertEqual(leading.quantity, "2")

        let trailingMultiplier = viewModel.quickAddDraft(from: "pan x3")
        XCTAssertEqual(trailingMultiplier.name, "pan")
        XCTAssertEqual(trailingMultiplier.quantity, "3")

        let trailingUnit = viewModel.quickAddDraft(from: "tomates 1 kg")
        XCTAssertEqual(trailingUnit.name, "tomates")
        XCTAssertEqual(trailingUnit.quantity, "1 kg")
    }

    func testSummaryTracksSkippedAndUnavailableStates() {
        let viewModel = ShoppingListViewModel()
        let items = [
            ShoppingItem(name: "Leche", status: .pending),
            ShoppingItem(name: "Pan", status: .purchased),
            ShoppingItem(name: "Tomates", status: .skipped),
            ShoppingItem(name: "Cafe", status: .unavailable)
        ]

        let summary = viewModel.summary(from: items)

        XCTAssertEqual(summary.pendingCount, 1)
        XCTAssertEqual(summary.purchasedCount, 1)
        XCTAssertEqual(summary.skippedCount, 1)
        XCTAssertEqual(summary.unavailableCount, 1)
    }

    func testArchivePurchasedItemsCreatesCompletedHistoryList() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ShoppingItem.self,
            ShoppingList.self,
            ProductCatalogItem.self,
            configurations: configuration
        )
        let context = container.mainContext
        let activeList = ShoppingList(title: "Compra actual")
        let purchasedItem = ShoppingItem(name: "Pan", listID: activeList.id, status: .purchased, price: 2)
        let pendingItem = ShoppingItem(name: "Leche", listID: activeList.id, status: .pending, price: 1)
        context.insert(activeList)
        context.insert(purchasedItem)
        context.insert(pendingItem)

        ShoppingListLifecycleService.archivePurchasedItems(
            from: [purchasedItem, pendingItem],
            activeList: activeList,
            context: context
        )

        let descriptor = FetchDescriptor<ShoppingList>()
        let lists = try context.fetch(descriptor)
        let completed = lists.first { $0.status == .completed }

        XCTAssertNotNil(completed)
        XCTAssertEqual(completed?.purchasedCount, 1)
        XCTAssertEqual(completed?.totalSpent, 2)
        XCTAssertEqual(purchasedItem.listID, completed?.id)
        XCTAssertEqual(pendingItem.listID, activeList.id)
    }
}
