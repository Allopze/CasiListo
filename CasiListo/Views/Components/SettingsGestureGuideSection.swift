import SwiftUI

struct SettingsGestureGuideSection: View {

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 22
    @ScaledMetric(relativeTo: .body) private var iconFrame: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var rowSpacing: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GUÍA DE USO")
                .font(Theme.captionDynamic)
                .foregroundStyle(Color.appTextSecondary)
                .padding(.leading, 6)
                .bold()

            VStack(alignment: .leading, spacing: rowSpacing) {
                gestoInfoRow(
                    icon: "hand.tap.fill",
                    title: "Marcar productos",
                    description: "Toca cualquier parte de la tarjeta del producto (nombre, nota, checkbox) para marcarlo o desmarcarlo al instante."
                )

                gestoInfoRow(
                    icon: "pencil.circle.fill",
                    title: "Editar detalles",
                    description: "Toca el botón circular del lápiz situado a la derecha del producto para modificar su nombre, cantidad o notas."
                )

                gestoInfoRow(
                    icon: "arrow.up.and.down.square.fill",
                    title: "Organizar categorías",
                    description: "Toca cualquier cabecera de categoría para colapsar o expandir su contenido de productos."
                )
            }
            .padding(Theme.cardPadding)
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
        }
        .padding(.horizontal, Theme.cardPadding)
    }

    private func gestoInfoRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundStyle(Theme.accentYellow)
                .frame(width: iconFrame)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.bodyBoldDynamic)
                    .foregroundStyle(Color.appTextPrimary)

                Text(description)
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
