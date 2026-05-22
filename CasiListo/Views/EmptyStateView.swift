import SwiftUI

/// Pantalla vacía mostrada cuando no hay productos en la lista.
struct EmptyStateView: View {
    let onAddTapped: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            LogoView(size: 80)
                .padding(.bottom, 8)

            Text("Tu lista está vacía")
                .font(Theme.bodyBoldFont)
                .foregroundStyle(Color.appTextPrimary)

            Text("Añade productos para tu próxima compra")
                .font(Theme.captionFont)
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)

            AdaptiveGlassEffectContainer(spacing: 12) {
                Button {
                    HapticFeedback.impact()
                    onAddTapped()
                } label: {
                    Label("Añadir producto", systemImage: "plus")
                        .font(Theme.bodyBoldFont)
                }
                .adaptiveGlassProminentButtonStyle()
            }
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

/// Vista del logo de CasiListo con carga adaptativa y fallback seguro.
struct LogoView: View {
    var size: CGFloat = 80

    var body: some View {
        if let uiImage = loadLogo() {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        } else {
            Image(systemName: "cart")
                .font(.system(size: size - 16, weight: .light))
                .foregroundStyle(Color.appTextPurchased)
        }
    }

    private func loadLogo() -> UIImage? {
        // 1. Rutas absolutas de desarrollo local
        let absolutePaths = [
            "/Users/allopze/dev/CasiListo/CasiListo/logo.png",
            "/Users/allopze/dev/CasiListo/logo.png"
        ]
        for path in absolutePaths {
            if let image = UIImage(contentsOfFile: path) {
                return image
            }
        }
        
        // 2. Rutas relativas al directorio de ejecución actual
        let fm = FileManager.default
        let relativePaths = [
            fm.currentDirectoryPath + "/CasiListo/logo.png",
            fm.currentDirectoryPath + "/logo.png"
        ]
        for path in relativePaths {
            if let image = UIImage(contentsOfFile: path) {
                return image
            }
        }
        
        // 3. Ruta en los recursos del Bundle (si se compila vía Xcode/SPM)
        if let bundlePath = Bundle.main.path(forResource: "logo", ofType: "png"),
           let image = UIImage(contentsOfFile: bundlePath) {
            return image
        }
        if let image = UIImage(named: "logo") {
            return image
        }
        return nil
    }
}
