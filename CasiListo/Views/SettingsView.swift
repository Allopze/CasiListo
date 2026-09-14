import SwiftUI
import SwiftData

/// Pestaña de Ajustes de la aplicación.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showsResetConfirmation = false
    @State private var resetErrorMessage: String?
    @State private var exportFileURL: URL?
    @State private var exportErrorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.sectionSpacing) {
                    SettingsGestureGuideSection()
                    SettingsCategoriesSection()
                    privacyAndSupportSection
                    dataSection
                    dedicationFooter
                }
                .padding(.vertical, 16)
            }
            .background(Color.appBackground)
            .navigationTitle("Ajustes")
            .confirmationDialog(
                "¿Borrar todos tus datos guardados?",
                isPresented: $showsResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Borrar todos mis datos", role: .destructive) { resetAllData() }
                    versionFooter
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Se eliminarán tus listas, historial, categorías personalizadas, catálogo, fotos de boletas y notas de voz de este dispositivo. Esta acción no se puede deshacer.")
            }
            .alert(
                "No se pudieron borrar los datos",
                isPresented: Binding(
                    get: { resetErrorMessage != nil },
                    set: { if !$0 { resetErrorMessage = nil } }
                )
            ) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(resetErrorMessage ?? "Inténtalo nuevamente.")
            }
            .alert(
                "No se pudo exportar",
                isPresented: Binding(
                    get: { exportErrorMessage != nil },
                    set: { if !$0 { exportErrorMessage = nil } }
                )
            ) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(exportErrorMessage ?? "Inténtalo nuevamente.")
            }
        }
    }

    private var privacyAndSupportSection: some View {
        SettingsSection(title: "PRIVACIDAD Y SOPORTE") {
            Link(destination: AppSupportLinks.privacy) {
                SettingsCard {
                    SettingsLinkRow(title: "Política de privacidad", detail: "Cómo se guardan y eliminan tus datos.", symbol: "hand.raised.fill")
                }
            }
            .accessibilityLabel("Abrir política de privacidad")

            Link(destination: AppSupportLinks.support) {
                SettingsCard {
                    SettingsLinkRow(title: "Soporte", detail: "Obtén ayuda con CasiListo.", symbol: "questionmark.circle.fill")
                }
            }
            .accessibilityLabel("Abrir soporte de CasiListo")
        }
    }

    private var dataSection: some View {
        SettingsSection(title: "DATOS LOCALES") {
            // Sin backend, el dispositivo es la única copia. El archivo se
            // genera al tocar, no en cada render de esta pantalla.
            if let exportFileURL {
                ShareLink(item: exportFileURL) {
                    SettingsCard {
                        SettingsLinkRow(title: "Exportar mis datos", detail: "Descarga un respaldo de tus listas, historial y catálogo.", symbol: "square.and.arrow.up")
                    }
                }
                .accessibilityLabel("Exportar mis datos")
            } else {
                Button { exportData() } label: {
                    SettingsCard {
                        SettingsLinkRow(title: "Exportar mis datos", detail: "Descarga un respaldo de tus listas, historial y catálogo.", symbol: "square.and.arrow.up")
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Exportar mis datos")
            }

            Button(role: .destructive) { showsResetConfirmation = true } label: {
                SettingsCard {
                    SettingsLinkRow(title: "Borrar todos mis datos guardados", detail: "Elimina los datos locales de este dispositivo.", symbol: "trash.fill", destructive: true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Borrar todos mis datos guardados")
        }
    }

    private func resetAllData() {
        do {
            try ShoppingPersistenceCoordinator(context: modelContext).resetAllData()
            HapticFeedback.success()
            // Un archivo exportado antes del borrado ya no refleja los datos
            // actuales (ahora vacíos): que la persona vuelva a pedirlo.
            exportFileURL = nil
        } catch {
            resetErrorMessage = error.localizedDescription
        }
    }

    private func exportData() {
        do {
            exportFileURL = try DataExportService.exportFile(context: modelContext)
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private var dedicationFooter: some View {
        Text("Desarrollado por Alejandro López Zelaya para su querido padre, Casimiro López Díaz. Ojalá esta lista te acompañe por siempre.")
            .font(Theme.captionDynamic)
            .foregroundStyle(Color.appTextSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.cardPadding * 2)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }
}

    /// La página de soporte pide la versión al reportar un problema y dice que
    /// está «al final de la pestaña Ajustes»: esta línea es lo que hace cierta
    /// esa instrucción.
    private var versionFooter: some View {
        Text("CasiListo \(Self.marketingVersion) (\(Self.buildNumber))")
            .font(Theme.captionDynamic)
            .foregroundStyle(Color.appTextSecondary)
            .padding(.bottom, 12)
            .accessibilityLabel("Versión de CasiListo \(Self.marketingVersion), compilación \(Self.buildNumber)")
    }

    private static var marketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
