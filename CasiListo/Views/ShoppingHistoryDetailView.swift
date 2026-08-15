import SwiftUI
import SwiftData
import UIKit

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
        let items = listItems
        let dict = Dictionary(grouping: items) { $0.category }
        return dict.map { (category: $0.key, items: $0.value.sorted(by: { $0.name < $1.name })) }
            .sorted { $0.category.displayName < $1.category.displayName }
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
        .onAppear {
            guard let filename = list.receiptImageFilename else { return }
            receiptImage = ReceiptImageStore.image(named: filename)
        }
    }
    
    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Resumen de Gasto")
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Color.appTextSecondary)
                    
                    Text(list.totalSpent > 0 ? list.totalSpent.formattedPriceWithSymbol : "$0")
                        .font(Theme.titleDynamic)
                        .foregroundStyle(Theme.accentYellow)
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
                statIndicator(title: "Comprados", count: list.purchasedCount, icon: "checkmark.circle.fill", color: .green)
                
                if list.skippedCount > 0 {
                    statIndicator(title: "Pospuestos", count: list.skippedCount, icon: "clock.fill", color: .orange)
                }
                
                if list.unavailableCount > 0 {
                    statIndicator(title: "No Encontrados", count: list.unavailableCount, icon: "exclamationmark.triangle.fill", color: .red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if let completedAt = list.completedAt {
                Divider().background(Color.appSeparator)
                
                HStack {
                    Image(systemName: "calendar")
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Color.appTextSecondary)
                    
                    Text("Finalizada el \(completedAt.formatted(date: .long, time: .shortened))")
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
    
    private func statIndicator(title: String, count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text("\(count)")
                .bold()
            Text(title)
                .foregroundStyle(Color.appTextSecondary)
        }
        .font(Theme.captionDynamic)
    }
    
    private func categorySection(_ category: Category, items: [ShoppingItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header de la Categoría
            HStack(spacing: 8) {
                Image(systemName: category.sfSymbol)
                    .foregroundStyle(Theme.accentYellow)
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
                    
                    if !item.quantity.isEmpty {
                        Text(item.quantity)
                            .font(Theme.captionDynamic)
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.appSeparator)
                            .clipShape(Capsule())
                    }
                    
                    if let price = item.price {
                        Text(price.formattedPriceWithSymbol)
                            .font(Theme.captionDynamic)
                            .foregroundStyle(item.status == .purchased ? Color.appTextPurchased : .green)
                    }
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
                .foregroundStyle(.green)
        case .skipped:
            Image(systemName: "clock.fill")
                .font(.system(size: statusIconSize, weight: .bold))
                .foregroundStyle(.orange)
        case .unavailable:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: statusIconSize, weight: .bold))
                .foregroundStyle(.red)
        case .pending:
            Image(systemName: "circle")
                .font(.system(size: statusIconSize, weight: .bold))
                .foregroundStyle(Color.appTextSecondary)
        }
    }
}
