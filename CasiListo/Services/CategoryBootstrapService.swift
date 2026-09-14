import Foundation
import SwiftData
import OSLog

/// Servicio que gestiona la inicialización de las categorías por defecto en base de datos
/// y la vinculación ("healer") de productos huérfanos sin relación establecida.
@MainActor
enum CategoryBootstrapService {
    private static let logger = Logger(subsystem: "com.casilisto.app", category: "CategoryBootstrapService")

    /// Inicializa las categorías por defecto y cura las relaciones de productos existentes.
    static func bootstrap(context: ModelContext) throws {
        do {
            // 1. Asegurar la existencia de las categorías por defecto
            let categoryDescriptor = FetchDescriptor<Category>()
            let existingCategories = try context.fetch(categoryDescriptor)

            var categoryMap: [String: Category] = [:]
            for category in existingCategories {
                categoryMap[category.name] = category
            }

            // Si la base de datos está vacía, sembrar las 15 iniciales
            if existingCategories.isEmpty {
                logger.info("Base de datos de categorías vacía. Sembrando categorías iniciales...")
                for defaultCat in DefaultCategory.allCases {
                    let newCat = Category(
                        name: defaultCat.rawValue,
                        sfSymbol: defaultCat.sfSymbol,
                        sortIndex: defaultCat.sortIndex,
                        isSystem: true,
                        defaultCategory: defaultCat
                    )
                    context.insert(newCat)
                    categoryMap[newCat.name] = newCat
                }
                try context.save()
                logger.info("Categorías iniciales sembradas con éxito.")
            } else {
                // Asegurarse de que exista la categoría fallback "Varios"
                if categoryMap["Varios"] == nil {
                    let fallback = Category(name: "Varios", sfSymbol: "bag.fill", sortIndex: 999, isSystem: true, defaultCategory: .varios)
                    context.insert(fallback)
                    categoryMap[fallback.name] = fallback
                    try context.save()
                }
                // Backfill del vínculo estable (CASI-008): los stores de la 1.0
                // no lo tienen. Corre aquí y no en una MigrationStage custom a
                // propósito: el bootstrap se ejecuta en cada arranque, cubre la
                // instalación limpia, el container en memoria y el reseteo de
                // los tests, y un bug tendría segunda oportunidad.
                let linkedNow = backfillDefaultCategoryLinks(in: existingCategories)
                if linkedNow > 0 {
                    try context.save()
                    logger.info("Vínculo con DefaultCategory rellenado en \(linkedNow) categorías del sistema.")
                }

                // Reconciliar sfSymbol con la definición actual de DefaultCategory.
                // Se exige además que el nombre siga siendo el original: una
                // categoría del sistema renombrada y re-simbolizada a propósito
                // no debe ver su icono pisado en cada arranque.
                var sfSymbolsUpdated = false
                for category in existingCategories {
                    if let match = category.defaultCategory,
                       category.name == match.rawValue,
                       category.sfSymbol != match.sfSymbol {
                        category.sfSymbol = match.sfSymbol
                        sfSymbolsUpdated = true
                    }
                }
                if sfSymbolsUpdated {
                    try context.save()
                    logger.info("sfSymbols de categorías actualizados a las definiciones más recientes.")
                }
            }

            // 2. Curar ShoppingItems que no tengan la relación `categoryRelation` establecida
            let itemDescriptor = FetchDescriptor<ShoppingItem>()
            let allItems = try context.fetch(itemDescriptor)
            var itemsCured = 0

            let fallbackCat = categoryMap["Varios"] ?? Category.resolvedFallback(in: context)

            for item in allItems {
                if item.categoryRelation == nil {
                    // Buscar coincidencia por categoryRawValue
                    let match = categoryMap[item.categoryRawValue] ?? fallbackCat
                    item.categoryRelation = match
                    item.categoryRawValue = match.name
                    itemsCured += 1
                }
            }

            // 3. Curar ProductCatalogItems que no tengan la relación `categoryRelation` establecida
            let catalogDescriptor = FetchDescriptor<ProductCatalogItem>()
            let allCatalog = try context.fetch(catalogDescriptor)
            var catalogCured = 0

            for catalogItem in allCatalog {
                if catalogItem.categoryRelation == nil {
                    let match = categoryMap[catalogItem.categoryRawValue] ?? fallbackCat
                    catalogItem.categoryRelation = match
                    catalogItem.categoryRawValue = match.name
                    catalogCured += 1
                }
            }

            if itemsCured > 0 || catalogCured > 0 {
                try context.save()
                logger.info("Relaciones curadas: \(itemsCured) ítems de compras y \(catalogCured) ítems de catálogo vinculados.")
            }

        } catch {
            logger.error("Error durante el bootstrap de categorías: \(error.localizedDescription)")
            throw error
        }
    }

    /// Vincula con su `DefaultCategory` las categorías del sistema que aún no
    /// lo están. Devuelve cuántas vinculó.
    ///
    /// 1. Por nombre exacto: es el caso de toda categoría del sistema que la
    ///    persona no renombró antes de V2.
    /// 2. Por `sfSymbol`, solo si exactamente una `DefaultCategory` todavía
    ///    libre lleva ese símbolo: recupera las renombradas antes de V2 que
    ///    conservaron su icono. Sin rastro se quedan sin vínculo, que es
    ///    exactamente el comportamiento que tenían hasta ahora — nunca peor.
    /// Una categoría creada por la persona (`isSystem == false`) no recibe
    /// vínculo aunque se llame igual que una del sistema borrada.
    @discardableResult
    static func backfillDefaultCategoryLinks(in categories: [Category]) -> Int {
        var taken = Set(categories.compactMap(\.defaultCategory))
        var linked = 0

        let unlinkedSystem = categories.filter { $0.isSystem && $0.defaultCategory == nil }
        for category in unlinkedSystem {
            if let byName = DefaultCategory(rawValue: category.name), !taken.contains(byName) {
                category.defaultCategory = byName
                taken.insert(byName)
                linked += 1
            }
        }

        // La ambigüedad se mira por los dos lados: una sola DefaultCategory
        // libre con ese símbolo, y una sola categoría sin vínculo que lo lleve.
        let stillUnlinked = unlinkedSystem.filter { $0.defaultCategory == nil }
        let unlinkedBySymbol = Dictionary(grouping: stillUnlinked, by: \.sfSymbol)
        for category in stillUnlinked {
            guard unlinkedBySymbol[category.sfSymbol]?.count == 1 else { continue }
            let bySymbol = DefaultCategory.allCases.filter {
                $0.sfSymbol == category.sfSymbol && !taken.contains($0)
            }
            guard bySymbol.count == 1, let match = bySymbol.first else { continue }
            category.defaultCategory = match
            taken.insert(match)
            linked += 1
        }
        return linked
    }
}
