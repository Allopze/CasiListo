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
                // El bloque de reparación es costoso (varios fetches de tabla
                // completa) y antes corría en cada reaparición de esta vista,
                // no una vez por lanzamiento — cambiar de pestaña y volver a
                // Compra lo repetía sin necesidad (CASI-006). Nada de lo que
                // hace es idempotente-pero-barato: los tres pasos guardados
                // por bandera de UserDefaults ya retornan temprano sin fetch,
                // así que no eran el problema; este bloque sí.
                if !Self.hasBootstrappedThisLaunch {
                    // Limpieza única de preferencias heredadas (geofencing, logros).
                    if !UserDefaults.standard.bool(forKey: AppDefaultsKeys.hasCleanedLegacyDefaultsV1) {
                        UserDefaults.standard.removeObject(forKey: AppDefaultsKeys.geofencingEnabled)
                        UserDefaults.standard.removeObject(forKey: AppDefaultsKeys.userStats)
                        UserDefaults.standard.removeObject(forKey: AppDefaultsKeys.accessibilityTextSizeScale)
                        UserDefaults.standard.set(true, forKey: AppDefaultsKeys.hasCleanedLegacyDefaultsV1)
                    }
                    try CategoryBootstrapService.bootstrap(context: modelContext)
                    try ShoppingListLifecycleService.bootstrap(context: modelContext)
                    try SuggestedProducts.seedCatalogItems(in: modelContext)
                    try SuggestedProducts.deduplicateCatalogItems(in: modelContext)

                    // Normalización única: fija sortOrder al orden alfabético actual
                    // para que activar el reordenamiento manual no cambie nada visible.
                    if !UserDefaults.standard.bool(forKey: AppDefaultsKeys.hasNormalizedSortOrderV1) {
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
                        UserDefaults.standard.set(true, forKey: AppDefaultsKeys.hasNormalizedSortOrderV1)
                    }

                    try persistence.cleanUnreferencedFiles()
                    Self.hasBootstrappedThisLaunch = true
                }

                // Se queda fuera del gate a propósito: es barato (dos fetches)
                // y es la red de seguridad que ya documentaba el comentario
                // original — las mutaciones reales ya la disparan por su
                // cuenta vía `ShoppingPersistenceCoordinator.commit()`.
                persistence.refreshWidgetSnapshot()
            } catch {
                persistenceErrorMessage = error.localizedDescription
            }
        }
    }

    /// El `.task` se vuelve a ejecutar cada vez que la pestaña Compra reaparece,
    /// así que sin esta marca volver desde Catálogo o Ajustes borraba todo lo
    /// creado mientras tanto. El reseteo es por lanzamiento, no por aparición.
    @MainActor private static var didResetForUITests = false

    /// Mismo problema, mismo remedio, para el bloque de reparación de arriba
    /// (CASI-006): sin esta marca, el bloque entero se repetía en cada
    /// reaparición de la vista en vez de una vez por lanzamiento.
    @MainActor private static var hasBootstrappedThisLaunch = false

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
        // Ya se reseteó en este lanzamiento: saltarse el bootstrap sigue siendo
        // lo correcto, pero volver a borrar la base no.
        guard !Self.didResetForUITests else { return true }
        Self.didResetForUITests = true

        // Sin esto, la guía de primer uso (CASI-011) se presenta encima de
        // los tests que abren la lista de 363 productos sembrados, incluido
        // el assert literal de "355 pendientes". "-ui-testing-onboarding" la
        // salta a propósito, para poder capturarla con el arnés de screenshots.
        // Hay que fijar el valor en los dos sentidos, no solo activarlo: un
        // test anterior en la misma corrida —lanzado sin este argumento— deja
        // la bandera en `true` en `UserDefaults.standard`, que persiste entre
        // lanzamientos dentro del mismo simulador. Sin el `else`, ese `true`
        // sobrevivía y el test de la guía nunca la veía aparecer.
        if arguments.contains("-ui-testing-onboarding") {
            UserDefaults.standard.set(false, forKey: AppDefaultsKeys.hasSeenOnboardingV1)
        } else {
            UserDefaults.standard.set(true, forKey: AppDefaultsKeys.hasSeenOnboardingV1)
        }

        ShoppingListViewModel.removeAllCollapsedCategoryState()
        UserDefaults.standard.removeObject(forKey: CatalogView.collapseKey)

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

        UserDefaults.standard.removeObject(forKey: SuggestedProducts.hasSeededCatalogKey)
        UserDefaults.standard.removeObject(forKey: SuggestedProducts.catalogSeedBatchKey)
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
