import SwiftUI
import SwiftData

/// Vista que gestiona la sesión de compra activa y el recorrido por categorías.
struct ShoppingModeActiveView: View {
    @Bindable var viewModel: ShoppingModeViewModel
    let onBack: () -> Void
    let onExit: () -> Void
    @Environment(\.modelContext) private var modelContext
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    var body: some View {
        VStack(spacing: 0) {
            ShoppingModeHeaderView(viewModel: viewModel, onBack: onBack, onExit: onExit)
            
            if viewModel.items.isEmpty {
                emptyStoreView
            } else if viewModel.categories.isEmpty {
                allPurchasedView
            } else {
                activeCategoryListView
            }
            
            Spacer(minLength: 0)
            
            if !viewModel.categories.isEmpty {
                bottomActionBar
            }
        }
    }

    private var emptyStoreView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "cart.badge.questionmark")
                .font(.system(size: 60))
                .foregroundStyle(Color.appTextSecondary)
            Text("No hay productos asignados a \(viewModel.store.displayName)")
                .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.appTextPrimary)
            Text("Asigna productos a esta tienda en la lista principal para verlos aquí.")
                .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var allPurchasedView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.green)
            Text("¡No hay productos pendientes!")
                .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.appTextPrimary)
            Text("Todos tus artículos para \(viewModel.store.displayName) ya fueron comprados.")
                .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.appTextSecondary)
                .padding(.horizontal, 40)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    @ViewBuilder
    private var activeCategoryListView: some View {
        if let activeCategory = viewModel.activeCategory {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: activeCategory.sfSymbol)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.accentYellow)
                    
                    Text(activeCategory.displayName.uppercased())
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    let categoryItems = viewModel.items.filter { $0.category == activeCategory }
                    let catPurchased = categoryItems.filter { $0.isPurchased }.count
                    Text("\(catPurchased)/\(categoryItems.count)")
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.04))
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.activeItems) { item in
                            ShoppingModeItemRow(item: item) {
                                viewModel.toggleItem(item, context: modelContext)
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    private var bottomActionBar: some View {
        HStack(spacing: 16) {
            Button {
                HapticFeedback.selection()
                viewModel.previousCategory()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.activeCategoryIndex == 0)
            .opacity(viewModel.activeCategoryIndex == 0 ? 0.3 : 1.0)
            
            Spacer()
            
            if viewModel.categories.count > 0 {
                VStack(spacing: 4) {
                    Text("Categoría \(viewModel.activeCategoryIndex + 1) de \(viewModel.categories.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.appTextSecondary)
                    
                    Button {
                        HapticFeedback.selection()
                        viewModel.nextCategory()
                    } label: {
                        Text("Saltar Categoría")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.accentYellow)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.activeCategoryIndex == viewModel.categories.count - 1)
                    .opacity(viewModel.activeCategoryIndex == viewModel.categories.count - 1 ? 0.0 : 1.0)
                }
            }
            
            Spacer()
            
            Button {
                HapticFeedback.selection()
                viewModel.nextCategory()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.activeCategoryIndex == viewModel.categories.count - 1)
            .opacity(viewModel.activeCategoryIndex == viewModel.categories.count - 1 ? 0.3 : 1.0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(Color.appCardBackground)
    }
}
