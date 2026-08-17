import SwiftUI

/// Insignia visual con icono y color temático para una lista de compras.
/// Se adapta a diferentes tamaños (tarjeta, detalle, vista previa).
struct ListBadgeView: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 48
    var iconSize: CGFloat = 22
    var cornerRadius: CGFloat = 14

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(color.opacity(0.16))
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(color.opacity(0.3), lineWidth: 1.2)
                )

            Image(systemName: symbol)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(color)
        }
        .accessibilityHidden(true)
    }
}
