import Foundation
import SwiftData

/// Categorías predefinidas para sembrado inicial.
enum DefaultCategory: String, CaseIterable, Codable, Identifiable {
    case vinos = "Vinos"
    case aseoPersonal = "Aseo personal"
    case bebidas = "Bebidas"
    case carnes = "Carnes"
    case condimentos = "Condimentos"
    case congelados = "Congelados"
    case conservas = "Conservas"
    case despensa = "Despensa"
    case frutasVerduras = "Frutas y verduras"
    case hogarLimpieza = "Hogar y limpieza"
    case lacteosHuevos = "Lácteos y huevos"
    case mascotas = "Mascotas"
    case panaderiaDulces = "Panadería y dulces"
    case pescados = "Pescados"
    case varios = "Varios"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var sfSymbol: String {
        switch self {
        case .vinos: return "wineglass.fill"
        case .aseoPersonal: return "sparkles"
        case .bebidas: return "cup.and.saucer.fill"
        case .carnes: return "fork.knife"
        case .condimentos: return "cookingspoon"
        case .congelados: return "snowflake"
        case .conservas: return "archivebox.fill"
        case .despensa: return "archivebox"
        case .frutasVerduras: return "leaf.fill"
        case .hogarLimpieza: return "house.fill"
        case .lacteosHuevos: return "egg.fill"
        case .mascotas: return "pawprint.fill"
        case .panaderiaDulces: return "birthday.cake.fill"
        case .pescados: return "fish.fill"
        case .varios: return "bag.fill"
        }
    }

    var sortIndex: Int {
        DefaultCategory.allCases.firstIndex(of: self) ?? 0
    }
}

/// Modelo de categoría persistido con SwiftData.
@Model
final class Category: Identifiable, Hashable {
    @Attribute(.unique) var name: String
    var sfSymbol: String
    var sortIndex: Int
    var isSystem: Bool

    @Relationship(deleteRule: .nullify, inverse: \ShoppingItem.categoryRelation)
    var items: [ShoppingItem]?

    @Relationship(deleteRule: .nullify, inverse: \ProductCatalogItem.categoryRelation)
    var catalogItems: [ProductCatalogItem]?

    init(name: String, sfSymbol: String, sortIndex: Int, isSystem: Bool = false) {
        self.name = name
        self.sfSymbol = sfSymbol
        self.sortIndex = sortIndex
        self.isSystem = isSystem
    }
}

extension Category {
    var displayName: String { name }
    var id: String { name }
    var rawValue: String { name }
    static var fallback: Category {
        Category(name: "Varios", sfSymbol: "bag.fill", sortIndex: 999, isSystem: true)
    }
}


