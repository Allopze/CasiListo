import Foundation

/// Exporta el historial de compras como CSV.
///
/// Antes vivía como una función privada dentro de `ShoppingHistoryView`, sin
/// ningún test, y se compartía como `String` vía `ShareLink(item:)` — eso no
/// ofrece "Guardar en Archivos", solo destinos de texto (CASI-005). Aquí
/// también se resuelve la construcción de filas, testeable con arrays planos.
///
/// `@MainActor`, no `nonisolated`, porque usa `AppDateFormatting`, que vive en
/// el target de la app (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
@MainActor
enum HistoryCSVExportService {
    static let header = ["Fecha", "Lista", "Supermercado", "Producto", "Cantidad", "Categoria", "Estado", "Precio"]

    /// Solo listas completadas, en el orden en que se pasen. Los ítems se
    /// agrupan por `listID`: archivar nunca borra un `ShoppingItem`, solo le
    /// cambia la lista.
    static func rows(completedLists: [ShoppingList], items: [ShoppingItem]) -> [[String]] {
        let itemsByListID = Dictionary(grouping: items, by: \.listID)
        var rows = [header]
        for list in completedLists {
            let dateStr = AppDateFormatting.numericWithTime(list.completedAt ?? list.createdAt)
            let storeStr = list.storeScope?.displayName ?? "Todos"

            for item in itemsByListID[list.id] ?? [] {
                let priceStr = item.price.map { String($0) } ?? ""
                rows.append([dateStr, list.title, storeStr, item.name, item.quantity, item.category.name, item.status.rawValue, priceStr])
            }
        }
        return rows
    }

    static func document(completedLists: [ShoppingList], items: [ShoppingItem]) -> String {
        CSVSerializer.document(rows: rows(completedLists: completedLists, items: items))
    }

    /// Mismo contrato que `DataExportService.exportFile`: archivo temporal con
    /// fecha en el nombre y escritura atómica. Compartir el texto suelto no
    /// ofrecía "Guardar en Archivos"; un `URL` de archivo sí.
    static func exportFile(completedLists: [ShoppingList], items: [ShoppingItem]) throws -> URL {
        let csv = document(completedLists: completedLists, items: items)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let url = FileManager.default.temporaryDirectory
            .appending(path: "CasiListo-historial-\(formatter.string(from: .now)).csv")
        // Ver el comentario equivalente en DataExportService.exportFile (CASI-021).
        DataExportService.removeStaleExports(prefix: "CasiListo-historial-", extension: "csv")
        do {
            try Data(csv.utf8).write(to: url, options: .atomic)
        } catch {
            throw DataExportService.ExportError.writeFailed
        }
        return url
    }
}
