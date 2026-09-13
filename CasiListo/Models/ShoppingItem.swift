import Foundation
import SwiftData
import os.log

enum ShoppingItemStatus: String, Codable, CaseIterable, Identifiable {
    case pending = "Pendiente"
    case purchased = "Comprado"
    case skipped = "Pospuesto"
    case unavailable = "No encontrado"

    var id: String { rawValue }

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
            categoryRelation = newValue
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
        self.categoryRelation = (category?.name == "Varios" && category?.isSystem == true) ? nil : category
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
    // Formatters cacheados — cada variante inmutable para thread safety.
    private static let decimalFormatterWhole: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = .autoupdatingCurrent
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        return f
    }()

    private static let decimalFormatterFractional: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = .autoupdatingCurrent
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()

    private static let currencyFormatterWhole: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = .autoupdatingCurrent
        f.numberStyle = .currency
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        return f
    }()

    private static let currencyFormatterFractional: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = .autoupdatingCurrent
        f.numberStyle = .currency
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()

    /// Formatea un precio: entero si no tiene decimales, 2 decimales si los tiene.
    /// Ejemplo en es_CL: 1500.0 -> "1.500", 3.50 -> "3,5".
    var formattedPrice: String {
        let formatter = isWholePrice ? Self.decimalFormatterWhole : Self.decimalFormatterFractional
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    /// Formatea con símbolo de moneda.
    var formattedPriceWithSymbol: String {
        let formatter = isWholePrice ? Self.currencyFormatterWhole : Self.currencyFormatterFractional
        return formatter.string(from: NSNumber(value: self)) ?? "$\(formattedPrice)"
    }

    private var isWholePrice: Bool {
        abs(self.rounded() - self) < 0.005
    }
}

extension ShoppingItem {
    /// Lo que costó este producto en la compra: `price` es unitario, así que
    /// sumarlo sin la cantidad subestima el total. Tres sitios lo calculaban
    /// distinto —o lo ignoraban directamente—; ahora lo calcula este.
    var lineTotal: Double {
        guard let price else { return 0 }
        return price * Double(QuantitySemantics.unitCount(of: quantity))
    }
}

/// Las dos mitades del campo de precio editable, juntas a propósito.
///
/// Separarlas fue lo que rompió los precios: el campo se rellenaba con el
/// formato de **presentación** (`1500` → «1.500», con separador de miles) y se
/// releía con `Double(_:)`, que interpreta ese punto como decimal y devuelve
/// 1,5. Cualquier producto de $1.000 o más perdía tres ceros al editarlo y
/// volver a guardarlo, en silencio y sin vuelta atrás.
///
/// Mientras vivan en el mismo tipo, el test de ida y vuelta las cubre a las dos.
enum PriceField {
    /// Sin separador de miles: es justo lo que distingue este texto del de
    /// presentación y lo que permite releerlo sin ambigüedad.
    private static let editingFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    /// Texto para mostrar dentro del `TextField` editable.
    static func text(for price: Double?) -> String {
        guard let price else { return "" }
        return editingFormatter.string(from: NSNumber(value: price)) ?? ""
    }

    /// Lee de vuelta lo que la persona dejó escrito en el campo.
    ///
    /// Reutiliza la gramática de montos de las boletas, que ya distingue el
    /// punto de miles del decimal y está cubierta por los tests de OCR. Un
    /// campo vacío o un cero dejan el producto sin precio.
    static func value(from text: String) -> Double? {
        ReceiptAmount.value(text)
    }
}
