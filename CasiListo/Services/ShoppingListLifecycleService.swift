import Foundation
import SwiftData

@MainActor
enum ShoppingListLifecycleService {
    static func bootstrap(
        lists: [ShoppingList],
        items: [ShoppingItem],
        context: ModelContext
    ) -> ShoppingList {
        let activeList = lists.first { $0.status == .active } ?? createActiveList(in: context)
        assignOrphanItems(items, to: activeList, context: context)
        return activeList
    }

    static func createActiveList(in context: ModelContext, title: String = "Compra actual") -> ShoppingList {
        let list = ShoppingList(title: title)
        context.insert(list)
        context.safeSave()
        return list
    }

    static func archivePurchasedItems(
        from items: [ShoppingItem],
        activeList: ShoppingList?,
        store: Store? = nil,
        title: String? = nil,
        context: ModelContext
    ) {
        let purchasedItems = items.filter { item in
            item.status == .purchased && (store == nil || item.store == store)
        }
        guard !purchasedItems.isEmpty else { return }

        let completedList = ShoppingList(
            title: title ?? defaultHistoryTitle(store: store),
            completedAt: Date(),
            status: .completed,
            storeScope: store,
            purchasedCount: purchasedItems.count,
            pendingCount: items.filter { $0.status == .pending }.count,
            skippedCount: purchasedItems.filter { $0.status == .skipped }.count,
            unavailableCount: purchasedItems.filter { $0.status == .unavailable }.count,
            totalSpent: purchasedItems.compactMap(\.price).reduce(0, +)
        )
        context.insert(completedList)

        for item in purchasedItems {
            item.listID = completedList.id
        }

        if let activeList {
            updateActiveListCounters(activeList, items: items)
        }

        context.safeSave()
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
    ) {
        var changed = false

        for item in items where item.listID == nil {
            item.listID = activeList.id
            if item.statusRawValue == nil {
                item.status = item.isPurchased ? .purchased : .pending
            }
            changed = true
        }

        updateActiveListCounters(activeList, items: items)

        if changed {
            context.safeSave()
        }
    }

    private static func defaultHistoryTitle(store: Store?) -> String {
        let date = Date().formatted(date: .abbreviated, time: .omitted)
        if let store {
            return "Compra \(store.displayName) - \(date)"
        }
        return "Compra completada - \(date)"
    }
}

