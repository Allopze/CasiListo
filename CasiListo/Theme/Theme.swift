import SwiftUI
import UIKit
import os.log

/// Sistema de diseño centralizado para CasiListo.
/// Minimalista cálido con acento amarillo. Sigue la apariencia del sistema (claro/oscuro).
enum Theme {

    // MARK: - Colores de acento

    /// Amarillo principal de la app — #F5C518.
    static let accentYellow = Color(red: 0.96, green: 0.77, blue: 0.09)

    /// Tinta para texto e íconos sobre el amarillo de acento (10.7:1 en ambos modos).
    nonisolated static let onAccent = Color(hex: "1A1A1A")

    /// Acento para **texto e íconos**, no para rellenos. El amarillo de marca
    /// rinde 1.45:1 sobre el crema de fondo y 1.63:1 sobre tarjeta blanca: como
    /// color de texto es ilegible.
    ///
    /// El oro claro cumple AA para texto normal sobre las dos superficies de la
    /// app —4.52:1 sobre el crema, 5.09:1 sobre tarjeta blanca— y en oscuro se
    /// conserva el amarillo de marca, que ahí rinde 10.6:1. Verificado por
    /// `testAccentTokensMeetContrastOnLightSurfaces`.
    ///
    /// Regla: `accentYellow` rellena, `accentInteractive` escribe.
    static let accentInteractive = Color(light: UIColor(hex: "8A6A00"), dark: UIColor(hex: "F5C518"))

    /// Color legible sobre un relleno arbitrario: elige blanco o `onAccent`
    /// según cuál dé mayor contraste WCAG. Ningún valor fijo sirve para una
    /// paleta que va del amarillo al violeta.
    nonisolated static func foreground(on hex: String) -> Color {
        let background = relativeLuminance(of: UIColor(hex: hex))
        let contrastWithWhite = 1.05 / (background + 0.05)
        let contrastWithDark = (background + 0.05) / (onAccentLuminance + 0.05)
        return contrastWithDark >= contrastWithWhite ? onAccent : .white
    }

    nonisolated private static let onAccentLuminance = relativeLuminance(of: UIColor(hex: "1A1A1A"))

    /// Razón de contraste WCAG entre dos colores opacos.
    nonisolated static func contrastRatio(_ a: UIColor, _ b: UIColor) -> Double {
        let la = relativeLuminance(of: a), lb = relativeLuminance(of: b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    nonisolated static func relativeLuminance(of color: UIColor) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        func linear(_ component: CGFloat) -> Double {
            let value = Double(component)
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    // MARK: - Medidas Estáticas (Compatibilidad)

    static let cornerRadius: CGFloat = 20
    static let smallCornerRadius: CGFloat = 16
    static let controlCornerRadius: CGFloat = 999
    static let chipCornerRadius: CGFloat = 999
    static let cardPadding: CGFloat = 16
    static let itemSpacing: CGFloat = 12
    static let sectionSpacing: CGFloat = 24
    static let minimumTouchTarget: CGFloat = 44

    // MARK: - Dynamic Type (Nativo)
    // Respetan automáticamente la configuración de accesibilidad del sistema
    // y conservan la identidad rounded de la app.

    static let titleDynamic: Font = .system(.largeTitle, design: .rounded, weight: .bold)
    static let headlineDynamic: Font = .system(.headline, design: .rounded, weight: .bold)
    static let bodyDynamic: Font = .system(.body, design: .rounded)
    static let bodyBoldDynamic: Font = .system(.body, design: .rounded, weight: .semibold)
    static let captionDynamic: Font = .system(.caption, design: .rounded)
    static let chipDynamic: Font = .system(.caption, design: .rounded, weight: .medium)
    static let sectionHeaderDynamic: Font = .system(.title3, design: .rounded, weight: .bold)

    // MARK: - Logger

    private static let logger = Logger(subsystem: "com.casilisto.app", category: "Theme")

    // MARK: - Estados de producto

    /// Los colores de estado del sistema no sirven sobre superficies claras:
    /// `.green` mide 2,22:1 y `.orange` similar sobre tarjeta blanca —bajo el
    /// 3:1 que WCAG exige a un elemento gráfico (CASI-015). Estos tres pares
    /// ya vivían repetidos como literales en `Store.labelColor`,
    /// `ItemRowView.metaChips` y `SettingsCard`; aquí existen una sola vez.
    ///
    /// Medidos sobre tarjeta clara (#FFFFFF) / fondo oscuro (#2A2928).
    static let statusPurchased = Color(light: UIColor(hex: "1B6E33"), dark: UIColor(hex: "6FD08C"))
    static let statusSkipped = Color(light: UIColor(hex: "A34A00"), dark: UIColor(hex: "FFA04D"))
    static let statusUnavailable = Color(light: UIColor(hex: "BA2115"), dark: UIColor(hex: "FF8078"))

    /// Verde de **relleno**, no de tinta: aquí el color es fondo y la
    /// etiqueta va en blanco encima. El token de arriba, pensado para texto
    /// sobre blanco, daría un relleno demasiado oscuro para una cápsula.
    static let statusPurchasedFill = Color(hex: "2E7D42")

    // MARK: - Animaciones

    static let defaultAnimation = Animation.spring(response: 0.35, dampingFraction: 0.75)
    static let quickAnimation = Animation.easeOut(duration: 0.2)

    /// Reduce Motion se honra pasando `nil`. Centralizado para que ninguna
    /// vista tenga que recordar el ternario —y para que olvidarlo se note al
    /// leer (CASI-010). No `nonisolated`: `defaultAnimation`/`quickAnimation`
    /// son propiedades aisladas a `@MainActor` (por defecto en este target) y
    /// solo se llaman desde Views/ViewModels, ya en ese contexto.
    static func defaultAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : defaultAnimation
    }

    static func quickAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : quickAnimation
    }
}

// MARK: - Liquid Glass

extension View {
    /// Superficie de vidrio para chips y campos. Con el piso en iOS 26 ya no
    /// hay rama de compatibilidad: se conserva como token del sistema de
    /// diseño para que el radio y la interactividad se decidan en un solo sitio.
    func glassFilterSurface(
        cornerRadius: CGFloat = Theme.controlCornerRadius,
        interactive: Bool = false
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
    }
}

// MARK: - Botón primario de marca

/// Botón primario de marca: relleno amarillo con tinta oscura (10.7:1).
///
/// Existe porque `.borderedProminent` pinta la etiqueta en blanco y el blanco
/// sobre el amarillo de marca da 1.63:1 — el CTA principal quedaba ilegible en
/// modo claro. Usar siempre este estilo en vez de `.borderedProminent` + `.tint`.
struct AccentProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.bodyBoldDynamic)
            .foregroundStyle(Theme.onAccent)
            .frame(minHeight: Theme.minimumTouchTarget)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Theme.accentYellow, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Theme.quickAnimation, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == AccentProminentButtonStyle {
    static var accentProminent: AccentProminentButtonStyle { AccentProminentButtonStyle() }
}

/// Botón secundario de marca: relleno de tarjeta, borde y etiqueta de acento.
///
/// Existe porque `.bordered` compone la etiqueta con el tint sobre un relleno
/// **del mismo tint** al ~20%: "Elegir una foto" en la boleta medía 3,60:1,
/// bajo el 4,5:1 que este proyecto exige al texto (CASI-016). Con el relleno
/// de tarjeta el mismo acento rinde 5,07:1 en claro y 8,91:1 en oscuro.
struct AccentBorderedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.bodyBoldDynamic)
            .foregroundStyle(Theme.accentInteractive)
            .frame(minHeight: Theme.minimumTouchTarget)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.appCardBackground, in: Capsule())
            .overlay { Capsule().strokeBorder(Theme.accentInteractive, lineWidth: 1.5) }
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(Theme.quickAnimation, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == AccentBorderedButtonStyle {
    static var accentBordered: AccentBorderedButtonStyle { AccentBorderedButtonStyle() }
}

// MARK: - Haptics

@MainActor
enum HapticFeedback {
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static let impactGenerator = UIImpactFeedbackGenerator(style: .light)

    static func selection() {
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }

    static func success() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.success)
    }

    static func impact() {
        impactGenerator.prepare()
        impactGenerator.impactOccurred()
    }
}

extension UIColor {
    /// Oscurece el color —bajando brillo y compensando saturación— hasta alcanzar
    /// `target` de contraste contra `background`, conservando el tono.
    ///
    /// Se usa para iconos pintados sobre una versión translúcida de su propio
    /// color: ahí los tonos claros quedan casi invisibles (el amarillo de
    /// «Lácteos y huevos» rendía 1.6:1) y no basta con elegir blanco o negro,
    /// porque se perdería la identidad cromática de la categoría.
    nonisolated func darkened(toContrast target: Double, over background: UIColor) -> UIColor {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }

        var candidate = self
        var currentBrightness = brightness
        var currentSaturation = saturation

        // 40 pasos de 2.5% cubren de brillo pleno a negro; se detiene al cumplir.
        for _ in 0..<40 {
            if Theme.contrastRatio(candidate, background) >= target { return candidate }
            currentBrightness = max(0, currentBrightness - 0.025)
            currentSaturation = min(1, currentSaturation + 0.01)
            candidate = UIColor(
                hue: hue,
                saturation: currentSaturation,
                brightness: currentBrightness,
                alpha: alpha
            )
        }

        return candidate
    }

    /// Compone este color con `alpha` sobre `background` (sin translucidez).
    nonisolated func blended(alpha: CGFloat, over background: UIColor) -> UIColor {
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
        background.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return UIColor(
            red: fr * alpha + br * (1 - alpha),
            green: fg * alpha + bg * (1 - alpha),
            blue: fb * alpha + bb * (1 - alpha),
            alpha: 1
        )
    }

    /// Crea un UIColor desde un string hexadecimal (RGB de 6 dígitos).
    nonisolated convenience init(hex: String) {
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
            red: CGFloat(Double(r) / 255.0),
            green: CGFloat(Double(g) / 255.0),
            blue: CGFloat(Double(b) / 255.0),
            alpha: 1.0
        )
    }
}

// MARK: - Colores programáticos (fallback sin Asset Catalog)

extension Color {

    /// Fondo principal adaptativo. Crema cálido con profundidad suficiente
    /// para que las tarjetas blancas se lean como superficies.
    static let appBackground = Color(light: UIColor(hex: "F5F1EB"), dark: UIColor(hex: "1C1B1A"))

    /// Fondo de tarjeta adaptativo.
    static let appCardBackground = Color(light: UIColor.white, dark: UIColor(hex: "2A2928"))

    /// Texto primario adaptativo.
    static let appTextPrimary = Color(light: UIColor(hex: "1A1A1A"), dark: UIColor(hex: "F5F5F5"))

    /// Texto secundario adaptativo. 6E6E6E da 4.8:1 sobre el fondo crema (WCAG AA).
    static let appTextSecondary = Color(light: UIColor(hex: "6E6E6E"), dark: UIColor(hex: "A0A0A0"))

    /// Texto para ítems comprados.
    static let appTextPurchased = Color(light: UIColor(hex: "8A8680"), dark: UIColor(hex: "A8A8A8"))

    /// Separador sutil (cálido, en armonía con el fondo crema).
    static let appSeparator = Color(light: UIColor(hex: "EAE5DD"), dark: UIColor(hex: "3A3938"))

    // MARK: - Helpers

    /// Crea un color adaptativo para claro y oscuro.
    /// `nonisolated` para que el provider de UIKit lo pueda resolver en el hilo
    /// del renderer sin que Swift 6 dispare la aserción de aislamiento @MainActor
    /// (recordar que el proyecto usa SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor).
    nonisolated init(light: UIColor, dark: UIColor) {
        self = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    /// Crea un color desde un string hexadecimal.
    nonisolated init(hex: String) {
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
