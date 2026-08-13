import Foundation

/// Datos serializados que la app principal escribe y el widget lee.
/// Se persiste en App Group UserDefaults (group.com.allopze.CasiListo).
struct WidgetSnapshot: Codable, Sendable {
    let pendingCount: Int
    let purchasedCount: Int
    /// Primeros cinco ítems pendientes, con identificador estable.
    let topItems: [WidgetItemSnapshot]
    let updatedAt: Date

    static let groupID = "group.com.allopze.CasiListo"
    static let key = "widgetSnapshot"

    static func read() -> WidgetSnapshot {
        guard
            let defaults = UserDefaults(suiteName: groupID),
            let data = defaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else {
            return WidgetSnapshot(pendingCount: 0, purchasedCount: 0, topItems: [], updatedAt: .distantPast)
        }
        return decoded
    }

    var isPlaceholder: Bool { updatedAt == .distantPast }
}

struct WidgetItemSnapshot: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
}
