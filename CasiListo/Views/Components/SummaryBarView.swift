import SwiftUI

/// Resumen de progreso de la compra: recuentos, barra de avance y control
/// para mostrar u ocultar los productos comprados.
struct SummaryBarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            // En tamaños accesibles la fila compacta no debe resolver el
            // problema con elipsis. `ViewThatFits` apila el contador y el
            // control cuando ambos textos ya no caben lado a lado.
            ViewThatFits(in: .horizontal) {
                controlsRow
                VStack(alignment: .leading, spacing: 8) {
                    countsText
                    visibilityButton
                }
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
                .animation(Theme.defaultAnimation(reduceMotion: reduceMotion), value: progress)
                .accessibilityElement()
                .accessibilityLabel("Progreso de la compra")
                .accessibilityValue(
                    "\(purchasedCount) de "
                        + "\(SpanishPluralization.count(totalCount, singular: "producto comprado", plural: "productos comprados"))"
                )
            }

            if purchasedCount > 0, let archive = onArchivePurchased {
                Button {
                    HapticFeedback.selection()
                    archive()
                } label: {
                    Label(
                        "Archivar " + SpanishPluralization.count(purchasedCount, singular: "comprado", plural: "comprados"),
                        systemImage: "archivebox"
                    )
                    .font(Theme.captionDynamic.weight(.semibold))
                    .foregroundStyle(Theme.accentInteractive)
                    .frame(minHeight: Theme.minimumTouchTarget, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "Archivar "
                        + SpanishPluralization.count(purchasedCount, singular: "producto comprado", plural: "productos comprados")
                )
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// «363 pendientes» o «362 pendientes · 1 comprado» en una sola cadena, para
    /// que el recuento no compita por espacio consigo mismo.
    private var countsSummary: String {
        let pending = SpanishPluralization.count(pendingCount, singular: "pendiente", plural: "pendientes")
        guard purchasedCount > 0 else { return pending }
        let purchased = SpanishPluralization.count(purchasedCount, singular: "comprado", plural: "comprados")
        return "\(pending) · \(purchased)"
    }

    private var countsText: some View {
        Text(countsSummary)
            .font(Theme.captionDynamic.weight(.medium))
            .foregroundStyle(Color.appTextSecondary)
            .monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
    }

    private var visibilityButton: some View {
        Button {
            HapticFeedback.selection()
            withAnimation(Theme.defaultAnimation(reduceMotion: reduceMotion)) {
                showPurchased.toggle()
            }
        } label: {
            Label(
                showPurchased ? "Ocultar comprados" : "Ver comprados",
                systemImage: showPurchased ? "eye.slash" : "eye"
            )
            .font(Theme.captionDynamic.weight(.medium))
            .foregroundStyle(Color.appTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
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

    private var controlsRow: some View {
        HStack(spacing: scaledSpacing) {
            countsText
            Spacer(minLength: 8)
            visibilityButton
        }
    }
}
