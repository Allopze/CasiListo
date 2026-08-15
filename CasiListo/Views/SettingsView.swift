import SwiftUI
import SwiftData

/// Pestaña de Ajustes de la aplicación.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showsResetConfirmation = false
    @State private var resetErrorMessage: String?

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
        } catch {
            resetErrorMessage = error.localizedDescription
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
