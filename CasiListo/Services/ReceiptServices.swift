import Foundation
import SwiftData
import UIKit
import Vision

/// Una línea de producto detectada en una boleta antes de que el usuario la confirme.
struct RecognizedReceiptLine: Identifiable, Sendable {
    let id: UUID
    let name: String
    let price: Double

    nonisolated init(id: UUID = UUID(), name: String, price: Double) {
        self.id = id
        self.name = name
        self.price = price
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
struct ReceiptPurchaseEntry: Identifiable {
    let id: UUID
    var name: String
    var price: Double
    var associatedItemID: UUID?

    init(id: UUID = UUID(), name: String, price: Double, associatedItemID: UUID? = nil) {
        self.id = id
        self.name = name
        self.price = price
        self.associatedItemID = associatedItemID
    }
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
        guard let imageData = image.jpegData(compressionQuality: 0.96) else {
            throw RecognitionError.unsupportedImage
        }

        return try await Task.detached(priority: .userInitiated) {
            guard let receiptImage = UIImage(data: imageData), let cgImage = receiptImage.cgImage else {
                throw RecognitionError.unsupportedImage
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["es-CL", "es"]

            let handler = VNImageRequestHandler(cgImage: cgImage)
            try handler.perform([request])

            let recognizedText = (request.results ?? [])
                .sorted { $0.boundingBox.midY > $1.boundingBox.midY }
                .compactMap { $0.topCandidates(1).first?.string }

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

private nonisolated enum ReceiptLineParser {
    private static let excludedTerms = [
        "total", "subtotal", "iva", "cambio", "efectivo", "debito", "credito",
        "tarjeta", "vuelto", "boleta", "rut", "cajero", "autorizacion", "folio",
        "fecha", "hora", "articulos", "unidades", "gracias"
    ]

    private static let priceAtEndExpression = try! NSRegularExpression(
        pattern: "^(.*?)(?:\\s+|\\t)\\$?\\s*([0-9]{1,3}(?:[\\.\\s,][0-9]{3})+|[0-9]{3,7})\\s*$",
        options: []
    )

    static func parse(_ lines: [String]) -> [RecognizedReceiptLine] {
        var parsed: [RecognizedReceiptLine] = []
        var seen = Set<String>()

        for line in lines {
            let candidate = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowered = candidate.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
            guard candidate.count > 4, !excludedTerms.contains(where: { lowered.contains($0) }) else { continue }

            let fullRange = NSRange(candidate.startIndex..., in: candidate)
            guard let match = priceAtEndExpression.firstMatch(in: candidate, options: [], range: fullRange),
                  let nameRange = Range(match.range(at: 1), in: candidate),
                  let priceRange = Range(match.range(at: 2), in: candidate)
            else { continue }

            let name = candidate[nameRange]
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            let priceText = String(candidate[priceRange])
            let digits = priceText.filter(\.isNumber)

            guard name.count > 2, name.rangeOfCharacter(from: .letters) != nil,
                  let price = Double(digits), price > 0, price < 1_000_000
            else { continue }

            let key = "\(ProductNameNormalizer.normalize(name))|\(price)"
            guard seen.insert(key).inserted else { continue }
            parsed.append(RecognizedReceiptLine(name: name, price: price))
        }

        return parsed
    }
}

nonisolated enum ProductNameMatcher {
    static func bestMatch(for scannedName: String, in items: [ShoppingItem]) -> ShoppingItem? {
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

@MainActor
enum ReceiptPurchaseService {
    /// Crea una compra histórica independiente y conserva la foto junto a ella.
    /// Los productos asociados se mueven desde la lista activa; los demás se crean
    /// directamente en el historial para que ninguna línea de la boleta se pierda.
    @discardableResult
    static func register(
        entries: [ReceiptPurchaseEntry],
        receiptImage: UIImage,
        store: Store,
        activeList: ShoppingList?,
        allItems: [ShoppingItem],
        categories: [Category],
        context: ModelContext
    ) throws -> ShoppingList {
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
            totalSpent: validEntries.map(\.price).reduce(0, +),
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

        do {
            completedList.purchasedCount = purchaseItems.count
            completedList.totalSpent = purchaseItems.compactMap(\.price).reduce(0, +)
            let currentItems = try context.fetch(FetchDescriptor<ShoppingItem>())
            if let activeList {
                ShoppingListLifecycleService.updateActiveListCounters(activeList, items: currentItems)
            }
            let activeItems = currentItems.filter { $0.listID == activeList?.id }
            try ShoppingPersistenceCoordinator(context: context).commit(itemsForWidget: activeItems)
            return completedList
        } catch {
            context.rollback()
            ReceiptImageStore.delete(named: receiptFilename)
            throw error
        }
    }
}
