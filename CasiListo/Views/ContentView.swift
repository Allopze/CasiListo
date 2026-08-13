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
        NavigationStack {
                    ZStack {
                        Color.appBackground.ignoresSafeArea()

                        if activeItems.isEmpty {
                            EmptyStateView(
                                onAddTapped: { presentAddItem() },
                                hasHistory: !completedLists.isEmpty,
                                onShowHistory: { viewModel.presentHistory() },
                                onQuickAdd: { name in
                                    viewModel.quickAddText = name
                                    viewModel.addQuickItem(
                                        to: activeList,
                                        from: activeItems,
                                        categories: categories,
                                        context: modelContext
                                    )
                                }
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
                    .navigationBarTitleDisplayMode(.inline)
                    .searchable(
                        text: $viewModel.searchText,
                        placement: .navigationBarDrawer(displayMode: .automatic),
                        prompt: "Buscar productos..."
                    )
                    .adaptiveSearchToolbarBehavior()
                    .adaptiveSearchPresentationToolbarBehavior()
                    .toolbarBackground(Color.appBackground, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) { menuButton }
                    }
                    .sheet(item: $viewModel.presentedSheet) { sheetContent(for: $0) }
                    .confirmationDialog(
                        "Archivar productos comprados",
                        isPresented: $showsClearPurchasedDialog,
                        titleVisibility: .visible
                    ) {
                        Button("Archivar \(viewModel.itemCounts(from: activeItems).purchased) comprados", role: .destructive) {
                            let purchasedCount = viewModel.itemCounts(from: activeItems).purchased
                            do {
                                try ShoppingPersistenceCoordinator(context: modelContext).archivePurchased(
                                    from: activeItems,
                                    activeList: activeList
                                )
                                var stats = UserStats.load()
                                stats.recordPurchase(productsCount: purchasedCount)
                                HapticFeedback.success()
                            } catch {
                                viewModel.presentPersistenceError(error)
                            }
                        }
                        Button("Cancelar", role: .cancel) {}
                    } message: {
                        Text("Esta acción mueve los productos comprados al historial y los quita de la lista actual.")
                    }
        }
        .tint(Theme.accentYellow)
        .alert(
            "No se pudieron guardar los cambios",
            isPresented: Binding(
                get: { viewModel.persistenceErrorMessage != nil },
                set: { if !$0 { viewModel.persistenceErrorMessage = nil } }
            )
        ) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(viewModel.persistenceErrorMessage ?? "Inténtalo nuevamente.")
        }
        .task {
            if resetStorageForUITestsIfNeeded() {
                return
            }
            
            let persistence = ShoppingPersistenceCoordinator(context: modelContext)
            do {
                // Limpieza única de la preferencia heredada de geofencing.
                UserDefaults.standard.removeObject(forKey: "geofencing_enabled")
                try CategoryBootstrapService.bootstrap(context: modelContext)
                let list = try ShoppingListLifecycleService.bootstrap(context: modelContext)
                try SuggestedProducts.seedCatalogItems(in: modelContext)

            let itemDescriptor = FetchDescriptor<ShoppingItem>()
            let itemCount = (try? modelContext.fetchCount(itemDescriptor)) ?? 0
            let hasSeeded = UserDefaults.standard.bool(forKey: "hasSeededDefaultProducts")
            
            if itemCount == 0 && !hasSeeded {
                try SuggestedProducts.seedDefaultItems(in: modelContext, listID: list.id)
                UserDefaults.standard.set(true, forKey: "hasSeededDefaultProducts")
            }
                try persistence.cleanUnreferencedFiles()
                WidgetDataBridge.write(items: activeItems)
            } catch {
                viewModel.presentPersistenceError(error)
            }
        }
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
                viewModel.presentTextImporter()
            } label: {
                Label("Importar desde texto", systemImage: "doc.on.clipboard")
            }

            Button {
                HapticFeedback.selection()
                viewModel.presentTemplates()
            } label: {
                Label("Usar plantilla", systemImage: "square.grid.2x2")
            }

            Button {
                HapticFeedback.selection()
                viewModel.presentHistory()
            } label: {
                Label("Historial", systemImage: "clock.arrow.circlepath")
            }

            Button {
                HapticFeedback.impact()
                viewModel.presentReceipt()
            } label: {
                Label("Registrar boleta", systemImage: "doc.text.viewfinder")
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
        case .receipt:
            ReceiptCaptureSheet(
                activeList: activeList,
                activeItems: activeItems,
                allItems: allItems,
                completedLists: completedLists,
                categories: categories
            )
        case .textImporter:
            TextImporterSheet(
                activeList: activeList,
                allItems: activeItems,
                categories: categories,
                viewModel: viewModel,
                onFinished: {
                    viewModel.updateDerivedState(items: activeItems, categories: categories)
                }
            )
        case .templates:
            TemplatesSheet(
                activeList: activeList,
                allItems: activeItems,
                categories: categories,
                viewModel: viewModel,
                onFinished: {
                    viewModel.updateDerivedState(items: activeItems, categories: categories)
                }
            )
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

        viewModel.resetCategoryCollapseState()

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
        do {
            try CategoryBootstrapService.bootstrap(context: modelContext)
            let list = try ShoppingListLifecycleService.createActiveList(in: modelContext)
            try SuggestedProducts.seedDefaultItems(in: modelContext, listID: list.id)
            try SuggestedProducts.seedCatalogItems(in: modelContext)
            UserDefaults.standard.set(true, forKey: "hasSeededDefaultProducts")
        } catch {
            viewModel.presentPersistenceError(error)
        }
        return true
    }
}
