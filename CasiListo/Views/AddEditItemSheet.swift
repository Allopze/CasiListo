import SwiftUI
import SwiftData

/// Modal para crear o editar un ítem de la lista de compra.
struct AddEditItemSheet: View {
    enum Mode: Identifiable {
        case add
        case edit(ShoppingItem)

        var id: String {
            switch self {
            case .add:
                return "add"
            case .edit(let item):
                return item.id.uuidString
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let allItems: [ShoppingItem]
    let viewModel: ShoppingListViewModel

    @State private var name: String = ""
    @State private var quantity: String = ""
    @State private var selectedCategory: Category = .varios
    @State private var note: String = ""
    @State private var showSuggestions: Bool = false

    @FocusState private var isNameFocused: Bool

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var suggestions: [String] {
        SuggestedProducts.suggestions(for: name)
    }

    var body: some View {
        NavigationStack {
            Form {
                productSection
                detailsSection
                categorySection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(isEditing ? "Editar producto" : "Nuevo producto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appTextSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Guardar" : "Añadir") {
                        saveItem()
                        HapticFeedback.success()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .onAppear {
                loadExistingData()
            }
            .task {
                try? await Task.sleep(for: .milliseconds(300))
                isNameFocused = true
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Secciones

    private var productSection: some View {
        Section {
            TextField("Nombre del producto", text: $name)
                .focused($isNameFocused)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onChange(of: name) { _, newValue in
                    let nextSuggestions = SuggestedProducts.suggestions(for: newValue)
                    showSuggestions = !newValue.isEmpty && !nextSuggestions.isEmpty

                    if let suggested = SuggestedProducts.suggestedCategory(for: newValue) {
                        selectedCategory = suggested
                    }
                }

            if showSuggestions && !suggestions.isEmpty {
                SuggestionsListView(suggestions: suggestions) { suggestion in
                    name = suggestion
                    showSuggestions = false
                    if let category = SuggestedProducts.suggestedCategory(for: suggestion) {
                        selectedCategory = category
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(Theme.quickAnimation, value: showSuggestions)
                .listRowInsets(.init(top: 8, leading: 12, bottom: 12, trailing: 12))
            }
        } header: {
            Label("Producto", systemImage: "cart.badge.plus")
        } footer: {
            Text("Las sugerencias ajustan la categoría automáticamente cuando hay una coincidencia exacta.")
        }
    }

    private var detailsSection: some View {
        Section {
            TextField("Cantidad, ej: 2, 1 kg, 500 g", text: $quantity)
                .textInputAutocapitalization(.never)

            TextField("Nota", text: $note, axis: .vertical)
                .lineLimit(2...4)
        } header: {
            Label("Detalles", systemImage: "text.justify.left")
        }
    }

    private var categorySection: some View {
        Section {
            CategoryPickerView(selectedCategory: $selectedCategory)
                .listRowInsets(.init(top: 12, leading: 12, bottom: 12, trailing: 12))
                .listRowBackground(Color.clear)
        } header: {
            Label("Categoría", systemImage: selectedCategory.sfSymbol)
        }
    }

    private func loadExistingData() {
        if case .edit(let item) = mode {
            name = item.name
            quantity = item.quantity
            selectedCategory = item.category
            note = item.note
        }
    }

    private func saveItem() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        switch mode {
        case .add:
            let newItem = ShoppingItem(
                name: trimmedName,
                quantity: quantity.trimmingCharacters(in: .whitespaces),
                category: selectedCategory,
                note: note.trimmingCharacters(in: .whitespaces),
                sortOrder: viewModel.nextSortOrder(for: selectedCategory, in: allItems)
            )
            modelContext.insert(newItem)

        case .edit(let item):
            item.name = trimmedName
            item.quantity = quantity.trimmingCharacters(in: .whitespaces)
            item.category = selectedCategory
            item.note = note.trimmingCharacters(in: .whitespaces)
        }
    }
}

// MARK: - Subviews

private struct SuggestionsListView: View {
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            AdaptiveGlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(suggestions.prefix(8), id: \.self) { suggestion in
                        Button {
                            HapticFeedback.selection()
                            onSelect(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(Theme.chipFont)
                                .foregroundStyle(Color.appTextPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .glassFilterSurface(cornerRadius: Theme.chipCornerRadius, interactive: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
