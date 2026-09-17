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

    func testPublishedEmptySnapshotIsNotPlaceholder() {
        let snapshot = WidgetSnapshot(
            pendingCount: 0,
            purchasedCount: 0,
            topItems: [],
            updatedAt: .now,
            publicationState: .empty
        )

        XCTAssertFalse(snapshot.isPlaceholder)
        XCTAssertTrue(snapshot.isEmpty)
    }

    func testLegacySnapshotWithoutPublicationStateRemainsCompatible() throws {
        let id = UUID()
        let legacy: [String: Any] = [
            "pendingCount": 1,
            "purchasedCount": 0,
            "topItems": [["id": id.uuidString, "name": "Pan"]],
            "updatedAt": Date(timeIntervalSince1970: 1_000).timeIntervalSinceReferenceDate
        ]
        let data = try JSONSerialization.data(withJSONObject: legacy)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: data)

        XCTAssertEqual(decoded.publicationState, .hasContent)
        XCTAssertEqual(decoded.topItems.first?.id, id)
    }

    func testLegacyPublishedEmptySnapshotIsNotMistakenForUnpublished() throws {
        let legacy: [String: Any] = [
            "pendingCount": 0,
            "purchasedCount": 0,
            "topItems": [],
            "updatedAt": Date(timeIntervalSince1970: 1_000).timeIntervalSinceReferenceDate
        ]
        let data = try JSONSerialization.data(withJSONObject: legacy)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: data)

        XCTAssertTrue(decoded.isEmpty)
        XCTAssertFalse(decoded.isPlaceholder)
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
        XCTAssertEqual(updated.publicationState, .hasContent)
    }

    func testPublicationStatesKeepUnpublishedEmptyAndContentDistinct() {
        let unpublished = WidgetSnapshot.empty
        let empty = WidgetSnapshot(
            pendingCount: 0,
            purchasedCount: 0,
            topItems: [],
            updatedAt: .now,
            publicationState: .empty
        )
        let purchased = WidgetSnapshot(
            pendingCount: 0,
            purchasedCount: 1,
            topItems: [],
            updatedAt: .now,
            publicationState: .hasContent
        )

        XCTAssertTrue(unpublished.isPlaceholder)
        XCTAssertTrue(empty.isEmpty)
        XCTAssertFalse(empty.isPlaceholder)
        XCTAssertFalse(purchased.isPlaceholder)
        XCTAssertFalse(purchased.isEmpty)
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

    func testQueueEnqueuesOnceAndAcknowledgesOnlyAppliedIDs() throws {
        let defaults = try makeScratchDefaults()
        let id = UUID()

        WidgetActionQueue.enqueue(itemID: id, in: defaults)
        WidgetActionQueue.enqueue(itemID: id, in: defaults)

        XCTAssertEqual(WidgetActionQueue.peek(from: defaults), [id])
        WidgetActionQueue.acknowledge(ids: [id], in: defaults)
        XCTAssertEqual(WidgetActionQueue.peek(from: defaults), [])
    }

    func testAcknowledgingOneIDPreservesOtherActions() throws {
        let defaults = try makeScratchDefaults()
        let first = UUID()
        let second = UUID()
        WidgetActionQueue.enqueue(itemID: first, in: defaults)
        WidgetActionQueue.enqueue(itemID: second, in: defaults)

        WidgetActionQueue.acknowledge(ids: [first], in: defaults)

        XCTAssertEqual(WidgetActionQueue.peek(from: defaults), [second])

        let third = UUID()
        WidgetActionQueue.enqueue(itemID: third, in: defaults)
        XCTAssertEqual(WidgetActionQueue.peek(from: defaults), [second, third])
    }

    func testMalformedQueueEntriesAreDiscardedExplicitly() throws {
        let defaults = try makeScratchDefaults()
        let valid = UUID()
        defaults.set(["not-a-uuid", valid.uuidString], forKey: WidgetContract.pendingPurchasesKey)

        WidgetActionQueue.discardMalformed(from: defaults)

        XCTAssertEqual(WidgetActionQueue.peek(from: defaults), [valid])
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
        XCTAssertEqual(WidgetActionQueue.peek(from: defaults), [])
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

    func testSaveFailureKeepsWidgetActionForRetry() throws {
        enum ForcedSaveFailure: Error { case expected }

        let defaults = try makeScratchDefaults()
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let item = ShoppingItem(name: "Pan", status: .pending)
        context.insert(item)
        try context.save()
        WidgetActionQueue.enqueue(itemID: item.id, in: defaults)

        let coordinator = ShoppingPersistenceCoordinator(
            context: context,
            saveOperation: { throw ForcedSaveFailure.expected }
        )

        XCTAssertThrowsError(try coordinator.applyPendingWidgetPurchases(from: defaults))
        XCTAssertEqual(WidgetActionQueue.peek(from: defaults), [item.id])
        XCTAssertEqual(item.status, .pending)

        try ShoppingPersistenceCoordinator(context: context).applyPendingWidgetPurchases(from: defaults)
        XCTAssertEqual(item.status, .purchased)
        XCTAssertEqual(WidgetActionQueue.peek(from: defaults), [])
        try ShoppingPersistenceCoordinator(context: context).applyPendingWidgetPurchases(from: defaults)
        XCTAssertEqual(item.status, .purchased)
    }
}
