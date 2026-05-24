import Foundation
import SwiftUI
import SwiftData

/// ViewModel que gestiona el estado y la lógica de una sesión de compra activa.
@Observable
@MainActor
final class ShoppingModeViewModel {
    let store: Store
    var items: [ShoppingItem] = []
    
    // Navegación de categorías
    var activeCategoryIndex: Int = 0
    var isCompleted: Bool = false
    @ObservationIgnored private var autoAdvanceTask: Task<Void, Never>? = nil
    
    var categories: [Category] {
        // Solo categorías que tengan al menos un ítem pendiente
        let categoriesWithPending = Set(items.filter { $0.status == .pending }.map { $0.category })
        // Ordenar categorías por su orden natural de enum
        return Category.allCases.filter { categoriesWithPending.contains($0) }
    }
    
    var activeCategory: Category? {
        guard activeCategoryIndex >= 0 && activeCategoryIndex < categories.count else { return nil }
        return categories[activeCategoryIndex]
    }
    
    var activeItems: [ShoppingItem] {
        guard let category = activeCategory else { return [] }
        return items.filter { $0.category == category && $0.status != .purchased }
            .sorted { a, b in
                if a.status != b.status {
                    return a.status.isActionableInShoppingMode && !b.status.isActionableInShoppingMode
                }
                return a.sortOrder < b.sortOrder
            }
    }
    
    // Progreso de la tienda activa
    var totalCount: Int {
        items.count
    }
    
    var purchasedCount: Int {
        items.filter { $0.status == .purchased }.count
    }
    
    var pendingCount: Int {
        items.filter { $0.status == .pending }.count
    }
    
    var progress: Double {
        guard totalCount > 0 else { return 1.0 }
        return Double(purchasedCount) / Double(totalCount)
    }

    struct CategoryProgress {
        let purchased: Int
        let total: Int
    }
    
    init(store: Store, allItems: [ShoppingItem]) {
        self.store = store
        self.items = allItems.filter { $0.store == store }
        
        // Inicializar el índice de categoría activa
        if !categories.isEmpty {
            self.activeCategoryIndex = 0
        }
    }
    
    func startSession() {
        isCompleted = false
    }
    
    func stopSession() {
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
    }
    
    func toggleItem(_ item: ShoppingItem, context: ModelContext) {
        withAnimation(.easeInOut) {
            item.status = item.status == .purchased ? .pending : .purchased
        }
        try? context.save()
        
        // Verificar si se completó la compra completa
        checkCompletion()
        
        if !isCompleted {
            // Verificar si se completó la categoría actual para auto-avanzar
            checkAutoAdvance()
        }
    }

    func markItem(_ item: ShoppingItem, as status: ShoppingItemStatus, context: ModelContext) {
        withAnimation(.easeInOut) {
            item.status = status
        }
        try? context.save()
        checkCompletion()
        if !isCompleted {
            checkAutoAdvance()
        }
    }
    
    private func checkCompletion() {
        // Se considera completado cuando todos los ítems de esta tienda están comprados
        if pendingCount == 0 && totalCount > 0 {
            withAnimation(.spring()) {
                isCompleted = true
            }
        }
    }
    
    private func checkAutoAdvance() {
        guard let currentCat = activeCategory else { return }
        let currentCatPending = items.filter { $0.category == currentCat && $0.status == .pending }.count
        
        if currentCatPending == 0 {
            autoAdvanceTask?.cancel()
            // Esperar un momento breve para que el usuario vea el check y luego avanzar
            autoAdvanceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                guard activeCategory == currentCat else { return }
                withAnimation(.spring()) {
                    if activeCategoryIndex < categories.count - 1 {
                        activeCategoryIndex += 1
                    }
                }
            }
        }
    }

    func categoryProgress(for category: Category) -> CategoryProgress {
        var purchased = 0
        var total = 0

        for item in items where item.category == category {
            total += 1
            if item.status == .purchased {
                purchased += 1
            }
        }

        return CategoryProgress(purchased: purchased, total: total)
    }
    
    func nextCategory() {
        if activeCategoryIndex < categories.count - 1 {
            withAnimation(.spring()) {
                activeCategoryIndex += 1
            }
        }
    }
    
    func previousCategory() {
        if activeCategoryIndex > 0 {
            withAnimation(.spring()) {
                activeCategoryIndex -= 1
            }
        }
    }
}
