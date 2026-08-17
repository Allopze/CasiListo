import SwiftUI
import SwiftData

/// Modal para crear o editar una lista de compras con icono, color y nombre personalizados.
struct AddEditListSheet: View {
    enum Mode: Identifiable {
        case add
        case edit(ShoppingList)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let list): return list.id.uuidString
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<ShoppingList> { $0.statusRawValue == activeShoppingListStatusRawValue })
    private var activeLists: [ShoppingList]

    let mode: Mode
    var onListCreated: ((ShoppingList) -> Void)? = nil

    @State private var name: String = ""
    @State private var selectedSymbol: String = ListAppearanceCatalog.defaultSymbol
    @State private var selectedColorHex: String = ListAppearanceCatalog.defaultColorHex
    @State private var autoAssignAppearance: Bool = true
    @State private var errorMessage: String?

    @FocusState private var isNameFocused: Bool

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var originalList: ShoppingList? {
        if case .edit(let list) = mode { return list }
        return nil
    }

    private var selectedColor: Color {
        Color(hex: selectedColorHex)
    }

    /// Choque con otra lista activa (ignorando la propia si se está editando).
    /// Se expone como texto para no dejar el botón «Guardar» apagado sin explicación.
    private var duplicateTitleMessage: String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalizedNew = ProductNameNormalizer.normalize(trimmed)
        let clash = activeLists.first { list in
            if let originalList, list.id == originalList.id { return false }
            return ProductNameNormalizer.normalize(list.title) == normalizedNew
        }

        guard let clash else { return nil }
        return "Ya tienes una lista activa llamada «\(clash.title)». Elige otro nombre."
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && duplicateTitleMessage == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                infoSection
                colorSection
                iconSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(isEditing ? "Editar lista" : "Nueva lista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Color.appTextSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        do {
                            try saveList()
                            HapticFeedback.success()
                            dismiss()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let list = originalList {
                    name = list.title
                    selectedSymbol = list.iconName
                    selectedColorHex = list.colorHex
                    autoAssignAppearance = false
                }
            }
            .task {
                if !isEditing {
                    try? await Task.sleep(for: .milliseconds(300))
                    isNameFocused = true
                }
            }
            .alert(
                "No se pudo guardar la lista",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Inténtalo nuevamente.")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Subvistas

    private var previewSection: some View {
        Section {
            HStack(spacing: 16) {
                ListBadgeView(
                    symbol: selectedSymbol,
                    color: selectedColor,
                    size: 60,
                    iconSize: 32,
                    cornerRadius: 16
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Nombre de la lista" : name)
                        .font(Theme.headlineDynamic)
                        .foregroundStyle(name.isEmpty ? Color.appTextSecondary : Color.appTextPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 8, height: 8)

                        Text(autoAssignAppearance && !name.isEmpty ? "Apariencia sugerida" : "Personalizada")
                            .font(Theme.captionDynamic)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
            }
            .padding(.vertical, 6)
        } header: {
            Text("VISTA PREVIA")
                .font(Theme.captionDynamic)
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    private var infoSection: some View {
        Section {
            TextField("Nombre (ej: Asado, Feria, Farmacia)", text: $name)
                .focused($isNameFocused)
                .textInputAutocapitalization(.sentences)
                .font(Theme.bodyBoldDynamic)
                .onChange(of: name) { _, newValue in
                    if autoAssignAppearance {
                        let (suggestedSymbol, suggestedColor) = ListAppearanceCatalog.suggestAppearance(for: newValue)
                        withAnimation(Theme.quickAnimation) {
                            selectedSymbol = suggestedSymbol
                            selectedColorHex = suggestedColor
                        }
                    }
                }
        } header: {
            Text("NOMBRE")
                .font(Theme.captionDynamic)
                .foregroundStyle(Color.appTextSecondary)
        } footer: {
            if let duplicateTitleMessage {
                Label(duplicateTitleMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(Theme.captionDynamic)
                    .foregroundStyle(.red)
            }
        }
    }

    private var colorSection: some View {
        Section {
            ListColorPickerView(selectedColorHex: $selectedColorHex) {
                autoAssignAppearance = false
            }
        } header: {
            Text("COLOR TEMÁTICO")
                .font(Theme.captionDynamic)
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    private var iconSection: some View {
        Section {
            ListIconPickerView(
                selectedSymbol: $selectedSymbol,
                tintColor: selectedColor,
                tintColorHex: selectedColorHex
            ) {
                autoAssignAppearance = false
            }
        } header: {
            HStack {
                Text("SELECCIONA UN ICONO")
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                Spacer()
                if !autoAssignAppearance {
                    Button("Auto-asignar") {
                        autoAssignAppearance = true
                        let (suggestedSymbol, suggestedColor) = ListAppearanceCatalog.suggestAppearance(for: name)
                        withAnimation(Theme.quickAnimation) {
                            selectedSymbol = suggestedSymbol
                            selectedColorHex = suggestedColor
                        }
                    }
                    .font(.caption.bold())
                    .foregroundStyle(Theme.accentYellow)
                }
            }
        }
    }

    // MARK: - Guardado

    private func saveList() throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if let list = originalList {
            list.title = trimmedName
            list.iconName = selectedSymbol
            list.colorHex = selectedColorHex
        } else {
            let newList = ShoppingList(
                title: trimmedName,
                status: .active,
                iconName: selectedSymbol,
                colorHex: selectedColorHex
            )
            modelContext.insert(newList)
            onListCreated?(newList)
        }

        try ShoppingPersistenceCoordinator(context: modelContext).commit()
    }
}
