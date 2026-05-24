import SwiftUI

/// Fila interactiva para un producto en Modo Compra.
struct ShoppingModeItemRow: View {
    let item: ShoppingItem
    let onToggle: () -> Void
    let onMarkSkipped: () -> Void
    let onMarkUnavailable: () -> Void
    
    @ScaledMetric(relativeTo: .body) private var checkboxSize: CGFloat = 42
    @ScaledMetric(relativeTo: .body) private var scaledSpacing: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var paddingVertical: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var paddingHorizontal: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 64
    @ScaledMetric(relativeTo: .body) private var checkmarkSize: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var ellipsisSize: CGFloat = 15
    @ScaledMetric(relativeTo: .caption) private var quantityPaddingHorizontal: CGFloat = 8
    @ScaledMetric(relativeTo: .caption) private var quantityPaddingVertical: CGFloat = 3
    @ScaledMetric(relativeTo: .caption) private var quantityCornerRadius: CGFloat = 6

    var body: some View {
        HStack(spacing: scaledSpacing) {
            Button {
                onToggle()
            } label: {
                HStack(spacing: scaledSpacing) {
                    checkboxView
                    itemText
                    Spacer(minLength: 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(item.isPurchased ? "Comprado" : "Pendiente")
            .accessibilityHint("Toca para marcar o desmarcar el producto")
            
            if let voiceNote = item.voiceNoteFilename {
                VoiceNotePlayerButton(filename: voiceNote)
            }

            Menu {
                Button {
                    onMarkSkipped()
                } label: {
                    Label("Posponer", systemImage: "clock")
                }

                Button {
                    onMarkUnavailable()
                } label: {
                    Label("No encontrado", systemImage: "exclamationmark.triangle")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: ellipsisSize, weight: .bold))
                    .foregroundStyle(Color.shoppingModeText)
                    .frame(width: Theme.minimumTouchTarget, height: Theme.minimumTouchTarget)
                    .background(Color.shoppingModeControlBackground)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Mas acciones para \(item.name)")
        }
        .padding(.vertical, paddingVertical)
        .padding(.horizontal, paddingHorizontal)
        .frame(minHeight: minHeight)
        .background(Color.shoppingModeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 4, y: 2)
        .opacity(item.isPurchased ? 0.68 : 1.0)
        .accessibilityAction(named: item.isPurchased ? "Marcar pendiente" : "Marcar comprado") {
            onToggle()
        }
    }

    private var checkboxView: some View {
        ZStack {
            Circle()
                .strokeBorder(item.isPurchased ? Theme.accentYellow : Color.shoppingModeSecondaryText, lineWidth: 3)

            if item.isPurchased {
                Circle()
                    .fill(Theme.accentYellow)
                    .transition(.scale.combined(with: .opacity))

                Image(systemName: "checkmark")
                    .font(.system(size: checkmarkSize, weight: .bold))
                    .foregroundStyle(.black)
            }
        }
        .frame(width: max(Theme.minimumTouchTarget, checkboxSize), height: max(Theme.minimumTouchTarget, checkboxSize))
    }

    private var itemText: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(item.name)
                    .font(Theme.bodyDynamic.weight(.medium))
                    .foregroundStyle(item.isPurchased ? Color.shoppingModeSecondaryText : Color.shoppingModeText)
                    .strikethrough(item.isPurchased, color: Color.shoppingModeSecondaryText)
                    .lineLimit(2)

                if !item.quantity.isEmpty {
                    Text(item.quantity)
                        .font(Theme.captionDynamic)
                        .foregroundStyle(item.isPurchased ? Color.shoppingModeSecondaryText : Theme.accentYellow)
                        .padding(.horizontal, quantityPaddingHorizontal)
                        .padding(.vertical, quantityPaddingVertical)
                        .background(Color.shoppingModeControlBackground)
                        .clipShape(RoundedRectangle(cornerRadius: quantityCornerRadius))
                }
            }

            if !item.note.isEmpty {
                Text(item.note)
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.shoppingModeSecondaryText)
                    .lineLimit(2)
            }
        }
    }

    private var accessibilityLabel: String {
        var parts = [item.name]
        if !item.quantity.isEmpty {
            parts.append(item.quantity)
        }
        if !item.note.isEmpty {
            parts.append(item.note)
        }
        return parts.joined(separator: ", ")
    }
}
