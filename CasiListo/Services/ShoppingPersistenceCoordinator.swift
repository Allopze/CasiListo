import Foundation
import SwiftData
import UIKit

enum PersistenceError: LocalizedError {
    case saveFailed(String)
    case resetFailed(String)

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "No se pudieron guardar los cambios. Inténtalo nuevamente."
        case .resetFailed:
            return "No se pudieron borrar todos los datos. Inténtalo nuevamente."
        }
    }
}

@MainActor
protocol WidgetSnapshotWriting {
    func publish(items: [ShoppingItem])
}

@MainActor
struct WidgetSnapshotWriter: WidgetSnapshotWriting {
    func publish(items: [ShoppingItem]) {
        WidgetDataBridge.write(items: items)
    }
}

/// Punto transaccional de las mutaciones persistentes de la lista. El snapshot
/// del widget se publica únicamente después de que SwiftData confirma el cambio.
@MainActor
final class ShoppingPersistenceCoordinator {
    let context: ModelContext
    let fileStore: FileStore
    private let widgetWriter: any WidgetSnapshotWriting

    init(
        context: ModelContext,
        fileStore: FileStore = LocalFileStore.shared,
        widgetWriter: any WidgetSnapshotWriting = WidgetSnapshotWriter()
    ) {
        self.context = context
        self.fileStore = fileStore
        self.widgetWriter = widgetWriter
    }

    func commit(itemsForWidget items: [ShoppingItem]) throws {
        do {
            try context.save()
            widgetWriter.publish(items: items)
        } catch {
            context.rollback()
            throw PersistenceError.saveFailed(error.localizedDescription)
        }
    }

    func commitWithoutWidget() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw PersistenceError.saveFailed(error.localizedDescription)
        }
    }

    func saveItem(_ item: ShoppingItem, allActiveItems: [ShoppingItem]) throws {
        try commit(itemsForWidget: allActiveItems)
    }

    func archivePurchased(
        from items: [ShoppingItem],
        activeList: ShoppingList?,
        store: Store? = nil,
        title: String? = nil
    ) throws {
        try ShoppingListLifecycleService.archivePurchasedItems(
            from: items,
            activeList: activeList,
            store: store,
            title: title,
            context: context,
            coordinator: self
        )
    }

    func deleteItem(_ item: ShoppingItem, remainingItems: [ShoppingItem]) throws {
        context.delete(item)
        try commit(itemsForWidget: remainingItems)
    }

    func importItems(_ importedItems: [ShoppingItem], allActiveItems: [ShoppingItem]) throws {
        guard !importedItems.isEmpty else { return }
        try commit(itemsForWidget: allActiveItems)
    }

    @discardableResult
    func registerReceipt(
        entries: [ReceiptPurchaseEntry],
        receiptImage: UIImage,
        store: Store,
        activeList: ShoppingList?,
        allItems: [ShoppingItem],
        categories: [Category],
        archivingPurchased: Bool = false
    ) throws -> ReceiptRegistrationSummary {
        try ReceiptPurchaseService.register(
            entries: entries,
            receiptImage: receiptImage,
            store: store,
            activeList: activeList,
            allItems: allItems,
            categories: categories,
            context: context,
            archivingPurchased: archivingPurchased
        )
    }

    /// Variante con la foto ya codificada y guardada fuera del hilo principal.
    @discardableResult
    func registerReceipt(
        entries: [ReceiptPurchaseEntry],
        receiptFilename: String,
        store: Store,
        activeList: ShoppingList?,
        allItems: [ShoppingItem],
        categories: [Category],
        archivingPurchased: Bool = false
    ) throws -> ReceiptRegistrationSummary {
        try ReceiptPurchaseService.register(
            entries: entries,
            receiptFilename: receiptFilename,
            store: store,
            activeList: activeList,
            allItems: allItems,
            categories: categories,
            context: context,
            archivingPurchased: archivingPurchased
        )
    }

    func cleanUnreferencedFiles() throws {
        let items = try context.fetch(FetchDescriptor<ShoppingItem>())
        let lists = try context.fetch(FetchDescriptor<ShoppingList>())
        try fileStore.cleanupUnreferencedFiles(
            voiceNoteFilenames: Set(items.compactMap(\.voiceNoteFilename)),
            receiptFilenames: Set(lists.compactMap(\.receiptImageFilename))
        )
    }

    func resetAllData() throws {
        VoiceNoteService.shared.stopPlaying()
        do {
            for item in try context.fetch(FetchDescriptor<ShoppingItem>()) { context.delete(item) }
            for list in try context.fetch(FetchDescriptor<ShoppingList>()) { context.delete(list) }
            for category in try context.fetch(FetchDescriptor<Category>()) { context.delete(category) }
            for catalogItem in try context.fetch(FetchDescriptor<ProductCatalogItem>()) { context.delete(catalogItem) }

            try context.save()
            try fileStore.resetAllFiles()
            UserDefaults.standard.removeObject(forKey: "hasSeededDefaultProducts")
            UserDefaults.standard.removeObject(forKey: "geofencing_enabled")
            UserDefaults.standard.removeObject(forKey: "accessibilityTextSizeScale")
            UserDefaults.standard.removeObject(forKey: "collapsedCategoryNames")
            UserDefaults.standard.removeObject(forKey: "catalogCollapsedCategoryNames")
            UserDefaults.standard.removeObject(forKey: "user_stats")
            UserDefaults(suiteName: WidgetDataBridge.appGroupID)?.removeObject(forKey: WidgetDataBridge.snapshotKey)

            try CategoryBootstrapService.bootstrap(context: context)
            _ = try ShoppingListLifecycleService.createActiveList(in: context)
            try commit(itemsForWidget: [])
        } catch {
            context.rollback()
            throw PersistenceError.resetFailed(error.localizedDescription)
        }
    }
}
