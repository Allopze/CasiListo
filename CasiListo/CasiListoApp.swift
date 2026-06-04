import SwiftUI
import SwiftData

/// Punto de entrada de la app CasiListo.
@main
struct CasiListoApp: App {
    @State private var geofenceService = GeofenceService.shared
    @State private var voiceNoteService = VoiceNoteService.shared
    @State private var appSettings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(geofenceService)
                .environment(voiceNoteService)
                .environment(appSettings)
        }
        .modelContainer(
            for: [ShoppingItem.self, ShoppingList.self, ProductCatalogItem.self, Category.self],
            isUndoEnabled: true
        )
    }
}
