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

    private func historyRow(for list: ShoppingList) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                historyTitleRow(for: list, vertical: false)
                historyTitleRow(for: list, vertical: true)
            }

            // Los recuentos se apoyan en el icono para ahorrar espacio; sin
            // etiqueta explícita VoiceOver solo dicta números sueltos.
            ViewThatFits(in: .horizontal) {
                historyCounts(for: list, vertical: false)
                historyCounts(for: list, vertical: true)
            }
            .font(.caption)
            .foregroundStyle(Color.appTextSecondary)

            if let completedAt = list.completedAt {
                Text(AppDateFormatting.shortWithTime(completedAt))
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func historyCounts(for list: ShoppingList, vertical: Bool) -> some View {
        let layout = vertical
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            Label("\(list.purchasedCount)", systemImage: "checkmark.circle.fill")
                .accessibilityLabel(
                    SpanishPluralization.count(
                        list.purchasedCount,
                        singular: "producto comprado",
                        plural: "productos comprados"
                    )
                )
            if list.pendingCount > 0 {
                Label("\(list.pendingCount)", systemImage: "circle")
                    .accessibilityLabel(
                        SpanishPluralization.count(
                            list.pendingCount,
                            singular: "producto pendiente",
                            plural: "productos pendientes"
                        )
                    )
            }
            if list.skippedCount > 0 {
                Label("\(list.skippedCount)", systemImage: "clock")
                    .accessibilityLabel(
                        SpanishPluralization.count(
                            list.skippedCount,
                            singular: "producto pospuesto",
                            plural: "productos pospuestos"
                        )
                    )
            }
            if list.unavailableCount > 0 {
                Label("\(list.unavailableCount)", systemImage: "exclamationmark.triangle")
                    .accessibilityLabel(
                        SpanishPluralization.count(
                            list.unavailableCount,
                            singular: "producto no encontrado",
                            plural: "productos no encontrados"
                        )
                    )
            }
        }
    }

    @ViewBuilder
    private func historyTitleRow(for list: ShoppingList, vertical: Bool) -> some View {
        let layout = vertical
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 8))
        layout {
            HStack(spacing: 6) {
                Label(list.title, systemImage: list.storeScope?.sfSymbol ?? "bag.fill")
                    .font(.headline)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                if list.receiptImageFilename != nil {
                    Image(systemName: "doc.text.viewfinder")
                        .foregroundStyle(Color.appTextSecondary)
                        .accessibilityLabel("Tiene boleta asociada")
                }
            }

            if list.totalSpent > 0 {
                Text(list.totalSpent.formattedPriceWithSymbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accentInteractive)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
