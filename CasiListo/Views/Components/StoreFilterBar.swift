import SwiftUI

/// Barra de filtro horizontal por supermercado para la lista de compras.
struct StoreFilterBar: View {
    @Binding var selectedStore: Store?
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8 * CGFloat(accessibilityTextSizeScale)) {
                filterChip(title: "Todos", store: nil, icon: "house.fill")
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
        let activeColor = store?.color ?? Theme.accentYellow

        Button {
            HapticFeedback.selection()
            withAnimation(Theme.defaultAnimation) {
                selectedStore = store
            }
        } label: {
            HStack(spacing: 6 * CGFloat(accessibilityTextSizeScale)) {
                Image(systemName: icon)
                    .font(.system(size: 13 * CGFloat(accessibilityTextSizeScale), weight: .semibold))
                Text(title)
                    .font(Theme.chipFont(scale: accessibilityTextSizeScale))
                    .bold()
            }
            .padding(.horizontal, 14 * CGFloat(accessibilityTextSizeScale))
            .padding(.vertical, 8 * CGFloat(accessibilityTextSizeScale))
            .foregroundStyle(isSelected ? selectedForeground(for: store) : Color.appTextPrimary)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12 * CGFloat(accessibilityTextSizeScale), style: .continuous)
                        .fill(activeColor)
                } else {
                    RoundedRectangle(cornerRadius: 12 * CGFloat(accessibilityTextSizeScale), style: .continuous)
                        .fill(Color.appCardBackground.opacity(0.4))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12 * CGFloat(accessibilityTextSizeScale), style: .continuous)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
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
        store == nil ? Color.black : Color.white
    }
}
