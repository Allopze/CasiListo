import SwiftUI
import SwiftData

/// Modal para crear o editar un ítem de la lista de compra.
struct AddEditItemSheet: View {
    enum Mode: Identifiable {
        case add
        case edit(ShoppingItem)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let item): return item.id.uuidString
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(VoiceNoteService.self) private var voiceNoteService

    let mode: Mode
    let activeList: ShoppingList?
    let allItems: [ShoppingItem]
    let preselectedStore: Store?
    let initialName: String
    let initialQuantity: String
    let onQuickAddConsumed: () -> Void
    let nextSortOrder: (Category) -> Int
    let checkDuplicate: (String, Store, UUID?) -> ShoppingItem?

    @Query(sort: \Category.sortIndex) private var categories: [Category]

    @State private var name: String = ""
    @State private var quantity: String = ""
    @State private var selectedCategory: Category = Category.fallback
    @State private var selectedStore: Store = .jumbo
    @State private var note: String = ""
    @State private var priceText: String = ""
    @State private var showSuggestions: Bool = false
    @State private var voiceNoteFilename: String? = nil
    @State private var initialVoiceNoteFilename: String? = nil
    @State private var recordedVoiceNoteFilenames: Set<String> = []
    @State private var didSave: Bool = false

    @FocusState private var isNameFocused: Bool
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isValid: Bool {
        !trimmedName.isEmpty && duplicateItem == nil
    }

    private var suggestions: [String] {
        SuggestedProducts.suggestions(for: name)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var excludedDuplicateID: UUID? {
        if case .edit(let item) = mode {
            return item.id
        }
        return nil
    }

    private var duplicateItem: ShoppingItem? {
        checkDuplicate(name, selectedStore, excludedDuplicateID)
    }

    var body: some View {
        NavigationStack {
            Form {
                productSection
                detailsSection
                storeSection
                AddEditVoiceNoteSection(
                    voiceNoteFilename: $voiceNoteFilename,
                    onRecorded: handleRecordedVoiceNote,
                    onRemoved: handleRemovedVoiceNote
                )
                categorySection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(isEditing ? "Editar producto" : "Nuevo producto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Color.appTextSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Guardar" : "Añadir") {
                        saveItem()
                        didSave = true
                        HapticFeedback.success()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .onAppear {
                loadExistingData()
                if case .add = mode {
                    if let store = preselectedStore {
                        selectedStore = store
                    }
                    if !initialName.isEmpty {
                        name = initialName
                        quantity = initialQuantity
                        onQuickAddConsumed()
                        if let suggested = SuggestedProducts.suggestedCategory(for: name, in: categories) {
                            selectedCategory = suggested
                        }
                    }
                }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(300))
                isNameFocused = true
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onDisappear {
            cleanupTemporaryVoiceNotesIfNeeded()
        }
    }

    private var storeSection: some View {
        Section {
            Picker("Supermercado", selection: $selectedStore) {
                ForEach(Store.allCases) { store in
                    Text(store.displayName).tag(store)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(.init(top: 8, leading: 12, bottom: 8, trailing: 12))
        } header: {
            Label("Supermercado", systemImage: "storefront")
        }
    }

    private var productSection: some View {
        Section {
            TextField("Nombre del producto", text: $name)
                .focused($isNameFocused)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .accessibilityIdentifier("item-name-field")
                .onChange(of: name) { _, newValue in
                    let nextSuggestions = SuggestedProducts.suggestions(for: newValue)
                    showSuggestions = !newValue.isEmpty && !nextSuggestions.isEmpty

                    if let suggested = SuggestedProducts.suggestedCategory(for: newValue, in: categories) {
                        selectedCategory = suggested
                    }
                }

            if showSuggestions && !suggestions.isEmpty {
                SuggestionsListView(suggestions: suggestions) { suggestion in
                    name = suggestion
                    showSuggestions = false
                    if let category = SuggestedProducts.suggestedCategory(for: suggestion, in: categories) {
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
            if let duplicateItem {
                Text("\"\(duplicateItem.name)\" ya existe en \(selectedStore.displayName). Edita el producto existente o cambia el nombre.")
            } else {
                Text("Las sugerencias ajustan la categoría automáticamente cuando hay una coincidencia exacta.")
            }
        }
    }

    private var detailsSection: some View {
        Section {
            TextField("Cantidad, ej: 2, 1 kg, 500 g", text: $quantity)
                .textInputAutocapitalization(.never)

            TextField("Precio opcional ($)", text: $priceText)
                .keyboardType(.decimalPad)

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
            selectedStore = item.store
            note = item.note
            priceText = item.price.formattedPriceOrEmpty
            voiceNoteFilename = item.voiceNoteFilename
            initialVoiceNoteFilename = item.voiceNoteFilename
        }
    }

    private func saveItem() {
        guard !trimmedName.isEmpty else { return }
        guard duplicateItem == nil else { return }

        switch mode {
        case .add:
            let parsedPrice = Double(priceText.replacingOccurrences(of: ",", with: "."))
            let newItem = ShoppingItem(
                name: trimmedName,
                listID: activeList?.id,
                quantity: quantity.trimmingCharacters(in: .whitespaces),
                category: selectedCategory,
                note: note.trimmingCharacters(in: .whitespaces),
                sortOrder: nextSortOrder(selectedCategory),
                price: parsedPrice,
                store: selectedStore,
                voiceNoteFilename: voiceNoteFilename
            )
            modelContext.insert(newItem)
            if let activeList {
                ShoppingListLifecycleService.updateActiveListCounters(activeList, items: allItems + [newItem])
            }
            modelContext.safeSave()

        case .edit(let item):
            item.name = trimmedName
            item.quantity = quantity.trimmingCharacters(in: .whitespaces)
            item.category = selectedCategory
            item.store = selectedStore
            item.note = note.trimmingCharacters(in: .whitespaces)
            item.price = Double(priceText.replacingOccurrences(of: ",", with: "."))
            
            if item.voiceNoteFilename != voiceNoteFilename {
                if let oldFile = item.voiceNoteFilename {
                    voiceNoteService.deleteVoiceNote(filename: oldFile)
                }
                item.voiceNoteFilename = voiceNoteFilename
            }
            if let activeList {
                ShoppingListLifecycleService.updateActiveListCounters(activeList, items: allItems)
            }
            modelContext.safeSave()
        }
    }

    private func handleRecordedVoiceNote(_ filename: String) {
        recordedVoiceNoteFilenames.insert(filename)
    }

    private func handleRemovedVoiceNote(_ filename: String) {
        if recordedVoiceNoteFilenames.contains(filename) {
            voiceNoteService.deleteVoiceNote(filename: filename)
            recordedVoiceNoteFilenames.remove(filename)
        }
    }

    private func cleanupTemporaryVoiceNotesIfNeeded() {
        if didSave {
            for filename in recordedVoiceNoteFilenames where filename != voiceNoteFilename {
                voiceNoteService.deleteVoiceNote(filename: filename)
            }
        } else {
            for filename in recordedVoiceNoteFilenames {
                voiceNoteService.deleteVoiceNote(filename: filename)
            }
            voiceNoteFilename = initialVoiceNoteFilename
        }

        recordedVoiceNoteFilenames.removeAll()
    }
}
