import Foundation
import SwiftUI

/// Supermercados donde se realizan las compras.
enum Store: String, CaseIterable, Codable, Identifiable {
    case jumbo = "Jumbo"
    case lider = "Líder"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var sfSymbol: String {
        switch self {
        case .jumbo: return "cart.fill"
        case .lider: return "basket.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .jumbo: return Color(red: 0.0, green: 0.6, blue: 0.2)   // Verde Jumbo
        case .lider: return Color(red: 0.0, green: 0.35, blue: 0.75) // Azul Lider
        }
    }

    /// Color de texto accesible sobre fondos claros/oscuros (≥4.5:1 WCAG AA).
    /// Para etiquetas de tienda con fondo tintado suave.
    var labelColor: Color {
        switch self {
        case .jumbo: return Color(light: UIColor(hex: "1B6E33"), dark: UIColor(hex: "6FD08C"))
        case .lider: return Color(light: UIColor(hex: "0A4FA0"), dark: UIColor(hex: "7AB4F5"))
        }
    }

    /// Relleno oscurecido para chips seleccionados con texto blanco (≥4.5:1).
    var selectedFillColor: Color {
        switch self {
        case .jumbo: return Color(hex: "1F7A38")
        case .lider: return Color(hex: "0B5299")
        }
    }
}
