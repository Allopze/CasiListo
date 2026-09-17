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
    @State private var isExporting = false

    // MARK: - Import de respaldo
    @State private var isImportPickerPresented = false
    @State private var pendingImport: (data: Data, outcome: DataExportService.ImportOutcome)?
    @State private var importResultMessage: String?
    @State private var importErrorMessage: String?
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            settingsListContent
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
                Text("Se eliminarán tus listas, historial, categorías personalizadas, catálogo, fotos de boletas y notas de voz "
                    + "de este dispositivo. Esta acción no se puede deshacer.")
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

    var settingsSections: some View {
        VStack(spacing: Theme.sectionSpacing) {
            SettingsCategoriesSection()
            privacyAndSupportSection
            dataSection
            SettingsGestureGuideSection()
            dedicationFooter
            versionFooter
        }
    }

    var settingsListContent: some View {
        ScrollView {
            settingsSections
                .padding(.vertical, 16)
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
            if isExporting || isImporting {
                ProgressView(isExporting ? "Preparando el respaldo…" : "Leyendo el respaldo…")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(isExporting ? "Preparando el respaldo" : "Leyendo el respaldo")
            }

            // Sin backend, el dispositivo es la única copia. El archivo se
            // genera en cada toque: cachearlo dejaba compartiendo para siempre
            // la foto de los datos tal como estaban en la primera exportación
            // de la sesión (CASI-002).
            Button { exportData() } label: {
                SettingsCard {
                    SettingsLinkRow(
                        title: "Exportar mis datos",
                        detail: "JSON de listas, productos, categorías y catálogo; CSV del historial. "
                            + "Fotos y notas de voz no se incluyen y dependen del respaldo del dispositivo.",
                        symbol: "square.and.arrow.up"
                    )
                }
            }
            .buttonStyle(.plain)
            .disabled(isExporting || isImporting)
            .accessibilityLabel("Exportar mis datos")
            .accessibilityIdentifier("settings-export-data")

            Button { isImportPickerPresented = true } label: {
                SettingsCard {
                    SettingsLinkRow(
                        title: "Restaurar desde un respaldo",
                        detail: "Añade listas, productos, categorías y catálogo desde un JSON exportado.",
                        symbol: "square.and.arrow.down"
                    )
                }
            }
            .buttonStyle(.plain)
            .disabled(isExporting || isImporting)
            .accessibilityLabel("Restaurar desde un respaldo")
            .accessibilityIdentifier("settings-import-data")

            Button(role: .destructive) { showsResetConfirmation = true } label: {
                SettingsCard {
                    SettingsLinkRow(
                        title: "Borrar todos mis datos guardados",
                        detail: "Elimina los datos locales de este dispositivo.",
                        symbol: "trash.fill",
                        destructive: true
                    )
                }
            }
            .buttonStyle(.plain)
            .disabled(isExporting || isImporting)
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
        guard !isExporting, !isImporting else { return }
        isExporting = true
        Task {
            defer { isExporting = false }
            do {
                let url = try await DataExportService.exportFileAsync(context: modelContext)
                fileToShare = SharedFile(url: url)
            } catch {
                exportErrorMessage = error.localizedDescription
            }
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
            guard !isExporting, !isImporting else { return }
            let isScoped = url.startAccessingSecurityScopedResource()
            isImporting = true
            Task {
                defer {
                    if isScoped { url.stopAccessingSecurityScopedResource() }
                    isImporting = false
                }
                do {
                    let data = try await Task.detached(priority: .utility) {
                        try Data(contentsOf: url)
                    }.value
                    let outcome = try await DataExportService.planImportAsync(data: data, context: modelContext)
                    pendingImport = (data, outcome)
                } catch {
                    importErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func runImport(_ data: Data) {
        pendingImport = nil
        // La confirmación solo aparece después de terminar la preparación del
        // archivo; no se vuelve a bloquear por el flag de lectura si SwiftUI
        // aún no alcanzó a dibujar ese último cambio de estado.
        guard !isExporting else { return }
        isImporting = true
        Task {
            defer { isImporting = false }
            do {
                let outcome = try await DataExportService.importAllAsync(data: data, context: modelContext)
                HapticFeedback.success()
                // Un archivo exportado antes de importar ya no refleja los datos
                // actuales: que la persona vuelva a pedirlo si lo necesita.
                fileToShare = nil
                importResultMessage = resultMessage(for: outcome)
            } catch {
                importErrorMessage = error.localizedDescription
            }
        }
    }

    private func confirmationMessage(for outcome: DataExportService.ImportOutcome) -> String {
        guard !outcome.addsNothing else {
            return "Este respaldo ya está completo en este dispositivo. No hay nada que añadir."
        }
        let categories = SpanishPluralization.count(outcome.newCategories, singular: "categoría")
        let lists = SpanishPluralization.count(outcome.newLists, singular: "lista")
        let items = SpanishPluralization.count(outcome.newItems, singular: "producto")
        let catalogItems = SpanishPluralization.count(outcome.newCatalogItems, singular: "producto de catálogo", plural: "productos de catálogo")
        var parts = ["Se añadirán \(categories), \(lists), \(items) y \(catalogItems) al dispositivo."]
        parts.append("No se borrará ni se reemplazará nada de lo que ya tienes: lo que coincida se conservará como está.")
        parts.append("Las fotos de boletas y las notas de voz no viajan en el respaldo.")
        return parts.joined(separator: "\n\n")
    }

    private func resultMessage(for outcome: DataExportService.ImportOutcome) -> String {
        let categories = SpanishPluralization.count(outcome.newCategories, singular: "categoría")
        let lists = SpanishPluralization.count(outcome.newLists, singular: "lista")
        let items = SpanishPluralization.count(outcome.newItems, singular: "producto")
        let catalogItems = SpanishPluralization.count(outcome.newCatalogItems, singular: "producto de catálogo", plural: "productos de catálogo")
        var parts = ["Se añadieron \(categories), \(lists), \(items) y \(catalogItems)."]
        if outcome.skippedItems > 0 || outcome.skippedLists > 0 {
            let skippedLists = SpanishPluralization.count(outcome.skippedLists, singular: "lista")
            let skippedItems = SpanishPluralization.count(outcome.skippedItems, singular: "producto")
            parts.append("Se omitieron \(skippedLists) y \(skippedItems) que ya tenías.")
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
