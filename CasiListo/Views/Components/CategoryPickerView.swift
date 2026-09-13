import SwiftUI
import SwiftData

/// Selector visual de categorías usando chips horizontales con scroll.
/// El chip seleccionado se resalta en amarillo.
struct CategoryPickerView: View {
    @Binding var selectedCategory: Category
    @Query(sort: \Category.sortIndex) private var categories: [Category]

    @ScaledMetric(relativeTo: .body) private var minWidth: CGFloat = 160
    @ScaledMetric(relativeTo: .body) private var chipPaddingHorizontal: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var chipPaddingVertical: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var symbolSize: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var checkmarkSize: CGFloat = 14

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: minWidth), spacing: 8)]
    }

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(categories) { category in
                    chipButton(for: category)
                }
            }
        }
    }

    private func chipButton(for category: Category) -> some View {
        let isSelected = selectedCategory.id == category.id

        return Button {
            withAnimation(Theme.quickAnimation) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.sfSymbol)
                    .font(.system(size: symbolSize, weight: .semibold))

                Text(category.displayName)
                    .font(Theme.chipDynamic)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, chipPaddingHorizontal)
            .padding(.vertical, chipPaddingVertical)
            .frame(maxWidth: .infinity)
            // El amarillo de marca rinde 1.45:1 sobre crema: rellena, no escribe.
            .foregroundStyle(isSelected ? Theme.accentInteractive : Color.appTextPrimary)
            .glassFilterSurface(cornerRadius: Theme.chipCornerRadius, interactive: true)
            .overlay(alignment: .trailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: checkmarkSize, weight: .semibold))
                        .foregroundStyle(Theme.accentInteractive)
                        .padding(.trailing, 10)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
