import SwiftData
import XCTest
@testable import CasiListo

/// `CasiListoStoreLocation` decide dónde vive el store y si hay que sospechar
/// pérdida de datos. Todo aquí es puro e inyectado: ningún test de esta clase
/// debe abrir el store real del simulador que hospeda los tests.
@MainActor
final class StoreLocationTests: XCTestCase {

    private let fakeStoreURL = URL(filePath: "/tmp/casilisto-tests/default.store")

    // Los dos indicadores estáticos de CasiListoModelContainer son globales:
    // se guardan y restauran para no contaminar otros tests de la misma clase
    // (el scheme corre con parallelizable = "YES").
    private var savedInMemoryFallback = false
    private var savedMissingStore = false

    override func setUp() {
        super.setUp()
        savedInMemoryFallback = CasiListoModelContainer.isUsingInMemoryFallback
        savedMissingStore = CasiListoModelContainer.didDetectMissingStore
    }

    override func tearDown() {
        CasiListoModelContainer.isUsingInMemoryFallback = savedInMemoryFallback
        CasiListoModelContainer.didDetectMissingStore = savedMissingStore
        super.tearDown()
    }

    private func makeScratchDefaults(_ name: String = #function) throws -> UserDefaults {
        let suite = "CasiListoTests.storeLocation.\(name)"
        UserDefaults.standard.removeSuite(named: suite)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { UserDefaults.standard.removeSuite(named: suite) }
        return defaults
    }

    /// El test clave del fix: si alguien vuelve a pasar `name:`/`url:` en el
    /// futuro, esto lo caza antes de mover el store de un usuario real.
    func testExplicitAppGroupConfigurationResolvesToTheSameURLAsTheImplicitOne() throws {
        try XCTSkipIf(
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetDataBridge.appGroupID) == nil,
            "Sin App Group disponible en este entorno de test"
        )

        let schema = Schema(versionedSchema: CasiListoSchemaV1.self)
        let implicit = ModelConfiguration(schema: schema)
        let explicit = ModelConfiguration(schema: schema, groupContainer: .identifier(WidgetDataBridge.appGroupID))

        let implicitURL = try XCTUnwrap(implicit.url.resolvingSymlinksInPath() as URL?)
        let explicitURL = try XCTUnwrap(explicit.url.resolvingSymlinksInPath() as URL?)
        XCTAssertEqual(implicitURL, explicitURL)
        XCTAssertTrue(explicitURL.path.hasSuffix("Library/Application Support/default.store"))

        let resolvedURL = try XCTUnwrap(CasiListoStoreLocation.appGroupStoreURL()?.resolvingSymlinksInPath())
        XCTAssertEqual(resolvedURL, explicitURL)
    }

    func testFirstLaunchWithoutStoreIsNotReportedAsDataLoss() throws {
        let defaults = try makeScratchDefaults()
        let resolution = CasiListoStoreLocation.resolve(
            groupStoreURL: fakeStoreURL,
            storeExists: { _ in false },
            defaults: defaults
        )
        XCTAssertEqual(resolution, .persistent(expectedURL: fakeStoreURL, suspectedDataLoss: false))
    }

    func testMissingStoreAfterAPreviousLaunchIsReportedAsDataLoss() throws {
        let defaults = try makeScratchDefaults()
        defaults.set(true, forKey: CasiListoStoreLocation.didOpenStoreKey)

        let resolution = CasiListoStoreLocation.resolve(
            groupStoreURL: fakeStoreURL,
            storeExists: { _ in false },
            defaults: defaults
        )
        XCTAssertTrue(resolution.suspectedDataLoss)
    }

    /// El caso real de cualquier instalación anterior a este fix: no tiene la
    /// marca nueva, pero ya sembró el catálogo alguna vez.
    func testLegacyInstallIsDetectedThroughTheSeededCatalogFlag() throws {
        let defaults = try makeScratchDefaults()
        defaults.set(true, forKey: SuggestedProducts.hasSeededCatalogKey)

        let resolution = CasiListoStoreLocation.resolve(
            groupStoreURL: fakeStoreURL,
            storeExists: { _ in false },
            defaults: defaults
        )
        XCTAssertTrue(resolution.suspectedDataLoss)
    }

    func testUnavailableAppGroupFallsBackToMemoryAndRaisesTheAlarm() throws {
        let defaults = try makeScratchDefaults()
        defaults.set(true, forKey: CasiListoStoreLocation.didOpenStoreKey)

        let resolution = CasiListoStoreLocation.resolve(
            groupStoreURL: nil,
            storeExists: { _ in false },
            defaults: defaults
        )
        XCTAssertEqual(resolution, .unavailable(suspectedDataLoss: true))

        let container = CasiListoModelContainer.make(resolution: resolution, defaults: defaults)
        XCTAssertTrue(container.configurations.first?.isStoredInMemoryOnly ?? false)
        XCTAssertTrue(CasiListoModelContainer.isUsingInMemoryFallback)
        XCTAssertTrue(CasiListoModelContainer.didDetectMissingStore)

        // La sesión en memoria no deja huella: la marca previa sigue igual y
        // no se escribió ninguna ruta.
        XCTAssertTrue(defaults.bool(forKey: CasiListoStoreLocation.didOpenStoreKey))
        XCTAssertNil(defaults.string(forKey: CasiListoStoreLocation.storePathKey))
    }

    func testMemoryFallbackContainerStillAcceptsWrites() throws {
        let defaults = try makeScratchDefaults()
        let resolution = CasiListoStoreLocation.Resolution.unavailable(suspectedDataLoss: false)
        let container = CasiListoModelContainer.make(resolution: resolution, defaults: defaults)

        let context = container.mainContext
        context.insert(ShoppingItem(name: "Producto de prueba"))
        try context.save()

        let items = try context.fetch(FetchDescriptor<ShoppingItem>())
        XCTAssertEqual(items.count, 1)
    }

    /// Detector para un futuro cambio de grupo: si la ruta registrada no
    /// coincide con la actual, algo cambió entre lanzamientos.
    func testStoreLocationChangeBetweenLaunchesIsReportedAsDataLoss() throws {
        let defaults = try makeScratchDefaults()
        defaults.set("/otra/ruta/default.store", forKey: CasiListoStoreLocation.storePathKey)

        let resolution = CasiListoStoreLocation.resolve(
            groupStoreURL: fakeStoreURL,
            storeExists: { _ in true },
            defaults: defaults
        )
        XCTAssertTrue(resolution.suspectedDataLoss)
    }

    func testSuccessfulOpenRecordsThePath() throws {
        let defaults = try makeScratchDefaults()
        CasiListoStoreLocation.recordSuccessfulOpen(at: fakeStoreURL, defaults: defaults)

        XCTAssertTrue(defaults.bool(forKey: CasiListoStoreLocation.didOpenStoreKey))
        XCTAssertEqual(defaults.string(forKey: CasiListoStoreLocation.storePathKey), fakeStoreURL.path(percentEncoded: false))

        let resolution = CasiListoStoreLocation.resolve(
            groupStoreURL: fakeStoreURL,
            storeExists: { _ in true },
            defaults: defaults
        )
        XCTAssertFalse(resolution.suspectedDataLoss)
    }
}
