import SwiftUI
import UIKit

/// Insignia visual con icono y color temático para una lista de compras.
/// Se adapta a diferentes tamaños (tarjeta, detalle, vista previa).
struct ListBadgeView: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 48
    var iconSize: CGFloat = 22
    var cornerRadius: CGFloat = 14

    /// Opacidad del tinte de fondo; la misma con la que se mide el ícono.
    nonisolated static let tintOpacity: CGFloat = 0.16

    var body: some View {
        let colors = Self.iconColors(for: UIColor(color))
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(color.opacity(Self.tintOpacity))
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(color.opacity(0.3), lineWidth: 1.2)
                )

            Image(systemName: symbol)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(Color(light: colors.light, dark: colors.dark))
        }
        .accessibilityHidden(true)
    }

    /// El ícono iba pintado con el color crudo sobre su propio tinte: el
    /// amarillo por defecto medía 1,6:1 en claro y el café 2,1:1 en oscuro,
    /// bajo el 3:1 de un elemento gráfico. Se conserva el tono y se ajusta el
    /// brillo hasta 3:1 contra el tinte ya compuesto sobre la tarjeta, igual
    /// que hacen las insignias de categoría (`Category.iconColor`).
    nonisolated static func iconColors(for base: UIColor) -> (light: UIColor, dark: UIColor) {
        let lightBadge = base.blended(alpha: tintOpacity, over: UIColor(hex: "FFFFFF"))
        let darkBadge = base.blended(alpha: tintOpacity, over: UIColor(hex: "2A2928"))

        let light = base.darkened(toContrast: 3, over: lightBadge)

        var dark = base
        var whiteMix: CGFloat = 0
        while Theme.contrastRatio(dark, darkBadge) < 3, whiteMix < 1 {
            whiteMix += 0.05
            dark = UIColor.white.blended(alpha: whiteMix, over: base)
        }
        return (light, dark)
    }
}
