import SwiftUI

/// Tarjeta interactiva que representa una lista de compras activa en el menú general.
struct ListCardView: View {
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

    private var previewNames: [String] {
        Array(pendingItems.prefix(3).map(\.name))
    }

    private var remainingCount: Int {
        max(0, pendingItems.count - 3)
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
                            .lineLimit(1)

                        statusRow
                    }

                    Spacer()

                    // Hueco reservado para el menú, que se dibuja por encima.
                    Color.clear.frame(width: 32, height: 32)
                }

                if !previewNames.isEmpty {
                    previewPillsRow
                }
            }
            .padding(14)
            .background(
                Color.appCardBackground,
                in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous)
            )
            .shadow(color: .black.opacity(0.025), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("list-card-\(list.title)")
        .accessibilityLabel("\(list.title), \(pendingItems.count) productos pendientes, \(purchasedItems.count) comprados")
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
            .padding(.top, 14)
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
                Text("\(pendingItems.count) pendientes")
                    .font(Theme.captionDynamic.weight(.medium))
                    .foregroundStyle(pendingItems.isEmpty ? Color.appTextSecondary : Color.appTextPrimary)

                if !purchasedItems.isEmpty {
                    Text("·")
                        .foregroundStyle(Color.appTextSecondary)
                    Text("\(purchasedItems.count) listos")
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Color(light: UIColor(hex: "1B6E33"), dark: UIColor(hex: "6FD08C")))
                }
            }
        }
    }

    private var previewPillsRow: some View {
        HStack(spacing: 6) {
            ForEach(Array(previewNames.enumerated()), id: \.offset) { _, name in
                Text(name)
                    .font(Theme.chipDynamic)
                    .foregroundStyle(Color.appTextPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appBackground, in: Capsule())
                    .lineLimit(1)
            }

            if remainingCount > 0 {
                Text("+\(remainingCount)")
                    .font(Theme.chipDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.appBackground.opacity(0.8), in: Capsule())
            }
        }
    }
}
