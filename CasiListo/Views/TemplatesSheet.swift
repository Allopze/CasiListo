import SwiftUI
import SwiftData

/// Modal para seleccionar y aplicar plantillas predefinidas de compras.
struct TemplatesSheet: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let activeList: ShoppingList?
    let allItems: [ShoppingItem]
    let categories: [Category]
    let viewModel: ShoppingListViewModel
    let onFinished: () -> Void
    @State private var errorMessage: String?

    struct PresetTemplate: Identifiable {
        let id: String
        let title: String
        let emoji: String
        let description: String
        let items: [(name: String, quantity: String)]
        /// Las plantillas grandes muestran un resumen en vez de listar cada producto.
        var isSummarized: Bool = false
    }

    /// Plantilla generada con todo el catálogo de productos habituales,
    /// para partir con la lista completa desde un arranque vacío.
    private var fullCatalogTemplate: PresetTemplate {
        var seen = Set<String>()
        let uniqueNames = DefaultCategory.allCases
            .flatMap { SuggestedProducts.byCategory[$0] ?? [] }
            .filter { seen.insert(ProductNameNormalizer.normalize($0)).inserted }
        return PresetTemplate(
            id: "catalogo-completo",
            title: "Catálogo completo",
            emoji: "🛒",
            description: "Todos los productos habituales, organizados en \(DefaultCategory.allCases.count) categorías.",
            items: uniqueNames.map { (name: $0, quantity: "") },
            isSummarized: true
        )
    }

    private let templates: [PresetTemplate] = [
        PresetTemplate(
            id: "asado",
            title: "Asado Familiar",
            emoji: "🥩",
            description: "Carnes, carbón, choripanes y bebidas para el fin de semana.",
            items: [
                ("Lomo liso", "1.5 kg"),
                ("Chorizo cocinar", "1 pack"),
                ("Carbón", "1 saco"),
                ("Pan marraqueta", "1 kg"),
                ("Tomates", "1 kg"),
                ("Cerveza", "6 pack")
            ]
        ),
        PresetTemplate(
            id: "desayuno",
            title: "Desayuno Semanal",
            emoji: "🍳",
            description: "Esenciales para comenzar cada mañana.",
            items: [
                ("Leche semi", "2 lt"),
                ("Huevos", "12 un"),
                ("Pan marraqueta", "1 kg"),
                ("Mantequilla", "1 un"),
                ("Queso laminado", "200 g"),
                ("Jamón de pavo", "200 g"),
                ("Café grano", "1 frasco")
            ]
        ),
        PresetTemplate(
            id: "limpieza",
            title: "Limpieza del Hogar",
            emoji: "🧹",
            description: "Detergente, lavaloza y artículos de aseo.",
            items: [
                ("Detergente", "3 lt"),
                ("Lavavajillas", "750 ml"),
                ("Papel higiénico", "12 rollos"),
                ("Papel de cocina", "3 rollos"),
                ("Limpiasuelo", "1 lt"),
                ("Toallas desinfectante", "1 pack")
            ]
        ),
        PresetTemplate(
            id: "despensa",
            title: "Despensa Básica",
            emoji: "🥫",
            description: "Arroz, fideos, aceite y conservas esenciales.",
            items: [
                ("Arroz", "2 kg"),
                ("Fideo", "3 paquetes"),
                ("Aceite girasol", "1 lt"),
                ("Salsa de tomate", "3 cajitas"),
                ("Atún en aceite", "4 latas"),
                ("Sal fina", "1 kg")
            ]
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    templateCard(fullCatalogTemplate)
                    ForEach(templates) { template in
                        templateCard(template)
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground)
            .navigationTitle("Plantillas de Lista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .alert(
            "No se pudo aplicar la plantilla",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Los productos que ya estaban en la lista se omitieron.")
        }
    }

    private func templateCard(_ template: PresetTemplate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { templateHeaderContent(template) }
                VStack(alignment: .leading, spacing: 8) { templateHeaderContent(template) }
            }

            Divider()

            if template.isSummarized {
                Label(
                    summarizedTemplateLabel(for: template),
                    systemImage: "square.stack.3d.up.fill"
                )
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(template.items, id: \.name) { item in
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(item.quantity)
                                    .font(.caption)
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                            .padding(.leading, 24)
                        } else {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Theme.accentInteractive)
                                    .font(.caption)
                                Text(item.name)
                                    .font(.subheadline)
                                Spacer()
                                Text(item.quantity)
                                    .font(.caption)
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                        }
                    }
                }
            }

            Button {
                applyTemplate(template)
            } label: {
                Label(
                    "Añadir estos \(SpanishPluralization.count(template.items.count, singular: "producto", plural: "productos"))",
                    systemImage: "plus.app.fill"
                )
                    .font(.subheadline.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.accentYellow)
                    .foregroundStyle(Theme.onAccent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
    }

    @ViewBuilder
    private func templateHeaderContent(_ template: PresetTemplate) -> some View {
        Text(template.emoji)
            .font(.largeTitle)

        VStack(alignment: .leading, spacing: 2) {
            Text(template.title)
                .font(.headline)
                .foregroundStyle(Color.appTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(template.description)
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .layoutPriority(1)
    }

    private func summarizedTemplateLabel(for template: PresetTemplate) -> String {
        "\(SpanishPluralization.count(template.items.count, singular: "producto", plural: "productos")) — los que ya tengas en la lista se omiten."
    }

    private func applyTemplate(_ template: PresetTemplate) {
        var itemsWithNewEntries = allItems
        var insertedItems: [ShoppingItem] = []
        var addedCount = 0

        // Índices incrementales para que aplicar plantillas grandes sea O(n).
        var existingKeys = Set(allItems.map { "\(ProductNameNormalizer.normalize($0.name))|\($0.store.rawValue)" })
        // Se calcula en línea y no en una func anidada: el compilador de
        // Xcode 26.2 (Swift 6.2) no infiere MainActor para la func local y el
        // archive de release murió con «sending 'category' risks causing
        // data races» al pasar el @Model al ViewModel.
        var nextOrders: [String: Int] = [:]

        for item in template.items {
            let category = SuggestedProducts.suggestedCategory(for: item.name, in: categories)
                ?? categories.first { $0.name == "Varios" }
                ?? Category.fallback
            let store = viewModel.selectedStore ?? SuggestedProducts.suggestedStore(for: item.name)
            let key = "\(ProductNameNormalizer.normalize(item.name))|\(store.rawValue)"
            guard existingKeys.insert(key).inserted else { continue }

            let sortOrder = nextOrders[category.name] ?? viewModel.nextSortOrder(for: category, in: allItems)
            nextOrders[category.name] = sortOrder + 1

            let newItem = ShoppingItem(
                name: item.name,
                listID: activeList?.id,
                quantity: item.quantity,
                category: category,
                sortOrder: sortOrder,
                store: store
            )
            modelContext.insert(newItem)
            itemsWithNewEntries.append(newItem)
            insertedItems.append(newItem)
            addedCount += 1
        }
        guard addedCount > 0 else {
            errorMessage = "Todos los productos de esta plantilla ya existen en el supermercado seleccionado."
            return
        }
        do {
            try ShoppingPersistenceCoordinator(context: modelContext).importItems(insertedItems)
            HapticFeedback.success()
            dismiss()
            onFinished()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
