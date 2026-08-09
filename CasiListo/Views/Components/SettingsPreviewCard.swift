import SwiftUI

struct SettingsPreviewCard: View {
    @Binding var mockItemPurchased: Bool
    let accessibilityTextSizeScale: Double

    @ScaledMetric(relativeTo: .body) private var hstackSpacing: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var checkboxSize: CGFloat = 26
    @ScaledMetric(relativeTo: .body) private var checkboxOuter: CGFloat = 28
    @ScaledMetric(relativeTo: .caption) private var checkmarkSize: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var innerVStackSpacing: CGFloat = 12
    @ScaledMetric(relativeTo: .caption) private var textSpacing: CGFloat = 2
    @ScaledMetric(relativeTo: .caption) private var waveformSize: CGFloat = 13
    @ScaledMetric(relativeTo: .body) private var waveformFrame: CGFloat = 32
    @ScaledMetric(relativeTo: .body) private var verticalPadding: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("VISTA PREVIA EN VIVO")
                .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.appTextSecondary)
                .padding(.leading, 6)
                .bold()
            
            VStack(alignment: .leading, spacing: innerVStackSpacing) {
                HStack(spacing: hstackSpacing) {
                    // Checkbox
                    Button {
                        HapticFeedback.selection()
                        withAnimation(Theme.quickAnimation) {
                            mockItemPurchased.toggle()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(mockItemPurchased ? Theme.accentYellow : Color.appTextSecondary, lineWidth: 2)
                                .frame(
                                    width: checkboxSize,
                                    height: checkboxSize
                                )
                            
                            if mockItemPurchased {
                                Image(systemName: "checkmark")
                                    .font(.system(size: checkmarkSize, weight: .bold))
                                    .foregroundStyle(Theme.accentYellow)
                            }
                        }
                        .frame(
                            width: checkboxOuter,
                            height: checkboxOuter
                        )
                    }
                    .buttonStyle(.plain)
                    
                    VStack(alignment: .leading, spacing: textSpacing) {
                        Text("Producto de Ejemplo")
                            .font(Theme.bodyFont(scale: accessibilityTextSizeScale))
                            .foregroundStyle(mockItemPurchased ? Color.appTextPurchased : Color.appTextPrimary)
                            .strikethrough(mockItemPurchased, color: Color.appTextPurchased)
                        
                        Text("Nota de ejemplo o cantidad")
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    
                    Spacer()
                    
                    // Waveform
                    Image(systemName: "waveform")
                        .font(.system(size: waveformSize, weight: .semibold))
                        .foregroundStyle(Theme.accentYellow.opacity(mockItemPurchased ? 0.35 : 0.68))
                        .frame(
                            width: max(Theme.minimumTouchTarget, waveformFrame),
                            height: max(Theme.minimumTouchTarget, waveformFrame)
                        )
                        .background(Theme.accentYellow.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale))
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius(scale: accessibilityTextSizeScale), style: .continuous))
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        }
        .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale))
        .padding(.top, 10)
    }
}
