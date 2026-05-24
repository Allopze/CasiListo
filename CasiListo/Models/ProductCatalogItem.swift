import Foundation
import SwiftData

/// Producto frecuente separado de la lista activa. Sirve como catalogo de sugerencias
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

    var category: Category {
        get { Category(rawValue: categoryRawValue) ?? .varios }
        set { categoryRawValue = newValue.rawValue }
    }

    var store: Store {
        get { Store(rawValue: storeRawValue) ?? .jumbo }
        set { storeRawValue = newValue.rawValue }
    }

    init(
        name: String,
        category: Category,
        store: Store = .jumbo,
        timesAdded: Int = 0,
        lastAddedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = UUID()
        self.name = name
        self.categoryRawValue = category.rawValue
        self.storeRawValue = store.rawValue
        self.timesAdded = timesAdded
        self.lastAddedAt = lastAddedAt
        self.createdAt = createdAt
    }
}

