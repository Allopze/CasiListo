import Foundation
import SwiftData
import SwiftUI

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
        case .condimentos: return "flame.fill"
        case .congelados: return "snowflake"
        case .conservas: return "archivebox.fill"
        case .despensa: return "tray.full.fill"
        case .frutasVerduras: return "leaf.fill"
        case .hogarLimpieza: return "house.fill"
        case .lacteosHuevos: return "egg.fill"
        case .mascotas: return "pawprint.fill"
        case .panaderiaDulces: return "birthday.cake.fill"
        case .pescados: return "fish.fill"
        case .varios: return "bag.fill"
        }
    }

    nonisolated var color: Color {
        switch self {
        case .vinos: return Color(hue: 0.75, saturation: 0.65, brightness: 0.70)
        case .aseoPersonal: return Color(hue: 0.58, saturation: 0.60, brightness: 0.80)
        case .bebidas: return Color(hue: 0.52, saturation: 0.65, brightness: 0.70)
        case .carnes: return Color(hue: 0.02, saturation: 0.75, brightness: 0.75)
        case .condimentos: return Color(hue: 0.07, saturation: 0.80, brightness: 0.88)
        case .congelados: return Color(hue: 0.56, saturation: 0.45, brightness: 0.85)
        case .conservas: return Color(hue: 0.08, saturation: 0.55, brightness: 0.62)
        case .despensa: return Color(hue: 0.11, saturation: 0.70, brightness: 0.78)
        case .frutasVerduras: return Color(hue: 0.35, saturation: 0.70, brightness: 0.60)
        case .hogarLimpieza: return Color(hue: 0.47, saturation: 0.55, brightness: 0.68)
        case .lacteosHuevos: return Color(hue: 0.13, saturation: 0.60, brightness: 0.88)
        case .mascotas: return Color(hue: 0.08, saturation: 0.50, brightness: 0.68)
        case .panaderiaDulces: return Color(hue: 0.95, saturation: 0.60, brightness: 0.82)
        case .pescados: return Color(hue: 0.60, saturation: 0.65, brightness: 0.72)
        case .varios: return Color(hue: 0.65, saturation: 0.15, brightness: 0.55)
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

    /// Instancia no gestionada para uso de solo lectura (display).
    /// ⚠️ NO asignar a relaciones de SwiftData — usar `resolvedFallback(in:)` en su lugar.
    nonisolated(unsafe) static let fallback = Category(name: "Varios", sfSymbol: "bag.fill", sortIndex: 999, isSystem: true)

    /// Busca "Varios" en el contexto, o la crea si no existe.
    /// Seguro para asignar a relaciones de SwiftData.
    @MainActor
    static func resolvedFallback(in context: ModelContext) -> Category {
        var descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.name == "Varios" })
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let newCat = Category(name: "Varios", sfSymbol: "bag.fill", sortIndex: 999, isSystem: true)
        context.insert(newCat)
        return newCat
    }

    nonisolated static func accentColor(forName name: String) -> Color {
        DefaultCategory.allCases.first { $0.rawValue == name }?.color
            ?? Color(hue: 0.13, saturation: 0.80, brightness: 0.95)
    }
}


