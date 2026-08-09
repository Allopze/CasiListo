import SwiftUI

struct SettingsGeofencingSection: View {
    @Binding var isGeofencingEnabled: Bool
    @Binding var showsLocationDeniedAlert: Bool
    @Binding var showsLocationOnboarding: Bool
    let geofenceService: GeofenceService
    let accessibilityTextSizeScale: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("RECORDATORIOS GEOLOCALIZADOS")
                .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.appTextSecondary)
                .padding(.leading, 6)
                .bold()

            VStack(alignment: .leading, spacing: 16) {
                let status = geofenceService.authorizationStatus
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
                        let currentStatus = geofenceService.authorizationStatus
                        if currentStatus == .denied || currentStatus == .restricted {
                            showsLocationDeniedAlert = true
                            isGeofencingEnabled = false
                        } else {
                            showsLocationOnboarding = true
                        }
                    } else {
                        geofenceService.stopMonitoringAll()
                    }
                }
            }
            .padding(Theme.cardPadding(scale: accessibilityTextSizeScale))
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius(scale: accessibilityTextSizeScale), style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
        }
        .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale))
    }
}
