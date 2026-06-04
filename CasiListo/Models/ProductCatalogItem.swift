import Foundation
import SwiftData

/// Producto frecuente separado de la lista activa. Sirve como catálogo de sugerencias
/// sin convertir cada sugerencia en un item pendiente.
@Model
final class ProductCatalogItem {
    var id: UUID
    var name: String
    var categoryRawValue: String
    var storeRawValue: String
    var timesAdded: Int
    var lastAddedAt: Date?
    var createdAt: Date

    /// Relación de categoría persistida.
    @Relationship(deleteRule: .nullify) var categoryRelation: Category?

    /// Categoría tipada, derivada de la relación o fallback.
    var category: Category {
        get { categoryRelation ?? Category.fallback }
        set {
            if newValue === Category.fallback {
                categoryRelation = nil
            } else {
                categoryRelation = newValue
            }
            categoryRawValue = newValue.name
        }
    }

    var store: Store {
        get { Store(rawValue: storeRawValue) ?? .jumbo }
        set { storeRawValue = newValue.rawValue }
    }

    init(
        name: String,
        category: Category? = nil,
        store: Store = .jumbo,
        timesAdded: Int = 0,
        lastAddedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = UUID()
        self.name = name
        self.categoryRelation = category === Category.fallback ? nil : category
        self.categoryRawValue = category?.name ?? "Varios"
        self.storeRawValue = store.rawValue
        self.timesAdded = timesAdded
        self.lastAddedAt = lastAddedAt
        self.createdAt = createdAt
    }
}

