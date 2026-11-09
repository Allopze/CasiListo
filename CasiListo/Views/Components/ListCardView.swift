import SwiftUI

/// Tarjeta interactiva que representa una lista de compras activa en el menú general.
struct ListCardView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let list: ShoppingList
    let items: [ShoppingItem]
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    private var pendingItems: [ShoppingItem] {
        items.filter { $0.status == .pending }
    }

    private var purchasedItems: [ShoppingItem] {
        items.filter { $0.status == .purchased }
    }

    private var progress: ListProgress {
        ListProgress(pending: pendingItems.count, purchased: purchasedItems.count)
    }

    var body: some View {
        Button {
            HapticFeedback.selection()
            onSelect()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    ListBadgeView(
                        symbol: list.iconName,
                        color: list.accentColor,
                        size: 48,
                        iconSize: 22,
                        cornerRadius: 14
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(list.title)
                            .font(Theme.bodyBoldDynamic)
                            .foregroundStyle(Color.appTextPrimary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                            .fixedSize(horizontal: false, vertical: true)

                        statusRow
                    }

                    Spacer()

                    // Hueco reservado para el menú, que se dibuja por encima.
                    Color.clear.frame(width: 32, height: 32)
                }

                // Al 0 % la barra sería una línea gris sin información.
                if progress.purchased > 0 {
                    progressBar
                }

                if !pendingItems.isEmpty {
                    previewPillsRow
                }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .fill(Color.appCardBackground)
                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("list-card-\(list.title)")
        .accessibilityLabel(
            "\(list.title), "
                + "\(SpanishPluralization.count(pendingItems.count, singular: "producto pendiente", plural: "productos pendientes")), "
                + "\(SpanishPluralization.count(purchasedItems.count, singular: "producto comprado", plural: "productos comprados"))"
        )
        .accessibilityHint("Toca para abrir esta lista")
        .contextMenu { listActions }
        // El menú vive fuera del Button: SwiftUI no activa controles anidados
        // dentro del label de otro control. `swipeActions` tampoco sirve aquí,
        // solo funciona en filas de `List` y estas tarjetas van en un `LazyVStack`.
        .overlay(alignment: .topTrailing) {
            Menu {
                listActions
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .padding(.top, 16)
            .padding(.trailing, 6)
            .accessibilityLabel("Acciones de \(list.title)")
            .accessibilityIdentifier("list-card-menu-\(list.title)")
        }
    }

    // MARK: - Subvistas

    @ViewBuilder
    private var listActions: some View {
        Button(action: onEdit) {
            Label("Editar lista", systemImage: "pencil")
        }

        Button(action: onDuplicate) {
            Label("Duplicar lista", systemImage: "doc.on.doc")
        }

        Divider()

        // Sin el tint explícito, el tint amarillo de la app pinta el basurero y
        // solo el texto queda rojo: la acción destructiva se lee a medias.
        Button(role: .destructive, action: onDelete) {
            Label("Eliminar lista", systemImage: "trash")
        }
        .tint(.red)
    }

    @ViewBuilder
    private var statusRow: some View {
        HStack(spacing: 6) {
            if pendingItems.isEmpty && purchasedItems.isEmpty {
                Text("Lista vacía")
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)
            } else {
                Text(SpanishPluralization.count(pendingItems.count, singular: "pendiente", plural: "pendientes"))
                    .font(Theme.captionDynamic.weight(.medium))
                    .foregroundStyle(pendingItems.isEmpty ? Color.appTextSecondary : Color.appTextPrimary)

                if !purchasedItems.isEmpty {
                    Text("·")
                        .foregroundStyle(Color.appTextSecondary)
                    Text(SpanishPluralization.count(purchasedItems.count, singular: "listo", plural: "listos"))
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Theme.statusPurchased)
                }

                stagePill
            }
        }
    }

    /// El nombre de la app aparece en la tarjeta exactamente cuando es verdad.
    @ViewBuilder
    private var stagePill: some View {
        switch progress.stage {
        case .almostDone:
            Text("Casi listo")
                .font(Theme.chipDynamic.weight(.bold))
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Theme.accentYellow, in: Capsule())
        case .done:
            Label("¡Listo!", systemImage: "checkmark")
                .font(Theme.chipDynamic.weight(.bold))
                .foregroundStyle(Theme.accentYellow)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Theme.panel, in: Capsule())
        default:
            EmptyView()
        }
    }

    /// Avance en el color de la lista, ajustado a 3:1 como su insignia.
    private var progressBar: some View {
        let colors = ListBadgeView.iconColors(for: list.uiColor)
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.appSeparator)
                Capsule()
                    .fill(Color(light: colors.light, dark: colors.dark))
                    .frame(width: progress.fraction > 0 ? max(6, proxy.size.width * progress.fraction) : 0)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    /// Muestra tantos nombres enteros como quepan (3, 2 o 1) en vez de tres
    /// truncados: «Bolsas basur…» no le dice nada a nadie.
    private var previewPillsRow: some View {
        ViewThatFits(in: .horizontal) {
            pills(count: 3, truncates: false)
            pills(count: 2, truncates: false)
            pills(count: 1, truncates: false)
            pills(count: 1, truncates: true)
        }
    }

    private func pills(count: Int, truncates: Bool) -> some View {
        let names = pendingItems.prefix(count).map(\.name)
        let remaining = max(0, pendingItems.count - names.count)
        return HStack(spacing: 6) {
            ForEach(Array(names.enumerated()), id: \.offset) { _, name in
                Text(name)
                    .font(Theme.chipDynamic)
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(truncates && !dynamicTypeSize.isAccessibilitySize ? 1 : nil)
                    .fixedSize(horizontal: !truncates, vertical: true)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appBackground, in: Capsule())
            }

            if remaining > 0 {
                Text("+\(remaining)")
                    .font(Theme.chipDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .monospacedDigit()
                    .fixedSize()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.appBackground.opacity(0.8), in: Capsule())
            }
        }
    }
}
