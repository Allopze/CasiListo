import SwiftUI
import SwiftData
import AVFoundation

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
    @State private var priceString: String = ""
    @State private var selectedCategory: Category = .varios
    @State private var selectedStore: Store = .jumbo
    @State private var note: String = ""
    @State private var showSuggestions: Bool = false
    
    // Grabación de voz
    @State private var voiceNoteFilename: String? = nil
    @State private var isRecording = false
    @State private var recordingPulse = false
    @State private var recordingDuration = 0
    @State private var recordingTimer: Timer? = nil

    @FocusState private var isNameFocused: Bool
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

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
                storeSection
                voiceNoteSection
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
                if case .add = mode {
                    if let store = viewModel.selectedStore {
                        selectedStore = store
                    }
                    if !viewModel.quickAddText.isEmpty {
                        name = viewModel.quickAddText
                        viewModel.quickAddText = ""
                        if let suggested = SuggestedProducts.suggestedCategory(for: name) {
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

    private var voiceNoteSection: some View {
        Section {
            HStack(spacing: 16) {
                if isRecording {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .opacity(recordingPulse ? 1.0 : 0.2)
                            .animation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: recordingPulse)
                            .onAppear { recordingPulse = true }
                            .onDisappear { recordingPulse = false }
                        
                        Text("Grabando... \(recordingDuration)s")
                            .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                            .foregroundStyle(.red)
                    }
                    
                    Spacer()
                    
                    Button {
                        stopRecording()
                    } label: {
                        Text("Detener")
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                            .bold()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                } else if let filename = voiceNoteFilename {
                    Image(systemName: "waveform")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.accentYellow)
                    
                    Text("Nota de voz")
                        .font(Theme.bodyFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(Color.appTextPrimary)
                    
                    Spacer()
                    
                    VoiceNotePlayerButton(filename: filename)
                    
                    Button {
                        HapticFeedback.impact()
                        deleteVoiceNote()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.appTextSecondary)
                    
                    Text("Grabar nota de voz")
                        .font(Theme.bodyFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(Color.appTextSecondary)
                    
                    Spacer()
                    
                    Button {
                        startRecording()
                    } label: {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.accentYellow)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowInsets(.init(top: 8, leading: 12, bottom: 8, trailing: 12))
        } header: {
            Label("Nota de Voz", systemImage: "mic.fill")
        }
    }

    private func startRecording() {
        let filename = "voice_\(UUID().uuidString).m4a"
        
        if #available(iOS 17.0, *) {
            Task {
                let granted = await AVAudioApplication.requestRecordPermission()
                if granted {
                    HapticFeedback.selection()
                    let success = VoiceNoteService.shared.startRecording(filename: filename)
                    if success {
                        self.voiceNoteFilename = filename
                        self.isRecording = true
                        self.recordingDuration = 0
                        
                        self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                            self.recordingDuration += 1
                            if self.recordingDuration >= 30 {
                                self.stopRecording()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func stopRecording() {
        HapticFeedback.success()
        recordingTimer?.invalidate()
        recordingTimer = nil
        VoiceNoteService.shared.stopRecording()
        isRecording = false
    }
    
    private func deleteVoiceNote() {
        if let filename = voiceNoteFilename {
            VoiceNoteService.shared.deleteVoiceNote(filename: filename)
            voiceNoteFilename = nil
        }
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

            TextField("Precio opcional, ej: 1.50", text: $priceString)
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
            priceString = item.price.formattedPriceOrEmpty
            voiceNoteFilename = item.voiceNoteFilename
        }
    }

    private func saveItem() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let parsedPrice = Double(priceString.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))

        switch mode {
        case .add:
            let newItem = ShoppingItem(
                name: trimmedName,
                quantity: quantity.trimmingCharacters(in: .whitespaces),
                category: selectedCategory,
                note: note.trimmingCharacters(in: .whitespaces),
                sortOrder: viewModel.nextSortOrder(for: selectedCategory, in: allItems),
                price: parsedPrice,
                store: selectedStore,
                voiceNoteFilename: voiceNoteFilename
            )
            modelContext.insert(newItem)

        case .edit(let item):
            item.name = trimmedName
            item.quantity = quantity.trimmingCharacters(in: .whitespaces)
            item.category = selectedCategory
            item.store = selectedStore
            item.note = note.trimmingCharacters(in: .whitespaces)
            item.price = parsedPrice
            
            // Delete old voice note file if it changed
            if item.voiceNoteFilename != voiceNoteFilename {
                if let oldFile = item.voiceNoteFilename {
                    VoiceNoteService.shared.deleteVoiceNote(filename: oldFile)
                }
                item.voiceNoteFilename = voiceNoteFilename
            }
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
