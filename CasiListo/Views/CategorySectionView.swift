import SwiftUI

/// Sección de la lista agrupada por categoría.
/// La cabecera y sus ítems forman una única tarjeta continua: la cabecera
/// redondea las esquinas superiores y la última fila las inferiores.
struct CategorySectionView: View {
    let category: Category
    let items: [ShoppingItem]
    var searchText: String = ""
    var showsStore: Bool = true
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void
    let onTogglePurchased: (ShoppingItem) -> Void
    let onEdit: (ShoppingItem) -> Void
    let onDelete: (ShoppingItem) -> Void
    let onMarkStatus: (ShoppingItem, ShoppingItemStatus) -> Void

    @ScaledMetric(relativeTo: .body) private var cardPadding: CGFloat = Theme.cardPadding
    @ScaledMetric(relativeTo: .body) private var headerPaddingVertical: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var listRowInsetVertical: CGFloat = 2
    @ScaledMetric(relativeTo: .body) private var lastRowBottomInset: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var hStackSpacing: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var sfSymbolSize: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var imageWidth: CGFloat = 30
    @ScaledMetric(relativeTo: .caption) private var countPaddingHorizontal: CGFloat = 9
    @ScaledMetric(relativeTo: .caption) private var countPaddingVertical: CGFloat = 3
    @ScaledMetric(relativeTo: .body) private var chevronSize: CGFloat = 13
    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat = Theme.smallCornerRadius
    @ScaledMetric(relativeTo: .body) private var headerMinimumHeight: CGFloat = 56

    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    var body: some View {
        Section {
            sectionHeader
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if !isCollapsed {
                ForEach(items, id: \.id) { item in
                    let isLast = item.id == items.last?.id

                    ItemRowView(
                        item: item,
                        searchText: searchText,
                        showsStore: showsStore,
                        onToggle: {
                            onTogglePurchased(item)
                        },
                        onEdit: {
                            onEdit(item)
                        },
                        onDelete: {
                            onDelete(item)
                        },
                        onMarkStatus: { status in
                            onMarkStatus(item, status)
                        }
                    )
                    .listRowInsets(.init(
                        top: listRowInsetVertical,
                        leading: cardPadding * 2,
                        bottom: isLast ? lastRowBottomInset : listRowInsetVertical,
                        trailing: cardPadding * 2
                    ))
                    .listRowSeparator(isLast ? .hidden : .visible, edges: .bottom)
                    .listRowSeparatorTint(Color.appSeparator)
                    .listRowBackground(rowBackground(isLast: isLast))
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            HapticFeedback.impact()
                            withAnimation(Theme.defaultAnimation) {
                                onDelete(item)
                            }
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }

                        Button {
                            HapticFeedback.selection()
                            onEdit(item)
                        } label: {
                            Label("Editar", systemImage: "pencil")
                        }
                        .tint(Color(hex: "B8860B"))
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            HapticFeedback.selection()
                            withAnimation(Theme.defaultAnimation) {
                                onTogglePurchased(item)
                            }
                        } label: {
                            Label(
                                item.isPurchased ? "Pendiente" : "Comprado",
                                systemImage: item.isPurchased ? "circle" : "checkmark.circle.fill"
                            )
                        }
                        .tint(.green)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
        }
    }

    /// Fondo blanco de fila que continúa la tarjeta de la cabecera.
    private func rowBackground(isLast: Bool) -> some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: isLast ? cornerRadius : 0,
            bottomTrailingRadius: isLast ? cornerRadius : 0,
            topTrailingRadius: 0,
            style: .continuous
        )
        .fill(Color.appCardBackground)
        .padding(.horizontal, cardPadding)
    }

    private var sectionHeader: some View {
        Button {
            HapticFeedback.selection()
            withAnimation(Theme.defaultAnimation) {
                onToggleCollapse()
            }
        } label: {
            HStack(spacing: hStackSpacing) {
                Image(systemName: category.sfSymbol)
                    .font(.system(size: sfSymbolSize, weight: .semibold))
                    .foregroundStyle(categoryAccent)
                    .frame(width: imageWidth, height: imageWidth)
                    .background(categoryAccent.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                Text(category.displayName)
                    .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(Color.appTextPrimary)

                Spacer()

                categoryBadge

                Image(systemName: "chevron.down")
                    .font(.system(size: chevronSize, weight: .semibold))
                    .foregroundStyle(Color.appTextSecondary)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 180))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCollapsed)
            }
            .textCase(nil)
            .padding(.vertical, headerPaddingVertical)
            .padding(.horizontal, cardPadding)
            .frame(maxWidth: .infinity, minHeight: headerMinimumHeight, alignment: .leading)
            .background {
                UnevenRoundedRectangle(
                    topLeadingRadius: cornerRadius,
                    bottomLeadingRadius: isCollapsed ? cornerRadius : 0,
                    bottomTrailingRadius: isCollapsed ? cornerRadius : 0,
                    topTrailingRadius: cornerRadius,
                    style: .continuous
                )
                .fill(Color.appCardBackground)
            }
            .padding(.horizontal, cardPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            var label = "\(category.displayName), \(pendingCount) pendientes"
            if purchasedCount > 0 { label += ", \(purchasedCount) comprados" }
            return label
        }())
        .accessibilityValue(isCollapsed ? "Colapsada" : "Expandida")
        .accessibilityHint(isCollapsed ? "Toca para expandir la categoría" : "Toca para colapsar la categoría")
        .accessibilityIdentifier("category-section-\(category.name)")
    }

    private var pendingCount: Int { items.filter { !$0.isPurchased }.count }
    private var purchasedCount: Int { items.filter { $0.isPurchased }.count }
    private var categoryAccent: Color { Category.accentColor(forName: category.name) }

    /// Recuento discreto: texto secundario para pendientes; verde solo cuando
    /// la categoría está completa (estado con significado real).
    @ViewBuilder
    private var categoryBadge: some View {
        if pendingCount == 0 {
            Label("\(purchasedCount)", systemImage: "checkmark")
                .font(Theme.captionFont(scale: accessibilityTextSizeScale).weight(.semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .padding(.horizontal, countPaddingHorizontal)
                .padding(.vertical, countPaddingVertical)
                .background(Color(hex: "2E7D42"))
                .clipShape(Capsule())
        } else if purchasedCount > 0 {
            Text("\(purchasedCount) de \(items.count)")
                .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.appTextSecondary)
                .monospacedDigit()
        } else {
            Text("\(pendingCount)")
                .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.appTextSecondary)
                .monospacedDigit()
        }
    }
}
