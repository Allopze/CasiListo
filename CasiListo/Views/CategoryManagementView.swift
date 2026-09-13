import SwiftUI
import SwiftData

/// Administración de categorías. La eliminación siempre explica qué datos se
/// reasignarán a «Varios» antes de modificar la base local.
struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortIndex) private var categories: [Category]
    @State private var sheetMode: AddEditCategorySheet.Mode?
    @State private var categoryPendingDeletion: Category?
    @State private var errorMessage: String?

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 20
    @ScaledMetric(relativeTo: .body) private var rowSpacing: CGFloat = 10

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            List {
                Section {
                    ForEach(categories) { category in
                        categoryRow(for: category)
                            .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.appCardBackground)
                            .swipeActions(edge: .trailing) {
                                if category.name != "Varios" {
                                    Button(role: .destructive) { categoryPendingDeletion = category } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                            }
                    }
                    .onMove(perform: moveCategories)
                } header: {
                    Text("MIS CATEGORÍAS").font(Theme.captionDynamic).foregroundStyle(Color.appTextSecondary).bold()
                } footer: {
                    Text("Arrastra las categorías para cambiar el orden de visualización de tu lista de compras.")
                        .font(Theme.captionDynamic).foregroundStyle(Color.appTextSecondary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Categorías")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { sheetMode = .add } label: { Image(systemName: "plus").bold().foregroundStyle(Theme.accentInteractive) }
                    .accessibilityLabel("Nueva categoría")
            }
        }
        .sheet(item: $sheetMode) { AddEditCategorySheet(mode: $0) }
        .confirmationDialog(
            "¿Eliminar \(categoryPendingDeletion?.name ?? "esta categoría")?",
            isPresented: Binding(get: { categoryPendingDeletion != nil }, set: { if !$0 { categoryPendingDeletion = nil } }),
            titleVisibility: .visible
        ) {
            Button("Reasignar y eliminar", role: .destructive) {
                if let category = categoryPendingDeletion { deleteCategory(category) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            if let category = categoryPendingDeletion {
                Text("\(affectedItemCount(for: category)) producto(s) y \(affectedCatalogCount(for: category)) sugerencia(s) se reasignarán a «Varios». Esta acción no se puede deshacer.")
            }
        }
        .alert(
            "No se pudo actualizar la categoría",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Inténtalo nuevamente.")
        }
    }

    private func categoryRow(for category: Category) -> some View {
        Button { sheetMode = .edit(category) } label: {
            HStack(spacing: rowSpacing) {
                Image(systemName: category.sfSymbol)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(Theme.accentInteractive)
                    .frame(width: 32, height: 32)
                    .background(Theme.accentYellow.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name).font(Theme.bodyBoldDynamic).foregroundStyle(Color.appTextPrimary)
                    Text(category.name == "Varios" ? "Categoría predeterminada del sistema" : (category.isSystem ? "Categoría del sistema" : "Personalizada"))
                        .font(Theme.captionDynamic).foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                if category.name != "Varios" { Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.appTextSecondary) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // El resto de la fila ya avisa que "Varios" es del sistema, pero el
        // botón seguía abriendo su sheet de edición: se podía renombrar, y el
        // bootstrap creaba un "Varios" nuevo al no encontrar el original en
        // el siguiente arranque.
        .disabled(!Category.isEditable(category))
    }

    private func moveCategories(from source: IndexSet, to destination: Int) {
        var sorted = categories
        sorted.move(fromOffsets: source, toOffset: destination)
        for (index, category) in sorted.enumerated() { category.sortIndex = index }
        do {
            try ShoppingPersistenceCoordinator(context: modelContext).commitWithoutWidget()
            HapticFeedback.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func affectedItemCount(for category: Category) -> Int { category.items?.count ?? 0 }
    private func affectedCatalogCount(for category: Category) -> Int { category.catalogItems?.count ?? 0 }

    private func deleteCategory(_ category: Category) {
        guard category.name != "Varios" else { return }
        let fallback = Category.resolvedFallback(in: modelContext)
        for item in category.items ?? [] {
            item.categoryRelation = fallback
            item.categoryRawValue = fallback.name
        }
        for item in category.catalogItems ?? [] {
            item.categoryRelation = fallback
            item.categoryRawValue = fallback.name
        }
        category.items = []
        category.catalogItems = []
        modelContext.delete(category)
        do {
            try ShoppingPersistenceCoordinator(context: modelContext).commitWithoutWidget()
            categoryPendingDeletion = nil
            HapticFeedback.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
