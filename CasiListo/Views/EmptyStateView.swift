import SwiftUI

/// Pantalla vacía mostrada cuando no hay productos en la lista.
struct EmptyStateView: View {
    let onAddTapped: () -> Void
    var hasHistory: Bool = false
    var onShowHistory: (() -> Void)? = nil

    @Environment(AppSettings.self) private var appSettings
    private var accessibilityTextSizeScale: Double {
        appSettings.accessibilityTextSizeScale
    }

    var body: some View {
        VStack(spacing: 20 * CGFloat(accessibilityTextSizeScale)) {
            Spacer()

            LogoView(size: 80 * CGFloat(accessibilityTextSizeScale))
                .padding(.bottom, 8)

            Text("Tu lista está vacía")
                .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.appTextPrimary)

            Text("Añade productos para tu próxima compra")
                .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)

            AdaptiveGlassEffectContainer(spacing: 12) {
                Button {
                    HapticFeedback.impact()
                    onAddTapped()
                } label: {
                    Label("Añadir producto", systemImage: "plus")
                        .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                }
                .adaptiveGlassProminentButtonStyle()

                if hasHistory, let showHistory = onShowHistory {
                    Button {
                        HapticFeedback.selection()
                        showHistory()
                    } label: {
                        Label("Ver última compra", systemImage: "clock.arrow.circlepath")
                            .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                    }
                    .adaptiveGlassButtonStyle()
                }
            }
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

/// Vista del logo de CasiListo con carga desde Asset Catalog y fallback seguro.
struct LogoView: View {
    var size: CGFloat = 80

    var body: some View {
        if let uiImage = UIImage(named: "AppLogo") ?? UIImage(named: "logo") {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.36, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        } else {
            Image(systemName: "cart")
                .font(.system(size: size - 16, weight: .light))
                .foregroundStyle(Color.appTextPurchased)
        }
    }
}
