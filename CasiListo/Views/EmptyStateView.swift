import SwiftUI

struct EmptyStateView: View {
    let onAddTapped: () -> Void
    var hasHistory: Bool = false
    var onShowHistory: (() -> Void)?
    var onQuickAdd: ((String) -> Void)?
    var onShowTemplates: (() -> Void)?

    @ScaledMetric(relativeTo: .body) private var logoSize: CGFloat = 88
    @ScaledMetric(relativeTo: .body) private var mainSpacing: CGFloat = 20

    /// Básicos de un toque. Sin emoji: el resto de la app habla en SF Symbols
    /// y los emoji mezclaban dos lenguajes de íconos en la misma pantalla.
    private let quickStaples = ["Leche", "Pan", "Huevos", "Manzanas", "Café", "Mantequilla"]

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

            VStack(spacing: 8) {
                Text("Tu lista está vacía")
                    .font(Theme.sectionHeaderDynamic)
                    .foregroundStyle(Color.appTextPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Añade lo que te falta o parte con un básico:")
                    .font(Theme.bodyDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(quickStaples, id: \.self) { staple in
                    Button {
                        HapticFeedback.impact()
                        onQuickAdd?(staple)
                    } label: {
                        Label(staple, systemImage: "plus")
                            .font(Theme.chipDynamic.weight(.semibold))
                            .foregroundStyle(Color.appTextPrimary)
                            .padding(.horizontal, 14)
                            .frame(minHeight: Theme.minimumTouchTarget)
                            .background(Color.appCardBackground, in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.appSeparator, lineWidth: 1))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Añadir \(staple)")
                }
            }

            ViewThatFits(in: .horizontal) {
                actionButtons(axis: .horizontal)
                actionButtons(axis: .vertical)
            }
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private enum ActionAxis { case horizontal, vertical }

    @ViewBuilder
    private func actionButtons(axis: ActionAxis) -> some View {
        if axis == .horizontal {
            HStack(spacing: 12) { actionButtonViews }
        } else {
            VStack(spacing: 12) { actionButtonViews }
        }
    }

    /// Un solo componente primario en ambos modos: antes `.glassProminent`
    /// pintaba oro con texto blanco en claro y amarillo con texto blanco en
    /// oscuro (1,6:1). La regla de marca es `.accentProminent`.
    @ViewBuilder
    private var actionButtonViews: some View {
        Button {
            HapticFeedback.impact()
            onAddTapped()
        } label: {
            Label("Añadir producto", systemImage: "plus")
        }
        .buttonStyle(.accentProminent)

        if let showTemplates = onShowTemplates {
            Button {
                HapticFeedback.selection()
                showTemplates()
            } label: {
                Label("Usar plantilla", systemImage: "square.grid.2x2")
            }
            .buttonStyle(.accentBordered)
            .accessibilityIdentifier("empty-state-templates")
        }

        if hasHistory, let showHistory = onShowHistory {
            Button {
                HapticFeedback.selection()
                showHistory()
            } label: {
                Label("Ver última compra", systemImage: "clock.arrow.circlepath")
            }
            .buttonStyle(.accentBordered)
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
