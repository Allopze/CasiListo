import AppIntents
import Foundation

/// Marca un producto como comprado desde el widget, sin abrir la app.
///
/// Corre en el proceso del widget, que no abre la base de datos (presupuesto
/// de memoria de WidgetKit y una sola fuente de verdad). Así que hace las dos
/// cosas que sí puede: actualiza el snapshot de forma optimista —el producto
/// desaparece del widget al instante— y deja el ID en una cola de los
/// defaults del grupo. La app lo persiste en SwiftData la próxima vez que
/// pasa a primer plano (`ShoppingPersistenceCoordinator.applyPendingWidgetPurchases`).
struct MarkPurchasedIntent: AppIntent {
    static let title: LocalizedStringResource = "Marcar como comprado"
    /// Solo tiene sentido desde el botón del widget: no aparece en Atajos.
    static let isDiscoverable = false

    @Parameter(title: "Producto")
    var itemID: String

    init() {}

    init(itemID: UUID) {
        self.itemID = itemID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: itemID) else { return .result() }
        WidgetSnapshot.read().markingPurchased(itemID: id).write()
        WidgetActionQueue.enqueue(itemID: id)
        // WidgetKit recarga la línea de tiempo del widget que disparó el
        // intent al terminar `perform()`: no hace falta pedirlo aquí.
        return .result()
    }
}
