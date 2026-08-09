import SwiftUI
import SwiftData
import UIKit

/// Flujo de captura, revisión y guardado de una boleta de compra.
/// La persona siempre confirma los productos y valores antes de persistirlos.
struct ReceiptCaptureSheet: View {
    let activeList: ShoppingList?
    let activeItems: [ShoppingItem]
    let allItems: [ShoppingItem]
    let completedLists: [ShoppingList]
    let categories: [Category]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStore: Store
    @State private var detectedStore: Store?
    @State private var receiptImage: UIImage?
    @State private var entries: [ReceiptPurchaseEntry] = []
    @State private var pickerSource: ReceiptImageSource?
    @State private var showsSourceDialog = false
    @State private var isRecognizing = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        activeList: ShoppingList?,
        activeItems: [ShoppingItem],
        allItems: [ShoppingItem],
        completedLists: [ShoppingList],
        categories: [Category]
    ) {
        self.activeList = activeList
        self.activeItems = activeItems
        self.allItems = allItems
        self.completedLists = completedLists
        self.categories = categories
        _selectedStore = State(initialValue: activeItems.first?.store ?? .jumbo)
    }

    private var validEntryCount: Int {
        entries.filter {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.price > 0
        }.count
    }

    private var canSave: Bool {
        receiptImage != nil && validEntryCount > 0 && !isRecognizing && !isSaving
    }

    var body: some View {
        NavigationStack {
            Group {
                if let receiptImage {
                    reviewContent(for: receiptImage)
                } else {
                    capturePrompt
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Registrar boleta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .disabled(isSaving)
                }
            }
            .confirmationDialog(
                "Añadir foto de la boleta",
                isPresented: $showsSourceDialog,
                titleVisibility: .visible
            ) {
                Button("Tomar foto", systemImage: "camera") {
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
                ReceiptImagePicker(sourceType: source.uiKitSource) { image in
                    receiptImage = image
                    scanReceipt(image)
                }
                .ignoresSafeArea()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

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
                    Text("Guarda una compra desde su boleta")
                        .font(Theme.sectionHeaderDynamic)
                        .multilineTextAlignment(.center)

                    Text("CasiListo detecta los productos y sus precios. Tú los revisas y los comparas con tu última compra antes de guardar.")
                        .font(Theme.bodyDynamic)
                        .foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    Button {
                        presentCamera()
                    } label: {
                        Label("Tomar foto de la boleta", systemImage: "camera.fill")
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

    private func reviewContent(for image: UIImage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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
                         : "Confirma el texto y asocia cada línea a tu lista cuando corresponda.")
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                Button {
                    entries.append(ReceiptPurchaseEntry(name: "", price: 0))
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
                ForEach(entries.indices, id: \.self) { index in
                    let entryID = entries[index].id
                    ReceiptProductEditor(
                        entry: $entries[index],
                        availableItems: activeItems,
                        comparison: comparison(for: entries[index])
                    ) {
                        entries.removeAll { $0.id == entryID }
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
                    ProgressView().tint(.black)
                }
                Text(isSaving ? "Guardando…" : "Guardar compra y comparar")
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

    private func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = "La cámara no está disponible en este dispositivo. Puedes elegir una foto de tu biblioteca."
            return
        }
        pickerSource = .camera
    }

    private func scanReceipt(_ image: UIImage) {
        isRecognizing = true
        entries = []
        detectedStore = nil

        Task {
            do {
                let recognition = try await ReceiptTextRecognitionService.recognizeReceipt(in: image)
                guard receiptImage === image else { return }
                if let rawValue = recognition.detectedStoreRawValue,
                   let store = Store(rawValue: rawValue) {
                    selectedStore = store
                    detectedStore = store
                }
                entries = recognition.products.map { line in
                    ReceiptPurchaseEntry(
                        name: line.name,
                        price: line.price,
                        associatedItemID: ProductNameMatcher.bestMatch(for: line.name, in: activeItems)?.id
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isRecognizing = false
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
            try ReceiptPurchaseService.register(
                entries: entries,
                receiptImage: receiptImage,
                store: selectedStore,
                activeList: activeList,
                allItems: allItems,
                categories: categories,
                context: modelContext
            )
            HapticFeedback.success()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}

private struct ReceiptProductEditor: View {
    @Binding var entry: ReceiptPurchaseEntry
    let availableItems: [ShoppingItem]
    let comparison: ReceiptPriceComparison?
    let onDelete: () -> Void

    private var comparisonColor: Color {
        guard let comparison else { return Color.appTextSecondary }
        if comparison.difference > 0 { return .red }
        if comparison.difference < 0 { return .green }
        return Color.appTextSecondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Producto")
                    .font(Theme.captionDynamic.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .frame(width: Theme.minimumTouchTarget, height: Theme.minimumTouchTarget)
                }
                .accessibilityLabel("Quitar producto de la boleta")
            }

            TextField("Nombre del producto", text: $entry.name)
                .textInputAutocapitalization(.words)
                .submitLabel(.next)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Precio pagado")
                        .font(Theme.captionDynamic.weight(.semibold))
                        .foregroundStyle(Color.appTextSecondary)
                    TextField("Precio", value: $entry.price, format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                        .frame(minHeight: Theme.minimumTouchTarget)
                        .accessibilityLabel("Precio pagado")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let comparison {
                    priceChangeView(comparison)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Asociar con")
                    .font(Theme.captionDynamic.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)

                Picker("Asociar con un producto de la lista", selection: $entry.associatedItemID) {
                    Text("Añadir como producto nuevo").tag(UUID?.none)
                    ForEach(availableItems) { item in
                        Text(item.name).tag(Optional(item.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHint("Si no lo asocias, se agregará como producto nuevo en esta compra")
            }
        }
        .padding(16)
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
    }

    private func priceChangeView(_ comparison: ReceiptPriceComparison) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Última compra")
                .font(Theme.captionDynamic.weight(.semibold))
                .foregroundStyle(Color.appTextSecondary)
            Text(comparison.previousPrice.formattedPriceWithSymbol)
                .font(Theme.bodyBoldDynamic)
            Text(changeLabel(for: comparison))
                .font(Theme.captionDynamic.weight(.semibold))
                .foregroundStyle(comparisonColor)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
    }

    private func changeLabel(for comparison: ReceiptPriceComparison) -> String {
        if comparison.difference == 0 {
            return "Sin variación"
        }
        let direction = comparison.difference > 0 ? "Subió" : "Bajó"
        let amount = abs(comparison.difference).formattedPriceWithSymbol
        return "\(direction) \(amount) (\(abs(comparison.percentage).formatted(.number.precision(.fractionLength(0))))%)"
    }
}

private enum ReceiptImageSource: String, Identifiable {
    case camera
    case photoLibrary

    var id: String { rawValue }

    var uiKitSource: UIImagePickerController.SourceType {
        switch self {
        case .camera: .camera
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
