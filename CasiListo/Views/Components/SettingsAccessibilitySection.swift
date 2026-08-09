import SwiftUI

struct SettingsAccessibilitySection: View {
    @Bindable var settings: AppSettings
    let scaleLevelLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ACCESIBILIDAD VISUAL")
                .font(Theme.captionFont(scale: settings.accessibilityTextSizeScale))
                .foregroundStyle(Color.appTextSecondary)
                .padding(.leading, 6)
                .bold()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tamaño del texto e ítems")
                        .font(Theme.bodyBoldFont(scale: settings.accessibilityTextSizeScale))
                        .foregroundStyle(Color.appTextPrimary)

                    Text("Ajusta el slider para cambiar el tamaño de letra, tarjetas y encabezados de categorías.")
                        .font(Theme.captionFont(scale: settings.accessibilityTextSizeScale))
                        .foregroundStyle(Color.appTextSecondary)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.appTextSecondary)
                    
                    Slider(value: $settings.accessibilityTextSizeScale, in: 1.0...1.6, step: 0.05) {
                        Text("Escala del tamaño de texto")
                    } minimumValueLabel: {
                        Text("")
                    } maximumValueLabel: {
                        Text("")
                    }
                    .tint(Theme.accentYellow)
                    .onChange(of: settings.accessibilityTextSizeScale) { _, _ in
                        HapticFeedback.selection()
                    }
                    
                    Image(systemName: "textformat.size")
                        .font(.system(size: 26))
                        .foregroundStyle(Theme.accentYellow)
                }
                .padding(.top, 4)

                HStack {
                    Spacer()
                    Text(scaleLevelLabel)
                        .font(Theme.captionFont(scale: settings.accessibilityTextSizeScale))
                        .bold()
                        .foregroundStyle(Theme.accentYellow)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.accentYellow.opacity(0.12))
                        .clipShape(Capsule())
                    Spacer()
                }
            }
            .padding(Theme.cardPadding(scale: settings.accessibilityTextSizeScale))
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius(scale: settings.accessibilityTextSizeScale), style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
        }
        .padding(.horizontal, Theme.cardPadding(scale: settings.accessibilityTextSizeScale))
    }
}
