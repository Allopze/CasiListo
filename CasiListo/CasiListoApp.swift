import SwiftUI
import SwiftData

/// Punto de entrada de la app CasiListo.
@main
struct CasiListoApp: App {
    @State private var voiceNoteService = VoiceNoteService.shared
    @State private var appSettings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(voiceNoteService)
                .environment(appSettings)
                .onOpenURL { url in
                    // La lista es la raíz de la app; las rutas desconocidas no
                    // modifican el estado ni presentan contenido inesperado.
                    guard let route = AppRoute(url: url), route == .list else { return }
                }
        }
        .modelContainer(CasiListoModelContainer.make())
    }
}
