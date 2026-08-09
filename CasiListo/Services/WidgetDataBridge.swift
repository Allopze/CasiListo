import Foundation
import WidgetKit

/// Puente entre la app principal y el widget.
/// Serializa el estado de la lista activa a App Group UserDefaults
/// y notifica a WidgetKit para que recargue sus timelines.
@MainActor
enum WidgetDataBridge {
    private static let groupID = "group.com.allopze.CasiListo"
    private static let key = "widgetSnapshot"

    struct Snapshot: Codable, Sendable {
        let pendingCount: Int
        let purchasedCount: Int
        let topItems: [String]
        let updatedAt: Date
    }

    static func write(items: [ShoppingItem]) {
        let pending = items.filter { $0.status == .pending }
        let purchased = items.filter { $0.status == .purchased }
        let snapshot = Snapshot(
            pendingCount: pending.count,
            purchasedCount: purchased.count,
            topItems: Array(pending.prefix(5).map(\.name)),
            updatedAt: .now
        )
        guard
            let data = try? JSONEncoder().encode(snapshot),
            let defaults = UserDefaults(suiteName: groupID)
        else { return }
        defaults.set(data, forKey: key)
        
        WidgetCenter.shared.reloadAllTimelines()
    }
}
