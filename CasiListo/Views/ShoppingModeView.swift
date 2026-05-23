import SwiftUI
import SwiftData

/// Pantalla en pantalla completa para enfocar la experiencia de compra en el supermercado.
struct ShoppingModeView: View {
    let allItems: [ShoppingItem]
    let onFinished: () -> Void // Callback al finalizar o salir
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Estado de la sesión de compra
    @State private var sessionViewModel: ShoppingModeViewModel? = nil
    @State private var preselectedStore: Store = .jumbo
    
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0
    
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            if let viewModel = sessionViewModel {
                if viewModel.isCompleted {
                    // Pantalla de celebración
                    CompletionCelebrationView(
                        storeName: viewModel.store.displayName,
                        productsCount: viewModel.totalCount,
                        duration: viewModel.formattedTime,
                        totalSpent: viewModel.items.compactMap(\.price).reduce(0, +),
                        onDismiss: {
                            // Al terminar la compra, podemos guardar estadísticas (Feature 6)
                            // de forma segura antes de cerrar
                            recordCompletedPurchase(viewModel: viewModel)
                            onFinished()
                            dismiss()
                        }
                    )
                    .transition(.opacity)
                } else {
                    // Interfaz activa de compra
                    shoppingContent(viewModel: viewModel)
                        .transition(.slide)
                }
            } else {
                // Selector de supermercado inicial
                initialStoreSelector
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: sessionViewModel == nil)
    }
    
    // MARK: - Selector Inicial de Tienda
    
    private var initialStoreSelector: some View {
        VStack(spacing: 24 * CGFloat(accessibilityTextSizeScale)) {
            HStack {
                Spacer()
                Button {
                    HapticFeedback.selection()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.appTextSecondary)
                        .padding(10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            Spacer()
            
            Text("🛒 Modo Compra")
                .font(.system(size: 34 * CGFloat(accessibilityTextSizeScale), weight: .black))
                .foregroundStyle(.white)
            
            Text("Selecciona en qué supermercado estás comprando hoy para enfocar tu lista:")
                .font(Theme.bodyFont(scale: accessibilityTextSizeScale))
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            // Selector visual grande
            HStack(spacing: 16) {
                ForEach(Store.allCases) { store in
                    storeSelectorButton(store: store)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            
            Spacer()
            
            Button {
                HapticFeedback.success()
                withAnimation(.spring()) {
                    let vm = ShoppingModeViewModel(store: preselectedStore, allItems: allItems)
                    vm.startSession()
                    self.sessionViewModel = vm
                }
            } label: {
                Text("Comenzar Compra")
                    .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16 * CGFloat(accessibilityTextSizeScale))
                    .background(Theme.accentYellow)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Theme.accentYellow.opacity(0.3), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }
    
    @ViewBuilder
    private func storeSelectorButton(store: Store) -> some View {
        let isSelected = preselectedStore == store
        let activeColor = store.color
        
        Button {
            HapticFeedback.selection()
            preselectedStore = store
        } label: {
            VStack(spacing: 16 * CGFloat(accessibilityTextSizeScale)) {
                Image(systemName: store.sfSymbol)
                    .font(.system(size: 36 * CGFloat(accessibilityTextSizeScale), weight: .bold))
                    .foregroundStyle(isSelected ? .white : activeColor)
                
                Text(store.displayName)
                    .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                    .foregroundStyle(isSelected ? .white : Color.appTextPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32 * CGFloat(accessibilityTextSizeScale))
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? activeColor : Color.appCardBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.05), lineWidth: 2)
            }
            .shadow(color: isSelected ? activeColor.opacity(0.25) : .black.opacity(0.05), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Interfaz de Compra Activa
    
    private func shoppingContent(viewModel: ShoppingModeViewModel) -> some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12 * CGFloat(accessibilityTextSizeScale)) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.store.sfSymbol)
                            .font(.system(size: 14, weight: .bold))
                        Text(viewModel.store.displayName)
                            .font(.system(size: 14, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .foregroundStyle(.white)
                    .background(viewModel.store.color)
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    // Temporizador
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14))
                        Text(viewModel.formattedTime)
                            .font(.system(size: 16, weight: .bold).monospacedDigit())
                    }
                    .foregroundStyle(Color.appTextSecondary)
                    
                    Spacer()
                    
                    Button {
                        HapticFeedback.selection()
                        viewModel.stopSession()
                        dismiss()
                    } label: {
                        Text("Salir")
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                            .bold()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                
                // Barra de Progreso
                VStack(spacing: 6) {
                    HStack {
                        Text("\(viewModel.purchasedCount) de \(viewModel.totalCount) comprados")
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                            .foregroundStyle(Color.appTextSecondary)
                        Spacer()
                        Text("\(Int(viewModel.progress * 100))%")
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                            .bold()
                            .foregroundStyle(Theme.accentYellow)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.08))
                            
                            RoundedRectangle(cornerRadius: 6)
                                .fill(viewModel.store.color)
                                .frame(width: max(0, geo.size.width * viewModel.progress))
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 16)
            .background(Color.appCardBackground)
            
            // Cuerpo principal
            if viewModel.items.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "cart.badge.questionmark")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.appTextSecondary)
                    Text("No hay productos asignados a \(viewModel.store.displayName)")
                        .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(Color.appTextPrimary)
                    Text("Asigna productos a esta tienda en la lista principal para verlos aquí.")
                        .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
            } else if viewModel.categories.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.green)
                    Text("¡No hay productos pendientes!")
                        .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(Color.appTextPrimary)
                    Text("Todos tus artículos para \(viewModel.store.displayName) ya fueron comprados.")
                        .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(Color.appTextSecondary)
                        .padding(.horizontal, 40)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            } else {
                // Mostrar categoría activa
                if let activeCategory = viewModel.activeCategory {
                    VStack(spacing: 0) {
                        // Nombre de Categoría
                        HStack {
                            Image(systemName: activeCategory.sfSymbol)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Theme.accentYellow)
                            
                            Text(activeCategory.displayName.uppercased())
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            // Progreso de categoría
                            let categoryItems = viewModel.items.filter { $0.category == activeCategory }
                            let catPurchased = categoryItems.filter { $0.isPurchased }.count
                            Text("\(catPurchased)/\(categoryItems.count)")
                                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.04))
                        
                        // Lista de productos de la categoría activa
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.activeItems) { item in
                                    shoppingItemRow(item: item, viewModel: viewModel)
                                }
                            }
                            .padding(20)
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            // Barra de navegación inferior
            if !viewModel.categories.isEmpty {
                bottomActionBar(viewModel: viewModel)
            }
        }
    }
    
    // Fila del producto adaptada al supermercado y modo compra
    @ViewBuilder
    private func shoppingItemRow(item: ShoppingItem, viewModel: ShoppingModeViewModel) -> some View {
        HStack(spacing: 16) {
            // Checkbox gigante (50% más grande que en lista normal)
            Button {
                viewModel.toggleItem(item, context: modelContext)
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(item.isPurchased ? Theme.accentYellow : Color.appTextPurchased, lineWidth: 3)
                        
                    if item.isPurchased {
                        Circle()
                            .fill(Theme.accentYellow)
                            .transition(.scale.combined(with: .opacity))
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black)
                    }
                }
                .frame(width: 42 * CGFloat(accessibilityTextSizeScale), height: 42 * CGFloat(accessibilityTextSizeScale))
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.system(size: 18 * CGFloat(accessibilityTextSizeScale), weight: .medium))
                        .foregroundStyle(item.isPurchased ? Color.appTextPurchased : Color.appTextPrimary)
                        .strikethrough(item.isPurchased, color: Color.appTextPurchased)
                        .lineLimit(2)
                    
                    if !item.quantity.isEmpty {
                        Text(item.quantity)
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                            .foregroundStyle(item.isPurchased ? Color.appTextPurchased : Theme.accentYellow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                
                if !item.note.isEmpty {
                    Text(item.note)
                        .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Si tiene nota de voz, permitir reproducción inline
            if item.voiceNoteFilename != nil {
                VoiceNotePlayerButton(filename: item.voiceNoteFilename!)
            }
        }
        .padding(.vertical, 14 * CGFloat(accessibilityTextSizeScale))
        .padding(.horizontal, 18 * CGFloat(accessibilityTextSizeScale))
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        .opacity(item.isPurchased ? 0.6 : 1.0)
    }
    
    // Controles de navegación de categorías inferiores
    @ViewBuilder
    private func bottomActionBar(viewModel: ShoppingModeViewModel) -> some View {
        HStack(spacing: 16) {
            // Categoría anterior
            Button {
                HapticFeedback.selection()
                viewModel.previousCategory()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.activeCategoryIndex == 0)
            .opacity(viewModel.activeCategoryIndex == 0 ? 0.3 : 1.0)
            
            Spacer()
            
            // Indicador / Botón Saltar Categoría
            if viewModel.categories.count > 0 {
                VStack(spacing: 4) {
                    Text("Categoría \(viewModel.activeCategoryIndex + 1) de \(viewModel.categories.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.appTextSecondary)
                    
                    Button {
                        HapticFeedback.selection()
                        viewModel.nextCategory()
                    } label: {
                        Text("Saltar Categoría")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.accentYellow)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.activeCategoryIndex == viewModel.categories.count - 1)
                    .opacity(viewModel.activeCategoryIndex == viewModel.categories.count - 1 ? 0.0 : 1.0)
                }
            }
            
            Spacer()
            
            // Categoría siguiente
            Button {
                HapticFeedback.selection()
                viewModel.nextCategory()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.activeCategoryIndex == viewModel.categories.count - 1)
            .opacity(viewModel.activeCategoryIndex == viewModel.categories.count - 1 ? 0.3 : 1.0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(Color.appCardBackground)
    }
    
    private func recordCompletedPurchase(viewModel: ShoppingModeViewModel) {
        var stats = UserStats.load()
        stats.recordPurchase(productsCount: viewModel.totalCount)
    }
}
