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
            fatalError("No se pudo abrir la base de datos local: \(error.localizedDescription)")
        }
    }
}
