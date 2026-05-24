import SwiftUI

/// Barra que resume el recuento de productos y precios acumulados, y permite mostrar/ocultar comprados.
struct SummaryBarView: View {
    let pendingCount: Int
    let purchasedCount: Int
    let pendingTotal: Double
    let purchasedTotal: Double
    @Binding var showPurchased: Bool

    @ScaledMetric(relativeTo: .caption) private var scaledSpacing: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var eyeIconSize: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var eyeButtonSize: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var eyeCornerRadius: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var leadingPadding: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var trailingPadding: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var verticalPadding: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat = Theme.cornerRadius

    var body: some View {
        let pendingLabel = pendingTotal > 0 ? "\(pendingCount) pendientes (\(pendingTotal.formattedPriceWithSymbol))" : "\(pendingCount) pendientes"
        let purchasedLabel = purchasedTotal > 0 ? "\(purchasedCount) comprados (\(purchasedTotal.formattedPriceWithSymbol))" : "\(purchasedCount) comprados"

        return AdaptiveGlassEffectContainer(spacing: 12) {
            HStack(spacing: scaledSpacing) {
                Label(pendingLabel, systemImage: "circle")
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)

                if purchasedCount > 0 {
                    Label(purchasedLabel, systemImage: "checkmark.circle.fill")
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Theme.accentYellow)
                }

                Spacer(minLength: 12)

                Button {
                    HapticFeedback.selection()
                    withAnimation(Theme.defaultAnimation) {
                        showPurchased.toggle()
                    }
                } label: {
                    Label(
                        showPurchased ? "Ocultar" : "Mostrar",
                        systemImage: showPurchased ? "eye.slash" : "eye"
                    )
                    .labelStyle(.iconOnly)
                    .font(.system(size: eyeIconSize, weight: .semibold))
                    .frame(width: eyeButtonSize, height: eyeButtonSize)
                }
                .buttonStyle(.plain)
                .glassFilterSurface(cornerRadius: eyeCornerRadius, interactive: true)
                .accessibilityLabel(showPurchased ? "Ocultar comprados" : "Mostrar comprados")
            }
            .padding(.leading, leadingPadding)
            .padding(.trailing, trailingPadding)
            .padding(.vertical, verticalPadding)
            .glassFilterSurface(cornerRadius: cornerRadius)
        }
        .accessibilityElement(children: .contain)
    }
}
