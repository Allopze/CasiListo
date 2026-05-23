import SwiftUI
import SwiftData

/// Pantalla en pantalla completa para enfocar la experiencia de compra en el supermercado.
struct ShoppingModeView: View {
    let allItems: [ShoppingItem]
    let onFinished: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    
    @State private var sessionViewModel: ShoppingModeViewModel? = nil
    @State private var preselectedStore: Store = .jumbo
    
    var body: some View {
        ZStack {
            Color.shoppingModeBackground.ignoresSafeArea()
            
            if let viewModel = sessionViewModel {
                if viewModel.isCompleted {
                    CompletionCelebrationView(
                        storeName: viewModel.store.displayName,
                        productsCount: viewModel.totalCount,
                        totalSpent: viewModel.items.compactMap(\.price).reduce(0, +),
                        onDismiss: {
                            recordCompletedPurchase(viewModel: viewModel)
                            onFinished()
                        }
                    )
                    .transition(.opacity)
                } else {
                    ShoppingModeActiveView(
                        viewModel: viewModel,
                        onBack: {
                            withAnimation(.spring()) {
                                self.sessionViewModel = nil
                            }
                        },
                        onExit: {
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
                            let vm = ShoppingModeViewModel(store: preselectedStore, allItems: allItems)
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
    
    private func recordCompletedPurchase(viewModel: ShoppingModeViewModel) {
        var stats = UserStats.load()
        stats.recordPurchase(productsCount: viewModel.totalCount)
    }
}
