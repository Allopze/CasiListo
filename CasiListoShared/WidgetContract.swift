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
    /// Tombstones de IDs confirmados. Se mantiene separado de la cola para que
    /// un `acknowledge` no reemplace una escritura concurrente del widget.
    static let acknowledgedPurchasesKey = "acknowledgedWidgetPurchases"

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
    nonisolated enum PublicationState: String, Codable, Hashable, Sendable {
        case unpublished
        case empty
        case hasContent
    }

    var pendingCount: Int
    var purchasedCount: Int
    /// Primeros cinco pendientes, en orden estable.
    var topItems: [WidgetItemSnapshot]
    var updatedAt: Date
    var publicationState: PublicationState

    init(
        pendingCount: Int,
        purchasedCount: Int,
        topItems: [WidgetItemSnapshot],
        updatedAt: Date,
        publicationState: PublicationState = .unpublished
    ) {
        self.pendingCount = pendingCount
        self.purchasedCount = purchasedCount
        self.topItems = topItems
        self.updatedAt = updatedAt
        self.publicationState = publicationState
    }

    static let empty = WidgetSnapshot(
        pendingCount: 0,
        purchasedCount: 0,
        topItems: [],
        updatedAt: .distantPast,
        publicationState: .unpublished
    )

    private enum CodingKeys: String, CodingKey {
        case pendingCount, purchasedCount, topItems, updatedAt, publicationState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pendingCount = try container.decode(Int.self, forKey: .pendingCount)
        purchasedCount = try container.decode(Int.self, forKey: .purchasedCount)
        topItems = try container.decode([WidgetItemSnapshot].self, forKey: .topItems)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        if let decodedState = try container.decodeIfPresent(PublicationState.self, forKey: .publicationState) {
            publicationState = decodedState
        } else {
            // Un snapshot antiguo que sí llegó a escribirse representa una
            // publicación real aunque estuviera vacío. `.unpublished` queda
            // reservado para la ausencia total de datos en App Group.
            publicationState = pendingCount > 0 || purchasedCount > 0 || !topItems.isEmpty ? .hasContent : .empty
        }
    }

    /// Sin nada pendiente ni comprado no hay nada útil que mostrar. La señal es
    /// el contenido, no la fecha: la app publica un snapshot real en todo
    /// arranque, incluido el primero, así que `updatedAt` nunca distinguía
    /// «recién instalada» de «lista vacía».
    var isPlaceholder: Bool { publicationState == .unpublished }
    var isEmpty: Bool { publicationState == .empty }

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
        updated.publicationState = .hasContent
        return updated
    }
}

/// Cola de identificadores marcados como comprados desde el widget.
///
/// El widget no abre la base de datos (presupuesto de memoria de WidgetKit y
/// una sola fuente de verdad), así que no puede persistir el cambio: deja el
/// ID aquí, actualiza el snapshot de forma optimista, y la app lo aplica en
/// SwiftData la próxima vez que pasa a primer plano. Si para entonces el
/// producto ya no existe o ya estaba comprado, el ID se descarta explícitamente.
nonisolated enum WidgetActionQueue {
    static func enqueue(itemID: UUID, in defaults: UserDefaults? = WidgetContract.groupDefaults) {
        guard let defaults else { return }
        var pending = defaults.stringArray(forKey: WidgetContract.pendingPurchasesKey) ?? []
        let acknowledged = Set(defaults.stringArray(forKey: WidgetContract.acknowledgedPurchasesKey) ?? [])
        let value = itemID.uuidString
        // No reescribir la clave de tombstones aquí: hacerlo permitiría que un
        // `enqueue` concurrente restaurara una lectura antigua y deshiciera un
        // `acknowledge`. Un ID confirmado no vuelve a ser una acción válida:
        // el widget deja de publicarlo cuando la app confirma el cambio.
        pending.removeAll { acknowledged.contains($0) }
        guard !pending.contains(value) else { return }
        pending.append(value)
        defaults.set(pending, forKey: WidgetContract.pendingPurchasesKey)
    }

    /// Lee la cola sin eliminarla. La confirmación ocurre únicamente después
    /// de que SwiftData confirma el cambio.
    static func peek(from defaults: UserDefaults? = WidgetContract.groupDefaults) -> [UUID] {
        guard let defaults else { return [] }
        let acknowledged = Set(defaults.stringArray(forKey: WidgetContract.acknowledgedPurchasesKey) ?? [])
        var seen = Set<String>()
        return (defaults.stringArray(forKey: WidgetContract.pendingPurchasesKey) ?? [])
            .filter { !acknowledged.contains($0) }
            .filter { seen.insert($0).inserted }
            .compactMap(UUID.init(uuidString:))
    }

    static func acknowledge(ids: [UUID], in defaults: UserDefaults? = WidgetContract.groupDefaults) {
        guard let defaults else { return }
        // No reemplazar la matriz pendiente: el widget puede añadir otro ID
        // entre la lectura y el commit. Los tombstones se aplican al leer y
        // hacen que esta confirmación sea idempotente sin perder esa escritura.
        var acknowledged = Set(defaults.stringArray(forKey: WidgetContract.acknowledgedPurchasesKey) ?? [])
        acknowledged.formUnion(ids.map(\.uuidString))
        defaults.set(Array(acknowledged), forKey: WidgetContract.acknowledgedPurchasesKey)
    }

    static func discardMalformed(from defaults: UserDefaults? = WidgetContract.groupDefaults) {
        guard let defaults else { return }
        let valid = (defaults.stringArray(forKey: WidgetContract.pendingPurchasesKey) ?? [])
            .filter { UUID(uuidString: $0) != nil }
        if valid.isEmpty {
            defaults.removeObject(forKey: WidgetContract.pendingPurchasesKey)
        } else {
            defaults.set(valid, forKey: WidgetContract.pendingPurchasesKey)
        }
    }

    static func clear(from defaults: UserDefaults? = WidgetContract.groupDefaults) {
        defaults?.removeObject(forKey: WidgetContract.pendingPurchasesKey)
        defaults?.removeObject(forKey: WidgetContract.acknowledgedPurchasesKey)
    }

    @available(*, deprecated, message: "Use peek y acknowledge después del commit")
    static func drain(from defaults: UserDefaults? = WidgetContract.groupDefaults) -> [UUID] {
        let pending = peek(from: defaults)
        acknowledge(ids: pending, in: defaults)
        return pending
    }
}
