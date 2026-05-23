import Foundation

/// Categorías predefinidas para agrupar los ítems de la lista de compra.
enum Category: String, CaseIterable, Codable, Identifiable {
    case frutasVerduras = "Frutas y verduras"
    case carnes = "Carnes"
    case pescados = "Pescados"
    case lacteosHuevos = "Lácteos y huevos"
    case congelados = "Congelados"
    case panaderiaDulces = "Panadería y dulces"
    case despensa = "Despensa"
    case bebidas = "Bebidas"
    case vinos = "Vinos"
    case bebidasAlcoholicas = "Bebidas alcohólicas"
    case aseoPersonal = "Aseo personal"
    case hogarLimpieza = "Hogar y limpieza"
    case mascotas = "Mascotas"
    case varios = "Varios"

    var id: String { rawValue }

    /// Nombre para mostrar en la UI.
    var displayName: String { rawValue }

    /// SF Symbol representativo de la categoría.
    var sfSymbol: String {
        switch self {
        case .frutasVerduras: return "leaf.fill"
        case .carnes: return "fork.knife"
        case .pescados: return "fish.fill"
        case .lacteosHuevos: return "egg.fill"
        case .congelados: return "snowflake"
        case .panaderiaDulces: return "birthday.cake.fill"
        case .despensa: return "archivebox.fill"
        case .bebidas: return "cup.and.saucer.fill"
        case .vinos: return "wineglass.fill"
        case .bebidasAlcoholicas: return "wineglass"
        case .aseoPersonal: return "sparkles"
        case .hogarLimpieza: return "house.fill"
        case .mascotas: return "pawprint.fill"
        case .varios: return "bag.fill"
        }
    }

    /// Orden de presentación en la lista (coincide con el orden de declaración del enum).
    var sortIndex: Int {
        Category.allCases.firstIndex(of: self) ?? 0
    }
}

