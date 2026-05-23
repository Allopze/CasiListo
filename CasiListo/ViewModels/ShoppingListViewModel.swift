import SwiftUI
import SwiftData

/// Destinos modales de la lista. Mantiene una sola presentación activa.
@MainActor
enum ShoppingListSheetDestination: Identifiable {
    case addItem
    case editItem(ShoppingItem)
    case settings

    var id: String {
        switch self {
        case .addItem:
            return "add-item"
        case .editItem(let item):
            return "edit-\(item.id.uuidString)"
        case .settings:
            return "settings"
        }
    }
}

/// ViewModel principal que centraliza la lógica de la lista de compra.
@Observable
@MainActor
final class ShoppingListViewModel {

    // MARK: - Estado de UI

    var searchText: String = ""
    var showPurchased: Bool = true
    var presentedSheet: ShoppingListSheetDestination?
    var collapsedCategories: Set<Category> = []
    var quickAddText: String = ""

    // MARK: - Filtrado y agrupación

    /// Agrupa los ítems visibles por categoría, respetando filtros de búsqueda y estado.
    /// Retorna solo las categorías que tienen ítems.
    func groupedItems(from items: [ShoppingItem]) -> [(category: Category, items: [ShoppingItem])] {
        let filtered = items.filter { item in
            // Filtro de comprado
            if !showPurchased && item.isPurchased {
                return false
            }
            // Filtro de búsqueda
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                return item.name.lowercased().contains(query)
                    || item.note.lowercased().contains(query)
                    || item.category.displayName.lowercased().contains(query)
            }
            return true
        }

        // Agrupar por categoría
        let grouped = Dictionary(grouping: filtered) { $0.category }

        // Ordenar categorías por sortIndex, y dentro de cada categoría por sortOrder y luego nombre
        return Category.allCases
            .compactMap { category in
                guard let items = grouped[category], !items.isEmpty else { return nil }
                let sorted = items.sorted { a, b in
                    if a.isPurchased != b.isPurchased {
                        return !a.isPurchased // Pendientes primero
                    }
                    if a.sortOrder != b.sortOrder {
                        return a.sortOrder < b.sortOrder
                    }
                    return a.name.localizedCompare(b.name) == .orderedAscending
                }
                return (category: category, items: sorted)
            }
    }

    /// Conteos de ítems en un solo pase.
    struct ItemCounts {
        let pending: Int
        let purchased: Int
    }

    /// Calcula pendientes y comprados en un único recorrido del array.
    func itemCounts(from items: [ShoppingItem]) -> ItemCounts {
        var pending = 0, purchased = 0
        for item in items {
            if item.isPurchased { purchased += 1 } else { pending += 1 }
        }
        return ItemCounts(pending: pending, purchased: purchased)
    }

    // MARK: - Acciones

    /// Alterna el estado de comprado de un ítem.
    func togglePurchased(_ item: ShoppingItem) {
        item.isPurchased.toggle()
    }

    func presentAddItem() {
        presentedSheet = .addItem
    }

    func presentEditItem(_ item: ShoppingItem) {
        presentedSheet = .editItem(item)
    }

    func presentSettings() {
        presentedSheet = .settings
    }

    func isCategoryCollapsed(_ category: Category) -> Bool {
        collapsedCategories.contains(category)
    }

    func toggleCategoryCollapse(_ category: Category) {
        if collapsedCategories.contains(category) {
            collapsedCategories.remove(category)
        } else {
            collapsedCategories.insert(category)
        }
    }

    /// Elimina un ítem del contexto.
    func deleteItem(_ item: ShoppingItem, context: ModelContext) {
        context.delete(item)
    }

    /// Elimina todos los ítems marcados como comprados.
    func clearPurchased(items: [ShoppingItem], context: ModelContext) {
        for item in items where item.isPurchased {
            context.delete(item)
        }
    }

    /// Calcula el siguiente sortOrder disponible para una categoría.
    func nextSortOrder(for category: Category, in items: [ShoppingItem]) -> Int {
        let categoryItems = items.filter { $0.category == category }
        let maxOrder = categoryItems.map(\.sortOrder).max() ?? -1
        return maxOrder + 1
    }

    /// Reordena los ítems dentro de una categoría y actualiza sus valores de `sortOrder`.
    func moveItem(from source: IndexSet, to destination: Int, within items: [ShoppingItem], context: ModelContext) {
        var mutableItems = items
        mutableItems.move(fromOffsets: source, toOffset: destination)
        for (index, item) in mutableItems.enumerated() {
            item.sortOrder = index
        }
        try? context.save()
    }

    /// Calcula la suma de precios de todos los artículos pendientes.
    func pendingTotal(from items: [ShoppingItem]) -> Double {
        items.filter { !$0.isPurchased }.compactMap(\.price).reduce(0, +)
    }

    /// Calcula la suma de precios de todos los artículos comprados.
    func purchasedTotal(from items: [ShoppingItem]) -> Double {
        items.filter { $0.isPurchased }.compactMap(\.price).reduce(0, +)
    }

    /// Calcula el costo total general de la lista.
    func grandTotal(from items: [ShoppingItem]) -> Double {
        items.compactMap(\.price).reduce(0, +)
    }
}
