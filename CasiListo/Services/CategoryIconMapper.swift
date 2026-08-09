import Foundation

/// Mapeador inteligente de nombres de categorías a iconos de SF Symbols.
struct CategoryIconMapper {
    /// Devuelve un SF Symbol sugerido según el nombre de la categoría en español.
    static func suggestSymbol(for categoryName: String) -> String {
        let name = categoryName.lowercased().folding(options: .diacriticInsensitive, locale: .current).trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return "tag.fill" }

        // Mapeo de palabras clave en español a símbolos SF
        let mappings: [(keywords: [String], symbol: String)] = [
            // Alcohol / Vinos
            (["vino", "vinos", "alcohol", "pisco", "cerveza", "cervezas", "licor", "trago", "tragos", "whisky", "champagne", "botella", "coctel", "cava"], "wineglass.fill"),
            
            // Bebidas / Jugos
            (["bebida", "bebidas", "jugo", "jugos", "gatorade", "cola", "fanta", "sprite", "tonica", "agua", "aguas", "soda", "refresco", "refrescos", "te", "cafe", "cafe", "infusion", "infusiones"], "cup.and.saucer.fill"),
            
            // Carnes
            (["carne", "carnes", "pollo", "cerdo", "vacuno", "bistec", "hamburguesa", "hamburguesas", "embutido", "embutidos", "chorizo", "jamon", "salchicha", "salchichas", "tocino", "asado", "parrilla", "pavo", "prieta", "prietas", "morcilla"], "fork.knife"),
            
            // Pescados
            (["pescado", "pescados", "marisco", "mariscos", "camaron", "camarones", "atun", "salmon", "jurel", "pulpo", "mejillon", "mejillones", "ostiones", "almejas", "reineta", "merluza"], "fish.fill"),
            
            // Panadería / Dulces
            (["pan", "panaderia", "dulce", "dulces", "pastel", "pasteles", "torta", "galleta", "galletas", "queque", "bolleria", "panificadora", "harina", "chocolate", "chocolates", "donas", "mermelada"], "birthday.cake.fill"),
            
            // Congelados
            (["congelado", "congelados", "hielo", "helado", "helados", "frio", "nieve"], "snowflake"),
            
            // Frutas & Verduras
            (["fruta", "frutas", "verdura", "verduras", "vegetal", "vegetales", "ensalada", "manzana", "platano", "limon", "naranja", "tomate", "cebolla", "ajo", "papas", "patata", "patatas", "zanahoria", "lechuga", "palta", "aguacate", "hoja", "hojas", "champiñon", "champiñones", "perejil", "albahaca"], "leaf.fill"),
            
            // Aseo personal
            (["aseo personal", "aseo", "baño", "ducha", "champu", "acondicionador", "jabon", "pasta", "cepillo", "dientes", "desodorante", "crema", "cremas", "perfume", "maquillaje", "afeitadora", "gillette", "algodon", "cuidado", "hilo dental"], "sparkles"),
            
            // Hogar y limpieza
            (["limpieza", "hogar", "casa", "detergente", "suavizante", "lavavajillas", "cloro", "desinfectante", "esponja", "basura", "bolsas", "servilleta", "servilletas", "papel higienico", "higienico", "toallas", "cocina", "insecticida", "encendedor"], "house.fill"),
            
            // Mascotas
            (["mascota", "mascotas", "perro", "perros", "gato", "gatos", "alimento perro", "comida gato", "arena gatos", "veterinaria", "pajaros", "comida mascotas"], "pawprint.fill"),
            
            // Despensa
            (["despensa", "arroz", "fideos", "pasta", "pastas", "aceite", "vinagre", "sal", "azucar", "harina", "salsa", "conserva", "conservas", "lentejas", "porotos", "garbanzos", "cereal", "cereales", "snack", "snacks", "papas fritas", "frutos secos", "nueces"], "tray.full.fill"),
            
            // Condimentos
            (["condimento", "condimentos", "especia", "especias", "pimienta", "comino", "oregano", "canela", "curcuma", "aderezo", "aderezos", "mayonesa", "ketchup", "mostaza", "salsa", "caldo"], "cookingspoon"),
            
            // Lácteos y huevos
            (["lacteo", "lacteos", "leche", "queso", "quesos", "huevo", "huevos", "mantequilla", "margarina", "yogur", "yogures", "crema leche", "nata"], "egg.fill"),
            
            // Farmacia
            (["farmacia", "remedio", "remedios", "medicamento", "medicamentos", "pastilla", "pastillas", "jarabe", "dolor", "aspirina", "paracetamol", "ibuprofeno"], "pills.fill"),
            
            // Herramientas / Ferretería
            (["herramienta", "herramientas", "ferreteria", "tornillo", "martillo", "pegamento", "cinta", "tijera", "tijeras", "destornillador"], "hammer.fill"),
            
            // Electrónica
            (["tecnologia", "electronica", "cable", "cargador", "pilas", "pila", "ampolleta", "bombilla", "bombillas", "bateria"], "bolt.fill")
        ]

        let nameWords = name.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }

        for mapping in mappings {
            for keyword in mapping.keywords {
                let normalizedKeyword = keyword.folding(options: .diacriticInsensitive, locale: .current)
                if normalizedKeyword.contains(" ") {
                    if name.contains(normalizedKeyword) {
                        return mapping.symbol
                    }
                } else {
                    for word in nameWords {
                        if word == normalizedKeyword {
                            return mapping.symbol
                        }
                        if normalizedKeyword.count >= 4 && word.hasPrefix(normalizedKeyword) {
                            return mapping.symbol
                        }
                    }
                }
            }
        }

        return "tag.fill"
    }

    /// Listado de 24 íconos populares recomendados para el selector visual.
    static let popularSymbols: [String] = [
        "wineglass.fill",
        "cup.and.saucer.fill",
        "fork.knife",
        "fish.fill",
        "birthday.cake.fill",
        "snowflake",
        "leaf.fill",
        "sparkles",
        "house.fill",
        "pawprint.fill",
        "archivebox.fill",
        "archivebox",
        "cookingspoon",
        "egg.fill",
        "pills.fill",
        "bolt.fill",
        "hammer.fill",
        "tag.fill",
        "cart.fill",
        "bag.fill",
        "tshirt.fill",
        "books.vertical.fill",
        "gift.fill",
        "heart.fill"
    ]
}
