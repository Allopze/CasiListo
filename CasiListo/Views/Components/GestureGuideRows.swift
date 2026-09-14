import SwiftUI

/// Las cuatro tarjetas de la guía de gestos, sin envoltorio.
///
/// Extraído de `SettingsGestureGuideSection` (CASI-011): el texto vive una
/// sola vez y lo consumen dos lugares con presentaciones distintas — Ajustes
/// (dentro de su `SettingsCard`) y el onboarding de primer uso (dentro de su
/// propia hoja).
struct GestureGuideRows: View {
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 22
    @ScaledMetric(relativeTo: .body) private var iconFrame: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var rowSpacing: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            gestoInfoRow(
                icon: "checkmark.circle.fill",
                title: "Marcar productos",
                description: "Toca el círculo a la izquierda del producto para marcarlo como comprado o volverlo a pendiente."
            )

            gestoInfoRow(
                icon: "hand.tap.fill",
                title: "Editar detalles",
                description: "Toca el nombre del producto para cambiar su cantidad, precio, tienda o notas. También puedes deslizar la fila."
            )

            gestoInfoRow(
                icon: "hand.point.up.left.and.text.fill",
                title: "Más acciones",
                description: "Mantén presionado un producto para posponerlo, marcarlo como no encontrado, reordenarlo o eliminarlo."
            )

            gestoInfoRow(
                icon: "books.vertical.fill",
                title: "Añadir desde el catálogo",
                description: "En la pestaña Catálogo, toca el + de cualquier producto habitual para enviarlo a tu compra."
            )
        }
    }

    private func gestoInfoRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundStyle(Theme.accentInteractive)
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
