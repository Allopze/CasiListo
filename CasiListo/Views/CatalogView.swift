import SwiftUI
import SwiftData

/// Pestaña de catálogo: los productos habituales, separados de la compra.
/// Desde aquí se agregan productos a la lista activa con un toque.
struct CatalogView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ProductCatalogItem.name, order: .forward) private var catalogItems: [ProductCatalogItem]
    @Query(sort: \Category.sortIndex) private var categories: [Category]
    @Query(sort: \ShoppingItem.createdAt, order: .forward) private var allItems: [ShoppingItem]
    @Query(sort: \ShoppingList.createdAt, order: .forward) private var allLists: [ShoppingList]

    @AppStorage(ActiveListSelection.storageKey) private var selectedActiveListID = ""

    @State private var searchText = ""
    @State private var collapsedCategories: Set<String> = []
    @State private var hasLoadedCollapseState = false
    @State private var errorMessage: String?
    @State private var catalogItemPendingDeletion: ProductCatalogItem?

    @ScaledMetric(relativeTo: .body) private var cardPadding: CGFloat = Theme.cardPadding
    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat = Theme.smallCornerRadius
    @ScaledMetric(relativeTo: .body) private var headerMinimumHeight: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var iconTileSize: CGFloat = 30
    @ScaledMetric(relativeTo: .body) private var rowVerticalPadding: CGFloat = 10

    // No `private`: `ShoppingPersistenceCoordinator.resetAllData` y el
    // bootstrap de `ContentView` necesitan borrar esta misma clave, y antes
    // la repetían como literal suelto en ambos sitios.
    static let collapseKey = "catalogCollapsedCategoryNames"

    private var activeList: ShoppingList? {
        ActiveListSelection.resolve(from: allLists, storedID: selectedActiveListID)
    }

    private var activeItems: [ShoppingItem] {
        guard let activeList else { return [] }
        return allItems.filter { $0.listID == activeList.id }
    }

    /// Estado en la compra activa por nombre normalizado.
    private var activeStatusByName: [String: ShoppingItemStatus] {
        var map: [String: ShoppingItemStatus] = [:]
        for item in activeItems {
            map[ProductNameNormalizer.normalize(item.name)] = item.status
        }
        return map
    }

    private var groupedCatalog: [(category: Category, items: [ProductCatalogItem])] {
        let filtered = searchText.isEmpty
            ? catalogItems
            : catalogItems.filter { ProductNameNormalizer.contains($0.name, query: searchText) }
        let grouped = Dictionary(grouping: filtered) { $0.category.name }
        return categories
            .compactMap { category -> (category: Category, items: [ProductCatalogItem])? in
                guard let items = grouped[category.name], !items.isEmpty else { return nil }
                return (category, items.sorted { $0.name.localizedCompare($1.name) == .orderedAscending })
            }
            .sorted { $0.category.name.localizedCompare($1.category.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Group {
                if catalogItems.isEmpty {
                    ContentUnavailableView(
                        "Catálogo vacío",
                        systemImage: "books.vertical",
                        description: Text("Los productos que añadas a tus compras aparecerán aquí para reutilizarlos.")
                    )
                } else {
                    catalogList
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                destinationBanner
            }
            .background(Color.appBackground)
            .navigationTitle("Catálogo")
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Buscar en el catálogo...")
            .confirmationDialog(
                "¿Quitar del catálogo?",
                isPresented: Binding(
                    get: { catalogItemPendingDeletion != nil },
                    set: { if !$0 { catalogItemPendingDeletion = nil } }
                ),
                titleVisibility: .visible,
                presenting: catalogItemPendingDeletion
            ) { item in
                Button("Eliminar \(item.name)", role: .destructive) {
                    deleteCatalogItem(item)
                    catalogItemPendingDeletion = nil
                }
                Button("Cancelar", role: .cancel) {}
            } message: { _ in
                Text("Dejará de aparecer como sugerencia. Los productos que ya están en tus listas no se tocan.")
            }
            .alert(
                "No se pudo actualizar la lista",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Inténtalo nuevamente.")
            }
        }
        .onAppear(perform: loadCollapseStateIfNeeded)
    }

    /// A qué lista van los productos. Sin esto no había ninguna indicación de
    /// destino, ni siquiera cuando sí existía una lista activa.
    private var destinationBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: activeList == nil ? "plus.circle" : "cart.fill")
                .font(Theme.captionDynamic)
                .foregroundStyle(Theme.accentInteractive)
                .accessibilityHidden(true)

            Text(activeList.map { "Añadiendo a \($0.title)" } ?? "Se creará una lista nueva")
                .font(Theme.captionDynamic)
                .foregroundStyle(Color.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, cardPadding)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.appBackground)
        .accessibilityElement(children: .combine)
    }

    private var catalogList: some View {
        List {
            ForEach(groupedCatalog, id: \.category.name) { group in
                let isCollapsed = searchText.isEmpty && collapsedCategories.contains(group.category.name)

                Section {
                    categoryHeader(for: group.category, count: group.items.count, isCollapsed: isCollapsed)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    if !isCollapsed {
                        ForEach(group.items) { catalogItem in
                            let isLast = catalogItem.id == group.items.last?.id
                            catalogRow(for: catalogItem)
                                .listRowInsets(.init(
                                    top: 2,
                                    leading: cardPadding * 2,
                                    bottom: isLast ? 8 : 2,
                                    trailing: cardPadding * 2
                                ))
                                .listRowSeparator(isLast ? .hidden : .visible, edges: .bottom)
                                .listRowSeparatorTint(Color.appSeparator)
                                .listRowBackground(rowBackground(isLast: isLast))
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        HapticFeedback.impact()
                                        catalogItemPendingDeletion = catalogItem
                                    } label: {
                                        Label("Eliminar del catálogo", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(.custom(14))
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 1)
    }

    private func categoryHeader(for category: Category, count: Int, isCollapsed: Bool) -> some View {
        Button {
            HapticFeedback.selection()
            withAnimation(Theme.defaultAnimation(reduceMotion: reduceMotion)) {
                toggleCollapse(category)
            }
        } label: {
            ViewThatFits(in: .horizontal) {
                categoryHeaderContent(category, count: count, isCollapsed: isCollapsed, axis: .horizontal)
                categoryHeaderContent(category, count: count, isCollapsed: isCollapsed, axis: .vertical)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, cardPadding)
            .frame(maxWidth: .infinity, minHeight: headerMinimumHeight, alignment: .leading)
            .background {
                UnevenRoundedRectangle(
                    topLeadingRadius: cornerRadius,
                    bottomLeadingRadius: isCollapsed ? cornerRadius : 0,
                    bottomTrailingRadius: isCollapsed ? cornerRadius : 0,
                    topTrailingRadius: cornerRadius,
                    style: .continuous
                )
                .fill(Color.appCardBackground)
            }
            .padding(.horizontal, cardPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(category.displayName), "
                + "\(SpanishPluralization.count(count, singular: "producto", plural: "productos")) en el catálogo"
        )
        .accessibilityValue(isCollapsed ? "Colapsada" : "Expandida")
        .accessibilityIdentifier("catalog-section-\(category.name)")
    }

    private enum CategoryHeaderAxis { case horizontal, vertical }

    @ViewBuilder
    private func categoryHeaderContent(
        _ category: Category,
        count: Int,
        isCollapsed: Bool,
        axis: CategoryHeaderAxis
    ) -> some View {
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 12))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
        layout {
            HStack(spacing: 12) {
                Image(systemName: category.sfSymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Category.iconColor(for: category))
                    .frame(width: iconTileSize, height: iconTileSize)
                    .background(Category.accentColor(for: category).opacity(Category.badgeBackgroundOpacity))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                Text(category.displayName)
                    .font(Theme.bodyBoldDynamic)
                    .foregroundStyle(Color.appTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if axis == .horizontal {
                Spacer(minLength: 0)
            }

            HStack {
                if axis == .vertical { Spacer(minLength: 0) }
                Text("\(count)")
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .monospacedDigit()

                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appTextSecondary)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 180))
            }
        }
    }

    @ViewBuilder
    private func catalogRow(for catalogItem: ProductCatalogItem) -> some View {
        let status = activeStatusByName[ProductNameNormalizer.normalize(catalogItem.name)]

        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    catalogItemLabel(for: catalogItem, status: status)
                    HStack {
                        Spacer(minLength: 0)
                        trailingButton(for: catalogItem, status: status)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    catalogItemLabel(for: catalogItem, status: status)
                    Spacer(minLength: 8)
                    trailingButton(for: catalogItem, status: status)
                }
            }
        }
        .padding(.vertical, rowVerticalPadding)
    }

    private func catalogItemLabel(for catalogItem: ProductCatalogItem, status: ShoppingItemStatus?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(catalogItem.name)
                .font(Theme.bodyDynamic)
                .foregroundStyle(Color.appTextPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                .fixedSize(horizontal: false, vertical: true)

            if status == .purchased {
                Text("Comprado en esta visita")
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if status != nil {
                Text("En tu compra")
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .layoutPriority(1)
    }

    @ViewBuilder
    private func trailingButton(for catalogItem: ProductCatalogItem, status: ShoppingItemStatus?) -> some View {
        switch status {
        case .purchased:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color.appTextPurchased)
                .accessibilityLabel("\(catalogItem.name) ya comprado")
        case .some:
            Button {
                HapticFeedback.selection()
                removeFromList(catalogItem)
            } label: {
                // Carrito, no visto bueno: el círculo amarillo con check ya
                // significa «comprado» en el detalle de la lista y aquí quiere
                // decir «ya está en tu compra». Dos sentidos para un mismo icono.
                Image(systemName: "cart.circle.fill")
                    .font(.system(size: 24))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Theme.onAccent, Theme.accentYellow)
                    .frame(width: Theme.minimumTouchTarget, height: Theme.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Quitar \(catalogItem.name) de la compra")
        case nil:
            Button {
                HapticFeedback.impact()
                addToList(catalogItem)
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(width: Theme.minimumTouchTarget, height: Theme.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Añadir \(catalogItem.name) a la compra")
            .accessibilityIdentifier("catalog-add-\(catalogItem.id.uuidString)")
        }
    }

    private func rowBackground(isLast: Bool) -> some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: isLast ? cornerRadius : 0,
            bottomTrailingRadius: isLast ? cornerRadius : 0,
            topTrailingRadius: 0,
            style: .continuous
        )
        .fill(Color.appCardBackground)
        .padding(.horizontal, cardPadding)
    }

    // MARK: - Acciones

    private func addToList(_ catalogItem: ProductCatalogItem) {
        do {
            try CatalogService.addToActiveList(
                catalogItem,
                activeList: try resolvedDestinationList(),
                activeItems: activeItems,
                context: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// El Catálogo puede ser la primera pantalla en la que la persona hace algo:
    /// en instalación limpia no existe ninguna lista y aquí ya hay 355 productos
    /// con su «+». Tocar ese botón es una decisión, así que la lista se crea en
    /// ese momento; antes el producto se perdía en un huérfano invisible.
    private func resolvedDestinationList() throws -> ShoppingList {
        if let activeList { return activeList }
        let created = try ShoppingListLifecycleService.createActiveList(
            in: modelContext,
            title: "Mi compra"
        )
        selectedActiveListID = created.id.uuidString
        return created
    }

    private func removeFromList(_ catalogItem: ProductCatalogItem) {
        do {
            try CatalogService.removeFromActiveList(
                catalogItem,
                activeList: activeList,
                activeItems: activeItems,
                context: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Único sitio del repo que se saltaba el coordinador y tragaba el error.
    /// Ahora que el borrado por fin persiste entre arranques, vale la pena
    /// protegerlo con una confirmación.
    private func deleteCatalogItem(_ catalogItem: ProductCatalogItem) {
        modelContext.delete(catalogItem)
        do {
            try ShoppingPersistenceCoordinator(context: modelContext).commitWithoutWidget()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Colapso persistido

    private func loadCollapseStateIfNeeded() {
        guard !hasLoadedCollapseState else { return }
        hasLoadedCollapseState = true
        if let stored = UserDefaults.standard.stringArray(forKey: Self.collapseKey) {
            collapsedCategories = Set(stored)
        } else {
            collapsedCategories = Set(categories.map(\.name))
            persistCollapseState()
        }
    }

    private func toggleCollapse(_ category: Category) {
        if collapsedCategories.contains(category.name) {
            collapsedCategories.remove(category.name)
        } else {
            collapsedCategories.insert(category.name)
        }
        persistCollapseState()
    }

    private func persistCollapseState() {
        UserDefaults.standard.set(
            Array(collapsedCategories).sorted(),
            forKey: Self.collapseKey
        )
    }

    /// Migra un nombre de categoría dentro del colapso del catálogo, que vive
    /// en una única clave global. Mismo motivo que
    /// `ShoppingListViewModel.renameCollapsedCategory`: sin esto, renombrar
    /// una categoría colapsada la dejaba huérfana en el catálogo también.
    static func renameCollapsedCategory(from oldName: String, to newName: String, in defaults: UserDefaults = .standard) {
        guard oldName != newName,
              let stored = defaults.stringArray(forKey: collapseKey),
              stored.contains(oldName)
        else { return }
        defaults.set(stored.map { $0 == oldName ? newName : $0 }, forKey: collapseKey)
    }
}
