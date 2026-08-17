import SwiftUI

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

    /// Mismo token verificado que el resto de textos e íconos de acento: el
    /// amarillo de marca no contrasta sobre fondos claros.
    private let tabTint = Theme.accentInteractive

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
    }
}
