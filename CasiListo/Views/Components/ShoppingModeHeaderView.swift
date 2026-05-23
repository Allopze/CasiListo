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
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
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
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            VStack(spacing: 6) {
                HStack {
                    Text("\(viewModel.purchasedCount) de \(viewModel.totalCount) comprados")
                        .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(Color.appTextSecondary)
                    Spacer()
                    Text("\(Int(viewModel.progress * 100))%")
                        .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                        .bold()
                        .foregroundStyle(Theme.accentYellow)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.08))
                        
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
        .background(Color.appCardBackground)
    }
}
