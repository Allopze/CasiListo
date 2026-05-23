import SwiftUI
import SwiftData

/// Vista principal de la app.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingItem.createdAt, order: .forward) private var allItems: [ShoppingItem]
    @State private var viewModel = ShoppingListViewModel()
    @State private var showsClearPurchasedDialog = false
    @State private var showsShoppingMode = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if showsShoppingMode {
                ShoppingModeView(
                    allItems: allItems,
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

                        if allItems.isEmpty {
                            EmptyStateView { presentAddItem() }
                        } else {
                            ShoppingListView(
                                allItems: allItems,
                                viewModel: viewModel,
                                onEdit: { viewModel.presentEditItem($0) },
                                onAddTapped: { presentAddItem() }
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
                        ToolbarItem(placement: .topBarLeading) { shoppingModeButton }
                        ToolbarItem(placement: .topBarTrailing) { menuButton }
                        if #available(iOS 26.0, *) {
                            ToolbarSpacer(.fixed, placement: .topBarTrailing)
                        }
                        ToolbarItem(placement: .topBarTrailing) { addButton }
                    }
                    .sheet(item: $viewModel.presentedSheet) { sheetContent(for: $0) }
                    .confirmationDialog(
                        "Borrar productos comprados",
                        isPresented: $showsClearPurchasedDialog,
                        titleVisibility: .visible
                    ) {
                        Button("Borrar \(viewModel.itemCounts(from: allItems).purchased) comprados", role: .destructive) {
                            HapticFeedback.impact()
                            let purchasedCount = viewModel.itemCounts(from: allItems).purchased
                            var stats = UserStats.load()
                            stats.recordPurchase(productsCount: purchasedCount)
                            withAnimation(Theme.defaultAnimation) {
                                viewModel.clearPurchased(items: allItems, context: modelContext)
                            }
                        }
                        Button("Cancelar", role: .cancel) {}
                    } message: {
                        Text("Esta acción elimina todos los productos marcados como comprados.")
                    }
                }
                .tint(Theme.accentYellow)
            }
        }
        .task {
            GeofenceService.shared.initialize(with: modelContext.container)
            let hasSeeded = UserDefaults.standard.bool(forKey: "hasSeededDefaultProducts")
            if !hasSeeded {
                SuggestedProducts.seedDefaultItems(in: modelContext)
                UserDefaults.standard.set(true, forKey: "hasSeededDefaultProducts")
            }
        }
    }

    private var addButton: some View {
        Button { presentAddItem() } label: {
            Image(systemName: "plus").fontWeight(.semibold)
        }
        .adaptiveGlassButtonStyle()
        .accessibilityLabel("Añadir producto")
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
        .adaptiveGlassButtonStyle()
        .accessibilityLabel("Entrar a Modo Compra")
    }

    private var formattedShareText: String {
        let groups = viewModel.groupedItems(from: allItems)
        let storeTitle = viewModel.selectedStore?.displayName ?? "Todos"
        guard !groups.isEmpty else { return "Mi lista de compras en CasiListo (\(storeTitle)) está vacía." }
        
        var text = "📝 *Lista de Compras: CasiListo (\(storeTitle))*\n\n"
        for group in groups {
            text += "*\(group.category.displayName.uppercased())*\n"
            for item in group.items {
                let check = item.isPurchased ? "✅" : "⬜"
                let qty = item.quantity.isEmpty ? "" : " (\(item.quantity))"
                let priceStr = item.price.map { " - \($0.formattedPriceWithSymbol)" } ?? ""
                let note = item.note.isEmpty ? "" : " [Nota: \(item.note)]"
                text += "\(check) \(item.name)\(qty)\(priceStr)\(note)\n"
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
                viewModel.presentSettings()
            } label: {
                Label("Ajustes", systemImage: "gearshape")
            }

            if viewModel.itemCounts(from: allItems).purchased > 0 {
                Button(role: .destructive) { showsClearPurchasedDialog = true } label: {
                    Label("Borrar comprados", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .adaptiveGlassButtonStyle()
        .accessibilityLabel("Opciones")
    }

    @ViewBuilder
    private func sheetContent(for destination: ShoppingListSheetDestination) -> some View {
        switch destination {
        case .addItem:
            AddEditItemSheet(mode: .add, allItems: allItems, viewModel: viewModel)
        case .editItem(let item):
            AddEditItemSheet(mode: .edit(item), allItems: allItems, viewModel: viewModel)
        case .settings:
            SettingsSheet()
        }
    }

    private func presentAddItem() {
        HapticFeedback.impact()
        viewModel.presentAddItem()
    }
}
