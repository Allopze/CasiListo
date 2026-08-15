import SwiftUI

/// Fila individual para un ítem de compra.
/// El checkbox alterna el estado; tocar el resto de la fila abre la edición.
struct ItemRowView: View {
    let item: ShoppingItem
    var searchText: String = ""
    var showsStore: Bool = true
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onMarkStatus: (ShoppingItemStatus) -> Void

    @ScaledMetric(relativeTo: .body) private var checkboxSize: CGFloat = 26
    @ScaledMetric(relativeTo: .body) private var scaledPaddingVertical: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var scaledSpacing: CGFloat = 12
    @ScaledMetric(relativeTo: .caption) private var storeTextSize: CGFloat = 11
    @ScaledMetric(relativeTo: .caption) private var pillPaddingHorizontal: CGFloat = 8
    @ScaledMetric(relativeTo: .caption) private var pillPaddingVertical: CGFloat = 2.5
    @ScaledMetric(relativeTo: .body) private var checkmarkSize: CGFloat = 12

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

            Button {
                HapticFeedback.selection()
                onEdit()
            } label: {
                HStack(spacing: scaledSpacing) {
                    rowContent
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Toca para editar el producto")

            if let voiceNote = item.voiceNoteFilename {
                VoiceNotePlayerButton(filename: voiceNote)
            }
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
                .font(Theme.bodyDynamic)
                .foregroundStyle(item.isPurchased ? Color.appTextPurchased : Color.appTextPrimary)
                .strikethrough(item.isPurchased, color: Color.appTextPurchased)
                .lineLimit(2)

            metaChips

            if !item.note.isEmpty {
                Text(item.note)
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var metaChips: some View {
        if showsStore || !item.quantity.isEmpty || item.status == .skipped || item.status == .unavailable {
            HStack(spacing: 6) {
                if showsStore {
                    Text(item.store.displayName)
                        .font(.system(size: storeTextSize, weight: .medium))
                        .foregroundStyle(item.store.labelColor)
                        .padding(.horizontal, pillPaddingHorizontal)
                        .padding(.vertical, pillPaddingVertical)
                        .background(item.store.color.opacity(0.13))
                        .clipShape(Capsule())
                        .opacity(item.isPurchased ? 0.55 : 1)
                        .accessibilityLabel("Tienda: \(item.store.displayName)")
                }

                if !item.quantity.isEmpty {
                    Text(item.quantity)
                        .font(Theme.captionDynamic)
                        .foregroundStyle(item.isPurchased ? Color.appTextPurchased : Color.appTextSecondary)
                        .padding(.horizontal, pillPaddingHorizontal)
                        .padding(.vertical, pillPaddingVertical)
                        .background(Color.appTextSecondary.opacity(0.08))
                        .clipShape(Capsule())
                        .accessibilityLabel("Cantidad \(item.quantity)")
                }

                if item.status == .skipped || item.status == .unavailable {
                    Label(item.status.rawValue, systemImage: item.status == .skipped ? "clock" : "exclamationmark.triangle")
                        .font(Theme.captionDynamic)
                        .foregroundStyle(
                            item.status == .skipped
                                ? Color(light: UIColor(hex: "A34A00"), dark: UIColor(hex: "FFA04D"))
                                : Color(light: UIColor(hex: "BA2115"), dark: UIColor(hex: "FF8078"))
                        )
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
                    item.isPurchased ? Theme.accentYellow : Color.appTextSecondary.opacity(0.85),
                    lineWidth: 1.8
                )

            if item.isPurchased {
                Circle()
                    .fill(Theme.accentYellow)
                    .transition(.scale.combined(with: .opacity))

                Image(systemName: "checkmark")
                    .font(.system(size: checkmarkSize, weight: .bold))
                    .foregroundStyle(Color(hex: "1A1A1A"))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: checkboxSize, height: checkboxSize)
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
