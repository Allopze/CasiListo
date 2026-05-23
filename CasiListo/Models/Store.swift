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
    
    // Coordenadas geográficas para recordatorios geolocalizados (Los Ángeles, Chile)
    var latitude: Double {
        switch self {
        case .jumbo: return -37.4628
        case .lider: return -37.44626
        }
    }
    
    var longitude: Double {
        switch self {
        case .jumbo: return -72.3559
        case .lider: return -72.33196
        }
    }
    
    var geofenceRadius: Double {
        return 250.0 // 250 metros
    }
}
