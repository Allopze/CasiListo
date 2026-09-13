import SwiftUI

/// Vista para cuando la lista no muestra productos: distingue entre una
/// búsqueda sin resultados (ofrece añadir directo o desde el catálogo)
/// y un filtrado que dejó la lista vacía.
struct NoResultsView: View {
    let searchText: String
    var catalogMatches: [ProductCatalogItem] = []
    /// Añade el texto buscado directamente (hereda el parser de cantidades).
    var onQuickAddSearch: (() -> Void)?
    /// Abre el formulario completo con el texto precargado.
    var onAddSearch: (() -> Void)?
    var onAddCatalogItem: ((ProductCatalogItem) -> Void)?

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isSearching ? "magnifyingglass" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 40))
                .foregroundStyle(Color.appTextPurchased)

            Text(isSearching ? "No está en tu compra" : "Nada con estos filtros")
                .font(Theme.bodyBoldDynamic)
                .foregroundStyle(Color.appTextSecondary)

            Text(isSearching
                 ? "\"\(searchText)\" no aparece en la lista actual."
                 : "Prueba mostrar los comprados o cambiar de supermercado.")
                .font(Theme.captionDynamic)
                .foregroundStyle(Color.appTextPurchased)
                .multilineTextAlignment(.center)

            if isSearching {
                if let onQuickAddSearch {
                    Button {
                        HapticFeedback.impact()
                        onQuickAddSearch()
                    } label: {
                        Label("Añadir \"\(searchText)\"", systemImage: "plus")
                            .font(Theme.bodyBoldDynamic)
                            .foregroundStyle(Theme.onAccent)
                            .frame(minHeight: Theme.minimumTouchTarget)
                            .padding(.horizontal, 16)
                            .background(Theme.accentYellow)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    .accessibilityLabel("Añadir \(searchText) a la compra")
                }

                if let onAddSearch {
                    Button {
                        HapticFeedback.selection()
                        onAddSearch()
                    } label: {
                        Text("Añadir con detalles…")
                            .font(Theme.captionDynamic.weight(.semibold))
                            .foregroundStyle(Color.appTextSecondary)
                            .frame(minHeight: Theme.minimumTouchTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Añadir \(searchText) con detalles")
                }

                if !catalogMatches.isEmpty, let onAddCatalogItem {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DE TU CATÁLOGO")
                            .font(Theme.captionDynamic.weight(.semibold))
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.horizontal, 6)
                            .padding(.bottom, 4)

                        ForEach(catalogMatches) { match in
                            Button {
                                HapticFeedback.impact()
                                onAddCatalogItem(match)
                            } label: {
                                HStack(spacing: 10) {
                                    Text(match.name)
                                        .font(Theme.bodyDynamic)
                                        .foregroundStyle(Color.appTextPrimary)
                                        .lineLimit(1)
                                    Spacer(minLength: 8)
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(Color.appTextSecondary)
                                }
                                .padding(.horizontal, 14)
                                .frame(minHeight: Theme.minimumTouchTarget)
                                .background(Color.appCardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Añadir \(match.name) del catálogo")
                        }
                    }
                    .frame(maxWidth: 420)
                    .padding(.top, 12)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
