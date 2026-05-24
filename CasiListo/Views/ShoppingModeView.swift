import SwiftUI
import SwiftData

/// Pantalla en pantalla completa para enfocar la experiencia de compra en el supermercado.
struct ShoppingModeView: View {
    let activeList: ShoppingList?
    let allItems: [ShoppingItem]
    let onFinished: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortIndex) private var categories: [Category]
    
    @State private var sessionViewModel: ShoppingModeViewModel? = nil
    @State private var preselectedStore: Store = .jumbo
    
    var body: some View {
        ZStack {
            Color.shoppingModeBackground.ignoresSafeArea()
            
            if let viewModel = sessionViewModel {
                if viewModel.isCompleted {
                    CompletionCelebrationView(
                        storeName: viewModel.store.displayName,
                        productsCount: viewModel.purchasedCount,
                        onDismiss: {
                            finishSession(viewModel: viewModel, clearPurchased: false)
                        },
                        onClearPurchasedAndDismiss: {
                            finishSession(viewModel: viewModel, clearPurchased: true)
                        }
                    )
                    .transition(.opacity)
                } else {
                    ShoppingModeActiveView(
                        viewModel: viewModel,
                        onBack: {
                            viewModel.stopSession()
                            withAnimation(.spring()) {
                                self.sessionViewModel = nil
                            }
                        },
                        onExit: {
                            viewModel.stopSession()
                            onCancel()
                        }
                    )
                    .transition(.slide)
                }
            } else {
                StoreSelectorView(
                    preselectedStore: $preselectedStore,
                    onDismiss: { onCancel() },
                    onStart: {
                        withAnimation(.spring()) {
                            let vm = ShoppingModeViewModel(store: preselectedStore, allItems: allItems, allCategories: categories)
                            vm.startSession()
                            self.sessionViewModel = vm
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: sessionViewModel == nil)
    }
    
    private func finishSession(viewModel: ShoppingModeViewModel, clearPurchased: Bool) {
        var stats = UserStats.load()
        stats.recordPurchase(productsCount: viewModel.purchasedCount)

        if clearPurchased {
            ShoppingListLifecycleService.archivePurchasedItems(
                from: viewModel.items,
                activeList: activeList,
                store: viewModel.store,
                context: modelContext
            )
        }

        onFinished()
    }
}
