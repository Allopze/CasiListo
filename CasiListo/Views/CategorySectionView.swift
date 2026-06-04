import SwiftUI
import SwiftData

/// Sección de la lista agrupada por categoría.
/// Muestra un header discreto con SF Symbol y los ítems de esa categoría.
struct CategorySectionView: View {
    let category: Category
    let items: [ShoppingItem]
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void
    let onTogglePurchased: (ShoppingItem) -> Void
    let onEdit: (ShoppingItem) -> Void
    let onDelete: (ShoppingItem) -> Void
    let onMarkStatus: (ShoppingItem, ShoppingItemStatus) -> Void

    @Environment(\.modelContext) private var modelContext
    
    @ScaledMetric(relativeTo: .body) private var cardPadding: CGFloat = Theme.cardPadding
    @ScaledMetric(relativeTo: .body) private var paddingVertical: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var listRowInsetTop: CGFloat = 4
    @ScaledMetric(relativeTo: .body) private var listRowInsetSide: CGFloat = 30 // Theme.cardPadding + 14
    @ScaledMetric(relativeTo: .body) private var hStackSpacing: CGFloat = 10
    @ScaledMetric(relativeTo: .body) private var sfSymbolSize: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var imageWidth: CGFloat = 24
    @ScaledMetric(relativeTo: .caption) private var countPaddingHorizontal: CGFloat = 10
    @ScaledMetric(relativeTo: .caption) private var countPaddingVertical: CGFloat = 4
    @ScaledMetric(relativeTo: .body) private var chevronSize: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat = Theme.cornerRadius
    @ScaledMetric(relativeTo: .body) private var smallCornerRadius: CGFloat = Theme.smallCornerRadius
    @ScaledMetric(relativeTo: .body) private var rowBackgroundPaddingVertical: CGFloat = 3
    @ScaledMetric(relativeTo: .body) private var topPadding: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var bottomPadding: CGFloat = 4
    @ScaledMetric(relativeTo: .body) private var collapsedPaddingVertical: CGFloat = 6
    @ScaledMetric(relativeTo: .body) private var collapsedOuterPadding: CGFloat = 1

    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    var body: some View {
        Section {
            if !isCollapsed {
                ForEach(items, id: \.id) { item in
                    ItemRowView(
                        item: item,
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
                    .equatable()
                    .listRowInsets(.init(
                        top: listRowInsetTop,
                        leading: listRowInsetSide,
                        bottom: listRowInsetTop,
                        trailing: listRowInsetSide
                    ))
                    .listRowSeparator(.hidden)
                    .listRowBackground(rowBackground)
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
                    .foregroundStyle(Category.accentColor(forName: category.name))
                    .frame(width: imageWidth, height: imageWidth)
                    .background(Category.accentColor(forName: category.name).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(category.displayName)
                    .font(Theme.sectionHeaderFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(Color.appTextPrimary)
                    .bold()

                Spacer()

                categoryBadge
                
                Image(systemName: "chevron.down")
                    .font(.system(size: chevronSize, weight: .bold))
                    .foregroundStyle(Color.appTextSecondary)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCollapsed)
            }
            .textCase(nil)
            .padding(.vertical, isCollapsed ? collapsedPaddingVertical : paddingVertical)
            .padding(.horizontal, cardPadding)
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
            .padding(.horizontal, cardPadding)
            .padding(.top, isCollapsed ? collapsedOuterPadding : topPadding)
            .padding(.bottom, isCollapsed ? collapsedOuterPadding : bottomPadding)
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
    }

    private var pendingCount: Int { items.filter { !$0.isPurchased }.count }
    private var purchasedCount: Int { items.filter { $0.isPurchased }.count }

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
                .background(Color.green)
                .clipShape(Capsule())
        } else if purchasedCount > 0 {
            HStack(spacing: 4) {
                Text("\(pendingCount)")
                    .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(Color.black)
                    .bold()
                    .monospacedDigit()
                    .padding(.horizontal, countPaddingHorizontal)
                    .padding(.vertical, countPaddingVertical)
                    .background(Theme.accentYellow)
                    .clipShape(Capsule())
                Label("\(purchasedCount)", systemImage: "checkmark")
                    .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(.white)
                    .bold()
                    .monospacedDigit()
                    .padding(.horizontal, countPaddingHorizontal)
                    .padding(.vertical, countPaddingVertical)
                    .background(Color.green)
                    .clipShape(Capsule())
            }
        } else {
            Text("\(pendingCount)")
                .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.black)
                .bold()
                .monospacedDigit()
                .padding(.horizontal, countPaddingHorizontal)
                .padding(.vertical, countPaddingVertical)
                .background(Theme.accentYellow)
                .clipShape(Capsule())
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: smallCornerRadius, style: .continuous)
            .fill(Color.appCardBackground)
            .padding(.horizontal, cardPadding)
            .padding(.vertical, rowBackgroundPaddingVertical)
            .shadow(color: .black.opacity(0.02), radius: 3, x: 0, y: 1)
    }
}
