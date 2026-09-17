import SwiftUI
import SwiftData

/// Modal para importar listas masivas de texto (WhatsApp, Notas, Mensajes).
struct TextImporterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let activeList: ShoppingList?
    let allItems: [ShoppingItem]
    let categories: [Category]
    let viewModel: ShoppingListViewModel
    let onFinished: () -> Void

    @State private var rawText: String = ""
    @State private var parsedItems: [ParsedRow] = []
    @State private var isPreviewing: Bool = false
    @State private var errorMessage: String?

    struct ParsedRow: Identifiable {
        let id = UUID()
        var name: String
        var quantity: String
        var category: Category
        var store: Store
        var isSelected: Bool = true
        var isDuplicate: Bool = false
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !isPreviewing {
                    textInputView
                } else {
                    parsedPreviewView
                }
            }
            .background(Color.appBackground)
            // «Importar desde texto» no cabe entre «Cancelar» y «Procesar»: se truncaba.
            .navigationTitle(isPreviewing ? "Confirmar productos" : "Importar texto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Color.appTextSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isPreviewing {
                        Button("Agregar (\(selectedCount))") {
                            importSelectedItems()
                        }
                        .fontWeight(.semibold)
                        .disabled(selectedCount == 0)
                    } else {
                        Button("Procesar") {
                            parseText()
                        }
                        .fontWeight(.semibold)
                        .disabled(rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .alert(
            "No se pudieron importar los productos",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Inténtalo nuevamente.")
        }
    }

    private var textInputView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pega el texto de WhatsApp, Notas o un mensaje. Cada línea se convertirá en un producto.")
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            // TextEditor no admite placeholder: sin esto el área queda como un
            // rectángulo blanco enorme y vacío, sin indicar qué hacer con él.
            TextEditor(text: $rawText)
                .padding(12)
                .background(Color.appCardBackground)
                .overlay(alignment: .topLeading) {
                    if rawText.isEmpty {
                        Text("Leche\nPan marraqueta 1 kg\nHuevos x12")
                            .font(Theme.bodyDynamic)
                            .foregroundStyle(Color.appTextSecondary.opacity(0.6))
                            .padding(.horizontal, 17)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
                .padding(.horizontal, 16)
                .frame(maxHeight: .infinity)

            Button {
                if let clipboard = UIPasteboard.general.string {
                    rawText = clipboard
                    HapticFeedback.selection()
                }
            } label: {
                Label("Pegar del Portapapeles", systemImage: "doc.on.clipboard")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.accentYellow)
                    .foregroundStyle(Theme.onAccent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private var parsedPreviewView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(SpanishPluralization.count(parsedItems.count, singular: "producto", plural: "productos")) detectados")
                    .font(.caption.bold())
                    .foregroundStyle(Color.appTextSecondary)
                Spacer()
                Button("Volver a editar") {
                    withAnimation { isPreviewing = false }
                }
                .font(.caption.bold())
                .foregroundStyle(Theme.accentInteractive)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            List {
                ForEach($parsedItems) { $item in
                    HStack(spacing: 12) {
                        Toggle("", isOn: $item.isSelected)
                            .labelsHidden()
                            .tint(Theme.accentInteractive)
                            .disabled(item.isDuplicate)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color.appTextPrimary)

                            HStack(spacing: 6) {
                                if !item.quantity.isEmpty {
                                    Text(item.quantity)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.appSeparator)
                                        .clipShape(Capsule())
                                }

                                Label(item.category.name, systemImage: item.category.sfSymbol)
                                    .font(.caption)
                                    .foregroundStyle(Color.appTextSecondary)

                                if item.isDuplicate {
                                    Text("Ya existe en esta tienda")
                                        .font(.caption)
                                        .foregroundStyle(Color(light: UIColor(hex: "A34A00"), dark: UIColor(hex: "FFA04D")))
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
        }
    }

    private var selectedCount: Int {
        parsedItems.filter(\.isSelected).count
    }

    private func parseText() {
        let lines = rawText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var result: [ParsedRow] = []
        var knownKeys = Set(allItems.map { DuplicatePolicy.key(named: $0.name, store: $0.store) })

        for line in lines {
            // Eliminar viñetas comunes ("- ", "* ", "1. ", "• ")
            let cleanedLine = PastedListParser.stripBullet(line)
            let draft = viewModel.quickAddDraft(from: cleanedLine)
            guard !draft.name.isEmpty else { continue }

            let category = SuggestedProducts.suggestedCategory(for: draft.name, in: categories)
                ?? categories.first { $0.name == "Varios" }
                ?? Category.fallback
            let store = viewModel.selectedStore ?? SuggestedProducts.suggestedStore(for: draft.name)

            let key = DuplicatePolicy.key(named: draft.name, store: store)
            let isDuplicate = knownKeys.contains(key)
            result.append(ParsedRow(
                name: draft.name,
                quantity: draft.quantity,
                category: category,
                store: store,
                isSelected: !isDuplicate,
                isDuplicate: isDuplicate
            ))
            knownKeys.insert(key)
        }

        parsedItems = result
        withAnimation {
            isPreviewing = true
        }
        HapticFeedback.selection()
    }

    private func importSelectedItems() {
        let selected = parsedItems.filter { $0.isSelected && !$0.isDuplicate }
        var itemsWithNewEntries = allItems
        var insertedItems: [ShoppingItem] = []
        for item in selected {
            let newItem = ShoppingItem(
                name: item.name,
                listID: activeList?.id,
                quantity: item.quantity,
                category: item.category,
                sortOrder: viewModel.nextSortOrder(for: item.category, in: itemsWithNewEntries),
                store: item.store
            )
            modelContext.insert(newItem)
            itemsWithNewEntries.append(newItem)
            insertedItems.append(newItem)
            // A diferencia del añadido rápido y del sheet completo, este
            // camino no alimentaba el catálogo (CASI-024): lo importado por
            // texto nunca aparecía como sugerencia después.
            CatalogService.recordAddition(name: item.name, category: item.category, store: item.store, context: modelContext)
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
