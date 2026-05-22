import Foundation
import SwiftData

/// Modelo principal de un ítem de la lista de compra.
/// Persistido automáticamente con SwiftData.
@Model
final class ShoppingItem {
    var id: UUID
    var name: String
    var quantity: String
    var categoryRawValue: String
    var note: String
    var isPurchased: Bool
    var sortOrder: Int
    var createdAt: Date

    /// Categoría tipada, derivada de `categoryRawValue`.
    var category: Category {
        get { Category(rawValue: categoryRawValue) ?? .varios }
        set { categoryRawValue = newValue.rawValue }
    }

    init(
        name: String,
        quantity: String = "",
        category: Category = .varios,
        note: String = "",
        isPurchased: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.categoryRawValue = category.rawValue
        self.note = note
        self.isPurchased = isPurchased
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}
