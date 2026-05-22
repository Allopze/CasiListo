import SwiftUI
import SwiftData

/// Punto de entrada de la app CasiListo.
@main
struct CasiListoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: ShoppingItem.self)
    }
}
