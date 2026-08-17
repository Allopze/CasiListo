import Foundation

/// Una línea de producto detectada en una boleta antes de que el usuario la confirme.
/// `lineTotal` es lo que la boleta cobra por esa línea y manda sobre el unitario:
/// así la suma de la revisión siempre cuadra con el papel.
nonisolated struct RecognizedReceiptLine: Identifiable, Sendable {
    let id: UUID
    let name: String
    let lineTotal: Double
    let quantity: Int
    /// Confianza mínima de los fragmentos que componen la línea (0…1).
    let confidence: Double
    /// La línea traía un descuento aplicado bajo el producto.
    let hasDiscount: Bool

    init(
        id: UUID = UUID(),
        name: String,
        lineTotal: Double,
        quantity: Int = 1,
        confidence: Double = 1,
        hasDiscount: Bool = false
    ) {
        self.id = id
        self.name = name
        self.lineTotal = lineTotal
        self.quantity = max(1, quantity)
        self.confidence = confidence
        self.hasDiscount = hasDiscount
    }

    var unitPrice: Double { lineTotal / Double(quantity) }
}

nonisolated struct ReceiptParseResult: Sendable {
    let products: [RecognizedReceiptLine]
    /// TOTAL impreso al pie de la boleta, cuando se pudo leer.
    let printedTotal: Double?

    init(products: [RecognizedReceiptLine], printedTotal: Double? = nil) {
        self.products = products
        self.printedTotal = printedTotal
    }
}

// MARK: - Montos

/// Lectura de montos en formato chileno: el punto y la coma son separadores de
/// miles (`$1.290`), y solo se interpretan como decimales cuando quedan una o
/// dos cifras al final (`1290,50`).
nonisolated enum ReceiptAmount {
    /// Fragmento de patrón reutilizable para montos dentro de otras expresiones.
    static let pattern = "[0-9]{1,3}(?:[.,\\s][0-9]{3})+|[0-9]+(?:[.,][0-9]{1,2})?"

    private static let thousands = regex("^[0-9]{1,3}(?:[.,\\s][0-9]{3})+$")
    private static let decimals = regex("^[0-9]+[.,][0-9]{1,2}$")

    static func value(_ raw: String) -> Double? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        text.removeAll { $0 == "$" || $0.isWhitespace }
        let isNegative = text.hasPrefix("-")
        if isNegative { text.removeFirst() }
        guard !text.isEmpty, text.contains(where: \.isNumber) else { return nil }

        let magnitude: Double
        if matches(thousands, text) {
            magnitude = Double(text.filter(\.isNumber)) ?? 0
        } else if matches(decimals, text) {
            magnitude = Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
        } else {
            magnitude = Double(text.filter(\.isNumber)) ?? 0
        }

        guard magnitude > 0 else { return nil }
        return isNegative ? -magnitude : magnitude
    }

    /// Redondeo a pesos: la moneda chilena no tiene decimales y arrastrarlos
    /// hace que los totales dejen de cuadrar.
    static func rounded(_ value: Double) -> Double { value.rounded() }

    /// Cantidades como `2`, `2,000` o `0,860` (kilos). Aquí el separador sí es decimal.
    static func decimalQuantity(_ raw: String) -> Double {
        let text = raw.replacingOccurrences(of: ",", with: ".")
        return Double(text) ?? 0
    }

    private static func matches(_ expression: NSRegularExpression, _ text: String) -> Bool {
        expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    static func regex(_ pattern: String) -> NSRegularExpression {
        // Los patrones son literales del propio archivo: un fallo aquí es un
        // error de programación, no una entrada inválida.
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
}

// MARK: - Parser

nonisolated enum ReceiptLineParser {

    // MARK: Vocabulario de la boleta

    /// Encabezado: datos del local que nunca son productos.
    private static let headerTokens: Set<String> = [
        "boleta", "rut", "giro", "sii", "sucursal", "caja", "cajero", "cajera",
        "folio", "fecha", "hora", "autorizacion", "autorizado", "resolucion",
        "electronica", "electronico", "tributaria", "tributario", "direccion",
        "fono", "telefono", "tel", "www", "cliente", "atendido", "atendida",
        "operador", "terminal", "comercio", "local", "avenida", "av", "avda",
        "calle", "pasaje", "psje", "mall", "matriz", "emision", "documento",
        "razon", "social", "sucursales", "vendedor"
    ]

    /// Pie: a partir de aquí ya no hay productos, solo el cierre monetario.
    private static let footerTokens: Set<String> = [
        "total", "subtotal", "iva", "neto", "exento", "afecto", "pagar",
        "efectivo", "debito", "credito", "transbank", "redcompra", "voucher",
        "vuelto", "cambio", "propina", "gracias"
    ]

    /// Recuentos de unidades que también empiezan con «TOTAL»: Líder imprime
    /// «TOTAL NUMERO DE ARTIC VEND 45». El 45 es un conteo, no el monto pagado.
    /// No van en `footerTokens`: un producto llamado «ARTICULOS DE ASEO» cortaría
    /// el cuerpo de la boleta y se perdería todo lo que viniera después.
    private static let itemCountTokens: Set<String> = [
        "articulos", "artic", "articulo", "unidades", "bultos", "numero"
    ]

    /// Líneas de rebaja explícitas («DCTO SOCIO 1.000») que pueden venir con monto positivo.
    /// Cualquier línea con monto negativo en la boleta se interpreta automáticamente como descuento.
    private static let discountTokens: Set<String> = [
        "dcto", "dctos", "descuento", "descuentos",
        "promocion", "promocional", "rebaja", "oferta"
    ]

    /// Ruido intercalado que se ignora sin cortar la relación nombre → precio.
    private static let noiseTokens: Set<String> = [
        "ahorro", "ahorros", "puntos", "socio", "socios", "acumulados", "acumulado",
        "copia", "original", "valida", "validez", "consulte", "reclamos",
        // Secciones de supermercados chilenos
        "ofertas", "codigo"
    ]

    /// Una línea de rebaja es corta («DCTO SOCIO 1.000»); si trae varias palabras
    /// es más probable que sea un producto en promoción.
    private static let maximumDiscountWords = 4

    /// Etiquetas de sección intercaladas entre productos: «Open bar»,
    /// «Mercado FFVV», «Precio normal». Se reconocen solo cuando la línea NO
    /// trae un monto propio (con monto puede ser un descuento de sección).
    private static let sectionLabels: Set<String> = [
        "open bar", "mercado ffvv", "precio normal"
    ]

    /// Líneas de referencia de promoción de Líder: «RF lleve M x $»,
    /// «SX1010 7801234…», «CODIGO 780044…».
    private static let liderPromoPattern = ReceiptAmount.regex(
        "^\\s*(RF\\s|SX[0-9]|[0-9]+X[0-9]+\\s+[0-9]{7,})"
    )

    // MARK: Expresiones

    /// `PRODUCTO ... $1.290`, `DESCUENTO ... -1.290`, `OFERTA ... -$1.290`
    private static let amountAtEnd = ReceiptAmount.regex(
        "^(.*?)[\\s\\t]+(-?\\s*\\$?\\s*|-)(\(ReceiptAmount.pattern))\\s*$"
    )

    /// `$1.290`, `-1.290`, `-$1.290` — la fila entera es un monto.
    private static let amountOnly = ReceiptAmount.regex(
        "^\\s*(-?\\s*\\$?\\s*|-)(\(ReceiptAmount.pattern))\\s*$"
    )

    /// `2 x $1.990 $3.980`, `2 UN × $1.990`, `0,860 KG X $1.290/KG $1.109`.
    /// Vision normaliza la `x` mecanografiada al signo `×` (U+00D7), así que la
    /// clase de caracteres tiene que aceptar ambos y sus variantes.
    private static let quantityLine = ReceiptAmount.regex(
        "^\\s*([0-9]{1,2}(?:[.,][0-9]{1,3})?)\\s*"
        + "(UN|UNI|UND|UD|U|KGS|KG|KLS|KL|K|GRS|GR|G|LTS|LT|L|MT|M)?\\.?\\s*"
        + "[xX\u{00D7}\u{2715}\u{2716}*]\\s*"
        + "(?:\\$\\s*)?(\(ReceiptAmount.pattern))"
        + "(?:\\s*/\\s*[A-Za-z]{1,3}\\.?)?"
        + "(?:[\\s\\t]+(?:\\$\\s*)?(\(ReceiptAmount.pattern)))?\\s*$"
    )

    /// Código de barras u otro identificador largo al inicio del nombre.
    private static let leadingCode = ReceiptAmount.regex("^[0-9]{7,}\\s+")

    private static let rutPattern = ReceiptAmount.regex("[0-9]{1,2}\\.[0-9]{3}\\.[0-9]{3}\\s*-\\s*[0-9kK]")
    private static let datePattern = ReceiptAmount.regex("[0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4}")
    private static let timePattern = ReceiptAmount.regex("[0-9]{1,2}:[0-9]{2}")
    private static let legalEntityPattern = ReceiptAmount.regex("\\bS\\.\\s?A\\.|\\b(SPA|LTDA|EIRL|S\\.P\\.A)\\b")
    private static let longNumberPattern = ReceiptAmount.regex("[0-9]{6,}")

    /// Montos por debajo de esto en una fila sin `$` ni columna propia son casi
    /// siempre gramajes o formatos (`3 L`, `500 GR`), no precios.
    private static let bareAmountFloor: Double = 100
    private static let minimumAmount: Double = 10
    private static let maximumAmount: Double = 1_000_000

    /// Cuántas filas de ruido puede haber entre el nombre y su precio.
    private static let maximumPendingGap = 2

    /// Cuántas filas iniciales se consideran encabezado como máximo.
    private static let headerScanLimit = 14

    // MARK: Entrada

    static func parse(_ lines: [String]) -> [RecognizedReceiptLine] {
        parse(lines.map { ReceiptTextLine(text: $0) }).products
    }

    static func parse(_ lines: [ReceiptTextLine]) -> ReceiptParseResult {
        let tokens = lines.map { Set(ProductNameNormalizer.normalize($0.text).split(separator: " ").map(String.init)) }

        let headerEnd = headerBoundary(lines: lines, tokens: tokens)
        let footerStart = footerBoundary(lines: lines, tokens: tokens, from: headerEnd)
        let total = printedTotal(lines: lines, tokens: tokens, from: footerStart)

        guard headerEnd < footerStart else {
            return ReceiptParseResult(products: [], printedTotal: total)
        }

        let body = Array(lines[headerEnd..<footerStart])
        let bodyTokens = Array(tokens[headerEnd..<footerStart])
        let kinds = zip(body, bodyTokens).map { classify($0, tokens: $1) }

        return ReceiptParseResult(products: walk(kinds), printedTotal: total)
    }

    // MARK: Segmentación

    private static func headerBoundary(lines: [ReceiptTextLine], tokens: [Set<String>]) -> Int {
        var boundary = 0
        for index in 0..<min(lines.count, headerScanLimit) where isHeaderLine(lines[index], tokens: tokens[index]) {
            boundary = index + 1
        }
        return boundary
    }

    private static func isHeaderLine(_ line: ReceiptTextLine, tokens: Set<String>) -> Bool {
        if !tokens.isDisjoint(with: headerTokens) { return true }
        let text = line.text
        if matches(rutPattern, text) || matches(datePattern, text) || matches(timePattern, text) { return true }
        if matches(legalEntityPattern, text) { return true }
        return false
    }

    private static func footerBoundary(lines: [ReceiptTextLine], tokens: [Set<String>], from start: Int) -> Int {
        guard start < lines.count else { return lines.count }
        for index in start..<lines.count where !tokens[index].isDisjoint(with: footerTokens) {
            // «TOTAL» sin monto puede ser un encabezado de columna; «GRACIAS» cierra igual.
            if tokens[index].contains("gracias") || trailingAmount(in: lines[index]) != nil {
                return index
            }
        }
        return lines.count
    }

    private static func printedTotal(lines: [ReceiptTextLine], tokens: [Set<String>], from start: Int) -> Double? {
        guard start < lines.count else { return nil }
        var fallback: Double?
        for index in start..<lines.count {
            guard let amount = trailingAmount(in: lines[index])?.value else { continue }
            // «TOTAL NUMERO DE ARTIC VEND 45» lleva «total» pero no es el monto.
            guard tokens[index].isDisjoint(with: itemCountTokens) else { continue }
            if tokens[index].contains("total") && !tokens[index].contains("subtotal") {
                return ReceiptAmount.rounded(amount)
            }
            if tokens[index].contains("subtotal"), fallback == nil {
                fallback = ReceiptAmount.rounded(amount)
            }
        }
        return fallback
    }

    // MARK: Clasificación

    private struct QuantityInfo {
        let count: Int
        let unitPrice: Double?
        let total: Double?
        let isWeight: Bool
        let weight: Double
    }

    private enum LineKind {
        case name(text: String, confidence: Double)
        /// El nombre y un monto en la misma fila. `isReliable` distingue un precio
        /// explícito (`$` o columna derecha propia) de un número suelto que
        /// perfectamente puede ser el gramaje del envase.
        case nameWithAmount(name: String, rawText: String, amount: Double, isReliable: Bool, confidence: Double)
        case amount(Double)
        case quantity(QuantityInfo)
        case discount(Double)
        case noise
    }

    private static func classify(_ line: ReceiptTextLine, tokens: Set<String>) -> LineKind {
        var text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .noise }

        // Un «$» suelto al inicio seguido de espacio y texto no numérico es una
        // marca visual de la boleta («$ Open bar»), no un precio.
        if text.hasPrefix("$"), text.count > 1 {
            let afterDollar = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
            if let first = afterDollar.first, first.isLetter {
                text = afterDollar
            }
        }

        if !tokens.isDisjoint(with: discountTokens), letterWordCount(tokens) <= maximumDiscountWords {
            if let amount = trailingAmount(in: line)?.value {
                return .discount(abs(ReceiptAmount.rounded(amount)))
            }
            return .noise
        }

        // Cualquier línea con monto negativo en el cuerpo de la boleta es un descuento
        // («Open bar -390», «Mercado FFVV -1.383», «JUMBO OFERTAS -1.180», «RF Lleve N x $ -600»).
        if let trailing = trailingAmount(in: line), trailing.value < 0 {
            return .discount(abs(ReceiptAmount.rounded(trailing.value)))
        }

        // Líneas de sección como «Open bar» o «Mercado FFVV» sin monto.
        if isSectionLabel(text) { return .noise }

        if !tokens.isDisjoint(with: noiseTokens) || isHeaderLine(line, tokens: tokens) { return .noise }
        if isContactNoise(line, tokens: tokens) { return .noise }
        if matches(liderPromoPattern, text) { return .noise }

        if let quantity = quantityInfo(in: text) { return .quantity(quantity) }

        if let single = wholeLineAmount(in: line) { return .amount(single) }

        if let trailing = trailingAmount(in: line) {
            let name = cleanName(trailing.name)
            if !name.isEmpty, name.rangeOfCharacter(from: .letters) != nil {
                let amount = ReceiptAmount.rounded(trailing.value)
                let reliable = trailing.hasCurrencySymbol || trailing.isOwnColumn
                if amount >= (reliable ? minimumAmount : bareAmountFloor) {
                    return .nameWithAmount(
                        name: name,
                        rawText: cleanName(text),
                        amount: amount,
                        isReliable: reliable,
                        confidence: line.confidence
                    )
                }
            }
        }

        let name = cleanName(text)
        if name.count >= 2, name.rangeOfCharacter(from: .letters) != nil {
            return .name(text: name, confidence: line.confidence)
        }
        return .noise
    }

    /// Teléfonos, folios y códigos sueltos: filas con a lo más una palabra y un
    /// número largo. El umbral de una palabra deja pasar `7801… ACEITE MARAVILLA`.
    private static func isContactNoise(_ line: ReceiptTextLine, tokens: Set<String>) -> Bool {
        letterWordCount(tokens) <= 1 && matches(longNumberPattern, line.text)
    }

    /// Etiqueta de sección sin monto: «Open bar», «Mercado FFVV».
    private static func isSectionLabel(_ text: String) -> Bool {
        let lowered = text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "$")))
        return sectionLabels.contains(lowered)
    }

    private static func letterWordCount(_ tokens: Set<String>) -> Int {
        tokens.count { $0.contains(where: \.isLetter) }
    }

    // MARK: Recorrido

    private static func walk(_ kinds: [LineKind]) -> [RecognizedReceiptLine] {
        var products: [RecognizedReceiptLine] = []
        var pendingName: String?
        var pendingConfidence: Double = 1
        var pendingAmount: Double?
        var pendingQuantity: QuantityInfo?
        var pendingGap = 0

        func flushPending() {
            if let name = pendingName, let amount = pendingAmount {
                append(&products, name: name, lineTotal: amount, quantity: 1, confidence: pendingConfidence)
            }
            pendingName = nil
            pendingAmount = nil
            pendingConfidence = 1
        }

        for (index, kind) in kinds.enumerated() {
            switch kind {
            case .noise:
                pendingGap += 1
                if pendingGap > maximumPendingGap {
                    flushPending()
                    pendingQuantity = nil
                    pendingGap = 0
                }

            case let .name(text, confidence):
                pendingGap = 0
                if let quantity = pendingQuantity {
                    append(&products, name: text, quantity: quantity, confidence: confidence)
                    pendingQuantity = nil
                } else {
                    flushPending()
                    pendingName = text
                    pendingConfidence = confidence
                }

            case let .nameWithAmount(name, rawText, amount, isReliable, confidence):
                pendingGap = 0
                let next = index + 1 < kinds.count ? kinds[index + 1] : nil

                // Número suelto al final del nombre con un precio real debajo:
                // era el gramaje del envase («LECHE DESCREMADA 1000» / «$990»).
                if !isReliable, isPriceBearing(next) {
                    flushPending()
                    pendingName = rawText
                    pendingConfidence = confidence
                    continue
                }

                if let quantity = pendingQuantity {
                    append(&products, name: name, quantity: quantity, fallbackTotal: amount, confidence: confidence)
                    pendingQuantity = nil
                    continue
                }

                // El total va en la fila del nombre y el desglose por unidad debajo.
                if case .quantity = next {
                    flushPending()
                    pendingName = name
                    pendingAmount = amount
                    pendingConfidence = confidence
                    continue
                }

                flushPending()
                append(&products, name: name, lineTotal: amount, quantity: 1, confidence: confidence)

            case let .amount(value):
                pendingGap = 0
                guard let name = pendingName else { continue }
                if let quantity = pendingQuantity {
                    append(&products, name: name, quantity: quantity, fallbackTotal: value, confidence: pendingConfidence)
                    pendingQuantity = nil
                } else {
                    append(&products, name: name, lineTotal: value, quantity: 1, confidence: pendingConfidence)
                }
                pendingName = nil
                pendingAmount = nil

            case let .quantity(info):
                pendingGap = 0
                if let name = pendingName {
                    append(&products, name: name, quantity: info, fallbackTotal: pendingAmount, confidence: pendingConfidence)
                    pendingName = nil
                    pendingAmount = nil
                } else {
                    pendingQuantity = info
                }

            case let .discount(amount):
                pendingGap = 0
                guard pendingName == nil, let last = products.last, amount < last.lineTotal else { continue }
                products[products.count - 1] = RecognizedReceiptLine(
                    id: last.id,
                    name: last.name,
                    lineTotal: ReceiptAmount.rounded(last.lineTotal - amount),
                    quantity: last.quantity,
                    confidence: last.confidence,
                    hasDiscount: true
                )
            }
        }

        flushPending()
        return products
    }

    private static func isPriceBearing(_ kind: LineKind?) -> Bool {
        switch kind {
        case .amount, .quantity: return true
        default: return false
        }
    }

    private static func append(
        _ products: inout [RecognizedReceiptLine],
        name: String,
        quantity: QuantityInfo,
        fallbackTotal: Double? = nil,
        confidence: Double
    ) {
        // Productos al peso: la boleta cobra el total de la pesada, no unidades.
        if quantity.isWeight {
            let total = quantity.total
                ?? fallbackTotal
                ?? quantity.unitPrice.map { $0 * quantity.weight }
            guard let total else { return }
            append(&products, name: name, lineTotal: total, quantity: 1, confidence: confidence)
            return
        }

        // El total impreso manda: es lo que se cobró y lo que hace cuadrar la suma.
        let total = quantity.total
            ?? fallbackTotal
            ?? quantity.unitPrice.map { $0 * Double(quantity.count) }
        guard let total else { return }
        append(&products, name: name, lineTotal: total, quantity: quantity.count, confidence: confidence)
    }

    private static func append(
        _ products: inout [RecognizedReceiptLine],
        name: String,
        lineTotal: Double,
        quantity: Int,
        confidence: Double
    ) {
        let cleaned = cleanName(name)
        let total = ReceiptAmount.rounded(lineTotal)
        guard cleaned.count >= 2,
              cleaned.rangeOfCharacter(from: .letters) != nil,
              total >= minimumAmount, total < maximumAmount,
              (1...99).contains(quantity)
        else { return }

        products.append(
            RecognizedReceiptLine(name: cleaned, lineTotal: total, quantity: quantity, confidence: confidence)
        )
    }

    // MARK: Utilidades de línea

    private struct TrailingAmount {
        let name: String
        let value: Double
        let hasCurrencySymbol: Bool
        /// El monto venía en una columna derecha propia, separada por una brecha.
        let isOwnColumn: Bool
    }

    private static func trailingAmount(in line: ReceiptTextLine) -> TrailingAmount? {
        // Camino preferente: Vision devolvió el precio como columna aparte.
        if let columns = line.columns,
           let match = firstMatch(amountOnly, in: columns.right),
           let raw = capture(match, 2, in: columns.right),
           let value = ReceiptAmount.value(raw) {
            let prefix = capture(match, 1, in: columns.right) ?? ""
            let isNegative = prefix.contains("-")
            return TrailingAmount(
                name: columns.left,
                value: isNegative ? -value : value,
                hasCurrencySymbol: prefix.contains("$"),
                isOwnColumn: true
            )
        }

        let text = line.text
        guard let match = firstMatch(amountAtEnd, in: text),
              let raw = capture(match, 3, in: text),
              let value = ReceiptAmount.value(raw)
        else { return nil }

        let prefix = capture(match, 2, in: text) ?? ""
        let isNegative = prefix.contains("-")
        return TrailingAmount(
            name: capture(match, 1, in: text) ?? "",
            value: isNegative ? -value : value,
            hasCurrencySymbol: prefix.contains("$"),
            isOwnColumn: false
        )
    }

    private static func wholeLineAmount(in line: ReceiptTextLine) -> Double? {
        let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let match = firstMatch(amountOnly, in: text),
              let raw = capture(match, 2, in: text),
              let value = ReceiptAmount.value(raw)
        else { return nil }

        let prefix = capture(match, 1, in: text) ?? ""
        guard !prefix.contains("-") else { return nil }

        let hasCurrency = prefix.contains("$")
        let amount = ReceiptAmount.rounded(value)
        guard amount >= (hasCurrency ? minimumAmount : bareAmountFloor), amount < maximumAmount else { return nil }
        return amount
    }

    private static func quantityInfo(in text: String) -> QuantityInfo? {
        guard let match = firstMatch(quantityLine, in: text),
              let rawCount = capture(match, 1, in: text)
        else { return nil }

        let numeric = ReceiptAmount.decimalQuantity(rawCount)
        let unit = capture(match, 2, in: text)?.uppercased() ?? ""
        let unitPrice = capture(match, 3, in: text).flatMap(ReceiptAmount.value)
        let total = capture(match, 4, in: text).flatMap(ReceiptAmount.value)

        let weightUnits: Set<String> = ["KG", "KGS", "KL", "KLS", "K", "GR", "GRS", "G"]
        let hasFraction = abs(numeric - numeric.rounded()) > 0.001
        let isWeight = weightUnits.contains(unit) || hasFraction

        let count = max(1, Int(numeric.rounded()))
        guard count <= 99 else { return nil }
        guard unitPrice != nil || total != nil else { return nil }

        return QuantityInfo(
            count: isWeight ? 1 : count,
            unitPrice: unitPrice,
            total: total,
            isWeight: isWeight,
            weight: numeric
        )
    }

    private static func cleanName(_ raw: String) -> String {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if let match = firstMatch(leadingCode, in: name), let range = Range(match.range, in: name) {
            name.removeSubrange(range)
        }
        return name
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "-–—·*|")))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Regex

    private static func matches(_ expression: NSRegularExpression, _ text: String) -> Bool {
        firstMatch(expression, in: text) != nil
    }

    private static func firstMatch(_ expression: NSRegularExpression, in text: String) -> NSTextCheckingResult? {
        expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    }

    private static func capture(_ match: NSTextCheckingResult, _ index: Int, in text: String) -> String? {
        guard index < match.numberOfRanges, let range = Range(match.range(at: index), in: text) else { return nil }
        let value = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
