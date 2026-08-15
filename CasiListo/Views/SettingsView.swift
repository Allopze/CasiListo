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
        VStack(alignment: .leading, spacing: 10) {
            Text("PRIVACIDAD Y SOPORTE")
                .font(Theme.captionDynamic)
                .foregroundStyle(Color.appTextSecondary)
                .padding(.leading, 6)
                .bold()

            Link(destination: AppSupportLinks.privacy) {
                settingsLinkRow(title: "Política de privacidad", detail: "Cómo se guardan y eliminan tus datos.", symbol: "hand.raised.fill")
            }
            .accessibilityLabel("Abrir política de privacidad")

            Link(destination: AppSupportLinks.support) {
                settingsLinkRow(title: "Soporte", detail: "Obtén ayuda con CasiListo.", symbol: "questionmark.circle.fill")
            }
            .accessibilityLabel("Abrir soporte de CasiListo")
        }
        .padding(.horizontal, Theme.cardPadding)
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DATOS LOCALES")
                .font(Theme.captionDynamic)
                .foregroundStyle(Color.appTextSecondary)
                .padding(.leading, 6)
                .bold()
            Button(role: .destructive) { showsResetConfirmation = true } label: {
                settingsLinkRow(title: "Borrar todos mis datos guardados", detail: "Elimina los datos locales de este dispositivo.", symbol: "trash.fill", destructive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Borrar todos mis datos guardados")
        }
        .padding(.horizontal, Theme.cardPadding)
    }

    private func settingsLinkRow(title: String, detail: String, symbol: String, destructive: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(destructive ? Color.red : Theme.accentYellow)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.bodyBoldDynamic)
                Text(detail).font(Theme.captionDynamic).foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(Color.appTextSecondary)
        }
        .foregroundStyle(destructive ? Color.red : Color.appTextPrimary)
        .padding(Theme.cardPadding)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
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
