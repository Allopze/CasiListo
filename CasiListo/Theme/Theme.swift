import SwiftUI
import UIKit

/// Sistema de diseño centralizado para CasiListo.
/// Minimalista cálido con acento amarillo. Sigue la apariencia del sistema (claro/oscuro).
enum Theme {

    // MARK: - Colores de acento

    /// Amarillo principal de la app — #F5C518.
    static let accentYellow = Color(red: 0.96, green: 0.77, blue: 0.09)

    // MARK: - Medidas Estáticas (Compatibilidad)

    static let cornerRadius: CGFloat = 20
    static let smallCornerRadius: CGFloat = 14
    static let controlCornerRadius: CGFloat = 24
    static let chipCornerRadius: CGFloat = 24
    static let cardPadding: CGFloat = 16
    static let itemSpacing: CGFloat = 12
    static let sectionSpacing: CGFloat = 24

    // MARK: - Fuentes Estáticas (Compatibilidad)

    static let titleFont = Font.system(size: 34, weight: .bold, design: .rounded)
    static let sectionHeaderFont = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let bodyFont = Font.system(size: 17, weight: .regular, design: .rounded)
    static let bodyBoldFont = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let captionFont = Font.system(size: 13, weight: .regular, design: .rounded)
    static let chipFont = Font.system(size: 13, weight: .medium, design: .rounded)

    // MARK: - Accesibilidad Dinámica

    static func titleFont(scale: Double) -> Font {
        Font.system(size: 34 * CGFloat(scale), weight: .bold, design: .rounded)
    }

    static func sectionHeaderFont(scale: Double) -> Font {
        Font.system(size: 15 * CGFloat(scale), weight: .bold, design: .rounded)
    }

    static func bodyFont(scale: Double) -> Font {
        Font.system(size: 17 * CGFloat(scale), weight: .regular, design: .rounded)
    }

    static func bodyBoldFont(scale: Double) -> Font {
        Font.system(size: 17 * CGFloat(scale), weight: .bold, design: .rounded)
    }

    static func captionFont(scale: Double) -> Font {
        Font.system(size: 13 * CGFloat(scale), weight: .regular, design: .rounded)
    }

    static func chipFont(scale: Double) -> Font {
        Font.system(size: 13 * CGFloat(scale), weight: .medium, design: .rounded)
    }

    static func cornerRadius(scale: Double) -> CGFloat {
        20 * CGFloat(scale)
    }

    static func smallCornerRadius(scale: Double) -> CGFloat {
        14 * CGFloat(scale)
    }

    static func controlCornerRadius(scale: Double) -> CGFloat {
        24 * CGFloat(scale)
    }

    static func cardPadding(scale: Double) -> CGFloat {
        16 * CGFloat(scale)
    }

    static func itemSpacing(scale: Double) -> CGFloat {
        12 * CGFloat(scale)
    }

    static func sectionSpacing(scale: Double) -> CGFloat {
        24 * CGFloat(scale)
    }

    // MARK: - Animaciones

    static let defaultAnimation = Animation.spring(response: 0.35, dampingFraction: 0.75)
    static let quickAnimation = Animation.easeOut(duration: 0.2)
}

// MARK: - Liquid Glass

extension View {
    @ViewBuilder
    func glassActionSurface(
        cornerRadius: CGFloat = Theme.controlCornerRadius,
        interactive: Bool = true
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(iOS 26, *) {
            if interactive {
                self.glassEffect(
                    .regular.tint(Theme.accentYellow.opacity(0.18)).interactive(),
                    in: shape
                )
            } else {
                self.glassEffect(
                    .regular.tint(Theme.accentYellow.opacity(0.12)),
                    in: shape
                )
            }
        } else {
            self.background(.ultraThinMaterial, in: shape)
                .background(Theme.accentYellow.opacity(interactive ? 0.12 : 0.08), in: shape)
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
        }
    }

    @ViewBuilder
    func glassFilterSurface(
        cornerRadius: CGFloat = Theme.controlCornerRadius,
        interactive: Bool = false
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(iOS 26, *) {
            if interactive {
                self.glassEffect(.regular.interactive(), in: shape)
            } else {
                self.glassEffect(.regular, in: shape)
            }
        } else {
            self.background(.ultraThinMaterial, in: shape)
                .background(Color.appCardBackground.opacity(interactive ? 0.5 : 0.2), in: shape)
                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - Adaptive Containers & Styles

/// Contenedor adaptativo para agrupar elementos con efecto glass.
/// En iOS 26+ usa `GlassEffectContainer` nativo. En versiones anteriores, renderiza el contenido directamente.
struct AdaptiveGlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

/// Estilo de botón glass adaptativo (fallback para iOS < 26).
struct AdaptiveGlassButtonStyle: ButtonStyle {
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    func makeBody(configuration: Configuration) -> some View {
        let size = 40 * CGFloat(accessibilityTextSizeScale)
        configuration.label
            .frame(width: size, height: size)
            .background(.ultraThinMaterial)
            .background(Color.appCardBackground.opacity(0.4))
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            .opacity(configuration.isPressed ? 0.72 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(Theme.quickAnimation, value: configuration.isPressed)
    }
}

/// Estilo de botón glass prominente adaptativo (fallback para iOS < 26).
struct AdaptiveGlassProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundStyle(Color.appTextPrimary)
            .background(Theme.accentYellow.opacity(0.85))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .shadow(color: Theme.accentYellow.opacity(0.2), radius: 6, x: 0, y: 3)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Theme.quickAnimation, value: configuration.isPressed)
    }
}

extension View {
    @ViewBuilder
    func adaptiveGlassButtonStyle() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(AdaptiveGlassButtonStyle())
        }
    }

    @ViewBuilder
    func adaptiveGlassProminentButtonStyle() -> some View {
        if #available(iOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(AdaptiveGlassProminentButtonStyle())
        }
    }

    @ViewBuilder
    func adaptiveSearchToolbarBehavior() -> some View {
        if #available(iOS 26.0, *) {
            self.searchToolbarBehavior(.minimize)
        } else {
            self
        }
    }

    @ViewBuilder
    func adaptiveSearchPresentationToolbarBehavior() -> some View {
        if #available(iOS 17.1, *) {
            self.searchPresentationToolbarBehavior(.avoidHidingContent)
        } else {
            self
        }
    }
}

// MARK: - Haptics

@MainActor
enum HapticFeedback {
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static let impactGenerator = UIImpactFeedbackGenerator(style: .light)

    static func selection() {
        selectionGenerator.selectionChanged()
    }

    static func success() {
        notificationGenerator.notificationOccurred(.success)
    }

    static func impact() {
        impactGenerator.impactOccurred()
    }
}

// MARK: - Colores programáticos (fallback sin Asset Catalog)

extension Color {

    /// Fondo principal adaptativo.
    static let appBackground = Color(light: Color(hex: "FAF8F5"), dark: Color(hex: "1C1B1A"))

    /// Fondo de tarjeta adaptativo.
    static let appCardBackground = Color(light: Color.white, dark: Color(hex: "2A2928"))

    /// Texto primario adaptativo.
    static let appTextPrimary = Color(light: Color(hex: "1A1A1A"), dark: Color(hex: "F5F5F5"))

    /// Texto secundario adaptativo.
    static let appTextSecondary = Color(light: Color(hex: "8A8A8A"), dark: Color(hex: "A0A0A0"))

    /// Texto para ítems comprados.
    static let appTextPurchased = Color(light: Color(hex: "C0C0C0"), dark: Color(hex: "666666"))

    /// Separador sutil.
    static let appSeparator = Color(light: Color(hex: "ECECEC"), dark: Color(hex: "3A3938"))

    // MARK: - Helpers

    /// Crea un color adaptativo para claro y oscuro.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }

    /// Crea un color desde un string hexadecimal.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}
