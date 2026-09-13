import SwiftUI
import SwiftData

/// Punto de entrada de la app CasiListo.
@main
struct CasiListoApp: App {
    @State private var voiceNoteService = VoiceNoteService.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(voiceNoteService)
        }
        .modelContainer(CasiListoModelContainer.make())
    }
}
