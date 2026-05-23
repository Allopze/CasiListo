import SwiftUI

/// Barra que resume el recuento de productos y precios acumulados, y permite mostrar/ocultar comprados.
struct SummaryBarView: View {
    let pendingCount: Int
    let purchasedCount: Int
    let pendingTotal: Double
    let purchasedTotal: Double
    @Binding var showPurchased: Bool
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    var body: some View {
        let pendingTotalStr = pendingTotal.formattedPrice
        let purchasedTotalStr = purchasedTotal.formattedPrice

        let pendingLabel = pendingTotal > 0 ? "\(pendingCount) pendientes ($\(pendingTotalStr))" : "\(pendingCount) pendientes"
        let purchasedLabel = purchasedTotal > 0 ? "\(purchasedCount) comprados ($\(purchasedTotalStr))" : "\(purchasedCount) comprados"

        return AdaptiveGlassEffectContainer(spacing: 12) {
            HStack(spacing: 14 * CGFloat(accessibilityTextSizeScale)) {
                Label(pendingLabel, systemImage: "circle")
                    .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(Color.appTextSecondary)

                if purchasedCount > 0 {
                    Label(purchasedLabel, systemImage: "checkmark.circle.fill")
                        .font(Theme.captionFont(scale: accessibilityTextSizeScale))
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
                    .font(.system(size: 15 * CGFloat(accessibilityTextSizeScale), weight: .semibold))
                    .frame(width: 36 * CGFloat(accessibilityTextSizeScale), height: 32 * CGFloat(accessibilityTextSizeScale))
                }
                .buttonStyle(.plain)
                .glassFilterSurface(cornerRadius: 16 * CGFloat(accessibilityTextSizeScale), interactive: true)
                .accessibilityLabel(showPurchased ? "Ocultar comprados" : "Mostrar comprados")
            }
            .padding(.leading, 16 * CGFloat(accessibilityTextSizeScale))
            .padding(.trailing, 8 * CGFloat(accessibilityTextSizeScale))
            .padding(.vertical, 8 * CGFloat(accessibilityTextSizeScale))
            .glassFilterSurface(cornerRadius: Theme.cornerRadius(scale: accessibilityTextSizeScale))
        }
        .accessibilityElement(children: .contain)
    }
}
