import Foundation
import SwiftData

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
        totalSpent: Double = 0
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
    }
}

