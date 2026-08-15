import SwiftUI
import SwiftData

/// Punto de entrada de la app CasiListo.
@main
struct CasiListoApp: App {
    @State private var voiceNoteService = VoiceNoteService.shared
    @State private var appSettings = AppSettings()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(voiceNoteService)
                .environment(appSettings)
        }
        .modelContainer(CasiListoModelContainer.make())
    }
}
