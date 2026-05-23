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
                ZStack {
                    Circle()
                        .strokeBorder(item.isPurchased ? Theme.accentYellow : Color.appTextPurchased, lineWidth: 3)
                        
                    if item.isPurchased {
                        Circle()
                            .fill(Theme.accentYellow)
                            .transition(.scale.combined(with: .opacity))
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black)
                    }
                }
                .frame(width: 42 * CGFloat(accessibilityTextSizeScale), height: 42 * CGFloat(accessibilityTextSizeScale))
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.system(size: 18 * CGFloat(accessibilityTextSizeScale), weight: .medium))
                        .foregroundStyle(item.isPurchased ? Color.appTextPurchased : Color.appTextPrimary)
                        .strikethrough(item.isPurchased, color: Color.appTextPurchased)
                        .lineLimit(2)
                    
                    if !item.quantity.isEmpty {
                        Text(item.quantity)
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                            .foregroundStyle(item.isPurchased ? Color.appTextPurchased : Theme.accentYellow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                
                if !item.note.isEmpty {
                    Text(item.note)
                        .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            if let voiceNote = item.voiceNoteFilename {
                VoiceNotePlayerButton(filename: voiceNote)
            }
        }
        .padding(.vertical, 14 * CGFloat(accessibilityTextSizeScale))
        .padding(.horizontal, 18 * CGFloat(accessibilityTextSizeScale))
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        .opacity(item.isPurchased ? 0.6 : 1.0)
    }
}
