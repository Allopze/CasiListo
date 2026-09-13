import SwiftData
import Foundation
import OSLog

/// Baseline del primer binario público. Las versiones posteriores deben añadir
/// un esquema nuevo y una etapa explícita, con fixture V1 en los tests.
enum CasiListoSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [ShoppingItem.self, ShoppingList.self, ProductCatalogItem.self, Category.self]
    }
}

/// Antes de cambiar cualquier @Model listado en CasiListoSchemaV1:
/// 1. Define CasiListoSchemaV2 con los modelos nuevos.
/// 2. Añade una MigrationStage (lightweight si alcanza, custom si no) a `stages`.
/// 3. Añade un fixture del store V1 a CasiListoTests y un test que lo abra con el plan
///    actualizado y confirme que los datos sobreviven.
enum CasiListoMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [CasiListoSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
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
        appGroupID: String = WidgetDataBridge.appGroupID,
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
        appGroupID: String = WidgetDataBridge.appGroupID,
        defaults: UserDefaults = .standard
    ) -> ModelContainer {
        isUsingInMemoryFallback = false
        didDetectMissingStore = resolution.suspectedDataLoss

        let schema = Schema(versionedSchema: CasiListoSchemaV1.self)

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
