import SwiftUI

/// Barra de filtro horizontal por supermercado para la lista de compras.
struct StoreFilterBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selectedStore: Store?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "Todos", store: nil, icon: "square.grid.2x2.fill")
                ForEach(Store.allCases) { store in
                    filterChip(title: store.displayName, store: store, icon: store.sfSymbol)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func filterChip(title: String, store: Store?, icon: String) -> some View {
        let isSelected = selectedStore == store
        // Relleno oscurecido para que el texto blanco cumpla 4.5:1 (WCAG AA).
        let activeColor = store?.selectedFillColor ?? Theme.accentYellow

        Button {
            HapticFeedback.selection()
            withAnimation(Theme.defaultAnimation(reduceMotion: reduceMotion)) {
                selectedStore = store
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(Theme.chipDynamic)
                Text(title)
                    .font(Theme.chipDynamic)
                    .bold()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? selectedForeground(for: store) : Color.appTextPrimary)
            .background {
                if isSelected {
                    Capsule()
                        .fill(activeColor)
                } else {
                    Capsule()
                        .fill(Color.appCardBackground.opacity(0.85))
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.appSeparator, lineWidth: 1)
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Seleccionado" : "No seleccionado")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func selectedForeground(for store: Store?) -> Color {
        store == nil ? Theme.onAccent : Color.white
    }
}
