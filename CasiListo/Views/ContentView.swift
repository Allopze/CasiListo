import SwiftUI
import SwiftData

/// Vista principal de la app.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingItem.createdAt, order: .forward) private var allItems: [ShoppingItem]
    @Query(sort: \ShoppingList.createdAt, order: .forward) private var allLists: [ShoppingList]
    @Query(sort: \ProductCatalogItem.name, order: .forward) private var catalogItems: [ProductCatalogItem]
    @Query(sort: \Category.sortIndex) private var categories: [Category]
    @State private var viewModel = ShoppingListViewModel()
    @State private var showsClearPurchasedDialog = false
    @State private var showsShoppingMode = false

    private var activeList: ShoppingList? {
        allLists.first { $0.status == .active }
    }

    private var activeItems: [ShoppingItem] {
        guard let activeList else { return [] }
        return allItems.filter { $0.listID == activeList.id }
    }

    private var completedLists: [ShoppingList] {
        allLists
            .filter { $0.status == .completed }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if showsShoppingMode {
                ShoppingModeView(
                    activeList: activeList,
                    allItems: activeItems,
                    onFinished: {
                        withAnimation(.easeInOut) {
                            showsShoppingMode = false
                        }
                    },
                    onCancel: {
                        withAnimation(.easeInOut) {
                            showsShoppingMode = false
                        }
                    }
                )
                .transition(.move(edge: .trailing))
            } else {
                NavigationStack {
                    ZStack {
                        Color.appBackground.ignoresSafeArea()

                        if activeItems.isEmpty {
                            EmptyStateView(
                                onAddTapped: { presentAddItem() },
                                hasHistory: !completedLists.isEmpty,
                                onShowHistory: { viewModel.presentHistory() }
                            )
                        } else {
                            ShoppingListView(
                                activeList: activeList,
                                allItems: activeItems,
                                categories: categories,
                                viewModel: viewModel,
                                onEdit: { viewModel.presentEditItem($0) },
                                onAddTapped: { presentAddItem() },
                                onArchivePurchased: { showsClearPurchasedDialog = true }
                            )
                        }
                    }
                    .navigationTitle("CasiListo")
                    .searchable(
                        text: $viewModel.searchText,
                        placement: .navigationBarDrawer(displayMode: .automatic),
                        prompt: "Buscar productos..."
                    )
                    .adaptiveSearchToolbarBehavior()
                    .adaptiveSearchPresentationToolbarBehavior()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            shoppingModeButton
                        }
                        ToolbarItem(placement: .topBarTrailing) { menuButton }
                        if #available(iOS 26.0, *) {
                            ToolbarSpacer(.fixed, placement: .topBarTrailing)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            addButton
                        }
                    }
                    .sheet(item: $viewModel.presentedSheet) { sheetContent(for: $0) }
                    .confirmationDialog(
                        "Archivar productos comprados",
                        isPresented: $showsClearPurchasedDialog,
                        titleVisibility: .visible
                    ) {
                        Button("Archivar \(viewModel.itemCounts(from: activeItems).purchased) comprados", role: .destructive) {
                            HapticFeedback.impact()
                            let purchasedCount = viewModel.itemCounts(from: activeItems).purchased
                            var stats = UserStats.load()
                            stats.recordPurchase(productsCount: purchasedCount)
                            withAnimation(Theme.defaultAnimation) {
                                ShoppingListLifecycleService.archivePurchasedItems(
                                    from: activeItems,
                                    activeList: activeList,
                                    context: modelContext
                                )
                            }
                        }
                        Button("Cancelar", role: .cancel) {}
                    } message: {
                        Text("Esta acción mueve los productos comprados al historial y los quita de la lista actual.")
                    }
                }
                .tint(Theme.accentYellow)
            }
        }
        .task {
            if resetStorageForUITestsIfNeeded() {
                return
            }
            
            // Inicializar servicios
            CategoryBootstrapService.bootstrap(context: modelContext)
            GeofenceService.shared.initialize(with: modelContext.container)
            
            let list = ShoppingListLifecycleService.bootstrap(context: modelContext)
            SuggestedProducts.seedCatalogItems(in: modelContext)

            let itemDescriptor = FetchDescriptor<ShoppingItem>()
            let itemCount = (try? modelContext.fetchCount(itemDescriptor)) ?? 0
            let hasSeeded = UserDefaults.standard.bool(forKey: "hasSeededDefaultProducts")
            
            if itemCount == 0 || !hasSeeded {
                SuggestedProducts.seedDefaultItems(in: modelContext, listID: list.id)
                UserDefaults.standard.set(true, forKey: "hasSeededDefaultProducts")
            }
            
            WidgetDataBridge.write(items: activeItems)
        }
        .onChange(of: activeItems) { _, newItems in
            WidgetDataBridge.write(items: newItems)
        }
    }

    private var addButton: some View {
        Button { presentAddItem() } label: {
            Image(systemName: "plus").fontWeight(.semibold)
        }
        .adaptiveGlassButtonStyle()
        .accessibilityLabel("Añadir producto")
        .accessibilityIdentifier("toolbar-add-product")
    }

    private var shoppingModeButton: some View {
        Button {
            HapticFeedback.selection()
            withAnimation(.easeInOut) {
                showsShoppingMode = true
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "cart.fill").fontWeight(.semibold)
                Text("Comprar").font(.system(size: 13, weight: .bold))
            }
        }
        .adaptiveGlassProminentButtonStyle()
        .accessibilityLabel("Entrar a Modo Compra")
    }

    private var formattedShareText: String {
        let groups = viewModel.groupedItems(from: activeItems, categories: categories)
        let storeTitle = viewModel.selectedStore?.displayName ?? "Todos"
        guard !groups.isEmpty else { return "Mi lista de compras en CasiListo (\(storeTitle)) está vacía." }
        
        var text = "📝 *Lista de Compras: CasiListo (\(storeTitle))*\n\n"
        for group in groups {
            text += "*\(group.category.displayName.uppercased())*\n"
            for item in group.items {
                let check = item.isPurchased ? "✅" : "⬜"
                let qty = item.quantity.isEmpty ? "" : " (\(item.quantity))"
                let note = item.note.isEmpty ? "" : " [Nota: \(item.note)]"
                text += "\(check) \(item.name)\(qty)\(note)\n"
            }
            text += "\n"
        }
        return text
    }

    private var menuButton: some View {
        Menu {
            Button {
                HapticFeedback.selection()
                withAnimation(Theme.defaultAnimation) {
                    viewModel.showPurchased.toggle()
                }
            } label: {
                Label(
                    viewModel.showPurchased ? "Ocultar comprados" : "Mostrar comprados",
                    systemImage: viewModel.showPurchased ? "eye.slash" : "eye"
                )
            }

            ShareLink(item: formattedShareText) {
                Label("Compartir lista", systemImage: "square.and.arrow.up")
            }

            Button {
                HapticFeedback.selection()
                viewModel.presentHistory()
            } label: {
                Label("Historial", systemImage: "clock.arrow.circlepath")
            }

            Button {
                HapticFeedback.selection()
                viewModel.presentSettings()
            } label: {
                Label("Ajustes", systemImage: "gearshape")
            }

            if viewModel.itemCounts(from: activeItems).purchased > 0 {
                Button(role: .destructive) { showsClearPurchasedDialog = true } label: {
                    Label("Archivar comprados", systemImage: "archivebox")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .adaptiveGlassButtonStyle()
        .accessibilityLabel("Opciones")
        .accessibilityIdentifier("toolbar-options-menu")
    }

    @ViewBuilder
    private func sheetContent(for destination: ShoppingListSheetDestination) -> some View {
        switch destination {
        case .addItem:
            let draft = viewModel.quickAddText.isEmpty ? nil : viewModel.quickAddDraft(from: viewModel.quickAddText)
            AddEditItemSheet(
                mode: .add,
                activeList: activeList,
                allItems: activeItems,
                preselectedStore: viewModel.selectedStore,
                initialName: draft?.name ?? "",
                initialQuantity: draft?.quantity ?? "",
                onQuickAddConsumed: { viewModel.quickAddText = "" },
                nextSortOrder: { viewModel.nextSortOrder(for: $0, in: activeItems) },
                checkDuplicate: { viewModel.duplicateItem(named: $0, store: $1, in: activeItems, excluding: $2) }
            )
        case .editItem(let item):
            AddEditItemSheet(
                mode: .edit(item),
                activeList: activeList,
                allItems: activeItems,
                preselectedStore: nil,
                initialName: "",
                initialQuantity: "",
                onQuickAddConsumed: {},
                nextSortOrder: { viewModel.nextSortOrder(for: $0, in: activeItems) },
                checkDuplicate: { viewModel.duplicateItem(named: $0, store: $1, in: activeItems, excluding: $2) }
            )
        case .settings:
            SettingsSheet()
        case .history:
            ShoppingHistoryView(completedLists: completedLists, allItems: allItems)
        }
    }

    private func presentAddItem() {
        HapticFeedback.impact()
        viewModel.presentAddItem()
    }

    @discardableResult
    private func resetStorageForUITestsIfNeeded() -> Bool {
        guard ProcessInfo.processInfo.arguments.contains("-ui-testing-reset") else {
            return false
        }

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

        UserDefaults.standard.set(false, forKey: "hasSeededDefaultProducts")
        CategoryBootstrapService.bootstrap(context: modelContext)
        let list = ShoppingListLifecycleService.createActiveList(in: modelContext)
        SuggestedProducts.seedDefaultItems(in: modelContext, listID: list.id)
        SuggestedProducts.seedCatalogItems(in: modelContext)
        UserDefaults.standard.set(true, forKey: "hasSeededDefaultProducts")
        try? modelContext.save()
        return true
    }
}
