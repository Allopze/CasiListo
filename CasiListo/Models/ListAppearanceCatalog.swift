import Foundation
import SwiftUI
import UIKit

/// Opción de color para personalizar una lista de compras.
struct ListColorOption: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let hex: String

    var color: Color {
        Color(hex: hex)
    }

    init(name: String, hex: String) {
        self.id = hex
        self.name = name
        self.hex = hex
    }
}

/// Categoría de iconos SF Symbols para organizar el selector de listas.
struct ListIconCategory: Identifiable, Sendable {
    let id: String
    let title: String
    let symbols: [String]
}

/// Catálogo centralizado de colores, iconos y sugerencias automáticas para listas.
enum ListAppearanceCatalog {

    // MARK: - Paleta de colores curada

    static let defaultColorHex = "F5C518"
    static let defaultSymbol = "cart.fill"

    static let colors: [ListColorOption] = [
        ListColorOption(name: "Amarillo CasiListo", hex: "F5C518"),
        ListColorOption(name: "Naranja Cálido", hex: "FF9500"),
        ListColorOption(name: "Coral Intenso", hex: "FF5722"),
        ListColorOption(name: "Rojo Frambuesa", hex: "E53935"),
        ListColorOption(name: "Rosa Fucsia", hex: "E91E63"),
        ListColorOption(name: "Violeta Mágico", hex: "9C27B0"),
        ListColorOption(name: "Índigo Profundo", hex: "5C6BC0"),
        ListColorOption(name: "Azul Océano", hex: "2196F3"),
        ListColorOption(name: "Turquesa Caribe", hex: "00BCD4"),
        ListColorOption(name: "Verde Esmeralda", hex: "4CAF50"),
        ListColorOption(name: "Menta Fresco", hex: "00C853"),
        ListColorOption(name: "Café Tierra", hex: "795548")
    ]

    // MARK: - Iconos categorizados

    static let iconCategories: [ListIconCategory] = [
        ListIconCategory(
            id: "shopping",
            title: "Compras & Mercado",
            symbols: ["cart.fill", "basket.fill", "bag.fill", "storefront.fill", "tag.fill", "barcode"]
        ),
        ListIconCategory(
            id: "food",
            title: "Comida & Bebida",
            symbols: ["fork.knife", "cup.and.saucer.fill", "wineglass.fill", "birthday.cake.fill", "carrot.fill", "fish.fill", "leaf.fill"]
        ),
        ListIconCategory(
            id: "home",
            title: "Hogar & Salud",
            symbols: ["house.fill", "bed.double.fill", "sofa.fill", "sparkles", "cross.case.fill", "pills.fill"]
        ),
        ListIconCategory(
            id: "events",
            title: "Eventos & Ocasiones",
            symbols: ["party.popper.fill", "gift.fill", "flame.fill", "airplane", "wrench.and.screwdriver.fill", "pawprint.fill"]
        )
    ]

    static var allSymbols: [String] {
        iconCategories.flatMap(\.symbols)
    }

    /// Nombre legible de cada icono: VoiceOver no puede dictar «cart.fill».
    private static let symbolNames: [String: String] = [
        "cart.fill": "Carro de compras",
        "basket.fill": "Canasto",
        "bag.fill": "Bolsa",
        "storefront.fill": "Tienda",
        "tag.fill": "Etiqueta",
        "barcode": "Código de barras",
        "fork.knife": "Restaurante",
        "cup.and.saucer.fill": "Taza de café",
        "wineglass.fill": "Copa de vino",
        "birthday.cake.fill": "Torta",
        "carrot.fill": "Zanahoria",
        "fish.fill": "Pescado",
        "leaf.fill": "Hoja",
        "house.fill": "Casa",
        "bed.double.fill": "Cama",
        "sofa.fill": "Sillón",
        "sparkles": "Limpieza",
        "cross.case.fill": "Botiquín",
        "pills.fill": "Remedios",
        "party.popper.fill": "Fiesta",
        "gift.fill": "Regalo",
        "flame.fill": "Fuego",
        "airplane": "Avión",
        "wrench.and.screwdriver.fill": "Herramientas",
        "pawprint.fill": "Mascota"
    ]

    static func displayName(for symbol: String) -> String {
        symbolNames[symbol] ?? symbol
    }

    // MARK: - Contraste sobre el color de la lista

    /// Color de primer plano legible sobre `hex`. La paleta va del amarillo al
    /// violeta, así que ningún valor fijo cumple AA sobre todos: el blanco se
    /// pierde sobre el amarillo de marca y el negro sobre el violeta. Se elige
    /// el que da mayor razón de contraste WCAG.
    static func foreground(on hex: String) -> Color {
        let background = relativeLuminance(of: UIColor(hex: hex))
        let contrastWithWhite = 1.05 / (background + 0.05)
        let contrastWithDark = (background + 0.05) / (onAccentLuminance + 0.05)
        return contrastWithDark >= contrastWithWhite ? Theme.onAccent : .white
    }

    private static let onAccentLuminance = relativeLuminance(of: UIColor(hex: "1A1A1A"))

    private static func relativeLuminance(of color: UIColor) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        func linear(_ component: CGFloat) -> Double {
            let value = Double(component)
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    // MARK: - Sugerencias inteligentes

    /// Infiere el icono y color más apropiados según el texto del nombre.
    static func suggestAppearance(for name: String) -> (symbol: String, colorHex: String) {
        let normalized = ProductNameNormalizer.normalize(name)
        guard !normalized.isEmpty else {
            return (defaultSymbol, defaultColorHex)
        }

        if normalized.contains("asado") || normalized.contains("parrilla") || normalized.contains("carne") || normalized.contains("barbacoa") {
            return ("flame.fill", "FF5722")
        }
        if normalized.contains("fiesta") || normalized.contains("cumple") || normalized.contains("evento") || normalized.contains("celebracion") {
            return ("party.popper.fill", "E91E63")
        }
        if normalized.contains("farmacia") || normalized.contains("remedio") || normalized.contains("salud") || normalized.contains("medicina") || normalized.contains("doctor") {
            return ("pills.fill", "00BCD4")
        }
        if normalized.contains("ferreteria") || normalized.contains("herramienta") || normalized.contains("construccion") || normalized.contains("taller") || normalized.contains("arreglo") {
            return ("wrench.and.screwdriver.fill", "FF9500")
        }
        if normalized.contains("viaje") || normalized.contains("vacaciones") || normalized.contains("paseo") || normalized.contains("vuelo") || normalized.contains("playa") {
            return ("airplane", "2196F3")
        }
        if normalized.contains("mascota") || normalized.contains("perro") || normalized.contains("gato") || normalized.contains("veterinaria") {
            return ("pawprint.fill", "795548")
        }
        if normalized.contains("limpieza") || normalized.contains("aseo") || normalized.contains("lavanderia") || normalized.contains("casa") {
            return ("sparkles", "00BCD4")
        }
        if normalized.contains("feria") || normalized.contains("verdura") || normalized.contains("fruta") || normalized.contains("vegano") || normalized.contains("vegetariano") {
            return ("leaf.fill", "4CAF50")
        }
        if normalized.contains("regalo") || normalized.contains("navidad") || normalized.contains("aniversario") {
            return ("gift.fill", "E53935")
        }
        if normalized.contains("cafe") || normalized.contains("desayuno") || normalized.contains("once") || normalized.contains("te") {
            return ("cup.and.saucer.fill", "795548")
        }
        if normalized.contains("tragos") || normalized.contains("bar") || normalized.contains("vino") || normalized.contains("cerveza") || normalized.contains("botilleria") {
            return ("wineglass.fill", "9C27B0")
        }
        if normalized.contains("ropa") || normalized.contains("mall") || normalized.contains("tienda") || normalized.contains("moda") {
            return ("bag.fill", "5C6BC0")
        }
        if normalized.contains("panaderia") || normalized.contains("pan") || normalized.contains("pasteleria") || normalized.contains("torta") {
            return ("birthday.cake.fill", "FF9500")
        }

        return (defaultSymbol, defaultColorHex)
    }
}
