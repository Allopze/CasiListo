import SwiftUI
import SwiftData

/// Pantalla en pantalla completa para enfocar la experiencia de compra en el supermercado.
struct ShoppingModeView: View {
    let activeList: ShoppingList?
    let allItems: [ShoppingItem]
    let selectedStore: Store?
    let onFinished: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortIndex) private var categories: [Category]
    
    @State private var sessionViewModel: ShoppingModeViewModel? = nil
    @State private var chosenStore: Store? = nil

    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

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
                            onCancel()
                        },
                        onExit: {
                            viewModel.stopSession()
                            onCancel()
                        }
                    )
                    .transition(.slide)
                }
            } else if chosenStore == nil {
                // Sin supermercado preseleccionado: mostrar selector rápido
                storePickerView
                    .transition(.opacity)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .animation(.easeInOut, value: sessionViewModel == nil)
        .animation(.easeInOut, value: chosenStore)
        .onAppear {
            if let store = selectedStore {
                chosenStore = store
            }
        }
        .onChange(of: chosenStore) { _, newStore in
            guard let store = newStore, sessionViewModel == nil else { return }
            let vm = ShoppingModeViewModel(store: store, allItems: allItems, allCategories: categories)
            vm.startSession()
            self.sessionViewModel = vm
        }
    }

    private var storePickerView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "cart.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accentYellow)

            Text("¿En qué supermercado estás?")
                .font(Theme.sectionHeaderFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.shoppingModeText)

            VStack(spacing: 12) {
                ForEach(Store.allCases) { store in
                    Button {
                        HapticFeedback.impact()
                        chosenStore = store
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: store.sfSymbol)
                                .font(.system(size: 18, weight: .bold))
                            Text(store.displayName)
                                .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(store.color)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 40)

            Button {
                HapticFeedback.selection()
                onCancel()
            } label: {
                Text("Cancelar")
                    .font(Theme.bodyFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(Color.shoppingModeSecondaryText)
                    .frame(minHeight: Theme.minimumTouchTarget)
            }
            .buttonStyle(.plain)

            Spacer()
            Spacer()
        }
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

