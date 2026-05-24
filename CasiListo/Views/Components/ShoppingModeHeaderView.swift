import SwiftUI

/// Cabecera informativa para la pantalla de compra activa en supermercado.
struct ShoppingModeHeaderView: View {
    @Bindable var viewModel: ShoppingModeViewModel
    let onBack: () -> Void
    let onExit: () -> Void

    @ScaledMetric(relativeTo: .body) private var scaledVStackSpacing: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var chevronSize: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var backPaddingHorizontal: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var backPaddingVertical: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var backMinHeight: CGFloat = Theme.minimumTouchTarget
    @ScaledMetric(relativeTo: .body) private var storeIconSize: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var storePaddingHorizontal: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var storePaddingVertical: CGFloat = 6
    @ScaledMetric(relativeTo: .body) private var xmarkSize: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var xmarkButtonSize: CGFloat = Theme.minimumTouchTarget
    @ScaledMetric(relativeTo: .body) private var textSpacing: CGFloat = 6
    @ScaledMetric(relativeTo: .body) private var progressBarHeight: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var containerPaddingHorizontal: CGFloat = 20
    @ScaledMetric(relativeTo: .body) private var containerPaddingVertical: CGFloat = 16

    var body: some View {
        VStack(spacing: scaledVStackSpacing) {
            HStack {
                Button {
                    HapticFeedback.selection()
                    viewModel.stopSession()
                    onBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: chevronSize, weight: .bold))
                        Text("Atrás")
                            .font(Theme.captionDynamic)
                            .bold()
                    }
                    .foregroundStyle(Color.shoppingModeText)
                    .padding(.horizontal, backPaddingHorizontal)
                    .padding(.vertical, backPaddingVertical)
                    .frame(minHeight: backMinHeight)
                    .background(Color.shoppingModeControlBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Volver a seleccionar supermercado")
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: viewModel.store.sfSymbol)
                        .font(.system(size: storeIconSize, weight: .bold))
                    Text(viewModel.store.displayName)
                        .font(.system(size: storeIconSize, weight: .bold))
                }
                .padding(.horizontal, storePaddingHorizontal)
                .padding(.vertical, storePaddingVertical)
                .foregroundStyle(.white)
                .background(viewModel.store.color)
                .clipShape(Capsule())
                
                Spacer()
                
                Button {
                    HapticFeedback.selection()
                    viewModel.stopSession()
                    onExit()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: xmarkSize, weight: .bold))
                        .foregroundStyle(Color.shoppingModeText)
                        .frame(width: xmarkButtonSize, height: xmarkButtonSize)
                        .background(Color.shoppingModeControlBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Salir del modo compra")
            }
            
            VStack(spacing: textSpacing) {
                HStack {
                    Text("\(viewModel.purchasedCount) de \(viewModel.totalCount) comprados")
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Color.shoppingModeSecondaryText)
                    Spacer()
                    Text("\(Int(viewModel.progress * 100))%")
                        .font(Theme.captionDynamic)
                        .bold()
                        .foregroundStyle(Theme.accentYellow)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.shoppingModeControlBackground)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(viewModel.store.color)
                            .frame(width: max(0, geo.size.width * viewModel.progress))
                    }
                }
                .frame(height: progressBarHeight)
            }
        }
        .padding(.horizontal, containerPaddingHorizontal)
        .padding(.top, containerPaddingVertical)
        .padding(.bottom, containerPaddingVertical)
        .background(Color.shoppingModeSurface)
    }
}
