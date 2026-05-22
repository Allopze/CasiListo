import SwiftUI
import SwiftData

/// Vista principal de la app. Muestra la lista de compra agrupada por categorías,
/// con buscador, menú de opciones y acciones Liquid Glass de iOS 26.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingItem.createdAt, order: .forward) private var allItems: [ShoppingItem]
    @State private var viewModel = ShoppingListViewModel()
    @State private var showsClearPurchasedDialog = false
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                if allItems.isEmpty {
                    EmptyStateView {
                        presentAddItem()
                    }
                } else {
                    ShoppingListView(
                        allItems: allItems,
                        viewModel: viewModel,
                        onEdit: { item in
                            viewModel.presentEditItem(item)
                        },
                        onAddTapped: {
                            presentAddItem()
                        }
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
                ToolbarItem(placement: .topBarTrailing) {
                    menuButton
                }

                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    addButton
                }
            }
            .sheet(item: $viewModel.presentedSheet) { destination in
                sheetContent(for: destination)
            }
            .confirmationDialog(
                "Borrar productos comprados",
                isPresented: $showsClearPurchasedDialog,
                titleVisibility: .visible
            ) {
                Button("Borrar \(viewModel.itemCounts(from: allItems).purchased) comprados", role: .destructive) {
                    HapticFeedback.impact()
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
        .task {
            let hasSeeded = UserDefaults.standard.bool(forKey: "hasSeededDefaultProducts")
            if !hasSeeded {
                seedDefaultItems()
                UserDefaults.standard.set(true, forKey: "hasSeededDefaultProducts")
            }
        }
    }

    private func seedDefaultItems() {
        var order = 0
        for category in Category.allCases {
            guard let products = SuggestedProducts.byCategory[category] else { continue }
            for productName in products {
                let newItem = ShoppingItem(
                    name: productName,
                    quantity: "",
                    category: category,
                    note: "",
                    isPurchased: false,
                    sortOrder: order
                )
                modelContext.insert(newItem)
                order += 1
            }
        }
        try? modelContext.save()
    }

    // MARK: - Botones toolbar

    private var addButton: some View {
        Button {
            presentAddItem()
        } label: {
            Image(systemName: "plus")
                .fontWeight(.semibold)
        }
        .adaptiveGlassButtonStyle()
        .accessibilityLabel("Añadir producto")
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

            Button {
                HapticFeedback.selection()
                viewModel.presentSettings()
            } label: {
                Label("Ajustes", systemImage: "gearshape")
            }

            if viewModel.itemCounts(from: allItems).purchased > 0 {
                Button(role: .destructive) {
                    showsClearPurchasedDialog = true
                } label: {
                    Label("Borrar comprados", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .adaptiveGlassButtonStyle()
        .accessibilityLabel("Opciones")
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(for destination: ShoppingListSheetDestination) -> some View {
        switch destination {
        case .addItem:
            AddEditItemSheet(
                mode: .add,
                allItems: allItems,
                viewModel: viewModel
            )
        case .editItem(let item):
            AddEditItemSheet(
                mode: .edit(item),
                allItems: allItems,
                viewModel: viewModel
            )
        case .settings:
            SettingsSheet()
        }
    }

    private func presentAddItem() {
        HapticFeedback.impact()
        viewModel.presentAddItem()
    }
}

// MARK: - Subviews

private struct SummaryBarView: View {
    let pendingCount: Int
    let purchasedCount: Int
    @Binding var showPurchased: Bool
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    var body: some View {
        AdaptiveGlassEffectContainer(spacing: 12) {
            HStack(spacing: 14 * CGFloat(accessibilityTextSizeScale)) {
                Label("\(pendingCount) pendientes", systemImage: "circle")
                    .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(Color.appTextSecondary)

                if purchasedCount > 0 {
                    Label("\(purchasedCount) comprados", systemImage: "checkmark.circle.fill")
                        .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(Theme.accentYellow)
                }

                Spacer(minLength: 12)

                Button {
                    HapticFeedback.selection()
                    withAnimation(Theme.defaultAnimation) {
                        showPurchased.toggle()
                    }
                } label: {
                    Label(
                        showPurchased ? "Ocultar" : "Mostrar",
                        systemImage: showPurchased ? "eye.slash" : "eye"
                    )
                    .labelStyle(.iconOnly)
                    .font(.system(size: 15 * CGFloat(accessibilityTextSizeScale), weight: .semibold))
                    .frame(width: 36 * CGFloat(accessibilityTextSizeScale), height: 32 * CGFloat(accessibilityTextSizeScale))
                }
                .buttonStyle(.plain)
                .glassFilterSurface(cornerRadius: 16 * CGFloat(accessibilityTextSizeScale), interactive: true)
                .accessibilityLabel(showPurchased ? "Ocultar comprados" : "Mostrar comprados")
            }
            .padding(.leading, 16 * CGFloat(accessibilityTextSizeScale))
            .padding(.trailing, 8 * CGFloat(accessibilityTextSizeScale))
            .padding(.vertical, 8 * CGFloat(accessibilityTextSizeScale))
            .glassFilterSurface(cornerRadius: Theme.cornerRadius(scale: accessibilityTextSizeScale))
        }
        .accessibilityElement(children: .contain)
    }
}

private struct NoResultsView: View {
    let searchText: String
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    var body: some View {
        VStack(spacing: 12 * CGFloat(accessibilityTextSizeScale)) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40 * CGFloat(accessibilityTextSizeScale)))
                .foregroundStyle(Color.appTextPurchased)

            Text("Sin resultados")
                .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.appTextSecondary)

            Text("No se encontraron productos para \"\(searchText)\"")
                .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.appTextPurchased)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
    }
}

private struct BottomAddBarView: View {
    let onAddTapped: () -> Void
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    var body: some View {
        AdaptiveGlassEffectContainer(spacing: 12) {
            HStack {
                Spacer()

                Button {
                    onAddTapped()
                } label: {
                    Label("Añadir producto", systemImage: "plus")
                        .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                        .padding(.vertical, 4 * CGFloat(accessibilityTextSizeScale))
                }
                .adaptiveGlassProminentButtonStyle()
            }
            .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale))
            .padding(.top, 8)
            .padding(.bottom, 10 * CGFloat(accessibilityTextSizeScale))
            .background(Color.appBackground.opacity(0.68))
        }
    }
}

private struct ShoppingListView: View {
    let allItems: [ShoppingItem]
    @Bindable var viewModel: ShoppingListViewModel
    let onEdit: (ShoppingItem) -> Void
    let onAddTapped: () -> Void
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    var body: some View {
        let groups = viewModel.groupedItems(from: allItems)

        let counts = viewModel.itemCounts(from: allItems)

        List {
            Section {
                SummaryBarView(
                    pendingCount: counts.pending,
                    purchasedCount: counts.purchased,
                    showPurchased: $viewModel.showPurchased
                )
                .listRowInsets(.init(
                    top: 10 * CGFloat(accessibilityTextSizeScale),
                    leading: Theme.cardPadding(scale: accessibilityTextSizeScale),
                    bottom: 4 * CGFloat(accessibilityTextSizeScale),
                    trailing: Theme.cardPadding(scale: accessibilityTextSizeScale)
                ))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if groups.isEmpty {
                NoResultsView(searchText: viewModel.searchText)
                    .listRowInsets(.init(top: 60, leading: Theme.cardPadding(scale: accessibilityTextSizeScale), bottom: 60, trailing: Theme.cardPadding(scale: accessibilityTextSizeScale)))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(groups, id: \.category) { group in
                    CategorySectionView(
                        category: group.category,
                        items: group.items,
                        viewModel: viewModel,
                        onEdit: onEdit
                    )
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 1)
        .background(Color.appBackground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomAddBarView(onAddTapped: onAddTapped)
        }
        .animation(Theme.defaultAnimation, value: viewModel.showPurchased)
        .animation(Theme.defaultAnimation, value: viewModel.searchText)
    }
}
