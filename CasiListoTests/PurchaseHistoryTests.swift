import SwiftData
import UIKit
import XCTest
@testable import CasiListo

@MainActor
final class PurchaseHistoryTests: XCTestCase {

    func testStoreDetectorRecognizesSupermarketInReceiptHeader() {
        XCTAssertEqual(
            ReceiptStoreDetector.detectStoreRawValue(in: ["JUMBO", "RUT 81.201.000-0", "PAN HALLULLA 1.200"]),
            Store.jumbo.rawValue
        )
        XCTAssertEqual(
            ReceiptStoreDetector.detectStoreRawValue(in: ["LÍDER", "BOLETA ELECTRÓNICA", "LECHE 990"]),
            Store.lider.rawValue
        )
    }

    /// Las boletas chilenas encabezan con la razón social y el RUT, no con el
    /// nombre de fantasía: buscar solo la marca dejaba la tienda sin detectar.
    func testStoreDetectorRecognizesLegalNameAndTaxID() {
        XCTAssertEqual(
            ReceiptStoreDetector.detectStoreRawValue(in: ["CENCOSUD RETAIL S.A.", "BOLETA ELECTRONICA"]),
            Store.jumbo.rawValue
        )
        XCTAssertEqual(
            ReceiptStoreDetector.detectStoreRawValue(in: ["WALMART CHILE COMERCIAL", "BOLETA ELECTRONICA"]),
            Store.lider.rawValue
        )
        XCTAssertEqual(
            ReceiptStoreDetector.detectStoreRawValue(in: ["SUPERMERCADO", "R.U.T. 81.201.000-K"]),
            Store.jumbo.rawValue
        )
    }

    /// «LIDERAZGO» contiene «lider»: la marca se busca como palabra completa.
    func testStoreDetectorDoesNotMatchPartialWords() {
        XCTAssertNil(ReceiptStoreDetector.detectStoreRawValue(in: ["CURSO DE LIDERAZGO", "BOLETA"]))
    }

    func testStoreDetectorDoesNotInferStoreFromProductLines() {
        let lines = Array(repeating: "Producto sin tienda", count: 12) + ["Oferta JUMBO 2.000"]
        XCTAssertNil(ReceiptStoreDetector.detectStoreRawValue(in: lines))
    }

    func testClosingListCreatesOneHistoricalPurchasePerStore() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeList = ShoppingList(title: "Compra actual")
        let jumboItem = ShoppingItem(
            name: "Pan",
            listID: activeList.id,
            status: .purchased,
            price: 1_200,
            store: .jumbo
        )
        let liderItem = ShoppingItem(
            name: "Leche",
            listID: activeList.id,
            status: .purchased,
            price: 990,
            store: .lider
        )
        let pendingItem = ShoppingItem(name: "Huevos", listID: activeList.id, status: .pending)
        context.insert(activeList)
        [jumboItem, liderItem, pendingItem].forEach { context.insert($0) }

        try ShoppingListLifecycleService.archivePurchasedItems(
            from: [jumboItem, liderItem, pendingItem],
            activeList: activeList,
            context: context
        )

        let completedLists = try context.fetch(FetchDescriptor<ShoppingList>())
            .filter { $0.status == .completed }
        XCTAssertEqual(completedLists.count, 2)

        let jumboPurchase = completedLists.first { $0.storeScope == .jumbo }
        XCTAssertEqual(jumboPurchase?.purchasedCount, 1)
        XCTAssertEqual(jumboPurchase?.totalSpent, 1_200)
        XCTAssertNotNil(jumboPurchase?.completedAt)
        XCTAssertEqual(jumboItem.listID, jumboPurchase?.id)

        let liderPurchase = completedLists.first { $0.storeScope == .lider }
        XCTAssertEqual(liderPurchase?.purchasedCount, 1)
        XCTAssertEqual(liderPurchase?.totalSpent, 990)
        XCTAssertNotNil(liderPurchase?.completedAt)
        XCTAssertEqual(liderItem.listID, liderPurchase?.id)
        XCTAssertEqual(pendingItem.listID, activeList.id)
    }

    func testClosingListKeepsPurchaseWithoutPrices() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeList = ShoppingList(title: "Compra actual")
        let item = ShoppingItem(name: "Pan", listID: activeList.id, status: .purchased, store: .jumbo)
        context.insert(activeList)
        context.insert(item)

        try ShoppingListLifecycleService.archivePurchasedItems(
            from: [item],
            activeList: activeList,
            context: context
        )

        let completedPurchase = try context.fetch(FetchDescriptor<ShoppingList>())
            .first { $0.status == .completed }
        XCTAssertEqual(completedPurchase?.purchasedCount, 1)
        XCTAssertEqual(completedPurchase?.totalSpent, 0)
        XCTAssertEqual(completedPurchase?.storeScope, .jumbo)
    }

    func testClosingListWithoutPurchasedProductsDoesNotCreateHistory() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeList = ShoppingList(title: "Compra actual")
        let pendingItem = ShoppingItem(name: "Pan", listID: activeList.id, status: .pending)
        context.insert(activeList)
        context.insert(pendingItem)

        try ShoppingListLifecycleService.archivePurchasedItems(
            from: [pendingItem],
            activeList: activeList,
            context: context
        )

        let completedLists = try context.fetch(FetchDescriptor<ShoppingList>())
            .filter { $0.status == .completed }
        XCTAssertTrue(completedLists.isEmpty)
        XCTAssertEqual(pendingItem.listID, activeList.id)
    }

    func testReceiptPurchaseCreatesHistoryWithPhotoAndConfirmedPrice() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeList = ShoppingList(title: "Compra actual")
        let item = ShoppingItem(name: "Leche", listID: activeList.id, status: .pending, store: .lider)
        context.insert(activeList)
        context.insert(item)

        let purchase = try ReceiptPurchaseService.register(
            entries: [ReceiptPurchaseEntry(name: "Leche", price: 1_490, associatedItemID: item.id)],
            receiptImage: receiptImage(),
            store: .lider,
            activeList: activeList,
            allItems: [item],
            categories: [],
            context: context
        ).list
        defer {
            if let filename = purchase.receiptImageFilename {
                ReceiptImageStore.delete(named: filename)
            }
        }

        XCTAssertEqual(purchase.status, .completed)
        XCTAssertEqual(purchase.storeScope, .lider)
        XCTAssertEqual(purchase.purchasedCount, 1)
        XCTAssertEqual(purchase.totalSpent, 1_490)
        XCTAssertNotNil(purchase.receiptImageFilename)
        XCTAssertNotNil(purchase.receiptCapturedAt)
        XCTAssertNotNil(purchase.receiptImageFilename.flatMap { ReceiptImageStore.image(named: $0) })
        XCTAssertEqual(item.listID, purchase.id)
        XCTAssertEqual(item.status, .purchased)
        XCTAssertEqual(item.price, 1_490)
    }

    func testPriceComparisonUsesMostRecentPurchaseAtSameStore() {
        let oldest = ShoppingList(
            title: "Compra Jumbo",
            createdAt: .now.addingTimeInterval(-14_400),
            completedAt: .now.addingTimeInterval(-14_400),
            status: .completed,
            storeScope: .jumbo
        )
        let latest = ShoppingList(
            title: "Compra Jumbo",
            createdAt: .now.addingTimeInterval(-7_200),
            completedAt: .now.addingTimeInterval(-7_200),
            status: .completed,
            storeScope: .jumbo
        )
        let otherStore = ShoppingList(
            title: "Compra Líder",
            createdAt: .now.addingTimeInterval(-3_600),
            completedAt: .now.addingTimeInterval(-3_600),
            status: .completed,
            storeScope: .lider
        )
        let items = [
            ShoppingItem(name: "Leche entera", listID: oldest.id, price: 1_000, store: .jumbo),
            ShoppingItem(name: "Leche entera", listID: latest.id, price: 1_200, store: .jumbo),
            ShoppingItem(name: "Leche entera", listID: otherStore.id, price: 800, store: .lider)
        ]

        let comparison = ReceiptPriceHistory.latestComparison(
            productName: "LECHE ENTERA",
            newPrice: 1_350,
            store: .jumbo,
            allItems: items,
            completedLists: [oldest, latest, otherStore]
        )

        XCTAssertEqual(comparison?.previousPrice, 1_200)
        XCTAssertEqual(comparison?.difference, 150)
        XCTAssertEqual(comparison?.percentage ?? -1, 12.5, accuracy: 0.001)
    }

    // MARK: - Reconstrucción de filas

    /// Vision devuelve el nombre y el precio de una fila como observaciones
    /// distintas, y ordenadas por altura se intercalan las dos columnas. Este es
    /// el caso que el parser tiene que resolver antes que ningún otro.
    func testAssemblerRebuildsRowsFromSeparateColumnObservations() {
        let lines = ReceiptLineAssembler.assemble([
            observation("990", row: 1, minX: 0.84, maxX: 0.95),
            observation("PAN MARRAQUETA", row: 0, minX: 0.05, maxX: 0.45),
            observation("LCH DESLC COLUN 1L", row: 1, minX: 0.05, maxX: 0.50),
            observation("1.250", row: 0, minX: 0.80, maxX: 0.95)
        ])

        XCTAssertEqual(lines.map(\.text), ["PAN MARRAQUETA 1.250", "LCH DESLC COLUN 1L 990"])
        XCTAssertEqual(lines.first?.columns?.left, "PAN MARRAQUETA")
        XCTAssertEqual(lines.first?.columns?.right, "1.250")
    }

    func testAssemblerOrderIsStableRegardlessOfObservationOrder() {
        let observations = [
            observation("PAN", row: 0, minX: 0.05, maxX: 0.30),
            observation("1.250", row: 0, minX: 0.80, maxX: 0.95),
            observation("LECHE", row: 1, minX: 0.05, maxX: 0.30),
            observation("990", row: 1, minX: 0.84, maxX: 0.95)
        ]
        let expected = ReceiptLineAssembler.assemble(observations).map(\.text)

        XCTAssertEqual(ReceiptLineAssembler.assemble(observations.reversed()).map(\.text), expected)
        XCTAssertEqual(ReceiptLineAssembler.assemble(observations.shuffled()).map(\.text), expected)
    }

    func testAssemblerDropsLowConfidenceObservations() {
        let lines = ReceiptLineAssembler.assemble([
            observation("PAN MARRAQUETA", row: 0, minX: 0.05, maxX: 0.45),
            observation("|||", row: 0, minX: 0.50, maxX: 0.60, confidence: 0.1)
        ])

        XCTAssertEqual(lines.map(\.text), ["PAN MARRAQUETA"])
    }

    // MARK: - Parser de líneas de boleta

    func testParserReadsSameLineAndTwoLineFormats() {
        let lines = [
            "JUMBO SPA",
            "BOLETA ELECTRONICA",
            "PAN MARRAQUETA 1.250",
            "COCA COLA ZERO 3L",
            "2 x $1.990 $3.980",
            "LECHE COLUN 1L",
            "$990",
            "AHORRO SOCIO 500",
            "TOTAL 7.210"
        ]

        let parsed = ReceiptLineParser.parse(lines)

        XCTAssertEqual(parsed.count, 3)

        XCTAssertEqual(parsed[0].name, "PAN MARRAQUETA")
        XCTAssertEqual(parsed[0].lineTotal, 1_250)
        XCTAssertEqual(parsed[0].quantity, 1)

        XCTAssertEqual(parsed[1].name, "COCA COLA ZERO 3L")
        XCTAssertEqual(parsed[1].lineTotal, 3_980)
        XCTAssertEqual(parsed[1].quantity, 2)
        XCTAssertEqual(parsed[1].unitPrice, 1_990)

        // «AHORRO SOCIO» es el resumen de la compra, no una rebaja de la leche.
        XCTAssertEqual(parsed[2].name, "LECHE COLUN 1L")
        XCTAssertEqual(parsed[2].lineTotal, 990)
        XCTAssertEqual(parsed[2].quantity, 1)
    }

    /// Vision normaliza la `x` mecanografiada al signo `×` (U+00D7): con la clase
    /// de caracteres anterior toda la lógica de cantidades quedaba muerta.
    func testParserReadsUnicodeMultiplicationSign() {
        let parsed = ReceiptLineParser.parse(["BOLETA ELECTRONICA", "COCA COLA ZERO 3L", "2 \u{00D7} $1.990 $3.980"])

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].quantity, 2)
        XCTAssertEqual(parsed[0].lineTotal, 3_980)
    }

    func testParserReadsQuantityPrintedBeforeTheName() {
        let parsed = ReceiptLineParser.parse(["BOLETA ELECTRONICA", "2 UN \u{00D7} $1.990 $3.980", "COCA COLA ZERO 3L"])

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].name, "COCA COLA ZERO 3L")
        XCTAssertEqual(parsed[0].quantity, 2)
    }

    /// Productos al peso: la boleta cobra el total de la pesada, no unidades.
    func testParserReadsWeightedItemsAsASingleLine() {
        let parsed = ReceiptLineParser.parse(["BOLETA ELECTRONICA", "PALTA HASS", "0,860 KG X $6.990/KG $6.011"])

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].name, "PALTA HASS")
        XCTAssertEqual(parsed[0].quantity, 1)
        XCTAssertEqual(parsed[0].lineTotal, 6_011)
    }

    func testParserKeepsPrintedLineTotalWhenUnitDoesNotDivideEvenly() {
        let parsed = ReceiptLineParser.parse(["BOLETA ELECTRONICA", "YOGURT GRIEGO", "3 x $1.000 $2.750"])

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].quantity, 3)
        // Antes se guardaba el unitario redondeado y la línea pasaba a valer
        // $2.751: el total impreso deja de cuadrar con la boleta.
        XCTAssertEqual(parsed[0].lineTotal, 2_750)
    }

    /// «OLIVA» contiene «iva» y «FRUTILLA» contiene «rut»: buscar los términos
    /// excluidos como subcadena borraba productos perfectamente válidos.
    func testParserKeepsProductsThatContainExcludedTermsAsSubstrings() {
        let parsed = ReceiptLineParser.parse([
            "BOLETA ELECTRONICA",
            "ACEITE DE OLIVA 500ML", "$5.990",
            "YOGURT FRUTILLA", "$690",
            "FRUTOS SECOS MIX 2.490",
            "TOTAL 9.170"
        ])

        XCTAssertEqual(parsed.map(\.name), ["ACEITE DE OLIVA 500ML", "YOGURT FRUTILLA", "FRUTOS SECOS MIX"])
    }

    /// El gramaje del envase queda al final del nombre y se leía como precio,
    /// consumiendo la fila y descartando el precio real de la línea siguiente.
    func testParserDoesNotMistakePackageSizeForPrice() {
        let parsed = ReceiptLineParser.parse(["BOLETA ELECTRONICA", "LECHE DESCREMADA 1000", "$990"])

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].name, "LECHE DESCREMADA 1000")
        XCTAssertEqual(parsed[0].lineTotal, 990)
    }

    /// Dos unidades pasadas por separado son dos líneas: colapsarlas por tener
    /// el mismo nombre y precio dejaba la compra por debajo de lo pagado.
    func testParserKeepsRepeatedIdenticalLines() {
        let parsed = ReceiptLineParser.parse([
            "BOLETA ELECTRONICA", "PAN MARRAQUETA 1.250", "PAN MARRAQUETA 1.250", "TOTAL 2.500"
        ])

        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed.map(\.lineTotal).reduce(0, +), 2_500)
    }

    func testParserSubtractsPerLineDiscounts() {
        let parsed = ReceiptLineParser.parse([
            "BOLETA ELECTRONICA", "DETERGENTE OMO 3L", "$8.990", "DCTO SOCIO 1.000", "TOTAL 7.990"
        ])

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].lineTotal, 7_990)
        XCTAssertTrue(parsed[0].hasDiscount)
    }

    func testParserIgnoresAddressesPhonesAndIdentifiers() {
        let parsed = ReceiptLineParser.parse([
            "JUMBO KENNEDY", "AV PROVIDENCIA 1234", "FONO 226001234", "RUT 81.201.000-K",
            "PAN HALLULLA 1.250", "TOTAL 1.250"
        ])

        XCTAssertEqual(parsed.map(\.name), ["PAN HALLULLA"])
    }

    func testParserStripsLeadingBarcodeFromName() {
        let parsed = ReceiptLineParser.parse(["BOLETA ELECTRONICA", "7801610001234 ACEITE MARAVILLA 2.590"])

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].name, "ACEITE MARAVILLA")
        XCTAssertEqual(parsed[0].lineTotal, 2_590)
    }

    func testParserIgnoresOrphanQuantityAndDiscountLines() {
        let parsed = ReceiptLineParser.parse(["2 x $1.990 $3.980", "$5.000", "DESCUENTO 900"])

        XCTAssertTrue(parsed.isEmpty)
    }

    func testParserReportsPrintedTotalForReconciliation() {
        let result = ReceiptLineParser.parse([
            "BOLETA ELECTRONICA", "PAN 1.250", "LECHE 990", "SUBTOTAL 2.240", "TOTAL 2.240"
        ].map { ReceiptTextLine(text: $0) })

        XCTAssertEqual(result.printedTotal, 2_240)
        XCTAssertEqual(result.products.map(\.lineTotal).reduce(0, +), 2_240)
    }

    func testParserReadsAmountsInChileanFormat() {
        XCTAssertEqual(ReceiptAmount.value("$1.290"), 1_290)
        XCTAssertEqual(ReceiptAmount.value("12.500"), 12_500)
        XCTAssertEqual(ReceiptAmount.value("1 290"), 1_290)
        XCTAssertEqual(ReceiptAmount.value("990"), 990)
        XCTAssertEqual(ReceiptAmount.value("1290,50"), 1_290.5)
        XCTAssertNil(ReceiptAmount.value("KG"))
    }

    // MARK: - Matching contra la lista

    func testMatcherPrefersPurchasedItemsOverPending() {
        let purchased = ShoppingItem(name: "Coca Cola", status: .purchased, store: .jumbo)
        let pending = ShoppingItem(name: "Coca Cola Zero", status: .pending, store: .jumbo)

        let match = ProductNameMatcher.bestMatch(for: "COCA COLA", in: [pending, purchased])

        XCTAssertEqual(match?.id, purchased.id)
    }

    func testMatcherFallsBackToPendingWhenNoPurchasedMatches() {
        let purchased = ShoppingItem(name: "Detergente", status: .purchased, store: .jumbo)
        let pending = ShoppingItem(name: "Coca Cola", status: .pending, store: .jumbo)

        let match = ProductNameMatcher.bestMatch(for: "COCA COLA", in: [pending, purchased])

        XCTAssertEqual(match?.id, pending.id)
    }

    /// Sin exclusividad, dos líneas parecidas apuntan al mismo producto y la
    /// segunda termina duplicándolo al guardar.
    func testMatcherAssignsEachListItemToAtMostOneReceiptLine() {
        let cocaCola = ShoppingItem(name: "Coca Cola", status: .purchased, store: .jumbo)
        let lines = [
            RecognizedReceiptLine(name: "COCA COLA", lineTotal: 1_990),
            RecognizedReceiptLine(name: "COCA COLA ZERO", lineTotal: 2_190)
        ]

        let assignments = ProductNameMatcher.assign(lines: lines, to: [cocaCola])

        XCTAssertEqual(assignments.count, 1)
        XCTAssertEqual(assignments[lines[0].id], cocaCola.id)
        XCTAssertNil(assignments[lines[1].id])
    }

    func testMatcherRecoversFromSingleCharacterOCRErrors() {
        let item = ShoppingItem(name: "Detergente", status: .purchased, store: .jumbo)

        XCTAssertEqual(ProductNameMatcher.bestMatch(for: "DETERGEMTE", in: [item])?.id, item.id)
        XCTAssertNil(ProductNameMatcher.bestMatch(for: "MANTEQUILLA", in: [item]))
    }

    /// Contención por palabras completas: «té» dentro de «leche» no es una
    /// coincidencia, aunque la subcadena exista.
    func testMatcherDoesNotMatchShortSubstrings() {
        let leche = ShoppingItem(name: "Leche", status: .purchased, store: .jumbo)

        XCTAssertNil(ProductNameMatcher.bestMatch(for: "TE", in: [leche]))
    }

    // MARK: - Presentación de nombres

    func testNameFormatterSoftensAllCapsButKeepsFormats() {
        XCTAssertEqual(ReceiptNameFormatter.presentable("PAN MARRAQUETA"), "Pan Marraqueta")
        XCTAssertEqual(ReceiptNameFormatter.presentable("COCA COLA ZERO 3L"), "Coca Cola Zero 3L")
        XCTAssertEqual(ReceiptNameFormatter.presentable("Leche descremada"), "Leche descremada")
    }

    func testNameCorrectorUsesTheUserVocabularyOnlyForClearMisreads() {
        let vocabulary = ["Detergente Omo", "Leche descremada"]

        XCTAssertEqual(ReceiptNameCorrector.correct("DETERGENTE OMO", vocabulary: vocabulary), "Detergente Omo")
        XCTAssertEqual(ReceiptNameCorrector.correct("PAN MARRAQUETA", vocabulary: vocabulary), "Pan Marraqueta")
    }

    // MARK: - Línea revisada

    /// El total impreso manda mientras nadie toque la línea; al editarla vuelve
    /// a derivarse del precio y la cantidad, que es lo que la persona espera.
    func testEntryKeepsPrintedTotalUntilItIsEdited() {
        var entry = ReceiptPurchaseEntry(
            recognized: RecognizedReceiptLine(name: "Yogurt", lineTotal: 2_750, quantity: 3)
        )
        XCTAssertEqual(entry.lineTotal, 2_750)

        entry.price = 1_000
        XCTAssertEqual(entry.lineTotal, 3_000)
    }

    func testEntryClampsQuantityToTheEditableRange() {
        var entry = ReceiptPurchaseEntry(name: "Pan", price: 500)
        entry.quantity = 0
        XCTAssertEqual(entry.quantity, 1)
        entry.quantity = 500
        XCTAssertEqual(entry.quantity, 99)
    }

    // MARK: - Cierre de compra con boleta

    func testReceiptClosingArchivesPurchasedItemsAlongsideReceipt() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeList = ShoppingList(title: "Compra actual")
        let scannedItem = ShoppingItem(name: "Leche", listID: activeList.id, status: .purchased, store: .jumbo)
        let unscannedSameStore = ShoppingItem(name: "Pan", listID: activeList.id, status: .purchased, price: 1_200, store: .jumbo)
        let otherStorePurchased = ShoppingItem(name: "Queso", listID: activeList.id, status: .purchased, price: 3_500, store: .lider)
        let pendingItem = ShoppingItem(name: "Huevos", listID: activeList.id, status: .pending, store: .jumbo)
        context.insert(activeList)
        [scannedItem, unscannedSameStore, otherStorePurchased, pendingItem].forEach { context.insert($0) }

        let summary = try ReceiptPurchaseService.register(
            entries: [
                ReceiptPurchaseEntry(name: "Leche", price: 1_490, associatedItemID: scannedItem.id),
                ReceiptPurchaseEntry(name: "Galletas", price: 890, quantity: 2)
            ],
            receiptImage: receiptImage(),
            store: .jumbo,
            activeList: activeList,
            allItems: [scannedItem, unscannedSameStore, otherStorePurchased, pendingItem],
            categories: [],
            context: context,
            archivingPurchased: true
        )
        defer {
            if let filename = summary.list.receiptImageFilename {
                ReceiptImageStore.delete(named: filename)
            }
        }

        // La lista de la boleta: 2 líneas + 1 marcado de la misma tienda fusionado.
        XCTAssertEqual(summary.receiptProductCount, 2)
        XCTAssertEqual(summary.mergedPurchasedCount, 1)
        XCTAssertEqual(summary.otherStoreArchivedCount, 1)
        XCTAssertEqual(summary.list.purchasedCount, 3)
        // Total: 1.490 + (890 × 2) + 1.200 del pan fusionado.
        XCTAssertEqual(summary.list.totalSpent, 1_490 + 1_780 + 1_200)
        XCTAssertEqual(scannedItem.listID, summary.list.id)
        XCTAssertEqual(unscannedSameStore.listID, summary.list.id)

        // El comprado de la otra tienda queda en su propia compra completada.
        let completedLists = try context.fetch(FetchDescriptor<ShoppingList>())
            .filter { $0.status == .completed }
        XCTAssertEqual(completedLists.count, 2)
        let liderList = completedLists.first { $0.storeScope == .lider }
        XCTAssertEqual(otherStorePurchased.listID, liderList?.id)
        XCTAssertEqual(liderList?.totalSpent, 3_500)

        // Lo pendiente no se toca.
        XCTAssertEqual(pendingItem.listID, activeList.id)
        XCTAssertEqual(pendingItem.status, .pending)
    }

    func testReceiptWithoutClosingLeavesPurchasedItemsInActiveList() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeList = ShoppingList(title: "Compra actual")
        let purchasedItem = ShoppingItem(name: "Pan", listID: activeList.id, status: .purchased, store: .jumbo)
        context.insert(activeList)
        context.insert(purchasedItem)

        let summary = try ReceiptPurchaseService.register(
            entries: [ReceiptPurchaseEntry(name: "Galletas", price: 890)],
            receiptImage: receiptImage(),
            store: .jumbo,
            activeList: activeList,
            allItems: [purchasedItem],
            categories: [],
            context: context
        )
        defer {
            if let filename = summary.list.receiptImageFilename {
                ReceiptImageStore.delete(named: filename)
            }
        }

        XCTAssertEqual(summary.mergedPurchasedCount, 0)
        XCTAssertEqual(purchasedItem.listID, activeList.id)
    }

    /// Antes esto era un `precondition`: una entrada inválida mataba la app en
    /// el punto donde la foto ya se había escrito a disco.
    func testRegisterThrowsInsteadOfCrashingWithoutValidEntries() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let filename = try ReceiptImageStore.save(receiptImage())

        XCTAssertThrowsError(
            try ReceiptPurchaseService.register(
                entries: [ReceiptPurchaseEntry(name: "  ", price: 0)],
                receiptFilename: filename,
                store: .jumbo,
                activeList: nil,
                allItems: [],
                categories: [],
                context: context
            )
        )
        // La foto huérfana se limpia al rechazar la compra.
        XCTAssertNil(ReceiptImageStore.image(named: filename))
    }

    /// El precio guardado es unitario: sumarlo sin la cantidad subestimaba el
    /// total de los productos archivados junto a la boleta.
    func testArchivedItemsContributeTheirFullLineTotal() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeList = ShoppingList(title: "Compra actual")
        let mergedItem = ShoppingItem(
            name: "Pan",
            listID: activeList.id,
            quantity: "3",
            status: .purchased,
            price: 1_200,
            store: .jumbo
        )
        context.insert(activeList)
        context.insert(mergedItem)

        let summary = try ReceiptPurchaseService.register(
            entries: [ReceiptPurchaseEntry(name: "Leche", price: 1_490)],
            receiptImage: receiptImage(),
            store: .jumbo,
            activeList: activeList,
            allItems: [mergedItem],
            categories: [],
            context: context,
            archivingPurchased: true
        )
        defer {
            if let filename = summary.list.receiptImageFilename {
                ReceiptImageStore.delete(named: filename)
            }
        }

        XCTAssertEqual(summary.totalSpent, 1_490 + 3_600)
    }

    /// Sin lista activa, filtrar por `listID == nil` arrastraba productos
    /// huérfanos que no pertenecen a esta compra.
    func testClosingWithoutActiveListDoesNotArchiveOrphanItems() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let orphan = ShoppingItem(name: "Queso", status: .purchased, price: 3_500, store: .jumbo)
        context.insert(orphan)

        let summary = try ReceiptPurchaseService.register(
            entries: [ReceiptPurchaseEntry(name: "Leche", price: 1_490)],
            receiptImage: receiptImage(),
            store: .jumbo,
            activeList: nil,
            allItems: [orphan],
            categories: [],
            context: context,
            archivingPurchased: true
        )
        defer {
            if let filename = summary.list.receiptImageFilename {
                ReceiptImageStore.delete(named: filename)
            }
        }

        XCTAssertEqual(summary.mergedPurchasedCount, 0)
        XCTAssertNil(orphan.listID)
    }

    /// Si la boleta trae una unidad, dejar el "2" viejo describe mal la compra.
    func testAssociatedItemQuantityIsResetWhenTheReceiptSaysOne() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let activeList = ShoppingList(title: "Compra actual")
        let item = ShoppingItem(name: "Leche", listID: activeList.id, quantity: "2", status: .purchased, store: .jumbo)
        context.insert(activeList)
        context.insert(item)

        let summary = try ReceiptPurchaseService.register(
            entries: [ReceiptPurchaseEntry(name: "Leche", price: 1_490, associatedItemID: item.id)],
            receiptImage: receiptImage(),
            store: .jumbo,
            activeList: activeList,
            allItems: [item],
            categories: [],
            context: context
        )
        defer {
            if let filename = summary.list.receiptImageFilename {
                ReceiptImageStore.delete(named: filename)
            }
        }

        XCTAssertEqual(item.quantity, "")
    }

    // MARK: - Boletas reales: secciones y descuentos de supermercado

    /// Las boletas del Jumbo intercalan etiquetas de sección entre productos:
    /// «JUMBO OFERTAS», «Open bar», «Mercado FFVV». No son productos.
    func testParserIgnoresJumboSectionLabels() {
        let parsed = ReceiptLineParser.parse([
            "BOLETA ELECTRONICA",
            "CHAMPIÑONES LAMINA 4.500",
            "JUMBO OFERTAS",
            "JABON LIQGARRET $2.590",
            "Open bar",
            "BEBIDA ENER FU 250 $890",
            "TOTAL 7.980"
        ])

        XCTAssertEqual(parsed.map(\.name), ["CHAMPIÑONES LAMINA", "JABON LIQGARRET", "BEBIDA ENER FU 250"])
    }

    /// Jumbo usa «Campaña Sabores» como nombre de descuento por línea.
    func testParserRecognizesCampaignDiscount() {
        let parsed = ReceiptLineParser.parse([
            "BOLETA ELECTRONICA",
            "TURRON EL ALMENDRO $5.590",
            "Campaña Sabores -1.118",
            "TOTAL 4.472"
        ])

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].lineTotal, 4_472)
        XCTAssertTrue(parsed[0].hasDiscount)
    }

    /// Jumbo: «OFERTA SEMANA -3.594» es un descuento por línea.
    func testParserRecognizesOfertaSemanaDiscount() {
        let parsed = ReceiptLineParser.parse([
            "BOLETA ELECTRONICA",
            "VINO CS 14G 750CC 18.580",
            "OFERTA SEMANA -3.594",
            "TOTAL 14.986"
        ])

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].lineTotal, 14_986)
        XCTAssertTrue(parsed[0].hasDiscount)
    }

    /// Líder: «RF Precio Antes Ahora -490» indica un descuento.
    func testParserRecognizesLiderPriceBeforeAfterDiscount() {
        let parsed = ReceiptLineParser.parse([
            "BOLETA ELECTRONICA",
            "CALDDCARNE $1.490",
            "RF Precio Antes Ahora -490",
            "TOTAL 1.000"
        ])

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].lineTotal, 1_000)
        XCTAssertTrue(parsed[0].hasDiscount)
    }

    /// Las boletas del Líder intercalan líneas de referencia de promoción
    /// («RF lleve M x $», «SX1010 780…», «CODIGO 780…»). No son productos.
    func testParserIgnoresLiderPromoAndCodeLines() {
        let parsed = ReceiptLineParser.parse([
            "BOLETA ELECTRONICA",
            "SX1010 7808743605826",
            "RF lleve M x $",
            "CODIGO 780044223848",
            "FIDEO SP 400",
            "$900",
            "TOTAL 900"
        ])

        XCTAssertEqual(parsed.map(\.name), ["FIDEO SP 400"])
    }

    /// Algunas sucursales del Líder usan el RUT 76.134.941 en vez de 86.721.900.
    func testStoreDetectorRecognizesLiderAlternateRUT() {
        XCTAssertEqual(
            ReceiptStoreDetector.detectStoreRawValue(in: [
                "SUC AVDA SOR VICENTA", "RUT 76.134.941-4", "BOLETA ELECTRONICA"
            ]),
            Store.lider.rawValue
        )
    }

    /// «JUMBO OFERTAS -4.000» con monto negativo es un descuento de sección,
    /// no ruido: el monto se resta del producto anterior.
    func testParserTreatsJumboOfertasWithAmountAsDiscount() {
        let parsed = ReceiptLineParser.parse([
            "BOLETA ELECTRONICA",
            "YOGURT FRUIT SEC 10.320",
            "JUMBO OFERTAS -4.000",
            "TOTAL 6.320"
        ])

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].lineTotal, 6_320)
        XCTAssertTrue(parsed[0].hasDiscount)
    }

    /// «$ Open bar» con $ suelto al inicio no es un producto ni un monto.
    func testParserIgnoresDollarPrefixedSectionLabel() {
        let parsed = ReceiptLineParser.parse([
            "BOLETA ELECTRONICA",
            "BEBIDA ENER AE 250 $3.780",
            "$ Open bar",
            "HELADO CAPUCCIN IL $5.090",
            "TOTAL 8.870"
        ])

        XCTAssertEqual(parsed.map(\.name), ["BEBIDA ENER AE 250", "HELADO CAPUCCIN IL"])
    }

    /// «Open bar -390», «Mercado FFVV -1.383» y «RF Lleve N x $ -600» con montos negativos
    /// se descuentan del producto inmediatamente anterior.
    func testParserRecognizesSectionDiscountsWithNegativeAmounts() {
        let parsed = ReceiptLineParser.parse([
            "BOLETA ELECTRONICA",
            "BEBIDA ENER FD 250 1.890",
            "Open bar -390",
            "MANZANA VERDE GRAN 4.610",
            "Mercado FFVV -1.383",
            "MOSTACCIOLI $3.150",
            "RF Lleve N x $ -600",
            "TOTAL 6.877"
        ])

        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(parsed[0].name, "BEBIDA ENER FD 250")
        XCTAssertEqual(parsed[0].lineTotal, 1_500)
        XCTAssertTrue(parsed[0].hasDiscount)

        XCTAssertEqual(parsed[1].name, "MANZANA VERDE GRAN")
        XCTAssertEqual(parsed[1].lineTotal, 3_227)
        XCTAssertTrue(parsed[1].hasDiscount)

        XCTAssertEqual(parsed[2].name, "MOSTACCIOLI")
        XCTAssertEqual(parsed[2].lineTotal, 2_550)
        XCTAssertTrue(parsed[2].hasDiscount)
    }

    /// Líder cierra con «TOTAL NUMERO DE ARTIC VEND 45»: ese 45 es un conteo de
    /// unidades y no puede confundirse con el monto pagado.
    func testParserIgnoresItemCountLineWhenReadingPrintedTotal() {
        let result = ReceiptLineParser.parse([
            "BOLETA ELECTRONICA",
            "PAN 1.250",
            "LECHE 990",
            "TOTAL NUMERO DE ARTIC VEND 45",
            "TOTAL 2.240"
        ].map { ReceiptTextLine(text: $0) })

        XCTAssertEqual(result.printedTotal, 2_240)
    }

    /// Un producto que se llama «ARTICULOS DE ASEO» no puede cortar la boleta:
    /// todo lo que viniera después se perdería.
    func testParserKeepsProductsAfterLineNamedArticulos() {
        let parsed = ReceiptLineParser.parse([
            "BOLETA ELECTRONICA",
            "ARTICULOS DE ASEO 2.990",
            "LECHE COLUN 1L 990",
            "TOTAL 3.980"
        ])

        XCTAssertEqual(parsed.map(\.name), ["ARTICULOS DE ASEO", "LECHE COLUN 1L"])
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ShoppingItem.self, ShoppingList.self, ProductCatalogItem.self, Category.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Observación sintética con la geometría normalizada de Vision (origen
    /// abajo-izquierda), para ejercitar la reconstrucción de filas.
    private func observation(
        _ text: String,
        row: Int,
        minX: Double,
        maxX: Double,
        confidence: Double = 0.9
    ) -> ReceiptLineAssembler.Observation {
        let top = 1.0 - Double(row) * 0.05
        return ReceiptLineAssembler.Observation(
            text: text,
            minX: minX,
            maxX: maxX,
            minY: top - 0.018,
            maxY: top,
            confidence: confidence
        )
    }

    private func receiptImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
    }
}
