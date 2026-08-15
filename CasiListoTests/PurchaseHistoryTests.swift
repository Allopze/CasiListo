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
        ).list
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

    // MARK: - Parser de líneas de boleta

    func testParserReadsSameLineAndTwoLineFormats() {
        let lines = [
            "JUMBO SPA",
            "BOLETA ELECTRONICA",
            "PAN MARRAQUETA 1.250",
            "COCA COLA ZERO 3L",
            "2 x $1.990 $3.980",
            "LECHE COLUN 1L",
            "$990",
            "AHORRO SOCIO 500",
            "TOTAL 7.210"
        ]

        let parsed = ReceiptLineParser.parse(lines)

        XCTAssertEqual(parsed.count, 3)

        XCTAssertEqual(parsed[0].name, "PAN MARRAQUETA")
        XCTAssertEqual(parsed[0].price, 1_250)
        XCTAssertEqual(parsed[0].quantity, 1)

        XCTAssertEqual(parsed[1].name, "COCA COLA ZERO 3L")
        XCTAssertEqual(parsed[1].price, 1_990)
        XCTAssertEqual(parsed[1].quantity, 2)

        XCTAssertEqual(parsed[2].name, "LECHE COLUN 1L")
        XCTAssertEqual(parsed[2].price, 990)
        XCTAssertEqual(parsed[2].quantity, 1)
    }

    func testParserPrefersPrintedTotalWhenUnitDoesNotMatch() {
        let parsed = ReceiptLineParser.parse(["YOGURT GRIEGO", "3 x $1.000 $2.700"])

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].quantity, 3)
        XCTAssertEqual(parsed[0].price, 900)
    }

    func testParserStripsLeadingBarcodeFromName() {
        let parsed = ReceiptLineParser.parse(["7801610001234 ACEITE MARAVILLA 2.590"])

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].name, "ACEITE MARAVILLA")
        XCTAssertEqual(parsed[0].price, 2_590)
    }

    func testParserIgnoresOrphanQuantityAndDiscountLines() {
        let parsed = ReceiptLineParser.parse(["2 x $1.990 $3.980", "$5.000", "DESCUENTO 900"])

        XCTAssertTrue(parsed.isEmpty)
    }

    // MARK: - Matching contra la lista

    func testMatcherPrefersPurchasedItemsOverPending() {
        let purchased = ShoppingItem(name: "Coca Cola", status: .purchased, store: .jumbo)
        let pending = ShoppingItem(name: "Coca Cola Zero", status: .pending, store: .jumbo)

        let match = ProductNameMatcher.bestMatch(for: "COCA COLA", in: [pending, purchased])

        XCTAssertEqual(match?.id, purchased.id)
    }

    func testMatcherFallsBackToPendingWhenNoPurchasedMatches() {
        let purchased = ShoppingItem(name: "Detergente", status: .purchased, store: .jumbo)
        let pending = ShoppingItem(name: "Coca Cola", status: .pending, store: .jumbo)

        let match = ProductNameMatcher.bestMatch(for: "COCA COLA", in: [pending, purchased])

        XCTAssertEqual(match?.id, pending.id)
    }

    // MARK: - Cierre de compra con boleta

    func testReceiptClosingArchivesPurchasedItemsAlongsideReceipt() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeList = ShoppingList(title: "Compra actual")
        let scannedItem = ShoppingItem(name: "Leche", listID: activeList.id, status: .purchased, store: .jumbo)
        let unscannedSameStore = ShoppingItem(name: "Pan", listID: activeList.id, status: .purchased, price: 1_200, store: .jumbo)
        let otherStorePurchased = ShoppingItem(name: "Queso", listID: activeList.id, status: .purchased, price: 3_500, store: .lider)
        let pendingItem = ShoppingItem(name: "Huevos", listID: activeList.id, status: .pending, store: .jumbo)
        context.insert(activeList)
        [scannedItem, unscannedSameStore, otherStorePurchased, pendingItem].forEach { context.insert($0) }

        let summary = try ReceiptPurchaseService.register(
            entries: [
                ReceiptPurchaseEntry(name: "Leche", price: 1_490, associatedItemID: scannedItem.id),
                ReceiptPurchaseEntry(name: "Galletas", price: 890, quantity: 2)
            ],
            receiptImage: receiptImage(),
            store: .jumbo,
            activeList: activeList,
            allItems: [scannedItem, unscannedSameStore, otherStorePurchased, pendingItem],
            categories: [],
            context: context,
            archivingPurchased: true
        )
        defer {
            if let filename = summary.list.receiptImageFilename {
                ReceiptImageStore.delete(named: filename)
            }
        }

        // La lista de la boleta: 2 líneas + 1 marcado de la misma tienda fusionado.
        XCTAssertEqual(summary.receiptProductCount, 2)
        XCTAssertEqual(summary.mergedPurchasedCount, 1)
        XCTAssertEqual(summary.otherStoreArchivedCount, 1)
        XCTAssertEqual(summary.list.purchasedCount, 3)
        // Total: 1.490 + (890 × 2) + 1.200 del pan fusionado.
        XCTAssertEqual(summary.list.totalSpent, 1_490 + 1_780 + 1_200)
        XCTAssertEqual(scannedItem.listID, summary.list.id)
        XCTAssertEqual(unscannedSameStore.listID, summary.list.id)

        // El comprado de la otra tienda queda en su propia compra completada.
        let completedLists = try context.fetch(FetchDescriptor<ShoppingList>())
            .filter { $0.status == .completed }
        XCTAssertEqual(completedLists.count, 2)
        let liderList = completedLists.first { $0.storeScope == .lider }
        XCTAssertEqual(otherStorePurchased.listID, liderList?.id)
        XCTAssertEqual(liderList?.totalSpent, 3_500)

        // Lo pendiente no se toca.
        XCTAssertEqual(pendingItem.listID, activeList.id)
        XCTAssertEqual(pendingItem.status, .pending)
    }

    func testReceiptWithoutClosingLeavesPurchasedItemsInActiveList() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeList = ShoppingList(title: "Compra actual")
        let purchasedItem = ShoppingItem(name: "Pan", listID: activeList.id, status: .purchased, store: .jumbo)
        context.insert(activeList)
        context.insert(purchasedItem)

        let summary = try ReceiptPurchaseService.register(
            entries: [ReceiptPurchaseEntry(name: "Galletas", price: 890)],
            receiptImage: receiptImage(),
            store: .jumbo,
            activeList: activeList,
            allItems: [purchasedItem],
            categories: [],
            context: context
        )
        defer {
            if let filename = summary.list.receiptImageFilename {
                ReceiptImageStore.delete(named: filename)
            }
        }

        XCTAssertEqual(summary.mergedPurchasedCount, 0)
        XCTAssertEqual(purchasedItem.listID, activeList.id)
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
