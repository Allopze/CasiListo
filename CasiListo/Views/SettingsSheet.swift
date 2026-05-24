import SwiftUI
import CoreLocation

/// Hoja de Ajustes de la aplicación.
/// Permite configurar opciones de accesibilidad visual y personalización de la lista.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0
    @State private var mockItemPurchased = false
    @State private var showsLocationDeniedAlert = false

    // Localización
    @AppStorage("geofencing_enabled") private var isGeofencingEnabled = false
    @State private var showsLocationOnboarding = false

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
                                        .clipShape(Capsule())
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
                                        width: max(Theme.minimumTouchTarget, 32 * CGFloat(accessibilityTextSizeScale)),
                                        height: max(Theme.minimumTouchTarget, 32 * CGFloat(accessibilityTextSizeScale))
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



                    // MARK: - Panel de Localización (Location Card)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("RECORDATORIOS GEOLOCALIZADOS")
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.leading, 6)
                            .bold()

                        VStack(alignment: .leading, spacing: 16) {
                            let status = GeofenceService.shared.authorizationStatus
                            if status == .denied || status == .restricted {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.red)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Ubicación Desactivada")
                                            .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                                            .foregroundStyle(Color.appTextPrimary)
                                        Text("Has denegado el acceso a la ubicación. Ve a Ajustes para activarlo.")
                                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                                            .foregroundStyle(Color.appTextSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button("Ajustes") {
                                        if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                    .font(Theme.captionFont(scale: accessibilityTextSizeScale).bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.red.opacity(0.15))
                                    .foregroundStyle(.red)
                                    .clipShape(Capsule())
                                }
                                .padding(.bottom, 8)
                                
                                Divider()
                            }

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
                                    let currentStatus = GeofenceService.shared.authorizationStatus
                                    if currentStatus == .denied || currentStatus == .restricted {
                                        showsLocationDeniedAlert = true
                                        isGeofencingEnabled = false
                                    } else {
                                        showsLocationOnboarding = true
                                    }
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

                    // MARK: - Panel de Categorías (Categories Card)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("CATEGORÍAS")
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.leading, 6)
                            .bold()

                        NavigationLink {
                            CategoryManagementView()
                        } label: {
                            HStack {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Theme.accentYellow)
                                    .frame(width: 32, height: 32)
                                    .background(Theme.accentYellow.opacity(0.15))
                                    .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Administrar Categorías")
                                        .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                                        .foregroundStyle(Color.appTextPrimary)
                                    Text("Crea, edita, ordena o elimina las categorías de tus productos.")
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

                    dedicationFooter
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
        .sheet(isPresented: $showsLocationOnboarding, onDismiss: {
            if !isGeofencingEnabled {
                GeofenceService.shared.stopMonitoringAll()
            }
        }) {
            LocationPermissionOnboardingView {
                isGeofencingEnabled = true
                GeofenceService.shared.startMonitoringAll()
            }
        }
        .alert("Permiso de Ubicación Necesario", isPresented: $showsLocationDeniedAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Ir a Ajustes") {
                if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Para recibir recordatorios cuando pases cerca de un supermercado, debes activar el acceso a la ubicación en los ajustes del dispositivo.")
        }
    }

    private var dedicationFooter: some View {
        Text("Desarrollado por Alejandro López Zelaya para su querido padre, Casimiro López Díaz. Ojalá esta lista te acompañe por siempre.")
            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
            .foregroundStyle(Color.appTextSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale) * 2)
            .padding(.top, 4)
            .padding(.bottom, 8)
            .accessibilityLabel("Desarrollado por Alejandro López Zelaya para su querido padre, Casimiro López Díaz. Ojalá esta lista te acompañe por siempre.")
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
