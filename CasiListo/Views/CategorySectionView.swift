import SwiftUI
import SwiftData

/// Sección de la lista agrupada por categoría.
/// Muestra un header discreto con SF Symbol y los ítems de esa categoría.
struct CategorySectionView: View {
    let category: Category
    let items: [ShoppingItem]
    let viewModel: ShoppingListViewModel
    let onEdit: (ShoppingItem) -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    var body: some View {
        let isCollapsed = viewModel.isCategoryCollapsed(category)
        
        Section {
            if !isCollapsed {
                ForEach(items, id: \.id) { item in
                    ItemRowView(
                        item: item,
                        onToggle: {
                            viewModel.togglePurchased(item)
                        },
                        onEdit: {
                            onEdit(item)
                        },
                        onDelete: {
                            viewModel.deleteItem(item, context: modelContext)
                        }
                    )
                    .listRowInsets(.init(
                        top: 4 * CGFloat(accessibilityTextSizeScale),
                        leading: Theme.cardPadding(scale: accessibilityTextSizeScale) + 14 * CGFloat(accessibilityTextSizeScale),
                        bottom: 4 * CGFloat(accessibilityTextSizeScale),
                        trailing: Theme.cardPadding(scale: accessibilityTextSizeScale) + 14 * CGFloat(accessibilityTextSizeScale)
                    ))
                    .listRowSeparator(.hidden)
                    .listRowBackground(rowBackground)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            HapticFeedback.impact()
                            withAnimation(Theme.defaultAnimation) {
                                viewModel.deleteItem(item, context: modelContext)
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
                                viewModel.togglePurchased(item)
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
        let isCollapsed = viewModel.isCategoryCollapsed(category)
        
        return Button {
            HapticFeedback.selection()
            withAnimation(Theme.defaultAnimation) {
                viewModel.toggleCategoryCollapse(category)
            }
        } label: {
            HStack(spacing: 8 * CGFloat(accessibilityTextSizeScale)) {
                Image(systemName: category.sfSymbol)
                    .font(.system(size: 14 * CGFloat(accessibilityTextSizeScale), weight: .semibold))
                    .foregroundStyle(Theme.accentYellow)
                    .frame(width: 20 * CGFloat(accessibilityTextSizeScale), alignment: .center)

                Text(category.displayName)
                    .font(Theme.sectionHeaderFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(Color.appTextSecondary)

                Spacer()

                Text("\(items.count)")
                    .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(Color.appTextPurchased)
                    .monospacedDigit()
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 11 * CGFloat(accessibilityTextSizeScale), weight: .bold))
                    .foregroundStyle(Color.appTextSecondary)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCollapsed)
            }
            .textCase(nil)
            .padding(.top, 8 * CGFloat(accessibilityTextSizeScale))
            .padding(.bottom, 4 * CGFloat(accessibilityTextSizeScale))
            .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(isCollapsed ? "Toca para expandir la categoría" : "Toca para colapsar la categoría")
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: Theme.cornerRadius(scale: accessibilityTextSizeScale), style: .continuous)
            .fill(Color.appCardBackground)
            .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale))
            .padding(.vertical, 3 * CGFloat(accessibilityTextSizeScale))
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}
