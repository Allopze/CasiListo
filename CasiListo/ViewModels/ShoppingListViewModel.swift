import SwiftUI
import SwiftData

/// Destinos modales de la lista. Mantiene una sola presentación activa.
@MainActor
enum ShoppingListSheetDestination: Identifiable {
    case addItem
    case editItem(ShoppingItem)
    case settings
    case history

    var id: String {
        switch self {
        case .addItem:
            return "add-item"
        case .editItem(let item):
            return "edit-\(item.id.uuidString)"
        case .settings:
            return "settings"
        case .history:
            return "history"
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
    var selectedStore: Store? = nil
    var presentedSheet: ShoppingListSheetDestination?
    var collapsedCategories: Set<String> = []
    var quickAddText: String = ""

    // MARK: - Filtrado y agrupación

    /// Agrupa los ítems visibles por categoría, respetando filtros de búsqueda y estado.
    /// Retorna solo las categorías que tienen ítems.
    func groupedItems(from items: [ShoppingItem], categories: [Category]) -> [(category: Category, items: [ShoppingItem])] {
        let filtered = items.filter { item in
            // Filtro de supermercado
            if let selectedStore = selectedStore, item.store != selectedStore {
                return false
            }
            if item.status == .purchased && !showPurchased {
                return false
            }
            // Filtro de comprado
            if !showPurchased && item.status == .purchased {
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
        let grouped = Dictionary(grouping: filtered) { $0.category.name }

        // Ordenar categorías por sortIndex, y dentro de cada categoría por sortOrder y luego nombre
        return categories
            .compactMap { category in
                guard let items = grouped[category.name], !items.isEmpty else { return nil }
                let sorted = items.sorted { a, b in
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

    struct ListSummary {
        let pendingCount: Int
        let purchasedCount: Int
        let pendingTotal: Double
        let purchasedTotal: Double
        let skippedCount: Int
        let unavailableCount: Int

        var counts: ItemCounts {
            ItemCounts(pending: pendingCount, purchased: purchasedCount)
        }
    }

    struct QuickAddDraft {
        let name: String
        let quantity: String
    }

    /// Calcula conteos y totales visibles en un solo recorrido.
    func summary(from items: [ShoppingItem]) -> ListSummary {
        var pendingCount = 0
        var purchasedCount = 0
        var skippedCount = 0
        var unavailableCount = 0
        var pendingTotal = 0.0
        var purchasedTotal = 0.0

        for item in items {
            if let selectedStore = selectedStore, item.store != selectedStore {
                continue
            }

            switch item.status {
            case .purchased:
                purchasedCount += 1
                purchasedTotal += item.price ?? 0
            case .pending:
                pendingCount += 1
                pendingTotal += item.price ?? 0
            case .skipped:
                skippedCount += 1
            case .unavailable:
                unavailableCount += 1
            }
        }

        return ListSummary(
            pendingCount: pendingCount,
            purchasedCount: purchasedCount,
            pendingTotal: pendingTotal,
            purchasedTotal: purchasedTotal,
            skippedCount: skippedCount,
            unavailableCount: unavailableCount
        )
    }

    /// Calcula pendientes y comprados en un único recorrido del array.
    func itemCounts(from items: [ShoppingItem]) -> ItemCounts {
        summary(from: items).counts
    }

    /// Interpreta entradas rapidas como "2 leche", "pan x3" o "tomates 1 kg".
    func quickAddDraft(from text: String) -> QuickAddDraft {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ").map(String.init)
        guard parts.count > 1 else {
            return QuickAddDraft(name: trimmed, quantity: "")
        }

        if let draft = parseTrailingMultiplier(parts) {
            return draft
        }

        if let draft = parseLeadingQuantity(parts) {
            return draft
        }

        if let draft = parseTrailingQuantity(parts) {
            return draft
        }

        return QuickAddDraft(name: trimmed, quantity: "")
    }

    // MARK: - Acciones

    /// Alterna el estado de comprado de un ítem.
    func togglePurchased(_ item: ShoppingItem) {
        item.status = item.status == .purchased ? .pending : .purchased
    }

    func markItem(_ item: ShoppingItem, as status: ShoppingItemStatus) {
        item.status = status
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

    func presentHistory() {
        presentedSheet = .history
    }

    func isCategoryCollapsed(_ category: Category) -> Bool {
        collapsedCategories.contains(category.name)
    }

    func toggleCategoryCollapse(_ category: Category) {
        if collapsedCategories.contains(category.name) {
            collapsedCategories.remove(category.name)
        } else {
            collapsedCategories.insert(category.name)
        }
    }

    /// Elimina un ítem del contexto.
    func deleteItem(_ item: ShoppingItem, context: ModelContext) {
        context.delete(item)
    }

    /// Elimina todos los ítems marcados como comprados.
    func clearPurchased(items: [ShoppingItem], context: ModelContext) {
        for item in items where item.isPurchased {
            if let selectedStore = selectedStore, item.store != selectedStore {
                continue
            }
            context.delete(item)
        }
    }

    func clearPurchased(in items: [ShoppingItem], context: ModelContext) {
        for item in items where item.isPurchased {
            context.delete(item)
        }
    }

    /// Calcula el siguiente sortOrder disponible para una categoría.
    func nextSortOrder(for category: Category, in items: [ShoppingItem]) -> Int {
        let categoryItems = items.filter { $0.category.name == category.name }
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
        context.safeSave()
    }

    /// Calcula la suma de precios de todos los artículos pendientes.
    func pendingTotal(from items: [ShoppingItem]) -> Double {
        summary(from: items).pendingTotal
    }

    /// Calcula la suma de precios de todos los artículos comprados.
    func purchasedTotal(from items: [ShoppingItem]) -> Double {
        summary(from: items).purchasedTotal
    }

    /// Calcula el costo total general de la lista.
    func grandTotal(from items: [ShoppingItem]) -> Double {
        items.filter { item in
            if let selectedStore = selectedStore, item.store != selectedStore {
                return false
            }
            return true
        }.compactMap(\.price).reduce(0, +)
    }

    private func parseTrailingMultiplier(_ parts: [String]) -> QuickAddDraft? {
        guard let last = parts.last else { return nil }

        if last.lowercased().hasPrefix("x") {
            let amount = String(last.dropFirst())
            guard isNumberLike(amount), parts.count > 1 else { return nil }
            let name = parts.dropLast().joined(separator: " ")
            return QuickAddDraft(name: name, quantity: amount.normalizedDecimalSeparator)
        }

        if parts.count > 2, parts[parts.count - 2].lowercased() == "x", isNumberLike(last) {
            let name = parts.dropLast(2).joined(separator: " ")
            guard !name.isEmpty else { return nil }
            return QuickAddDraft(name: name, quantity: last.normalizedDecimalSeparator)
        }

        return nil
    }

    private func parseLeadingQuantity(_ parts: [String]) -> QuickAddDraft? {
        guard let first = parts.first, isNumberLike(first) else { return nil }

        var quantity = first.normalizedDecimalSeparator
        var nameStartIndex = 1

        if parts.count > 2, isUnit(parts[1]) {
            quantity += " \(parts[1])"
            nameStartIndex = 2
        }

        let name = parts.dropFirst(nameStartIndex).joined(separator: " ")
        guard !name.isEmpty else { return nil }
        return QuickAddDraft(name: name, quantity: quantity)
    }

    private func parseTrailingQuantity(_ parts: [String]) -> QuickAddDraft? {
        guard let last = parts.last else { return nil }

        if isUnit(last), parts.count > 2 {
            let previous = parts[parts.count - 2]
            guard isNumberLike(previous) else { return nil }
            let name = parts.dropLast(2).joined(separator: " ")
            guard !name.isEmpty else { return nil }
            return QuickAddDraft(name: name, quantity: "\(previous.normalizedDecimalSeparator) \(last)")
        }

        guard isNumberWithUnit(last), parts.count > 1 else { return nil }
        let name = parts.dropLast().joined(separator: " ")
        return QuickAddDraft(name: name, quantity: last.normalizedDecimalSeparator)
    }

    private func isNumberLike(_ value: String) -> Bool {
        Double(value.normalizedDecimalSeparator) != nil
    }

    private func isNumberWithUnit(_ value: String) -> Bool {
        let lowered = value.lowercased()
        return ["kg", "g", "l", "lt", "ml"].contains { unit in
            lowered.hasSuffix(unit) && isNumberLike(String(lowered.dropLast(unit.count)))
        }
    }

    private func isUnit(_ value: String) -> Bool {
        ["kg", "g", "l", "lt", "ml", "u", "un", "uds", "unidad", "unidades"].contains(value.lowercased())
    }
}

private extension String {
    var normalizedDecimalSeparator: String {
        replacingOccurrences(of: ",", with: ".")
    }
}
