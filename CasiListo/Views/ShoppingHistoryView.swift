import SwiftUI
import SwiftData

/// Pestaña de historial de compras completadas.
struct ShoppingHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var listPendingDeletion: ShoppingList?
    @State private var errorMessage: String?
    /// No es un caché: solo vive mientras el share sheet está presentado.
    /// Antes se compartía un `String` cacheado en `.task(id: allItems)`, que
    /// compara identidad de array, no contenido — editar el precio de un
    /// producto del historial no lo regeneraba, y además un `String` no
    /// ofrece "Guardar en Archivos" (CASI-005).
    @State private var fileToShare: SharedFile?
    @State private var exportErrorMessage: String?
    @State private var isExporting = false

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
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                HapticFeedback.impact()
                                listPendingDeletion = list
                            } label: {
                                Label("Eliminar compra", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Historial")
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .confirmationDialog(
                "¿Eliminar esta compra del historial?",
                isPresented: Binding(
                    get: { listPendingDeletion != nil },
                    set: { if !$0 { listPendingDeletion = nil } }
                ),
                titleVisibility: .visible,
                presenting: listPendingDeletion
            ) { list in
                Button("Eliminar \(list.title)", role: .destructive) {
                    deletePurchase(list)
                }
                Button("Cancelar", role: .cancel) {}
            } message: { _ in
                Text("Se borrarán sus productos, sus precios y la foto de la boleta. Esta acción no se puede deshacer.")
            }
            .alert(
                "No se pudo eliminar la compra",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Inténtalo nuevamente.")
            }
            .alert(
                "No se pudo exportar el historial",
                isPresented: Binding(
                    get: { exportErrorMessage != nil },
                    set: { if !$0 { exportErrorMessage = nil } }
                )
            ) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(exportErrorMessage ?? "Inténtalo nuevamente.")
            }
            .toolbar {
                if !completedLists.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { exportCSV() } label: {
                            Label("Exportar CSV", systemImage: "square.and.arrow.up")
                        }
                        .disabled(isExporting)
                        .accessibilityIdentifier("history-export-csv")
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if isExporting {
                    ProgressView("Preparando el historial…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.appBackground)
                        .accessibilityLabel("Preparando el historial")
                }
            }
            .sheet(item: $fileToShare) { ShareSheet(url: $0.url) }
        }
    }

    /// Insignia de tienda + título, recuentos en palabras y el total en la
    /// columna de la boleta. Antes los recuentos eran íconos sueltos («◎ 1»)
    /// que nadie sabía leer.
    private func historyRow(for list: ShoppingList) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ListBadgeView(
                symbol: list.storeScope?.sfSymbol ?? "bag.fill",
                color: list.accentColor,
                size: 40,
                iconSize: 18,
                cornerRadius: 12
            )

            VStack(alignment: .leading, spacing: 4) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        historyTitle(for: list)
                        Spacer(minLength: 4)
                        historyTotal(for: list)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        historyTitle(for: list)
                        historyTotal(for: list)
                    }
                }

                Text(countsSummary(for: list))
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let completedAt = list.completedAt {
                    Text(AppDateFormatting.shortWithTime(completedAt))
                        .font(Theme.receiptMonoCaption)
                        .foregroundStyle(Color.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func historyTitle(for list: ShoppingList) -> some View {
        Text(list.title)
            .font(Theme.bodyBoldDynamic)
            .foregroundStyle(Color.appTextPrimary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
    }

    @ViewBuilder
    private func historyTotal(for list: ShoppingList) -> some View {
        if list.totalSpent > 0 {
            Text(list.totalSpent.formattedPriceWithSymbol)
                .font(Theme.receiptMono.weight(.bold))
                .foregroundStyle(Color.appTextPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .accessibilityLabel("Total pagado \(list.totalSpent.formattedPriceWithSymbol)")
        }
    }

    /// «15 comprados · 2 pospuestos · con boleta», en palabras.
    private func countsSummary(for list: ShoppingList) -> String {
        var parts = [SpanishPluralization.count(list.purchasedCount, singular: "comprado", plural: "comprados")]
        if list.pendingCount > 0 {
            parts.append(SpanishPluralization.count(list.pendingCount, singular: "pendiente", plural: "pendientes"))
        }
        if list.skippedCount > 0 {
            parts.append(SpanishPluralization.count(list.skippedCount, singular: "pospuesto", plural: "pospuestos"))
        }
        if list.unavailableCount > 0 {
            parts.append(SpanishPluralization.count(list.unavailableCount, singular: "no encontrado", plural: "no encontrados"))
        }
        if list.receiptImageFilename != nil {
            parts.append("con boleta")
        }
        return parts.joined(separator: " · ")
    }

    /// Archivar nunca borra un `ShoppingItem`: solo le cambia el `listID`. Sin
    /// esta acción, una compra mal registrada quedaba en el historial para
    /// siempre y sus filas y su JPEG se acumulaban sin techo.
    private func deletePurchase(_ list: ShoppingList) {
        for item in allItems where item.listID == list.id {
            modelContext.delete(item)
        }
        modelContext.delete(list)

        let persistence = ShoppingPersistenceCoordinator(context: modelContext)
        do {
            try persistence.commit()
            // Barre la foto de la boleta, que ya no tiene quien la referencie.
            try persistence.cleanUnreferencedFiles()
            listPendingDeletion = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportCSV() {
        guard !isExporting else { return }
        isExporting = true
        Task {
            defer { isExporting = false }
            do {
                let url = try await HistoryCSVExportService.exportFileAsync(
                    completedLists: completedLists,
                    items: allItems
                )
                fileToShare = SharedFile(url: url)
            } catch {
                exportErrorMessage = error.localizedDescription
            }
        }
    }
}
