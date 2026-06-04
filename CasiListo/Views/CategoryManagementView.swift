import SwiftUI
import SwiftData

/// Vista de administración de categorías dinámicas.
/// Permite reordenar, editar y crear nuevas categorías.
struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortIndex) private var categories: [Category]
    @Environment(\.dismiss) private var dismiss

    @State private var sheetMode: AddEditCategorySheet.Mode? = nil
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 20
    @ScaledMetric(relativeTo: .body) private var rowSpacing: CGFloat = 10
    @ScaledMetric(relativeTo: .body) private var listPadding: CGFloat = 16

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
                                    Button(role: .destructive) {
                                        HapticFeedback.impact()
                                        withAnimation(Theme.defaultAnimation) {
                                            deleteCategory(category)
                                        }
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                            }
                    }
                    .onMove(perform: moveCategories)
                } header: {
                    Text("MIS CATEGORÍAS")
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Color.appTextSecondary)
                        .bold()
                } footer: {
                    Text("Arrastra las categorías para cambiar el orden de visualización de tu lista de compras.")
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Categorías")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    HapticFeedback.selection()
                    sheetMode = .add
                } label: {
                    Image(systemName: "plus")
                        .bold()
                        .foregroundStyle(Theme.accentYellow)
                }
                .accessibilityLabel("Nueva categoría")
            }
        }
        .sheet(item: $sheetMode) { mode in
            AddEditCategorySheet(mode: mode)
        }
    }

    private func categoryRow(for category: Category) -> some View {
        Button {
            HapticFeedback.selection()
            sheetMode = .edit(category)
        } label: {
            HStack(spacing: rowSpacing) {
                Image(systemName: category.sfSymbol)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(Theme.accentYellow)
                    .frame(width: 32, height: 32)
                    .background(Theme.accentYellow.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(Theme.bodyBoldDynamic)
                        .foregroundStyle(Color.appTextPrimary)

                    if category.name == "Varios" {
                        Text("Categoría predeterminada del sistema")
                            .font(Theme.captionDynamic)
                            .foregroundStyle(Color.appTextSecondary)
                    } else if category.isSystem {
                        Text("Categoría del sistema")
                            .font(Theme.captionDynamic)
                            .foregroundStyle(Color.appTextSecondary)
                    } else {
                        Text("Personalizada")
                            .font(Theme.captionDynamic)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }

                Spacer()

                if category.name != "Varios" {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func moveCategories(from source: IndexSet, to destination: Int) {
        var sortedCategories = categories
        sortedCategories.move(fromOffsets: source, toOffset: destination)
        for (index, category) in sortedCategories.enumerated() {
            category.sortIndex = index
        }
        try? modelContext.save()
        HapticFeedback.selection()
    }

    private func deleteCategory(_ category: Category) {
        guard category.name != "Varios" else { return }

        // Buscar fallback
        let fallback = Category.resolvedFallback(in: modelContext)

        // Reasociar ítems de compras
        if let items = category.items {
            for item in items {
                item.categoryRelation = fallback
                item.categoryRawValue = fallback.name
            }
        }

        // Reasociar catálogo de sugerencias
        if let catalog = category.catalogItems {
            for item in catalog {
                item.categoryRelation = fallback
                item.categoryRawValue = fallback.name
            }
        }

        modelContext.delete(category)
        try? modelContext.save()
    }
}
