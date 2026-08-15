import SwiftUI
import SwiftData

/// Destinos modales de la lista. Mantiene una sola presentación activa.
@MainActor
enum ShoppingListSheetDestination: Identifiable {
    case addItem
    case editItem(ShoppingItem)
    case settings
    case history
    case receipt(closesPurchase: Bool)
    case textImporter
    case templates

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
        case .receipt(let closesPurchase):
            return closesPurchase ? "receipt-closing" : "receipt"
        case .textImporter:
            return "text-importer"
        case .templates:
            return "templates"
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
    var quickAddText: String = ""
    var showUndoToast: Bool = false
    var persistenceErrorMessage: String?
    @ObservationIgnored var deletedItemUndoBuffer: (name: String, quantity: String, category: Category, store: Store, note: String, isPurchased: Bool, status: ShoppingItemStatus, sortOrder: Int, price: Double?, voiceNoteFilename: String?, listID: UUID?)? = nil
    @ObservationIgnored private var undoTimerTask: Task<Void, Never>? = nil
    /// Categorías que la persona usuaria ha contraído en esta sesión.
    /// Debe permanecer observable: la vista consulta este estado para decidir
    /// si muestra los productos de cada tarjeta.
    private var collapsedCategories: Set<String> = []
    @ObservationIgnored private var hasInitializedCategoryCollapseState = false

    // MARK: - Snapshot derivado

    /// Grupos cacheados — actualizados explícitamente desde la vista para no
    /// recalcular en cada re-render. La vista llama `updateDerivedState` al
    /// cambiar items, categorías o filtros.
    private(set) var derivedGroups: [(category: Category, items: [ShoppingItem])] = []
    private(set) var derivedSummary: ListSummary = ListSummary(pendingCount: 0, purchasedCount: 0, skippedCount: 0, unavailableCount: 0)

    @ObservationIgnored private var latestItems: [ShoppingItem] = []
    @ObservationIgnored private var latestCategories: [Category] = []

    func updateDerivedState(items: [ShoppingItem], categories: [Category]) {
        PerformanceSignpost.measure("Recalcular lista") {
            let previousItemIDs = Set(latestItems.map(\.id))
            latestItems = items
            latestCategories = categories

            if hasInitializedCategoryCollapseState {
                let newCategories = items
                    .filter { !previousItemIDs.contains($0.id) }
                    .map { $0.category.name }
                collapsedCategories.subtract(newCategories)
            } else if !items.isEmpty && !categories.isEmpty {
                collapsedCategories = Set(categories.map(\.name))
                hasInitializedCategoryCollapseState = true
            }

            recomputeSnapshot()
        }
    }

    func rederiveFilters() {
        PerformanceSignpost.measure("Aplicar filtros") {
            recomputeSnapshot()
        }
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
            // Filtro de comprado
            if item.status == .purchased && !showPurchased {
                return false
            }
            // Filtro de búsqueda
            if !searchText.isEmpty {
                return ProductNameNormalizer.contains(item.name, query: searchText)
                    || ProductNameNormalizer.contains(item.note, query: searchText)
                    || ProductNameNormalizer.contains(item.category.displayName, query: searchText)
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
        let previousStatus = item.status
        item.status = item.status == .purchased ? .pending : .purchased
        defer {
            // Mutar una propiedad no cambia la identidad del array de @Query,
            // así que onChange(of: allItems) no dispara: recalcular aquí.
            rederiveFilters()
        }
        guard let context else { return }
        do {
            try ShoppingPersistenceCoordinator(context: context).commit(itemsForWidget: latestItems)
            HapticFeedback.success()
        } catch {
            item.status = previousStatus
            presentPersistenceError(error)
        }
    }

    func markItem(_ item: ShoppingItem, as status: ShoppingItemStatus, context: ModelContext? = nil) {
        let previousStatus = item.status
        item.status = status
        defer {
            rederiveFilters()
        }
        guard let context else { return }
        do {
            try ShoppingPersistenceCoordinator(context: context).commit(itemsForWidget: latestItems)
            HapticFeedback.success()
        } catch {
            item.status = previousStatus
            presentPersistenceError(error)
        }
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

    func presentReceipt(closesPurchase: Bool = false) {
        presentedSheet = .receipt(closesPurchase: closesPurchase)
    }

    func presentTextImporter() {
        presentedSheet = .textImporter
    }

    func presentTemplates() {
        presentedSheet = .templates
    }

    func isCategoryCollapsed(_ category: Category, forceExpanded: Bool = false) -> Bool {
        !forceExpanded && collapsedCategories.contains(category.name)
    }

    func toggleCategoryCollapse(_ category: Category) {
        if collapsedCategories.contains(category.name) {
            collapsedCategories.remove(category.name)
        } else {
            collapsedCategories.insert(category.name)
        }
    }

    func resetCategoryCollapseState() {
        collapsedCategories.removeAll()
        hasInitializedCategoryCollapseState = false
    }

    /// Elimina un ítem con soporte de Deshacer (Undo).
    func deleteItem(_ item: ShoppingItem, context: ModelContext) {
        finalizePendingUndo()
        let buffer = (
            name: item.name,
            quantity: item.quantity,
            category: item.category,
            store: item.store,
            note: item.note,
            isPurchased: item.isPurchased,
            status: item.status,
            sortOrder: item.sortOrder,
            price: item.price,
            voiceNoteFilename: item.voiceNoteFilename,
            listID: item.listID
        )
        do {
            try ShoppingPersistenceCoordinator(context: context).deleteItem(
                item,
                remainingItems: latestItems.filter { $0.id != item.id }
            )
        } catch {
            presentPersistenceError(error)
            return
        }

        deletedItemUndoBuffer = buffer

        withAnimation(Theme.defaultAnimation) {
            showUndoToast = true
        }

        undoTimerTask?.cancel()
        undoTimerTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self.finalizePendingUndo()
        }
    }

    /// Restaura el último producto eliminado.
    func undoLastDelete(context: ModelContext) {
        guard let buffer = deletedItemUndoBuffer else { return }
        let restoredItem = ShoppingItem(
            name: buffer.name,
            listID: buffer.listID,
            quantity: buffer.quantity,
            category: buffer.category,
            note: buffer.note,
            isPurchased: buffer.isPurchased,
            status: buffer.status,
            sortOrder: buffer.sortOrder,
            price: buffer.price,
            store: buffer.store,
            voiceNoteFilename: buffer.voiceNoteFilename
        )
        do {
            context.insert(restoredItem)
            try ShoppingPersistenceCoordinator(context: context).saveItem(
                restoredItem,
                allActiveItems: latestItems + [restoredItem]
            )
        } catch {
            presentPersistenceError(error)
            return
        }

        withAnimation(Theme.defaultAnimation) {
            showUndoToast = false
            deletedItemUndoBuffer = nil
        }
        HapticFeedback.success()
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
            do {
                try ShoppingPersistenceCoordinator(context: context).commit(itemsForWidget: latestItems)
                quickAddText = ""
                HapticFeedback.success()
            } catch {
                presentPersistenceError(error)
            }
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
        }
        do {
            try ShoppingPersistenceCoordinator(context: context).commit(itemsForWidget: allItems + [newItem])
            quickAddText = ""
            HapticFeedback.success()
        } catch {
            presentPersistenceError(error)
        }
    }

    /// Busca un producto equivalente dentro de la lista activa para evitar duplicados accidentales.
    func duplicateItem(
        named name: String,
        store: Store,
        in items: [ShoppingItem],
        excluding excludedID: UUID? = nil
    ) -> ShoppingItem? {
        DuplicatePolicy.duplicate(named: name, store: store, in: items, excluding: excludedID)
    }

    func normalizedProductName(_ value: String) -> String {
        ProductNameNormalizer.normalize(value)
    }

    /// Calcula el siguiente sortOrder disponible para una categoría.
    func nextSortOrder(for category: Category, in items: [ShoppingItem]) -> Int {
        let categoryItems = items.filter { $0.category.name == category.name }
        let maxOrder = categoryItems.map(\.sortOrder).max() ?? -1
        return maxOrder + 1
    }

    func presentPersistenceError(_ error: Error) {
        persistenceErrorMessage = error.localizedDescription
    }

    private func finalizePendingUndo() {
        undoTimerTask?.cancel()
        undoTimerTask = nil
        if let filename = deletedItemUndoBuffer?.voiceNoteFilename {
            try? LocalFileStore.shared.deleteVoiceNote(named: filename)
        }
        withAnimation(Theme.defaultAnimation) {
            showUndoToast = false
            deletedItemUndoBuffer = nil
        }
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
