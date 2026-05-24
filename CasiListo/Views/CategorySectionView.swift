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
    let onMove: (IndexSet, Int) -> Void

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
    @ScaledMetric(relativeTo: .body) private var collapsedPaddingVertical: CGFloat = 10
    @ScaledMetric(relativeTo: .body) private var collapsedOuterPadding: CGFloat = 2

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
                .onMove { source, destination in
                    onMove(source, destination)
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
                    .font(.system(size: sfSymbolSize * CGFloat(accessibilityTextSizeScale), weight: .bold))
                    .foregroundStyle(Theme.accentYellow)
                    .frame(width: imageWidth * CGFloat(accessibilityTextSizeScale), alignment: .center)

                Text(category.displayName)
                    .font(Theme.sectionHeaderFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(Color.appTextPrimary)
                    .bold()

                Spacer()

                Text("\(items.count)")
                    .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(Color.black)
                    .bold()
                    .monospacedDigit()
                    .padding(.horizontal, countPaddingHorizontal)
                    .padding(.vertical, countPaddingVertical)
                    .background(Theme.accentYellow)
                    .clipShape(Capsule())
                
                Image(systemName: "chevron.down")
                    .font(.system(size: chevronSize * CGFloat(accessibilityTextSizeScale), weight: .bold))
                    .foregroundStyle(Color.appTextSecondary)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCollapsed)
            }
            .textCase(nil)
            .padding(.vertical, isCollapsed ? collapsedPaddingVertical : paddingVertical)
            .padding(.horizontal, cardPadding)
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
            .padding(.horizontal, cardPadding)
            .padding(.top, isCollapsed ? collapsedOuterPadding : topPadding)
            .padding(.bottom, isCollapsed ? collapsedOuterPadding : bottomPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.displayName), \(items.count) productos")
        .accessibilityValue(isCollapsed ? "Colapsada" : "Expandida")
        .accessibilityHint(isCollapsed ? "Toca para expandir la categoría" : "Toca para colapsar la categoría")
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: smallCornerRadius, style: .continuous)
            .fill(Color.appCardBackground)
            .padding(.horizontal, cardPadding)
            .padding(.vertical, rowBackgroundPaddingVertical)
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}
