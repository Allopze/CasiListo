import SwiftUI
import SwiftData

/// Hoja de Ajustes de la aplicación.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var appSettings
    @State private var mockItemPurchased = false
    @State private var showsResetConfirmation = false
    @State private var resetErrorMessage: String?

    private var accessibilityTextSizeScale: Double { appSettings.accessibilityTextSizeScale }

    private var scaleLevelLabel: String {
        let percent = Int(accessibilityTextSizeScale * 100)
        switch accessibilityTextSizeScale {
        case 1.0..<1.15: return "Normal (\(percent)%)"
        case 1.15..<1.35: return "Mediano (\(percent)%)"
        case 1.35..<1.55: return "Grande (\(percent)%)"
        default: return "Extra Grande (\(percent)%)"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.sectionSpacing(scale: accessibilityTextSizeScale)) {
                    SettingsPreviewCard(mockItemPurchased: $mockItemPurchased, accessibilityTextSizeScale: accessibilityTextSizeScale)
                    SettingsAccessibilitySection(settings: appSettings, scaleLevelLabel: scaleLevelLabel)
                    SettingsGestureGuideSection(accessibilityTextSizeScale: accessibilityTextSizeScale)
                    SettingsCategoriesSection(accessibilityTextSizeScale: accessibilityTextSizeScale)
                    SettingsAchievementsSection(accessibilityTextSizeScale: accessibilityTextSizeScale)
                    privacyAndSupportSection
                    dataSection
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var privacyAndSupportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PRIVACIDAD Y SOPORTE")
                .font(Theme.captionFont(scale: accessibilityTextSizeScale))
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
        .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale))
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DATOS LOCALES")
                .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.appTextSecondary)
                .padding(.leading, 6)
                .bold()
            Button(role: .destructive) { showsResetConfirmation = true } label: {
                settingsLinkRow(title: "Borrar todos mis datos guardados", detail: "Elimina los datos locales de este dispositivo.", symbol: "trash.fill", destructive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Borrar todos mis datos guardados")
        }
        .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale))
    }

    private func settingsLinkRow(title: String, detail: String, symbol: String, destructive: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(destructive ? Color.red : Theme.accentYellow)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                Text(detail).font(Theme.captionFont(scale: accessibilityTextSizeScale)).foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(Color.appTextSecondary)
        }
        .foregroundStyle(destructive ? Color.red : Color.appTextPrimary)
        .padding(Theme.cardPadding(scale: accessibilityTextSizeScale))
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius(scale: accessibilityTextSizeScale), style: .continuous))
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
            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
            .foregroundStyle(Color.appTextSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale) * 2)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }
}
