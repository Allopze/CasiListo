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

    /// Línea sintética a partir de texto plano (pruebas, entradas sin geometría
    /// y las mitades en que se parte una fila que traía dos cosas juntas).
    init(text: String, confidence: Double = 1, pageIndex: Int = 0) {
        self.init(
            fragments: [ReceiptTextFragment(text: text, minX: 0, maxX: 1, confidence: confidence)],
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

    /// Los fragmentos de una misma fila se reparten el ancho del papel: nunca se
    /// pisan. La holgura absorbe cajas que se rozan en columnas apretadas.
    private static let horizontalOverlapTolerance = 0.02

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

        // Agrupar por afinidad, de la mejor pareja a la peor, en vez de por orden
        // de aparición: recorriendo de arriba abajo, el precio de la columna
        // derecha se enganchaba a la fila de más arriba solo porque esa banda ya
        // existía cuando le tocaba el turno, y toda la boleta quedaba corrida.
        var parent = Array(usable.indices)
        var members: [[Int]] = usable.indices.map { [$0] }

        func root(_ index: Int) -> Int {
            var current = index
            while parent[current] != current {
                parent[current] = parent[parent[current]]
                current = parent[current]
            }
            return current
        }

        var candidates: [(score: Double, lhs: Int, rhs: Int)] = []
        for lhs in usable.indices {
            for rhs in usable.indices where rhs > lhs {
                guard let score = affinity([lhs], [rhs], in: usable) else { continue }
                candidates.append((score, lhs, rhs))
            }
        }
        // El desempate por índice mantiene el resultado reproducible.
        candidates.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.lhs != $1.lhs { return $0.lhs < $1.lhs }
            return $0.rhs < $1.rhs
        }

        for candidate in candidates {
            let lhs = root(candidate.lhs)
            let rhs = root(candidate.rhs)
            // Se revalida sobre las bandas ya formadas: así una fila no crece
            // hasta tragarse a sus vecinas de arriba y de abajo.
            guard lhs != rhs, affinity(members[lhs], members[rhs], in: usable) != nil else { continue }
            parent[rhs] = lhs
            members[lhs] += members[rhs]
            members[rhs] = []
        }

        let bands = usable.indices
            .filter { root($0) == $0 }
            .map { members[$0].map { usable[$0] } }
            .sorted { lhs, rhs in
                let left = lhs.map(\.midY).reduce(0, +) / Double(lhs.count)
                let right = rhs.map(\.midY).reduce(0, +) / Double(rhs.count)
                if left != right { return left > right }
                return (lhs.map(\.minX).min() ?? 0) < (rhs.map(\.minX).min() ?? 0)
            }

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

    /// Cuánto se parecen dos grupos a una misma fila, o `nil` si no pueden serlo.
    ///
    /// Fotografiada en ángulo, una boleta devuelve cajas más altas que la
    /// separación entre sus filas: el producto y el descuento de abajo se solapan
    /// en vertical aunque sean filas distintas. Lo que sí los separa es el eje
    /// horizontal — el precio de una fila no se monta sobre su nombre —, y sin
    /// esa condición las filas se fundían de a seis en una sola ilegible.
    private static func affinity(_ lhs: [Int], _ rhs: [Int], in observations: [Observation]) -> Double? {
        for left in lhs {
            for right in rhs {
                let shared = min(observations[left].maxX, observations[right].maxX)
                    - max(observations[left].minX, observations[right].minX)
                if shared > horizontalOverlapTolerance { return nil }
            }
        }

        let lhsMinY = lhs.map { observations[$0].minY }.min() ?? 0
        let lhsMaxY = lhs.map { observations[$0].maxY }.max() ?? 0
        let rhsMinY = rhs.map { observations[$0].minY }.min() ?? 0
        let rhsMaxY = rhs.map { observations[$0].maxY }.max() ?? 0

        let overlap = min(lhsMaxY, rhsMaxY) - max(lhsMinY, rhsMinY)
        let shorter = min(lhsMaxY - lhsMinY, rhsMaxY - rhsMinY)
        guard shorter > 0 else { return nil }

        let score = overlap / shorter
        return score >= verticalOverlapRatio ? score : nil
    }
}
