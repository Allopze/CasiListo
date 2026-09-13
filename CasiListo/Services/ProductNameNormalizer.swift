import Foundation

/// Fuente única de verdad para comparar y buscar nombres de productos.
/// Conserva palabras separadas para que las coincidencias sean legibles y
/// elimina diferencias accidentales de espacios, mayúsculas y tildes.
nonisolated enum ProductNameNormalizer {
    static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func contains(_ value: String, query: String) -> Bool {
        let normalizedQuery = normalize(query)
        return normalizedQuery.isEmpty || normalize(value).contains(normalizedQuery)
    }
}

/// Limpieza de las líneas que llegan pegadas desde WhatsApp, Notas o Mensajes.
///
/// Vivía como una expresión suelta dentro de `TextImporterSheet.parseText`, así
/// que no había forma de probarla: una lista numerada («1. Leche») perdía el
/// dígito pero conservaba el punto y el producto entraba llamándose «. Leche».
nonisolated enum PastedListParser {
    /// Alternancia, no clase de caracteres: `[-*•\d+\.]` borraba **un** carácter,
    /// así que «1. Leche» conservaba el punto y «10. Pan» perdía solo el «1».
    private static let bulletPattern = #"^\s*(?:[-*•]|\d+[.)])\s*"#

    /// Quita la viñeta o numeración inicial de una línea pegada.
    static func stripBullet(_ line: String) -> String {
        line.replacingOccurrences(of: bulletPattern, with: "", options: .regularExpression)
    }
}

/// La política de duplicados se aplica por nombre normalizado y supermercado.
enum DuplicatePolicy {
    static func key(named name: String, store: Store) -> String {
        "\(ProductNameNormalizer.normalize(name))|\(store.rawValue)"
    }

    static func duplicate(
        named name: String,
        store: Store,
        in items: [ShoppingItem],
        excluding excludedID: UUID? = nil
    ) -> ShoppingItem? {
        guard !ProductNameNormalizer.normalize(name).isEmpty else { return nil }

        return items.first { item in
            item.id != excludedID
                && item.store == store
                && key(named: item.name, store: item.store) == key(named: name, store: store)
        }
    }

    static func isDuplicate(
        named name: String,
        store: Store,
        in items: [ShoppingItem],
        excluding excludedID: UUID? = nil
    ) -> Bool {
        duplicate(named: name, store: store, in: items, excluding: excludedID) != nil
    }
}
