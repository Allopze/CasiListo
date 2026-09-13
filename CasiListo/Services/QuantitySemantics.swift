import Foundation

/// Qué significa el texto libre del campo «Cantidad» a la hora de contar plata.
///
/// El campo es libre y el propio formulario sugiere tres formas distintas
/// («2», «1 kg», «500 g»), así que el mismo string lo interpretaban tres sitios
/// con tres reglas incompatibles: la barra de añadido rápido fabricaba
/// «3 unidades», `ReceiptPurchaseService` solo sabía multiplicar enteros
/// desnudos, y el cierre de lista sin boleta ignoraba la cantidad por
/// completo. Una Coca Cola de $1.500 con «3 unidades» se archivaba por $1.500
/// —o menos, según el camino— en vez de $4.500, para siempre y sin ninguna
/// pantalla desde la que corregirlo. Esta es la única regla.
///
/// Invariante que sostiene todo lo demás: `ShoppingItem.price` es **unitario**
/// y `quantity` lleva el multiplicador. `ReceiptPriceIndex` compara precios
/// unitarios entre compras; meter un total de línea en `price` envenena el
/// historial de precios de ese producto para siempre.
nonisolated enum QuantitySemantics {
    /// Palabras que describen un **recuento de piezas**: multiplican el precio.
    /// Están las abreviaturas que escribe la gente y las que produce la barra
    /// de añadido rápido.
    static let countWords: Set<String> = ["u", "un", "ud", "uds", "unid", "unidad", "unidades"]

    /// Palabras que describen una **magnitud**: no multiplican nada. «500 g» es
    /// medio kilo de queso, no quinientos quesos. Tomar el número inicial de una
    /// magnitud dejaba el gasto de la compra multiplicado por 500.
    static let magnitudeWords: Set<String> = [
        "kg", "kgs", "g", "gr", "grs", "l", "lt", "lts", "ml", "cc", "mg"
    ]

    /// Tope de piezas, el mismo que ya aplica `ReceiptPurchaseEntry.quantity`
    /// (1...99). Un «2024» tecleado por error en Cantidad multiplicaría una
    /// compra por dos mil, y eso queda archivado sin forma de deshacerlo.
    static let maximumCount = 99

    enum Meaning: Equatable {
        /// N piezas del mismo producto: el precio unitario se multiplica por N.
        case count(Int)
        /// Una magnitud («500 g», «1,5 kg»), texto libre o vacío: el precio
        /// guardado ya es el de esa cantidad y vale por una unidad.
        case magnitude
    }

    static func meaning(of quantity: String) -> Meaning {
        // Se normaliza con la misma regla que los nombres (tildes, mayúsculas,
        // puntuación) para que «3 Unidades» y «3 unidades.» sean el mismo caso.
        // Como `normalize` parte por no-alfanuméricos, «1,5 kg» llega como
        // tres piezas y cae sola en `.magnitude`, que es lo correcto.
        let parts = ProductNameNormalizer.normalize(quantity)
            .split(separator: " ")
            .map(String.init)

        switch parts.count {
        case 1:
            // «2», «2u», «500g»: el número pegado a la palabra es lo que
            // produce el teclado de quien va con prisa en el pasillo.
            let digits = parts[0].prefix { $0.isNumber }
            guard !digits.isEmpty, let value = Int(digits) else { return .magnitude }
            let word = String(parts[0].dropFirst(digits.count))
            if word.isEmpty || countWords.contains(word) { return .count(clamped(value)) }
            return .magnitude
        case 2:
            // «3 unidades», «2 u», «500 g», «1 kg».
            guard let value = Int(parts[0]), countWords.contains(parts[1]) else { return .magnitude }
            return .count(clamped(value))
        default:
            return .magnitude
        }
    }

    /// Por cuánto se multiplica el precio unitario guardado. Siempre ≥ 1: una
    /// fila del historial nunca vale cero por no entender su cantidad.
    static func unitCount(of quantity: String) -> Int {
        switch meaning(of: quantity) {
        case .count(let value): return value
        case .magnitude: return 1
        }
    }

    /// Texto canónico de `ShoppingItem.quantity` para un recuento entero. El 1
    /// no se escribe: la fila ya se lee como una unidad y «1» era ruido.
    static func text(forCount count: Int) -> String {
        let value = clamped(count)
        return value > 1 ? "\(value)" : ""
    }

    /// ¿Esta palabra suelta es una unidad reconocible? La usa el parseo de la
    /// barra rápida para no cortar «3 unidades coca cola» por el sitio malo.
    static func isUnitWord(_ value: String) -> Bool {
        let word = ProductNameNormalizer.normalize(value)
        return countWords.contains(word) || magnitudeWords.contains(word)
    }

    /// ¿«500g», «2u»? Número pegado a la unidad, sin espacio.
    static func isNumberWithUnit(_ value: String) -> Bool {
        let normalized = ProductNameNormalizer.normalize(value)
        let digits = normalized.prefix { $0.isNumber }
        guard !digits.isEmpty, Int(digits) != nil else { return false }
        return isUnitWord(String(normalized.dropFirst(digits.count)))
    }

    private static func clamped(_ value: Int) -> Int {
        min(max(value, 1), maximumCount)
    }
}
