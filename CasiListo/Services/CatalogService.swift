import Foundation
import SwiftData

/// Operaciones entre el catálogo de productos y la lista de compra activa.
@MainActor
enum CatalogService {

    /// Añade un producto del catálogo a la lista activa. Si ya existe un
    /// equivalente, no hace nada: la fila del catálogo ya comunica el estado.
    @discardableResult
    static func addToActiveList(
        _ catalogItem: ProductCatalogItem,
        activeList: ShoppingList?,
        activeItems: [ShoppingItem],
        context: ModelContext
    ) throws -> ShoppingItem? {
        guard !DuplicatePolicy.isDuplicate(
            named: catalogItem.name,
            store: catalogItem.store,
            in: activeItems
        ) else { return nil }

        let item = ShoppingItem(
            name: catalogItem.name,
            listID: activeList?.id,
            category: catalogItem.category,
            sortOrder: nextSortOrder(for: catalogItem.category, in: activeItems),
            store: catalogItem.store
        )
        context.insert(item)
        catalogItem.timesAdded += 1
        catalogItem.lastAddedAt = .now

        if let activeList {
            ShoppingListLifecycleService.updateActiveListCounters(activeList, items: activeItems + [item])
        }
        try ShoppingPersistenceCoordinator(context: context).commit()
        return item
    }

    /// Quita de la lista activa el ítem pendiente equivalente a un producto del
    /// catálogo (toggle simétrico estilo Recordatorios).
    static func removeFromActiveList(
        _ catalogItem: ProductCatalogItem,
        activeList: ShoppingList?,
        activeItems: [ShoppingItem],
        context: ModelContext
    ) throws {
        let normalized = ProductNameNormalizer.normalize(catalogItem.name)
        guard let match = activeItems.first(where: {
            $0.status == .pending && ProductNameNormalizer.normalize($0.name) == normalized
        }) else { return }

        context.delete(match)
        let remaining = activeItems.filter { $0.id != match.id }
        if let activeList {
            ShoppingListLifecycleService.updateActiveListCounters(activeList, items: remaining)
        }
        try ShoppingPersistenceCoordinator(context: context).commit()
    }

    /// Registra en el catálogo un producto añadido manualmente para que el
    /// catálogo aprenda los productos propios del usuario. No guarda por sí
    /// mismo: el flujo que llama es responsable del commit.
    static func recordAddition(
        name: String,
        category: Category?,
        store: Store,
        context: ModelContext
    ) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = ProductNameNormalizer.normalize(trimmed)
        guard !normalized.isEmpty else { return }

        // Reusar match() en vez de un fetch completo redundante.
        if let existing = match(named: trimmed, context: context) {
            existing.timesAdded += 1
            existing.lastAddedAt = .now
        } else {
            let entry = ProductCatalogItem(
                name: trimmed,
                category: category,
                store: store,
                timesAdded: 1,
                lastAddedAt: .now
            )
            context.insert(entry)
        }
    }

    /// Siguiente sortOrder disponible dentro de una categoría.
    nonisolated static func nextSortOrder(for category: Category, in items: [ShoppingItem]) -> Int {
        let categoryItems = items.filter { $0.category.name == category.name }
        return (categoryItems.map(\.sortOrder).max() ?? -1) + 1
    }

    /// Sugerencias de autocompletado desde el catálogo, ordenadas por uso
    /// (los productos que más agregas aparecen primero).
    nonisolated static func suggestions(for text: String, in catalogItems: [ProductCatalogItem]) -> [String] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return catalogItems
            .filter { ProductNameNormalizer.contains($0.name, query: text) }
            .sorted {
                if $0.timesAdded != $1.timesAdded { return $0.timesAdded > $1.timesAdded }
                return $0.name.localizedCompare($1.name) == .orderedAscending
            }
            .map(\.name)
    }

    /// Entrada del catálogo cuyo nombre normalizado coincide exactamente.
    static func match(named name: String, context: ModelContext) -> ProductCatalogItem? {
        let normalized = ProductNameNormalizer.normalize(name)
        guard !normalized.isEmpty else { return nil }
        let items = (try? context.fetch(FetchDescriptor<ProductCatalogItem>())) ?? []
        return items.first { ProductNameNormalizer.normalize($0.name) == normalized }
    }
}
