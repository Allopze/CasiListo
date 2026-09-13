import SwiftUI

/// Selector de iconos categorizado para personalizar una lista de compras.
struct ListIconPickerView: View {
    @Binding var selectedSymbol: String
    let tintColor: Color
    /// Hex del color seleccionado: hace falta para calcular el contraste del icono.
    let tintColorHex: String
    var onIconSelected: (() -> Void)?

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 38

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: iconSize, maximum: iconSize * 1.5), spacing: 10)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(ListAppearanceCatalog.iconCategories) { category in
                VStack(alignment: .leading, spacing: 8) {
                    Text(category.title)
                        .font(Theme.captionDynamic.weight(.semibold))
                        .foregroundStyle(Color.appTextSecondary)

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(category.symbols, id: \.self) { symbol in
                            Button {
                                HapticFeedback.selection()
                                onIconSelected?()
                                withAnimation(Theme.quickAnimation) {
                                    selectedSymbol = symbol
                                }
                            } label: {
                                Image(systemName: symbol)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(
                                        selectedSymbol == symbol
                                            ? ListAppearanceCatalog.foreground(on: tintColorHex)
                                            : Color.appTextPrimary
                                    )
                                    .frame(width: iconSize, height: iconSize)
                                    .background(selectedSymbol == symbol ? tintColor : Color.appCardBackground.opacity(0.8))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(selectedSymbol == symbol ? tintColor : Color.appSeparator, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(ListAppearanceCatalog.displayName(for: symbol))
                            .accessibilityAddTraits(selectedSymbol == symbol ? .isSelected : [])
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
