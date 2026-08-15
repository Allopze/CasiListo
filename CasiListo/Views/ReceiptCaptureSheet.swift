import SwiftUI
import SwiftData
import UIKit

/// Flujo de captura, revisión y guardado de una boleta de compra.
/// La persona siempre confirma los productos y valores antes de persistirlos.
/// En modo cierre (`closesPurchase`), la boleta además archiva los productos
/// marcados como comprados, unificando "archivar" y "registrar boleta".
struct ReceiptCaptureSheet: View {
    let activeList: ShoppingList?
    let activeItems: [ShoppingItem]
    let allItems: [ShoppingItem]
    let completedLists: [ShoppingList]
    let categories: [Category]
    var closesPurchase: Bool = false
    var onShowHistory: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStore: Store
    @State private var detectedStore: Store?
    @State private var receiptImage: UIImage?
    @State private var entries: [ReceiptPurchaseEntry] = []
    @State private var expandedEntryID: UUID?
    @State private var pickerSource: ReceiptImageSource?
    @State private var showsSourceDialog = false
    @State private var isRecognizing = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var scanToken = UUID()
    @State private var savedSummary: ReceiptRegistrationSummary?

    init(
        activeList: ShoppingList?,
        activeItems: [ShoppingItem],
        allItems: [ShoppingItem],
        completedLists: [ShoppingList],
        categories: [Category],
        closesPurchase: Bool = false,
        onShowHistory: (() -> Void)? = nil
    ) {
        self.activeList = activeList
        self.activeItems = activeItems
        self.allItems = allItems
        self.completedLists = completedLists
        self.categories = categories
        self.closesPurchase = closesPurchase
        self.onShowHistory = onShowHistory

        // En modo cierre, la tienda por defecto es la mayoritaria entre los comprados.
        let purchased = activeItems.filter { $0.status == .purchased }
        let reference = closesPurchase && !purchased.isEmpty ? purchased : activeItems
        let majorityStore = Dictionary(grouping: reference, by: \.store)
            .max { $0.value.count < $1.value.count }?.key
        _selectedStore = State(initialValue: majorityStore ?? .jumbo)
    }

    private var purchasedActiveItems: [ShoppingItem] {
        activeItems.filter { $0.status == .purchased }
    }

    /// Comprados que no tienen línea asociada en la boleta: en modo cierre
    /// se archivarán junto con ella.
    private var unmatchedPurchasedCount: Int {
        let associatedIDs = Set(entries.compactMap(\.associatedItemID))
        return purchasedActiveItems.filter { !associatedIDs.contains($0.id) }.count
    }

    private var validEntryCount: Int {
        entries.filter {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.price > 0
        }.count
    }

    private var entriesTotal: Double {
        entries
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.price > 0 }
            .map(\.lineTotal)
            .reduce(0, +)
    }

    private var canSave: Bool {
        receiptImage != nil && validEntryCount > 0 && !isRecognizing && !isSaving
    }

    var body: some View {
        NavigationStack {
            Group {
                if let savedSummary {
                    successContent(savedSummary)
                } else if let receiptImage {
                    reviewContent(for: receiptImage)
                } else {
                    capturePrompt
                }
            }
            .background(Color.appBackground)
            .navigationTitle(closesPurchase ? "Cerrar compra" : "Registrar boleta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if savedSummary == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { dismiss() }
                            .disabled(isSaving)
                    }
                }
            }
            .confirmationDialog(
                "Añadir foto de la boleta",
                isPresented: $showsSourceDialog,
                titleVisibility: .visible
            ) {
                Button("Escanear boleta", systemImage: "doc.viewfinder") {
                    presentCamera()
                }
                Button("Elegir de Fotos", systemImage: "photo.on.rectangle") {
                    pickerSource = .photoLibrary
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Procura que se lean claramente los nombres y precios.")
            }
            .alert(
                "No se pudo registrar la boleta",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Intenta nuevamente con una foto más nítida.")
            }
            .sheet(item: $pickerSource) { source in
                switch source {
                case .documentCamera:
                    ReceiptDocumentCamera { pages in
                        applyScannedPages(pages)
                    }
                    .ignoresSafeArea()
                case .camera, .photoLibrary:
                    ReceiptImagePicker(sourceType: source.uiKitSource) { image in
                        applyScannedPages([image])
                    }
                    .ignoresSafeArea()
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSaving)
    }

    // MARK: - Captura

    private var capturePrompt: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundStyle(Theme.accentYellow)
                    .frame(width: 104, height: 104)
                    .background(Theme.accentYellow.opacity(0.14), in: Circle())
                    .padding(.top, 44)

                VStack(spacing: 10) {
                    Text(closesPurchase
                         ? "Cierra tu compra con la boleta"
                         : "Guarda una compra desde su boleta")
                        .font(Theme.sectionHeaderDynamic)
                        .multilineTextAlignment(.center)

                    Text(closesPurchase
                         ? "CasiListo detecta los productos y precios de la boleta, los cruza con lo que marcaste y archiva todo junto en el historial."
                         : "CasiListo detecta los productos y sus precios. Tú los revisas y los comparas con tu última compra antes de guardar.")
                        .font(Theme.bodyDynamic)
                        .foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    Button {
                        presentCamera()
                    } label: {
                        Label("Escanear boleta", systemImage: "doc.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accentYellow)
                    .controlSize(.large)

                    Button {
                        pickerSource = .photoLibrary
                    } label: {
                        Label("Elegir una foto", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal, 24)

                if closesPurchase && !purchasedActiveItems.isEmpty {
                    Label(
                        purchasedActiveItems.count == 1
                            ? "Tienes 1 producto marcado listo para archivar."
                            : "Tienes \(purchasedActiveItems.count) productos marcados listos para archivar.",
                        systemImage: "checkmark.circle"
                    )
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .padding(.horizontal, 36)
                }

                Label("La foto y el reconocimiento se procesan y guardan solo en este dispositivo.", systemImage: "lock.fill")
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Revisión

    private func reviewContent(for image: UIImage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                receiptPreview(image)
                storePicker

                if isRecognizing {
                    HStack(spacing: 12) {
                        ProgressView()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Leyendo la boleta")
                                .font(Theme.bodyBoldDynamic)
                            Text("Esto puede tardar unos segundos.")
                                .font(Theme.captionDynamic)
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
                } else {
                    productReviewSection

                    if closesPurchase && unmatchedPurchasedCount > 0 {
                        Label(
                            "Se archivarán además \(unmatchedPurchasedCount) productos marcados que no aparecen en la boleta.",
                            systemImage: "archivebox"
                        )
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Color.appTextSecondary)
                        .padding(.horizontal, 4)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 96)
        }
        .safeAreaInset(edge: .bottom) {
            if !isRecognizing {
                saveButton
            }
        }
    }

    private func receiptPreview(_ image: UIImage) -> some View {
        HStack(spacing: 14) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 70, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text("Foto de la boleta")
                    .font(Theme.bodyBoldDynamic)
                Text(isRecognizing ? "Buscando productos y precios…" : "Revisa cada producto antes de guardar la compra.")
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button("Cambiar") {
                showsSourceDialog = true
            }
            .font(Theme.captionDynamic.weight(.semibold))
            .accessibilityLabel("Cambiar foto de la boleta")
        }
        .padding(12)
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
    }

    private var storePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Supermercado", systemImage: "storefront")
                .font(Theme.bodyBoldDynamic)

            Picker("Supermercado de esta boleta", selection: $selectedStore) {
                ForEach(Store.allCases) { store in
                    Text(store.displayName).tag(store)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Supermercado de esta boleta")

            if let detectedStore {
                Label(storeDetectionMessage(for: detectedStore), systemImage: "checkmark.seal.fill")
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .accessibilityElement(children: .combine)
            } else if receiptImage != nil && !isRecognizing {
                Text("No pudimos identificar el supermercado; puedes elegirlo aquí.")
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .padding(16)
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
    }

    private var productReviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Productos y precios")
                        .font(Theme.sectionHeaderDynamic)
                    Text(entries.isEmpty
                         ? "No se detectaron líneas automáticamente. Añade los productos de la boleta."
                         : "\(validEntryCount) productos · \(entriesTotal.formattedPriceWithSymbol) · toca una línea para corregirla")
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                Button {
                    let newEntry = ReceiptPurchaseEntry(name: "", price: 0)
                    entries.append(newEntry)
                    expandedEntryID = newEntry.id
                } label: {
                    Image(systemName: "plus")
                        .frame(width: Theme.minimumTouchTarget, height: Theme.minimumTouchTarget)
                }
                .accessibilityLabel("Añadir producto de la boleta")
            }

            if entries.isEmpty {
                ContentUnavailableView(
                    "Sin productos detectados",
                    systemImage: "text.badge.xmark",
                    description: Text("Puedes añadirlos manualmente o probar con una foto mejor iluminada."))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    ForEach($entries) { $entry in
                        ReceiptEntryRow(
                            entry: $entry,
                            isExpanded: expandedEntryID == entry.id,
                            purchasedItems: purchasedActiveItems,
                            pendingItems: activeItems.filter { $0.status != .purchased },
                            comparison: comparison(for: entry),
                            onToggleExpanded: {
                                withAnimation(Theme.quickAnimation) {
                                    expandedEntryID = expandedEntryID == entry.id ? nil : entry.id
                                }
                            },
                            onDelete: {
                                let entryID = entry.id
                                withAnimation(Theme.quickAnimation) {
                                    entries.removeAll { $0.id == entryID }
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            savePurchase()
        } label: {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView().tint(Theme.onAccent)
                }
                Text(isSaving ? "Guardando…" : (closesPurchase ? "Guardar y archivar compra" : "Guardar compra"))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.minimumTouchTarget)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.accentYellow)
        .disabled(!canSave)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .accessibilityHint("Guarda la boleta, sus productos y los precios en el historial")
    }

    // MARK: - Confirmación

    private func successContent(_ summary: ReceiptRegistrationSummary) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Theme.onAccent, Theme.accentYellow)

            VStack(spacing: 8) {
                Text("Compra guardada")
                    .font(Theme.sectionHeaderDynamic)

                Text(summarySubtitle(summary))
                    .font(Theme.bodyDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                if let onShowHistory {
                    Button {
                        onShowHistory()
                    } label: {
                        Label("Ver en historial", systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accentYellow)
                    .controlSize(.large)
                }

                Button {
                    dismiss()
                } label: {
                    Text("Listo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
    }

    private func summarySubtitle(_ summary: ReceiptRegistrationSummary) -> String {
        let receiptLabel = summary.receiptProductCount == 1 ? "1 producto de la boleta" : "\(summary.receiptProductCount) productos de la boleta"
        var parts = ["\(receiptLabel) · \(summary.totalSpent.formattedPriceWithSymbol)"]
        if summary.mergedPurchasedCount > 0 {
            parts.append(summary.mergedPurchasedCount == 1
                ? "Se archivó además 1 producto que marcaste."
                : "Se archivaron además \(summary.mergedPurchasedCount) productos que marcaste.")
        }
        if summary.otherStoreArchivedCount > 0 {
            parts.append(summary.otherStoreArchivedCount == 1
                ? "1 de otra tienda quedó en su propia compra."
                : "\(summary.otherStoreArchivedCount) de otra tienda quedaron en su propia compra.")
        }
        return parts.joined(separator: "\n")
    }

    // MARK: - Acciones

    private func presentCamera() {
        if ReceiptDocumentCamera.isSupported {
            pickerSource = .documentCamera
            return
        }
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = "La cámara no está disponible en este dispositivo. Puedes elegir una foto de tu biblioteca."
            return
        }
        pickerSource = .camera
    }

    private func applyScannedPages(_ pages: [UIImage]) {
        guard let combined = ReceiptImageComposer.stitchVertically(pages) else { return }
        receiptImage = combined
        scanReceipt(pages: pages)
    }

    private func scanReceipt(pages: [UIImage]) {
        isRecognizing = true
        entries = []
        expandedEntryID = nil
        detectedStore = nil
        let token = UUID()
        scanToken = token

        Task {
            do {
                let recognition = try await ReceiptTextRecognitionService.recognizeReceipt(in: pages)
                guard scanToken == token else { return }
                if let rawValue = recognition.detectedStoreRawValue,
                   let store = Store(rawValue: rawValue) {
                    selectedStore = store
                    detectedStore = store
                }
                entries = recognition.products.map { line in
                    ReceiptPurchaseEntry(
                        name: line.name,
                        price: line.price,
                        quantity: line.quantity,
                        associatedItemID: ProductNameMatcher.bestMatch(for: line.name, in: activeItems)?.id
                    )
                }
            } catch {
                guard scanToken == token else { return }
                errorMessage = error.localizedDescription
            }
            if scanToken == token {
                isRecognizing = false
            }
        }
    }

    private func storeDetectionMessage(for store: Store) -> String {
        if selectedStore == store {
            return "Detectamos \(store.displayName) en la boleta."
        }
        return "Detectamos \(store.displayName); puedes mantener tu selección si necesitas corregirlo."
    }

    private func comparison(for entry: ReceiptPurchaseEntry) -> ReceiptPriceComparison? {
        let comparisonName = activeItems.first(where: { $0.id == entry.associatedItemID })?.name ?? entry.name
        return ReceiptPriceHistory.latestComparison(
            productName: comparisonName,
            newPrice: entry.price,
            store: selectedStore,
            allItems: allItems,
            completedLists: completedLists
        )
    }

    private func savePurchase() {
        guard let receiptImage, canSave else { return }
        isSaving = true

        do {
            let summary = try ShoppingPersistenceCoordinator(context: modelContext).registerReceipt(
                entries: entries,
                receiptImage: receiptImage,
                store: selectedStore,
                activeList: activeList,
                allItems: allItems,
                categories: categories,
                archivingPurchased: closesPurchase
            )
            HapticFeedback.success()
            isSaving = false
            withAnimation(Theme.defaultAnimation) {
                savedSummary = summary
            }
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}

// MARK: - Fila de producto detectado

/// Fila compacta y expandible para revisar una línea de la boleta.
/// Colapsada muestra lo esencial; expandida permite corregir todo.
private struct ReceiptEntryRow: View {
    @Binding var entry: ReceiptPurchaseEntry
    let isExpanded: Bool
    let purchasedItems: [ShoppingItem]
    let pendingItems: [ShoppingItem]
    let comparison: ReceiptPriceComparison?
    let onToggleExpanded: () -> Void
    let onDelete: () -> Void

    private var isAssociated: Bool { entry.associatedItemID != nil }

    private var comparisonColor: Color {
        guard let comparison else { return Color.appTextSecondary }
        if comparison.difference > 0 { return Color(light: UIColor(hex: "BA2115"), dark: UIColor(hex: "FF8078")) }
        if comparison.difference < 0 { return Color(light: UIColor(hex: "1B6E33"), dark: UIColor(hex: "6FD08C")) }
        return Color.appTextSecondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            collapsedRow

            if isExpanded {
                expandedEditor
                    .transition(.opacity)
            }
        }
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
    }

    private var collapsedRow: some View {
        Button(action: onToggleExpanded) {
            HStack(spacing: 12) {
                Image(systemName: isAssociated ? "link.circle.fill" : "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isAssociated ? Theme.accentYellow : Color.appTextSecondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name.isEmpty ? "Producto sin nombre" : entry.name)
                        .font(Theme.bodyDynamic)
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(1)

                    Text(isAssociated ? "En tu lista" : "Se añadirá como nuevo")
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Color.appTextSecondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.lineTotal.formattedPriceWithSymbol)
                        .font(Theme.bodyBoldDynamic)
                        .foregroundStyle(Color.appTextPrimary)
                        .monospacedDigit()

                    if entry.quantity > 1 {
                        Text("\(entry.quantity) × \(entry.price.formattedPriceWithSymbol)")
                            .font(Theme.captionDynamic)
                            .foregroundStyle(Color.appTextSecondary)
                            .monospacedDigit()
                    }
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appTextSecondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.name), \(entry.lineTotal.formattedPriceWithSymbol)\(isAssociated ? ", asociado a tu lista" : ", se añadirá como nuevo")")
        .accessibilityHint(isExpanded ? "Toca para contraer" : "Toca para editar esta línea")
    }

    private var expandedEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider()

            TextField("Nombre del producto", text: $entry.name)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Precio unitario")
                        .font(Theme.captionDynamic.weight(.semibold))
                        .foregroundStyle(Color.appTextSecondary)
                    TextField("Precio", value: $entry.price, format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                        .frame(minHeight: Theme.minimumTouchTarget)
                        .accessibilityLabel("Precio unitario")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Cantidad")
                        .font(Theme.captionDynamic.weight(.semibold))
                        .foregroundStyle(Color.appTextSecondary)
                    Stepper("\(entry.quantity)", value: $entry.quantity, in: 1...99)
                        .accessibilityLabel("Cantidad: \(entry.quantity)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let comparison {
                HStack(spacing: 8) {
                    Image(systemName: comparison.difference > 0 ? "arrow.up.circle" : (comparison.difference < 0 ? "arrow.down.circle" : "equal.circle"))
                    Text(changeLabel(for: comparison))
                }
                .font(Theme.captionDynamic.weight(.semibold))
                .foregroundStyle(comparisonColor)
                .accessibilityElement(children: .combine)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Asociar con")
                    .font(Theme.captionDynamic.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)

                Picker("Asociar con un producto de la lista", selection: $entry.associatedItemID) {
                    Text("Añadir como producto nuevo").tag(UUID?.none)
                    if !purchasedItems.isEmpty {
                        Section("Marcados en esta compra") {
                            ForEach(purchasedItems) { item in
                                Text(item.name).tag(Optional(item.id))
                            }
                        }
                    }
                    if !pendingItems.isEmpty {
                        Section("Resto de la lista") {
                            ForEach(pendingItems) { item in
                                Text(item.name).tag(Optional(item.id))
                            }
                        }
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHint("Si no lo asocias, se agregará como producto nuevo en esta compra")
            }

            Button(role: .destructive, action: onDelete) {
                Label("Quitar esta línea", systemImage: "trash")
                    .font(Theme.captionDynamic.weight(.semibold))
            }
            .accessibilityLabel("Quitar producto de la boleta")
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }

    private func changeLabel(for comparison: ReceiptPriceComparison) -> String {
        if comparison.difference == 0 {
            return "Mismo precio que tu última compra"
        }
        let direction = comparison.difference > 0 ? "Subió" : "Bajó"
        let amount = abs(comparison.difference).formattedPriceWithSymbol
        return "\(direction) \(amount) (\(abs(comparison.percentage).formatted(.number.precision(.fractionLength(0))))%) desde tu última compra"
    }
}

// MARK: - Fuentes de imagen

private enum ReceiptImageSource: String, Identifiable {
    case documentCamera
    case camera
    case photoLibrary

    var id: String { rawValue }

    var uiKitSource: UIImagePickerController.SourceType {
        switch self {
        case .camera, .documentCamera: .camera
        case .photoLibrary: .photoLibrary
        }
    }
}

private struct ReceiptImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: ReceiptImagePicker

        init(parent: ReceiptImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                parent.dismiss()
                return
            }
            parent.dismiss()
            parent.onImagePicked(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
