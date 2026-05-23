import SwiftUI

/// Cabecera informativa para la pantalla de compra activa en supermercado.
struct ShoppingModeHeaderView: View {
    @Bindable var viewModel: ShoppingModeViewModel
    let onBack: () -> Void
    let onExit: () -> Void
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    var body: some View {
        VStack(spacing: 12 * CGFloat(accessibilityTextSizeScale)) {
            HStack {
                Button {
                    HapticFeedback.selection()
                    viewModel.stopSession()
                    onBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                        Text("Atrás")
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                            .bold()
                    }
                    .foregroundStyle(Color.shoppingModeText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: Theme.minimumTouchTarget)
                    .background(Color.shoppingModeControlBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Volver a seleccionar supermercado")
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: viewModel.store.sfSymbol)
                        .font(.system(size: 14, weight: .bold))
                    Text(viewModel.store.displayName)
                        .font(.system(size: 14, weight: .bold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
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
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.shoppingModeText)
                        .frame(width: Theme.minimumTouchTarget, height: Theme.minimumTouchTarget)
                        .background(Color.shoppingModeControlBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Salir del modo compra")
            }
            
            VStack(spacing: 6) {
                HStack {
                    Text("\(viewModel.purchasedCount) de \(viewModel.totalCount) comprados")
                        .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(Color.shoppingModeSecondaryText)
                    Spacer()
                    Text("\(Int(viewModel.progress * 100))%")
                        .font(Theme.captionFont(scale: accessibilityTextSizeScale))
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
                .frame(height: 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .background(Color.shoppingModeSurface)
    }
}
