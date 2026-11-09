import SwiftUI
import SwiftData

/// Menú general de listas de compras ("Mis Listas").
/// Muestra todas las listas activas en tarjetas interactivas con su icono,
/// color temático, contadores de productos y vista previa.
struct ListsOverviewView: View {
    let onSelectList: (ShoppingList) -> Void
    let onShowHistory: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<ShoppingList> { $0.statusRawValue == activeShoppingListStatusRawValue },
        sort: \ShoppingList.createdAt,
        order: .forward
    ) private var activeLists: [ShoppingList]

    @Query(sort: \ShoppingItem.createdAt, order: .forward) private var allItems: [ShoppingItem]

    @State private var sheetDestination: SheetDestination?
    @State private var listToDelete: ShoppingList?
    @State private var showsDeleteConfirmation = false
    @State private var persistenceErrorMessage: String?
    @ScaledMetric(relativeTo: .largeTitle) private var overviewNumeralSize: CGFloat = 56

    private enum SheetDestination: Identifiable {
        case createList
        case editList(ShoppingList)

        var id: String {
            switch self {
            case .createList: return "create"
            case .editList(let list): return "edit_\(list.id)"
            }
        }
    }

    private var pendingItemsAcrossLists: [ShoppingItem] {
        let activeIDs = Set(activeLists.map(\.id))
        return allItems.filter { item in
            guard let listID = item.listID else { return false }
            return activeIDs.contains(listID) && item.status == .pending
        }
    }

    private var totalPendingItemsAcrossLists: Int {
        pendingItemsAcrossLists.count
    }

    /// Pendientes por supermercado, solo los que tienen algo. Es lo que no dice
    /// ninguna tarjeta por sí sola: a qué súper conviene ir.
    private var pendingByStore: [(store: Store, count: Int)] {
        let pending = pendingItemsAcrossLists
        return Store.allCases.compactMap { store in
            let count = pending.filter { $0.store == store }.count
            return count > 0 ? (store, count) : nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Sin listas, la tarjeta solo informaría «0 listas activas, 0
                // productos» y añadiría un tercer botón «Nueva» junto al «+» de la
                // barra y al «Crear mi primera lista» del estado vacío.
                if !activeLists.isEmpty {
                    headerSummaryCard
                }

                if activeLists.isEmpty {
                    ListsOverviewEmptyStateView(
                        onCreateTapped: {
                            HapticFeedback.impact()
                            sheetDestination = .createList
                        },
                        onQuickStarterTapped: { title, symbol, colorHex in
                            createQuickStarter(title: title, symbol: symbol, colorHex: colorHex)
                        }
                    )
                } else {
                    activeListsSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Mis listas")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticFeedback.impact()
                    sheetDestination = .createList
                } label: {
                    Label("Nueva lista", systemImage: "plus")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Crear nueva lista")
            }
        }
        .sheet(item: $sheetDestination) { destination in
            switch destination {
            case .createList:
                AddEditListSheet(mode: .add) { createdList in
                    onSelectList(createdList)
                }
            case .editList(let list):
                AddEditListSheet(mode: .edit(list))
            }
        }
        .confirmationDialog(
            "¿Eliminar esta lista?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible,
            presenting: listToDelete
        ) { list in
            Button("Eliminar «\(list.title)»", role: .destructive) {
                deleteList(list)
            }
            Button("Cancelar", role: .cancel) {}
        } message: { _ in
            Text("Se eliminarán la lista y los productos asociados permanentemente.")
        }
        .alert(
            "No se pudieron guardar los cambios",
            isPresented: Binding(
                get: { persistenceErrorMessage != nil },
                set: { if !$0 { persistenceErrorMessage = nil } }
            )
        ) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(persistenceErrorMessage ?? "Inténtalo nuevamente.")
        }
    }

    // MARK: - Panel de resumen superior

    /// El mismo panel carbón que encabeza cada lista, a escala de todas: el
    /// ícono de la app hecho pantalla (DESIGN.md). Informa, no actúa: la
    /// creación tiene un único CTA primario en la barra de navegación.
    private var headerSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(totalPendingItemsAcrossLists)")
                        .font(Theme.displayNumeral(size: overviewNumeralSize))
                        .tracking(-1.5)
                        .foregroundStyle(Theme.accentYellow)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText(value: Double(totalPendingItemsAcrossLists)))
                    (Text("por comprar ")
                        .foregroundStyle(Theme.onPanel)
                        + Text("en " + SpanishPluralization.count(activeLists.count, singular: "lista", plural: "listas"))
                        .foregroundStyle(Theme.onPanelSecondary))
                        .font(Theme.bodyBoldDynamic)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if !pendingByStore.isEmpty {
                Rectangle()
                    .fill(Theme.panelTrack)
                    .frame(height: 1)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { storeSplitLabels }
                    VStack(alignment: .leading, spacing: 6) { storeSplitLabels }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(Theme.panelEdge, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(overviewAccessibilityLabel)
    }

    @ViewBuilder
    private var storeSplitLabels: some View {
        if pendingByStore.count == 1, let only = pendingByStore.first {
            storeLabel(only.store, text: "Todo en \(only.store.displayName)")
        } else {
            ForEach(pendingByStore, id: \.store) { entry in
                storeLabel(entry.store, text: "\(entry.count) en \(entry.store.displayName)")
            }
        }
    }

    private func storeLabel(_ store: Store, text: String) -> some View {
        Label(text, systemImage: store.sfSymbol)
            .font(Theme.captionDynamic.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(Theme.onPanel)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var overviewAccessibilityLabel: String {
        var label = SpanishPluralization.count(totalPendingItemsAcrossLists, singular: "producto por comprar", plural: "productos por comprar")
            + " en " + SpanishPluralization.count(activeLists.count, singular: "lista", plural: "listas")
        if !pendingByStore.isEmpty {
            label += ". " + pendingByStore.map { "\($0.count) en \($0.store.displayName)" }.joined(separator: ", ")
        }
        return label
    }

    // MARK: - Sección de Listas Activas

    private var activeListsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVStack(spacing: 12) {
                ForEach(activeLists) { list in
                    ListCardView(
                        list: list,
                        items: allItems.filter { $0.listID == list.id },
                        onSelect: { onSelectList(list) },
                        onEdit: { sheetDestination = .editList(list) },
                        onDuplicate: { duplicateList(list) },
                        onDelete: {
                            listToDelete = list
                            showsDeleteConfirmation = true
                        }
                    )
                }
            }
        }
    }

    // MARK: - Acciones

    private func createQuickStarter(title: String, symbol: String, colorHex: String) {
        let newList = ShoppingList(title: title, status: .active, iconName: symbol, colorHex: colorHex)
        modelContext.insert(newList)
        guard commit() else { return }
        HapticFeedback.success()
        onSelectList(newList)
    }

    private func duplicateList(_ original: ShoppingList) {
        let duplicate = ShoppingList(
            title: "Copia de \(original.title)",
            status: .active,
            iconName: original.iconName,
            colorHex: original.colorHex
        )
        modelContext.insert(duplicate)

        let itemsToCopy = allItems.filter { $0.listID == original.id && $0.status == .pending }
        for item in itemsToCopy {
            let copiedItem = ShoppingItem(
                name: item.name,
                listID: duplicate.id,
                quantity: item.quantity,
                category: item.category,
                note: item.note,
                isPurchased: false,
                status: .pending,
                sortOrder: item.sortOrder,
                price: item.price,
                store: item.store
            )
            modelContext.insert(copiedItem)
        }

        guard commit() else { return }
        HapticFeedback.success()
    }

    private func deleteList(_ list: ShoppingList) {
        let itemsToDelete = allItems.filter { $0.listID == list.id }
        for item in itemsToDelete {
            modelContext.delete(item)
        }
        modelContext.delete(list)
        guard commit(cleaningFiles: true) else { return }
        HapticFeedback.impact()
    }

    /// Guarda y refresca el widget. Devuelve `false` —tras mostrar la alerta— si
    /// SwiftData rechazó el cambio, para no seguir como si se hubiera guardado.
    private func commit(cleaningFiles: Bool = false) -> Bool {
        let persistence = ShoppingPersistenceCoordinator(context: modelContext)
        do {
            try persistence.commit()
            // Las notas de voz de los productos eliminados quedan huérfanas en disco.
            if cleaningFiles {
                try persistence.cleanUnreferencedFiles()
            }
            return true
        } catch {
            persistenceErrorMessage = error.localizedDescription
            return false
        }
    }
}
