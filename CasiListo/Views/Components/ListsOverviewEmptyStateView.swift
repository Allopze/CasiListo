import SwiftUI

/// Estado vacío del menú general cuando no hay listas activas.
/// Ofrece botón de creación y atajos rápidos sugeridos.
struct ListsOverviewEmptyStateView: View {
    let onCreateTapped: () -> Void
    let onQuickStarterTapped: (_ title: String, _ symbol: String, _ colorHex: String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart.badge.plus")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Theme.accentYellow)
                .frame(width: 88, height: 88)
                .background(Theme.accentYellow.opacity(0.12), in: Circle())
                .padding(.top, 24)

            VStack(spacing: 6) {
                Text("No tienes listas activas")
                    .font(Theme.sectionHeaderDynamic)
                    .foregroundStyle(Color.appTextPrimary)

                Text("Crea una lista para organizar tus compras por ocasión o supermercado.")
                    .font(Theme.bodyDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button(action: onCreateTapped) {
                Label("Crear mi primera lista", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accentYellow)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .accessibilityIdentifier("empty-lists-create")

            // Atajos rápidos
            VStack(spacing: 8) {
                Text("O empieza con una sugerida:")
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)

                HStack(spacing: 8) {
                    quickStarterButton(title: "Supermercado", symbol: "cart.fill", colorHex: "F5C518")
                    quickStarterButton(title: "Feria & Frutas", symbol: "leaf.fill", colorHex: "4CAF50")
                    quickStarterButton(title: "Asado", symbol: "flame.fill", colorHex: "FF5722")
                }
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            Color.appCardBackground,
            in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
        )
    }

    private func quickStarterButton(title: String, symbol: String, colorHex: String) -> some View {
        Button {
            onQuickStarterTapped(title, symbol, colorHex)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.caption)
                Text(title)
                    .font(Theme.captionDynamic.weight(.medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(Color.appTextPrimary)
            .background(Color.appBackground, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("list-starter-\(title)")
    }
}
