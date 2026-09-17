import SwiftUI

struct EmptyStateView: View {
    let onAddTapped: () -> Void
    var hasHistory: Bool = false
    var onShowHistory: (() -> Void)?
    var onQuickAdd: ((String) -> Void)?
    var onShowTemplates: (() -> Void)?

    @ScaledMetric(relativeTo: .body) private var logoSize: CGFloat = 80
    @ScaledMetric(relativeTo: .body) private var mainSpacing: CGFloat = 20

    private let quickStaples = ["Leche 🥛", "Pan 🍞", "Huevos 🥚", "Manzanas 🍎", "Café ☕️", "Mantequilla 🧈"]

    var body: some View {
        // En Accessibility XXL el contenido mide ~1.300 pt contra una ventana de
        // 874 pt: sin scroll, «Usar plantilla» y «Ver última compra» quedaban
        // fuera de pantalla y no había forma de alcanzarlos (CASI-108). El
        // `minHeight` conserva el centrado con los tamaños en que sí cabe.
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var content: some View {
        VStack(spacing: mainSpacing) {
            Spacer()

            LogoView(size: logoSize)
                .padding(.bottom, 4)

            Text("Tu lista está vacía")
                .font(Theme.bodyBoldDynamic)
                .foregroundStyle(Color.appTextPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Añade productos para tu próxima compra o selecciona uno de los básicos:")
                .font(Theme.captionDynamic)
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

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

            ViewThatFits(in: .horizontal) {
                actionButtons(axis: .horizontal)
                actionButtons(axis: .vertical)
            }
            .padding(.top, 4)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private enum ActionAxis { case horizontal, vertical }

    @ViewBuilder
    private func actionButtons(axis: ActionAxis) -> some View {
        GlassEffectContainer(spacing: 12) {
            if axis == .horizontal {
                HStack(spacing: 12) { actionButtonViews }
            } else {
                VStack(spacing: 12) { actionButtonViews }
            }
        }
    }

    @ViewBuilder
    private var actionButtonViews: some View {
        Button {
            HapticFeedback.impact()
            onAddTapped()
        } label: {
            Label("Añadir producto", systemImage: "plus")
                .font(Theme.bodyBoldDynamic)
        }
        .buttonStyle(.glassProminent)

        if let showTemplates = onShowTemplates {
            Button {
                HapticFeedback.selection()
                showTemplates()
            } label: {
                Label("Usar plantilla", systemImage: "square.grid.2x2")
                    .font(Theme.bodyBoldDynamic)
            }
            .buttonStyle(.glass)
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
            .buttonStyle(.glass)
        }
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
