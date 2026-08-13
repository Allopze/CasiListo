import SwiftUI

/// Barra que resume el recuento de productos y precios acumulados, y permite mostrar/ocultar comprados.
struct SummaryBarView: View {
    let pendingCount: Int
    let purchasedCount: Int
    @Binding var showPurchased: Bool
    var onArchivePurchased: (() -> Void)? = nil

    @ScaledMetric(relativeTo: .caption) private var scaledSpacing: CGFloat = 10
    @ScaledMetric(relativeTo: .body) private var eyeIconSize: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var eyeCornerRadius: CGFloat = Theme.chipCornerRadius
    @ScaledMetric(relativeTo: .body) private var verticalPadding: CGFloat = 4

    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    var body: some View {
        let pendingLabel = "\(pendingCount) pendientes"
        let purchasedLabel = "\(purchasedCount) comprados"

        return HStack(spacing: scaledSpacing) {
            Label(pendingLabel, systemImage: "checklist.unchecked")
                .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.appTextSecondary)

            if purchasedCount > 0 {
                if let archive = onArchivePurchased {
                    Button {
                        HapticFeedback.selection()
                        archive()
                    } label: {
                        Label("Archivar \(purchasedCount)", systemImage: "archivebox")
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale).weight(.semibold))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Archivar \(purchasedCount) productos comprados")
                } else {
                    Label(purchasedLabel, systemImage: "checkmark.circle.fill")
                        .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(Color.appTextSecondary)
                }
            }

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
                .font(.system(size: eyeIconSize, weight: .semibold))
                .padding(.horizontal, 10)
                .frame(minHeight: Theme.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .glassFilterSurface(cornerRadius: eyeCornerRadius, interactive: true)
            .accessibilityLabel(showPurchased ? "Ocultar comprados" : "Mostrar comprados")
        }
        .padding(.vertical, verticalPadding)
        .accessibilityElement(children: .contain)
    }
}
