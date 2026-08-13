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
