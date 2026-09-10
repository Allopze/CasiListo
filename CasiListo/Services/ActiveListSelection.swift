import Foundation

/// Lista activa que comparten la pestaña Compra y la de Catálogo.
///
/// Antes cada pantalla resolvía «la lista activa» por su cuenta con
/// `allLists.first { $0.status == .active }`. Como el `@Query` viene ordenado
/// por `createdAt` ascendente, Catálogo se quedaba siempre con la **más
/// antigua**: con dos listas abiertas, añadir desde Catálogo escribía en una
/// lista distinta de la que la persona tenía a la vista en Compra.
enum ActiveListSelection {
    /// Clave de `@AppStorage` compartida entre pestañas.
    static let storageKey = "selectedActiveListID"

    /// Lista sobre la que deben operar las pestañas: la última abierta en
    /// Compra si sigue activa; si no, la activa más reciente.
    static func resolve(from lists: [ShoppingList], storedID: String) -> ShoppingList? {
        let active = lists.filter { $0.status == .active }
        if let uuid = UUID(uuidString: storedID),
           let selected = active.first(where: { $0.id == uuid }) {
            return selected
        }
        return active.max { $0.createdAt < $1.createdAt }
    }
}
