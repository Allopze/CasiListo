import SwiftUI

/// Resumen de progreso de la compra: recuentos, barra de avance y control
/// para mostrar u ocultar los productos comprados.
struct SummaryBarView: View {
    let pendingCount: Int
    let purchasedCount: Int
    @Binding var showPurchased: Bool
    var onArchivePurchased: (() -> Void)? = nil

    @ScaledMetric(relativeTo: .caption) private var scaledSpacing: CGFloat = 10
    @ScaledMetric(relativeTo: .caption) private var progressHeight: CGFloat = 5

    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    private var totalCount: Int { pendingCount + purchasedCount }

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(purchasedCount) / Double(totalCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: scaledSpacing) {
                Text(pendingCount == 1 ? "1 pendiente" : "\(pendingCount) pendientes")
                    .font(Theme.captionFont(scale: accessibilityTextSizeScale).weight(.medium))
                    .foregroundStyle(Color.appTextSecondary)
                    .monospacedDigit()

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
                        Text(purchasedCount == 1 ? "1 comprado" : "\(purchasedCount) comprados")
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                            .foregroundStyle(Color.appTextSecondary)
                            .monospacedDigit()
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
                    .font(Theme.captionFont(scale: accessibilityTextSizeScale).weight(.medium))
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

            if totalCount > 0 {
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
        }
        .accessibilityElement(children: .contain)
    }
}
