import CoreGraphics
import Foundation
import ImageIO
import SwiftData
import UIKit
import Vision

/// Resultado completo de leer una boleta: productos, la tienda reconocida desde
/// su encabezado y el TOTAL impreso, que sirve para avisar si falta alguna línea.
nonisolated struct ReceiptRecognitionResult: Sendable {
    let products: [RecognizedReceiptLine]
    let detectedStoreRawValue: String?
    let printedTotal: Double?
    /// Filas de texto que Vision alcanzó a reconstruir (diagnóstico).
    let recognizedLineCount: Int

    init(
        products: [RecognizedReceiptLine],
        detectedStoreRawValue: String?,
        printedTotal: Double? = nil,
        recognizedLineCount: Int = 0
    ) {
        self.products = products
        self.detectedStoreRawValue = detectedStoreRawValue
        self.printedTotal = printedTotal
        self.recognizedLineCount = recognizedLineCount
    }

    var detectedTotal: Double { products.map(\.lineTotal).reduce(0, +) }
}

/// Entrada ya revisada por la persona. Un producto sin asociación se crea en el historial.
///
/// `lineTotal` es lo que cobró la boleta y manda mientras el usuario no toque la
/// línea: así `3 × $916,67 = $2.750` sigue cuadrando con el papel en vez de
/// convertirse en $2.751 por redondear el unitario. Al editar precio o cantidad
/// el total vuelve a derivarse de ellos, que es lo que la persona espera.
struct ReceiptPurchaseEntry: Identifiable {
    let id: UUID
    var name: String
    var associatedItemID: UUID?
    /// Confianza del reconocimiento (0…1); 1 en las líneas añadidas a mano.
    var confidence: Double
    /// La línea traía un descuento aplicado en la boleta.
    var hasDiscount: Bool

    private var storedPrice: Double
    private var storedQuantity: Int
    private var printedLineTotal: Double?

    var price: Double {
        get { storedPrice }
        set {
            storedPrice = max(0, newValue)
            printedLineTotal = nil
        }
    }

    var quantity: Int {
        get { storedQuantity }
        set {
            storedQuantity = min(99, max(1, newValue))
            printedLineTotal = nil
        }
    }

    var lineTotal: Double { printedLineTotal ?? storedPrice * Double(storedQuantity) }

    init(
        id: UUID = UUID(),
        name: String,
        price: Double,
        quantity: Int = 1,
        associatedItemID: UUID? = nil,
        confidence: Double = 1,
        hasDiscount: Bool = false,
        printedLineTotal: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.storedPrice = max(0, price)
        self.storedQuantity = min(99, max(1, quantity))
        self.associatedItemID = associatedItemID
        self.confidence = confidence
        self.hasDiscount = hasDiscount
        self.printedLineTotal = printedLineTotal
    }

    init(recognized line: RecognizedReceiptLine, associatedItemID: UUID? = nil) {
        self.init(
            name: line.name,
            price: line.unitPrice,
            quantity: line.quantity,
            associatedItemID: associatedItemID,
            confidence: line.confidence,
            hasDiscount: line.hasDiscount,
            printedLineTotal: line.lineTotal
        )
    }
}

// MARK: - Almacenamiento de la foto

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

    /// Calidad de archivo para la foto que queda junto a la compra.
    nonisolated static let archiveQuality: CGFloat = 0.82
    /// Calidad para las páginas que se conservan por si hay que releerlas: más
    /// alta, porque de ahí sale el reconocimiento del reintento.
    nonisolated static let rereadQuality: CGFloat = 0.92

    /// Codificar una boleta larga es lo caro del guardado (la escritura en disco
    /// son milisegundos); es la parte que conviene sacar del hilo principal.
    nonisolated static func encode(_ image: UIImage, quality: CGFloat = archiveQuality) throws -> Data {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw StorageError.couldNotEncodeImage
        }
        return data
    }

    static func save(_ data: Data) throws -> String {
        try LocalFileStore.shared.saveReceiptData(data)
    }

    static func save(_ image: UIImage) throws -> String {
        try save(try encode(image))
    }

    static func image(named filename: String) -> UIImage? {
        guard let url = try? LocalFileStore.shared.receiptURL(named: filename) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    static func delete(named filename: String) {
        try? LocalFileStore.shared.deleteReceipt(named: filename)
    }
}

/// `UIImage` y `CGImage` son inmutables una vez creados y su lectura es segura
/// entre hilos; el envoltorio es solo para cruzar el límite de concurrencia.
nonisolated struct SendableImage: @unchecked Sendable {
    let image: UIImage
    init(_ image: UIImage) { self.image = image }
}

// MARK: - Reconocimiento

/// Reconoce texto localmente con Vision. Conserva la geometría de cada
/// observación para poder reconstruir las filas de la boleta: sin ella el
/// nombre y el precio, que Vision devuelve por separado, quedan desordenados.
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

    /// Página lista para Vision, ya con su orientación resuelta.
    private struct Page: @unchecked Sendable {
        let image: CGImage
        let orientation: CGImagePropertyOrientation
        let index: Int
    }

    static func recognizeReceipt(in image: UIImage) async throws -> ReceiptRecognitionResult {
        try await recognizeReceipt(in: [image])
    }

    /// Reconoce una boleta capturada en una o varias páginas (boletas largas).
    /// Las filas se concatenan en orden de página antes de interpretarlas.
    static func recognizeReceipt(in images: [UIImage]) async throws -> ReceiptRecognitionResult {
        let pages: [Page] = images.enumerated().compactMap { index, image in
            guard let cgImage = image.cgImage else { return nil }
            return Page(image: cgImage, orientation: cgOrientation(image.imageOrientation), index: index)
        }
        // Descartar páginas en silencio deja la foto guardada y los datos
        // desalineados: si alguna no se puede leer, se avisa.
        guard !pages.isEmpty, pages.count == images.count else {
            throw RecognitionError.unsupportedImage
        }

        return try await Task.detached(priority: .userInitiated) {
            try PerformanceSignpost.measureOffMain("Leer boleta") {
            var lines: [ReceiptTextLine] = []

            for page in pages {
                try Task.checkCancellation()

                let request = makeRequest()
                let handler = VNImageRequestHandler(cgImage: page.image, orientation: page.orientation, options: [:])
                try handler.perform([request])

                let observations = (request.results ?? []).compactMap { observation -> ReceiptLineAssembler.Observation? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    let box = observation.boundingBox
                    return ReceiptLineAssembler.Observation(
                        text: candidate.string,
                        minX: box.minX,
                        maxX: box.maxX,
                        minY: box.minY,
                        maxY: box.maxY,
                        confidence: Double(candidate.confidence)
                    )
                }

                lines += ReceiptLineAssembler.assemble(observations, pageIndex: page.index)
            }

            try Task.checkCancellation()
            let parsed = ReceiptLineParser.parse(lines)

            return ReceiptRecognitionResult(
                products: parsed.products,
                detectedStoreRawValue: ReceiptStoreDetector.detectStoreRawValue(in: lines.map(\.text)),
                printedTotal: parsed.printedTotal,
                recognizedLineCount: lines.count
            )
            }
        }.value
    }

    private nonisolated static func makeRequest() -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        // Fijar la revisión evita que el comportamiento del OCR cambie bajo los
        // pies del parser al actualizar el sistema.
        if VNRecognizeTextRequest.supportedRevisions.contains(VNRecognizeTextRequestRevision3) {
            request.revision = VNRecognizeTextRequestRevision3
        }
        request.recognitionLevel = .accurate
        // Las boletas van en abreviaturas («LCH DESLC», «YOG BAT», «DET LIQ»):
        // la corrección de lenguaje las reescribe hacia palabras que no
        // corresponden y también toca los montos.
        request.usesLanguageCorrection = false
        request.recognitionLanguages = supportedLanguages(for: request)
        return request
    }

    /// Vision solo acepta códigos de su lista; `es-CL` no está y pedirlo hacía
    /// que se ignorara toda la configuración de idioma.
    private nonisolated static func supportedLanguages(for request: VNRecognizeTextRequest) -> [String] {
        let preferred = ["es-ES", "en-US"]
        guard let supported = try? request.supportedRecognitionLanguages(), !supported.isEmpty else {
            return ["en-US"]
        }
        let available = preferred.filter(supported.contains)
        return available.isEmpty ? [supported[0]] : available
    }

    /// Las fotos de cámara y biblioteca llegan rotadas por metadatos; sin pasar
    /// la orientación, Vision lee el búfer de lado y el orden de las filas se
    /// desarma.
    private nonisolated static func cgOrientation(_ orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: .up
        case .upMirrored: .upMirrored
        case .down: .down
        case .downMirrored: .downMirrored
        case .left: .left
        case .leftMirrored: .leftMirrored
        case .right: .right
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}

// MARK: - Detección de tienda

/// Busca el supermercado solo en el encabezado de la boleta. Además de la marca
/// se reconoce la razón social y el RUT, porque las boletas chilenas encabezan
/// con «CENCOSUD RETAIL S.A.» o «WALMART CHILE» antes que con el nombre de fantasía.
nonisolated enum ReceiptStoreDetector {
    private static let headerLineLimit = 12

    private static let jumboMarks = ["jumbo", "cencosud", "812010000", "81201000"]
    private static let liderMarks = ["lider", "walmart", "ekono", "867219007", "86721900", "76134941"]

    static func detectStoreRawValue(in recognizedLines: [String]) -> String? {
        let header = recognizedLines.prefix(headerLineLimit)
        let words = Set(
            header
                .flatMap { ProductNameNormalizer.normalize($0).split(separator: " ") }
                .map(String.init)
        )
        // El RUT se compara sin puntos ni guion, sobre los dígitos concatenados.
        let digits = header
            .map { $0.filter(\.isNumber) }
            .joined(separator: " ")

        if matches(jumboMarks, words: words, digits: digits) { return Store.jumbo.rawValue }
        if matches(liderMarks, words: words, digits: digits) { return Store.lider.rawValue }
        return nil
    }

    private static func matches(_ marks: [String], words: Set<String>, digits: String) -> Bool {
        marks.contains { mark in
            mark.allSatisfy(\.isNumber) ? digits.contains(mark) : words.contains(mark)
        }
    }
}

// MARK: - Nombres

/// Los nombres de boleta vienen en mayúsculas y abreviados. Presentarlos tal
/// cual grita en pantalla y no calza con cómo la persona escribe sus productos.
nonisolated enum ReceiptNameFormatter {
    /// Sufijos de formato que se mantienen en mayúscula: «3L», «500ML», «1KG».
    private static let unitPattern = ReceiptAmount.regex("^[0-9]+(ML|MG|GR|G|KG|KL|LT|L|CC|UN|PACK|X[0-9]+)$")

    static func presentable(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        // Solo se reescribe lo que viene todo en mayúsculas: si el texto ya trae
        // minúsculas, es que alguien lo escribió y se respeta.
        guard trimmed == trimmed.uppercased() else { return trimmed }

        return trimmed
            .split(separator: " ")
            .map { word -> String in
                let text = String(word)
                if unitPattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                    return text
                }
                guard text.count > 1, text.contains(where: \.isLetter) else { return text }
                return text.prefix(1) + text.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }
}

// MARK: - Emparejamiento con la lista

nonisolated enum ProductNameMatcher {
    /// Bajo este puntaje la coincidencia es más ruido que ayuda.
    static let minimumScore = 0.55

    /// Asigna cada línea de la boleta a lo sumo un producto de la lista, y cada
    /// producto a lo sumo una línea. Sin esta exclusividad dos líneas parecidas
    /// («Coca Cola 3L» y «Coca Cola 1,5L») apuntan al mismo ítem y la segunda
    /// termina duplicando el producto al guardar.
    static func assign(
        lines: [RecognizedReceiptLine],
        to items: [ShoppingItem]
    ) -> [UUID: UUID] {
        struct Pair {
            let lineID: UUID
            let itemID: UUID
            let score: Double
        }

        let normalizedItems = items.map {
            (id: $0.id, name: ProductNameNormalizer.normalize($0.name), purchased: $0.status == .purchased)
        }

        var pairs: [Pair] = []
        for line in lines {
            let scanned = ProductNameNormalizer.normalize(line.name)
            guard !scanned.isEmpty else { continue }
            for item in normalizedItems where !item.name.isEmpty {
                let score = similarity(scanned, item.name)
                guard score >= minimumScore else { continue }
                // Lo que la persona ya marcó como comprado es el candidato obvio
                // de una boleta: gana los empates sin excluir al resto.
                pairs.append(Pair(lineID: line.id, itemID: item.id, score: item.purchased ? score + 0.15 : score))
            }
        }

        pairs.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.lineID.uuidString < $1.lineID.uuidString
        }

        var assignments: [UUID: UUID] = [:]
        var usedItems = Set<UUID>()
        for pair in pairs where assignments[pair.lineID] == nil && !usedItems.contains(pair.itemID) {
            assignments[pair.lineID] = pair.itemID
            usedItems.insert(pair.itemID)
        }
        return assignments
    }

    /// Los productos marcados como comprados son los candidatos obvios: se
    /// buscan primero y solo si ninguno calza se considera el resto de la lista.
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

        var best: (item: ShoppingItem, score: Double)?
        for item in items {
            let score = similarity(scanned, ProductNameNormalizer.normalize(item.name))
            if score >= minimumScore, score > (best?.score ?? 0) {
                best = (item, score)
            }
        }
        return best?.item
    }

    /// Combina tres señales: palabras en común, contención por palabras
    /// completas y distancia de edición. Esta última es la que rescata los
    /// errores típicos del OCR («LECFE COLUN» → «Leche Colún»).
    static func similarity(_ scanned: String, _ candidate: String) -> Double {
        guard !scanned.isEmpty, !candidate.isEmpty else { return 0 }
        if scanned == candidate { return 1 }

        let scannedTokens = Set(scanned.split(separator: " ").map(String.init))
        let candidateTokens = Set(candidate.split(separator: " ").map(String.init))
        guard !scannedTokens.isEmpty, !candidateTokens.isEmpty else { return 0 }

        let overlap = Double(scannedTokens.intersection(candidateTokens).count)
        let tokenScore = overlap / Double(max(scannedTokens.count, candidateTokens.count))

        // Contención por palabras completas: «te» dentro de «leche» no cuenta.
        let paddedScanned = " \(scanned) "
        let paddedCandidate = " \(candidate) "
        let contained = min(scanned.count, candidate.count) >= 4
            && (paddedScanned.contains(paddedCandidate) || paddedCandidate.contains(paddedScanned))
        let containmentScore = contained ? 0.9 : 0

        let distance = editDistance(scanned, candidate)
        let editScore = 1 - Double(distance) / Double(max(scanned.count, candidate.count))

        return max(tokenScore, containmentScore, editScore >= 0.78 ? editScore : 0)
    }

    static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let source = Array(lhs)
        let target = Array(rhs)
        if source.isEmpty { return target.count }
        if target.isEmpty { return source.count }

        var previous = Array(0...target.count)
        var current = [Int](repeating: 0, count: target.count + 1)

        for i in 1...source.count {
            current[0] = i
            for j in 1...target.count {
                let substitution = previous[j - 1] + (source[i - 1] == target[j - 1] ? 0 : 1)
                current[j] = min(previous[j] + 1, current[j - 1] + 1, substitution)
            }
            swap(&previous, &current)
        }
        return previous[target.count]
    }
}

/// Corrige el nombre leído contra el vocabulario del usuario (su lista, su
/// historial y las sugerencias de la app) cuando la diferencia es claramente
/// un error de lectura y no otro producto.
nonisolated enum ReceiptNameCorrector {
    /// Umbral alto a propósito: preferimos dejar el nombre de la boleta antes
    /// que cambiarlo por un producto distinto.
    private static let minimumScore = 0.8

    static func correct(_ scanned: String, vocabulary: [String]) -> String {
        let normalizedScanned = ProductNameNormalizer.normalize(scanned)
        guard !normalizedScanned.isEmpty, !vocabulary.isEmpty else {
            return ReceiptNameFormatter.presentable(scanned)
        }

        var best: (name: String, score: Double)?
        for candidate in vocabulary {
            let score = ProductNameMatcher.similarity(
                normalizedScanned,
                ProductNameNormalizer.normalize(candidate)
            )
            if score >= minimumScore, score > (best?.score ?? 0) {
                best = (candidate, score)
            }
        }

        return best?.name ?? ReceiptNameFormatter.presentable(scanned)
    }
}

// MARK: - Comparación de precios

struct ReceiptPriceComparison {
    let previousPrice: Double
    let purchaseDate: Date
    let difference: Double

    var percentage: Double {
        guard previousPrice > 0 else { return 0 }
        return (difference / previousPrice) * 100
    }
}

/// Índice de precios por producto y tienda. Construirlo una vez por pantalla
/// evita recorrer todo el historial en cada tecleo de la revisión.
struct ReceiptPriceIndex {
    private let latestByKey: [String: (price: Double, date: Date)]

    init(allItems: [ShoppingItem], completedLists: [ShoppingList]) {
        let completedByID = Dictionary(
            completedLists.map { ($0.id, $0) },
            // Los identificadores no son únicos por esquema: quedarse con el
            // primero es preferible a caer con `uniqueKeysWithValues`.
            uniquingKeysWith: { first, _ in first }
        )

        var index: [String: (price: Double, date: Date)] = [:]
        for item in allItems {
            guard let price = item.price,
                  let listID = item.listID,
                  let list = completedByID[listID]
            else { continue }
            let name = ProductNameNormalizer.normalize(item.name)
            guard !name.isEmpty else { continue }

            let key = "\(name)|\(item.store.rawValue)"
            let date = list.completedAt ?? list.createdAt
            if let existing = index[key], existing.date >= date { continue }
            index[key] = (price, date)
        }
        latestByKey = index
    }

    func comparison(productName: String, newPrice: Double, store: Store) -> ReceiptPriceComparison? {
        let name = ProductNameNormalizer.normalize(productName)
        guard !name.isEmpty, let previous = latestByKey["\(name)|\(store.rawValue)"] else { return nil }
        return ReceiptPriceComparison(
            previousPrice: previous.price,
            purchaseDate: previous.date,
            difference: newPrice - previous.price
        )
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
        ReceiptPriceIndex(allItems: allItems, completedLists: completedLists)
            .comparison(productName: productName, newPrice: newPrice, store: store)
    }
}

// MARK: - Registro de la compra

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
    enum RegistrationError: LocalizedError {
        case noValidEntries

        var errorDescription: String? {
            switch self {
            case .noValidEntries:
                return "Una compra con boleta necesita al menos un producto con nombre y precio."
            }
        }
    }

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
        try register(
            entries: entries,
            receiptFilename: try ReceiptImageStore.save(receiptImage),
            store: store,
            activeList: activeList,
            allItems: allItems,
            categories: categories,
            context: context,
            archivingPurchased: archivingPurchased
        )
    }

    @discardableResult
    static func register(
        entries: [ReceiptPurchaseEntry],
        receiptFilename: String,
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
        // La vista ya lo impide, pero un servicio no debe matar la app por una
        // entrada inválida: se informa y se limpia la foto ya guardada.
        guard !validEntries.isEmpty else {
            ReceiptImageStore.delete(named: receiptFilename)
            throw RegistrationError.noValidEntries
        }

        let now = Date()
        let completedList = ShoppingList(
            title: "Compra \(store.displayName) - \(AppDateFormatting.short(now))",
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

        let itemsByID = Dictionary(allItems.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var usedItemIDs = Set<UUID>()
        var purchaseItems: [ShoppingItem] = []
        var sortOrderByCategory: [String: Int] = [:]

        for entry in validEntries {
            let trimmedName = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let itemID = entry.associatedItemID,
               let existingItem = itemsByID[itemID],
               usedItemIDs.insert(itemID).inserted {
                existingItem.price = entry.price
                existingItem.store = store
                existingItem.status = .purchased
                existingItem.listID = completedList.id
                // Se asigna siempre: si antes decía "2" y la boleta trae una
                // unidad, dejar el valor viejo describe mal la compra.
                existingItem.quantity = entry.quantity > 1 ? "\(entry.quantity)" : ""
                purchaseItems.append(existingItem)
                continue
            }

            let category = SuggestedProducts.suggestedCategory(for: trimmedName, in: categories)
                ?? categories.first(where: { $0.name == "Varios" })
                ?? categories.first
                ?? Category.resolvedFallback(in: context)
            let nextOrder = sortOrderByCategory[category.name, default: 0]
            sortOrderByCategory[category.name] = nextOrder + 1

            let item = ShoppingItem(
                name: trimmedName,
                listID: completedList.id,
                quantity: entry.quantity > 1 ? "\(entry.quantity)" : "",
                category: category,
                isPurchased: true,
                status: .purchased,
                sortOrder: nextOrder,
                price: entry.price,
                store: store
            )
            context.insert(item)
            purchaseItems.append(item)
        }

        // Cierre de compra: archiva los marcados que no tenían línea en la boleta.
        var mergedPurchased: [ShoppingItem] = []
        var otherStoreArchivedCount = 0

        // Sin lista activa no hay nada que cerrar: filtrar por `listID == nil`
        // arrastraría productos huérfanos que no son de esta compra.
        if archivingPurchased, let activeListID = activeList?.id {
            let remainingPurchased = allItems.filter {
                $0.listID == activeListID && $0.status == .purchased && !usedItemIDs.contains($0.id)
            }

            for item in remainingPurchased where item.store == store {
                item.listID = completedList.id
                mergedPurchased.append(item)
            }

            let otherStoreItems = remainingPurchased.filter { $0.store != store }
            let groupedByStore = Dictionary(grouping: otherStoreItems, by: \.store)
            for (otherStore, storeItems) in groupedByStore.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                let storeList = ShoppingList(
                    title: "Compra \(otherStore.displayName) - \(AppDateFormatting.short(now))",
                    completedAt: now,
                    status: .completed,
                    storeScope: otherStore,
                    purchasedCount: storeItems.count,
                    pendingCount: 0,
                    skippedCount: 0,
                    unavailableCount: 0,
                    totalSpent: storeItems.map(lineTotal).reduce(0, +)
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
            let mergedTotal = mergedPurchased.map(lineTotal).reduce(0, +)
            completedList.purchasedCount = purchaseItems.count + mergedPurchased.count
            completedList.totalSpent = entriesTotal + mergedTotal

            let currentItems = try context.fetch(FetchDescriptor<ShoppingItem>())
            if let activeList {
                ShoppingListLifecycleService.updateActiveListCounters(activeList, items: currentItems)
            }
            try ShoppingPersistenceCoordinator(context: context).commit()

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

    /// Total de un producto ya archivado: el precio guardado es unitario, así
    /// que sumarlo sin la cantidad subestima la compra.
    private static func lineTotal(of item: ShoppingItem) -> Double {
        guard let price = item.price else { return 0 }
        let units = Int(item.quantity.trimmingCharacters(in: .whitespaces)) ?? 1
        return price * Double(max(1, units))
    }
}
