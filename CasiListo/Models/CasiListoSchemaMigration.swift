import SwiftData
import Foundation
import OSLog

/// Baseline del primer binario público, **congelado**: las cuatro clases de
/// aquí dentro son copias fieles de la forma con la que la 1.0 escribió sus
/// stores (solo propiedades almacenadas y un init crudo; nada de lógica). No
/// se editan jamás — `testV1InventoryIsFrozen` lo vigila — porque su única
/// función es que SwiftData reconozca un store de la 1.0 y sepa desde qué
/// forma migrar.
///
/// Regla del proyecto para versionar el esquema: **las clases top-level
/// (`Category`, `ShoppingItem`, …) son siempre la versión vigente**; cada
/// versión histórica es una copia congelada anidada dentro de su enum de
/// esquema. SwiftData nombra la entidad por el último componente del tipo,
/// así que `CasiListoSchemaV1.Category` y `Category` son la misma entidad
/// "Category" para la migración. Para V3: copiar las clases vivas tal como
/// están **hoy** dentro de `CasiListoSchemaV2`, y evolucionar las top-level.
///
/// ⚠️ Por qué hay que duplicar y no basta con listar las clases vivas en las
/// dos versiones (trampa real de la primera vez, CASI-008): SwiftData deriva
/// el checksum de cada versión de la **forma actual** de la clase, no de una
/// foto histórica. V1 y V2 apuntando a la misma `Category` daban el mismo
/// checksum y `ModelContainer(migrationPlan:)` lanzaba
/// `NSInvalidArgumentException: Duplicate version checksums detected`. Y hay
/// que copiar las cuatro, no solo la que cambia: `ShoppingItem` y
/// `ProductCatalogItem` tienen relación con `Category`, y una V1 con
/// `Category` congelada pero `ShoppingItem` vivo apuntaría a la `Category` de
/// V2.
enum CasiListoSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [ShoppingItem.self, ShoppingList.self, ProductCatalogItem.self, Category.self]
    }

    @Model
    final class Category {
        @Attribute(.unique) var name: String
        var sfSymbol: String
        var sortIndex: Int
        var isSystem: Bool

        @Relationship(deleteRule: .nullify, inverse: \ShoppingItem.categoryRelation)
        var items: [ShoppingItem]?

        @Relationship(deleteRule: .nullify, inverse: \ProductCatalogItem.categoryRelation)
        var catalogItems: [ProductCatalogItem]?

        init(name: String, sfSymbol: String, sortIndex: Int, isSystem: Bool) {
            self.name = name
            self.sfSymbol = sfSymbol
            self.sortIndex = sortIndex
            self.isSystem = isSystem
        }
    }

    @Model
    final class ShoppingItem {
        var id: UUID
        var listID: UUID?
        var name: String
        var quantity: String
        var categoryRawValue: String
        var storeRawValue: String
        var note: String
        @Attribute(originalName: "isPurchased") var storedIsPurchased: Bool
        var statusRawValue: String?
        var sortOrder: Int
        var price: Double?
        var voiceNoteFilename: String?
        var createdAt: Date
        @Relationship(deleteRule: .nullify) var categoryRelation: Category?

        init(
            id: UUID = UUID(),
            listID: UUID?,
            name: String,
            quantity: String = "",
            categoryRawValue: String,
            storeRawValue: String,
            note: String = "",
            storedIsPurchased: Bool,
            statusRawValue: String?,
            sortOrder: Int = 0,
            price: Double? = nil,
            voiceNoteFilename: String? = nil,
            createdAt: Date = Date(),
            categoryRelation: Category?
        ) {
            self.id = id
            self.listID = listID
            self.name = name
            self.quantity = quantity
            self.categoryRawValue = categoryRawValue
            self.storeRawValue = storeRawValue
            self.note = note
            self.storedIsPurchased = storedIsPurchased
            self.statusRawValue = statusRawValue
            self.sortOrder = sortOrder
            self.price = price
            self.voiceNoteFilename = voiceNoteFilename
            self.createdAt = createdAt
            self.categoryRelation = categoryRelation
        }
    }

    @Model
    final class ShoppingList {
        var id: UUID
        var title: String
        var createdAt: Date
        var completedAt: Date?
        var statusRawValue: String
        var storeScopeRawValue: String?
        var purchasedCount: Int
        var pendingCount: Int
        var skippedCount: Int
        var unavailableCount: Int
        var totalSpent: Double
        var receiptImageFilename: String?
        var receiptCapturedAt: Date?
        var iconNameRawValue: String?
        var colorHexRawValue: String?

        init(
            id: UUID = UUID(),
            title: String,
            createdAt: Date = Date(),
            completedAt: Date? = nil,
            statusRawValue: String,
            storeScopeRawValue: String? = nil,
            purchasedCount: Int = 0,
            pendingCount: Int = 0,
            skippedCount: Int = 0,
            unavailableCount: Int = 0,
            totalSpent: Double = 0,
            receiptImageFilename: String? = nil,
            receiptCapturedAt: Date? = nil,
            iconNameRawValue: String? = "cart.fill",
            colorHexRawValue: String? = "F5C518"
        ) {
            self.id = id
            self.title = title
            self.createdAt = createdAt
            self.completedAt = completedAt
            self.statusRawValue = statusRawValue
            self.storeScopeRawValue = storeScopeRawValue
            self.purchasedCount = purchasedCount
            self.pendingCount = pendingCount
            self.skippedCount = skippedCount
            self.unavailableCount = unavailableCount
            self.totalSpent = totalSpent
            self.receiptImageFilename = receiptImageFilename
            self.receiptCapturedAt = receiptCapturedAt
            self.iconNameRawValue = iconNameRawValue
            self.colorHexRawValue = colorHexRawValue
        }
    }

    @Model
    final class ProductCatalogItem {
        var id: UUID
        var name: String
        var categoryRawValue: String
        var storeRawValue: String
        var timesAdded: Int
        var lastAddedAt: Date?
        var createdAt: Date
        @Relationship(deleteRule: .nullify) var categoryRelation: Category?

        init(
            id: UUID = UUID(),
            name: String,
            categoryRawValue: String,
            storeRawValue: String,
            timesAdded: Int = 0,
            lastAddedAt: Date? = nil,
            createdAt: Date = Date(),
            categoryRelation: Category?
        ) {
            self.id = id
            self.name = name
            self.categoryRawValue = categoryRawValue
            self.storeRawValue = storeRawValue
            self.timesAdded = timesAdded
            self.lastAddedAt = lastAddedAt
            self.createdAt = createdAt
            self.categoryRelation = categoryRelation
        }
    }
}

/// Versión vigente: las clases top-level. Novedad respecto a V1: la columna
/// opcional `Category.defaultCategoryRawValue` (CASI-008), el vínculo estable
/// entre una categoría del sistema y su `DefaultCategory` que sobrevive a
/// renombrarla. Una columna opcional nueva es exactamente lo que cubre una
/// etapa *lightweight*.
enum CasiListoSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            CasiListo.ShoppingItem.self,
            CasiListo.ShoppingList.self,
            CasiListo.ProductCatalogItem.self,
            CasiListo.Category.self
        ]
    }
}

/// Antes de cambiar cualquier @Model vivo:
/// 1. Congela la forma actual como copias anidadas en un `CasiListoSchemaV(n)`
///    (ver el encabezado de `CasiListoSchemaV1`) y define `V(n+1)` apuntando a
///    las clases vivas.
/// 2. Añade la MigrationStage (lightweight si alcanza, custom si no) a `stages`.
/// 3. Actualiza el golden de `testSchemaInventoryIsFrozen` y suma a
///    `testV1FixtureSurvivesTheCurrentMigrationPlan` los asserts de los campos
///    nuevos. El fixture `CasiListoV1.store` no se regenera nunca.
enum CasiListoMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [CasiListoSchemaV1.self, CasiListoSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: CasiListoSchemaV1.self, toVersion: CasiListoSchemaV2.self)]
    }

    /// El esquema que abre la app. Se deriva de `schemas` a propósito: así
    /// `make()` no necesita una segunda línea que alguien podría olvidar
    /// actualizar al añadir una versión.
    static var currentSchema: any VersionedSchema.Type { schemas.last! }
}

/// Dónde vive la base SwiftData y qué se sabe de arranques anteriores.
///
/// Hasta ahora el container se creaba sin `ModelConfiguration`, así que la
/// ubicación la decidía `groupContainer: .automatic`: con el entitlement puesto,
/// el App Group. Bastaba con que ese entitlement se cayera —perfil mal firmado,
/// capability quitada del target, un build de release sin el grupo— para que
/// SwiftData abriera un store vacío en el sandbox y la app arrancara como
/// instalación limpia, sembrara el catálogo y no dijera absolutamente nada.
/// Esto deja la ubicación por escrito y detecta ese caso.
enum CasiListoStoreLocation {
    /// Se escribe tras cada apertura exitosa del store persistente. Vive en los
    /// defaults **estándar** del sandbox a propósito: si el App Group no está,
    /// sus defaults tampoco, y la prueba de que hubo vida anterior se perdería
    /// justo en el arranque en que hace falta.
    static let didOpenStoreKey = "persistentStoreDidOpenV1"
    /// Ruta absoluta del último store abierto con éxito. Es el testigo de que
    /// la ubicación no cambió entre versiones.
    static let storePathKey = "persistentStorePathV1"
    /// Nombre que SwiftData genera cuando `ModelConfiguration.name` es nil.
    /// Mantenerlo idéntico es lo que garantiza que hacer explícita la
    /// configuración no mueva el archivo de sitio.
    static let storeFilename = "default.store"

    enum Resolution: Equatable {
        /// Se puede abrir el store persistente del App Group.
        case persistent(expectedURL: URL, suspectedDataLoss: Bool)
        /// El contenedor del grupo no se pudo resolver. Abrir un store nuevo en
        /// el sandbox dejaría dos bases divergentes en cuanto el grupo vuelva,
        /// así que no se abre ninguno.
        case unavailable(suspectedDataLoss: Bool)

        var suspectedDataLoss: Bool {
            switch self {
            case .persistent(_, let suspected), .unavailable(let suspected):
                return suspected
            }
        }
    }

    /// La URL que `.automatic` viene resolviendo desde el primer día.
    static func appGroupStoreURL(
        appGroupID: String = WidgetContract.appGroupID,
        fileManager: FileManager = .default
    ) -> URL? {
        fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appending(path: "Library/Application Support", directoryHint: .isDirectory)
            .appending(path: storeFilename, directoryHint: .notDirectory)
    }

    /// Decisión pura: no toca disco salvo por `storeExists`, que es inyectable
    /// para poder probar "el App Group desapareció" sin entitlements reales.
    static func resolve(
        groupStoreURL: URL? = appGroupStoreURL(),
        storeExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) },
        defaults: UserDefaults = .standard
    ) -> Resolution {
        // Evidencia de que esta instalación ya arrancó alguna vez. La marca
        // propia es la buena; la del catálogo sembrado cubre las instalaciones
        // anteriores a este arreglo, que no tienen la nueva.
        let ranBefore = defaults.bool(forKey: didOpenStoreKey)
            || defaults.bool(forKey: SuggestedProducts.hasSeededCatalogKey)

        guard let groupStoreURL else {
            // Sin contenedor de grupo no hay dónde abrir sin inventarse una
            // ubicación nueva. Si nunca arrancó, es una instalación rota desde
            // el minuto cero; si arrancó, los datos existen y no se alcanzan.
            return .unavailable(suspectedDataLoss: ranBefore)
        }

        let recordedPath = defaults.string(forKey: storePathKey)
        let movedSinceLastLaunch = recordedPath != nil
            && recordedPath != groupStoreURL.path(percentEncoded: false)

        if storeExists(groupStoreURL) {
            // Caso normal, y también el de toda instalación previa a este fix:
            // el archivo está donde `.automatic` lo dejó y se abre ahí.
            return .persistent(expectedURL: groupStoreURL, suspectedDataLoss: movedSinceLastLaunch)
        }

        // El archivo no está. Sin arranques previos es el primer arranque real
        // (SwiftData lo creará). Con arranques previos, algo se llevó los datos:
        // se abre igual —la persona tiene que poder seguir usando la app— pero
        // con el aviso puesto, en vez de fingir instalación limpia.
        return .persistent(expectedURL: groupStoreURL, suspectedDataLoss: ranBefore || movedSinceLastLaunch)
    }

    /// Deja constancia de dónde quedó el store. Solo se llama cuando el store
    /// **persistente** abrió: si lo escribiera la sesión en memoria, el
    /// siguiente arranque creería que hubo datos que nunca existieron.
    static func recordSuccessfulOpen(at url: URL?, defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: didOpenStoreKey)
        if let url {
            defaults.set(url.path(percentEncoded: false), forKey: storePathKey)
        }
    }
}

@MainActor
enum CasiListoModelContainer {
    private static let log = Logger(subsystem: "com.casilisto.app", category: "persistencia")

    /// Indicador visible para la UI: si `true`, la base de datos persistente
    /// no se pudo abrir y la sesión usa almacenamiento temporal.
    nonisolated(unsafe) static var isUsingInMemoryFallback = false

    /// Segundo indicador, independiente del anterior: el store esperado no
    /// estaba y hay constancia de que esta instalación ya había arrancado. La
    /// app funciona, pero lo que la persona ve no son sus datos. Arrancar en
    /// silencio como instalación limpia es lo que convierte un entitlement roto
    /// en "la app me borró la lista".
    nonisolated(unsafe) static var didDetectMissingStore = false

    static func make(
        resolution: CasiListoStoreLocation.Resolution = CasiListoStoreLocation.resolve(),
        appGroupID: String = WidgetContract.appGroupID,
        defaults: UserDefaults = .standard
    ) -> ModelContainer {
        isUsingInMemoryFallback = false
        didDetectMissingStore = resolution.suspectedDataLoss

        let schema = Schema(versionedSchema: CasiListoMigrationPlan.currentSchema)

        if case .persistent(let expectedURL, _) = resolution {
            // Explícito a propósito y apuntando exactamente al mismo sitio que
            // `.automatic` ya resolvía. Sin `name:` ni `url:`: el objetivo es
            // dejarlo por escrito, no mover un solo byte.
            let configuration = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(appGroupID)
            )
            do {
                let container = try ModelContainer(
                    for: schema,
                    migrationPlan: CasiListoMigrationPlan.self,
                    configurations: configuration
                )
                let openedURL = container.configurations.first?.url ?? expectedURL
                if openedURL != expectedURL {
                    log.error("El store abrió en \(openedURL.path, privacy: .public), no en \(expectedURL.path, privacy: .public)")
                }
                CasiListoStoreLocation.recordSuccessfulOpen(at: openedURL, defaults: defaults)
                return container
            } catch {
                log.error("No se pudo abrir el store persistente: \(error.localizedDescription, privacy: .public)")
            }
        }

        // En vez de tumbar la app con fatalError, se arranca con un container
        // en memoria. La persona puede seguir usando la app (sin persistencia)
        // y resetear los datos desde Ajustes.
        isUsingInMemoryFallback = true
        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            )
        } catch {
            // Si ni el container en memoria funciona, no hay nada que hacer.
            fatalError("No se pudo crear un contenedor de datos de emergencia: \(error.localizedDescription)")
        }
    }
}
