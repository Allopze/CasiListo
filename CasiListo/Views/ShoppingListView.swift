import SwiftUI
import SwiftData

/// Vista que organiza y muestra la lista de compras con filtros, barra de adición rápida y categorías.
struct ShoppingListView: View {
    let activeList: ShoppingList?
    let allItems: [ShoppingItem]
    let categories: [Category]
    @Bindable var viewModel: ShoppingListViewModel
    let onEdit: (ShoppingItem) -> Void
    let onAddTapped: () -> Void
    var onArchivePurchased: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \ProductCatalogItem.name, order: .forward) private var catalogItems: [ProductCatalogItem]

    /// Coincidencias del catálogo para la búsqueda actual que aún no están en la lista.
    private var catalogSearchMatches: [ProductCatalogItem] {
        let query = viewModel.searchText
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let activeNames = Set(allItems.map { ProductNameNormalizer.normalize($0.name) })
        return Array(
            catalogItems
                .filter {
                    ProductNameNormalizer.contains($0.name, query: query)
                        && !activeNames.contains(ProductNameNormalizer.normalize($0.name))
                }
                .prefix(5)
        )
    }

    /// El chip de tienda solo aporta si la lista mezcla supermercados. Con una
    /// sola tienda repetía la misma etiqueta en cada fila —29 veces seguidas en
    /// una categoría— sin distinguir nada.
    private var listMixesStores: Bool {
        Set(allItems.map(\.store)).count > 1
    }

    @ScaledMetric(relativeTo: .body) private var cardPadding: CGFloat = Theme.cardPadding
    @ScaledMetric(relativeTo: .body) private var filterSpacing: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var listRowInsetTop: CGFloat = 10
    @ScaledMetric(relativeTo: .body) private var listRowInsetBottom: CGFloat = 4
    @ScaledMetric(relativeTo: .body) private var noResultsVerticalPadding: CGFloat = 60
    @State private var scrollTask: Task<Void, Never>?

    var body: some View {
        ScrollViewReader { scrollProxy in
            listContent(scrollProxy: scrollProxy)
        }
    }

    private func listContent(scrollProxy: ScrollViewProxy) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: filterSpacing) {
                    StoreFilterBar(selectedStore: $viewModel.selectedStore)

                    SummaryBarView(
                        pendingCount: viewModel.derivedSummary.pendingCount,
                        purchasedCount: viewModel.derivedSummary.purchasedCount,
                        showPurchased: $viewModel.showPurchased,
                        onArchivePurchased: onArchivePurchased
                    )
                }
                .listRowInsets(.init(
                    top: listRowInsetTop,
                    leading: cardPadding,
                    bottom: listRowInsetBottom,
                    trailing: cardPadding
                ))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if viewModel.derivedGroups.isEmpty {
                NoResultsView(
                    searchText: viewModel.searchText,
                    catalogMatches: catalogSearchMatches,
                    onQuickAddSearch: {
                        viewModel.quickAddText = viewModel.searchText
                        viewModel.addQuickItem(
                            to: activeList,
                            from: allItems,
                            categories: categories,
                            context: modelContext
                        )
                    },
                    onAddSearch: {
                        viewModel.quickAddText = viewModel.searchText
                        onAddTapped()
                    },
                    onAddCatalogItem: { catalogItem in
                        do {
                            try CatalogService.addToActiveList(
                                catalogItem,
                                activeList: activeList,
                                activeItems: allItems,
                                context: modelContext
                            )
                        } catch {
                            viewModel.presentPersistenceError(error)
                        }
                    }
                )
                .listRowInsets(.init(
                    top: noResultsVerticalPadding,
                    leading: cardPadding,
                    bottom: noResultsVerticalPadding,
                    trailing: cardPadding
                ))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.derivedGroups, id: \.category) { group in
                    CategorySectionView(
                        category: group.category,
                        items: group.items,
                        searchText: viewModel.searchText,
                        showsStore: viewModel.selectedStore == nil && listMixesStores,
                        isCollapsed: viewModel.isCategoryCollapsed(
                            group.category,
                            forceExpanded: !viewModel.searchText.isEmpty
                        ),
                        onToggleCollapse: {
                            viewModel.toggleCategoryCollapse(group.category)
                        },
                        onTogglePurchased: { item in
                            viewModel.togglePurchased(item, context: modelContext)
                        },
                        onEdit: onEdit,
                        onDelete: { item in
                            viewModel.deleteItem(item, context: modelContext)
                        },
                        onMarkStatus: { item, status in
                            viewModel.markItem(item, as: status, context: modelContext)
                        },
                        onMove: viewModel.allowsManualReorder
                            ? { item, direction in
                                viewModel.moveItem(item, direction: direction, context: modelContext)
                            }
                            : nil
                    )
                }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(.custom(14))
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 1)
        .background(Color.appBackground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                if viewModel.showUndoToast, let buffer = viewModel.deletedItemUndoBuffer {
                    UndoToastView(itemName: buffer.name) {
                        viewModel.undoLastDelete(context: modelContext)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                BottomAddBarView(
                    text: $viewModel.quickAddText,
                    onAddQuick: {
                        viewModel.addQuickItem(
                            to: activeList,
                            from: allItems,
                            categories: categories,
                            context: modelContext
                        )
                    },
                    onAddTapped: onAddTapped
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .background(Color.appBackground.ignoresSafeArea(edges: .bottom))
        }
        .animation(Theme.defaultAnimation(reduceMotion: reduceMotion), value: viewModel.showPurchased)
        .onAppear {
            viewModel.bind(listID: activeList?.id)
            viewModel.updateDerivedState(items: allItems, categories: categories)
        }
        .onChange(of: activeList?.id) { _, newID in
            viewModel.bind(listID: newID)
            viewModel.updateDerivedState(items: allItems, categories: categories)
        }
        .onChange(of: allItems) { _, _ in
            viewModel.updateDerivedState(items: allItems, categories: categories)
        }
        .onChange(of: viewModel.scrollTargetItemID) { _, target in
            guard let target else { return }
            scrollTask?.cancel()
            // Pequeña espera para que la expansión de la categoría materialice
            // las filas antes de desplazar.
            scrollTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(80))
                guard !Task.isCancelled else { return }
                withAnimation(Theme.defaultAnimation(reduceMotion: reduceMotion)) {
                    scrollProxy.scrollTo("item-row-\(target)", anchor: .center)
                }
                viewModel.clearScrollTarget()
            }
        }
        .onChange(of: categories) { _, _ in
            viewModel.updateDerivedState(items: allItems, categories: categories)
        }
        .onChange(of: viewModel.selectedStore) { _, _ in
            viewModel.rederiveFilters()
        }
        .onChange(of: viewModel.showPurchased) { _, _ in
            viewModel.rederiveFilters()
        }
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.rederiveFilters()
        }
    }
}
