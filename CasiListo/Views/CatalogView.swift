import SwiftUI
import SwiftData

/// Pestaña de catálogo: los productos habituales, separados de la compra.
/// Desde aquí se agregan productos a la lista activa con un toque.
struct CatalogView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ProductCatalogItem.name, order: .forward) private var catalogItems: [ProductCatalogItem]
    @Query(sort: \Category.sortIndex) private var categories: [Category]
    @Query(sort: \ShoppingItem.createdAt, order: .forward) private var allItems: [ShoppingItem]
    @Query(sort: \ShoppingList.createdAt, order: .forward) private var allLists: [ShoppingList]

    @State private var searchText = ""
    @State private var collapsedCategories: Set<String> = []
    @State private var hasLoadedCollapseState = false
    @State private var errorMessage: String?

    @ScaledMetric(relativeTo: .body) private var cardPadding: CGFloat = Theme.cardPadding
    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat = Theme.smallCornerRadius
    @ScaledMetric(relativeTo: .body) private var headerMinimumHeight: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var iconTileSize: CGFloat = 30
    @ScaledMetric(relativeTo: .body) private var rowVerticalPadding: CGFloat = 10

    private static let collapseKey = "catalogCollapsedCategoryNames"

    private var activeList: ShoppingList? {
        allLists.first { $0.status == .active }
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
            .background(Color.appBackground)
            .navigationTitle("Catálogo")
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Buscar en el catálogo...")
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
                                        deleteCatalogItem(catalogItem)
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
            withAnimation(Theme.defaultAnimation) {
                toggleCollapse(category)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: category.sfSymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Category.iconColor(forName: category.name))
                    .frame(width: iconTileSize, height: iconTileSize)
                    .background(Category.accentColor(forName: category.name).opacity(Category.badgeBackgroundOpacity))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                Text(category.displayName)
                    .font(Theme.bodyBoldDynamic)
                    .foregroundStyle(Color.appTextPrimary)

                Spacer()

                Text("\(count)")
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .monospacedDigit()

                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appTextSecondary)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 180))
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
        .accessibilityLabel("\(category.displayName), \(count) productos en el catálogo")
        .accessibilityValue(isCollapsed ? "Colapsada" : "Expandida")
        .accessibilityIdentifier("catalog-section-\(category.name)")
    }

    private func catalogRow(for catalogItem: ProductCatalogItem) -> some View {
        let status = activeStatusByName[ProductNameNormalizer.normalize(catalogItem.name)]

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(catalogItem.name)
                    .font(Theme.bodyDynamic)
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(2)

                if status == .purchased {
                    Text("Comprado en esta visita")
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Color.appTextSecondary)
                } else if status != nil {
                    Text("En tu compra")
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }

            Spacer(minLength: 8)

            trailingButton(for: catalogItem, status: status)
        }
        .padding(.vertical, rowVerticalPadding)
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
                activeList: activeList,
                activeItems: activeItems,
                context: modelContext
            )
        } catch {
            errorMessage = error.localizedDescription
        }
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

    private func deleteCatalogItem(_ catalogItem: ProductCatalogItem) {
        modelContext.delete(catalogItem)
        try? modelContext.save()
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
}
