import Foundation

/// Un trozo de texto reconocido, con su posición horizontal normalizada (0…1).
/// Vision entrega el nombre y el precio de una misma fila como observaciones
/// distintas cuando la separación entre columnas es amplia; guardar la posición
/// es lo que permite volver a juntarlas y saber cuál número es el precio.
nonisolated struct ReceiptTextFragment: Sendable, Equatable {
    let text: String
    let minX: Double
    let maxX: Double
    let confidence: Double

    init(text: String, minX: Double, maxX: Double, confidence: Double) {
        self.text = text
        self.minX = minX
        self.maxX = maxX
        self.confidence = confidence
    }
}

/// Una fila visual de la boleta, ya reconstruida a partir de sus fragmentos.
nonisolated struct ReceiptTextLine: Sendable {
    let fragments: [ReceiptTextFragment]
    let midY: Double
    let height: Double
    let pageIndex: Int

    init(fragments: [ReceiptTextFragment], midY: Double, height: Double, pageIndex: Int) {
        self.fragments = fragments
        self.midY = midY
        self.height = height
        self.pageIndex = pageIndex
    }

    /// Línea sintética a partir de texto plano (pruebas y entradas sin geometría).
    init(text: String, pageIndex: Int = 0) {
        self.init(
            fragments: [ReceiptTextFragment(text: text, minX: 0, maxX: 1, confidence: 1)],
            midY: 0.5,
            height: 0.02,
            pageIndex: pageIndex
        )
    }

    var text: String {
        fragments.map(\.text).joined(separator: " ")
    }

    var confidence: Double {
        fragments.map(\.confidence).min() ?? 0
    }

    /// Separación en dos columnas cuando existe una brecha horizontal claramente
    /// mayor que el espaciado normal entre palabras. `right` es la columna de
    /// precios en el formato habitual de boleta.
    var columns: (left: String, right: String)? {
        guard fragments.count >= 2 else { return nil }

        var widestGap = 0.0
        var splitIndex = 0
        for index in 1..<fragments.count {
            let gap = fragments[index].minX - fragments[index - 1].maxX
            if gap > widestGap {
                widestGap = gap
                splitIndex = index
            }
        }

        // Una brecha de columna es mucho mayor que un espacio entre palabras:
        // se exige al menos ~1,2 veces la altura del texto y un 3 % del ancho.
        guard splitIndex > 0, widestGap >= max(0.03, height * 1.2) else { return nil }

        return (
            left: fragments[..<splitIndex].map(\.text).joined(separator: " "),
            right: fragments[splitIndex...].map(\.text).joined(separator: " ")
        )
    }
}

/// Reconstruye las filas de la boleta agrupando por bandas horizontales.
/// Se mantiene libre de Vision para poder ejercitarlo en pruebas con datos fijos.
nonisolated enum ReceiptLineAssembler {
    /// Observación cruda: caja normalizada con origen abajo-izquierda (como Vision).
    struct Observation: Sendable {
        let text: String
        let minX: Double
        let maxX: Double
        let minY: Double
        let maxY: Double
        let confidence: Double

        init(text: String, minX: Double, maxX: Double, minY: Double, maxY: Double, confidence: Double) {
            self.text = text
            self.minX = minX
            self.maxX = maxX
            self.minY = minY
            self.maxY = maxY
            self.confidence = confidence
        }

        var height: Double { max(maxY - minY, 0.0001) }
        var midY: Double { (minY + maxY) / 2 }
    }

    /// Observaciones por debajo de esta confianza aportan más ruido que datos.
    static let minimumConfidence = 0.3

    /// Dos observaciones pertenecen a la misma fila si sus cajas se solapan
    /// verticalmente en al menos esta fracción de la más baja de las dos.
    private static let verticalOverlapRatio = 0.4

    static func assemble(_ observations: [Observation], pageIndex: Int = 0) -> [ReceiptTextLine] {
        let usable = observations
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { $0.confidence >= minimumConfidence }
            // Orden total y determinista: de arriba abajo y, a igual altura, de
            // izquierda a derecha. `sorted` no es estable, así que el desempate
            // por X (y por texto) es lo que hace reproducible el resultado.
            .sorted {
                if $0.midY != $1.midY { return $0.midY > $1.midY }
                if $0.minX != $1.minX { return $0.minX < $1.minX }
                return $0.text < $1.text
            }

        guard !usable.isEmpty else { return [] }

        var bands: [[Observation]] = []
        var current: [Observation] = [usable[0]]
        var bandMinY = usable[0].minY
        var bandMaxY = usable[0].maxY

        for observation in usable.dropFirst() {
            let overlap = min(bandMaxY, observation.maxY) - max(bandMinY, observation.minY)
            let threshold = verticalOverlapRatio * min(bandMaxY - bandMinY, observation.height)

            if overlap >= threshold {
                current.append(observation)
                bandMinY = min(bandMinY, observation.minY)
                bandMaxY = max(bandMaxY, observation.maxY)
            } else {
                bands.append(current)
                current = [observation]
                bandMinY = observation.minY
                bandMaxY = observation.maxY
            }
        }
        bands.append(current)

        return bands.map { band in
            let ordered = band.sorted { $0.minX < $1.minX }
            return ReceiptTextLine(
                fragments: ordered.map {
                    ReceiptTextFragment(text: $0.text, minX: $0.minX, maxX: $0.maxX, confidence: $0.confidence)
                },
                midY: ordered.map(\.midY).reduce(0, +) / Double(ordered.count),
                height: ordered.map(\.height).reduce(0, +) / Double(ordered.count),
                pageIndex: pageIndex
            )
        }
    }
}
