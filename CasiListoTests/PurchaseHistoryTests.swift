import SwiftData
import UIKit
import XCTest
@testable import CasiListo

@MainActor
final class PurchaseHistoryTests: XCTestCase {

    func testStoreDetectorRecognizesSupermarketInReceiptHeader() {
        XCTAssertEqual(
            ReceiptStoreDetector.detectStoreRawValue(in: ["JUMBO", "RUT 81.201.000-0", "PAN HALLULLA 1.200"]),
            Store.jumbo.rawValue
        )
        XCTAssertEqual(
            ReceiptStoreDetector.detectStoreRawValue(in: ["LÍDER", "BOLETA ELECTRÓNICA", "LECHE 990"]),
            Store.lider.rawValue
        )
    }

    func testStoreDetectorDoesNotInferStoreFromProductLines() {
        let lines = Array(repeating: "Producto sin tienda", count: 12) + ["Oferta JUMBO 2.000"]
        XCTAssertNil(ReceiptStoreDetector.detectStoreRawValue(in: lines))
    }

    func testClosingListCreatesOneHistoricalPurchasePerStore() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeList = ShoppingList(title: "Compra actual")
        let jumboItem = ShoppingItem(
            name: "Pan",
            listID: activeList.id,
            status: .purchased,
            price: 1_200,
            store: .jumbo
        )
        let liderItem = ShoppingItem(
            name: "Leche",
            listID: activeList.id,
            status: .purchased,
            price: 990,
            store: .lider
        )
        let pendingItem = ShoppingItem(name: "Huevos", listID: activeList.id, status: .pending)
        context.insert(activeList)
        [jumboItem, liderItem, pendingItem].forEach { context.insert($0) }

        try ShoppingListLifecycleService.archivePurchasedItems(
            from: [jumboItem, liderItem, pendingItem],
            activeList: activeList,
            context: context
        )

        let completedLists = try context.fetch(FetchDescriptor<ShoppingList>())
            .filter { $0.status == .completed }
        XCTAssertEqual(completedLists.count, 2)

        let jumboPurchase = completedLists.first { $0.storeScope == .jumbo }
        XCTAssertEqual(jumboPurchase?.purchasedCount, 1)
        XCTAssertEqual(jumboPurchase?.totalSpent, 1_200)
        XCTAssertNotNil(jumboPurchase?.completedAt)
        XCTAssertEqual(jumboItem.listID, jumboPurchase?.id)

        let liderPurchase = completedLists.first { $0.storeScope == .lider }
        XCTAssertEqual(liderPurchase?.purchasedCount, 1)
        XCTAssertEqual(liderPurchase?.totalSpent, 990)
        XCTAssertNotNil(liderPurchase?.completedAt)
        XCTAssertEqual(liderItem.listID, liderPurchase?.id)
        XCTAssertEqual(pendingItem.listID, activeList.id)
    }

    func testClosingListKeepsPurchaseWithoutPrices() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeList = ShoppingList(title: "Compra actual")
        let item = ShoppingItem(name: "Pan", listID: activeList.id, status: .purchased, store: .jumbo)
        context.insert(activeList)
        context.insert(item)

        try ShoppingListLifecycleService.archivePurchasedItems(
            from: [item],
            activeList: activeList,
            context: context
        )

        let completedPurchase = try context.fetch(FetchDescriptor<ShoppingList>())
            .first { $0.status == .completed }
        XCTAssertEqual(completedPurchase?.purchasedCount, 1)
        XCTAssertEqual(completedPurchase?.totalSpent, 0)
        XCTAssertEqual(completedPurchase?.storeScope, .jumbo)
    }

    func testClosingListWithoutPurchasedProductsDoesNotCreateHistory() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeList = ShoppingList(title: "Compra actual")
        let pendingItem = ShoppingItem(name: "Pan", listID: activeList.id, status: .pending)
        context.insert(activeList)
        context.insert(pendingItem)

        try ShoppingListLifecycleService.archivePurchasedItems(
            from: [pendingItem],
            activeList: activeList,
            context: context
        )

        let completedLists = try context.fetch(FetchDescriptor<ShoppingList>())
            .filter { $0.status == .completed }
        XCTAssertTrue(completedLists.isEmpty)
        XCTAssertEqual(pendingItem.listID, activeList.id)
    }

    func testReceiptPurchaseCreatesHistoryWithPhotoAndConfirmedPrice() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeList = ShoppingList(title: "Compra actual")
        let item = ShoppingItem(name: "Leche", listID: activeList.id, status: .pending, store: .lider)
        context.insert(activeList)
        context.insert(item)

        let purchase = try ReceiptPurchaseService.register(
            entries: [ReceiptPurchaseEntry(name: "Leche", price: 1_490, associatedItemID: item.id)],
            receiptImage: receiptImage(),
            store: .lider,
            activeList: activeList,
            allItems: [item],
            categories: [],
            context: context
        )
        defer {
            if let filename = purchase.receiptImageFilename {
                ReceiptImageStore.delete(named: filename)
            }
        }

        XCTAssertEqual(purchase.status, .completed)
        XCTAssertEqual(purchase.storeScope, .lider)
        XCTAssertEqual(purchase.purchasedCount, 1)
        XCTAssertEqual(purchase.totalSpent, 1_490)
        XCTAssertNotNil(purchase.receiptImageFilename)
        XCTAssertNotNil(purchase.receiptCapturedAt)
        XCTAssertNotNil(purchase.receiptImageFilename.flatMap { ReceiptImageStore.image(named: $0) })
        XCTAssertEqual(item.listID, purchase.id)
        XCTAssertEqual(item.status, .purchased)
        XCTAssertEqual(item.price, 1_490)
    }

    func testPriceComparisonUsesMostRecentPurchaseAtSameStore() {
        let oldest = ShoppingList(
            title: "Compra Jumbo",
            createdAt: .now.addingTimeInterval(-14_400),
            completedAt: .now.addingTimeInterval(-14_400),
            status: .completed,
            storeScope: .jumbo
        )
        let latest = ShoppingList(
            title: "Compra Jumbo",
            createdAt: .now.addingTimeInterval(-7_200),
            completedAt: .now.addingTimeInterval(-7_200),
            status: .completed,
            storeScope: .jumbo
        )
        let otherStore = ShoppingList(
            title: "Compra Líder",
            createdAt: .now.addingTimeInterval(-3_600),
            completedAt: .now.addingTimeInterval(-3_600),
            status: .completed,
            storeScope: .lider
        )
        let items = [
            ShoppingItem(name: "Leche entera", listID: oldest.id, price: 1_000, store: .jumbo),
            ShoppingItem(name: "Leche entera", listID: latest.id, price: 1_200, store: .jumbo),
            ShoppingItem(name: "Leche entera", listID: otherStore.id, price: 800, store: .lider)
        ]

        let comparison = ReceiptPriceHistory.latestComparison(
            productName: "LECHE ENTERA",
            newPrice: 1_350,
            store: .jumbo,
            allItems: items,
            completedLists: [oldest, latest, otherStore]
        )

        XCTAssertEqual(comparison?.previousPrice, 1_200)
        XCTAssertEqual(comparison?.difference, 150)
        XCTAssertEqual(comparison?.percentage ?? -1, 12.5, accuracy: 0.001)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ShoppingItem.self, ShoppingList.self, ProductCatalogItem.self, Category.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func receiptImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
    }
}
