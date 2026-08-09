import Foundation
import SwiftData
import OSLog

/// Servicio que gestiona la inicialización de las categorías por defecto en base de datos
/// y la vinculación ("healer") de productos huérfanos sin relación establecida.
@MainActor
enum CategoryBootstrapService {
    private static let logger = Logger(subsystem: "com.casilisto.app", category: "CategoryBootstrapService")

    /// Inicializa las categorías por defecto y cura las relaciones de productos existentes.
    static func bootstrap(context: ModelContext) {
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
                UserDefaults.standard.set(false, forKey: "hasSeededDefaultProducts")
                for defaultCat in DefaultCategory.allCases {
                    let newCat = Category(
                        name: defaultCat.rawValue,
                        sfSymbol: defaultCat.sfSymbol,
                        sortIndex: defaultCat.sortIndex,
                        isSystem: true
                    )
                    context.insert(newCat)
                    categoryMap[newCat.name] = newCat
                }
                context.safeSave()
                logger.info("Categorías iniciales sembradas con éxito.")
            } else {
                // Asegurarse de que exista la categoría fallback "Varios"
                if categoryMap["Varios"] == nil {
                    let fallback = Category(name: "Varios", sfSymbol: "bag.fill", sortIndex: 999, isSystem: true)
                    context.insert(fallback)
                    categoryMap[fallback.name] = fallback
                    context.safeSave()
                }
                // Reconciliar sfSymbol con la definición actual de DefaultCategory
                var sfSymbolsUpdated = false
                for category in existingCategories {
                    if let match = DefaultCategory.allCases.first(where: { $0.rawValue == category.name }),
                       category.sfSymbol != match.sfSymbol {
                        category.sfSymbol = match.sfSymbol
                        sfSymbolsUpdated = true
                    }
                }
                if sfSymbolsUpdated {
                    context.safeSave()
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
                context.safeSave()
                logger.info("Relaciones curadas: \(itemsCured) ítems de compras y \(catalogCured) ítems de catálogo vinculados.")
            }
            
        } catch {
            logger.error("Error durante el bootstrap de categorías: \(error.localizedDescription)")
        }
    }
}
