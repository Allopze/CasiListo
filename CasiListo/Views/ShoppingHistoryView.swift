import SwiftUI

struct ShoppingHistoryView: View {
    let completedLists: [ShoppingList]
    let allItems: [ShoppingItem]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if completedLists.isEmpty {
                    ContentUnavailableView(
                        "Sin historial",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Cuando limpies productos comprados, CasiListo guardara un resumen aqui.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(completedLists) { list in
                        NavigationLink {
                            ShoppingHistoryDetailView(list: list, allItems: allItems)
                        } label: {
                            historyRow(for: list)
                        }
                    }
                }
            }
            .navigationTitle("Historial")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !completedLists.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        ShareLink(item: exportCSVText(), preview: SharePreview("Historial CasiListo.csv", image: Image(systemName: "tablecells"))) {
                            Label("Exportar CSV", systemImage: "square.and.arrow.up")
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
                        .foregroundStyle(Theme.accentYellow)
                }
            }

            HStack(spacing: 12) {
                Label("\(list.purchasedCount)", systemImage: "checkmark.circle.fill")
                if list.pendingCount > 0 {
                    Label("\(list.pendingCount)", systemImage: "circle")
                }
                if list.skippedCount > 0 {
                    Label("\(list.skippedCount)", systemImage: "clock")
                }
                if list.unavailableCount > 0 {
                    Label("\(list.unavailableCount)", systemImage: "exclamationmark.triangle")
                }
            }
            .font(.caption)
            .foregroundStyle(Color.appTextSecondary)

            if let completedAt = list.completedAt {
                Text(completedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func exportCSVText() -> String {
        var csv = "Fecha,Lista,Supermercado,Producto,Cantidad,Categoria,Estado,Precio\n"
        for list in completedLists {
            let listItems = allItems.filter { $0.listID == list.id }
            let dateStr = (list.completedAt ?? list.createdAt).formatted(date: .numeric, time: .shortened)
            let storeStr = list.storeScope?.displayName ?? "Todos"

            for item in listItems {
                let priceStr = item.price != nil ? "\(item.price!)" : ""
                csv += "\"\(dateStr)\",\"\(list.title)\",\"\(storeStr)\",\"\(item.name)\",\"\(item.quantity)\",\"\(item.category.name)\",\"\(item.status.rawValue)\",\"\(priceStr)\"\n"
            }
        }
        return csv
    }
}
