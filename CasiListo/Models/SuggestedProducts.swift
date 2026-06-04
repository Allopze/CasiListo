import Foundation
import SwiftData

/// Productos frecuentes agrupados por categoría para autocompletado.
struct SuggestedProducts {

    /// Diccionario de categoría → lista de productos sugeridos.
    static let byCategory: [DefaultCategory: [String]] = [
        .vinos: [
            "Vino", "Botellines 187,5", "Botellines 350", "Tío Pepe", "Vino blanco", "Vino blanco cocina"
        ],
        .aseoPersonal: [
            "Acondicionador", "Acondicionador L'Oréal", "Acondicionador pelo Gabriel", "Cacao labial", 
            "Cepillo de dientes bambú", "Cepillo de dientes Pepsodent suave", "Cepillo de dientes Vitis", 
            "Champú", "Champú Alejandro", "Champú L'Oréal", "Crema corporal", "Crema corporal St. Ives", 
            "Crema humectante", "Desodorante", "Desodorante Dove", "Fijador", "Gotas ojos", "Hisopos", 
            "Jabón líquido Dove", "Jabón pastilla Dove", "Maquinilla de afeitar", "Maquinilla de afeitar BIC 4", 
            "Palillos dentales", "Pasta de dientes Pepsodent", "Pasta de dientes Vitis", "Repuestos afeitar", 
            "Tintura pelo", "Tiras adhesivas", "Toallitas húmedas"
        ],
        .bebidas: [
            "Aloe vera", "Cerveza", "Cerveza sin alcohol", "Coca cola", "Gatorade", "Ginebra", "Hielo", 
            "Jugos", "Mistral ICE", "Monster", "Orange", "Orange Zero", "Pisco", "Pisco sour", "Sprite", 
            "Sprite Zero", "Tónica", "Whisky"
        ],
        .carnes: [
            "Anticuchos", "Asiento", "Bistec", "Callos", "Carne cachopo", "Carne guisar", "Carne molida", 
            "Chorizo bocata", "Chorizo cocinar", "Chuletas de cerdo", "Corte americano", "Costilla de cerdo", 
            "Filete de cerdo", "Filete vacuno", "Hueso carnudo", "Ibéricos", "Jamón Colonial", 
            "Jamón Colonial Acaramelado", "Jamón de pavo", "Jamón serrano", "Lomo curado", "Lomo curado ibérico", 
            "Lomo de cerdo", "Lomo liso", "Longaniza", "Morcilla", "Osobuco", "Pechugas de pollo", "Plateada", 
            "Pollo", "Pollo asado", "Prietas", "Salchichas", "Salchichón", "Taco de jamón", "Tira", "Tocino", 
            "Tocino parrillero", "Trutros de pollo", "Trutros cortos"
        ],
        .condimentos: [
            "Albahaca", "Azafrán", "Bicarbonato", "Canela polvo", "Canela rama", "Colorante", "Comino", 
            "Cúrcuma", "Guindilla cayena", "Nuez moscada", "Orégano", "Paellero", "Pastillas caldo carne", 
            "Pastillas caldo pollo", "Pastillas caldo verduras", "Pimentón dulce", "Pimentón picante", 
            "Pimienta blanca", "Pimienta negra grano", "Pimienta negra molida", "Romero", "Sal Biosal", 
            "Sal entrefina", "Sal fina", "Sal gruesa", "Sésamo tostado", "Tomillo"
        ],
        .congelados: [
            "Camarones apanados", "Camarones crudos enteros", "Colas de camarón crudo", "Guisantes", 
            "Hamburguesas", "Helado", "Judías verdes", "Maíz en grano", "Mix de verduras", 
            "Palitos de mar (cangrejo)", "Panoja", "Pescado", "Postre", "Pulpo"
        ],
        .conservas: [
            "Anchoas", "Atún en aceite", "Atún grande", "Calamares", "Champiñones enteros", 
            "Champiñones laminados", "Espárragos blancos", "Espárragos verdes", "Guisantes", 
            "Jurel", "Mejillones escabeche", "Paté", "Pimientos Morrones", "Pimientos Piquillo", 
            "Sardinas en aceite", "Sardinas en tomate"
        ],
        .despensa: [
            "Aceite de oliva", "Aceite girasol", "Aceitunas con hueso", "Aceitunas rellenas", "Alioli", 
            "Almendras", "Alubias", "Arroz", "Arroz paella", "Azúcar", "Café capuchino", "Café descafeinado", 
            "Café grano", "Café Nescafé bote", "Café vainilla", "Castañas cajú", "Colacao bajo calorías", 
            "Corbatas", "Crema champiñones", "Crema espárragos", "Doritos", "Endulzante", "Espagueti", 
            "Fetuchini", "Fideo", "Fideos preparados", "Garbanzos", "Guisantes", "Harina con polvos de hornear", 
            "Harina de maíz", "Harina de trigo", "Ketchup bolsa", "Ketchup tarro", "Legumbres cocidas", 
            "Lentejas", "Levadura", "Macarrones", "Mariposas", "Mayonesa", "Mayonesa con ajo", 
            "Mayonesa Ybarra", "Nueces peladas", "Pasta china", "Pasta Chop suey", "Pasta lasaña", 
            "Patatas duquesa", "Patatas fritas", "Pipas", "Pistachos", "Pollo crispi", "Puré de patatas", 
            "Salsa Alfredo", "Salsa blanca", "Salsa de soja", "Salsa de tomate", "Salsa ensalada césar", 
            "Salsa salmón", "Sopas", "Sopas de pollo", "Tuco", "Vinagre blanco Carbonel", "Vinagre corriente", 
            "Vinagre de arroz", "Vinagre de jerez Carbonel"
        ],
        .frutasVerduras: [
            "Ajos", "Albahaca", "Cebolla", "Cebolla morada", "Champiñones frescos", "Champiñones frescos laminados", 
            "Frutas temporada", "Jengibre", "Kiwis", "Lechuga", "Limones", "Mandarinas", "Mangos", 
            "Manzanas Fuji", "Manzanas verdes", "Naranjas", "Palta", "Patatas", "Perejil", "Pimiento rojo", 
            "Pimiento verde", "Plátanos", "Puerro", "Repollo", "Setas", "Tomates", "Uvas", "Zanahorias", 
            "Zapallo"
        ],
        .hogarLimpieza: [
            "Ambientador", "Ambientador automático", "Ambientador desinfectante", "Balleta gamuza", 
            "Bolsas basura grandes", "Bolsas basura pequeñas", "Bolsas medianas", "Bolsas pequeñas", 
            "Bombillas", "Carbón", "Cerillas", "CIF Crema", "Cloro color", "Cloro gel", "Cloro normal", 
            "Clorox desinfectante", "Colgadores adhesivos", "Detergente", "Encendedor cocina", "Estropajos", 
            "Estropajos metálicos", "Insecticida", "La Gotita", "Lavavajillas", "Limpiasuelo", 
            "Mr. Músculo spray", "Papel de cocina", "Papel de regalo", "Papel higiénico", "Papel higiénico 25 m.", 
            "Pasa puré", "Paño de secar", "Pañuelos bolsillo", "Pañuelos caja", "Pegamento cerámica", 
            "Pegamento Ecole (zapatos)", "Pilas AA", "Pilas AAA", "Pinzas tendal", "Plumero", "Quita grasa", 
            "Repuestos quita pelos", "Rodillo quita pelos Scotch", "Scotch", "Servilletas", "Servilletas buenas", 
            "Suavizante", "Taper vidrio", "Tijera", "Toallas desinfectante", "Toallas desinfectantes suelo"
        ],
        .lacteosHuevos: [
            "Crema de leche (nata)", "Crema de leche sin lactosa", "Huevos", "Leche semi", 
            "Leche sin lactosa", "Mantequilla", "Mantequilla untable", "Margarina", "Postres", 
            "Queso", "Queso Camembert", "Queso cheddar", "Queso fresco", "Queso La Vaquita", 
            "Queso Laminado", "Queso laminado 250 Gr.", "Queso Manchego", "Queso mezcla semi", 
            "Queso rallado", "Yogures"
        ],
        .mascotas: [
            "Arena gatos", "Comida húmeda Gatos", "Comida seca Frijol", "Comida seca Gatos", 
            "Desodorante mascotas", "Latas comida gatos", "Saborizante comida gatos", "Snacks gatos"
        ],
        .panaderiaDulces: [
            "Caramelos Sunny", "Cereales Zucaritas", "Chocolate", "Chocolate menta", "Chocolate Pascal", 
            "Colaciones", "Ferrero Rocher", "Galletas café", "Galletas mantequilla", "Palillos", 
            "Pan baguete", "Pan Bimbo", "Pan ciabatta", "Pan de ajo", "Pan de cebolla", "Pan marraqueta", 
            "Pan molde Integral", "Pan Perfecto", "Pan rallado", "Pan tostado grande", "Pan tostado pequeño", 
            "Postre", "Tortillas mexicanas"
        ],
        .pescados: [
            "Atún rojo", "Calamares", "Camarones apanados", "Camarones crudos sin cabeza", 
            "Camarones grandes crudos enteros", "Camarones normales crudos enteros", "Congrio", 
            "Jibia", "Mejillones", "Merluza", "Ostiones", "Pescado", "Pulpo", "Rabas", "Salmón"
        ],
        .varios: [
            "Jarras para desayuno", "Lo de Gabriel", "Titicosas"
        ]
    ]

    /// Todos los nombres de productos sugeridos, sin duplicados.
    static let allProducts: [String] = {
        Array(Set(byCategory.values.flatMap { $0 })).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }()

    /// Filtra productos sugeridos cuyo nombre contiene el texto dado.
    static func suggestions(for text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        let lowered = text.lowercased()
        return allProducts.filter { $0.lowercased().contains(lowered) }
    }

    /// Devuelve la categoría más probable para un nombre de producto.
    /// Primero intenta coincidencia exacta; si no hay, prueba coincidencia por prefijo
    /// para cubrir variantes como "Tomates cherry" → "Tomates" (Frutas y verduras).
    static func suggestedCategory(for productName: String, in categories: [Category]) -> Category? {
        let lowered = productName.lowercased()
        let sortedEntries = byCategory.sorted { $0.key.sortIndex < $1.key.sortIndex }
        for (defaultCat, products) in sortedEntries {
            if products.contains(where: { $0.lowercased() == lowered }) {
                return categories.first { $0.name == defaultCat.rawValue }
            }
        }
        for (defaultCat, products) in sortedEntries {
            if products.contains(where: {
                let p = $0.lowercased()
                return lowered.hasPrefix(p) || p.hasPrefix(lowered)
            }) {
                return categories.first { $0.name == defaultCat.rawValue }
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
        let catDescriptor = FetchDescriptor<Category>()
        let categories = (try? context.fetch(catDescriptor)) ?? []
        
        var order = 0
        for defaultCat in DefaultCategory.allCases {
            guard let products = byCategory[defaultCat] else { continue }
            let realCategory = categories.first { $0.name == defaultCat.rawValue }
            for productName in products {
                let newItem = ShoppingItem(
                    name: productName,
                    listID: listID,
                    quantity: "",
                    category: realCategory,
                    note: "",
                    isPurchased: false,
                    sortOrder: order
                )
                context.insert(newItem)
                order += 1
            }
        }
        context.safeSave()
    }

    @MainActor
    static func seedCatalogItems(in context: ModelContext) {
        let catalogDescriptor = FetchDescriptor<ProductCatalogItem>()
        let existingCatalog = (try? context.fetch(catalogDescriptor)) ?? []
        let existingNames = Set(existingCatalog.map { $0.name.lowercased() })
        
        let catDescriptor = FetchDescriptor<Category>()
        let categories = (try? context.fetch(catDescriptor)) ?? []

        for (defaultCat, products) in byCategory {
            let realCategory = categories.first { $0.name == defaultCat.rawValue }
            for productName in products where !existingNames.contains(productName.lowercased()) {
                let catalogItem = ProductCatalogItem(
                    name: productName,
                    category: realCategory,
                    store: suggestedStore(for: productName)
                )
                context.insert(catalogItem)
            }
        }

        context.safeSave()
    }
}
