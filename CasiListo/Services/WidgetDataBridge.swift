import Foundation
import WidgetKit

/// Puente entre la app principal y el widget. Publica identificadores estables
/// y coalesce cambios consecutivos para respetar el presupuesto de WidgetKit.
///
/// Las constantes y los tipos del snapshot viven en `CasiListoShared/`, que
/// compila también en el widget: es el único contrato que hay, no una copia.
@MainActor
enum WidgetDataBridge {
    nonisolated static let appGroupID = WidgetContract.appGroupID
    nonisolated static let snapshotKey = WidgetContract.snapshotKey
    nonisolated static let widgetKind = WidgetContract.widgetKind

    private static var pendingReloadTask: Task<Void, Never>?

    static func write(items: [ShoppingItem]) {
        let pending = items.filter { $0.status == .pending }
        let purchased = items.filter { $0.status == .purchased }
        let snapshot = WidgetSnapshot(
            pendingCount: pending.count,
            purchasedCount: purchased.count,
            topItems: Array(pending.prefix(5).map { WidgetItemSnapshot(id: $0.id, name: $0.name) }),
            updatedAt: .now,
            publicationState: pending.isEmpty && purchased.isEmpty ? .empty : .hasContent
        )
        snapshot.write()
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
