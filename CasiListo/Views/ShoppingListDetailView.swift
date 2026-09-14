import SwiftUI
import SwiftData

/// Vista de detalle de una lista de compras específica.
/// Permite gestionar los productos de la lista seleccionada, filtrar por supermercado,
/// buscar en catálogo, importar texto, usar plantillas y registrar boletas.
struct ShoppingListDetailView: View {
    @Bindable var list: ShoppingList
    let allItems: [ShoppingItem]
    let allLists: [ShoppingList]
    let categories: [Category]
    var onShowHistory: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = ShoppingListViewModel()
    @State private var showsClearPurchasedDialog = false
    @State private var isEditingListSheetPresented = false
    @AppStorage(AppDefaultsKeys.hasSeenOnboardingV1) private var hasSeenOnboarding = false
    @State private var showsOnboarding = false

    private var activeItems: [ShoppingItem] {
        allItems.filter { $0.listID == list.id }
    }

    private var completedLists: [ShoppingList] {
        allLists
            .filter { $0.status == .completed }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if activeItems.isEmpty {
                EmptyStateView(
                    onAddTapped: { presentAddItem() },
                    hasHistory: !completedLists.isEmpty,
                    onShowHistory: onShowHistory,
                    onQuickAdd: { name in
                        viewModel.quickAddText = name
                        viewModel.addQuickItem(
                            to: list,
                            from: activeItems,
                            categories: categories,
                            context: modelContext
                        )
                    },
                    onShowTemplates: { viewModel.presentTemplates() }
                )
            } else {
                ShoppingListView(
                    activeList: list,
                    allItems: activeItems,
                    categories: categories,
                    viewModel: viewModel,
                    onEdit: { viewModel.presentEditItem($0) },
                    onAddTapped: { presentAddItem() },
                    onArchivePurchased: { showsClearPurchasedDialog = true }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // El ítem `.principal` reemplaza al título del navigation bar, así que
            // no se declara además un `.navigationTitle`: sería el mismo texto dos veces.
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image(systemName: list.iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(list.accentColor)
                        .accessibilityHidden(true)

                    Text(list.title)
                        .font(Theme.bodyBoldDynamic)
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(1)
                }
                .accessibilityAddTraits(.isHeader)
            }

            ToolbarItem(placement: .topBarTrailing) {
                menuButton
            }
        }
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Buscar en \(list.title)..."
        )
        .searchToolbarBehavior(.minimize)
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(item: $viewModel.presentedSheet) { sheetContent(for: $0) }
        .sheet(isPresented: $isEditingListSheetPresented) {
            AddEditListSheet(mode: .edit(list))
        }
        .confirmationDialog(
            "Archivar productos comprados",
            isPresented: $showsClearPurchasedDialog,
            titleVisibility: .visible
        ) {
            Button("Añadir boleta y archivar") {
                viewModel.presentReceipt(closesPurchase: true)
            }
            Button({
                let count = viewModel.itemCounts(from: activeItems).purchased
                return count == 1 ? "Archivar 1 comprado" : "Archivar \(count) comprados"
            }(), role: .destructive) {
                do {
                    try ShoppingPersistenceCoordinator(context: modelContext).archivePurchased(
                        from: activeItems,
                        activeList: list
                    )
                    HapticFeedback.success()
                } catch {
                    viewModel.presentPersistenceError(error)
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Mueve los comprados al historial de \"\(list.title)\". Con la boleta, CasiListo además registra los precios que pagaste.")
        }
        .alert(
            "No se pudieron guardar los cambios",
            isPresented: Binding(
                get: { viewModel.persistenceErrorMessage != nil },
                set: { if !$0 { viewModel.persistenceErrorMessage = nil } }
            )
        ) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(viewModel.persistenceErrorMessage ?? "Inténtalo nuevamente.")
        }
        // `initial: true` cubre la aparición; el resto del `onChange` cubre
        // que la persona active Reduce Motion con la app abierta. Sin la
        // segunda mitad, el VM se quedaba con el valor del primer render
        // hasta relanzar la app (CASI-010).
        .onChange(of: reduceMotion, initial: true) { _, isReduced in
            viewModel.reduceMotion = isReduced
        }
        .onAppear { presentOnboardingIfNeeded() }
        .onChange(of: activeItems.isEmpty) { _, _ in presentOnboardingIfNeeded() }
        // Cubre el flujo real más probable: lista vacía → "Usar plantilla" →
        // se puebla → se cierra el sheet → aparece la guía.
        .onChange(of: viewModel.presentedSheet?.id) { _, _ in presentOnboardingIfNeeded() }
        .sheet(isPresented: $showsOnboarding, onDismiss: { hasSeenOnboarding = true }) {
            OnboardingGuideSheet(onDismiss: { showsOnboarding = false })
        }
    }

    // MARK: - Menú de Opciones

    private var formattedShareText: String {
        let groups = viewModel.groupedItems(from: activeItems, categories: categories)
        let storeTitle = viewModel.selectedStore?.displayName ?? "Todos"
        guard !groups.isEmpty else { return "Mi lista \"\(list.title)\" en CasiListo (\(storeTitle)) está vacía." }

        var text = "📝 *Lista: \(list.title) (\(storeTitle))*\n\n"
        for group in groups {
            text += "*\(group.category.displayName.uppercased())*\n"
            for item in group.items {
                let check = item.isPurchased ? "✅" : "⬜"
                let qty = item.quantity.isEmpty ? "" : " (\(item.quantity))"
                let note = item.note.isEmpty ? "" : " [Nota: \(item.note)]"
                text += "\(check) \(item.name)\(qty)\(note)\n"
            }
            text += "\n"
        }
        return text
    }

    private var menuButton: some View {
        Menu {
            Button {
                HapticFeedback.selection()
                isEditingListSheetPresented = true
            } label: {
                Label("Personalizar lista", systemImage: "paintbrush.fill")
            }

            Divider()

            Button {
                HapticFeedback.selection()
                withAnimation(Theme.defaultAnimation(reduceMotion: reduceMotion)) {
                    viewModel.showPurchased.toggle()
                }
            } label: {
                Label(
                    viewModel.showPurchased ? "Ocultar comprados" : "Mostrar comprados",
                    systemImage: viewModel.showPurchased ? "eye.slash" : "eye"
                )
            }

            ShareLink(item: formattedShareText) {
                Label("Compartir lista", systemImage: "square.and.arrow.up")
            }

            Button {
                HapticFeedback.selection()
                viewModel.presentTextImporter()
            } label: {
                Label("Importar desde texto", systemImage: "doc.on.clipboard")
            }

            Button {
                HapticFeedback.selection()
                viewModel.presentTemplates()
            } label: {
                Label("Usar plantilla", systemImage: "square.grid.2x2")
            }

            Button {
                HapticFeedback.impact()
                viewModel.presentReceipt()
            } label: {
                Label("Registrar boleta", systemImage: "doc.text.viewfinder")
            }

            if viewModel.itemCounts(from: activeItems).purchased > 0 {
                Button(role: .destructive) { showsClearPurchasedDialog = true } label: {
                    Label("Archivar comprados", systemImage: "archivebox")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .buttonStyle(.glass)
        .accessibilityLabel("Opciones de lista")
        .accessibilityIdentifier("toolbar-options-menu")
    }

    // MARK: - Hojas modales

    @ViewBuilder
    private func sheetContent(for destination: ShoppingListSheetDestination) -> some View {
        switch destination {
        case .addItem:
            let draft = viewModel.quickAddText.isEmpty ? nil : viewModel.quickAddDraft(from: viewModel.quickAddText)
            AddEditItemSheet(
                mode: .add,
                activeList: list,
                allItems: activeItems,
                preselectedStore: viewModel.selectedStore,
                initialName: draft?.name ?? "",
                initialQuantity: draft?.quantity ?? "",
                onQuickAddConsumed: { viewModel.quickAddText = "" },
                nextSortOrder: { viewModel.nextSortOrder(for: $0, in: activeItems) },
                checkDuplicate: { viewModel.duplicateItem(named: $0, store: $1, in: activeItems, excluding: $2) },
                onItemAdded: { viewModel.revealCategory($0.category, itemID: $0.id) }
            )
        case .editItem(let item):
            AddEditItemSheet(
                mode: .edit(item),
                activeList: list,
                allItems: activeItems,
                preselectedStore: nil,
                initialName: "",
                initialQuantity: "",
                onQuickAddConsumed: {},
                nextSortOrder: { viewModel.nextSortOrder(for: $0, in: activeItems) },
                checkDuplicate: { viewModel.duplicateItem(named: $0, store: $1, in: activeItems, excluding: $2) }
            )
        case .receipt(let closesPurchase):
            ReceiptCaptureSheet(
                activeList: list,
                activeItems: activeItems,
                allItems: allItems,
                completedLists: completedLists,
                categories: categories,
                closesPurchase: closesPurchase,
                onShowHistory: {
                    viewModel.presentedSheet = nil
                    onShowHistory()
                }
            )
        case .textImporter:
            TextImporterSheet(
                activeList: list,
                allItems: activeItems,
                categories: categories,
                viewModel: viewModel,
                onFinished: {
                    viewModel.updateDerivedState(items: activeItems, categories: categories)
                }
            )
        case .templates:
            TemplatesSheet(
                activeList: list,
                allItems: activeItems,
                categories: categories,
                viewModel: viewModel,
                onFinished: {
                    viewModel.updateDerivedState(items: activeItems, categories: categories)
                }
            )
        }
    }

    private func presentAddItem() {
        HapticFeedback.impact()
        viewModel.presentAddItem()
    }

    /// La guía habla de marcar, editar y mantener presionado un producto:
    /// aparece cuando hay productos que mirar, no antes (CASI-011). Ni al
    /// primer arranque —competiría con los CTA de `ListsOverviewEmptyStateView`—
    /// ni justo tras crear la lista —`EmptyStateView` todavía no tiene
    /// ninguna fila que la guía pueda señalar. Y nunca encima de otro sheet:
    /// el de plantillas es justo el camino más probable para poblar la
    /// primera lista, y presentar mientras otro se cierra se descarta solo.
    private func presentOnboardingIfNeeded() {
        guard !hasSeenOnboarding,
              !activeItems.isEmpty,
              viewModel.presentedSheet == nil,
              !isEditingListSheetPresented,
              !showsClearPurchasedDialog
        else { return }
        showsOnboarding = true
    }
}
