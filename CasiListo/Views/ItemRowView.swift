import SwiftUI

/// Fila individual para un ítem de compra.
/// Muestra estado, contenido y acciones nativas de edición.
struct ItemRowView: View {
    let item: ShoppingItem
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    private var checkboxSize: CGFloat {
        28 * CGFloat(accessibilityTextSizeScale)
    }

    var body: some View {
        HStack(spacing: 14 * CGFloat(accessibilityTextSizeScale)) {
            // Toda la tarjeta (excepto el botón de edición) al tocarla completa o descompleta el ítem.
            Button {
                toggleItem()
            } label: {
                HStack(spacing: 14 * CGFloat(accessibilityTextSizeScale)) {
                    checkboxView
                    rowContent
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(item.isPurchased ? "Comprado" : "Pendiente")
            .accessibilityHint("Toca para marcar o desmarcar el producto")

            // Lado derecho independiente que al tocar permite editar el producto.
            editButton
        }
        .padding(.vertical, 10 * CGFloat(accessibilityTextSizeScale))
        .contextMenu {
            Button {
                HapticFeedback.selection()
                onEdit()
            } label: {
                Label("Editar", systemImage: "pencil")
            }

            Button {
                toggleItem()
            } label: {
                Label(
                    item.isPurchased ? "Marcar como pendiente" : "Marcar como comprado",
                    systemImage: item.isPurchased ? "circle" : "checkmark.circle"
                )
            }

            Divider()

            Button(role: .destructive) {
                HapticFeedback.impact()
                withAnimation(Theme.defaultAnimation) {
                    onDelete()
                }
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
        .accessibilityAction(named: item.isPurchased ? "Marcar pendiente" : "Marcar comprado") {
            toggleItem()
        }
        .accessibilityAction(named: "Eliminar") {
            HapticFeedback.impact()
            withAnimation(Theme.defaultAnimation) {
                onDelete()
            }
        }
        .opacity(item.isPurchased ? 0.72 : 1.0)
        .animation(Theme.quickAnimation, value: item.isPurchased)
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(item.name)
                    .font(Theme.bodyFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(item.isPurchased ? Color.appTextPurchased : Color.appTextPrimary)
                    .strikethrough(item.isPurchased, color: Color.appTextPurchased)
                    .lineLimit(2)

                if !item.quantity.isEmpty {
                    Text(item.quantity)
                        .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(item.isPurchased ? Color.appTextPurchased : Theme.accentYellow)
                        .padding(.horizontal, 8 * CGFloat(accessibilityTextSizeScale))
                        .padding(.vertical, 3 * CGFloat(accessibilityTextSizeScale))
                        .background(quantityBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6 * CGFloat(accessibilityTextSizeScale)))
                        .accessibilityLabel("Cantidad \(item.quantity)")
                }

                if let price = item.price {
                    Text(price.formattedPriceWithSymbol)
                        .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(item.isPurchased ? Color.appTextPurchased : .green)
                        .padding(.horizontal, 8 * CGFloat(accessibilityTextSizeScale))
                        .padding(.vertical, 3 * CGFloat(accessibilityTextSizeScale))
                        .background(item.isPurchased ? Color.appTextPurchased.opacity(0.1) : Color.green.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6 * CGFloat(accessibilityTextSizeScale)))
                        .accessibilityLabel("Precio \(price.formattedPrice)")
                }
            }

            if !item.note.isEmpty {
                Text(item.note)
                    .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(2)
            }
        }
    }

    private var checkboxView: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    item.isPurchased ? Theme.accentYellow : Color.appTextPurchased,
                    lineWidth: 2
                )

            if item.isPurchased {
                Circle()
                    .fill(Theme.accentYellow)
                    .transition(.scale.combined(with: .opacity))

                Image(systemName: "checkmark")
                    .font(.system(size: 12 * CGFloat(accessibilityTextSizeScale), weight: .bold))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: checkboxSize, height: checkboxSize)
    }

    private var editButton: some View {
        Button {
            HapticFeedback.selection()
            onEdit()
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 13 * CGFloat(accessibilityTextSizeScale), weight: .semibold))
                .foregroundStyle(Theme.accentYellow)
                .frame(
                    width: 32 * CGFloat(accessibilityTextSizeScale),
                    height: 32 * CGFloat(accessibilityTextSizeScale)
                )
                .background(Theme.accentYellow.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Editar \(item.name)")
    }

    private var quantityBackground: some ShapeStyle {
        item.isPurchased
            ? Color.appTextPurchased.opacity(0.1)
            : Theme.accentYellow.opacity(0.15)
    }

    private var accessibilityLabel: String {
        var parts = [item.name]
        if !item.quantity.isEmpty {
            parts.append(item.quantity)
        }
        if let price = item.price {
            parts.append("Precio \(price.formattedPriceWithSymbol)")
        }
        if !item.note.isEmpty {
            parts.append(item.note)
        }
        return parts.joined(separator: ", ")
    }

    private func toggleItem() {
        HapticFeedback.selection()
        withAnimation(Theme.defaultAnimation) {
            onToggle()
        }
    }
}
