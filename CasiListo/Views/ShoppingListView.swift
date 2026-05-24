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

    private var groups: [(category: Category, items: [ShoppingItem])] {
        viewModel.groupedItems(from: allItems, categories: categories)
    }

    private var summary: ShoppingListViewModel.ListSummary {
        viewModel.summary(from: allItems)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: filterSpacing) {
                    StoreFilterBar(selectedStore: $viewModel.selectedStore)
                    
                    SummaryBarView(
                        pendingCount: summary.pendingCount,
                        purchasedCount: summary.purchasedCount,
                        pendingTotal: summary.pendingTotal,
                        purchasedTotal: summary.purchasedTotal,
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

            if groups.isEmpty {
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
                ForEach(groups, id: \.category) { group in
                    CategorySectionView(
                        category: group.category,
                        items: group.items,
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
                        },
                        onMove: { source, destination in
                            viewModel.moveItem(from: source, to: destination, within: group.items, context: modelContext)
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
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
        .animation(Theme.defaultAnimation, value: viewModel.showPurchased)
    }
}
