import SwiftUI
import SwiftData

/// Raíz de la pestaña Compra: Menú General de Listas ("Mis Listas") con navegación hacia el detalle.
struct ContentView: View {
    /// Cambia a la pestaña de Historial (inyectado por MainTabView).
    var onShowHistory: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingItem.createdAt, order: .forward) private var allItems: [ShoppingItem]
    @Query(sort: \ShoppingList.createdAt, order: .forward) private var allLists: [ShoppingList]
    @Query(sort: \ProductCatalogItem.name, order: .forward) private var catalogItems: [ProductCatalogItem]
    @Query(sort: \Category.sortIndex) private var categories: [Category]

    @State private var navigationPath = NavigationPath()
    @State private var persistenceErrorMessage: String?
    /// Compartida con Catálogo: esa pestaña necesita saber sobre qué lista
    /// está operando la persona, no adivinarla.
    @AppStorage(ActiveListSelection.storageKey) private var selectedActiveListID = ""

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ListsOverviewView(
                onSelectList: { list in
                    selectedActiveListID = list.id.uuidString
                    navigationPath.append(list.id)
                },
                onShowHistory: onShowHistory
            )
            .navigationDestination(for: UUID.self) { listID in
                if let list = allLists.first(where: { $0.id == listID }) {
                    ShoppingListDetailView(
                        list: list,
                        allItems: allItems,
                        allLists: allLists,
                        categories: categories,
                        onShowHistory: onShowHistory
                    )
                } else {
                    // La lista se borró mientras estaba abierta: sin este `else`
                    // SwiftUI deja una pantalla en blanco de la que no se sale.
                    Color.appBackground
                        .ignoresSafeArea()
                        .onAppear { navigationPath = NavigationPath() }
                }
            }
        }
        .tint(Theme.accentInteractive)
        .alert(
            "No se pudieron guardar los cambios",
            isPresented: Binding(
                get: { persistenceErrorMessage != nil },
                set: { if !$0 { persistenceErrorMessage = nil } }
            )
        ) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(persistenceErrorMessage ?? "Inténtalo nuevamente.")
        }
        .task {
            if resetStorageForUITestsIfNeeded() {
                return
            }

            let persistence = ShoppingPersistenceCoordinator(context: modelContext)
            do {
                // Limpieza única de preferencias heredadas (geofencing, logros).
                if !UserDefaults.standard.bool(forKey: "hasCleanedLegacyDefaultsV1") {
                    UserDefaults.standard.removeObject(forKey: "geofencing_enabled")
                    UserDefaults.standard.removeObject(forKey: "user_stats")
                    UserDefaults.standard.removeObject(forKey: "accessibilityTextSizeScale")
                    UserDefaults.standard.set(true, forKey: "hasCleanedLegacyDefaultsV1")
                }
                try CategoryBootstrapService.bootstrap(context: modelContext)
                try ShoppingListLifecycleService.bootstrap(context: modelContext)
                try SuggestedProducts.seedCatalogItems(in: modelContext)

                // La lista parte vacía: el catálogo completo vive en su pestaña
                // y como plantilla. Se limpia el flag del seed legado.
                UserDefaults.standard.removeObject(forKey: "hasSeededDefaultProducts")

                // Normalización única: fija sortOrder al orden alfabético actual
                // para que activar el reordenamiento manual no cambie nada visible.
                if !UserDefaults.standard.bool(forKey: "hasNormalizedSortOrderV1") {
                    let allStoredItems = try modelContext.fetch(FetchDescriptor<ShoppingItem>())
                    let groupsByListAndCategory = Dictionary(grouping: allStoredItems) {
                        "\($0.listID?.uuidString ?? "none")|\($0.category.name)"
                    }
                    for (_, groupItems) in groupsByListAndCategory {
                        let alphabetical = groupItems.sorted {
                            $0.name.localizedCompare($1.name) == .orderedAscending
                        }
                        for (position, storedItem) in alphabetical.enumerated() {
                            storedItem.sortOrder = position
                        }
                    }
                    try modelContext.save()
                    UserDefaults.standard.set(true, forKey: "hasNormalizedSortOrderV1")
                }

                try persistence.cleanUnreferencedFiles()
                persistence.refreshWidgetSnapshot()
            } catch {
                persistenceErrorMessage = error.localizedDescription
            }
        }
    }

    @discardableResult
    private func resetStorageForUITestsIfNeeded() -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        // "-ui-testing-reset" siembra el fixture de 363 productos que usan los
        // tests existentes; "-ui-testing-reset-empty" reproduce el primer
        // arranque real (lista vacía, catálogo poblado).
        let seedsListFixture = arguments.contains("-ui-testing-reset")
        let startsEmpty = arguments.contains("-ui-testing-reset-empty")
        guard seedsListFixture || startsEmpty else {
            return false
        }

        ShoppingListViewModel.removeAllCollapsedCategoryState()
        UserDefaults.standard.removeObject(forKey: "catalogCollapsedCategoryNames")

        for item in allItems {
            modelContext.delete(item)
        }
        for list in allLists {
            modelContext.delete(list)
        }
        for catalogItem in catalogItems {
            modelContext.delete(catalogItem)
        }

        let catDescriptor = FetchDescriptor<Category>()
        if let allCats = try? modelContext.fetch(catDescriptor) {
            for cat in allCats {
                modelContext.delete(cat)
            }
        }

        UserDefaults.standard.removeObject(forKey: "hasSeededDefaultProducts")
        do {
            try CategoryBootstrapService.bootstrap(context: modelContext)
            // "-ui-testing-reset-empty" no crea lista: reproduce el primer arranque
            // real, en el que "Mis Listas" aparece vacío y el usuario elige la suya.
            if seedsListFixture && !startsEmpty {
                let list = try ShoppingListLifecycleService.createActiveList(in: modelContext)
                try SuggestedProducts.seedDefaultItems(in: modelContext, listID: list.id)
            }
            try SuggestedProducts.seedCatalogItems(in: modelContext)
        } catch {
            persistenceErrorMessage = error.localizedDescription
        }
        return true
    }
}
