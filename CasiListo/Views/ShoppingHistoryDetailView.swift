import SwiftUI
import SwiftData
import UIKit

/// Agrupación de los productos ya archivados de una compra.
///
/// Vivía como una expresión suelta dentro de la vista y por eso nunca se probó.
/// Agrupaba por `$0.category`, es decir por **identidad de objeto**, y
/// `Category.fallback` devuelve una instancia nueva en cada acceso: los
/// productos de «Varios» —el caso normal, porque `ShoppingItem.init` deja su
/// relación en `nil` a propósito— formaban una sección de un elemento cada uno,
/// todas con el mismo id en el `ForEach`.
nonisolated enum PurchasedItemGrouping {
    static func byCategory(_ items: [ShoppingItem]) -> [(category: Category, items: [ShoppingItem])] {
        // Por nombre, como el resto de la app: es la clave estable, y además la
        // que usa el `ForEach` como identidad.
        let dict = Dictionary(grouping: items) { $0.category.name }
        return dict.compactMap { _, group -> (category: Category, items: [ShoppingItem])? in
            guard let category = group.first?.category else { return nil }
            return (category: category, items: group.sorted { $0.name < $1.name })
        }
        .sorted { $0.category.displayName < $1.category.displayName }
    }
}

/// Vista de detalle para una lista del historial de compras.
/// Muestra los productos archivados agrupados por categoría con su estado final.
struct ShoppingHistoryDetailView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let list: ShoppingList
    let allItems: [ShoppingItem]
    @State private var receiptImage: UIImage?

    @ScaledMetric(relativeTo: .body) private var cardPadding: CGFloat = Theme.cardPadding
    @ScaledMetric(relativeTo: .body) private var sectionSpacing: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var itemSpacing: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var statusIconSize: CGFloat = 18

    private var listItems: [ShoppingItem] {
        allItems.filter { $0.listID == list.id }
    }

    private var groupedItems: [(category: Category, items: [ShoppingItem])] {
        PurchasedItemGrouping.byCategory(listItems)
    }

    @ViewBuilder
    private func content<Groups: View>(groups: Groups) -> some View {
        VStack(spacing: sectionSpacing) {
            ReceiptTicketView(list: list, itemCount: listItems.count)
                .padding(.horizontal, cardPadding)
                .padding(.top, 12)

            if let receiptImage {
                receiptCard(receiptImage)
                    .padding(.horizontal, cardPadding)
            }

            if listItems.isEmpty {
                ContentUnavailableView(
                    "Sin productos",
                    systemImage: "cart.badge.questionmark",
                    description: Text("No hay detalles registrados para esta compra.")
                )
                .padding(.top, 40)
            } else {
                groups
                    .padding(.horizontal, cardPadding)
            }
        }
        .padding(.bottom, 24)
    }

    /// Variante no virtualizada usada solo por el diagnóstico ImageRenderer.
    /// La pantalla real usa `LazyVStack` en `body`.
    var contentWithoutScroll: some View {
        content(
            groups: VStack(spacing: sectionSpacing) {
                ForEach(groupedItems, id: \.category.rawValue) { group in
                    categorySection(group.category, items: group.items)
                }
            }
        )
    }

    var body: some View {
        ScrollView {
            content(
                groups: LazyVStack(spacing: sectionSpacing) {
                    ForEach(groupedItems, id: \.category.rawValue) { group in
                        categorySection(group.category, items: group.items)
                    }
                }
            )
        }
        .background(Color.appBackground)
        .navigationTitle(list.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Decodificar a resolución completa (hasta 24 MP en boletas de
            // varias páginas) bloqueaba el hilo principal cada vez que se
            // abría esta compra. La miniatura basta para la vista previa.
            guard let filename = list.receiptImageFilename,
                  let url = ReceiptImageStore.receiptURL(named: filename)
            else { return }
            receiptImage = await Task.detached(priority: .userInitiated) {
                ReceiptImageStore.thumbnail(at: url)
            }.value
        }
    }

    private func receiptCard(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Boleta asociada", systemImage: "doc.text.viewfinder")
                .font(Theme.bodyBoldDynamic)

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
                .accessibilityLabel("Foto de la boleta asociada a esta compra")
        }
        .padding(16)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private func categorySection(_ category: Category, items: [ShoppingItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header de la Categoría
            ViewThatFits(in: .horizontal) {
                categoryHeader(category, count: items.count, axis: .horizontal)
                categoryHeader(category, count: items.count, axis: .vertical)
            }
            .font(Theme.bodyBoldDynamic)
            .padding(.horizontal, 4)

            // Fila de Productos
            VStack(spacing: 0) {
                ForEach(items) { item in
                    itemRow(item)
                    if item.id != items.last?.id {
                        Divider()
                            .overlay(Color.appSeparator)
                            .padding(.leading, 44)
                    }
                }
            }
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .compositingGroup()
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        }
    }

    private enum StatAxis { case horizontal, vertical }

    @ViewBuilder
    private func categoryHeader(_ category: Category, count: Int, axis: StatAxis) -> some View {
        let stack = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 8))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
        stack {
            HStack(spacing: 8) {
                // El color de su categoría, como en la lista activa: antes todas
                // iban en el mismo oro y la sección perdía su identidad.
                Image(systemName: category.sfSymbol)
                    .foregroundStyle(Category.iconColor(for: category))
                    .accessibilityHidden(true)
                Text(category.displayName)
                    .bold()
                    .fixedSize(horizontal: false, vertical: true)
            }
            if axis == .horizontal { Spacer(minLength: 8) }
            Text("\(count)")
                .font(Theme.receiptMonoCaption)
                .foregroundStyle(Color.appTextSecondary)
        }
        .font(Theme.bodyBoldDynamic)
        .padding(.horizontal, 4)
    }

    /// Mismo criterio que la revisión de la boleta (`ReceiptEntryRow`), vía
    /// `QuantitySemantics.breakdown`.
    private func lineBreakdownCaption(for item: ShoppingItem) -> String? {
        guard let price = item.price else { return nil }
        switch QuantitySemantics.breakdown(
            unitPrice: price,
            lineTotal: item.lineTotal,
            count: QuantitySemantics.unitCount(of: item.quantity)
        ) {
        case .single: return nil
        case .inexactMultiple(let count): return "\(count) unidades"
        case .exactMultiple(let count, let unitPrice): return "\(count) × \(unitPrice.formattedPriceWithSymbol)"
        }
    }

    private func itemRow(_ item: ShoppingItem) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityItemRow(item)
            } else {
                standardItemRow(item)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }

    private func standardItemRow(_ item: ShoppingItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            statusIcon(for: item.status)
            itemDetails(item, titleLineLimit: 2)
            Spacer(minLength: 8)
            lineTotal(for: item)
        }
    }

    private func accessibilityItemRow(_ item: ShoppingItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                statusIcon(for: item.status)
                itemDetails(item, titleLineLimit: nil)
                Spacer(minLength: 0)
            }
            HStack {
                Spacer(minLength: 30)
                lineTotal(for: item)
            }
        }
    }

    private func itemDetails(_ item: ShoppingItem, titleLineLimit: Int?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            itemTitle(item, lineLimit: titleLineLimit)

            if hasMeta(item) {
                HStack(spacing: 6) {
                    storeTag(for: item)
                    quantityBadge(for: item)
                }
            }

            if let caption = lineBreakdownCaption(for: item) {
                Text(caption)
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !item.note.isEmpty {
                Text(item.note)
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(titleLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .layoutPriority(1)
    }

    /// Sin tachado: en el registro de una compra «comprado» es el estado
    /// normal, y tachar cada línea hacía que lo pagado pareciera anulado. Lo
    /// que no llegó al carro es lo que se atenúa.
    private func itemTitle(_ item: ShoppingItem, lineLimit: Int?) -> some View {
        Text(item.name)
            .font(Theme.bodyDynamic)
            .foregroundStyle(item.status == .purchased ? Color.appTextPrimary : Color.appTextSecondary)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func hasMeta(_ item: ShoppingItem) -> Bool {
        showsStoreTags || (!item.quantity.isEmpty && lineBreakdownCaption(for: item) == nil)
    }

    /// La tienda por fila solo distingue algo si la compra mezcló tiendas:
    /// con una sola, «Jumbo» se repetía en cada línea (y se truncaba a «Jum…»).
    private var showsStoreTags: Bool {
        Set(listItems.map(\.store)).count > 1
    }

    @ViewBuilder
    private func quantityBadge(for item: ShoppingItem) -> some View {
        if !item.quantity.isEmpty, lineBreakdownCaption(for: item) == nil {
            Text(item.quantity)
                .font(Theme.captionDynamic)
                .foregroundStyle(Color.appTextSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.appSeparator)
                .clipShape(Capsule())
        }
    }

    /// Columna de precios alineada a la derecha, en la voz de la boleta.
    @ViewBuilder
    private func lineTotal(for item: ShoppingItem) -> some View {
        if item.price != nil {
            Text(item.lineTotal.formattedPriceWithSymbol)
                .font(Theme.receiptMono)
                .monospacedDigit()
                .foregroundStyle(item.status == .purchased ? Color.appTextPrimary : Color.appTextSecondary)
                .lineLimit(1)
                .fixedSize()
        }
    }

    /// Mismo chip que la fila de la lista activa (`ItemRowView.metaChips`).
    @ViewBuilder
    private func storeTag(for item: ShoppingItem) -> some View {
        if showsStoreTags {
            Text(item.store.displayName)
                .font(Theme.chipDynamic)
                .foregroundStyle(item.store.labelColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(item.store.color.opacity(0.13), in: Capsule())
                .accessibilityLabel("Tienda: \(item.store.displayName)")
        }
    }

    @ViewBuilder
    private func statusIcon(for status: ShoppingItemStatus) -> some View {
        switch status {
        case .purchased:
            // El mismo visto amarillo de la lista: lo comprado se ve igual
            // antes y después de archivar.
            ZStack {
                Circle().fill(Theme.accentYellow)
                CheckmarkShape()
                    .stroke(Theme.onAccent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .padding(statusIconSize * 0.28)
            }
            .frame(width: statusIconSize + 2, height: statusIconSize + 2)
            .accessibilityLabel("Comprado")
        case .skipped:
            Image(systemName: "clock.fill")
                .font(.system(size: statusIconSize, weight: .bold))
                .foregroundStyle(Theme.statusSkipped)
        case .unavailable:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: statusIconSize, weight: .bold))
                .foregroundStyle(Theme.statusUnavailable)
        case .pending:
            Image(systemName: "circle")
                .font(.system(size: statusIconSize, weight: .bold))
                .foregroundStyle(Color.appTextSecondary)
        }
    }
}
