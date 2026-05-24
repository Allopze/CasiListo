import SwiftUI

/// Barra que resume el recuento de productos y precios acumulados, y permite mostrar/ocultar comprados.
struct SummaryBarView: View {
    let pendingCount: Int
    let purchasedCount: Int
    @Binding var showPurchased: Bool
    var onArchivePurchased: (() -> Void)? = nil

    @ScaledMetric(relativeTo: .caption) private var scaledSpacing: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var eyeIconSize: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var eyeButtonSize: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var eyeCornerRadius: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var leadingPadding: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var trailingPadding: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var verticalPadding: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat = Theme.cornerRadius

    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    var body: some View {
        let pendingLabel = "\(pendingCount) pendientes"
        let purchasedLabel = "\(purchasedCount) comprados"

        return AdaptiveGlassEffectContainer(spacing: 12) {
            HStack(spacing: scaledSpacing) {
                Label(pendingLabel, systemImage: "circle")
                    .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(Color.appTextSecondary)

                if purchasedCount > 0 {
                    if let archive = onArchivePurchased {
                        Button {
                            HapticFeedback.selection()
                            archive()
                        } label: {
                            Label("\(purchasedCount) comprados", systemImage: "archivebox")
                                .font(Theme.captionFont(scale: accessibilityTextSizeScale).weight(.semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.accentYellow)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Archivar \(purchasedCount) productos comprados")
                    } else {
                        Label(purchasedLabel, systemImage: "checkmark.circle.fill")
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                            .foregroundStyle(Theme.accentYellow)
                    }
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
