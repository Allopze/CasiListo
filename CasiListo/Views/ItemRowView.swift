import SwiftUI

/// Fila individual para un ítem de compra.
/// Muestra estado, contenido y acciones nativas de edición.
struct ItemRowView: View {
    let item: ShoppingItem
    var searchText: String = ""
    var showsStore: Bool = true
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onMarkStatus: (ShoppingItemStatus) -> Void

    @ScaledMetric(relativeTo: .body) private var checkboxSize: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var scaledEditButtonSize: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var scaledPaddingVertical: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var scaledSpacing: CGFloat = 14
    @ScaledMetric(relativeTo: .caption) private var storeTextSize: CGFloat = 9
    @ScaledMetric(relativeTo: .caption) private var storePaddingHorizontal: CGFloat = 6
    @ScaledMetric(relativeTo: .caption) private var storePaddingVertical: CGFloat = 2
    @ScaledMetric(relativeTo: .caption) private var pillPaddingHorizontal: CGFloat = 8
    @ScaledMetric(relativeTo: .caption) private var pillPaddingVertical: CGFloat = 3
    @ScaledMetric(relativeTo: .body) private var checkmarkSize: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var editButtonSymbolSize: CGFloat = 13

    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: scaledSpacing) {
            Button {
                toggleItem()
            } label: {
                checkboxView
                    .frame(width: Theme.minimumTouchTarget, height: Theme.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isPurchased ? "Marcar \(item.name) como pendiente" : "Marcar \(item.name) como comprado")
            .accessibilityValue(item.isPurchased ? "Comprado" : "Pendiente")
            .accessibilityHint("Cambia el estado del producto")
            .accessibilityIdentifier("item-toggle-\(item.id.uuidString)")

            rowContent
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityLabel)

            Spacer(minLength: 0)

            if let voiceNote = item.voiceNoteFilename {
                VoiceNotePlayerButton(filename: voiceNote)
            }

            // Lado derecho independiente que al tocar permite editar el producto.
            editButton
        }
        .padding(.vertical, scaledPaddingVertical)
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

            Button {
                markStatus(.skipped)
            } label: {
                Label("Posponer", systemImage: "clock")
            }

            Button {
                markStatus(.unavailable)
            } label: {
                Label("No encontrado", systemImage: "exclamationmark.triangle")
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
        .accessibilityAction(named: "Editar") {
            HapticFeedback.selection()
            onEdit()
        }
        .accessibilityAction(named: "Posponer") {
            markStatus(.skipped)
        }
        .accessibilityAction(named: "Marcar no encontrado") {
            markStatus(.unavailable)
        }
        .accessibilityAction(named: "Eliminar") {
            HapticFeedback.impact()
            withAnimation(Theme.defaultAnimation) {
                onDelete()
            }
        }
        .animation(reduceMotion ? nil : Theme.quickAnimation, value: item.isPurchased)
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(highlighting: item.name, query: searchText)
                .font(Theme.bodyFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(item.isPurchased ? Color.appTextPurchased : Color.appTextPrimary)
                .strikethrough(item.isPurchased, color: Color.appTextPurchased)
                .lineLimit(2)

            metaChips

            if !item.note.isEmpty {
                Text(item.note)
                    .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var metaChips: some View {
        if showsStore || !item.quantity.isEmpty || item.status == .skipped || item.status == .unavailable {
            HStack(spacing: 5) {
                if showsStore {
                    Text(item.store.displayName)
                    .font(.system(size: storeTextSize, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, storePaddingHorizontal)
                    .padding(.vertical, storePaddingVertical)
                    .background(item.store.color.opacity(item.isPurchased ? 0.35 : 0.68))
                    .clipShape(Capsule())
                    .accessibilityLabel("Tienda: \(item.store.displayName)")
                }

                if !item.quantity.isEmpty {
                    Text(item.quantity)
                    .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(item.isPurchased ? Color.appTextPurchased : Color.appTextSecondary)
                    .padding(.horizontal, pillPaddingHorizontal)
                    .padding(.vertical, pillPaddingVertical)
                    .background(quantityBackground)
                    .clipShape(Capsule())
                    .accessibilityLabel("Cantidad \(item.quantity)")
            }

                if item.status == .skipped || item.status == .unavailable {
                    Label(item.status.rawValue, systemImage: item.status == .skipped ? "clock" : "exclamationmark.triangle")
                    .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(item.status == .skipped ? Color.orange : Color.red)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, pillPaddingHorizontal)
                    .padding(.vertical, pillPaddingVertical)
                    .background((item.status == .skipped ? Color.orange : Color.red).opacity(0.10))
                        .clipShape(Capsule())
                }
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
                    .font(.system(size: checkmarkSize, weight: .bold))
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
                .font(.system(size: editButtonSymbolSize, weight: .semibold))
                .foregroundStyle(Color.appTextSecondary)
                .frame(width: max(Theme.minimumTouchTarget, scaledEditButtonSize),
                       height: max(Theme.minimumTouchTarget, scaledEditButtonSize))
                .overlay {
                    Circle()
                        .stroke(Color.appSeparator.opacity(0.85), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Editar \(item.name)")
    }

    private var quantityBackground: some ShapeStyle {
        item.isPurchased
            ? Color.appTextPurchased.opacity(0.1)
            : Color.appTextSecondary.opacity(0.1)
    }

    private var accessibilityLabel: String {
        var parts = [item.name, "en \(item.store.displayName)"]
        if !item.quantity.isEmpty {
            parts.append(item.quantity)
        }
        if item.status == .skipped || item.status == .unavailable {
            parts.append(item.status.rawValue)
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

    private func markStatus(_ status: ShoppingItemStatus) {
        HapticFeedback.selection()
        withAnimation(Theme.defaultAnimation) {
            onMarkStatus(status)
        }
    }
}

// MARK: - Text Highlighting Extension
private extension Text {
    init(highlighting text: String, query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = ProductNameNormalizer.normalize(query)
        guard !normalizedQuery.isEmpty, ProductNameNormalizer.contains(text, query: query) else {
            self.init(text)
            return
        }
        let queryForRange = text.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            ? trimmed
            : normalizedQuery
        guard let range = text.range(of: queryForRange, options: [.caseInsensitive, .diacriticInsensitive]) else {
            self.init(text)
            return
        }
        var attributed = AttributedString(text)
        if let attrRange = attributed.range(of: String(text[range]), options: [.caseInsensitive, .diacriticInsensitive]) {
            attributed[attrRange].backgroundColor = Theme.accentYellow.opacity(0.35)
            attributed[attrRange].inlinePresentationIntent = .stronglyEmphasized
        }
        self.init(attributed)
    }
}
