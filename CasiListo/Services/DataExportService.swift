import Foundation
import SwiftData

/// Exporta un volcado de lectura de los datos del usuario.
///
/// Sin backend, el dispositivo es la única copia: esto es una red de
/// seguridad barata frente a perder el acceso a la app o al teléfono, no un
/// formato de sincronización ni de reimportación. No incluye los archivos
/// (fotos de boleta, notas de voz) —solo sus nombres, como referencia—: esos
/// blobs viven en el sandbox y sacarlos de la app es un problema aparte.
@MainActor
enum DataExportService {
    enum ExportError: LocalizedError {
        case encodingFailed
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .encodingFailed:
                return "No se pudo preparar el archivo de exportación."
            case .writeFailed:
                return "No se pudo guardar el archivo de exportación."
            }
        }
    }

    struct Export: Codable {
        /// Formato del respaldo. Opcional para que los archivos exportados
        /// antes de esta versión (sin el campo) sigan decodificando: ausente
        /// se interpreta como 1. Sin esto, un formato 2.0 futuro no tendría
        /// forma de rechazarse y se importaría a medias.
        var schemaVersion: Int?
        let exportedAt: Date
        let categories: [CategoryExport]
        let lists: [ShoppingListExport]
        let items: [ShoppingItemExport]
        let catalogItems: [ProductCatalogItemExport]
    }

    /// Versión del formato que escribe este binario.
    static let currentExportSchemaVersion = 1

    struct CategoryExport: Codable {
        let name: String
        let sfSymbol: String
        let sortIndex: Int
        let isSystem: Bool
        /// Vínculo estable con `DefaultCategory` (CASI-008). Opcional para que
        /// los respaldos escritos antes de V2 sigan decodificando.
        var defaultCategoryRawValue: String?
    }

    struct ShoppingListExport: Codable {
        let id: UUID
        let title: String
        let createdAt: Date
        let completedAt: Date?
        let status: String
        let storeScope: String?
        let purchasedCount: Int
        let pendingCount: Int
        let skippedCount: Int
        let unavailableCount: Int
        let totalSpent: Double
        let receiptImageFilename: String?
        let iconName: String
        let colorHex: String
    }

    struct ShoppingItemExport: Codable {
        let id: UUID
        let listID: UUID?
        let name: String
        let quantity: String
        let category: String
        let store: String
        let note: String
        let status: String
        let sortOrder: Int
        let price: Double?
        let voiceNoteFilename: String?
        let createdAt: Date
    }

    struct ProductCatalogItemExport: Codable {
        let id: UUID
        let name: String
        let category: String
        let store: String
        let timesAdded: Int
        let lastAddedAt: Date?
        let createdAt: Date
    }

    static func exportAll(context: ModelContext) throws -> Data {
        let categories = try context.fetch(FetchDescriptor<Category>()).map {
            CategoryExport(
                name: $0.name,
                sfSymbol: $0.sfSymbol,
                sortIndex: $0.sortIndex,
                isSystem: $0.isSystem,
                defaultCategoryRawValue: $0.defaultCategoryRawValue
            )
        }
        let itemModels = try context.fetch(FetchDescriptor<ShoppingItem>())

        // Los contadores de una lista **activa** se desactualizan en cuanto se
        // marca o borra un producto: `togglePurchased`/`markItem`/`deleteItem`
        // no llaman a `updateActiveListCounters` (solo lo hacen los caminos de
        // alta y el archivado). El respaldo es el único consumidor real de
        // esos campos para listas activas, así que aquí se recalculan al
        // vuelo en vez de confiar en el valor guardado (CASI-031). Las listas
        // completadas sí guardan un snapshot legítimo: no se tocan.
        let lists = try context.fetch(FetchDescriptor<ShoppingList>()).map { list -> ShoppingListExport in
            let isActive = list.status == .active
            let activeItems = isActive ? itemModels.filter { $0.listID == list.id } : []
            return ShoppingListExport(
                id: list.id,
                title: list.title,
                createdAt: list.createdAt,
                completedAt: list.completedAt,
                status: list.status.rawValue,
                storeScope: list.storeScope?.rawValue,
                purchasedCount: isActive ? activeItems.filter { $0.status == .purchased }.count : list.purchasedCount,
                pendingCount: isActive ? activeItems.filter { $0.status == .pending }.count : list.pendingCount,
                skippedCount: isActive ? activeItems.filter { $0.status == .skipped }.count : list.skippedCount,
                unavailableCount: isActive ? activeItems.filter { $0.status == .unavailable }.count : list.unavailableCount,
                totalSpent: isActive ? activeItems.map(\.lineTotal).reduce(0, +) : list.totalSpent,
                receiptImageFilename: list.receiptImageFilename,
                iconName: list.iconName,
                colorHex: list.colorHex
            )
        }
        let items = itemModels.map {
            ShoppingItemExport(
                id: $0.id,
                listID: $0.listID,
                name: $0.name,
                quantity: $0.quantity,
                category: $0.category.name,
                store: $0.store.rawValue,
                note: $0.note,
                status: $0.status.rawValue,
                sortOrder: $0.sortOrder,
                price: $0.price,
                voiceNoteFilename: $0.voiceNoteFilename,
                createdAt: $0.createdAt
            )
        }
        let catalogItems = try context.fetch(FetchDescriptor<ProductCatalogItem>()).map {
            ProductCatalogItemExport(
                id: $0.id,
                name: $0.name,
                category: $0.category.name,
                store: $0.store.rawValue,
                timesAdded: $0.timesAdded,
                lastAddedAt: $0.lastAddedAt,
                createdAt: $0.createdAt
            )
        }

        let export = Export(
            schemaVersion: currentExportSchemaVersion,
            exportedAt: .now,
            categories: categories,
            lists: lists,
            items: items,
            catalogItems: catalogItems
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(export) else {
            throw ExportError.encodingFailed
        }
        return data
    }

    /// Escribe el volcado en un archivo temporal con nombre legible, listo
    /// para compartir por `ShareLink`. El nombre lleva la fecha para que
    /// exportar dos veces el mismo día no confunda cuál es la más reciente.
    static func exportFile(context: ModelContext) throws -> URL {
        let data = try exportAll(context: context)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let filename = "CasiListo-\(formatter.string(from: .now)).json"
        let url = FileManager.default.temporaryDirectory.appending(path: filename)
        // Sin backend, `temporaryDirectory` es el único lugar donde exportar
        // repetidamente puede acumular archivos sueltos: el sistema la purga
        // de forma oportunista, pero no hay razón para dejarle basura propia
        // (CASI-021).
        removeStaleExports(prefix: "CasiListo-", extension: "json")
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ExportError.writeFailed
        }
        return url
    }

    /// Borra respaldos anteriores de la misma familia en `temporaryDirectory`.
    /// Se usa antes de escribir uno nuevo, tanto aquí como en
    /// `HistoryCSVExportService`, con prefijos distintos para no pisarse.
    static func removeStaleExports(prefix: String, extension fileExtension: String) {
        let directory = FileManager.default.temporaryDirectory
        guard let existing = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for url in existing where url.lastPathComponent.hasPrefix(prefix) && url.pathExtension == fileExtension {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Import de respaldo

    enum ImportError: LocalizedError {
        case invalidFile
        case unsupportedVersion(Int)
        case saveFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidFile:
                return "Este archivo no parece un respaldo de CasiListo."
            case .unsupportedVersion:
                return "Este respaldo viene de una versión más nueva de CasiListo. Actualiza la app e inténtalo de nuevo."
            case .saveFailed:
                return "No se pudo guardar el respaldo. No se cambió nada de lo que ya tenías."
            }
        }
    }

    /// Qué haría (o hizo) una importación. Se usa dos veces —para la
    /// confirmación previa y para el resumen posterior— para que la persona
    /// pueda comparar lo que se le prometió con lo que pasó.
    struct ImportOutcome: Equatable {
        let newCategories: Int
        let newLists: Int
        let newItems: Int
        let newCatalogItems: Int
        let skippedLists: Int
        let skippedItems: Int
        let mergedCatalogItems: Int

        var addsNothing: Bool { newCategories + newLists + newItems + newCatalogItems == 0 }
    }

    private static func decodeExport(_ data: Data) throws -> Export {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let export = try? decoder.decode(Export.self, from: data) else {
            throw ImportError.invalidFile
        }
        let version = export.schemaVersion ?? 1
        guard version <= currentExportSchemaVersion else {
            throw ImportError.unsupportedVersion(version)
        }
        return export
    }

    /// Cuenta qué entraría sin insertar ni guardar nada. `importAll` calcula
    /// este mismo resultado con las mismas reglas antes de mutar el contexto
    /// y lo devuelve tal cual: plan y ejecución no pueden divergir porque
    /// comparten esta única función.
    private static func outcome(for export: Export, context: ModelContext) throws -> ImportOutcome {
        var categoryNames = Set(try context.fetch(FetchDescriptor<Category>()).map { ProductNameNormalizer.normalize($0.name) })
        var newCategories = 0
        for category in export.categories where categoryNames.insert(ProductNameNormalizer.normalize(category.name)).inserted {
            newCategories += 1
        }

        let existingListIDs = Set(try context.fetch(FetchDescriptor<ShoppingList>()).map(\.id))
        let newLists = export.lists.filter { !existingListIDs.contains($0.id) }.count

        let existingItemIDs = Set(try context.fetch(FetchDescriptor<ShoppingItem>()).map(\.id))
        let newItems = export.items.filter { !existingItemIDs.contains($0.id) }.count

        var catalogNames = Set(try context.fetch(FetchDescriptor<ProductCatalogItem>()).map { ProductNameNormalizer.normalize($0.name) })
        var newCatalogItems = 0
        var mergedCatalogItems = 0
        for catalogItem in export.catalogItems {
            if catalogNames.insert(ProductNameNormalizer.normalize(catalogItem.name)).inserted {
                newCatalogItems += 1
            } else {
                mergedCatalogItems += 1
            }
        }

        return ImportOutcome(
            newCategories: newCategories,
            newLists: newLists,
            newItems: newItems,
            newCatalogItems: newCatalogItems,
            skippedLists: export.lists.count - newLists,
            skippedItems: export.items.count - newItems,
            mergedCatalogItems: mergedCatalogItems
        )
    }

    /// Simulacro: decodifica y cuenta sin insertar ni guardar nada. Para la
    /// confirmación previa a importar.
    static func planImport(data: Data, context: ModelContext) throws -> ImportOutcome {
        try outcome(for: try decodeExport(data), context: context)
    }

    /// Importación real. **Aditiva siempre**: nunca borra ni reemplaza una
    /// fila existente — en cualquier colisión, el dispositivo gana.
    @discardableResult
    static func importAll(data: Data, context: ModelContext) throws -> ImportOutcome {
        let export = try decodeExport(data)
        let plannedOutcome = try outcome(for: export, context: context)

        // Categorías: se resuelven por nombre normalizado, no por `id` ni por
        // nombre exacto. `Category.name` es `@Attribute(.unique)` y SwiftData
        // hace upsert en conflicto en vez de lanzar (gotcha documentado):
        // insertar por nombre exacto podría pisar en silencio un `sfSymbol`
        // personalizado, y sin normalizar "Lacteos y huevos" vs "Lácteos y
        // huevos" serían dos categorías.
        var categoryByNormalizedName: [String: Category] = [:]
        // El vínculo con `DefaultCategory` viaja en el respaldo, pero solo se
        // copia a una categoría **nueva** y si ninguna del dispositivo lo tiene
        // ya: dos "Carnes" lógicas harían que `Category.matching` eligiera una
        // al azar. Las existentes no se tocan (el dispositivo gana).
        var takenLinks = Set<String>()
        for category in try context.fetch(FetchDescriptor<Category>()) {
            categoryByNormalizedName[ProductNameNormalizer.normalize(category.name)] = category
            if let link = category.defaultCategoryRawValue { takenLinks.insert(link) }
        }
        for categoryExport in export.categories {
            let key = ProductNameNormalizer.normalize(categoryExport.name)
            guard categoryByNormalizedName[key] == nil else { continue }
            let link = categoryExport.defaultCategoryRawValue.flatMap(DefaultCategory.init(rawValue:))
            let newCategory = Category(
                name: categoryExport.name,
                sfSymbol: categoryExport.sfSymbol,
                sortIndex: categoryExport.sortIndex,
                isSystem: categoryExport.isSystem,
                defaultCategory: link.flatMap { takenLinks.contains($0.rawValue) ? nil : $0 }
            )
            if let assigned = newCategory.defaultCategoryRawValue { takenLinks.insert(assigned) }
            context.insert(newCategory)
            categoryByNormalizedName[key] = newCategory
        }

        func resolvedCategory(named name: String) -> Category {
            categoryByNormalizedName[ProductNameNormalizer.normalize(name)] ?? Category.resolvedFallback(in: context)
        }

        // Listas: `id` estable en el export. En colisión, el dispositivo gana
        // —saltar hace la reimportación idempotente.
        let existingListIDs = Set(try context.fetch(FetchDescriptor<ShoppingList>()).map(\.id))
        for listExport in export.lists where !existingListIDs.contains(listExport.id) {
            let newList = ShoppingList(
                title: listExport.title,
                createdAt: listExport.createdAt,
                completedAt: listExport.completedAt,
                status: ShoppingListStatus(rawValue: listExport.status) ?? .completed,
                storeScope: listExport.storeScope.flatMap(Store.init(rawValue:)),
                purchasedCount: listExport.purchasedCount,
                pendingCount: listExport.pendingCount,
                skippedCount: listExport.skippedCount,
                unavailableCount: listExport.unavailableCount,
                totalSpent: listExport.totalSpent,
                // Los blobs no viajan en el respaldo (nunca lo hicieron):
                // dejar el nombre apuntaría a un archivo que nunca existió
                // en este dispositivo.
                receiptImageFilename: nil,
                iconName: listExport.iconName,
                colorHex: listExport.colorHex
            )
            newList.id = listExport.id
            context.insert(newList)
        }

        // Ítems cuyo `listID` no exista ni en el archivo ni en el dispositivo
        // van a una lista de respaldo nueva, nunca con `listID == nil`: eso
        // evita que productos ya archivados reaparezcan en la compra activa
        // de mañana. `.completed` a propósito, para no contaminar ninguna
        // lista en curso ni el snapshot del widget.
        let allKnownListIDs = existingListIDs.union(export.lists.map(\.id))
        var fallbackListID: UUID?
        func fallbackList() -> UUID {
            if let fallbackListID { return fallbackListID }
            let list = ShoppingList(
                title: "Respaldo importado — \(AppDateFormatting.short(.now))",
                completedAt: .now,
                status: .completed
            )
            context.insert(list)
            fallbackListID = list.id
            return list.id
        }

        let existingItemIDs = Set(try context.fetch(FetchDescriptor<ShoppingItem>()).map(\.id))
        var touchedActiveListIDs: Set<UUID> = []
        for itemExport in export.items where !existingItemIDs.contains(itemExport.id) {
            let resolvedListID: UUID
            if let listID = itemExport.listID, allKnownListIDs.contains(listID) {
                resolvedListID = listID
            } else {
                resolvedListID = fallbackList()
            }

            let newItem = ShoppingItem(
                name: itemExport.name,
                listID: resolvedListID,
                quantity: itemExport.quantity,
                category: resolvedCategory(named: itemExport.category),
                note: itemExport.note,
                status: ShoppingItemStatus(rawValue: itemExport.status),
                sortOrder: itemExport.sortOrder,
                price: itemExport.price,
                store: Store(rawValue: itemExport.store) ?? .jumbo,
                // Los nombres de blob llegan nil por la misma razón que en las
                // listas: sin el archivo real, el botón de nota de voz solo
                // fallaría al tocarlo.
                voiceNoteFilename: nil
            )
            newItem.id = itemExport.id
            newItem.createdAt = itemExport.createdAt
            context.insert(newItem)
            touchedActiveListIDs.insert(resolvedListID)
        }

        // Catálogo: fusión por nombre normalizado, no por `id` — el
        // dispositivo destino ya sembró 355 productos sugeridos con UUIDs
        // propios; cruzar por `id` los duplicaría enteros. La fusión es
        // monótona: ningún contador baja.
        var catalogByNormalizedName: [String: ProductCatalogItem] = [:]
        for catalogItem in try context.fetch(FetchDescriptor<ProductCatalogItem>()) {
            catalogByNormalizedName[ProductNameNormalizer.normalize(catalogItem.name)] = catalogItem
        }
        for catalogExport in export.catalogItems {
            let key = ProductNameNormalizer.normalize(catalogExport.name)
            if let existing = catalogByNormalizedName[key] {
                existing.timesAdded = max(existing.timesAdded, catalogExport.timesAdded)
                if let importedDate = catalogExport.lastAddedAt {
                    existing.lastAddedAt = max(existing.lastAddedAt ?? .distantPast, importedDate)
                }
            } else {
                let newCatalogItem = ProductCatalogItem(
                    name: catalogExport.name,
                    category: resolvedCategory(named: catalogExport.category),
                    store: Store(rawValue: catalogExport.store) ?? .jumbo,
                    timesAdded: catalogExport.timesAdded,
                    lastAddedAt: catalogExport.lastAddedAt,
                    createdAt: catalogExport.createdAt
                )
                context.insert(newCatalogItem)
                catalogByNormalizedName[key] = newCatalogItem
            }
        }

        // Mismo mecanismo que CASI-031: las listas activas tocadas quedan con
        // contadores correctos en vez de heredar lo que traía (o no traía) el
        // archivo.
        if !touchedActiveListIDs.isEmpty {
            let allItemsAfter = try context.fetch(FetchDescriptor<ShoppingItem>())
            for list in try context.fetch(FetchDescriptor<ShoppingList>())
            where list.status == .active && touchedActiveListIDs.contains(list.id) {
                ShoppingListLifecycleService.updateActiveListCounters(list, items: allItemsAfter)
            }
        }

        do {
            try ShoppingPersistenceCoordinator(context: context).commit()
        } catch {
            throw ImportError.saveFailed(error.localizedDescription)
        }
        return plannedOutcome
    }
}
