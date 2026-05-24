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

    // MARK: - Snapshot derivado

    /// Grupos cacheados — actualizados explícitamente desde la vista para no
    /// recalcular en cada re-render. La vista llama `updateDerivedState` al
    /// cambiar items, categorías o filtros.
    private(set) var derivedGroups: [(category: Category, items: [ShoppingItem])] = []
    private(set) var derivedSummary: ListSummary = ListSummary(pendingCount: 0, purchasedCount: 0, skippedCount: 0, unavailableCount: 0)

    @ObservationIgnored private var latestItems: [ShoppingItem] = []
    @ObservationIgnored private var latestCategories: [Category] = []

    func updateDerivedState(items: [ShoppingItem], categories: [Category]) {
        latestItems = items
        latestCategories = categories
        recomputeSnapshot()
    }

    func rederiveFilters() {
        recomputeSnapshot()
    }

    private func recomputeSnapshot() {
        derivedGroups = groupedItems(from: latestItems, categories: latestCategories)
        derivedSummary = summary(from: latestItems)
    }

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

        // Ordenar categorías e ítems alfabéticamente
        return categories
            .compactMap { category in
                guard let items = grouped[category.name], !items.isEmpty else { return nil }
                let sorted = items.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
                return (category: category, items: sorted)
            }
            .sorted { $0.category.name.localizedCompare($1.category.name) == .orderedAscending }
    }

    /// Conteos de ítems en un solo pase.
    struct ItemCounts {
        let pending: Int
        let purchased: Int
    }

    struct ListSummary {
        let pendingCount: Int
        let purchasedCount: Int
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

    /// Calcula conteos visibles en un solo recorrido.
    func summary(from items: [ShoppingItem]) -> ListSummary {
        var pendingCount = 0
        var purchasedCount = 0
        var skippedCount = 0
        var unavailableCount = 0

        for item in items {
            if let selectedStore = selectedStore, item.store != selectedStore {
                continue
            }

            switch item.status {
            case .purchased:
                purchasedCount += 1
            case .pending:
                pendingCount += 1
            case .skipped:
                skippedCount += 1
            case .unavailable:
                unavailableCount += 1
            }
        }

        return ListSummary(
            pendingCount: pendingCount,
            purchasedCount: purchasedCount,
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
    func togglePurchased(_ item: ShoppingItem, context: ModelContext? = nil) {
        item.status = item.status == .purchased ? .pending : .purchased
        context?.safeSave()
    }

    func markItem(_ item: ShoppingItem, as status: ShoppingItemStatus, context: ModelContext? = nil) {
        item.status = status
        context?.safeSave()
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
        context.safeSave()
    }

    func addQuickItem(
        to activeList: ShoppingList?,
        from allItems: [ShoppingItem],
        categories: [Category],
        context: ModelContext
    ) {
        let draft = quickAddDraft(from: quickAddText)
        guard !draft.name.isEmpty else { return }

        let category = SuggestedProducts.suggestedCategory(for: draft.name, in: categories)
            ?? categories.first { $0.name == "Varios" }
            ?? Category.fallback
        let store = selectedStore ?? SuggestedProducts.suggestedStore(for: draft.name)

        if let duplicate = duplicateItem(named: draft.name, store: store, in: allItems) {
            if duplicate.quantity.isEmpty && !draft.quantity.isEmpty {
                duplicate.quantity = draft.quantity
            }
            quickAddText = ""
            context.safeSave()
            HapticFeedback.selection()
            return
        }

        let newItem = ShoppingItem(
            name: draft.name,
            listID: activeList?.id,
            quantity: draft.quantity,
            category: category,
            note: "",
            isPurchased: false,
            sortOrder: nextSortOrder(for: category, in: allItems),
            store: store
        )
        withAnimation(Theme.defaultAnimation) {
            context.insert(newItem)
            if let activeList {
                ShoppingListLifecycleService.updateActiveListCounters(activeList, items: allItems + [newItem])
            }
            quickAddText = ""
            context.safeSave()
        }
        HapticFeedback.success()
    }

    /// Busca un producto equivalente dentro de la lista activa para evitar duplicados accidentales.
    func duplicateItem(
        named name: String,
        store: Store,
        in items: [ShoppingItem],
        excluding excludedID: UUID? = nil
    ) -> ShoppingItem? {
        let normalizedName = normalizedProductName(name)
        guard !normalizedName.isEmpty else { return nil }

        return items.first { item in
            item.id != excludedID
                && item.store == store
                && normalizedProductName(item.name) == normalizedName
        }
    }

    func normalizedProductName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    /// Calcula el siguiente sortOrder disponible para una categoría.
    func nextSortOrder(for category: Category, in items: [ShoppingItem]) -> Int {
        let categoryItems = items.filter { $0.category.name == category.name }
        let maxOrder = categoryItems.map(\.sortOrder).max() ?? -1
        return maxOrder + 1
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
