import SwiftUI
import SwiftData
@testable import CasiListo

// El runtime de Objective-C exporta su propio `Category`, así que en
// posición de tipo hay que calificar el modelo con su módulo.

/// Vistas optimizadas para captura y renderizado de longitud completa (sin virtualización).
/// Al no usar `List`, `ImageRenderer` puede medir y rasterizar el 100% de la altura de la vista.

/// Contenedor de lista de compras activa en longitud completa.
struct ShoppingListFullContentView: View {
    let listTitle: String
    let activeList: ShoppingList?
    let allItems: [ShoppingItem]
    let categories: [CasiListo.Category]
    @Bindable var viewModel: ShoppingListViewModel

    @ScaledMetric(relativeTo: .body) private var cardPadding: CGFloat = Theme.cardPadding
    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat = Theme.smallCornerRadius

    var body: some View {
        VStack(spacing: 14) {
            // Cabecera superior
            HStack {
                Text(listTitle)
                    .font(Theme.titleDynamic)
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
            }
            .padding(.horizontal, cardPadding)
            .padding(.top, 16)

            // Filtros y barra de resumen
            VStack(alignment: .leading, spacing: 12) {
                StoreFilterBar(selectedStore: $viewModel.selectedStore)

                SummaryBarView(
                    pendingCount: viewModel.derivedSummary.pendingCount,
                    purchasedCount: viewModel.derivedSummary.purchasedCount,
                    showPurchased: $viewModel.showPurchased,
                    onArchivePurchased: nil
                )
            }
            .padding(.horizontal, cardPadding)

            // Categorías y productos
            ForEach(viewModel.derivedGroups, id: \.category.name) { group in
                categoryCard(for: group)
            }

            // Pie de lista (representación nativa de la barra rápida para evitar shaders de Liquid Glass en ImageRenderer)
            HStack(spacing: 10) {
                HStack {
                    Image(systemName: "cart.badge.plus")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.appTextSecondary)
                        .padding(.leading, 12)

                    Text("Añade “2kg arroz” o “pan x3”…")
                        .font(Theme.bodyDynamic)
                        .foregroundStyle(Color.appTextSecondary)

                    Spacer()
                }
                .frame(height: 40)
                .background(Color.appCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.controlCornerRadius))

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.accentYellow)
            }
            .padding(.horizontal, cardPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(Color.appBackground)
    }

    private func categoryCard(for group: (category: CasiListo.Category, items: [ShoppingItem])) -> some View {
        VStack(spacing: 0) {
            // Cabecera de la categoría
            HStack(spacing: 12) {
                Image(systemName: group.category.sfSymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Category.iconColor(for: group.category))
                    .frame(width: 30, height: 30)
                    .background(Category.accentColor(for: group.category).opacity(Category.badgeBackgroundOpacity))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                Text(group.category.displayName)
                    .font(Theme.bodyBoldDynamic)
                    .foregroundStyle(Color.appTextPrimary)

                Spacer()

                // Badge de conteo
                Text("\(group.items.filter { $0.status == .pending }.count)")
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .monospacedDigit()
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Color.appBackground)
                    .clipShape(Capsule())
            }
            .padding(.vertical, 12)
            .padding(.horizontal, cardPadding)
            .frame(minHeight: 56)

            // Ítems de la categoría
            ForEach(group.items, id: \.id) { item in
                Divider()
                    .background(Color.appSeparator)
                    .padding(.horizontal, cardPadding)

                ItemRowView(
                    item: item,
                    searchText: "",
                    showsStore: viewModel.selectedStore == nil,
                    onToggle: {},
                    onEdit: {},
                    onDelete: {},
                    onMarkStatus: { _ in }
                )
                .padding(.horizontal, cardPadding)
            }
        }
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .padding(.horizontal, cardPadding)
    }
}

/// Contenedor del catálogo de diagnóstico en longitud completa. Cada categoría
/// muestra una muestra acotada para que ImageRenderer no convierta el fixture
/// en una falsa promesa de contenido completo.
struct CatalogFullContentView: View {
    let catalogItems: [ProductCatalogItem]
    let categories: [CasiListo.Category]
    let activeList: ShoppingList?
    let allItems: [ShoppingItem]

    @ScaledMetric(relativeTo: .body) private var cardPadding: CGFloat = Theme.cardPadding
    @ScaledMetric(relativeTo: .body) private var cornerRadius: CGFloat = Theme.smallCornerRadius

    private var activeStatusByName: [String: ShoppingItemStatus] {
        var map: [String: ShoppingItemStatus] = [:]
        if let activeList {
            for item in allItems where item.listID == activeList.id {
                map[ProductNameNormalizer.normalize(item.name)] = item.status
            }
        }
        return map
    }

    private var groupedCatalog: [(category: CasiListo.Category, totalCount: Int, items: [ProductCatalogItem])] {
        let grouped = Dictionary(grouping: catalogItems) { $0.category.name }
        return categories
            .compactMap { category -> (category: CasiListo.Category, totalCount: Int, items: [ProductCatalogItem])? in
                guard let items = grouped[category.name], !items.isEmpty else { return nil }
                let sorted = items.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
                return (category, items.count, Array(sorted.prefix(4)))
            }
            .sorted { $0.category.name.localizedCompare($1.category.name) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 14) {
            // Cabecera superior
            HStack {
                Text("Catálogo")
                    .font(Theme.titleDynamic)
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
            }
            .padding(.horizontal, cardPadding)
            .padding(.top, 16)

            // Banner de destino
            if let activeList {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.appTextSecondary)

                    Text("Los productos se añadirán a ")
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Color.appTextSecondary)
                    + Text(activeList.title)
                        .font(Theme.captionDynamic.weight(.semibold))
                        .foregroundStyle(Color.appTextPrimary)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, cardPadding)
            }

            // Categorías y productos
            ForEach(groupedCatalog, id: \.category.name) { group in
                VStack(spacing: 0) {
                    // Cabecera de la categoría
                    HStack(spacing: 12) {
                        Image(systemName: group.category.sfSymbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Category.iconColor(for: group.category))
                            .frame(width: 30, height: 30)
                            .background(Category.accentColor(for: group.category).opacity(Category.badgeBackgroundOpacity))
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                        Text(group.category.displayName)
                            .font(Theme.bodyBoldDynamic)
                            .foregroundStyle(Color.appTextPrimary)

                        Spacer()

                        Text("\(group.totalCount)")
                            .font(Theme.captionDynamic)
                            .foregroundStyle(Color.appTextSecondary)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, cardPadding)
                    .frame(minHeight: 56)

                    // Filas de productos
                    ForEach(group.items) { item in
                        Divider()
                            .background(Color.appSeparator)
                            .padding(.horizontal, cardPadding)

                        HStack(spacing: 12) {
                            let status = activeStatusByName[ProductNameNormalizer.normalize(item.name)]
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
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

                            if status == .purchased {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color.appTextPurchased)
                            } else if status != nil {
                                Image(systemName: "cart.circle.fill")
                                    .font(.system(size: 24))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(Theme.onAccent, Theme.accentYellow)
                                    .frame(width: Theme.minimumTouchTarget, height: Theme.minimumTouchTarget)
                            } else {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color.appTextSecondary)
                                    .frame(width: Theme.minimumTouchTarget, height: Theme.minimumTouchTarget)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, cardPadding)
                    }
                }
                .background(Color.appCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .padding(.horizontal, cardPadding)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.appBackground)
        .padding(.bottom, 24)
    }
}

/// Contenedor de "Mis Listas" en longitud completa.
struct ListsOverviewFullContentView: View {
    let activeLists: [ShoppingList]
    let allItems: [ShoppingItem]

    private var totalPendingItemsAcrossLists: Int {
        let activeIDs = Set(activeLists.map(\.id))
        return allItems.filter { item in
            guard let listID = item.listID else { return false }
            return activeIDs.contains(listID) && item.status == .pending
        }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Cabecera superior
            HStack {
                Text("Mis Listas")
                    .font(Theme.titleDynamic)
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            if !activeLists.isEmpty {
                headerSummaryCard
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("LISTAS ACTIVAS")
                    .font(Theme.captionDynamic.weight(.bold))
                    .foregroundStyle(Color.appTextSecondary)
                    .padding(.horizontal, 4)

                VStack(spacing: 12) {
                    ForEach(activeLists) { list in
                        ListCardView(
                            list: list,
                            items: allItems.filter { $0.listID == list.id },
                            onSelect: {},
                            onEdit: {},
                            onDuplicate: {},
                            onDelete: {}
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .background(Color.appBackground)
        .padding(.bottom, 24)
    }

    private var headerSummaryCard: some View {
            HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(SpanishPluralization.count(activeLists.count, singular: "lista activa", plural: "listas activas"))
                    .font(Theme.captionDynamic.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)

                Text(SpanishPluralization.count(totalPendingItemsAcrossLists, singular: "producto por comprar", plural: "productos por comprar"))
                    .font(Theme.headlineDynamic)
                    .foregroundStyle(Color.appTextPrimary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            Color.appCardBackground,
            in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous)
        )
        .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
}

/// Contenedor de Ajustes en longitud completa (sin ScrollView para ImageRenderer).
struct SettingsFullContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
            HStack {
                Text("Ajustes")
                    .font(Theme.titleDynamic)
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.top, 16)

            SettingsView().settingsSections
        }
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(Color.appBackground)
    }
}

/// Contenedor de Detalle de Historial en longitud completa.
struct HistoryDetailFullContentView: View {
    let list: ShoppingList
    let allItems: [ShoppingItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(list.title)
                    .font(Theme.titleDynamic)
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.top, 16)

            ShoppingHistoryDetailView(list: list, allItems: allItems).contentWithoutScroll
        }
        .frame(maxWidth: .infinity)
        .background(Color.appBackground)
    }
}
