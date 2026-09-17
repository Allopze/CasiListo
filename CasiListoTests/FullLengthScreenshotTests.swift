import XCTest
import SwiftUI
import SwiftData
import UIKit
@testable import CasiListo

private typealias Category = CasiListo.Category

/// Suite de tests que renderiza pantallas de longitud completa (full-length)
/// utilizando SwiftUI `ImageRenderer`, sin estar limitadas por la resolución
/// física de la pantalla del simulador.
@MainActor
final class FullLengthScreenshotTests: XCTestCase {

    private struct Fixture {
        let container: ModelContainer
        let activeList: ShoppingList
        let allItems: [ShoppingItem]
        let categories: [Category]
        let catalogItems: [ProductCatalogItem]
    }

    private var outputDirectory: String {
        if let env = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !env.isEmpty {
            return env
        }
        // Ruta por defecto: build/screenshots-full
        let currentFile = URL(fileURLWithPath: #filePath)
        let projectRoot = currentFile
            .deletingLastPathComponent() // CasiListoTests
            .deletingLastPathComponent() // CasiListo
        return projectRoot.appendingPathComponent("build/screenshots-full").path
    }

    private var appearancesToTest: [ColorScheme] {
        if let env = ProcessInfo.processInfo.environment["SCREENSHOT_APPEARANCE"] {
            switch env.lowercased() {
            case "light": return [.light]
            case "dark": return [.dark]
            default: break
            }
        }
        return [.light, .dark]
    }

    private func makeContainer() throws -> Fixture {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ShoppingItem.self,
            ShoppingList.self,
            ProductCatalogItem.self,
            Category.self,
            configurations: configuration
        )
        let context = container.mainContext

        // 1. Bootstrap de categorías
        try CategoryBootstrapService.bootstrap(context: context)
        let categories = try context.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortIndex)]))

        // 2. Sembrado de catálogo
        let suiteName = "test.catalog.seeding.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removeSuite(named: suiteName) }
        try SuggestedProducts.seedCatalogItems(in: context, defaults: defaults)
        let catalogItems = try context.fetch(FetchDescriptor<ProductCatalogItem>(sortBy: [SortDescriptor(\.name)]))

        // 3. Crear lista activa
        let activeList = try ShoppingListLifecycleService.createActiveList(in: context)
        activeList.title = "Compra semanal"

        // 4. Sembrar ítems en la lista activa (muestra de ~35 ítems para visualización)
        for (index, catItem) in catalogItems.prefix(35).enumerated() {
            let isPurchased = index % 4 == 0
            let status: ShoppingItemStatus = isPurchased ? .purchased : .pending
            let item = ShoppingItem(
                name: catItem.name,
                listID: activeList.id,
                quantity: index % 3 == 0 ? "2" : (index % 5 == 0 ? "1 kg" : ""),
                category: catItem.category,
                status: status,
                price: isPurchased ? Double(1200 + index * 150) : nil,
                store: catItem.store ?? .jumbo
            )
            context.insert(item)
        }

        try context.save()

        let allItems = try context.fetch(FetchDescriptor<ShoppingItem>())
        return Fixture(container: container, activeList: activeList, allItems: allItems, categories: categories, catalogItems: catalogItems)
    }

    private func renderAndSave<V: View>(
        view: V,
        name: String,
        appearance: ColorScheme,
        width: CGFloat = 393,
        desiredScale: CGFloat = 2.0
    ) throws -> CGSize {
        let wrapped = view
            .environment(\.colorScheme, appearance)
            .preferredColorScheme(appearance)
            .frame(width: width)

        let renderer = ImageRenderer(content: wrapped)
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)

        var measuredSize: CGSize = .zero
        renderer.render(rasterizationScale: 1.0) { size, _ in
            measuredSize = size
        }

        let effectiveScale: CGFloat
        if measuredSize.height > 0 && measuredSize.height * desiredScale > 8000 {
            effectiveScale = max(1.0, 8000.0 / measuredSize.height)
        } else {
            effectiveScale = desiredScale
        }
        renderer.scale = effectiveScale

        let traitCollection = UITraitCollection(userInterfaceStyle: appearance == .dark ? .dark : .light)
        var uiImage: UIImage?
        traitCollection.performAsCurrent {
            uiImage = renderer.uiImage
        }

        guard let renderedImage = uiImage else {
            XCTFail("No se pudo obtener UIImage para \(name) (medido: \(measuredSize), escala: \(effectiveScale))")
            throw XCTSkip("Fallo UIImage")
        }
        XCTAssertEqual(renderedImage.imageOrientation, .up, "La captura no debe llegar invertida")

        let pngData: Data? = renderedImage.pngData() ?? {
            guard let cg = renderedImage.cgImage else { return nil }
            let mutableData = NSMutableData()
            guard let dest = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil) else { return nil }
            CGImageDestinationAddImage(dest, cg, nil)
            guard CGImageDestinationFinalize(dest) else { return nil }
            return mutableData as Data
        }()

        guard let data = pngData else {
            XCTFail("No se pudo obtener datos PNG para \(name) (tamaño: \(renderedImage.size))")
            throw XCTSkip("Fallo PNG Data")
        }
        XCTAssertGreaterThan(data.count, 1_024, "La captura no puede ser un PNG vacío o sin contenido")

        let appearanceName = appearance == .dark ? "dark" : "light"
        let outDir = URL(fileURLWithPath: outputDirectory).appendingPathComponent(appearanceName)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let fileURL = outDir.appendingPathComponent("\(name).png")
        try data.write(to: fileURL)
        print("📸 [\(appearanceName)] \(name).png -> \(Int(renderedImage.size.width))x\(Int(renderedImage.size.height))pt (\(data.count / 1024) KB)")

        return renderedImage.size
    }

    private func assertAppearanceDiffers(_ name: String, file: StaticString = #filePath, line: UInt = #line) throws {
        guard appearancesToTest.count == 2 else { return }
        let light = try Data(contentsOf: URL(fileURLWithPath: outputDirectory).appendingPathComponent("light/\(name).png"))
        let dark = try Data(contentsOf: URL(fileURLWithPath: outputDirectory).appendingPathComponent("dark/\(name).png"))
        XCTAssertNotEqual(light, dark, "Claro y oscuro produjeron bytes idénticos para \(name)", file: file, line: line)
    }

    // MARK: - Tests de Captura de Longitud Completa

    func testCaptureActiveShoppingListFullLength() throws {
        let fixture = try makeContainer()
        let container = fixture.container
        let activeList = fixture.activeList
        let allItems = fixture.allItems
        let categories = fixture.categories
        let vm = ShoppingListViewModel()
        vm.updateDerivedState(items: allItems, categories: categories)

        for appearance in appearancesToTest {
            let view = ShoppingListFullContentView(
                listTitle: activeList.title,
                activeList: activeList,
                allItems: allItems,
                categories: categories,
                viewModel: vm
            )
            .modelContainer(container)

            let size = try renderAndSave(view: view, name: "01-lista-activa-completa", appearance: appearance)
            XCTAssertGreaterThan(size.height, 800, "La lista activa debería ser más alta que una pantalla estándar")
        }
        try assertAppearanceDiffers("01-lista-activa-completa")
    }

    func testCaptureCatalogFullLength() throws {
        let fixture = try makeContainer()
        let container = fixture.container
        let activeList = fixture.activeList
        let allItems = fixture.allItems
        let categories = fixture.categories
        let catalogItems = fixture.catalogItems
        XCTAssertGreaterThan(catalogItems.count, 4, "El fixture debe contener más elementos que los mostrados por categoría")

        for appearance in appearancesToTest {
            let view = CatalogFullContentView(
                catalogItems: catalogItems,
                categories: categories,
                activeList: activeList,
                allItems: allItems
            )
            .modelContainer(container)

            let size = try renderAndSave(view: view, name: "02-catalogo-diagnostico", appearance: appearance)
            XCTAssertGreaterThan(size.height, 1500, "El catálogo diagnóstico debería tener gran longitud")
        }
        try assertAppearanceDiffers("02-catalogo-diagnostico")
    }

    func testCaptureSettingsFullLength() throws {
        let container = try makeContainer().container

        for appearance in appearancesToTest {
            let view = SettingsFullContentView()
                .modelContainer(container)

            let size = try renderAndSave(view: view, name: "03-ajustes-completo", appearance: appearance)
            XCTAssertGreaterThan(size.height, 600, "Ajustes debería renderizarse completamente")
        }
        try assertAppearanceDiffers("03-ajustes-completo")
    }

    func testCaptureListsOverviewFullLength() throws {
        let fixture = try makeContainer()
        let container = fixture.container
        let activeList = fixture.activeList
        let allItems = fixture.allItems
        let context = container.mainContext

        // Crear una segunda y tercera lista para ver tarjetas múltiples
        let list2 = ShoppingList(title: "Asado familiar", iconName: "flame.fill", colorHex: "E76F51")
        let list3 = ShoppingList(title: "Ferretería y hogar", iconName: "wrench.and.screwdriver.fill", colorHex: "2A9D8F")
        context.insert(list2)
        context.insert(list3)
        try context.save()

        for appearance in appearancesToTest {
            let view = ListsOverviewFullContentView(
                activeLists: [activeList, list2, list3],
                allItems: allItems
            )
            .modelContainer(container)

            let size = try renderAndSave(view: view, name: "04-mis-listas-completo", appearance: appearance)
            XCTAssertGreaterThan(size.height, 400, "Mis Listas debería renderizarse completamente")
        }
        try assertAppearanceDiffers("04-mis-listas-completo")
    }

    func testCaptureHistoryDetailFullLength() throws {
        let fixture = try makeContainer()
        let container = fixture.container
        let allItems = fixture.allItems
        let context = container.mainContext

        // Crear compra archivada con varios ítems
        let completedList = ShoppingList(
            title: "Supermercado Mensual",
            status: .completed,
            iconName: "cart.fill",
            colorHex: "4A90E2"
        )
        completedList.completedAt = Date()
        completedList.totalSpent = 48500
        completedList.purchasedCount = 15
        context.insert(completedList)

        for item in allItems.prefix(15) {
            let histItem = ShoppingItem(
                name: item.name,
                listID: completedList.id,
                quantity: item.quantity,
                category: item.category,
                status: .purchased,
                price: item.price ?? 2500,
                store: item.store
            )
            context.insert(histItem)
        }
        try context.save()

        let historyItems = try context.fetch(FetchDescriptor<ShoppingItem>())

        for appearance in appearancesToTest {
            let view = HistoryDetailFullContentView(
                list: completedList,
                allItems: historyItems
            )
            .modelContainer(container)

            let size = try renderAndSave(view: view, name: "05-historial-detalle-completo", appearance: appearance)
            XCTAssertGreaterThan(size.height, 400, "El detalle de historial debería renderizarse completo")
        }
        try assertAppearanceDiffers("05-historial-detalle-completo")
    }
}
