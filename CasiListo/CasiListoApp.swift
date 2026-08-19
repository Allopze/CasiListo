import SwiftUI
import SwiftData

/// Punto de entrada de la app CasiListo.
@main
struct CasiListoApp: App {
    @State private var voiceNoteService = VoiceNoteService.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(voiceNoteService)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        // Guardar cambios pendientes antes de que el sistema pueda terminar la app.
                        try? modelContext.save()
                        voiceNoteService.stopPlaying()
                    }
                }
        }
        .modelContainer(CasiListoModelContainer.make())
    }
}
