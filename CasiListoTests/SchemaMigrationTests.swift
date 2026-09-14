import SwiftData
import XCTest
@testable import CasiListo

/// Guardianes de que el plan de migración de SwiftData no quede desfasado del
/// esquema real (CASI-003). SwiftData migra automáticamente en modo
/// *lightweight* incluso con `stages` vacío — así que un cambio a cualquier
/// `@Model` sin su `MigrationStage` no falla al abrir el store: abre igual,
/// con datos potencialmente corrompidos o perdidos, y ningún test lo notaba.
///
/// Cómo se versiona el esquema en este proyecto (ver el encabezado de
/// `CasiListoSchemaV1` en `CasiListoSchemaMigration.swift`): las clases
/// top-level son siempre la versión vigente y cada versión histórica es una
/// copia congelada anidada dentro de su enum. La primera vez (CASI-008) se
/// intentó listar las mismas clases vivas en V1 y V2 y SwiftData lanzó
/// `Duplicate version checksums detected`: el checksum sale de la forma
/// actual de la clase, no de una foto histórica. `testV1InventoryIsFrozen`
/// existe para que nadie "arregle" la copia congelada.
@MainActor
final class SchemaMigrationTests: XCTestCase {

    /// Inventario canónico del esquema vigente: por entidad, sus propiedades
    /// ordenadas. Cualquier propiedad añadida, quitada o renombrada en
    /// cualquier `@Model` mueve esta cadena.
    private func inventory(of versioned: any VersionedSchema.Type) -> String {
        let schema = Schema(versionedSchema: versioned)
        return schema.entities
            .sorted { $0.name < $1.name }
            .map { entity in
                let propertyNames = entity.properties.map(\.name).sorted().joined(separator: ", ")
                return "\(entity.name): \(propertyNames)"
            }
            .joined(separator: "\n")
    }

    /// Tripwire. Si este test se pone rojo, NO actualices la cadena esperada
    /// sin antes leer el aviso del encabezado de este archivo: un cambio de
    /// esquema real necesita clases anidadas por versión, no solo tocar la
    /// clase viva.
    func testSchemaInventoryIsFrozen() {
        let expected = """
        Category: catalogItems, defaultCategoryRawValue, isSystem, items, name, sfSymbol, sortIndex
        ProductCatalogItem: categoryRawValue, categoryRelation, createdAt, id, lastAddedAt, name, storeRawValue, timesAdded
        ShoppingItem: categoryRawValue, categoryRelation, createdAt, id, listID, name, note, price, quantity, sortOrder, statusRawValue, storeRawValue, storedIsPurchased, voiceNoteFilename
        ShoppingList: colorHexRawValue, completedAt, createdAt, iconNameRawValue, id, pendingCount, purchasedCount, receiptCapturedAt, receiptImageFilename, skippedCount, statusRawValue, storeScopeRawValue, title, totalSpent, unavailableCount
        """
        XCTAssertEqual(inventory(of: CasiListoMigrationPlan.currentSchema), expected)
    }

    /// La copia congelada de la 1.0. Si esto se pone rojo, alguien editó las
    /// clases anidadas en `CasiListoSchemaV1`, y eso rompe la migración de
    /// todos los stores escritos por la 1.0: la forma de V1 no se toca nunca.
    func testV1InventoryIsFrozen() {
        let expected = """
        Category: catalogItems, isSystem, items, name, sfSymbol, sortIndex
        ProductCatalogItem: categoryRawValue, categoryRelation, createdAt, id, lastAddedAt, name, storeRawValue, timesAdded
        ShoppingItem: categoryRawValue, categoryRelation, createdAt, id, listID, name, note, price, quantity, sortOrder, statusRawValue, storeRawValue, storedIsPurchased, voiceNoteFilename
        ShoppingList: colorHexRawValue, completedAt, createdAt, iconNameRawValue, id, pendingCount, purchasedCount, receiptCapturedAt, receiptImageFilename, skippedCount, statusRawValue, storeScopeRawValue, title, totalSpent, unavailableCount
        """
        XCTAssertEqual(inventory(of: CasiListoSchemaV1.self), expected)
    }

    /// N esquemas exigen N-1 etapas. Hoy: 2 esquemas, 1 etapa.
    func testEverySchemaTransitionHasItsStage() {
        XCTAssertEqual(
            CasiListoMigrationPlan.stages.count,
            CasiListoMigrationPlan.schemas.count - 1,
            "Hay un esquema nuevo sin su MigrationStage en CasiListoMigrationPlan.stages"
        )
    }

    func testV1IsTheBaselineVersion() {
        XCTAssertEqual(CasiListoSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
    }

    func testV2IsTheCurrentSchema() {
        XCTAssertTrue(CasiListoMigrationPlan.currentSchema == CasiListoSchemaV2.self)
        XCTAssertEqual(CasiListoSchemaV2.versionIdentifier, Schema.Version(2, 0, 0))
        XCTAssertTrue(CasiListoSchemaV2.models.contains { $0 == CasiListo.Category.self })
    }

    // MARK: - Fixture V1: generador (opt-in) y round-trip

    /// Generador del fixture. No corre en la suite normal: hay que pedirlo a mano.
    ///
    ///   TEST_RUNNER_CASILISTO_WRITE_V1_FIXTURE=1 TEST_RUNNER_FIXTURE_OUTPUT_DIR=/tmp/casilisto-v1 \
    ///     xcodebuild test -project CasiListo.xcodeproj -scheme CasiListo \
    ///     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    ///     -only-testing:CasiListoTests/SchemaMigrationTests/testGenerateV1FixtureStore
    ///
    /// `TEST_RUNNER_` es obligatorio (xcodebuild no propaga variables sueltas
    /// al proceso del runner, igual que con `TEST_RUNNER_SCREENSHOT_DIR`).
    /// `FIXTURE_OUTPUT_DIR` también: `NSTemporaryDirectory()` a secas vive
    /// dentro del contenedor efímero del clon de simulador que xcodebuild crea
    /// para la corrida y destruye al terminar — el store desaparecía con él.
    ///
    /// Luego se copia el `CasiListoV1.store` de esa carpeta a
    /// `CasiListoTests/Fixtures/` (sin los sidecars `-wal`/`-shm`: el
    /// generador ya lo deja completamente checkpointado — WAL en 0 bytes —
    /// así que solo el archivo principal hace falta; copiar un `-shm`
    /// residual junto a un WAL vacío es la trampa clásica que confunde a
    /// SQLite en un proceso nuevo).
    /// Escribe con las copias congeladas de `CasiListoSchemaV1`, no con las
    /// clases vivas: por eso sigue produciendo un store 1.0 auténtico aunque
    /// el esquema vigente ya sea V2. Aun así, el fixture commiteado **no se
    /// regenera**: el que está en `Fixtures/` lo escribió la 1.0 de verdad.
    func testGenerateV1FixtureStore() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["CASILISTO_WRITE_V1_FIXTURE"] == "1",
            "Generador del fixture: se pide a mano, no corre en la suite normal"
        )

        let outputDir = ProcessInfo.processInfo.environment["FIXTURE_OUTPUT_DIR"] ?? NSTemporaryDirectory()
        let directory = URL(fileURLWithPath: outputDir)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storeURL = directory.appending(path: "CasiListoV1.store")

        let schema = Schema(versionedSchema: CasiListoSchemaV1.self)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, url: storeURL)
        )
        let context = container.mainContext
        try seedV1SampleData(in: context)
        try context.save()

        print("FIXTURE V1 escrito en: \(directory.path)")
        print("Copia CasiListoV1.store (sin sidecars) a CasiListoTests/Fixtures/")
    }

    /// Ejercita las trampas reales del modelo: la fila "legacy" sin
    /// `statusRawValue`, el ítem en "Varios" sin relación, precios, notas de
    /// voz, y una compra completada con foto y contadores. Todo con los tipos
    /// congelados de V1 y sus valores crudos.
    private func seedV1SampleData(in context: ModelContext) throws {
        typealias V1 = CasiListoSchemaV1
        let carnes = V1.Category(name: "Carnes", sfSymbol: "fork.knife", sortIndex: 3, isSystem: true)
        let varios = V1.Category(name: "Varios", sfSymbol: "bag.fill", sortIndex: 999, isSystem: true)
        let personalizada = V1.Category(name: "Regalos", sfSymbol: "gift.fill", sortIndex: 20, isSystem: false)
        context.insert(carnes)
        context.insert(varios)
        context.insert(personalizada)

        let activeList = V1.ShoppingList(title: "Compra actual", statusRawValue: ShoppingListStatus.active.rawValue)
        context.insert(activeList)

        let fixtureDate = Date(timeIntervalSince1970: 1_755_000_000)
        let completedList = V1.ShoppingList(
            title: "Compra Jumbo - 12 ago 2026",
            completedAt: fixtureDate,
            statusRawValue: ShoppingListStatus.completed.rawValue,
            storeScopeRawValue: Store.jumbo.rawValue,
            purchasedCount: 2,
            totalSpent: 12_345,
            receiptImageFilename: "receipt-fixture.jpg",
            receiptCapturedAt: fixtureDate
        )
        context.insert(completedList)

        // Fila legacy: statusRawValue nil, el estado sale de storedIsPurchased.
        context.insert(V1.ShoppingItem(
            listID: activeList.id, name: "Producto legacy", categoryRawValue: "Carnes",
            storeRawValue: Store.jumbo.rawValue, storedIsPurchased: true, statusRawValue: nil,
            categoryRelation: carnes
        ))

        // "Varios" es el caso normal: sin relación, solo en la sombra.
        context.insert(V1.ShoppingItem(
            listID: activeList.id, name: "Producto en Varios", categoryRawValue: "Varios",
            storeRawValue: Store.jumbo.rawValue, storedIsPurchased: false,
            statusRawValue: ShoppingItemStatus.pending.rawValue, categoryRelation: nil
        ))

        // Ítem con relación real, precio y nota de voz.
        context.insert(V1.ShoppingItem(
            listID: activeList.id, name: "Producto con categoría", categoryRawValue: "Carnes",
            storeRawValue: Store.jumbo.rawValue, storedIsPurchased: false,
            statusRawValue: ShoppingItemStatus.pending.rawValue, price: 4_990,
            voiceNoteFilename: "voice-fixture.m4a", categoryRelation: carnes
        ))

        // Dos ítems ya archivados en la compra completada.
        context.insert(V1.ShoppingItem(
            listID: completedList.id, name: "Vino", categoryRawValue: "Regalos",
            storeRawValue: Store.jumbo.rawValue, storedIsPurchased: true,
            statusRawValue: ShoppingItemStatus.purchased.rawValue, price: 5_990, categoryRelation: personalizada
        ))
        context.insert(V1.ShoppingItem(
            listID: completedList.id, name: "Pan", categoryRawValue: "Varios",
            storeRawValue: Store.jumbo.rawValue, storedIsPurchased: true,
            statusRawValue: ShoppingItemStatus.purchased.rawValue, price: 1_200, categoryRelation: nil
        ))

        context.insert(V1.ProductCatalogItem(
            name: "Vino", categoryRawValue: "Regalos", storeRawValue: Store.jumbo.rawValue,
            timesAdded: 2, lastAddedAt: fixtureDate, categoryRelation: personalizada
        ))
        context.insert(V1.ProductCatalogItem(
            name: "Pan", categoryRawValue: "Varios", storeRawValue: Store.jumbo.rawValue,
            timesAdded: 5, categoryRelation: nil
        ))
        context.insert(V1.ProductCatalogItem(
            name: "Cerveza", categoryRawValue: "Varios", storeRawValue: Store.lider.rawValue, categoryRelation: nil
        ))
    }

    /// Abre el store escrito por la 1.0 con el plan de migración vigente y
    /// comprueba que no se perdió nada. Desde V2 es una migración real
    /// (lightweight, V1→V2): la columna nueva llega vacía y la rellena el
    /// backfill de `CategoryBootstrapService`, igual que en un dispositivo.
    func testV1FixtureSurvivesTheCurrentMigrationPlan() throws {
        let workingURL = try copyFixtureToWritableLocation()

        let schema = Schema(versionedSchema: CasiListoMigrationPlan.currentSchema)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: CasiListoMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, url: workingURL)
        )
        let context = container.mainContext

        XCTAssertEqual(try context.fetch(FetchDescriptor<CasiListo.Category>()).count, 3)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ShoppingList>()).count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ShoppingItem>()).count, 5)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductCatalogItem>()).count, 3)

        let items = try context.fetch(FetchDescriptor<ShoppingItem>())

        let legacy = try XCTUnwrap(items.first { $0.name == "Producto legacy" })
        XCTAssertNil(legacy.statusRawValue)
        XCTAssertEqual(legacy.status, .purchased)

        let varios = try XCTUnwrap(items.first { $0.name == "Producto en Varios" })
        XCTAssertNil(varios.categoryRelation)
        XCTAssertEqual(varios.categoryRawValue, "Varios")
        XCTAssertEqual(varios.category.name, "Varios")

        let linked = try XCTUnwrap(items.first { $0.name == "Producto con categoría" })
        XCTAssertEqual(linked.categoryRelation?.name, "Carnes")
        XCTAssertEqual(linked.price, 4_990)
        XCTAssertEqual(linked.voiceNoteFilename, "voice-fixture.m4a")

        let completed = try XCTUnwrap(
            try context.fetch(FetchDescriptor<ShoppingList>()).first { $0.status == .completed }
        )
        XCTAssertEqual(completed.totalSpent, 12_345)
        XCTAssertEqual(completed.receiptImageFilename, "receipt-fixture.jpg")
        XCTAssertEqual(items.filter { $0.listID == completed.id }.count, 2)

        // V1→V2: la columna nueva abre vacía para las tres…
        let categories = try context.fetch(FetchDescriptor<CasiListo.Category>())
        XCTAssertTrue(categories.allSatisfy { $0.defaultCategoryRawValue == nil })

        // …y el bootstrap la rellena solo para las del sistema (CASI-008).
        try CategoryBootstrapService.bootstrap(context: context)
        let afterBootstrap = try context.fetch(FetchDescriptor<CasiListo.Category>())
        XCTAssertEqual(afterBootstrap.first { $0.name == "Carnes" }?.defaultCategory, DefaultCategory.carnes)
        XCTAssertEqual(afterBootstrap.first { $0.name == "Varios" }?.defaultCategory, DefaultCategory.varios)
        XCTAssertNil(afterBootstrap.first { $0.name == "Regalos" }?.defaultCategory)
        XCTAssertEqual(afterBootstrap.count, 3, "El bootstrap no debe sembrar categorías sobre un store con datos")
    }

    /// El bundle es de solo lectura y SwiftData necesita escribir.
    ///
    /// El fixture se commitea sin sidecars `-wal`/`-shm` a propósito: el
    /// generador ya lo deja con el WAL en 0 bytes (completamente checkpointado
    /// — nada pendiente que reconciliar), así que copiar solo el `.store`
    /// principal basta. Copiar un `.shm` residual junto a un WAL vacío es la
    /// trampa clásica: ese índice de memoria compartida puede quedar
    /// desincronizado para un proceso nuevo que reabre el archivo, y SQLite lo
    /// nota. Sin sidecars, se abre limpio y los recrea vacíos él solo.
    private func copyFixtureToWritableLocation() throws -> URL {
        let bundle = Bundle(for: type(of: self))
        let source = try XCTUnwrap(
            bundle.url(forResource: "CasiListoV1", withExtension: "store"),
            "Falta el fixture V1 en el bundle de tests (CasiListoTests/Fixtures/CasiListoV1.store)"
        )
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "casilisto-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

        let destination = directory.appending(path: "CasiListoV1.store")
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }
}
