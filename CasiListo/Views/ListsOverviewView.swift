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

    private var totalPendingItemsAcrossLists: Int {
        let activeIDs = Set(activeLists.map(\.id))
        return allItems.filter { item in
            guard let listID = item.listID else { return false }
            return activeIDs.contains(listID) && item.status == .pending
        }.count
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
        .navigationTitle("Mis Listas")
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
            Button("Eliminar \"\(list.title)\"", role: .destructive) {
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

    // MARK: - Tarjeta de resumen superior

    private var headerSummaryCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(activeLists.count == 1 ? "1 lista activa" : "\(activeLists.count) listas activas")
                    .font(Theme.captionDynamic.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)

                Text(totalPendingItemsAcrossLists == 1 ? "1 producto por comprar" : "\(totalPendingItemsAcrossLists) productos por comprar")
                    .font(Theme.headlineDynamic)
                    .foregroundStyle(Color.appTextPrimary)
            }

            Spacer()

            Button {
                HapticFeedback.impact()
                sheetDestination = .createList
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Nueva")
                        .fontWeight(.semibold)
                }
                .font(Theme.captionDynamic)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(Theme.onAccent)
                .background(Theme.accentYellow, in: Capsule())
            }
            .accessibilityLabel("Crear nueva lista de compra")
        }
        .padding(16)
        .background(
            Color.appCardBackground,
            in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous)
        )
        .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    // MARK: - Sección de Listas Activas

    private var activeListsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LISTAS ACTIVAS")
                .font(Theme.captionDynamic.weight(.bold))
                .foregroundStyle(Color.appTextSecondary)
                .padding(.horizontal, 4)

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
