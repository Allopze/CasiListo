import SwiftUI

/// Selector de supermercado para inicializar la sesión de compras.
struct StoreSelectorView: View {
    @Binding var preselectedStore: Store
    let onDismiss: () -> Void
    let onStart: () -> Void
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    var body: some View {
        VStack(spacing: 24 * CGFloat(accessibilityTextSizeScale)) {
            HStack {
                Spacer()
                Button {
                    HapticFeedback.selection()
                    onDismiss()
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
                onStart()
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
}
