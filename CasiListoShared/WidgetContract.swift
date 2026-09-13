import Foundation

// Esta carpeta compila en la app Y en el widget (las dos la declaran en
// `fileSystemSynchronizedGroups`). Es el único código que comparten: antes
// el contrato del App Group eran tres constantes y dos tipos duplicados a
// mano en cada lado, y un typo en cualquiera de las copias dejaba un widget
// plausible en «0 pendientes» sin ningún error visible.
//
// Lo que sigue sin poder compartirse son los dos `.entitlements`: el ID del
// grupo también vive ahí y tiene que coincidir con `WidgetContract.appGroupID`.

/// Nombres que la app y el widget tienen que acordar para hablarse.
nonisolated enum WidgetContract {
    static let appGroupID = "group.com.allopze.CasiListo"
    static let widgetKind = "CasiListoWidget"
    /// Clave del snapshot publicado por la app en los defaults del grupo.
    static let snapshotKey = "widgetSnapshot"
    /// Clave de la cola de productos marcados como comprados desde el
    /// widget, pendientes de que la app los persista.
    static let pendingPurchasesKey = "pendingWidgetPurchases"

    static var groupDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
}

/// Producto pendiente tal como lo ve el widget: identificador estable para
/// poder marcarlo desde ahí, y el nombre para mostrarlo.
nonisolated struct WidgetItemSnapshot: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let name: String
}

/// Lo que la app publica y el widget lee. Serializado como JSON en los
/// defaults del grupo: el contrato entre procesos son estos nombres de campo.
nonisolated struct WidgetSnapshot: Codable, Hashable, Sendable {
    var pendingCount: Int
    var purchasedCount: Int
    /// Primeros cinco pendientes, en orden estable.
    var topItems: [WidgetItemSnapshot]
    var updatedAt: Date

    static let empty = WidgetSnapshot(pendingCount: 0, purchasedCount: 0, topItems: [], updatedAt: .distantPast)

    /// Sin nada pendiente ni comprado no hay nada útil que mostrar. La señal es
    /// el contenido, no la fecha: la app publica un snapshot real en todo
    /// arranque, incluido el primero, así que `updatedAt` nunca distinguía
    /// «recién instalada» de «lista vacía».
    var isPlaceholder: Bool { pendingCount == 0 && purchasedCount == 0 && topItems.isEmpty }

    static func read(from defaults: UserDefaults? = WidgetContract.groupDefaults) -> WidgetSnapshot {
        guard let defaults,
              let data = defaults.data(forKey: WidgetContract.snapshotKey),
              let decoded = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .empty }
        return decoded
    }

    func write(to defaults: UserDefaults? = WidgetContract.groupDefaults) {
        guard let defaults, let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: WidgetContract.snapshotKey)
    }

    /// Versión optimista del snapshot tras marcar un producto desde el widget:
    /// desaparece de la lista y los contadores se mueven, sin esperar a que la
    /// app lo persista. Si el producto no está entre los publicados —ya lo
    /// marcó la app, o el snapshot cambió— no se toca nada.
    func markingPurchased(itemID: UUID) -> WidgetSnapshot {
        guard topItems.contains(where: { $0.id == itemID }) else { return self }
        var updated = self
        updated.topItems.removeAll { $0.id == itemID }
        updated.pendingCount = max(0, pendingCount - 1)
        updated.purchasedCount += 1
        updated.updatedAt = .now
        return updated
    }
}

/// Cola de identificadores marcados como comprados desde el widget.
///
/// El widget no abre la base de datos (presupuesto de memoria de WidgetKit y
/// una sola fuente de verdad), así que no puede persistir el cambio: deja el
/// ID aquí, actualiza el snapshot de forma optimista, y la app lo aplica en
/// SwiftData la próxima vez que pasa a primer plano. Si para entonces el
/// producto ya no existe o ya estaba comprado, el ID se descarta en silencio.
nonisolated enum WidgetActionQueue {
    static func enqueue(itemID: UUID, in defaults: UserDefaults? = WidgetContract.groupDefaults) {
        guard let defaults else { return }
        var pending = defaults.stringArray(forKey: WidgetContract.pendingPurchasesKey) ?? []
        let value = itemID.uuidString
        guard !pending.contains(value) else { return }
        pending.append(value)
        defaults.set(pending, forKey: WidgetContract.pendingPurchasesKey)
    }

    /// Devuelve y vacía la cola. Vaciarla antes de aplicar es deliberado: un
    /// fallo al persistir no debe reintentar para siempre un ID que quizá ya
    /// no corresponde a nada.
    static func drain(from defaults: UserDefaults? = WidgetContract.groupDefaults) -> [UUID] {
        guard let defaults else { return [] }
        let pending = defaults.stringArray(forKey: WidgetContract.pendingPurchasesKey) ?? []
        defaults.removeObject(forKey: WidgetContract.pendingPurchasesKey)
        return pending.compactMap(UUID.init(uuidString:))
    }
}
