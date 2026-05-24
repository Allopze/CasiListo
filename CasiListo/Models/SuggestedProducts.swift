import Foundation
import SwiftData

/// Productos frecuentes agrupados por categoría para autocompletado.
struct SuggestedProducts {

    /// Diccionario de categoría → lista de productos sugeridos.
    static let byCategory: [Category: [String]] = [
        .vinos: [
            "Vino", "Vino blanco", "Vino blanco cocina"
        ],
        .bebidasAlcoholicas: [
            "Cerveza", "Pisco sour", "Pisco", "Ginebra", "Wisky", "Mistral ICE"
        ],
        .aseoPersonal: [
            "Jabón líquido Dove", "Jabón pastilla Dove", "Crema corporal St. Ives",
            "Acondicionador pelo Gabriel", "Cacao labial", "Pasta de dientes Pepsoden",
            "Pasta de dientes VITIS", "Cepillo de dientes Pepsodent suave",
            "Cepillo de dientes Vitis", "Cepillo de dientes bambú", "Desodorante",
            "Desodorante Dove", "Champú Alejandro", "Champú", "Acondicionador",
            "Toallitas húmedas", "Hisopos", "Papel higiénico.", "Papel higiénico 25 m.",
            "Maquinilla de afeitar", "Maquinilla de afeitar BIC 4", "Repuestos afeitar",
            "Pañuelos caja", "Pañuelos bolsillo", "Palillos dentales", "Tintura pelo",
            "Gotas ojos"
        ],
        .bebidas: [
            "Sprite", "Jugos", "Coca cola", "Orange", "Tónica", "Aloe vera",
            "Monster", "Gatorade", "Colacao bajo calorías", "Te", "Café vainilla",
            "Café capuccino", "Descafeinado bote", "Café Nescafé bote", "Café express"
        ],
        .carnes: [
            "Jamon Colonial", "Jamón de pavo", "Jamón Colonial Acaramelado", "Tocino",
            "Tocino parrillero", "Chorizo bocata", "Salchichón", "Chorizo cocinar",
            "Jamón serrano", "Lomo curado", "Lomo curado ibérico", "Ibéricos",
            "Taco de jamón.", "Pollo asado", "Pollo", "Trutros cortos",
            "Pechugas de pollo", "Trutos de Pollo", "Asiento", "Costilla de cerdo",
            "Chuletas de cerdo", "Lomo de cerdo", "Filete de cerdo", "Carne guisar",
            "Corte americano", "Bistec", "Lomo liso", "Anticuchos", "Osobuco",
            "Plateada", "Carne cachopo", "Filete vacuno", "Tira", "Longaniza",
            "Prietas", "Morcilla", "Hueso carnudo", "Carne molida"
        ],
        .despensa: [
            "Palillos", "Pan rallado", "Almendras", "Nueces peladas", "Castañas cajú",
            "Mix de verduras", "Aceite girasol", "Aceite de oliva", "Vinagre corriente",
            "Vinagre blanco Carbonel", "Vinagre de jerez Carbonel", "Vinagre de arroz",
            "Bicarbonato", "Salsa de soja", "Alioli", "Mayonesa", "Mayonesa con ajo",
            "Salsa de tomate", "Salsa salmón", "Salsa ensalada cesar", "Crema champiñones",
            "Crema espárragos", "Kepchup tarro", "Kepchup bolsa", "Orégano",
            "Pimienta negra", "Pimentón dulce", "Pimentón picante", "Sesamo tostado",
            "Canela en rama", "Sal fina", "Sal entrefina", "Sal gruesa", "Levadura",
            "Pote de sal", "Pasta sashuy", "Puré de patatas",
            "Arroz", "Arroz paella", "Macarrones", "Espagueti", "Fideos", "Corbatas",
            "Mariposas", "Sopas", "Caldo de pollo", "Caldo de carne", "Lentejas",
            "Alubias", "Garbanzos", "Mejillones escabeche", "Sardinas salsa de tomate",
            "Sardinas en aceite", "Atún", "Anchoas", "Aceitunas rellenas",
            "Aceitunas con hueso", "Paté", "Guisantes", "Pimiento morrón",
            "Pimientos Piquillo", "Champiñones enteros", "Champiñones laminados",
            "Tuco", "Latas picoteo (calamares, pulpo, etc.)",
            "Sopas de pollo", "Cereales Zucaritas", "Azúcar", "Endulzante",
            "Harina de maíz", "Harina de trigo", "Harina con polvos de hornear",
            "Pasta lasaña", "Pasta china"
        ],
        .frutasVerduras: [
            "Patatas", "Manzanas verdes", "Manzanas Fuji", "Kiwis", "Plátanos",
            "Mandarinas", "Naranjas", "Tomates", "Cebolla", "Cebolla morada",
            "Ajos", "Repollo", "Puerro", "Zapallo", "Palta", "Frutas temporada",
            "Mangos", "Limones", "Albahaca", "Jengibre", "Perejil", "Zanahorias",
            "Lechuga", "Pimiento rojo", "Pimiento verde", "Setas",
            "Champiñones frescos", "Champiñones frescos laminados", "Uvas"
        ],
        .hogarLimpieza: [
            "Carbón", "Cloro normal", "Cloro color", "Detergente",
            "Clorox desinfectante", "CID Cream", "M. Músculo spray", "Suavizante",
            "Ambientador automático", "Ambientador", "Ambientador desinfectante",
            "Insecticida", "Limpiasuelo", "Quita grasa", "Cloro gel",
            "Balleta gamuza", "Toallas desinfectante", "Toallas desinfectantes suelo",
            "Rodillo quita pelos Scotch", "Repuestos quita pelos", "Estropajos",
            "Estropajos metálicos", "Lavavajillas", "Bolsas medianas",
            "Bolsas pequeñas", "Bolsas basura grandes", "Bolsas basura pequeñas",
            "Plumero", "Servilletas", "Servilletas buenas", "Papel de cocina",
            "Paño de secar"
        ],
        .lacteosHuevos: [
            "Queso Laminado", "Queso mezcla semi", "Queso Manchego", "Queso fresco",
            "Queso cheddar", "Queso Camenbert", "Queso", "Queso rallado",
            "Queso La Vaquita", "Margarina", "Mantequilla", "Postres",
            "Leche sin lactosa", "Leche semi", "Crema de leche (nata)",
            "Crema de leche sin lactosa", "Yogures", "Huevos", "Postre"
        ],
        .congelados: [
            "Hielo", "Judias verdes congeladas", "Maíz en grano congelado", "Maíz (panoja) congelado",
            "Patatas duquesa", "Pollo crispi", "Hamburguesas congeladas", "Pizzas congeladas",
            "Helado de vainilla", "Helado de chocolate", "Mix de verduras congelado",
            "Pescado congelado", "Empanadas congeladas", "Papas fritas congeladas"
        ],
        .mascotas: [
            "Comida seca Gatos", "Arena gatos", "Comida seca Frijol",
            "Comida húmeda Gatos", "Saborizante comida gatos", "Latas comida gatos",
            "Snacks gatos", "Desodorante mascotas"
        ],
        .panaderiaDulces: [
            "Pan ciabata", "Pan marraqueta", "Pan baguete", "Pan de cebolla",
            "Pan Perfecto", "Pan Bimbo", "Pan molde Integral", "Pan tostado grande",
            "Pan tostado pequeño", "Tortillas mexicanas", "Pan de ajo",
            "Colaciones", "Chocolate", "Chocolate Pascal", "Chocolate menta",
            "Ferrero Rocher", "Galletas mantequilla", "Galletas café",
            "Patatas fritas", "Pistachos", "Doritos", "Caramelos Sunny"
        ],
        .pescados: [
            "Pescado", "Merluza", "Salmón", "Congrio",
            "Camarones grandes crudos enteros", "Camarones normales crudos enteros",
            "Camarones crudos sin cabez", "Ostiones", "Pulpo",
            "Palitos de mar (cangrejo)", "Calamares", "Atún rojo", "Rabas",
            "Jibia", "Mejillones"
        ],
        .varios: [
            "Bombillas", "Pilas AAA", "Pilas AA", "Taper vidrio", "Pinzas tendal",
            "Tiras adhesivas", "Pegamento cerámica", "Pegamento Ecole (zapatos)",
            "Colgadores adhesivos", "Scotch", "Tijera", "Papel de regalo",
            "Cerillas", "Encendedor cocina", "LO DE PATRICIA", "La Gotita",
            "LO DE GABRIEL"
        ]
    ]

    /// Todos los nombres de productos sugeridos, sin duplicados.
    static let allProducts: [String] = {
        Array(Set(byCategory.values.flatMap { $0 })).sorted()
    }()

    /// Filtra productos sugeridos cuyo nombre contiene el texto dado.
    static func suggestions(for text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        let lowered = text.lowercased()
        return allProducts.filter { $0.lowercased().contains(lowered) }
    }

    /// Devuelve la categoría más probable para un nombre de producto.
    static func suggestedCategory(for productName: String) -> Category? {
        let lowered = productName.lowercased()
        for (category, products) in byCategory {
            if products.contains(where: { $0.lowercased() == lowered }) {
                return category
            }
        }
        return nil
    }

    /// Devuelve el supermercado más probable para un nombre de producto (por defecto Jumbo).
    static func suggestedStore(for productName: String) -> Store {
        // En el futuro se pueden mapear productos específicos de Líder aquí
        return .jumbo
    }

    /// Siembra los productos sugeridos por defecto en la base de datos de SwiftData.
    @MainActor
    static func seedDefaultItems(in context: ModelContext, listID: UUID? = nil) {
        var order = 0
        for category in Category.allCases {
            guard let products = byCategory[category] else { continue }
            for productName in products {
                let newItem = ShoppingItem(
                    name: productName,
                    listID: listID,
                    quantity: "",
                    category: category,
                    note: "",
                    isPurchased: false,
                    sortOrder: order
                )
                context.insert(newItem)
                order += 1
            }
        }
        try? context.save()
    }

    @MainActor
    static func seedCatalogItems(in context: ModelContext, existingCatalog: [ProductCatalogItem]) {
        let existingNames = Set(existingCatalog.map { $0.name.lowercased() })

        for (category, products) in byCategory {
            for productName in products where !existingNames.contains(productName.lowercased()) {
                let catalogItem = ProductCatalogItem(
                    name: productName,
                    category: category,
                    store: suggestedStore(for: productName)
                )
                context.insert(catalogItem)
            }
        }

        try? context.save()
    }
}
