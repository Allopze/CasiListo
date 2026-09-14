import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Pestaña de Ajustes de la aplicación.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showsResetConfirmation = false
    @State private var resetErrorMessage: String?
    /// No es un caché: solo vive mientras el share sheet está presentado. Antes
    /// era `exportFileURL: URL?` y sobrevivía a toda la sesión — la primera
    /// exportación quedaba congelada y las siguientes compartían el mismo
    /// archivo viejo en silencio (CASI-002).
    @State private var fileToShare: SharedFile?
    @State private var exportErrorMessage: String?

    // MARK: - Import de respaldo
    @State private var isImportPickerPresented = false
    @State private var pendingImport: (data: Data, outcome: DataExportService.ImportOutcome)?
    @State private var importResultMessage: String?
    @State private var importErrorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.sectionSpacing) {
                    SettingsGestureGuideSection()
                    SettingsCategoriesSection()
                    privacyAndSupportSection
                    dataSection
                    dedicationFooter
                    versionFooter
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
            .sheet(item: $fileToShare) { ShareSheet(url: $0.url) }
            .fileImporter(isPresented: $isImportPickerPresented, allowedContentTypes: [.json]) { result in
                handlePickedImportFile(result)
            }
            .confirmationDialog(
                "¿Restaurar este respaldo?",
                isPresented: Binding(
                    get: { pendingImport != nil },
                    set: { if !$0 { pendingImport = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingImport
            ) { pending in
                if pending.outcome.addsNothing {
                    Button("Entendido", role: .cancel) { pendingImport = nil }
                } else {
                    Button("Añadir a mis datos") { runImport(pending.data) }
                    Button("Cancelar", role: .cancel) { pendingImport = nil }
                }
            } message: { pending in
                Text(confirmationMessage(for: pending.outcome))
            }
            .alert(
                "Respaldo restaurado",
                isPresented: Binding(
                    get: { importResultMessage != nil },
                    set: { if !$0 { importResultMessage = nil } }
                )
            ) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(importResultMessage ?? "")
            }
            .alert(
                "No se pudo restaurar el respaldo",
                isPresented: Binding(
                    get: { importErrorMessage != nil },
                    set: { if !$0 { importErrorMessage = nil } }
                )
            ) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(importErrorMessage ?? "Inténtalo nuevamente.")
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
            // genera en cada toque: cachearlo dejaba compartiendo para siempre
            // la foto de los datos tal como estaban en la primera exportación
            // de la sesión (CASI-002).
            Button { exportData() } label: {
                SettingsCard {
                    SettingsLinkRow(title: "Exportar mis datos", detail: "Descarga un respaldo de tus listas, historial y catálogo.", symbol: "square.and.arrow.up")
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Exportar mis datos")
            .accessibilityIdentifier("settings-export-data")

            Button { isImportPickerPresented = true } label: {
                SettingsCard {
                    SettingsLinkRow(title: "Restaurar desde un respaldo", detail: "Añade a este dispositivo las listas, el historial y el catálogo de un archivo exportado.", symbol: "square.and.arrow.down")
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Restaurar desde un respaldo")
            .accessibilityIdentifier("settings-import-data")

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

    private func exportData() {
        do {
            fileToShare = SharedFile(url: try DataExportService.exportFile(context: modelContext))
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func handlePickedImportFile(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            importErrorMessage = error.localizedDescription
        case .success(let url):
            // El archivo puede venir de fuera del sandbox (Archivos, iCloud
            // Drive): sin el recurso con ámbito de seguridad, `Data(contentsOf:)`
            // falla por permisos.
            let isScoped = url.startAccessingSecurityScopedResource()
            defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let outcome = try DataExportService.planImport(data: data, context: modelContext)
                pendingImport = (data, outcome)
            } catch {
                importErrorMessage = error.localizedDescription
            }
        }
    }

    private func runImport(_ data: Data) {
        do {
            let outcome = try DataExportService.importAll(data: data, context: modelContext)
            HapticFeedback.success()
            // Un archivo exportado antes de importar ya no refleja los datos
            // actuales: que la persona vuelva a pedirlo si lo necesita.
            fileToShare = nil
            importResultMessage = resultMessage(for: outcome)
        } catch {
            importErrorMessage = error.localizedDescription
        }
        pendingImport = nil
    }

    private func confirmationMessage(for outcome: DataExportService.ImportOutcome) -> String {
        guard !outcome.addsNothing else {
            return "Este respaldo ya está completo en este dispositivo. No hay nada que añadir."
        }
        var parts = ["Se añadirán \(outcome.newLists) lista(s), \(outcome.newItems) producto(s) y \(outcome.newCatalogItems) producto(s) al catálogo."]
        parts.append("No se borrará ni se reemplazará nada de lo que ya tienes: lo que coincida se conservará como está.")
        parts.append("Las fotos de boletas y las notas de voz no viajan en el respaldo.")
        return parts.joined(separator: "\n\n")
    }

    private func resultMessage(for outcome: DataExportService.ImportOutcome) -> String {
        var parts = ["Se añadieron \(outcome.newLists) lista(s) y \(outcome.newItems) producto(s)."]
        if outcome.skippedItems > 0 || outcome.skippedLists > 0 {
            parts.append("Se omitieron \(outcome.skippedLists) lista(s) y \(outcome.skippedItems) producto(s) que ya tenías.")
        }
        return parts.joined(separator: " ")
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
}
