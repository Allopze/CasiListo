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
        // «egg.fill» no existe en SF Symbols: el badge salía vacío.
        case .lacteosHuevos: return "oval.portrait.fill"
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
    /// Vínculo estable con `DefaultCategory` (CASI-008). Solo lo llevan las
    /// categorías del sistema y nunca lo edita la persona: es lo que permite
    /// renombrar "Carnes" a "Carnicería" sin que "Bistec" empiece a caer en
    /// «Varios». Opcional porque los stores de la 1.0 no lo tienen; el
    /// backfill de `CategoryBootstrapService` lo rellena en el primer arranque.
    var defaultCategoryRawValue: String?

    @Relationship(deleteRule: .nullify, inverse: \ShoppingItem.categoryRelation)
    var items: [ShoppingItem]?

    @Relationship(deleteRule: .nullify, inverse: \ProductCatalogItem.categoryRelation)
    var catalogItems: [ProductCatalogItem]?

    init(
        name: String,
        sfSymbol: String,
        sortIndex: Int,
        isSystem: Bool = false,
        defaultCategory: DefaultCategory? = nil
    ) {
        self.name = name
        self.sfSymbol = sfSymbol
        self.sortIndex = sortIndex
        self.isSystem = isSystem
        self.defaultCategoryRawValue = defaultCategory?.rawValue
    }
}

extension Category {
    var displayName: String { name }
    var id: String { name }
    var rawValue: String { name }

    /// `DefaultCategory` tipada, derivada de `defaultCategoryRawValue`. Un raw
    /// value desconocido (una categoría del sistema retirada en el futuro) se
    /// lee como "sin vínculo", no lanza.
    var defaultCategory: DefaultCategory? {
        get { defaultCategoryRawValue.flatMap(DefaultCategory.init(rawValue:)) }
        set { defaultCategoryRawValue = newValue?.rawValue }
    }

    /// Resuelve la categoría real que representa a `defaultCategory`. Primero
    /// por el vínculo estable; si nadie lo tiene todavía (instalación que aún
    /// no pasó por el backfill, o container en memoria antes del bootstrap),
    /// cae a la comparación por nombre de siempre.
    nonisolated static func matching(_ defaultCategory: DefaultCategory, in categories: [Category]) -> Category? {
        categories.first { $0.defaultCategoryRawValue == defaultCategory.rawValue }
            ?? categories.first { $0.name == defaultCategory.rawValue }
    }

    /// "Varios" no se puede renombrar: la fila que la muestra ya avisa que es
    /// del sistema, pero antes se podía abrir igual, y renombrarla dejaba al
    /// bootstrap sin "Varios" que encontrar — creaba uno nuevo y vacío en el
    /// siguiente arranque, duplicándola.
    nonisolated static func isEditable(_ category: Category) -> Bool {
        category.name != "Varios" && category.defaultCategoryRawValue != DefaultCategory.varios.rawValue
    }

    /// Instancia no gestionada para uso de solo lectura (display).
    /// ⚠️ NO asignar a relaciones de SwiftData — usar `resolvedFallback(in:)` en su lugar.
    /// Cada acceso crea una nueva instancia para evitar problemas con SwiftData.
    nonisolated static var fallback: Category {
        Category(name: "Varios", sfSymbol: "bag.fill", sortIndex: 999, isSystem: true, defaultCategory: .varios)
    }

    /// Busca "Varios" en el contexto, o la crea si no existe.
    /// Seguro para asignar a relaciones de SwiftData.
    @MainActor
    static func resolvedFallback(in context: ModelContext) -> Category {
        var descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.name == "Varios" })
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let newCat = Category(name: "Varios", sfSymbol: "bag.fill", sortIndex: 999, isSystem: true, defaultCategory: .varios)
        context.insert(newCat)
        return newCat
    }

    nonisolated static func accentColor(forName name: String) -> Color {
        DefaultCategory.allCases.first { $0.rawValue == name }?.color
            ?? Color(hue: 0.13, saturation: 0.80, brightness: 0.95)
    }

    /// Igual que `accentColor(forName:)`, pero una categoría del sistema
    /// renombrada conserva su color gracias al vínculo estable (CASI-008).
    nonisolated static func accentColor(for category: Category) -> Color {
        category.defaultCategoryRawValue.flatMap(DefaultCategory.init(rawValue:))?.color
            ?? accentColor(forName: category.name)
    }

    /// Opacidad del fondo del badge de categoría. El icono se pinta encima, así
    /// que el contraste hay que medirlo contra esta mezcla, no contra la tarjeta.
    nonisolated static let badgeBackgroundOpacity: CGFloat = 0.14

    /// Color del icono dentro del badge de categoría.
    ///
    /// En claro, el color de la categoría sobre su propio 14% deja ocho de las
    /// quince categorías bajo 3:1 —«Lácteos y huevos» en 1.6:1, invisible—, así
    /// que se oscurece hasta 4.5:1 conservando el tono. En oscuro la mezcla es
    /// oscura y el color original ya contrasta.
    nonisolated static func iconColor(for category: Category) -> Color {
        iconColor(base: UIColor(accentColor(for: category)))
    }

    nonisolated static func iconColor(forName name: String) -> Color {
        iconColor(base: UIColor(accentColor(forName: name)))
    }

    nonisolated private static func iconColor(base: UIColor) -> Color {
        let lightBadge = base.blended(alpha: badgeBackgroundOpacity, over: UIColor(hex: "FFFFFF"))
        let darkBadge = base.blended(alpha: badgeBackgroundOpacity, over: UIColor(hex: "2A2928"))

        return Color(
            light: base.darkened(toContrast: 4.5, over: lightBadge),
            dark: Theme.contrastRatio(base, darkBadge) >= 4.5
                ? base
                : UIColor(hex: "F5F5F5")
        )
    }
}
