import XCTest
@testable import CasiListo

/// Mide el reconocimiento contra boletas reales completas (ver `ReceiptFixtures`).
/// El criterio es el de la persona que revisa la pantalla: todos los productos,
/// con su monto, y una suma que cuadre con el TOTAL impreso.
final class ReceiptRecognitionFixtureTests: XCTestCase {

    /// Antes de exigirle nada al parser, la transcripción tiene que cuadrar sola:
    /// si el fixture está mal copiado, cualquier fallo apunta al lugar equivocado.
    func testFixturesMatchTheirOwnPrintedTotals() {
        for fixture in ReceiptFixtures.all {
            XCTAssertEqual(
                fixture.expectedGross, fixture.grossTotal, accuracy: 0.5,
                "\(fixture.title): la suma bruta esperada no da el total antes de descuentos"
            )
            XCTAssertEqual(
                fixture.expectedNet, fixture.printedTotal, accuracy: 0.5,
                "\(fixture.title): la suma neta esperada no da el TOTAL impreso"
            )
        }
    }

    func testParserReadsEveryProductOfEveryReceipt() {
        for fixture in ReceiptFixtures.all {
            let parsed = ReceiptLineParser.parse(fixture.lines.map { ReceiptTextLine(text: $0) })
            XCTAssertEqual(
                parsed.products.map(\.name), fixture.products.map(\.name),
                "\(fixture.title): los productos leídos no son los de la boleta"
            )
        }
    }

    func testParserReadsEveryLineTotal() {
        for fixture in ReceiptFixtures.all {
            let parsed = ReceiptLineParser.parse(fixture.lines.map { ReceiptTextLine(text: $0) })
            guard parsed.products.count == fixture.products.count else {
                XCTFail("\(fixture.title): se leyeron \(parsed.products.count) de \(fixture.products.count) productos")
                continue
            }
            for (read, expected) in zip(parsed.products, fixture.products) {
                XCTAssertEqual(
                    read.lineTotal, expected.total, accuracy: 0.5,
                    "\(fixture.title): monto incorrecto en «\(expected.name)»"
                )
            }
        }
    }

    func testParserReadsEveryQuantity() {
        for fixture in ReceiptFixtures.all {
            let parsed = ReceiptLineParser.parse(fixture.lines.map { ReceiptTextLine(text: $0) })
            guard parsed.products.count == fixture.products.count else { continue }
            for (read, expected) in zip(parsed.products, fixture.products) {
                XCTAssertEqual(
                    read.quantity, expected.quantity,
                    "\(fixture.title): cantidad incorrecta en «\(expected.name)»"
                )
            }
        }
    }

    /// Lo que ve la persona: la suma de la revisión contra el TOTAL del papel.
    /// Este es el test que decide si el descuadre desaparece.
    func testParsedTotalMatchesThePrintedTotal() {
        for fixture in ReceiptFixtures.all {
            let parsed = ReceiptLineParser.parse(fixture.lines.map { ReceiptTextLine(text: $0) })
            let sum = parsed.products.map(\.lineTotal).reduce(0, +)
            XCTAssertEqual(
                sum, fixture.printedTotal, accuracy: 0.5,
                "\(fixture.title): la suma leída es \(sum) y la boleta dice \(fixture.printedTotal)"
            )
        }
    }

    /// El banner de cuadratura compara contra este número: si toma el SUB TOTAL
    /// o el TOTAL AFECTO, avisa de un descuadre que no existe.
    func testParserReadsThePrintedTotalAndNotTheSubtotal() {
        for fixture in ReceiptFixtures.all {
            let parsed = ReceiptLineParser.parse(fixture.lines.map { ReceiptTextLine(text: $0) })
            XCTAssertEqual(
                parsed.printedTotal, fixture.printedTotal,
                "\(fixture.title): TOTAL impreso mal identificado"
            )
        }
    }

    /// Vision funde filas vecinas cuando la boleta va curvada o arrugada, que es
    /// justo lo que pasó en la captura que originó esto: el desglose de cantidad
    /// terminó pegado a otra fila y arrastró el precio de todos los productos.
    /// Los montos tienen que sobrevivir a la fusión en cualquier dirección.
    func testRecognitionSurvivesMergedNeighbouringRows() {
        for fixture in ReceiptFixtures.all {
            for downward in [true, false] {
                let lines = Self.mergingModifierRows(fixture.lines, downward: downward)
                let parsed = ReceiptLineParser.parse(lines.map { ReceiptTextLine(text: $0) })
                let sense = downward ? "hacia abajo" : "hacia arriba"

                XCTAssertEqual(
                    parsed.products.count, fixture.products.count,
                    "\(fixture.title) [fusión \(sense)]: se perdieron productos"
                )
                XCTAssertEqual(
                    parsed.products.map(\.lineTotal).reduce(0, +), fixture.printedTotal, accuracy: 0.5,
                    "\(fixture.title) [fusión \(sense)]: la suma dejó de cuadrar"
                )
            }
        }
    }

    /// Pega cada fila de desglose («2 X $1.490», «0,912 KG X $3.490») a su vecina.
    private static func mergingModifierRows(_ lines: [String], downward: Bool) -> [String] {
        func isModifier(_ text: String) -> Bool {
            text.range(
                of: "^[0-9]{1,2}([.,][0-9]{1,3})? ?(KG|UN)? ?[X\u{00D7}] ?\\$?[0-9.]+$",
                options: [.regularExpression, .caseInsensitive]
            ) != nil
        }

        var merged: [String] = []
        var index = 0
        while index < lines.count {
            if isModifier(lines[index]) {
                if downward, index + 1 < lines.count {
                    merged.append(lines[index] + " " + lines[index + 1])
                    index += 2
                    continue
                }
                if !downward, let previous = merged.last, !isModifier(previous) {
                    merged[merged.count - 1] = lines[index] + " " + previous
                    index += 1
                    continue
                }
            }
            merged.append(lines[index])
            index += 1
        }
        return merged
    }

    // MARK: - Regresiones concretas encontradas con estas tres boletas

    /// Fotografiada en ángulo, la caja de una fila es más alta que la separación
    /// entre filas: el producto y el descuento de abajo se solapaban en vertical
    /// y se fundían. Que se pisen en horizontal prueba que son filas distintas.
    func testAssemblerKeepsRowsApartWhenTheirBoxesOverlapVertically() {
        func box(_ text: String, minX: Double, maxX: Double, midY: Double, height: Double)
        -> ReceiptLineAssembler.Observation {
            ReceiptLineAssembler.Observation(
                text: text, minX: minX, maxX: maxX,
                minY: midY - height / 2, maxY: midY + height / 2, confidence: 0.9
            )
        }

        // Geometría tomada de una boleta real: las cajas se solapan en vertical.
        let lines = ReceiptLineAssembler.assemble([
            box("8410134006687 ACEIT FRAG ANCH 85 1.590", minX: 0.154, maxX: 0.887, midY: 0.8772, height: 0.0149),
            box("-390", minX: 0.804, maxX: 0.887, midY: 0.8709, height: 0.0084),
            box("Campaña Sabores", minX: 0.403, maxX: 0.697, midY: 0.8675, height: 0.0117)
        ])

        XCTAssertEqual(lines.map(\.text), [
            "8410134006687 ACEIT FRAG ANCH 85 1.590",
            "Campaña Sabores -390"
        ])
    }

    /// El precio de la columna derecha se enganchaba a la fila de más arriba solo
    /// porque esa banda ya existía cuando le llegaba el turno, y desde ahí toda
    /// la boleta quedaba corrida en una fila.
    func testAssemblerGivesEachPriceToItsOwnRowAndNotTheOneAbove() {
        func box(_ text: String, minX: Double, maxX: Double, midY: Double, height: Double)
        -> ReceiptLineAssembler.Observation {
            ReceiptLineAssembler.Observation(
                text: text, minX: minX, maxX: maxX,
                minY: midY - height / 2, maxY: midY + height / 2, confidence: 0.9
            )
        }

        let lines = ReceiptLineAssembler.assemble([
            box("CODIGO: 7802575001832", minX: 0.10, maxX: 0.52, midY: 0.9000, height: 0.0110),
            box("3X1.050 MOSTACCIOLI", minX: 0.10, maxX: 0.60, midY: 0.8930, height: 0.0110),
            box("$ 3.150", minX: 0.78, maxX: 0.92, midY: 0.8952, height: 0.0100)
        ])

        XCTAssertEqual(lines.map(\.text), [
            "CODIGO: 7802575001832",
            "3X1.050 MOSTACCIOLI $ 3.150"
        ])
    }

    /// El Líder imprime el desglose pegado al nombre: sin separarlo, el producto
    /// se llamaba «3X1.050 MOSTACCIOLI» y quedaba con cantidad 1.
    func testParserSplitsQuantityGluedToTheProductName() {
        let parsed = ReceiptLineParser.parse([
            "BOLETA ELECTRONICA",
            "CODIGO: 7802575001832",
            "3X1.050 MOSTACCIOLI $ 3.150",
            "TOTAL 3.150"
        ])

        XCTAssertEqual(parsed.map(\.name), ["MOSTACCIOLI"])
        XCTAssertEqual(parsed[0].quantity, 3)
        XCTAssertEqual(parsed[0].lineTotal, 3_150)
    }

    /// Cuando Vision junta el desglose con la fila siguiente, la fila entera se
    /// leía como un producto llamado «2 X $1.490 7803473002662 …».
    func testParserSplitsQuantityMergedWithTheNextRow() {
        let parsed = ReceiptLineParser.parse([
            "BOLETA ELECTRONICA",
            "2 X $1.490 7803473002662 PAN IDEAL BCO XL 2.990",
            "TOTAL 2.990"
        ])

        XCTAssertEqual(parsed.map(\.name), ["PAN IDEAL BCO XL"])
        XCTAssertEqual(parsed[0].quantity, 2)
        XCTAssertEqual(parsed[0].lineTotal, 2_990)
    }

    /// Un código de barras se leía como monto de línea; el total resultante
    /// superaba el máximo y el producto se descartaba sin dejar rastro.
    func testParserNeverReadsABarcodeAsAnAmount() {
        XCTAssertNil(ReceiptAmount.value("KG"))

        let parsed = ReceiptLineParser.parse([
            "BOLETA ELECTRONICA",
            "2 X $1.490 7803473002662",
            "7803473002662 PAN IDEAL BCO XL 2.990",
            "TOTAL 2.990"
        ])

        XCTAssertEqual(parsed.map(\.name), ["PAN IDEAL BCO XL"])
        XCTAssertEqual(parsed[0].lineTotal, 2_990)
    }

    /// En papel térmico gastado Vision confunde la `X` con la Х cirílica.
    func testParserReadsQuantityWrittenWithAHomoglyphOfX() {
        let parsed = ReceiptLineParser.parse([
            "BOLETA ELECTRONICA",
            "3\u{0425}1.290 ARROZ G2 LD $ 3.870",
            "TOTAL 3.870"
        ])

        XCTAssertEqual(parsed.map(\.name), ["ARROZ G2 LD"])
        XCTAssertEqual(parsed[0].quantity, 3)
    }

    /// Un producto de una sola palabra impreso junto a su código cumplía la regla
    /// de «teléfono o folio» y se descartaba, llevándose además su rebaja al
    /// producto anterior.
    func testParserKeepsSingleWordProductPrintedNextToItsBarcode() {
        let parsed = ReceiptLineParser.parse([
            "BOLETA ELECTRONICA",
            "2030300000002 PALTA HASS $ 7.565",
            "7802950005974 CALDOCARNE $ 1.490",
            "RF Precio Antes Ahora -490",
            "TOTAL 8.565"
        ])

        XCTAssertEqual(parsed.map(\.name), ["PALTA HASS", "CALDOCARNE"])
        XCTAssertEqual(parsed[0].lineTotal, 7_565)
        XCTAssertEqual(parsed[1].lineTotal, 1_000)
    }

    /// La sucursal del encabezado («LOS ANGELES - LOS ANGELES») se colaba al
    /// cuerpo y podía quedarse con el precio del primer producto.
    func testParserTreatsTheBranchLineAsHeader() {
        let parsed = ReceiptLineParser.parse([
            "CENCOSUD RETAIL S.A.",
            "LOS ANGELES - LOS ANGELES",
            "7804677020001 BOLSA PAPEL YAPACK 290",
            "TOTAL 290"
        ])

        XCTAssertEqual(parsed.map(\.name), ["BOLSA PAPEL YAPACK"])
        XCTAssertEqual(parsed[0].lineTotal, 290)
    }

    /// «2 X $2.590» impreso encima describe al producto de abajo, no al de
    /// arriba: creerle desplazaba el precio de toda la boleta en una línea.
    func testParserBindsQuantityBreakdownToTheProductItBelongsTo() {
        let parsed = ReceiptLineParser.parse([
            "BOLETA ELECTRONICA",
            "7804677020001 BOLSA PAPEL YAPACK 290",
            "2 X $2.590",
            "7807910028475 PASTILLA PARA ESTA 5.180",
            "TOTAL 5.470"
        ])

        XCTAssertEqual(parsed.map(\.name), ["BOLSA PAPEL YAPACK", "PASTILLA PARA ESTA"])
        XCTAssertEqual(parsed[0].lineTotal, 290)
        XCTAssertEqual(parsed[0].quantity, 1)
        XCTAssertEqual(parsed[1].lineTotal, 5_180)
        XCTAssertEqual(parsed[1].quantity, 2)
    }

    /// El OCR mete un espacio tras el punto de miles y el TOTAL quedaba en $717.
    func testParserReadsTotalPrintedWithASpaceInsideTheAmount() {
        let result = ReceiptLineParser.parse([
            "BOLETA ELECTRONICA", "PAN 1.250", "SUB TOTAL $ 1.250", "TOTAL $ 142. 717"
        ].map { ReceiptTextLine(text: $0) })

        XCTAssertEqual(result.printedTotal, 142_717)
    }

    /// El OCR se come el cero de «0,918 KG X» y el resto de la fila se convertía
    /// en un producto fantasma llamado «918 KG X».
    func testParserStillReadsAWeightBreakdownMissingItsLeadingZero() {
        let parsed = ReceiptLineParser.parse([
            "BOLETA ELECTRONICA",
            ",918 KG X $3.490",
            "2496230032047 CIABATTA RUSTICA K 3.204",
            "TOTAL 3.204"
        ])

        XCTAssertEqual(parsed.map(\.name), ["CIABATTA RUSTICA K"])
        XCTAssertEqual(parsed[0].quantity, 1)
        XCTAssertEqual(parsed[0].lineTotal, 3_204)
    }

    func testStoreDetectorRecognizesEveryReceiptHeader() {
        for fixture in ReceiptFixtures.all {
            XCTAssertEqual(
                ReceiptStoreDetector.detectStoreRawValue(in: fixture.lines),
                fixture.store,
                "\(fixture.title): supermercado mal detectado"
            )
        }
    }
}
