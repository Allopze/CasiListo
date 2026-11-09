import SwiftUI

/// Resumen de una compra archivada con la voz de la boleta térmica: la app
/// lee boletas reales de Jumbo y Líder, y el registro de lo pagado se parece
/// al papel que salió de la caja (DESIGN.md, «de B se toma»).
///
/// Monoespaciada, columnas con puntos guía, guiones como separadores y el
/// borde inferior dentado del corte de la impresora.
struct ReceiptTicketView: View {
    let list: ShoppingList
    /// Productos de la compra; su recuento encabeza cuando no hay precios.
    let itemCount: Int

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var toothDepth: CGFloat = 7

    private var storeTitle: String {
        (list.storeScope?.displayName ?? "Compra").uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 4) {
                Text(storeTitle)
                    .font(.system(.title3, design: .monospaced, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(Color.appTextPrimary)
                if let completedAt = list.completedAt {
                    Text(AppDateFormatting.shortWithTime(completedAt))
                        .font(Theme.receiptMonoCaption)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

            DashedRule()

            VStack(spacing: 6) {
                leaderRow(label: "Productos", value: "\(itemCount)")
                leaderRow(label: "Comprados", value: "\(list.purchasedCount)")
                if list.skippedCount > 0 {
                    leaderRow(label: "Pospuestos", value: "\(list.skippedCount)", color: Theme.statusSkipped)
                }
                if list.unavailableCount > 0 {
                    leaderRow(label: "No encontrados", value: "\(list.unavailableCount)", color: Theme.statusUnavailable)
                }
            }

            DashedRule()

            totalRow
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 20 + toothDepth)
        // La sombra va en la silueta, no en el contenedor: aplicada al
        // VStack, SwiftUI sombreaba cada texto y dejaba halos grises.
        .background {
            TornReceiptShape(toothDepth: toothDepth)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private var totalRow: some View {
        if list.totalSpent > 0 {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    totalLabel
                    Spacer(minLength: 12)
                    totalValue
                }
                VStack(alignment: .leading, spacing: 4) {
                    totalLabel
                    totalValue
                }
            }
        } else {
            leaderRow(label: "Total", value: "sin precios")
        }
    }

    private var totalLabel: some View {
        Text("TOTAL")
            .font(.system(.headline, design: .monospaced, weight: .bold))
            .tracking(2)
            .foregroundStyle(Color.appTextPrimary)
    }

    private var totalValue: some View {
        Text(list.totalSpent.formattedPriceWithSymbol)
            .font(.system(.largeTitle, design: .monospaced, weight: .bold))
            .tracking(-1)
            .foregroundStyle(Color.appTextPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    /// «COMPRADOS ........ 15». En tamaños de accesibilidad los puntos guía no
    /// caben: la fila se apila.
    @ViewBuilder
    private func leaderRow(label: String, value: String, color: Color = Color.appTextPrimary) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .foregroundStyle(Color.appTextSecondary)
                Text(value)
                    .foregroundStyle(color)
            }
            .font(Theme.receiptMono)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(label.uppercased())
                    .foregroundStyle(Color.appTextSecondary)
                    .layoutPriority(1)
                DottedLeader()
                    .frame(height: 2)
                Text(value)
                    .foregroundStyle(color)
                    .layoutPriority(1)
            }
            .font(Theme.receiptMono)
        }
    }

    private var accessibilitySummary: String {
        var parts = ["Compra en \(list.storeScope?.displayName ?? "varias tiendas")"]
        if let completedAt = list.completedAt {
            parts.append(AppDateFormatting.longWithTime(completedAt))
        }
        parts.append(SpanishPluralization.count(itemCount, singular: "producto", plural: "productos"))
        parts.append(SpanishPluralization.count(list.purchasedCount, singular: "comprado", plural: "comprados"))
        if list.skippedCount > 0 {
            parts.append(SpanishPluralization.count(list.skippedCount, singular: "pospuesto", plural: "pospuestos"))
        }
        if list.unavailableCount > 0 {
            parts.append(SpanishPluralization.count(list.unavailableCount, singular: "no encontrado", plural: "no encontrados"))
        }
        parts.append(list.totalSpent > 0 ? "Total pagado \(list.totalSpent.formattedPriceWithSymbol)" : "Sin precios registrados")
        return parts.joined(separator: ", ")
    }
}

// MARK: - Piezas de papel

/// Separador de guiones, como los que imprime la caja entre secciones.
struct DashedRule: View {
    var body: some View {
        Line()
            .stroke(Color.appTextSecondary.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// Puntos guía entre una etiqueta y su valor.
struct DottedLeader: View {
    var body: some View {
        Line()
            .stroke(Color.appTextSecondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0.5, 5]))
            .accessibilityHidden(true)
    }
}

private nonisolated struct Line: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// Rectángulo con esquinas superiores redondeadas y borde inferior dentado:
/// el corte de la impresora térmica.
nonisolated struct TornReceiptShape: Shape {
    var toothDepth: CGFloat = 7
    /// Igual a `Theme.cornerRadius`; literal porque el tipo es `nonisolated`.
    var cornerRadius: CGFloat = 20

    nonisolated func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, rect.width / 2, rect.height / 2)
        let toothCount = max(6, Int((rect.width / (toothDepth * 2.2)).rounded()))
        let toothWidth = rect.width / CGFloat(toothCount)
        let baseline = rect.maxY - toothDepth

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: baseline))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
            radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
            radius: radius, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: baseline))
        for index in stride(from: toothCount, to: 0, by: -1) {
            let x = rect.minX + CGFloat(index) * toothWidth
            path.addLine(to: CGPoint(x: x - toothWidth / 2, y: rect.maxY))
            path.addLine(to: CGPoint(x: x - toothWidth, y: baseline))
        }
        path.closeSubpath()
        return path
    }
}
