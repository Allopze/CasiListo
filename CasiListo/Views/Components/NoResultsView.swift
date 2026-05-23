import SwiftUI

/// Vista que se muestra cuando una búsqueda en la lista de compras no arroja resultados.
struct NoResultsView: View {
    let searchText: String
    var onAddSearch: (() -> Void)? = nil
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    var body: some View {
        VStack(spacing: 12 * CGFloat(accessibilityTextSizeScale)) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40 * CGFloat(accessibilityTextSizeScale)))
                .foregroundStyle(Color.appTextPurchased)

            Text("Sin resultados")
                .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.appTextSecondary)

            Text("No se encontraron productos para \"\(searchText)\"")
                .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.appTextPurchased)
                .multilineTextAlignment(.center)

            if !searchText.trimmingCharacters(in: .whitespaces).isEmpty, let onAddSearch {
                Button {
                    HapticFeedback.impact()
                    onAddSearch()
                } label: {
                    Label("Añadir \"\(searchText)\"", systemImage: "plus")
                        .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(.black)
                        .frame(minHeight: Theme.minimumTouchTarget)
                        .padding(.horizontal, 16)
                        .background(Theme.accentYellow)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .accessibilityLabel("Añadir \(searchText)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
