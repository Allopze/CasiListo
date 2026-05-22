import SwiftUI

/// Selector visual de categorías usando chips horizontales con scroll.
/// El chip seleccionado se resalta en amarillo.
struct CategoryPickerView: View {
    @Binding var selectedCategory: Category

    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 8)
    ]

    var body: some View {
        AdaptiveGlassEffectContainer(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Category.allCases) { category in
                    chipButton(for: category)
                }
            }
        }
    }

    private func chipButton(for category: Category) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            withAnimation(Theme.quickAnimation) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.sfSymbol)
                    .font(.system(size: 12, weight: .semibold))

                Text(category.displayName)
                    .font(Theme.chipFont)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .foregroundStyle(isSelected ? Theme.accentYellow : Color.appTextPrimary)
            .glassFilterSurface(cornerRadius: Theme.chipCornerRadius, interactive: true)
            .overlay(alignment: .trailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accentYellow)
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
