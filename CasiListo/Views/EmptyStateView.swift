import SwiftUI

struct EmptyStateView: View {
    let onAddTapped: () -> Void
    var hasHistory: Bool = false
    var onShowHistory: (() -> Void)? = nil
    var onQuickAdd: ((String) -> Void)? = nil
    var onShowTemplates: (() -> Void)? = nil

    @ScaledMetric(relativeTo: .body) private var logoSize: CGFloat = 80
    @ScaledMetric(relativeTo: .body) private var mainSpacing: CGFloat = 20

    private let quickStaples = ["Leche 🥛", "Pan 🍞", "Huevos 🥚", "Manzanas 🍎", "Café ☕️", "Mantequilla 🧈"]

    var body: some View {
        VStack(spacing: mainSpacing) {
            Spacer()

            LogoView(size: logoSize)
                .padding(.bottom, 4)

            Text("Tu lista está vacía")
                .font(Theme.bodyBoldDynamic)
                .foregroundStyle(Color.appTextPrimary)

            Text("Añade productos para tu próxima compra o selecciona uno de los básicos:")
                .font(Theme.captionDynamic)
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)

            // Chips de productos básicos rápidos
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickStaples, id: \.self) { staple in
                        Button {
                            HapticFeedback.impact()
                            let cleanName = staple.components(separatedBy: " ").first ?? staple
                            onQuickAdd?(cleanName)
                        } label: {
                            Text(staple)
                                .font(Theme.chipDynamic)
                                .foregroundStyle(Color.appTextPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.appCardBackground)
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(Theme.accentYellow.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(.vertical, 4)

            AdaptiveGlassEffectContainer(spacing: 12) {
                Button {
                    HapticFeedback.impact()
                    onAddTapped()
                } label: {
                    Label("Añadir producto", systemImage: "plus")
                        .font(Theme.bodyBoldDynamic)
                }
                .adaptiveGlassProminentButtonStyle()

                if let showTemplates = onShowTemplates {
                    Button {
                        HapticFeedback.selection()
                        showTemplates()
                    } label: {
                        Label("Usar plantilla", systemImage: "square.grid.2x2")
                            .font(Theme.bodyBoldDynamic)
                    }
                    .adaptiveGlassButtonStyle()
                    .accessibilityIdentifier("empty-state-templates")
                }

                if hasHistory, let showHistory = onShowHistory {
                    Button {
                        HapticFeedback.selection()
                        showHistory()
                    } label: {
                        Label("Ver última compra", systemImage: "clock.arrow.circlepath")
                            .font(Theme.bodyBoldDynamic)
                    }
                    .adaptiveGlassButtonStyle()
                }
            }
            .padding(.top, 4)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
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
