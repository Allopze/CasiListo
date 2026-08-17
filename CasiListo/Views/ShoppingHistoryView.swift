import SwiftUI
import SwiftData

/// Pestaña de historial de compras completadas.
struct ShoppingHistoryView: View {
    @Query(sort: \ShoppingItem.createdAt, order: .forward) private var allItems: [ShoppingItem]
    @Query(sort: \ShoppingList.createdAt, order: .forward) private var allLists: [ShoppingList]

    private var completedLists: [ShoppingList] {
        allLists
            .filter { $0.status == .completed }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }

    var body: some View {
        NavigationStack {
            List {
                if completedLists.isEmpty {
                    ContentUnavailableView(
                        "Sin historial",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Cuando archives productos comprados, CasiListo guardará un resumen aquí.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(completedLists) { list in
                        NavigationLink {
                            ShoppingHistoryDetailView(list: list, allItems: allItems)
                        } label: {
                            historyRow(for: list)
                        }
                        .listRowBackground(Color.appCardBackground)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Historial")
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                if !completedLists.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: exportCSVText(), preview: SharePreview("Historial CasiListo.csv", image: Image(systemName: "tablecells"))) {
                            Label("Exportar CSV", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    private func historyRow(for list: ShoppingList) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(list.title, systemImage: list.storeScope?.sfSymbol ?? "bag.fill")
                    .font(.headline)
                if list.receiptImageFilename != nil {
                    Image(systemName: "doc.text.viewfinder")
                        .foregroundStyle(Color.appTextSecondary)
                        .accessibilityLabel("Tiene boleta asociada")
                }
                Spacer()
                if list.totalSpent > 0 {
                    Text(list.totalSpent.formattedPriceWithSymbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accentInteractive)
                }
            }

            // Los recuentos se apoyan en el icono para ahorrar espacio; sin
            // etiqueta explícita VoiceOver solo dicta números sueltos.
            HStack(spacing: 12) {
                Label("\(list.purchasedCount)", systemImage: "checkmark.circle.fill")
                    .accessibilityLabel("\(list.purchasedCount) comprados")
                if list.pendingCount > 0 {
                    Label("\(list.pendingCount)", systemImage: "circle")
                        .accessibilityLabel("\(list.pendingCount) pendientes")
                }
                if list.skippedCount > 0 {
                    Label("\(list.skippedCount)", systemImage: "clock")
                        .accessibilityLabel("\(list.skippedCount) pospuestos")
                }
                if list.unavailableCount > 0 {
                    Label("\(list.unavailableCount)", systemImage: "exclamationmark.triangle")
                        .accessibilityLabel("\(list.unavailableCount) no encontrados")
                }
            }
            .font(.caption)
            .foregroundStyle(Color.appTextSecondary)

            if let completedAt = list.completedAt {
                Text(AppDateFormatting.shortWithTime(completedAt))
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func exportCSVText() -> String {
        PerformanceSignpost.measure("Exportar CSV") {
            let itemsByListID = Dictionary(grouping: allItems, by: \.listID)
            var rows = [["Fecha", "Lista", "Supermercado", "Producto", "Cantidad", "Categoria", "Estado", "Precio"]]
            for list in completedLists {
                let dateStr = AppDateFormatting.numericWithTime(list.completedAt ?? list.createdAt)
                let storeStr = list.storeScope?.displayName ?? "Todos"

                for item in itemsByListID[list.id] ?? [] {
                    let priceStr = item.price.map { String($0) } ?? ""
                    rows.append([dateStr, list.title, storeStr, item.name, item.quantity, item.category.name, item.status.rawValue, priceStr])
                }
            }
            return CSVSerializer.document(rows: rows)
        }
    }
}
