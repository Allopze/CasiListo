import Foundation
import SwiftData
import UIKit
import Vision

/// Una línea de producto detectada en una boleta antes de que el usuario la confirme.
/// `price` es el precio unitario; `quantity` la cantidad detectada (1 si no se indica).
struct RecognizedReceiptLine: Identifiable, Sendable {
    let id: UUID
    let name: String
    let price: Double
    let quantity: Int

    nonisolated init(id: UUID = UUID(), name: String, price: Double, quantity: Int = 1) {
        self.id = id
        self.name = name
        self.price = price
        self.quantity = quantity
    }
}

/// Resultado completo de leer una boleta: productos y la tienda reconocida
/// desde su encabezado cuando Vision logra identificarla.
struct ReceiptRecognitionResult: Sendable {
    let products: [RecognizedReceiptLine]
    let detectedStoreRawValue: String?

    nonisolated init(products: [RecognizedReceiptLine], detectedStoreRawValue: String?) {
        self.products = products
        self.detectedStoreRawValue = detectedStoreRawValue
    }
}

/// Entrada ya revisada por la persona. Un producto sin asociación se crea en el historial.
/// `price` es el precio unitario; el total de la línea es `price * quantity`.
struct ReceiptPurchaseEntry: Identifiable {
    let id: UUID
    var name: String
    var price: Double
    var quantity: Int
    var associatedItemID: UUID?

    init(id: UUID = UUID(), name: String, price: Double, quantity: Int = 1, associatedItemID: UUID? = nil) {
        self.id = id
        self.name = name
        self.price = price
        self.quantity = max(1, quantity)
        self.associatedItemID = associatedItemID
    }

    var lineTotal: Double { price * Double(quantity) }
}

enum ReceiptImageStore {
    enum StorageError: LocalizedError {
        case couldNotEncodeImage

        var errorDescription: String? {
            switch self {
            case .couldNotEncodeImage:
                return "No fue posible preparar la foto de la boleta."
            }
        }
    }

    static func save(_ image: UIImage) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.82) else {
            throw StorageError.couldNotEncodeImage
        }
        return try LocalFileStore.shared.saveReceiptData(data)
    }

    static func image(named filename: String) -> UIImage? {
        guard let url = try? LocalFileStore.shared.receiptURL(named: filename) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    static func delete(named filename: String) {
        try? LocalFileStore.shared.deleteReceipt(named: filename)
    }
}

/// Reconoce texto localmente con Vision. La interpretación de precios se mantiene
/// deliberadamente conservadora: las líneas dudosas se dejan fuera para revisión manual.
enum ReceiptTextRecognitionService {
    enum RecognitionError: LocalizedError {
        case unsupportedImage

        var errorDescription: String? {
            switch self {
            case .unsupportedImage:
                return "No se pudo leer el formato de esta imagen."
            }
        }
    }

    static func recognizeReceipt(in image: UIImage) async throws -> ReceiptRecognitionResult {
        try await recognizeReceipt(in: [image])
    }

    /// Reconoce una boleta capturada en una o varias páginas (boletas largas).
    /// Las líneas se concatenan en orden de página antes de interpretarlas.
    static func recognizeReceipt(in images: [UIImage]) async throws -> ReceiptRecognitionResult {
        let imagesData = images.compactMap { $0.jpegData(compressionQuality: 0.96) }
        guard !imagesData.isEmpty else {
            throw RecognitionError.unsupportedImage
        }

        return try await Task.detached(priority: .userInitiated) {
            var recognizedText: [String] = []

            for imageData in imagesData {
                guard let pageImage = UIImage(data: imageData), let cgImage = pageImage.cgImage else {
                    throw RecognitionError.unsupportedImage
                }

                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["es-CL", "es"]

                let handler = VNImageRequestHandler(cgImage: cgImage)
                try handler.perform([request])

                recognizedText += (request.results ?? [])
                    .sorted { $0.boundingBox.midY > $1.boundingBox.midY }
                    .compactMap { $0.topCandidates(1).first?.string }
            }

            return ReceiptRecognitionResult(
                products: ReceiptLineParser.parse(recognizedText),
                detectedStoreRawValue: ReceiptStoreDetector.detectStoreRawValue(in: recognizedText)
            )
        }.value
    }
}

/// Busca el supermercado solo en las primeras líneas de la boleta, donde se
/// encuentra el encabezado. Así se evita tomar un nombre de tienda que aparezca
/// incidentalmente entre productos o promociones.
nonisolated enum ReceiptStoreDetector {
    private static let headerLineLimit = 12

    static func detectStoreRawValue(in recognizedLines: [String]) -> String? {
        let header = recognizedLines
            .prefix(headerLineLimit)
            .map(ProductNameNormalizer.normalize)
            .joined(separator: " ")

        if header.contains("jumbo") {
            return Store.jumbo.rawValue
        }
        if header.contains("lider") {
            return Store.lider.rawValue
        }
        return nil
    }
}

nonisolated enum ReceiptLineParser {
    private static let excludedTerms = [
        "total", "subtotal", "iva", "cambio", "efectivo", "debito", "credito",
        "tarjeta", "vuelto", "boleta", "rut", "cajero", "autorizacion", "folio",
        "fecha", "hora", "articulos", "unidades", "gracias", "ahorro", "descuento",
        "dcto", "puntos", "propina"
    ]

    /// "PRODUCTO ... $1.290" — nombre y precio en la misma línea.
    private static let priceAtEndExpression = try! NSRegularExpression(
        pattern: "^(.*?)(?:\\s+|\\t)\\$?\\s*([0-9]{1,3}(?:[\\.\\s,][0-9]{3})+|[0-9]{3,7})\\s*$",
        options: []
    )

    /// "2 x $1.290 $2.580" — línea de cantidad bajo el nombre (formato Jumbo/Líder).
    /// Grupo 1: cantidad; grupo 2: precio unitario; grupo 3 (opcional): total.
    private static let quantityLineExpression = try! NSRegularExpression(
        pattern: "^\\s*([0-9]{1,2})\\s*[xX]\\s*\\$?\\s*([0-9]{1,3}(?:[\\.\\s,][0-9]{3})+|[0-9]{1,7})(?:\\s+\\$?\\s*([0-9]{1,3}(?:[\\.\\s,][0-9]{3})+|[0-9]{3,7}))?\\s*$",
        options: []
    )

    /// "$1.290" — solo un precio, bajo la línea del nombre.
    private static let priceOnlyExpression = try! NSRegularExpression(
        pattern: "^\\s*\\$?\\s*([0-9]{1,3}(?:[\\.\\s,][0-9]{3})+|[0-9]{3,7})\\s*$",
        options: []
    )

    /// Código de barras u otro identificador numérico largo al inicio del nombre.
    private static let leadingCodeExpression = try! NSRegularExpression(
        pattern: "^[0-9]{7,}\\s+",
        options: []
    )

    static func parse(_ lines: [String]) -> [RecognizedReceiptLine] {
        var parsed: [RecognizedReceiptLine] = []
        var seen = Set<String>()
        var index = 0

        func appendIfNew(name: String, price: Double, quantity: Int) {
            guard name.count > 2, name.rangeOfCharacter(from: .letters) != nil,
                  price > 0, price < 1_000_000, quantity >= 1, quantity < 100
            else { return }
            let key = "\(ProductNameNormalizer.normalize(name))|\(price)|\(quantity)"
            guard seen.insert(key).inserted else { return }
            parsed.append(RecognizedReceiptLine(name: name, price: price, quantity: quantity))
        }

        while index < lines.count {
            let candidate = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            let lowered = candidate.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
            let fullRange = NSRange(candidate.startIndex..., in: candidate)

            guard candidate.count > 2, !excludedTerms.contains(where: { lowered.contains($0) }) else {
                index += 1
                continue
            }

            // Las líneas de cantidad o precio sin nombre previo no son productos.
            if quantityLineExpression.firstMatch(in: candidate, options: [], range: fullRange) != nil
                || priceOnlyExpression.firstMatch(in: candidate, options: [], range: fullRange) != nil {
                index += 1
                continue
            }

            // Caso 1: nombre y precio en la misma línea.
            if candidate.count > 4,
               let match = priceAtEndExpression.firstMatch(in: candidate, options: [], range: fullRange),
               let nameRange = Range(match.range(at: 1), in: candidate),
               let priceRange = Range(match.range(at: 2), in: candidate) {
                let name = cleanName(String(candidate[nameRange]))
                if let price = parseAmount(String(candidate[priceRange])) {
                    appendIfNew(name: name, price: price, quantity: 1)
                }
                index += 1
                continue
            }

            // Caso 2: línea de nombre seguida de una línea de cantidad o precio.
            let isNameLike = candidate.rangeOfCharacter(from: .letters) != nil
                && priceOnlyExpression.firstMatch(in: candidate, options: [], range: fullRange) == nil
                && quantityLineExpression.firstMatch(in: candidate, options: [], range: fullRange) == nil

            if isNameLike, index + 1 < lines.count {
                let next = lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                let nextRange = NSRange(next.startIndex..., in: next)
                let name = cleanName(candidate)

                if let match = quantityLineExpression.firstMatch(in: next, options: [], range: nextRange),
                   let quantityRange = Range(match.range(at: 1), in: next),
                   let unitRange = Range(match.range(at: 2), in: next) {
                    let quantity = Int(next[quantityRange]) ?? 1
                    var unitPrice = parseAmount(String(next[unitRange]))
                    // Si el total impreso no calza con unitario × cantidad, el total manda.
                    if let totalRange = Range(match.range(at: 3), in: next),
                       let total = parseAmount(String(next[totalRange])),
                       quantity > 0 {
                        let impliedUnit = total / Double(quantity)
                        if unitPrice == nil || abs((unitPrice! * Double(quantity)) - total) > 1 {
                            unitPrice = impliedUnit.rounded()
                        }
                    }
                    if let unitPrice {
                        appendIfNew(name: name, price: unitPrice, quantity: quantity)
                        index += 2
                        continue
                    }
                }

                if let match = priceOnlyExpression.firstMatch(in: next, options: [], range: nextRange),
                   let priceRange = Range(match.range(at: 1), in: next),
                   let price = parseAmount(String(next[priceRange])) {
                    appendIfNew(name: name, price: price, quantity: 1)
                    index += 2
                    continue
                }
            }

            index += 1
        }

        return parsed
    }

    private static func cleanName(_ raw: String) -> String {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let range = NSRange(name.startIndex..., in: name)
        if let match = leadingCodeExpression.firstMatch(in: name, options: [], range: range),
           let matchRange = Range(match.range, in: name) {
            name.removeSubrange(matchRange)
        }
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseAmount(_ text: String) -> Double? {
        let digits = text.filter(\.isNumber)
        guard let value = Double(digits), value > 0, value < 1_000_000 else { return nil }
        return value
    }
}

nonisolated enum ProductNameMatcher {
    /// Los productos que la persona marcó como comprados en esta visita son los
    /// candidatos obvios de una boleta: se buscan primero, y solo si ninguno
    /// calza se considera el resto de la lista.
    static func bestMatch(for scannedName: String, in items: [ShoppingItem]) -> ShoppingItem? {
        let purchased = items.filter { $0.status == .purchased }
        if let match = bestMatch(for: scannedName, among: purchased) {
            return match
        }
        return bestMatch(for: scannedName, among: items.filter { $0.status != .purchased })
    }

    private static func bestMatch(for scannedName: String, among items: [ShoppingItem]) -> ShoppingItem? {
        let scanned = ProductNameNormalizer.normalize(scannedName)
        guard !scanned.isEmpty else { return nil }

        if let exact = items.first(where: { ProductNameNormalizer.normalize($0.name) == scanned }) {
            return exact
        }

        let scannedTokens = Set(scanned.split(separator: " ").map(String.init))
        var best: (item: ShoppingItem, score: Double)?

        for item in items {
            let product = ProductNameNormalizer.normalize(item.name)
            let productTokens = Set(product.split(separator: " ").map(String.init))
            guard !productTokens.isEmpty else { continue }

            let overlap = Double(scannedTokens.intersection(productTokens).count)
            let tokenScore = overlap / Double(max(scannedTokens.count, productTokens.count))
            let containsScore = scanned.contains(product) || product.contains(scanned) ? 0.9 : 0
            let score = max(tokenScore, containsScore)

            if score >= 0.5, score > (best?.score ?? 0) {
                best = (item, score)
            }
        }

        return best?.item
    }
}

struct ReceiptPriceComparison {
    let previousPrice: Double
    let purchaseDate: Date
    let difference: Double

    var percentage: Double {
        guard previousPrice > 0 else { return 0 }
        return (difference / previousPrice) * 100
    }
}

enum ReceiptPriceHistory {
    static func latestComparison(
        productName: String,
        newPrice: Double,
        store: Store,
        allItems: [ShoppingItem],
        completedLists: [ShoppingList]
    ) -> ReceiptPriceComparison? {
        let normalizedName = ProductNameNormalizer.normalize(productName)
        guard !normalizedName.isEmpty else { return nil }

        let completedByID = Dictionary(uniqueKeysWithValues: completedLists.map { ($0.id, $0) })
        let candidate = allItems
            .compactMap { item -> (price: Double, date: Date)? in
                guard item.store == store,
                      ProductNameNormalizer.normalize(item.name) == normalizedName,
                      let price = item.price,
                      let listID = item.listID,
                      let list = completedByID[listID]
                else { return nil }
                return (price, list.completedAt ?? list.createdAt)
            }
            .max { $0.date < $1.date }

        guard let candidate else { return nil }
        return ReceiptPriceComparison(
            previousPrice: candidate.price,
            purchaseDate: candidate.date,
            difference: newPrice - candidate.price
        )
    }
}

/// Resultado de registrar una boleta, para informar a la persona qué ocurrió.
struct ReceiptRegistrationSummary {
    let list: ShoppingList
    /// Productos que venían en la boleta (confirmados en la revisión).
    let receiptProductCount: Int
    /// Marcados como comprados que se archivaron junto a la boleta sin tener línea propia.
    let mergedPurchasedCount: Int
    /// Marcados de otras tiendas archivados en sus propias listas.
    let otherStoreArchivedCount: Int
    let totalSpent: Double
}

@MainActor
enum ReceiptPurchaseService {
    /// Crea una compra histórica y conserva la foto junto a ella. Los productos
    /// asociados se mueven desde la lista activa; los demás se crean directamente
    /// en el historial para que ninguna línea de la boleta se pierda.
    ///
    /// Con `archivingPurchased`, la boleta además cierra la compra: los productos
    /// marcados como comprados que no aparecen en la boleta se archivan también —
    /// los de la misma tienda dentro de esta lista, y los de otras tiendas en su
    /// propia lista por tienda (misma semántica que "Archivar comprados").
    @discardableResult
    static func register(
        entries: [ReceiptPurchaseEntry],
        receiptImage: UIImage,
        store: Store,
        activeList: ShoppingList?,
        allItems: [ShoppingItem],
        categories: [Category],
        context: ModelContext,
        archivingPurchased: Bool = false
    ) throws -> ReceiptRegistrationSummary {
        let validEntries = entries.filter {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.price > 0
        }
        precondition(!validEntries.isEmpty, "Una compra con boleta necesita al menos un producto válido.")

        let receiptFilename = try ReceiptImageStore.save(receiptImage)
        let now = Date()
        let completedList = ShoppingList(
            title: "Compra \(store.displayName) - \(now.formatted(date: .abbreviated, time: .omitted))",
            completedAt: now,
            status: .completed,
            storeScope: store,
            purchasedCount: validEntries.count,
            pendingCount: 0,
            skippedCount: 0,
            unavailableCount: 0,
            totalSpent: validEntries.map(\.lineTotal).reduce(0, +),
            receiptImageFilename: receiptFilename,
            receiptCapturedAt: now
        )
        context.insert(completedList)

        var usedItemIDs = Set<UUID>()
        var purchaseItems: [ShoppingItem] = []

        for entry in validEntries {
            let trimmedName = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let itemID = entry.associatedItemID,
               let existingItem = allItems.first(where: { $0.id == itemID }),
               usedItemIDs.insert(itemID).inserted {
                existingItem.price = entry.price
                existingItem.store = store
                existingItem.status = .purchased
                existingItem.listID = completedList.id
                if entry.quantity > 1 {
                    existingItem.quantity = "\(entry.quantity)"
                }
                purchaseItems.append(existingItem)
                continue
            }

            let category = SuggestedProducts.suggestedCategory(for: trimmedName, in: categories)
                ?? categories.first(where: { $0.name == "Varios" })
                ?? categories.first
                ?? Category.resolvedFallback(in: context)
            let item = ShoppingItem(
                name: trimmedName,
                listID: completedList.id,
                quantity: entry.quantity > 1 ? "\(entry.quantity)" : "",
                category: category,
                isPurchased: true,
                status: .purchased,
                sortOrder: purchaseItems.filter { $0.category.name == category.name }.count,
                price: entry.price,
                store: store
            )
            context.insert(item)
            purchaseItems.append(item)
        }

        // Cierre de compra: archiva los marcados que no tenían línea en la boleta.
        var mergedPurchased: [ShoppingItem] = []
        var otherStoreArchivedCount = 0

        if archivingPurchased {
            let remainingPurchased = allItems.filter {
                $0.listID == activeList?.id && $0.status == .purchased && !usedItemIDs.contains($0.id)
            }

            for item in remainingPurchased where item.store == store {
                item.listID = completedList.id
                mergedPurchased.append(item)
            }

            let otherStoreItems = remainingPurchased.filter { $0.store != store }
            let groupedByStore = Dictionary(grouping: otherStoreItems, by: \.store)
            for (otherStore, storeItems) in groupedByStore {
                let storeList = ShoppingList(
                    title: "Compra \(otherStore.displayName) - \(now.formatted(date: .abbreviated, time: .omitted))",
                    completedAt: now,
                    status: .completed,
                    storeScope: otherStore,
                    purchasedCount: storeItems.count,
                    pendingCount: 0,
                    skippedCount: 0,
                    unavailableCount: 0,
                    totalSpent: storeItems.compactMap(\.price).reduce(0, +)
                )
                context.insert(storeList)
                for item in storeItems {
                    item.listID = storeList.id
                }
                otherStoreArchivedCount += storeItems.count
            }
        }

        do {
            let entriesTotal = validEntries.map(\.lineTotal).reduce(0, +)
            let mergedTotal = mergedPurchased.compactMap(\.price).reduce(0, +)
            completedList.purchasedCount = purchaseItems.count + mergedPurchased.count
            completedList.totalSpent = entriesTotal + mergedTotal

            let currentItems = try context.fetch(FetchDescriptor<ShoppingItem>())
            if let activeList {
                ShoppingListLifecycleService.updateActiveListCounters(activeList, items: currentItems)
            }
            let activeItems = currentItems.filter { $0.listID == activeList?.id }
            try ShoppingPersistenceCoordinator(context: context).commit(itemsForWidget: activeItems)

            return ReceiptRegistrationSummary(
                list: completedList,
                receiptProductCount: purchaseItems.count,
                mergedPurchasedCount: mergedPurchased.count,
                otherStoreArchivedCount: otherStoreArchivedCount,
                totalSpent: completedList.totalSpent
            )
        } catch {
            context.rollback()
            ReceiptImageStore.delete(named: receiptFilename)
            throw error
        }
    }
}
