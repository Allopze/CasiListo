import SwiftUI
import SwiftData

/// Modal para seleccionar y aplicar plantillas predefinidas de compras.
struct TemplatesSheet: View {
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
    }

    private let templates: [PresetTemplate] = [
        PresetTemplate(
            id: "asado",
            title: "Asado Familiar",
            emoji: "🥩",
            description: "Carnes, carbón, choripanes y bebidas para el fin de semana.",
            items: [
                ("Lomo vetado", "1.5 kg"),
                ("Chorizos", "1 pack"),
                ("Carbón", "1 saco"),
                ("Pan marraqueta", "1 kg"),
                ("Pebre / Tomates", "1 kg"),
                ("Cerveza / Bebidas", "6 pack")
            ]
        ),
        PresetTemplate(
            id: "desayuno",
            title: "Desayuno Semanal",
            emoji: "🍳",
            description: "Esenciales para comenzar cada mañana.",
            items: [
                ("Leche entera", "2 lt"),
                ("Huevos", "12 un"),
                ("Pan molde", "1 un"),
                ("Mantequilla", "1 un"),
                ("Queso laminado", "200 g"),
                ("Jamón", "200 g"),
                ("Café", "1 frasco")
            ]
        ),
        PresetTemplate(
            id: "limpieza",
            title: "Limpieza del Hogar",
            emoji: "🧹",
            description: "Detergente, lavaloza y artículos de aseo.",
            items: [
                ("Detergente líquido", "3 lt"),
                ("Lavaloza", "750 ml"),
                ("Papel higiénico", "12 rollos"),
                ("Toalla de papel", "3 rollos"),
                ("Limpiador multiuso", "1 lt"),
                ("Esponjas de loza", "1 pack")
            ]
        ),
        PresetTemplate(
            id: "despensa",
            title: "Despensa Básica",
            emoji: "🥫",
            description: "Arroz, fideos, aceite y conservas esenciales.",
            items: [
                ("Arroz grado 1", "2 kg"),
                ("Fideos", "3 paquetes"),
                ("Aceite vegetal", "1 lt"),
                ("Salsa de tomate", "3 cajitas"),
                ("Atún en agua", "4 latas"),
                ("Sal de mesa", "1 kg")
            ]
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
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
            HStack(spacing: 12) {
                Text(template.emoji)
                    .font(.largeTitle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.title)
                        .font(.headline)
                        .foregroundStyle(Color.appTextPrimary)

                    Text(template.description)
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                ForEach(template.items, id: \.name) { item in
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Theme.accentYellow)
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

            Button {
                applyTemplate(template)
            } label: {
                Label("Añadir estos \(template.items.count) productos", systemImage: "plus.app.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.accentYellow)
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
    }

    private func applyTemplate(_ template: PresetTemplate) {
        var itemsWithNewEntries = allItems
        var insertedItems: [ShoppingItem] = []
        var addedCount = 0
        for item in template.items {
            let category = SuggestedProducts.suggestedCategory(for: item.name, in: categories)
                ?? categories.first { $0.name == "Varios" }
                ?? Category.fallback
            let store = viewModel.selectedStore ?? SuggestedProducts.suggestedStore(for: item.name)
            guard !DuplicatePolicy.isDuplicate(named: item.name, store: store, in: itemsWithNewEntries) else { continue }

            let newItem = ShoppingItem(
                name: item.name,
                listID: activeList?.id,
                quantity: item.quantity,
                category: category,
                sortOrder: viewModel.nextSortOrder(for: category, in: itemsWithNewEntries),
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
            try ShoppingPersistenceCoordinator(context: modelContext).importItems(
                insertedItems,
                allActiveItems: itemsWithNewEntries
            )
            HapticFeedback.success()
            dismiss()
            onFinished()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
