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
    
    var categories: [Category] {
        // Solo categorías que tengan al menos un ítem pendiente
        let categoriesWithPending = Set(items.filter { !$0.isPurchased }.map { $0.category })
        // Ordenar categorías por su orden natural de enum
        return Category.allCases.filter { categoriesWithPending.contains($0) }
    }
    
    var activeCategory: Category? {
        guard activeCategoryIndex >= 0 && activeCategoryIndex < categories.count else { return nil }
        return categories[activeCategoryIndex]
    }
    
    var activeItems: [ShoppingItem] {
        guard let category = activeCategory else { return [] }
        return items.filter { $0.category == category }
            .sorted { a, b in
                if a.isPurchased != b.isPurchased {
                    return !a.isPurchased // Pendientes primero
                }
                return a.sortOrder < b.sortOrder
            }
    }
    
    // Progreso de la tienda activa
    var totalCount: Int {
        items.count
    }
    
    var purchasedCount: Int {
        items.filter { $0.isPurchased }.count
    }
    
    var pendingCount: Int {
        items.filter { !$0.isPurchased }.count
    }
    
    var progress: Double {
        guard totalCount > 0 else { return 1.0 }
        return Double(purchasedCount) / Double(totalCount)
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
        // No-op
    }
    
    func toggleItem(_ item: ShoppingItem, context: ModelContext) {
        withAnimation(.easeInOut) {
            item.isPurchased.toggle()
        }
        try? context.save()
        
        // Verificar si se completó la compra completa
        checkCompletion()
        
        if !isCompleted {
            // Verificar si se completó la categoría actual para auto-avanzar
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
        let currentCatPending = items.filter { $0.category == currentCat && !$0.isPurchased }.count
        
        if currentCatPending == 0 {
            // Esperar un momento breve para que el usuario vea el check y luego avanzar
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                withAnimation(.spring()) {
                    if activeCategoryIndex < categories.count - 1 {
                        activeCategoryIndex += 1
                    }
                }
            }
        }
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
