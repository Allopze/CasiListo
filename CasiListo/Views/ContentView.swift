import SwiftUI
import SwiftData

/// Vista principal de la app. Muestra la lista de compra agrupada por categorías,
/// con buscador, menú de opciones y acciones Liquid Glass de iOS 26.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingItem.createdAt, order: .forward) private var allItems: [ShoppingItem]
    @State private var viewModel = ShoppingListViewModel()
    @State private var showsClearPurchasedDialog = false
    @State private var showsShoppingMode = false
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
                ToolbarItem(placement: .topBarLeading) {
                    shoppingModeButton
                }

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
        .fullScreenCover(isPresented: $showsShoppingMode) {
            ShoppingModeView(allItems: allItems) {
                // Al finalizar
            }
        }
        .tint(Theme.accentYellow)
        .task {
            // Inicializar el servicio de geolocalización con el contenedor de SwiftData
            GeofenceService.shared.initialize(with: modelContext.container)
            
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

    private var shoppingModeButton: some View {
        Button {
            HapticFeedback.selection()
            showsShoppingMode = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "cart.fill")
                    .fontWeight(.semibold)
                Text("Comprar")
                    .font(.system(size: 13, weight: .bold))
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
    let pendingTotal: Double
    let purchasedTotal: Double
    @Binding var showPurchased: Bool
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    var body: some View {
        let pendingTotalStr = pendingTotal.formattedPrice
        let purchasedTotalStr = purchasedTotal.formattedPrice

        let pendingLabel = pendingTotal > 0 ? "\(pendingCount) pendientes ($\(pendingTotalStr))" : "\(pendingCount) pendientes"
        let purchasedLabel = purchasedTotal > 0 ? "\(purchasedCount) comprados ($\(purchasedTotalStr))" : "\(purchasedCount) comprados"

        return AdaptiveGlassEffectContainer(spacing: 12) {
            HStack(spacing: 14 * CGFloat(accessibilityTextSizeScale)) {
                Label(pendingLabel, systemImage: "circle")
                    .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(Color.appTextSecondary)

                if purchasedCount > 0 {
                    Label(purchasedLabel, systemImage: "checkmark.circle.fill")
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
    @Binding var text: String
    let onAddQuick: () -> Void
    let onAddTapped: () -> Void
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0
    @State private var suggestions: [String] = []

    var body: some View {
        AdaptiveGlassEffectContainer(spacing: 8) {
            VStack(spacing: 6) {
                // Suggestions horizontal chip list (debounced)
                if !text.isEmpty && !suggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestions.prefix(5), id: \.self) { suggestion in
                                Button {
                                    HapticFeedback.selection()
                                    text = suggestion
                                    onAddQuick()
                                } label: {
                                    Text(suggestion)
                                        .font(Theme.chipFont(scale: accessibilityTextSizeScale))
                                        .foregroundStyle(Color.appTextPrimary)
                                        .padding(.horizontal, 12 * CGFloat(accessibilityTextSizeScale))
                                        .padding(.vertical, 6 * CGFloat(accessibilityTextSizeScale))
                                        .glassFilterSurface(cornerRadius: Theme.chipCornerRadius, interactive: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale))
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.top, 4)
                }

                HStack(spacing: 10 * CGFloat(accessibilityTextSizeScale)) {
                    // Text input field
                    HStack {
                        Image(systemName: "cart.badge.plus")
                            .font(.system(size: 14 * CGFloat(accessibilityTextSizeScale)))
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.leading, 12 * CGFloat(accessibilityTextSizeScale))

                        TextField("Añadir rápido...", text: $text)
                            .font(Theme.bodyFont(scale: accessibilityTextSizeScale))
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit {
                                if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                                    onAddQuick()
                                }
                            }
                    }
                    .frame(height: 40 * CGFloat(accessibilityTextSizeScale))
                    .glassFilterSurface(cornerRadius: Theme.controlCornerRadius(scale: accessibilityTextSizeScale), interactive: true)

                    if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                        // Quick add confirmation button (+)
                        Button {
                            onAddQuick()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28 * CGFloat(accessibilityTextSizeScale)))
                                .foregroundStyle(Theme.accentYellow)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Añadir instantáneamente")

                        // Open details modal button
                        Button {
                            onAddTapped()
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: 28 * CGFloat(accessibilityTextSizeScale)))
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Añadir con detalles")
                    } else {
                        // Classic add button (opens sheet)
                        Button {
                            onAddTapped()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28 * CGFloat(accessibilityTextSizeScale)))
                                .foregroundStyle(Theme.accentYellow)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Añadir producto")
                    }
                }
                .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale))
                .padding(.top, 4)
                .padding(.bottom, 8 * CGFloat(accessibilityTextSizeScale))
            }
            .background(Color.appBackground.opacity(0.85))
        }
        .task(id: text) {
            // Debounce: espera 150ms antes de filtrar sugerencias
            try? await Task.sleep(for: .milliseconds(150))
            suggestions = SuggestedProducts.suggestions(for: text)
        }
    }
}

private struct ShoppingListView: View {
    let allItems: [ShoppingItem]
    @Bindable var viewModel: ShoppingListViewModel
    let onEdit: (ShoppingItem) -> Void
    let onAddTapped: () -> Void
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0
    @Environment(\.modelContext) private var modelContext

    private func addQuickItem() {
        let name = viewModel.quickAddText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let category = SuggestedProducts.suggestedCategory(for: name) ?? .varios
        let store = viewModel.selectedStore ?? SuggestedProducts.suggestedStore(for: name)
        let newItem = ShoppingItem(
            name: name,
            quantity: "",
            category: category,
            note: "",
            isPurchased: false,
            sortOrder: viewModel.nextSortOrder(for: category, in: allItems),
            store: store
        )
        withAnimation(Theme.defaultAnimation) {
            modelContext.insert(newItem)
            viewModel.quickAddText = ""
        }
        HapticFeedback.success()
    }

    private var storeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8 * CGFloat(accessibilityTextSizeScale)) {
                filterChip(title: "Todos", store: nil, icon: "house.fill")
                ForEach(Store.allCases) { store in
                    filterChip(title: store.displayName, store: store, icon: store.sfSymbol)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func filterChip(title: String, store: Store?, icon: String) -> some View {
        let isSelected = viewModel.selectedStore == store
        let activeColor = store?.color ?? Theme.accentYellow

        Button {
            HapticFeedback.selection()
            withAnimation(Theme.defaultAnimation) {
                viewModel.selectedStore = store
            }
        } label: {
            HStack(spacing: 6 * CGFloat(accessibilityTextSizeScale)) {
                Image(systemName: icon)
                    .font(.system(size: 13 * CGFloat(accessibilityTextSizeScale), weight: .semibold))
                Text(title)
                    .font(Theme.chipFont(scale: accessibilityTextSizeScale))
                    .bold()
            }
            .padding(.horizontal, 14 * CGFloat(accessibilityTextSizeScale))
            .padding(.vertical, 8 * CGFloat(accessibilityTextSizeScale))
            .foregroundStyle(isSelected ? Color.white : Color.appTextPrimary)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12 * CGFloat(accessibilityTextSizeScale), style: .continuous)
                        .fill(activeColor)
                } else {
                    RoundedRectangle(cornerRadius: 12 * CGFloat(accessibilityTextSizeScale), style: .continuous)
                        .fill(Color.appCardBackground.opacity(0.4))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12 * CGFloat(accessibilityTextSizeScale), style: .continuous)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        }
                }
            }
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        let groups = viewModel.groupedItems(from: allItems)

        let counts = viewModel.itemCounts(from: allItems)
        let pendingTotal = viewModel.pendingTotal(from: allItems)
        let purchasedTotal = viewModel.purchasedTotal(from: allItems)

        List {
            Section {
                VStack(alignment: .leading, spacing: 12 * CGFloat(accessibilityTextSizeScale)) {
                    storeFilterBar
                    
                    SummaryBarView(
                        pendingCount: counts.pending,
                        purchasedCount: counts.purchased,
                        pendingTotal: pendingTotal,
                        purchasedTotal: purchasedTotal,
                        showPurchased: $viewModel.showPurchased
                    )
                    
                    BudgetMeterView(
                        currentTotal: viewModel.grandTotal(from: allItems),
                        selectedStore: viewModel.selectedStore
                    )
                }
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
            BottomAddBarView(
                text: $viewModel.quickAddText,
                onAddQuick: {
                    addQuickItem()
                },
                onAddTapped: onAddTapped
            )
        }
        .animation(Theme.defaultAnimation, value: viewModel.showPurchased)
    }
}
