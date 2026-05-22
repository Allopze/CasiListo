import Foundation

/// Categorías predefinidas para agrupar los ítems de la lista de compra.
enum Category: String, CaseIterable, Codable, Identifiable {
    case vinos = "Vinos"
    case bebidasAlcoholicas = "Bebidas alcohólicas"
    case aseoPersonal = "Aseo personal"
    case bebidas = "Bebidas"
    case carnes = "Carnes"
    case despensa = "Despensa"
    case frutasVerduras = "Frutas y verduras"
    case hogarLimpieza = "Hogar y limpieza"
    case lacteosHuevos = "Lácteos y huevos"
    case mascotas = "Mascotas"
    case panaderiaDulces = "Panadería y dulces"
    case pescados = "Pescados"
    case varios = "Varios"

    var id: String { rawValue }

    /// Nombre para mostrar en la UI.
    var displayName: String { rawValue }

    /// SF Symbol representativo de la categoría.
    var sfSymbol: String {
        switch self {
        case .vinos: return "wineglass.fill"
        case .bebidasAlcoholicas: return "wineglass"
        case .aseoPersonal: return "sparkles"
        case .bebidas: return "cup.and.saucer.fill"
        case .carnes: return "fork.knife"
        case .despensa: return "archivebox.fill"
        case .frutasVerduras: return "leaf.fill"
        case .hogarLimpieza: return "house.fill"
        case .lacteosHuevos: return "egg.fill"
        case .mascotas: return "pawprint.fill"
        case .panaderiaDulces: return "birthday.cake.fill"
        case .pescados: return "fish.fill"
        case .varios: return "bag.fill"
        }
    }

    /// Orden de presentación en la lista (coincide con el orden de declaración del enum).
    var sortIndex: Int {
        Category.allCases.firstIndex(of: self) ?? 0
    }
}

