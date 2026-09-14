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

    var body: some View {
        ScrollView {
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
                    // Productos agrupados por categoría
                    LazyVStack(spacing: sectionSpacing) {
                        ForEach(groupedItems, id: \.category.rawValue) { group in
                            categorySection(group.category, items: group.items)
                        }
                    }
                    .padding(.horizontal, cardPadding)
                }
            }
            .padding(.bottom, 24)
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
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Resumen de Gasto")
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Color.appTextSecondary)

                    // Archivar sin boleta no significa gasto cero, significa que
                    // no se registró. Un «$0» gigante afirmaba lo primero.
                    if list.totalSpent > 0 {
                        Text(list.totalSpent.formattedPriceWithSymbol)
                            .font(Theme.titleDynamic)
                            .foregroundStyle(Theme.accentInteractive)
                    } else {
                        Text("Sin precios registrados")
                            .font(Theme.headlineDynamic)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }

                Spacer()

                if let store = list.storeScope {
                    HStack(spacing: 6) {
                        Image(systemName: store.sfSymbol)
                        Text(store.displayName)
                    }
                    .font(Theme.chipDynamic)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(store.color)
                    .clipShape(Capsule())
                }
            }

            Divider().background(Color.appSeparator)

            HStack(spacing: 16) {
                statIndicator(singular: "Comprado", plural: "Comprados", count: list.purchasedCount, icon: "checkmark.circle.fill", color: Theme.statusPurchased)

                if list.skippedCount > 0 {
                    statIndicator(singular: "Pospuesto", plural: "Pospuestos", count: list.skippedCount, icon: "clock.fill", color: Theme.statusSkipped)
                }

                if list.unavailableCount > 0 {
                    statIndicator(singular: "No encontrado", plural: "No encontrados", count: list.unavailableCount, icon: "exclamationmark.triangle.fill", color: Theme.statusUnavailable)
                }
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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
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
            HStack(spacing: 8) {
                Image(systemName: category.sfSymbol)
                    .foregroundStyle(Theme.accentInteractive)
                Text(category.displayName)
                    .bold()
                Spacer()
                Text("\(items.count)")
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
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
        HStack(spacing: 12) {
            statusIcon(for: item.status)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(Theme.bodyDynamic)
                        .foregroundStyle(item.status == .purchased ? Color.appTextPurchased : Color.appTextPrimary)
                        .strikethrough(item.status == .purchased, color: Color.appTextPurchased)
                        .lineLimit(1)

                    // La cantidad se calla cuando el pie ya la lleva ("3 × $917"):
                    // repetir el 3 en una píldora y en el pie era ruido.
                    if !item.quantity.isEmpty, lineBreakdownCaption(for: item) == nil {
                        Text(item.quantity)
                            .font(Theme.captionDynamic)
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.appSeparator)
                            .clipShape(Capsule())
                    }

                    // `price` es **unitario** (invariante de QuantitySemantics),
                    // pero el resumen de arriba suma `lineTotal`: mostrar aquí
                    // el unitario hacía que varias filas de $917 no cuadraran
                    // con el total del encabezado (CASI-007).
                    if item.price != nil {
                        Text(item.lineTotal.formattedPriceWithSymbol)
                            .font(Theme.captionDynamic)
                            .foregroundStyle(item.status == .purchased ? Color.appTextPurchased : Theme.statusPurchased)
                    }
                }

                if let caption = lineBreakdownCaption(for: item) {
                    Text(caption)
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Color.appTextSecondary)
                }

                if !item.note.isEmpty {
                    Text(item.note)
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Tag del supermercado si difiere de la lista
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
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
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
