import SwiftUI

/// Hoja de Ajustes de la aplicación.
/// Permite configurar opciones de accesibilidad visual y personalización de la lista.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0
    @State private var mockItemPurchased = false

    // Presupuesto
    @AppStorage(BudgetConfig.isEnabledKey) private var isBudgetEnabled = true
    @AppStorage(BudgetConfig.totalKey) private var totalBudget = BudgetConfig.defaultTotal
    @AppStorage(BudgetConfig.jumboKey) private var jumboBudget = BudgetConfig.defaultJumbo
    @AppStorage(BudgetConfig.liderKey) private var liderBudget = BudgetConfig.defaultLider
    @AppStorage(BudgetConfig.warningThresholdKey) private var warningThreshold = BudgetConfig.defaultWarningThreshold

    // Localización
    @AppStorage("geofencing_enabled") private var isGeofencingEnabled = false

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
                        .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius(scale: accessibilityTextSizeScale), style: .continuous))
                        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
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

                    // MARK: - Panel de Presupuesto (Budget Card)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("PRESUPUESTO INTELIGENTE")
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.leading, 6)
                            .bold()

                        VStack(alignment: .leading, spacing: 16 * CGFloat(accessibilityTextSizeScale)) {
                            Toggle(isOn: $isBudgetEnabled) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Habilitar presupuestos")
                                        .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                                        .foregroundStyle(Color.appTextPrimary)
                                    Text("Muestra el costo acumulado contra el límite establecido.")
                                        .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                                        .foregroundStyle(Color.appTextSecondary)
                                }
                            }
                            .tint(Theme.accentYellow)
                            .onChange(of: isBudgetEnabled) { _, _ in
                                HapticFeedback.selection()
                            }
                            
                            if isBudgetEnabled {
                                Divider().background(Color.white.opacity(0.1))
                                
                                budgetFieldRow(title: "Presupuesto General", value: $totalBudget)
                                budgetFieldRow(title: "Presupuesto Jumbo", value: $jumboBudget)
                                budgetFieldRow(title: "Presupuesto Líder", value: $liderBudget)
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Alerta al alcanzar")
                                            .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                                            .foregroundStyle(Color.appTextPrimary)
                                        Spacer()
                                        Text("\(Int(warningThreshold * 100))%")
                                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                                            .bold()
                                            .foregroundStyle(Theme.accentYellow)
                                    }
                                    
                                    Slider(value: $warningThreshold, in: 0.5...0.95, step: 0.05)
                                        .tint(Theme.accentYellow)
                                        .onChange(of: warningThreshold) { _, _ in
                                            HapticFeedback.selection()
                                        }
                                }
                            }
                        }
                        .padding(Theme.cardPadding(scale: accessibilityTextSizeScale))
                        .background(Color.appCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius(scale: accessibilityTextSizeScale), style: .continuous))
                        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
                    }
                    .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale))

                    // MARK: - Panel de Localización (Location Card)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("RECORDATORIOS GEOLOCALIZADOS")
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.leading, 6)
                            .bold()

                        VStack(alignment: .leading, spacing: 16) {
                            Toggle(isOn: $isGeofencingEnabled) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Alertas al pasar cerca")
                                        .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                                        .foregroundStyle(Color.appTextPrimary)
                                    Text("Te notifica cuando pasas cerca de Jumbo o Líder si tienes compras pendientes.")
                                        .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                                        .foregroundStyle(Color.appTextSecondary)
                                }
                            }
                            .tint(Theme.accentYellow)
                            .onChange(of: isGeofencingEnabled) { _, newValue in
                                HapticFeedback.selection()
                                if newValue {
                                    GeofenceService.shared.requestPermissions()
                                } else {
                                    GeofenceService.shared.stopMonitoringAll()
                                }
                            }
                        }
                        .padding(Theme.cardPadding(scale: accessibilityTextSizeScale))
                        .background(Color.appCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius(scale: accessibilityTextSizeScale), style: .continuous))
                        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
                    }
                    .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale))

                    // MARK: - Panel de Gamificación (Achievements Card)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("MIS LOGROS")
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.leading, 6)
                            .bold()

                        NavigationLink {
                            AchievementsView()
                        } label: {
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Theme.accentYellow)
                                    .frame(width: 32, height: 32)
                                    .background(Theme.accentYellow.opacity(0.15))
                                    .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Ver Medallas y Rachas")
                                        .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                                        .foregroundStyle(Color.appTextPrimary)
                                    Text("Consulta tus estadísticas y logros de compras completadas.")
                                        .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                                        .foregroundStyle(Color.appTextSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                        }
                        .buttonStyle(.plain)
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

    @ViewBuilder
    private func budgetFieldRow(title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
                .font(Theme.bodyFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.appTextPrimary)
            
            Spacer()
            
            TextField("$0", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Theme.accentYellow)
                .frame(width: 120)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

#if DEBUG
#Preview {
    SettingsSheet()
}
#endif
