import SwiftUI
import SwiftData

/// Vista que gestiona la sesión de compra activa y el recorrido por categorías.
struct ShoppingModeActiveView: View {
    @Bindable var viewModel: ShoppingModeViewModel
    let onBack: () -> Void
    let onExit: () -> Void
    @Environment(\.modelContext) private var modelContext

    @ScaledMetric(relativeTo: .body) private var emptyImageSize: CGFloat = 60
    @ScaledMetric(relativeTo: .body) private var headerIconSize: CGFloat = 20
    @ScaledMetric(relativeTo: .body) private var categoryProgressPaddingHorizontal: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var categoryProgressPaddingVertical: CGFloat = 4
    @ScaledMetric(relativeTo: .body) private var categoryRowSpacing: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var categoryPadding: CGFloat = 20
    @ScaledMetric(relativeTo: .body) private var arrowIconSize: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var arrowButtonSize: CGFloat = 48

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
                .font(.system(size: emptyImageSize))
                .foregroundStyle(Color.shoppingModeSecondaryText)
            Text("No hay productos asignados a \(viewModel.store.displayName)")
                .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.shoppingModeText)
            Text("Asigna productos a esta tienda en la lista principal para verlos aquí.")
                .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.shoppingModeSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var allPurchasedView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: emptyImageSize))
                .foregroundStyle(Color.green)
            Text("¡No hay productos pendientes!")
                .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.shoppingModeText)
            Text("Todos tus artículos para \(viewModel.store.displayName) ya fueron comprados.")
                .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.shoppingModeSecondaryText)
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
                        .font(.system(size: headerIconSize, weight: .bold))
                        .foregroundStyle(Theme.accentYellow)
                    
                    Text(activeCategory.displayName.uppercased())
                        .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale).weight(.black))
                        .foregroundStyle(Color.shoppingModeText)
                    
                    Spacer()
                    
                    let categoryProgress = viewModel.categoryProgress(for: activeCategory)
                    Text("\(categoryProgress.purchased)/\(categoryProgress.total)")
                        .font(Theme.captionFont(scale: accessibilityTextSizeScale).weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color.shoppingModeText)
                        .padding(.horizontal, categoryProgressPaddingHorizontal)
                        .padding(.vertical, categoryProgressPaddingVertical)
                        .background(Color.shoppingModeControlBackground)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, categoryPadding)
                .padding(.vertical, 14)
                .background(Color.shoppingModeSurface)
                
                ScrollView {
                    LazyVStack(spacing: categoryRowSpacing) {
                        ForEach(viewModel.activeItems) { item in
                            ShoppingModeItemRow(item: item) {
                                viewModel.toggleItem(item, context: modelContext)
                            } onMarkSkipped: {
                                viewModel.markItem(item, as: .skipped, context: modelContext)
                            } onMarkUnavailable: {
                                viewModel.markItem(item, as: .unavailable, context: modelContext)
                            }
                        }
                    }
                    .padding(categoryPadding)
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
                    .font(.system(size: arrowIconSize, weight: .bold))
                    .foregroundStyle(Color.shoppingModeText)
                    .frame(width: arrowButtonSize, height: arrowButtonSize)
                    .background(Color.shoppingModeControlBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.activeCategoryIndex == 0)
            .opacity(viewModel.activeCategoryIndex == 0 ? 0.45 : 1.0)
            .accessibilityLabel("Categoría anterior")
            
            Spacer()
            
            if viewModel.categories.count > 0 {
                VStack(spacing: 4) {
                    Text("Categoría \(viewModel.activeCategoryIndex + 1) de \(viewModel.categories.count)")
                        .font(Theme.captionFont(scale: accessibilityTextSizeScale).weight(.bold))
                        .foregroundStyle(Color.shoppingModeSecondaryText)
                    
                    Button {
                        HapticFeedback.selection()
                        viewModel.nextCategory()
                    } label: {
                        Text("Saltar Categoría")
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale).weight(.bold))
                            .foregroundStyle(Theme.accentYellow)
                            .frame(minHeight: Theme.minimumTouchTarget)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.activeCategoryIndex == viewModel.categories.count - 1)
                    .opacity(viewModel.activeCategoryIndex == viewModel.categories.count - 1 ? 0.0 : 1.0)
                    .accessibilityLabel("Saltar categoría")
                }
            }
            
            Spacer()
            
            Button {
                HapticFeedback.selection()
                viewModel.nextCategory()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: arrowIconSize, weight: .bold))
                    .foregroundStyle(Color.shoppingModeText)
                    .frame(width: arrowButtonSize, height: arrowButtonSize)
                    .background(Color.shoppingModeControlBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.activeCategoryIndex == viewModel.categories.count - 1)
            .opacity(viewModel.activeCategoryIndex == viewModel.categories.count - 1 ? 0.45 : 1.0)
            .accessibilityLabel("Categoría siguiente")
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(Color.shoppingModeSurface)
    }
}
