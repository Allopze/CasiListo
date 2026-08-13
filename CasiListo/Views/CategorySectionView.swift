import SwiftUI

/// Sección de la lista agrupada por categoría.
/// La cabecera funciona como una tarjeta principal y permite expandir o contraer
/// los ítems de la categoría.
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
    @ScaledMetric(relativeTo: .body) private var listRowInsetTop: CGFloat = 2
    @ScaledMetric(relativeTo: .body) private var hStackSpacing: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var sfSymbolSize: CGFloat = 19
    @ScaledMetric(relativeTo: .body) private var imageWidth: CGFloat = 32
    @ScaledMetric(relativeTo: .caption) private var countPaddingHorizontal: CGFloat = 10
    @ScaledMetric(relativeTo: .caption) private var countPaddingVertical: CGFloat = 4
    @ScaledMetric(relativeTo: .body) private var chevronSize: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat = Theme.smallCornerRadius
    @ScaledMetric(relativeTo: .body) private var topPadding: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var bottomPadding: CGFloat = 0
    @ScaledMetric(relativeTo: .body) private var headerMinimumHeight: CGFloat = 64

    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    var body: some View {
        Section {
            if !isCollapsed {
                ForEach(items, id: \.id) { item in
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
                        top: listRowInsetTop,
                        leading: cardPadding,
                        bottom: listRowInsetTop,
                        trailing: cardPadding
                    ))
                    .listRowSeparator(.visible, edges: .bottom)
                    .listRowSeparatorTint(Color.appSeparator.opacity(0.85))
                    .listRowBackground(Color.clear)
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
                        .tint(Theme.accentYellow)
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
        } header: {
            sectionHeader
        }
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
                    .font(.system(size: sfSymbolSize, weight: .bold))
                    .foregroundStyle(categoryAccent)
                    .frame(width: imageWidth, height: imageWidth)
                    .background(categoryAccent.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(category.displayName)
                    .font(Theme.sectionHeaderFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(Color.appTextPrimary)
                    .bold()

                Spacer()

                categoryBadge
                
                Image(systemName: "chevron.down")
                    .font(.system(size: chevronSize, weight: .bold))
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(width: Theme.minimumTouchTarget, height: Theme.minimumTouchTarget)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 180))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCollapsed)
            }
            .textCase(nil)
            .padding(.vertical, headerPaddingVertical)
            .padding(.horizontal, cardPadding)
            .frame(maxWidth: .infinity, minHeight: headerMinimumHeight, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.appCardBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.appSeparator.opacity(0.8), lineWidth: 1)
                    }
            }
            .shadow(color: .black.opacity(0.025), radius: 4, x: 0, y: 2)
            .padding(.horizontal, cardPadding)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
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

    @ViewBuilder
    private var categoryBadge: some View {
        if pendingCount == 0 {
            Label("\(purchasedCount)", systemImage: "checkmark")
                .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(.white)
                .bold()
                .monospacedDigit()
                .padding(.horizontal, countPaddingHorizontal)
                .padding(.vertical, countPaddingVertical)
                .background(Color.green.opacity(0.85))
                .clipShape(Capsule())
        } else if purchasedCount > 0 {
            HStack(spacing: 4) {
                Text("\(pendingCount)")
                    .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(categoryAccent)
                    .bold()
                    .monospacedDigit()
                    .padding(.horizontal, countPaddingHorizontal)
                    .padding(.vertical, countPaddingVertical)
                    .background(categoryAccent.opacity(0.16))
                    .clipShape(Capsule())
                Label("\(purchasedCount)", systemImage: "checkmark")
                    .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(.white)
                    .bold()
                    .monospacedDigit()
                    .padding(.horizontal, countPaddingHorizontal)
                    .padding(.vertical, countPaddingVertical)
                    .background(Color.green.opacity(0.85))
                    .clipShape(Capsule())
            }
        } else {
            Text("\(pendingCount)")
                .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(categoryAccent)
                .bold()
                .monospacedDigit()
                .padding(.horizontal, countPaddingHorizontal)
                .padding(.vertical, countPaddingVertical)
                .background(categoryAccent.opacity(0.16))
                .clipShape(Capsule())
        }
    }
}
