import SwiftUI
import SwiftData

/// Modal para crear o editar una categoría.
struct AddEditCategorySheet: View {
    enum Mode: Identifiable {
        case add
        case edit(Category)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let category): return category.id
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortIndex) private var allCategories: [Category]

    let mode: Mode

    @State private var name: String = ""
    @State private var selectedSymbol: String = "tag.fill"
    @State private var autoAssignSymbol: Bool = true
    
    @FocusState private var isNameFocused: Bool
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    @ScaledMetric(relativeTo: .body) private var iconSelectorSize: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var previewIconSize: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var symbolPadding: CGFloat = 8

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var originalCategory: Category? {
        if case .edit(let category) = mode { return category }
        return nil
    }

    private var isValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        
        // No permitir duplicados de nombre (comparar ignorando mayúsculas y diacríticos)
        let normalizedNew = trimmed.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        
        for category in allCategories {
            // Si estamos editando, ignorar la categoría actual
            if let originalCategory, category.id == originalCategory.id {
                continue
            }
            let normalizedExisting = category.name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            if normalizedNew == normalizedExisting {
                return false
            }
        }
        
        return true
    }

    private var columns: [GridItem] {
        [
            GridItem(.adaptive(minimum: iconSelectorSize, maximum: iconSelectorSize * 1.5), spacing: 10)
        ]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        // Icon Preview Circular Container
                        ZStack {
                            Circle()
                                .fill(Theme.accentYellow.opacity(0.12))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: selectedSymbol)
                                .font(.system(size: previewIconSize * CGFloat(accessibilityTextSizeScale), weight: .semibold))
                                .foregroundStyle(Theme.accentYellow)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Nombre de categoría, ej: Juguetes", text: $name)
                                .focused($isNameFocused)
                                .textInputAutocapitalization(.sentences)
                                .autocorrectionDisabled()
                                .font(Theme.bodyBoldDynamic)
                                .onChange(of: name) { _, newValue in
                                    if autoAssignSymbol {
                                        let suggested = CategoryIconMapper.suggestSymbol(for: newValue)
                                        withAnimation(Theme.quickAnimation) {
                                            selectedSymbol = suggested
                                        }
                                    }
                                }
                            
                            if autoAssignSymbol && !name.isEmpty {
                                Text("Icono auto-asignado inteligentemente")
                                    .font(Theme.captionDynamic)
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("INFORMACIÓN DE CATEGORÍA")
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Color.appTextSecondary)
                }
                
                Section {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(CategoryIconMapper.popularSymbols, id: \.self) { symbol in
                            Button {
                                HapticFeedback.selection()
                                autoAssignSymbol = false
                                withAnimation(Theme.quickAnimation) {
                                    selectedSymbol = symbol
                                }
                            } label: {
                                Image(systemName: symbol)
                                    .font(.system(size: 16))
                                    .foregroundStyle(selectedSymbol == symbol ? .white : Color.appTextPrimary)
                                    .frame(width: iconSelectorSize, height: iconSelectorSize)
                                    .background(selectedSymbol == symbol ? Theme.accentYellow : Color.appCardBackground.opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(selectedSymbol == symbol ? Theme.accentYellow : Color.appSeparator, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    HStack {
                        Text("SELECCIONA UN ICONO")
                            .font(Theme.captionDynamic)
                            .foregroundStyle(Color.appTextSecondary)
                        Spacer()
                        if !autoAssignSymbol {
                            Button("Auto-asignar") {
                                autoAssignSymbol = true
                                let suggested = CategoryIconMapper.suggestSymbol(for: name)
                                withAnimation(Theme.quickAnimation) {
                                    selectedSymbol = suggested
                                }
                            }
                            .font(.caption.bold())
                            .foregroundStyle(Theme.accentYellow)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(isEditing ? "Editar categoría" : "Nueva categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Color.appTextSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveCategory()
                        HapticFeedback.success()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let category = originalCategory {
                    name = category.name
                    selectedSymbol = category.sfSymbol
                    autoAssignSymbol = false
                }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(300))
                isNameFocused = true
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func saveCategory() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if let category = originalCategory {
            // Actualizar categoría existente
            let oldName = category.name
            category.name = trimmedName
            category.sfSymbol = selectedSymbol
            
            // Si el nombre cambió, actualizamos categoryRawValue en cascada
            if oldName != trimmedName {
                if let items = category.items {
                    for item in items {
                        item.categoryRawValue = trimmedName
                    }
                }
                if let catalog = category.catalogItems {
                    for item in catalog {
                        item.categoryRawValue = trimmedName
                    }
                }
            }
        } else {
            // Crear nueva categoría
            let maxIndex = allCategories.map(\.sortIndex).max() ?? -1
            let newCategory = Category(
                name: trimmedName,
                sfSymbol: selectedSymbol,
                sortIndex: maxIndex + 1,
                isSystem: false
            )
            modelContext.insert(newCategory)
        }
        
        try? modelContext.save()
    }
}
