import Foundation
import SwiftData
import SwiftUI
import UIKit

/// Raw value de la lista activa para usar en `@Query`. `#Predicate` no evalúa
/// `ShoppingListStatus.active.rawValue` en línea ni miembros estáticos: solo
/// captura identificadores sueltos, así que el literal vive aquí una sola vez.
let activeShoppingListStatusRawValue = ShoppingListStatus.active.rawValue

/// Estado persistido de una lista de compra.
enum ShoppingListStatus: String, Codable, CaseIterable {
    case active = "Activa"
    case completed = "Completada"
}

/// Lista de compra real. Las compras completadas quedan como historial ligero y
/// los items se asocian por `ShoppingItem.listID` para mantener una migracion simple.
@Model
final class ShoppingList {
    var id: UUID
    var title: String
    var createdAt: Date
    var completedAt: Date?
    var statusRawValue: String
    var storeScopeRawValue: String?
    var purchasedCount: Int
    var pendingCount: Int
    var skippedCount: Int
    var unavailableCount: Int
    var totalSpent: Double
    /// Imagen de la boleta almacenada localmente para esta compra, si existe.
    var receiptImageFilename: String?
    /// Fecha en la que se registró la boleta. Se mantiene separada de
    /// `completedAt` para compras importadas o corregidas posteriormente.
    var receiptCapturedAt: Date?
    /// Ícono SF Symbol de la lista (ej: "cart.fill", "basket.fill", "flame.fill").
    var iconNameRawValue: String?
    /// Color distintivo en formato hexadecimal (ej: "F5C518", "FF9500").
    var colorHexRawValue: String?

    var status: ShoppingListStatus {
        get { ShoppingListStatus(rawValue: statusRawValue) ?? .active }
        set { statusRawValue = newValue.rawValue }
    }

    var storeScope: Store? {
        get {
            guard let storeScopeRawValue else { return nil }
            return Store(rawValue: storeScopeRawValue)
        }
        set {
            storeScopeRawValue = newValue?.rawValue
        }
    }

    var iconName: String {
        get { iconNameRawValue ?? "cart.fill" }
        set { iconNameRawValue = newValue }
    }

    var colorHex: String {
        get { colorHexRawValue ?? "F5C518" }
        set { colorHexRawValue = newValue }
    }

    var accentColor: Color {
        Color(hex: colorHex)
    }

    var uiColor: UIColor {
        UIColor(hex: colorHex)
    }

    init(
        title: String,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        status: ShoppingListStatus = .active,
        storeScope: Store? = nil,
        purchasedCount: Int = 0,
        pendingCount: Int = 0,
        skippedCount: Int = 0,
        unavailableCount: Int = 0,
        totalSpent: Double = 0,
        receiptImageFilename: String? = nil,
        receiptCapturedAt: Date? = nil,
        iconName: String = "cart.fill",
        colorHex: String = "F5C518"
    ) {
        self.id = UUID()
        self.title = title
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.statusRawValue = status.rawValue
        self.storeScopeRawValue = storeScope?.rawValue
        self.purchasedCount = purchasedCount
        self.pendingCount = pendingCount
        self.skippedCount = skippedCount
        self.unavailableCount = unavailableCount
        self.totalSpent = totalSpent
        self.receiptImageFilename = receiptImageFilename
        self.receiptCapturedAt = receiptCapturedAt
        self.iconNameRawValue = iconName
        self.colorHexRawValue = colorHex
    }
}
