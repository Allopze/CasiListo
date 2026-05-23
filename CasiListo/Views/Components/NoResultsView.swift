import SwiftUI

/// Vista que se muestra cuando una búsqueda en la lista de compras no arroja resultados.
struct NoResultsView: View {
    let searchText: String
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
        }
        .frame(maxWidth: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
    }
}
