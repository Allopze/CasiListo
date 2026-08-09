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
    var onArchivePurchased: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext

    @ScaledMetric(relativeTo: .body) private var cardPadding: CGFloat = Theme.cardPadding
    @ScaledMetric(relativeTo: .body) private var filterSpacing: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var listRowInsetTop: CGFloat = 10
    @ScaledMetric(relativeTo: .body) private var listRowInsetBottom: CGFloat = 4
    @ScaledMetric(relativeTo: .body) private var noResultsVerticalPadding: CGFloat = 60

    var body: some View {
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
                    onAddSearch: {
                        viewModel.quickAddText = viewModel.searchText
                        onAddTapped()
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
                        isCollapsed: viewModel.isCategoryCollapsed(group.category),
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
                        }
                    )
                }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 1)
        .background(Color.appBackground)
        .refreshable {
            HapticFeedback.selection()
            viewModel.updateDerivedState(items: allItems, categories: categories)
        }
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
        }
        .animation(Theme.defaultAnimation, value: viewModel.showPurchased)
        .onAppear {
            viewModel.updateDerivedState(items: allItems, categories: categories)
        }
        .onChange(of: allItems) { _, _ in
            viewModel.updateDerivedState(items: allItems, categories: categories)
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
