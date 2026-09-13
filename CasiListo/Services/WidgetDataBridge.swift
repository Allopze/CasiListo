import Foundation
import WidgetKit

struct WidgetItemSnapshot: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let name: String
}

/// Puente entre la app principal y el widget. Publica identificadores estables
/// y coalesce cambios consecutivos para respetar el presupuesto de WidgetKit.
@MainActor
enum WidgetDataBridge {
    // El store SwiftData también lo necesita, y se resuelve antes de que
    // exista nada aislado al MainActor: sin `nonisolated` habría que
    // duplicar el identificador una quinta vez.
    nonisolated static let appGroupID = "group.com.allopze.CasiListo"
    static let snapshotKey = "widgetSnapshot"
    static let widgetKind = "CasiListoWidget"

    private static var pendingReloadTask: Task<Void, Never>?

    struct Snapshot: Codable, Sendable {
        let pendingCount: Int
        let purchasedCount: Int
        let topItems: [WidgetItemSnapshot]
        let updatedAt: Date
    }

    static func write(items: [ShoppingItem]) {
        let pending = items.filter { $0.status == .pending }
        let purchased = items.filter { $0.status == .purchased }
        let snapshot = Snapshot(
            pendingCount: pending.count,
            purchasedCount: purchased.count,
            topItems: Array(pending.prefix(5).map { WidgetItemSnapshot(id: $0.id, name: $0.name) }),
            updatedAt: .now
        )
        guard let data = try? JSONEncoder().encode(snapshot),
              let defaults = UserDefaults(suiteName: appGroupID)
        else { return }

        defaults.set(data, forKey: snapshotKey)
        scheduleReload()
    }

    private static func scheduleReload() {
        pendingReloadTask?.cancel()
        pendingReloadTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        }
    }
}
