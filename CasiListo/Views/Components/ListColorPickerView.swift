import SwiftUI

/// Selector de color para personalizar una lista de compras.
/// Muestra una cuadrícula adaptativa con la paleta curada de CasiListo.
struct ListColorPickerView: View {
    @Binding var selectedColorHex: String
    var onColorSelected: (() -> Void)? = nil

    @ScaledMetric(relativeTo: .body) private var circleSize: CGFloat = 34

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: circleSize, maximum: circleSize * 1.5), spacing: 12)]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(ListAppearanceCatalog.colors) { option in
                Button {
                    HapticFeedback.selection()
                    onColorSelected?()
                    withAnimation(Theme.quickAnimation) {
                        selectedColorHex = option.hex
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(option.color)
                            .frame(width: circleSize, height: circleSize)

                        if selectedColorHex == option.hex {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(ListAppearanceCatalog.foreground(on: option.hex))
                        }
                    }
                    .overlay(
                        Circle()
                            .stroke(selectedColorHex == option.hex ? Color.appTextPrimary : Color.clear, lineWidth: 2.5)
                            .padding(-3)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.name)
                .accessibilityAddTraits(selectedColorHex == option.hex ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
