import SwiftUI

/// Resumen de progreso de la compra: recuentos, barra de avance y control
/// para mostrar u ocultar los productos comprados.
struct SummaryBarView: View {
    let pendingCount: Int
    let purchasedCount: Int
    @Binding var showPurchased: Bool
    var onArchivePurchased: (() -> Void)?

    @ScaledMetric(relativeTo: .caption) private var scaledSpacing: CGFloat = 10
    @ScaledMetric(relativeTo: .caption) private var progressHeight: CGFloat = 5

    private var totalCount: Int { pendingCount + purchasedCount }

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(purchasedCount) / Double(totalCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Recuento y control de visibilidad. El botón de archivar vive en su
            // propia fila: los tres juntos no caben y se truncaban entre sí
            // («362 pendien…», «Archi…»).
            HStack(spacing: scaledSpacing) {
                Text(countsSummary)
                    .font(Theme.captionDynamic.weight(.medium))
                    .foregroundStyle(Color.appTextSecondary)
                    .monospacedDigit()
                    .lineLimit(1)

                Spacer(minLength: 8)

                Button {
                    HapticFeedback.selection()
                    withAnimation(Theme.defaultAnimation) {
                        showPurchased.toggle()
                    }
                } label: {
                    Label(
                        showPurchased ? "Ocultar comprados" : "Ver comprados",
                        systemImage: showPurchased ? "eye.slash" : "eye"
                    )
                    .font(Theme.captionDynamic.weight(.medium))
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background {
                        Capsule()
                            .fill(Color.appCardBackground)
                            .overlay {
                                Capsule()
                                    .strokeBorder(Color.appSeparator, lineWidth: 1)
                            }
                    }
                    .frame(minHeight: Theme.minimumTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .layoutPriority(1)
                .accessibilityLabel(showPurchased ? "Ocultar comprados" : "Mostrar comprados")
            }

            // Sin nada comprado la barra sería una franja gris sin significado.
            if purchasedCount > 0 {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.appSeparator)

                        if progress > 0 {
                            Capsule()
                                .fill(Theme.accentYellow)
                                .frame(width: max(progressHeight, proxy.size.width * progress))
                        }
                    }
                }
                .frame(height: progressHeight)
                .animation(Theme.defaultAnimation, value: progress)
                .accessibilityElement()
                .accessibilityLabel("Progreso de la compra")
                .accessibilityValue("\(purchasedCount) de \(totalCount) productos comprados")
            }

            if purchasedCount > 0, let archive = onArchivePurchased {
                Button {
                    HapticFeedback.selection()
                    archive()
                } label: {
                    Label(
                        purchasedCount == 1 ? "Archivar 1 comprado" : "Archivar \(purchasedCount) comprados",
                        systemImage: "archivebox"
                    )
                    .font(Theme.captionDynamic.weight(.semibold))
                    .foregroundStyle(Theme.accentInteractive)
                    .lineLimit(1)
                    .frame(minHeight: Theme.minimumTouchTarget, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Archivar \(purchasedCount) productos comprados")
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// «363 pendientes» o «362 pendientes · 1 comprado» en una sola cadena, para
    /// que el recuento no compita por espacio consigo mismo.
    private var countsSummary: String {
        let pending = pendingCount == 1 ? "1 pendiente" : "\(pendingCount) pendientes"
        guard purchasedCount > 0 else { return pending }
        let purchased = purchasedCount == 1 ? "1 comprado" : "\(purchasedCount) comprados"
        return "\(pending) · \(purchased)"
    }
}
