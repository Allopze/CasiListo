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

    /// Ámbar oscurecido para la selección del tab bar en modo claro
    /// (el amarillo de marca no contrasta sobre fondos claros); en oscuro
    /// el amarillo de marca funciona.
    private let tabTint = Color(light: UIColor(hex: "9A7B00"), dark: UIColor(hex: "F5C518"))

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
        // Solo para verificación visual automatizada.
        .preferredColorScheme(
            ProcessInfo.processInfo.arguments.contains("-ui-testing-dark") ? .dark : nil
        )
        .onOpenURL { url in
            // La lista es el único destino público; rutas desconocidas no
            // modifican el estado ni presentan contenido inesperado.
            guard let route = AppRoute(url: url), route == .list else { return }
            selection = .compra
        }
    }
}
