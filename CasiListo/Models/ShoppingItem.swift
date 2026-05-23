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
    var storeRawValue: String
    var note: String
    var isPurchased: Bool
    var sortOrder: Int
    var price: Double?
    var voiceNoteFilename: String?
    var createdAt: Date

    /// Categoría tipada, derivada de `categoryRawValue`.
    var category: Category {
        get { Category(rawValue: categoryRawValue) ?? .varios }
        set { categoryRawValue = newValue.rawValue }
    }

    /// Supermercado tipado, derivado de `storeRawValue`.
    var store: Store {
        get { Store(rawValue: storeRawValue) ?? .jumbo }
        set { storeRawValue = newValue.rawValue }
    }

    init(
        name: String,
        quantity: String = "",
        category: Category = .varios,
        note: String = "",
        isPurchased: Bool = false,
        sortOrder: Int = 0,
        price: Double? = nil,
        store: Store = .jumbo,
        voiceNoteFilename: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.categoryRawValue = category.rawValue
        self.storeRawValue = store.rawValue
        self.note = note
        self.isPurchased = isPurchased
        self.sortOrder = sortOrder
        self.price = price
        self.voiceNoteFilename = voiceNoteFilename
        self.createdAt = Date()
    }
}

// MARK: - Formateo de precio centralizado

extension Double {
    /// Formatea un precio: entero si no tiene decimales, 2 decimales si los tiene.
    /// Ejemplo: 1500.0 → "1500", 3.50 → "3.50"
    var formattedPrice: String {
        truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(self))
            : String(format: "%.2f", self)
    }

    /// Formatea con símbolo de moneda.
    var formattedPriceWithSymbol: String {
        "$\(formattedPrice)"
    }
}

extension Optional where Wrapped == Double {
    /// Formatea el precio si existe, o devuelve cadena vacía.
    var formattedPriceOrEmpty: String {
        self?.formattedPrice ?? ""
    }
}
