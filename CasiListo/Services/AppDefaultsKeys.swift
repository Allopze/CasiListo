import Foundation

/// Claves de `UserDefaults.standard` sin dueño natural en un tipo de dominio.
///
/// Las que sí lo tienen —el sembrado del catálogo (`SuggestedProducts`), la
/// ubicación del store (`CasiListoStoreLocation`), el colapso de categorías
/// (`ShoppingListViewModel`, `CatalogView`), la lista activa compartida
/// (`ActiveListSelection`)— se quedan junto a esa lógica: moverlas aquí solo
/// alejaría la clave de quien la usa. Estas cuatro no tenían ese dueño y se
/// repetían como literales sueltos en más de un archivo (el bootstrap de
/// `ContentView` y el reseteo de `ShoppingPersistenceCoordinator`): un typo
/// en una de las copias habría sido silencioso, porque `removeObject` y
/// `bool(forKey:)` nunca avisan de una clave que no existe.
enum AppDefaultsKeys {
    /// Preferencia heredada de una función ya eliminada (geolocalización).
    static let geofencingEnabled = "geofencing_enabled"
    /// Preferencia heredada de una función ya eliminada (logros/estadísticas).
    static let userStats = "user_stats"
    /// Preferencia heredada de un slider de tamaño de texto ya eliminado
    /// (Dynamic Type nativo lo reemplazó).
    static let accessibilityTextSizeScale = "accessibilityTextSizeScale"
    /// Marca de que la limpieza única de las tres claves heredadas de arriba
    /// ya corrió en este dispositivo.
    static let hasCleanedLegacyDefaultsV1 = "hasCleanedLegacyDefaultsV1"
    /// Marca de que `sortOrder` ya se normalizó al orden alfabético una vez.
    static let hasNormalizedSortOrderV1 = "hasNormalizedSortOrderV1"
    /// Marca de que la guía de primer uso ya se mostró (CASI-011). La borra
    /// el reseteo de datos y la fija a mano el arnés de UI tests, para que la
    /// guía no se presente encima de la lista de 363 productos sembrados.
    static let hasSeenOnboardingV1 = "hasSeenOnboardingV1"
}
