import Foundation
import SwiftData

@MainActor
enum ShoppingListLifecycleService {
    static func bootstrap(context: ModelContext) throws -> ShoppingList {
        let lists = try context.fetch(FetchDescriptor<ShoppingList>())
        let items = try context.fetch(FetchDescriptor<ShoppingItem>())
        let activeList: ShoppingList
        if let existing = lists.first(where: { $0.status == .active }) {
            activeList = existing
        } else {
            activeList = try createActiveList(in: context)
        }
        try assignOrphanItems(items, to: activeList, context: context)
        return activeList
    }

    static func createActiveList(in context: ModelContext, title: String = "Compra actual") throws -> ShoppingList {
        let list = ShoppingList(title: title)
        context.insert(list)
        try context.save()
        return list
    }

    /// Una lista activa puede reunir productos de más de un supermercado. Al
    /// cerrarla, cada tienda se conserva como una compra independiente.
    static func archivePurchasedItems(
        from items: [ShoppingItem],
        activeList: ShoppingList?,
        store: Store? = nil,
        title: String? = nil,
        context: ModelContext,
        coordinator: ShoppingPersistenceCoordinator? = nil
    ) throws {
        let purchasedItems = items.filter {
            $0.status == .purchased && (store == nil || $0.store == store)
        }
        guard !purchasedItems.isEmpty else { return }

        let purchasesByStore = Dictionary(grouping: purchasedItems) { store ?? $0.store }
        for (purchaseStore, storeItems) in purchasesByStore {
            let completedList = ShoppingList(
                title: title ?? defaultHistoryTitle(store: purchaseStore),
                completedAt: Date(),
                status: .completed,
                storeScope: purchaseStore,
                purchasedCount: storeItems.count,
                pendingCount: 0,
                skippedCount: 0,
                unavailableCount: 0,
                totalSpent: storeItems.compactMap(\.price).reduce(0, +)
            )
            context.insert(completedList)
            for item in storeItems {
                item.listID = completedList.id
            }
        }

        let currentItems = try context.fetch(FetchDescriptor<ShoppingItem>())
        if let activeList {
            updateActiveListCounters(activeList, items: currentItems)
        }

        let activeItems = currentItems.filter { $0.listID == activeList?.id }
        if let coordinator {
            try coordinator.commit(itemsForWidget: activeItems)
        } else {
            try context.save()
        }
    }

    static func updateActiveListCounters(_ list: ShoppingList, items: [ShoppingItem]) {
        let activeItems = items.filter { $0.listID == list.id }
        list.pendingCount = activeItems.filter { $0.status == .pending }.count
        list.purchasedCount = activeItems.filter { $0.status == .purchased }.count
        list.skippedCount = activeItems.filter { $0.status == .skipped }.count
        list.unavailableCount = activeItems.filter { $0.status == .unavailable }.count
        list.totalSpent = activeItems.compactMap(\.price).reduce(0, +)
    }

    private static func assignOrphanItems(
        _ items: [ShoppingItem],
        to activeList: ShoppingList,
        context: ModelContext
    ) throws {
        for item in items where item.listID == nil {
            item.listID = activeList.id
            if item.statusRawValue == nil {
                item.status = item.isPurchased ? .purchased : .pending
            }
        }

        updateActiveListCounters(activeList, items: items)
        try context.save()
    }

    private static func defaultHistoryTitle(store: Store?) -> String {
        let date = Date().formatted(date: .abbreviated, time: .omitted)
        return store.map { "Compra \($0.displayName) - \(date)" } ?? "Compra completada - \(date)"
    }
}
