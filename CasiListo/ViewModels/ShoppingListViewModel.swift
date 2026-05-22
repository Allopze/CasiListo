import SwiftUI
import SwiftData

/// Destinos modales de la lista. Mantiene una sola presentación activa.
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
final class ShoppingListViewModel {

    // MARK: - Estado de UI

    var searchText: String = ""
    var showPurchased: Bool = true
    var presentedSheet: ShoppingListSheetDestination?
    var collapsedCategories: Set<Category> = []

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

    /// Cuenta de ítems pendientes.
    func pendingCount(from items: [ShoppingItem]) -> Int {
        items.filter { !$0.isPurchased }.count
    }

    /// Cuenta de ítems comprados.
    func purchasedCount(from items: [ShoppingItem]) -> Int {
        items.filter { $0.isPurchased }.count
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
}
