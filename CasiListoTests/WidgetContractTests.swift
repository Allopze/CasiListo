import SwiftData
import XCTest
@testable import CasiListo

/// El contrato app↔widget vive una sola vez en `CasiListoShared/`. Estos
/// tests fijan las dos mitades del widget interactivo: lo que el intent hace
/// en el proceso del widget (snapshot optimista + cola) y lo que la app hace
/// al volver a primer plano (persistir y republicar).
@MainActor
final class WidgetContractTests: XCTestCase {

    private func makeScratchDefaults(_ name: String = #function) throws -> UserDefaults {
        let suite = "CasiListoTests.widgetContract.\(name)"
        UserDefaults.standard.removeSuite(named: suite)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { UserDefaults.standard.removeSuite(named: suite) }
        return defaults
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ShoppingItem.self, ShoppingList.self, ProductCatalogItem.self, CasiListo.Category.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    // MARK: - Snapshot

    func testSnapshotRoundTripsThroughGroupDefaults() throws {
        let defaults = try makeScratchDefaults()
        let original = WidgetSnapshot(
            pendingCount: 3,
            purchasedCount: 1,
            topItems: [WidgetItemSnapshot(id: UUID(), name: "Leche")],
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        original.write(to: defaults)
        XCTAssertEqual(WidgetSnapshot.read(from: defaults), original)
    }

    func testReadingWithoutSnapshotIsPlaceholder() throws {
        let defaults = try makeScratchDefaults()
        let snapshot = WidgetSnapshot.read(from: defaults)
        XCTAssertTrue(snapshot.isPlaceholder)
    }

    func testMarkingPurchasedRemovesTheItemAndMovesTheCounters() {
        let id = UUID()
        let snapshot = WidgetSnapshot(
            pendingCount: 2,
            purchasedCount: 0,
            topItems: [WidgetItemSnapshot(id: id, name: "Pan"), WidgetItemSnapshot(id: UUID(), name: "Leche")],
            updatedAt: .distantPast
        )

        let updated = snapshot.markingPurchased(itemID: id)

        XCTAssertEqual(updated.pendingCount, 1)
        XCTAssertEqual(updated.purchasedCount, 1)
        XCTAssertEqual(updated.topItems.map(\.name), ["Leche"])
        XCTAssertGreaterThan(updated.updatedAt, .distantPast)
    }

    /// Un ID que no está publicado —ya lo marcó la app, o el snapshot cambió
    /// entre medio— no debe descontar nada: el contador quedaría en negativo
    /// o desfasado respecto a lo que la base dice.
    func testMarkingAnUnknownItemLeavesTheSnapshotUntouched() {
        let snapshot = WidgetSnapshot(
            pendingCount: 1,
            purchasedCount: 0,
            topItems: [WidgetItemSnapshot(id: UUID(), name: "Pan")],
            updatedAt: .distantPast
        )
        XCTAssertEqual(snapshot.markingPurchased(itemID: UUID()), snapshot)
    }

    // MARK: - Cola

    func testQueueEnqueuesOnceAndDrainClearsIt() throws {
        let defaults = try makeScratchDefaults()
        let id = UUID()

        WidgetActionQueue.enqueue(itemID: id, in: defaults)
        WidgetActionQueue.enqueue(itemID: id, in: defaults)

        XCTAssertEqual(WidgetActionQueue.drain(from: defaults), [id])
        XCTAssertEqual(WidgetActionQueue.drain(from: defaults), [], "La cola debe vaciarse al drenar")
    }

    // MARK: - Drenado en la app

    func testApplyingPendingPurchasesMarksOnlyPendingItemsAndClearsTheQueue() throws {
        let defaults = try makeScratchDefaults()
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let pending = ShoppingItem(name: "Pan", status: .pending)
        let alreadyPurchased = ShoppingItem(name: "Leche", status: .purchased)
        let untouched = ShoppingItem(name: "Queso", status: .pending)
        [pending, alreadyPurchased, untouched].forEach { context.insert($0) }
        try context.save()

        WidgetActionQueue.enqueue(itemID: pending.id, in: defaults)
        WidgetActionQueue.enqueue(itemID: alreadyPurchased.id, in: defaults)
        WidgetActionQueue.enqueue(itemID: UUID(), in: defaults) // borrado entre medio

        try ShoppingPersistenceCoordinator(context: context).applyPendingWidgetPurchases(from: defaults)

        XCTAssertEqual(pending.status, .purchased)
        XCTAssertEqual(alreadyPurchased.status, .purchased)
        XCTAssertEqual(untouched.status, .pending)
        XCTAssertEqual(WidgetActionQueue.drain(from: defaults), [])
    }

    func testApplyingAnEmptyQueueDoesNothing() throws {
        let defaults = try makeScratchDefaults()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let item = ShoppingItem(name: "Pan", status: .pending)
        context.insert(item)
        try context.save()

        try ShoppingPersistenceCoordinator(context: context).applyPendingWidgetPurchases(from: defaults)

        XCTAssertEqual(item.status, .pending)
    }
}
