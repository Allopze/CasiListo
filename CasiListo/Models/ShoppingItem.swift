import Foundation
import SwiftData
import os.log

enum ShoppingItemStatus: String, Codable, CaseIterable, Identifiable {
    case pending = "Pendiente"
    case purchased = "Comprado"
    case skipped = "Pospuesto"
    case unavailable = "No encontrado"

    var id: String { rawValue }

    var isActionableInShoppingMode: Bool {
        self == .pending
    }
}

/// Modelo principal de un ítem de la lista de compra.
/// Persistido automáticamente con SwiftData.
@Model
final class ShoppingItem {
    var id: UUID
    var listID: UUID?
    var name: String
    var quantity: String
    var categoryRawValue: String
    var storeRawValue: String
    var note: String
    @Attribute(originalName: "isPurchased") var storedIsPurchased: Bool
    var statusRawValue: String?
    var sortOrder: Int
    var price: Double?
    var voiceNoteFilename: String?
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

    /// Computed property for backward compatibility and SwiftUI animations.
    /// Derived from status.
    var isPurchased: Bool {
        get { status == .purchased }
        set { status = newValue ? .purchased : .pending }
    }

    /// Supermercado tipado, derivado de `storeRawValue`.
    var store: Store {
        get {
            if let resolved = Store(rawValue: storeRawValue) {
                return resolved
            }
            ShoppingItem.logger.warning("storeRawValue desconocido: '\(self.storeRawValue, privacy: .public)' — usando .jumbo")
            return .jumbo
        }
        set { storeRawValue = newValue.rawValue }
    }

    private static let logger = Logger(subsystem: "com.casilisto.app", category: "ShoppingItem")

    var status: ShoppingItemStatus {
        get {
            if let statusRawValue, let status = ShoppingItemStatus(rawValue: statusRawValue) {
                return status
            }
            return storedIsPurchased ? .purchased : .pending
        }
        set {
            statusRawValue = newValue.rawValue
            storedIsPurchased = newValue == .purchased
        }
    }

    init(
        name: String,
        listID: UUID? = nil,
        quantity: String = "",
        category: Category? = nil,
        note: String = "",
        isPurchased: Bool = false,
        status: ShoppingItemStatus? = nil,
        sortOrder: Int = 0,
        price: Double? = nil,
        store: Store = .jumbo,
        voiceNoteFilename: String? = nil
    ) {
        self.id = UUID()
        self.listID = listID
        self.name = name
        self.quantity = quantity
        self.categoryRelation = category === Category.fallback ? nil : category
        self.categoryRawValue = category?.name ?? "Varios"
        self.storeRawValue = store.rawValue
        self.note = note
        self.storedIsPurchased = isPurchased
        self.statusRawValue = status?.rawValue ?? (isPurchased ? ShoppingItemStatus.purchased.rawValue : ShoppingItemStatus.pending.rawValue)
        self.sortOrder = sortOrder
        self.price = price
        self.voiceNoteFilename = voiceNoteFilename
        self.createdAt = Date()
    }
}

// MARK: - Formateo de precio centralizado

extension Double {
    // Formatters cacheados — NumberFormatter es costoso de instanciar.
    private static let decimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = .autoupdatingCurrent
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        return f
    }()

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = .autoupdatingCurrent
        f.numberStyle = .currency
        f.minimumFractionDigits = 0
        return f
    }()

    /// Formatea un precio: entero si no tiene decimales, 2 decimales si los tiene.
    /// Ejemplo en es_CL: 1500.0 -> "1.500", 3.50 -> "3,5".
    var formattedPrice: String {
        let formatter = Self.decimalFormatter
        formatter.maximumFractionDigits = isWholePrice ? 0 : 2
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    /// Formatea con símbolo de moneda.
    var formattedPriceWithSymbol: String {
        let formatter = Self.currencyFormatter
        formatter.maximumFractionDigits = isWholePrice ? 0 : 2
        return formatter.string(from: NSNumber(value: self)) ?? "$\(formattedPrice)"
    }

    private var isWholePrice: Bool {
        abs(self.rounded() - self) < 0.005
    }
}

extension Optional where Wrapped == Double {
    /// Formatea el precio si existe, o devuelve cadena vacía.
    var formattedPriceOrEmpty: String {
        self?.formattedPrice ?? ""
    }
}
