import SwiftUI

/// Hoja de Ajustes de la aplicación.
/// Permite configurar opciones de accesibilidad visual y personalización de la lista.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0
    @State private var mockItemPurchased = false

    private var scaleLevelLabel: String {
        let percent = Int(accessibilityTextSizeScale * 100)
        switch accessibilityTextSizeScale {
        case 1.0..<1.15:
            return "Normal (\(percent)%)"
        case 1.15..<1.35:
            return "Mediano (\(percent)%)"
        case 1.35..<1.55:
            return "Grande (\(percent)%)"
        default:
            return "Extra Grande (\(percent)%)"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.sectionSpacing(scale: accessibilityTextSizeScale)) {
                    
                    // MARK: - Tarjeta de Vista Previa en Vivo (Live Preview Card)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("VISTA PREVIA EN VIVO")
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.leading, 6)
                            .bold()

                        // Tarjeta simulada de producto
                        HStack(spacing: 14 * CGFloat(accessibilityTextSizeScale)) {
                            
                            // Checkbox de vista previa
                            Button {
                                HapticFeedback.selection()
                                withAnimation(Theme.defaultAnimation) {
                                    mockItemPurchased.toggle()
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .strokeBorder(
                                            mockItemPurchased ? Theme.accentYellow : Color.appTextPurchased,
                                            lineWidth: 2
                                        )

                                    if mockItemPurchased {
                                        Circle()
                                            .fill(Theme.accentYellow)
                                            .transition(.scale.combined(with: .opacity))

                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12 * CGFloat(accessibilityTextSizeScale), weight: .bold))
                                            .foregroundStyle(.white)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .frame(
                                    width: 28 * CGFloat(accessibilityTextSizeScale),
                                    height: 28 * CGFloat(accessibilityTextSizeScale)
                                )
                            }
                            .buttonStyle(.plain)

                            // Contenido del texto
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text("Tomates")
                                        .font(Theme.bodyFont(scale: accessibilityTextSizeScale))
                                        .foregroundStyle(mockItemPurchased ? Color.appTextPurchased : Color.appTextPrimary)
                                        .strikethrough(mockItemPurchased, color: Color.appTextPurchased)
                                        .lineLimit(1)

                                    Text("1 kg")
                                        .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                                        .foregroundStyle(mockItemPurchased ? Color.appTextPurchased : Theme.accentYellow)
                                        .padding(.horizontal, 8 * CGFloat(accessibilityTextSizeScale))
                                        .padding(.vertical, 3 * CGFloat(accessibilityTextSizeScale))
                                        .background(
                                            mockItemPurchased
                                                ? Color.appTextPurchased.opacity(0.1)
                                                : Theme.accentYellow.opacity(0.15)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 10 * CGFloat(accessibilityTextSizeScale)))
                                }

                                Text("Maduros pero firmes")
                                    .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                                    .foregroundStyle(Color.appTextSecondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 12)

                            // Botón de edición simulado en el lado derecho
                            Button {
                                HapticFeedback.impact()
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 13 * CGFloat(accessibilityTextSizeScale), weight: .semibold))
                                    .foregroundStyle(Theme.accentYellow)
                                    .frame(
                                        width: 32 * CGFloat(accessibilityTextSizeScale),
                                        height: 32 * CGFloat(accessibilityTextSizeScale)
                                    )
                                    .background(Theme.accentYellow.opacity(0.12))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 10 * CGFloat(accessibilityTextSizeScale))
                        .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale))
                        .background(Color.appCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius(scale: accessibilityTextSizeScale), style: .continuous))
                        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
                    }
                    .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale))
                    .padding(.top, 10)

                    // MARK: - Panel de Accesibilidad Visual (Slider de escala continua)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ACCESIBILIDAD VISUAL")
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.leading, 6)
                            .bold()

                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tamaño del texto e ítems")
                                    .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                                    .foregroundStyle(Color.appTextPrimary)

                                Text("Ajusta el slider para cambiar el tamaño de letra, tarjetas y encabezados de categorías.")
                                    .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                            
                            HStack(spacing: 12) {
                                Image(systemName: "textformat.size")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.appTextSecondary)
                                
                                Slider(value: $accessibilityTextSizeScale, in: 1.0...1.6, step: 0.05) {
                                    Text("Escala del tamaño de texto")
                                } minimumValueLabel: {
                                    Text("")
                                } maximumValueLabel: {
                                    Text("")
                                }
                                .tint(Theme.accentYellow)
                                .onChange(of: accessibilityTextSizeScale) { _, _ in
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
                                    .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                                    .bold()
                                    .foregroundStyle(Theme.accentYellow)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Theme.accentYellow.opacity(0.12))
                                    .clipShape(Capsule())
                                Spacer()
                            }
                        }
                        .padding(Theme.cardPadding(scale: accessibilityTextSizeScale))
                        .background(Color.appCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius(scale: accessibilityTextSizeScale), style: .continuous))
                        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
                    }
                    .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale))

                    // MARK: - Guía de Gestos Tactiles
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GUÍA DE USO")
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.leading, 6)
                            .bold()

                        VStack(alignment: .leading, spacing: 14 * CGFloat(accessibilityTextSizeScale)) {
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
                        .padding(Theme.cardPadding(scale: accessibilityTextSizeScale))
                        .background(Color.appCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius(scale: accessibilityTextSizeScale), style: .continuous))
                        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
                    }
                    .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale))
                }
                .padding(.vertical, 16)
            }
            .background(Color.appBackground)
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        HapticFeedback.selection()
                        dismiss()
                    }
                    .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(Theme.accentYellow)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func gestoInfoRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22 * CGFloat(accessibilityTextSizeScale)))
                .foregroundStyle(Theme.accentYellow)
                .frame(width: 28 * CGFloat(accessibilityTextSizeScale))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(Color.appTextPrimary)

                Text(description)
                    .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#if DEBUG
#Preview {
    SettingsSheet()
}
#endif
