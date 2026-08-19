import SwiftData
import Foundation

/// Baseline del primer binario público. Las versiones posteriores deben añadir
/// un esquema nuevo y una etapa explícita, con fixture V1 en los tests.
enum CasiListoSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [ShoppingItem.self, ShoppingList.self, ProductCatalogItem.self, Category.self]
    }
}

enum CasiListoMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [CasiListoSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

@MainActor
enum CasiListoModelContainer {
    /// Indicador visible para la UI: si `true`, la base de datos persistente
    /// no se pudo abrir y la sesión usa almacenamiento temporal.
    nonisolated(unsafe) static var isUsingInMemoryFallback = false

    static func make() -> ModelContainer {
        do {
            return try ModelContainer(
                for: ShoppingItem.self,
                ShoppingList.self,
                ProductCatalogItem.self,
                Category.self,
                migrationPlan: CasiListoMigrationPlan.self
            )
        } catch {
            // En vez de tumbar la app con fatalError, se arranca con un
            // container en memoria. La persona puede seguir usando la app
            // (sin persistencia) y resetear los datos desde Ajustes.
            Self.isUsingInMemoryFallback = true
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(
                    for: ShoppingItem.self,
                    ShoppingList.self,
                    ProductCatalogItem.self,
                    Category.self,
                    configurations: config
                )
            } catch {
                // Si ni el container en memoria funciona, no hay nada que hacer.
                fatalError("No se pudo crear un contenedor de datos de emergencia: \(error.localizedDescription)")
            }
        }
    }
}
