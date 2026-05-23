import SwiftUI
import SwiftData

/// Vista que organiza y muestra la lista de compras con filtros, barra de adición rápida y categorías.
struct ShoppingListView: View {
    let allItems: [ShoppingItem]
    @Bindable var viewModel: ShoppingListViewModel
    let onEdit: (ShoppingItem) -> Void
    let onAddTapped: () -> Void
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let groups = viewModel.groupedItems(from: allItems)
        let counts = viewModel.itemCounts(from: allItems)

        List {
            Section {
                VStack(alignment: .leading, spacing: 12 * CGFloat(accessibilityTextSizeScale)) {
                    StoreFilterBar(selectedStore: $viewModel.selectedStore)
                    
                    SummaryBarView(
                        pendingCount: counts.pending,
                        purchasedCount: counts.purchased,
                        pendingTotal: viewModel.pendingTotal(from: allItems),
                        purchasedTotal: viewModel.purchasedTotal(from: allItems),
                        showPurchased: $viewModel.showPurchased
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
                NoResultsView(
                    searchText: viewModel.searchText,
                    onAddSearch: {
                        viewModel.quickAddText = viewModel.searchText
                        onAddTapped()
                    }
                )
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
                onAddQuick: addQuickItem,
                onAddTapped: onAddTapped
            )
        }
        .animation(Theme.defaultAnimation, value: viewModel.showPurchased)
    }

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
}
