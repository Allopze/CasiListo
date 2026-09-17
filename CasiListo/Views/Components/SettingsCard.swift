import SwiftUI

/// Sección estándar de Ajustes: encabezado en mayúsculas + contenido.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.captionDynamic.weight(.semibold))
                .foregroundStyle(Color.appTextSecondary)
                .padding(.leading, 6)

            content
        }
        .padding(.horizontal, Theme.cardPadding)
    }
}

/// Tarjeta estándar de Ajustes (fondo, radio y sombra unificados).
struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

/// Fila estándar de enlace en Ajustes: ícono + título + detalle + chevron.
struct SettingsLinkRow: View {
    let title: String
    let detail: String
    let symbol: String
    var destructive: Bool = false

    private var destructiveColor: Color {
        Color(light: UIColor(hex: "BA2115"), dark: UIColor(hex: "FF8078"))
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(destructive ? destructiveColor : Theme.accentYellow)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.bodyBoldDynamic)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appTextSecondary)
        }
        .foregroundStyle(destructive ? destructiveColor : Color.appTextPrimary)
    }
}
