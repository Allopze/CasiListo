import SwiftUI
import CoreLocation

/// Hoja de Ajustes de la aplicación.
/// Permite configurar opciones de accesibilidad visual y personalización de la lista.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(GeofenceService.self) private var geofenceService
    @Environment(AppSettings.self) private var appSettings
    private var accessibilityTextSizeScale: Double {
        appSettings.accessibilityTextSizeScale
    }
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
                    // MARK: - Live Preview Card
                    SettingsPreviewCard(mockItemPurchased: $mockItemPurchased, accessibilityTextSizeScale: accessibilityTextSizeScale)
                    
                    // MARK: - Visual Accessibility Panel
                    SettingsAccessibilitySection(settings: appSettings, scaleLevelLabel: scaleLevelLabel)

                    // MARK: - Gesture Guide
                    SettingsGestureGuideSection(accessibilityTextSizeScale: accessibilityTextSizeScale)

                    // MARK: - Geofencing Location Panel
                    SettingsGeofencingSection(
                        isGeofencingEnabled: $isGeofencingEnabled,
                        showsLocationDeniedAlert: $showsLocationDeniedAlert,
                        showsLocationOnboarding: $showsLocationOnboarding,
                        geofenceService: geofenceService,
                        accessibilityTextSizeScale: accessibilityTextSizeScale
                    )

                    // MARK: - Categories Panel
                    SettingsCategoriesSection(accessibilityTextSizeScale: accessibilityTextSizeScale)

                    // MARK: - Achievements Panel
                    SettingsAchievementsSection(accessibilityTextSizeScale: accessibilityTextSizeScale)

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
                geofenceService.stopMonitoringAll()
            }
        }) {
            LocationPermissionOnboardingView {
                isGeofencingEnabled = true
                geofenceService.startMonitoringAll()
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
}
