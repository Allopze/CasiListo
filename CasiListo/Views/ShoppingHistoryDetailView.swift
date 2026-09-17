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
    @ScaledMetric(relativeTo: .caption) private var storeTextSize: CGFloat = 9

    private var listItems: [ShoppingItem] {
        allItems.filter { $0.listID == list.id }
    }

    private var groupedItems: [(category: Category, items: [ShoppingItem])] {
        PurchasedItemGrouping.byCategory(listItems)
    }

    @ViewBuilder
    private func content<Groups: View>(groups: Groups) -> some View {
        VStack(spacing: sectionSpacing) {
            // Tarjeta de Resumen (Gasto, Conteo, etc.)
            summaryCard
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

    private var summaryCard: some View {
        VStack(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    summaryTitle
                    Spacer()
                    storeBadge
                }
                VStack(alignment: .leading, spacing: 10) {
                    summaryTitle
                    storeBadge
                }
            }

            Divider().background(Color.appSeparator)

            ViewThatFits(in: .horizontal) {
                statIndicators(axis: .horizontal)
                statIndicators(axis: .vertical)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let completedAt = list.completedAt {
                Divider().background(Color.appSeparator)

                HStack {
                    Image(systemName: "calendar")
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Color.appTextSecondary)

                    Text("Finalizada el \(AppDateFormatting.longWithTime(completedAt))")
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Color.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
    }

    private var summaryTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Resumen de Gasto")
                .font(Theme.captionDynamic)
                .foregroundStyle(Color.appTextSecondary)

            if list.totalSpent > 0 {
                Text(list.totalSpent.formattedPriceWithSymbol)
                    .font(Theme.titleDynamic)
                    .foregroundStyle(Theme.accentInteractive)
            } else {
                Text("Sin precios registrados")
                    .font(Theme.headlineDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var storeBadge: some View {
        if let store = list.storeScope {
            HStack(spacing: 6) {
                Image(systemName: store.sfSymbol)
                Text(store.displayName)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(Theme.chipDynamic)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(store.color)
            .clipShape(Capsule())
        }
    }

    private enum StatAxis { case horizontal, vertical }

    @ViewBuilder
    private func statIndicators(axis: StatAxis) -> some View {
        let stack = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 16))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
        stack {
            statIndicator(
                singular: "Comprado", plural: "Comprados", count: list.purchasedCount,
                icon: "checkmark.circle.fill", color: Theme.statusPurchased
            )
            if list.skippedCount > 0 {
                statIndicator(singular: "Pospuesto", plural: "Pospuestos", count: list.skippedCount, icon: "clock.fill", color: Theme.statusSkipped)
            }
            if list.unavailableCount > 0 {
                statIndicator(
                    singular: "No encontrado", plural: "No encontrados", count: list.unavailableCount,
                    icon: "exclamationmark.triangle.fill", color: Theme.statusUnavailable
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    /// - Parameters:
    ///   - singular: etiqueta para `count == 1`; evita el «1 Comprados».
    private func statIndicator(
        singular: String,
        plural: String,
        count: Int,
        icon: String,
        color: Color
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text("\(count)")
                .bold()
            Text(count == 1 ? singular : plural)
                .foregroundStyle(Color.appTextSecondary)
        }
        .font(Theme.captionDynamic)
        .accessibilityElement(children: .combine)
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
            VStack(spacing: 1) {
                ForEach(items) { item in
                    itemRow(item)
                }
            }
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 2)
        }
    }

    @ViewBuilder
    private func categoryHeader(_ category: Category, count: Int, axis: StatAxis) -> some View {
        let stack = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 8))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
        stack {
            HStack(spacing: 8) {
                Image(systemName: category.sfSymbol)
                    .foregroundStyle(Theme.accentInteractive)
                Text(category.displayName)
                    .bold()
                    .fixedSize(horizontal: false, vertical: true)
            }
            if axis == .horizontal { Spacer(minLength: 8) }
            Text("\(count)")
                .font(.caption)
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
        HStack(spacing: 12) {
            statusIcon(for: item.status)
            itemDetails(item, titleLineLimit: 1)
            Spacer()
            storeTag(for: item)
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
                storeTag(for: item)
            }
        }
    }

    private func itemDetails(_ item: ShoppingItem, titleLineLimit: Int?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    itemTitle(item, lineLimit: titleLineLimit)
                    quantityBadge(for: item)
                    lineTotal(for: item)
                }
                VStack(alignment: .leading, spacing: 4) {
                    itemTitle(item, lineLimit: titleLineLimit)
                    HStack(spacing: 6) {
                        quantityBadge(for: item)
                        lineTotal(for: item)
                    }
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

    private func itemTitle(_ item: ShoppingItem, lineLimit: Int?) -> some View {
        Text(item.name)
            .font(Theme.bodyDynamic)
            .foregroundStyle(item.status == .purchased ? Color.appTextPurchased : Color.appTextPrimary)
            .strikethrough(item.status == .purchased, color: Color.appTextPurchased)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
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

    @ViewBuilder
    private func lineTotal(for item: ShoppingItem) -> some View {
        if item.price != nil {
            Text(item.lineTotal.formattedPriceWithSymbol)
                .font(Theme.captionDynamic)
                .foregroundStyle(item.status == .purchased ? Color.appTextPurchased : Theme.statusPurchased)
        }
    }

    @ViewBuilder
    private func storeTag(for item: ShoppingItem) -> some View {
        if item.store != list.storeScope {
            Text(item.store.displayName)
                .font(.system(size: storeTextSize, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(item.store.color.opacity(0.8))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private func statusIcon(for status: ShoppingItemStatus) -> some View {
        switch status {
        case .purchased:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: statusIconSize, weight: .bold))
                .foregroundStyle(Theme.statusPurchased)
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
