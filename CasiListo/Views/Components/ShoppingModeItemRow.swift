import SwiftUI

/// Fila interactiva para un producto en Modo Compra.
struct ShoppingModeItemRow: View {
    let item: ShoppingItem
    let onToggle: () -> Void
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    var body: some View {
        HStack(spacing: 16) {
            Button {
                onToggle()
            } label: {
                HStack(spacing: 16) {
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
        }
        .padding(.vertical, 14 * CGFloat(accessibilityTextSizeScale))
        .padding(.horizontal, 18 * CGFloat(accessibilityTextSizeScale))
        .frame(minHeight: 64 * CGFloat(accessibilityTextSizeScale))
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
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)
            }
        }
        .frame(
            width: max(Theme.minimumTouchTarget, 42 * CGFloat(accessibilityTextSizeScale)),
            height: max(Theme.minimumTouchTarget, 42 * CGFloat(accessibilityTextSizeScale))
        )
    }

    private var itemText: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(item.name)
                    .font(.system(size: 18 * CGFloat(accessibilityTextSizeScale), weight: .medium))
                    .foregroundStyle(item.isPurchased ? Color.shoppingModeSecondaryText : Color.shoppingModeText)
                    .strikethrough(item.isPurchased, color: Color.shoppingModeSecondaryText)
                    .lineLimit(2)

                if !item.quantity.isEmpty {
                    Text(item.quantity)
                        .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(item.isPurchased ? Color.shoppingModeSecondaryText : Theme.accentYellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.shoppingModeControlBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            if !item.note.isEmpty {
                Text(item.note)
                    .font(Theme.captionFont(scale: accessibilityTextSizeScale))
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
