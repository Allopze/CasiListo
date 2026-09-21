import Foundation
import OSLog
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
    private static let widgetLogger = Logger(subsystem: "com.allopze.CasiListo", category: "WidgetActions")
    let context: ModelContext
    let fileStore: FileStore
    private let widgetWriter: any WidgetSnapshotWriting
    private let saveOperation: (() throws -> Void)?

    init(
        context: ModelContext,
        fileStore: FileStore = LocalFileStore.shared,
        widgetWriter: any WidgetSnapshotWriting = WidgetSnapshotWriter(),
        saveOperation: (() throws -> Void)? = nil
    ) {
        self.context = context
        self.fileStore = fileStore
        self.widgetWriter = widgetWriter
        self.saveOperation = saveOperation
    }

    // Evita el scope implícito de `MainActor` durante la liberación. iOS 26
    // aborta en `TaskLocal::StopLookupScope` al destruir coordinadores
    // temporales creados por servicios como `CatalogService`.
    nonisolated deinit {}

    func commit() throws {
        try commitWithoutWidget()
        refreshWidgetSnapshot()
    }

    func commitWithoutWidget() throws {
        do {
            if let saveOperation {
                try saveOperation()
            } else {
                try context.save()
            }
        } catch {
            context.rollback()
            throw PersistenceError.saveFailed(error.localizedDescription)
        }
    }

    /// El widget refleja **todas** las listas activas. Con multi-lista no existe
    /// una «lista actual» única, y dejar que cada pantalla decida qué publicar
    /// hacía que el widget mostrara la última lista abierta —o una ya borrada.
    ///
    /// No propaga errores a propósito: un snapshot desactualizado no puede tumbar
    /// una escritura que SwiftData ya confirmó.
    func refreshWidgetSnapshot() {
        guard let items = try? itemsInActiveLists() else { return }
        widgetWriter.publish(items: items)
    }

    private func itemsInActiveLists() throws -> [ShoppingItem] {
        let activeListIDs = Set(
            try context.fetch(FetchDescriptor<ShoppingList>())
                .filter { $0.status == .active }
                .map(\.id)
        )
        // El widget publica solo los primeros 5 pendientes: sin orden explícito
        // SwiftData los devuelve en el orden que quiera y el «top 5» cambiaba
        // entre refrescos sin que nadie tocara la lista.
        var descriptor = FetchDescriptor<ShoppingItem>()
        descriptor.sortBy = [
            SortDescriptor(\.sortOrder),
            SortDescriptor(\.createdAt)
        ]
        return try context.fetch(descriptor)
            .filter { item in item.listID.map(activeListIDs.contains) ?? false }
    }

    func saveItem(_ item: ShoppingItem) throws {
        try commit()
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

    func deleteItem(_ item: ShoppingItem) throws {
        context.delete(item)
        try commit()
    }

    func importItems(_ importedItems: [ShoppingItem]) throws {
        guard !importedItems.isEmpty else { return }
        try commit()
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

    /// Aplica en SwiftData lo que la persona marcó desde el widget.
    ///
    /// El widget no abre la base: `MarkPurchasedIntent` solo actualiza el
    /// snapshot de forma optimista y deja el ID en una cola del App Group.
    /// Aquí se persiste de verdad. Un ID que ya no corresponde a un producto
    /// pendiente —borrado o marcado desde la app entre medio— se descarta;
    /// el `commit()` final republica el snapshot desde la base, que es la
    /// única fuente de verdad, por si el optimista se había quedado atrás.
    func applyPendingWidgetPurchases(from defaults: UserDefaults? = WidgetContract.groupDefaults) throws {
        WidgetActionQueue.discardMalformed(from: defaults)
        let pendingIDs = Set(WidgetActionQueue.peek(from: defaults))
        guard !pendingIDs.isEmpty else { return }

        let items = try context.fetch(FetchDescriptor<ShoppingItem>())
        var appliedIDs = Set<UUID>()
        var obsoleteIDs = Set<UUID>()
        var appliedItems: [ShoppingItem] = []
        for id in pendingIDs {
            guard let item = items.first(where: { $0.id == id }) else {
                obsoleteIDs.insert(id)
                continue
            }
            guard item.status == .pending else {
                obsoleteIDs.insert(id)
                continue
            }
            item.status = .purchased
            appliedIDs.insert(id)
            appliedItems.append(item)
        }
        do {
            try commit()
        } catch {
            // SwiftData's rollback restores the store, but on iOS 26 the
            // already-fetched @Model instances can keep their mutated values.
            // Restore those objects too so this still-pending queue can retry.
            for item in appliedItems {
                item.status = .pending
            }
            throw error
        }
        // Tanto los cambios aplicados como los IDs que ya no tienen trabajo
        // válido se confirman solo después del save. Si fetch o save falla, la
        // cola completa permanece disponible para el siguiente intento.
        WidgetActionQueue.acknowledge(ids: Array(pendingIDs), in: defaults)
        Self.widgetLogger.debug("Aplicadas \(appliedIDs.count) acciones del widget; descartadas \(obsoleteIDs.count) obsoletas")
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
            UserDefaults.standard.removeObject(forKey: SuggestedProducts.hasSeededCatalogKey)
            UserDefaults.standard.removeObject(forKey: SuggestedProducts.catalogSeedBatchKey)
            UserDefaults.standard.removeObject(forKey: AppDefaultsKeys.geofencingEnabled)
            UserDefaults.standard.removeObject(forKey: AppDefaultsKeys.accessibilityTextSizeScale)
            ShoppingListViewModel.removeAllCollapsedCategoryState()
            UserDefaults.standard.removeObject(forKey: ActiveListSelection.storageKey)
            UserDefaults.standard.removeObject(forKey: CatalogView.collapseKey)
            UserDefaults.standard.removeObject(forKey: AppDefaultsKeys.userStats)
            // Borrar todo deja la app como recién instalada, y eso incluye
            // la guía de primer uso (CASI-011).
            UserDefaults.standard.removeObject(forKey: AppDefaultsKeys.hasSeenOnboardingV1)
            UserDefaults(suiteName: WidgetContract.appGroupID)?.removeObject(forKey: WidgetContract.snapshotKey)
            // Los IDs encolados desde el widget apuntan a productos que
            // acaban de desaparecer: aplicarlos después no marcaría nada,
            // pero dejarlos ahí es basura que sobrevive al «borrar todo».
            WidgetActionQueue.clear()

            try CategoryBootstrapService.bootstrap(context: context)
            // Borrar todo deja la app como recién instalada, y eso incluye el
            // catálogo sugerido: sin esto quedaba vacío hasta el próximo arranque.
            try SuggestedProducts.seedCatalogItems(in: context)
            try commit()

            // Los archivos se borran al final, con la base ya reseteada y con
            // categorías: si esto lanza, el `rollback()` del catch ya no puede
            // deshacer el `save()` anterior, y dejar la base vacía y sin
            // categorías es mucho peor que dejar blobs sueltos —que además
            // barre `cleanupUnreferencedFiles` en el siguiente arranque.
            try fileStore.resetAllFiles()
        } catch {
            context.rollback()
            throw PersistenceError.resetFailed(error.localizedDescription)
        }
    }
}
