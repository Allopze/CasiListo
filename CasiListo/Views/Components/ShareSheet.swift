import SwiftUI
import UIKit

/// Archivo temporal listo para compartir. `URL` no es `Identifiable`, y
/// `.sheet(item:)` sí lo exige.
struct SharedFile: Identifiable {
    let id = UUID()
    let url: URL
}

/// Envoltorio mínimo de `UIActivityViewController`.
///
/// `ShareLink` evalúa su contenido en cada render, no al tocarlo: con un
/// volcado caro (el respaldo JSON, el CSV del historial) eso obligaba a
/// cachearlo, y el caché se quedaba viejo en silencio — Ajustes compartía para
/// siempre el primer respaldo de la sesión (CASI-002), e Historial el primer
/// CSV (CASI-005). Esto genera el archivo recién al tocar y lo presenta.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
