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
        let exportedAt: Date
        let categories: [CategoryExport]
        let lists: [ShoppingListExport]
        let items: [ShoppingItemExport]
        let catalogItems: [ProductCatalogItemExport]
    }

    struct CategoryExport: Codable {
        let name: String
        let sfSymbol: String
        let sortIndex: Int
        let isSystem: Bool
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
            CategoryExport(name: $0.name, sfSymbol: $0.sfSymbol, sortIndex: $0.sortIndex, isSystem: $0.isSystem)
        }
        let lists = try context.fetch(FetchDescriptor<ShoppingList>()).map {
            ShoppingListExport(
                id: $0.id,
                title: $0.title,
                createdAt: $0.createdAt,
                completedAt: $0.completedAt,
                status: $0.status.rawValue,
                storeScope: $0.storeScope?.rawValue,
                purchasedCount: $0.purchasedCount,
                pendingCount: $0.pendingCount,
                skippedCount: $0.skippedCount,
                unavailableCount: $0.unavailableCount,
                totalSpent: $0.totalSpent,
                receiptImageFilename: $0.receiptImageFilename,
                iconName: $0.iconName,
                colorHex: $0.colorHex
            )
        }
        let items = try context.fetch(FetchDescriptor<ShoppingItem>()).map {
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
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ExportError.writeFailed
        }
        return url
    }
}
