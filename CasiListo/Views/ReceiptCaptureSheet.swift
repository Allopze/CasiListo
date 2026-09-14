import SwiftUI
import SwiftData
import PhotosUI
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
    var onShowHistory: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStore: Store
    @State private var detectedStore: Store?
    @State private var receiptImage: UIImage?
    @State private var scannedPageData: [Data] = []
    @State private var entries: [ReceiptPurchaseEntry] = []
    @State private var expandedEntryID: UUID?
    @State private var pickerSource: ReceiptImageSource?
    @State private var showsSourceDialog = false
    @State private var isRecognizing = false
    @State private var isSaving = false
    @State private var alert: ReceiptAlert?
    @State private var recognitionTask: Task<Void, Never>?
    @State private var savedSummary: ReceiptRegistrationSummary?
    @State private var printedTotal: Double?
    @State private var recognizedLineCount = 0
    @State private var hasStoreOverride = false

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

    /// Índice de precios anteriores. Antes era una `var` computada: cualquier
    /// cambio de cualquier `@State` del sheet —incluida cada pulsación al
    /// editar un precio— la reconstruía recorriendo todo el historial. El
    /// sheet es modal y estos datos no cambian durante su sesión, así que se
    /// arman una sola vez en `.task`.
    @State private var priceIndex = ReceiptPriceIndex(allItems: [], completedLists: [])

    /// Vocabulario propio de la persona para corregir lo que leyó el OCR.
    @State private var vocabulary: [String] = []

    /// Diferencia entre lo que suman las líneas revisadas y el TOTAL impreso.
    private var totalMismatch: Double? {
        guard let printedTotal, printedTotal > 0 else { return nil }
        let difference = entriesTotal - printedTotal
        // Un peso de diferencia es redondeo, no una línea perdida.
        return abs(difference) > 1 ? difference : nil
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
                alert?.title ?? "",
                isPresented: Binding(
                    get: { alert != nil },
                    set: { if !$0 { alert = nil } }
                ),
                presenting: alert
            ) { _ in
                Button("Entendido", role: .cancel) {}
            } message: { alert in
                Text(alert.message)
            }
            .sheet(item: $pickerSource) { source in
                switch source {
                case .documentCamera:
                    ReceiptDocumentCamera { pages in
                        applyScannedPages(pages)
                    }
                    .ignoresSafeArea()
                case .camera:
                    ReceiptImagePicker { image in
                        applyScannedPages([image])
                    }
                    .ignoresSafeArea()
                case .photoLibrary:
                    ReceiptPhotoLibraryPicker { image in
                        applyScannedPages([image])
                    }
                    .ignoresSafeArea()
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSaving)
        .task {
            priceIndex = ReceiptPriceIndex(allItems: allItems, completedLists: completedLists)
            var names = Set(allItems.map(\.name))
            names.formUnion(SuggestedProducts.byCategory.values.flatMap { $0 })
            vocabulary = Array(names)
        }
        .onDisappear { recognitionTask?.cancel() }
    }

    // MARK: - Captura

    private var capturePrompt: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundStyle(Theme.accentInteractive)
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
                    .buttonStyle(.accentProminent)
                    .controlSize(.large)

                    Button {
                        pickerSource = .photoLibrary
                    } label: {
                        Label("Elegir una foto", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.accentBordered)
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
                    totalCheckBanner
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

            VStack(alignment: .trailing, spacing: 8) {
                Button("Cambiar") {
                    showsSourceDialog = true
                }
                .font(Theme.captionDynamic.weight(.semibold))
                .accessibilityLabel("Cambiar foto de la boleta")

                if !isRecognizing && !scannedPageData.isEmpty {
                    Button("Reintentar lectura") {
                        retryRecognition()
                    }
                    .font(Theme.captionDynamic.weight(.semibold))
                    .accessibilityHint("Vuelve a leer los productos de esta misma foto")
                }
            }
        }
        .padding(12)
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
    }

    /// Cuadratura contra el TOTAL impreso: es la mejor señal disponible de que
    /// quedó alguna línea sin leer, y hasta ahora se descartaba.
    @ViewBuilder
    private var totalCheckBanner: some View {
        if let printedTotal, printedTotal > 0 {
            let mismatch = totalMismatch
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: mismatch == nil ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(mismatch == nil ? Theme.accentYellow : Color(light: UIColor(hex: "BA2115"), dark: UIColor(hex: "FF8078")))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mismatch == nil ? "La suma cuadra con la boleta" : "La suma no cuadra con la boleta")
                        .font(Theme.bodyBoldDynamic)
                    Text(mismatch == nil
                         ? "Total impreso \(printedTotal.formattedPriceWithSymbol)."
                         : "Van \(entriesTotal.formattedPriceWithSymbol) de \(printedTotal.formattedPriceWithSymbol): \(mismatchDescription(mismatch ?? 0)).")
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Color.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }

    private func mismatchDescription(_ difference: Double) -> String {
        difference < 0
            ? "faltan \(abs(difference).formattedPriceWithSymbol), revisa si quedó alguna línea sin leer"
            : "sobran \(difference.formattedPriceWithSymbol), revisa si alguna línea se leyó dos veces"
    }

    private var storePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Supermercado", systemImage: "storefront")
                .font(Theme.bodyBoldDynamic)

            Picker("Supermercado de esta boleta", selection: Binding(
                get: { selectedStore },
                set: { newValue in
                    hasStoreOverride = true
                    selectedStore = newValue
                }
            )) {
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
                // Distinguir «no se leyó nada» de «se leyó texto pero ninguna
                // línea parecía un producto» cambia por completo el consejo útil.
                ContentUnavailableView(
                    "Sin productos detectados",
                    systemImage: "text.badge.xmark",
                    description: Text(
                        recognizedLineCount == 0
                        ? "No pudimos leer texto en esta foto. Prueba con más luz, la boleta plana y sin sombras."
                        : "Leímos \(recognizedLineCount) líneas, pero ninguna tenía forma de producto con precio. Puedes añadirlos a mano."
                    ))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
            } else {
                let index = priceIndex
                let purchased = purchasedActiveItems
                let pending = activeItems.filter { $0.status != .purchased }
                VStack(spacing: 8) {
                    ForEach($entries) { $entry in
                        ReceiptEntryRow(
                            entry: $entry,
                            isExpanded: expandedEntryID == entry.id,
                            purchasedItems: purchased,
                            pendingItems: pending,
                            comparison: comparison(for: entry, using: index),
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
        .buttonStyle(.accentProminent)
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
                    .buttonStyle(.accentProminent)
                    .controlSize(.large)
                }

                Button {
                    dismiss()
                } label: {
                    Text("Listo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.accentBordered)
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
            alert = ReceiptAlert(
                title: "Cámara no disponible",
                message: "La cámara no está disponible en este dispositivo. Puedes elegir una foto de tu biblioteca."
            )
            return
        }
        pickerSource = .camera
    }

    private func applyScannedPages(_ pages: [UIImage]) {
        guard let combined = ReceiptImageComposer.stitchVertically(pages) else {
            alert = ReceiptAlert(
                title: "No se pudo usar esta foto",
                message: "Vuelve a escanear la boleta o elige otra imagen."
            )
            return
        }
        receiptImage = combined
        printedTotal = nil
        hasStoreOverride = false
        scannedPageData = []

        // Para poder releer la boleta hay que conservar las páginas, pero
        // guardarlas como bitmaps son decenas de megas por página: se retienen
        // comprimidas y se decodifican solo si hace falta reintentar.
        let boxed = pages.map(SendableImage.init)
        Task {
            scannedPageData = await Task.detached(priority: .utility) {
                boxed.compactMap { try? ReceiptImageStore.encode($0.image, quality: ReceiptImageStore.rereadQuality) }
            }.value
        }

        scanReceipt(pages: pages)
    }

    private func retryRecognition() {
        let pages = scannedPageData.compactMap { UIImage(data: $0) }
        guard !pages.isEmpty else { return }
        scanReceipt(pages: pages)
    }

    private func scanReceipt(pages: [UIImage]) {
        guard !pages.isEmpty else { return }

        // Cancelar de verdad: antes el resultado viejo se descartaba, pero el
        // reconocimiento seguía consumiendo CPU hasta terminar.
        recognitionTask?.cancel()
        isRecognizing = true
        entries = []
        expandedEntryID = nil
        detectedStore = nil
        printedTotal = nil
        recognizedLineCount = 0

        let userVocabulary = vocabulary
        let items = activeItems

        recognitionTask = Task {
            do {
                let recognition = try await ReceiptTextRecognitionService.recognizeReceipt(in: pages)
                try Task.checkCancellation()

                if let rawValue = recognition.detectedStoreRawValue,
                   let store = Store(rawValue: rawValue) {
                    detectedStore = store
                    // Una detección posterior no debe pisar lo que la persona eligió.
                    if !hasStoreOverride { selectedStore = store }
                }

                let assignments = ProductNameMatcher.assign(lines: recognition.products, to: items)
                entries = recognition.products.map { line in
                    var entry = ReceiptPurchaseEntry(recognized: line, associatedItemID: assignments[line.id])
                    entry.name = ReceiptNameCorrector.correct(line.name, vocabulary: userVocabulary)
                    return entry
                }
                printedTotal = recognition.printedTotal
                recognizedLineCount = recognition.recognizedLineCount
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                alert = ReceiptAlert(
                    title: "No se pudo leer la boleta",
                    message: error.localizedDescription
                )
            }
            if !Task.isCancelled { isRecognizing = false }
        }
    }

    private func storeDetectionMessage(for store: Store) -> String {
        if selectedStore == store {
            return "Detectamos \(store.displayName) en la boleta."
        }
        return "Detectamos \(store.displayName); puedes mantener tu selección si necesitas corregirlo."
    }

    private func comparison(for entry: ReceiptPurchaseEntry, using index: ReceiptPriceIndex) -> ReceiptPriceComparison? {
        let comparisonName = activeItems.first(where: { $0.id == entry.associatedItemID })?.name ?? entry.name
        return index.comparison(productName: comparisonName, newPrice: entry.price, store: selectedStore)
    }

    private func savePurchase() {
        guard let receiptImage, canSave else { return }
        isSaving = true

        let image = SendableImage(receiptImage)
        Task {
            do {
                // Codificar una boleta larga puede tardar cientos de
                // milisegundos: hacerlo en el hilo principal congelaba la vista
                // justo cuando debía aparecer el indicador de guardado.
                let data = try await Task.detached(priority: .userInitiated) {
                    try ReceiptImageStore.encode(image.image)
                }.value
                let filename = try ReceiptImageStore.save(data)

                let summary = try ShoppingPersistenceCoordinator(context: modelContext).registerReceipt(
                    entries: entries,
                    receiptFilename: filename,
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
                alert = ReceiptAlert(
                    title: "No se pudo registrar la boleta",
                    message: error.localizedDescription
                )
                isSaving = false
            }
        }
    }
}

private struct ReceiptAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
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

    /// Vision entrega su confianza por fragmento y hasta ahora se descartaba.
    /// Marcar las líneas dudosas dirige la revisión a donde hace falta.
    private var isUncertain: Bool { entry.confidence < 0.5 }

    private var displayName: String {
        entry.name.isEmpty ? "Producto sin nombre" : entry.name
    }

    /// Cuando el total impreso no se reparte en unidades exactas (3 por $2.750),
    /// mostrar «3 × $917» miente sobre el papel; se muestra el recuento a secas.
    private var quantityCaption: String? {
        switch QuantitySemantics.breakdown(unitPrice: entry.price, lineTotal: entry.lineTotal, count: entry.quantity) {
        case .single: return nil
        case .inexactMultiple(let count): return "\(count) unidades"
        case .exactMultiple(let count, let unitPrice): return "\(count) × \(unitPrice.formattedPriceWithSymbol)"
        }
    }

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
                    Text(displayName)
                        .font(Theme.bodyDynamic)
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(isAssociated ? "En tu lista" : "Se añadirá como nuevo")
                        if isUncertain {
                            Label("Revisar", systemImage: "questionmark.circle")
                                .labelStyle(.titleAndIcon)
                        }
                        if entry.hasDiscount {
                            Label("Con descuento", systemImage: "tag")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.lineTotal.formattedPriceWithSymbol)
                        .font(Theme.bodyBoldDynamic)
                        .foregroundStyle(Color.appTextPrimary)
                        .monospacedDigit()

                    if let quantityCaption {
                        Text(quantityCaption)
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
        .accessibilityLabel(
            "\(displayName), \(entry.lineTotal.formattedPriceWithSymbol)"
            + (entry.quantity > 1 ? ", \(entry.quantity) unidades" : "")
            + (isAssociated ? ", asociado a tu lista" : ", se añadirá como nuevo")
            + (isUncertain ? ", lectura poco clara, conviene revisarla" : "")
        )
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
                    // El peso chileno no tiene decimales: admitirlos solo genera
                    // totales que no cuadran con la boleta.
                    TextField("Precio", value: $entry.price, format: .number.precision(.fractionLength(0)))
                        .keyboardType(.numberPad)
                        .frame(minHeight: Theme.minimumTouchTarget)
                        .accessibilityLabel("Precio unitario")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Cantidad")
                        .font(Theme.captionDynamic.weight(.semibold))
                        .foregroundStyle(Color.appTextSecondary)
                    HStack(spacing: 8) {
                        // Escribible además del stepper: llegar a 12 a punta de
                        // toques son once pulsaciones.
                        TextField("1", value: $entry.quantity, format: .number)
                            .keyboardType(.numberPad)
                            .frame(width: 46, height: Theme.minimumTouchTarget)
                            .multilineTextAlignment(.center)
                            .accessibilityLabel("Cantidad")
                        Stepper("", value: $entry.quantity, in: 1...99)
                            .labelsHidden()
                            .accessibilityLabel("Cantidad: \(entry.quantity)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if entry.hasDiscount {
                Label("La boleta traía un descuento en esta línea; el total ya lo incluye.", systemImage: "tag")
                    .font(Theme.captionDynamic)
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
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
}

/// Selector de la fototeca sin permiso.
///
/// `UIImagePickerController` con `.photoLibrary` dispara el diálogo de acceso a
/// **toda** la fototeca; `PHPickerViewController` corre fuera del proceso y
/// entrega solo la foto elegida, sin pedir nada. Era el único punto de la app
/// que no aplicaba mínimo privilegio.
private struct ReceiptPhotoLibraryPicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: ReceiptPhotoLibraryPicker

        init(parent: ReceiptPhotoLibraryPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self)
            else { return }

            provider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else { return }
                Task { @MainActor in self.parent.onImagePicked(image) }
            }
        }
    }
}

/// Cámara clásica para los dispositivos donde VisionKit no está disponible.
private struct ReceiptImagePicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
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
