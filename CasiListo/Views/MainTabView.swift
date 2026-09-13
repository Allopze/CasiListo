import SwiftData
import SwiftUI
import UIKit

/// Pestañas raíz de la app.
enum AppTab: Hashable {
    case compra
    case catalogo
    case historial
    case ajustes
}

/// Raíz de navegación: Compra · Catálogo · Historial · Ajustes.
struct MainTabView: View {
    @State private var selection: AppTab = .compra
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(VoiceNoteService.self) private var voiceNoteService

    /// Mismo token verificado que el resto de textos e íconos de acento: el
    /// amarillo de marca no contrasta sobre fondos claros.
    private let tabTint = Theme.accentInteractive

    private func persistenceBanner(title: String, message: String, identifier: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(light: UIColor(hex: "BA2115"), dark: UIColor(hex: "FF8078")))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.bodyBoldDynamic)
                    .foregroundStyle(Color.appTextPrimary)
                Text(message)
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.cardPadding)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.appCardBackground)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private var uiTestingColorScheme: ColorScheme? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-testing-dark") { return .dark }
        if arguments.contains("-ui-testing-light") { return .light }
        return nil
    }

    var body: some View {
        TabView(selection: $selection) {
            ContentView(onShowHistory: { selection = .historial })
                .tabItem { Label("Compra", systemImage: "cart.fill") }
                .tag(AppTab.compra)

            CatalogView()
                .tabItem { Label("Catálogo", systemImage: "books.vertical.fill") }
                .tag(AppTab.catalogo)

            ShoppingHistoryView()
                .tabItem { Label("Historial", systemImage: "clock.arrow.circlepath") }
                .tag(AppTab.historial)

            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "gearshape.fill") }
                .tag(AppTab.ajustes)
        }
        .tint(tabTint)
        // Si el store no abrió, la sesión corre en memoria y todo se pierde al
        // cerrar. La bandera existía desde el principio y nadie la leía: la
        // persona usaba la app un día entero creyendo que guardaba.
        //
        // El aviso de store no encontrado manda sobre el de memoria: lo
        // urgente es que la persona sepa que esto no es su lista antes de
        // seguir usándola, no que se enteren de que no se guardará nada nuevo.
        .safeAreaInset(edge: .top, spacing: 0) {
            if CasiListoModelContainer.didDetectMissingStore {
                persistenceBanner(
                    title: "No encontramos tus datos guardados",
                    message: "La app arrancó vacía, pero ya la habías usado. No borres ni reinstales: escríbenos antes de seguir.",
                    identifier: "persistence-missing-store-banner"
                )
            } else if CasiListoModelContainer.isUsingInMemoryFallback {
                persistenceBanner(
                    title: "CasiListo no puede guardar en este dispositivo",
                    message: "Tus cambios se perderán al cerrar la app.",
                    identifier: "persistence-warning-banner"
                )
            }
        }
        // Solo para verificación visual automatizada. La apariencia se fuerza en
        // ambos sentidos: sin "-ui-testing-light" la app seguiría al simulador,
        // que conserva el modo de la corrida anterior y arruina la comparación.
        .preferredColorScheme(uiTestingColorScheme)
        .onOpenURL { url in
            // La lista es el único destino público; rutas desconocidas no
            // modifican el estado ni presentan contenido inesperado.
            guard let route = AppRoute(url: url), route == .list else { return }
            selection = .compra
        }
        // Vivía en CasiListoApp, pero `.modelContainer(...)` se aplica sobre
        // la `WindowGroup`, no sobre el `App` en sí: el `@Environment` que se
        // leía ahí no era garantizado el mismo que el de esta jerarquía. Aquí
        // sí lo es. Toda mutación real ya hace commit síncrono vía el
        // coordinador, así que esto es una red de seguridad, no la única vía
        // de guardado.
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                try? modelContext.save()
                voiceNoteService.stopPlaying()
            case .active:
                applyPendingWidgetPurchases()
            default:
                break
            }
        }
        // El primer `.active` puede llegar antes de que esta vista exista:
        // se drena también al aparecer para no perder lo marcado con la app
        // cerrada del todo.
        .task { applyPendingWidgetPurchases() }
    }

    /// Lo que se marcó desde el widget mientras la app no estaba. Un fallo
    /// aquí no se muestra: la persona no hizo nada en esta pantalla que
    /// explicar, y el widget ya refleja el cambio de forma optimista.
    private func applyPendingWidgetPurchases() {
        try? ShoppingPersistenceCoordinator(context: modelContext).applyPendingWidgetPurchases()
    }
}
