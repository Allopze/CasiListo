import Foundation

/// Formateo de fechas anclado a Chile.
///
/// `Date.formatted(date:time:)` sigue el idioma del dispositivo, así que un
/// teléfono en inglés producía «17 Aug 2026 at 12:08 PM» dentro de una interfaz
/// en español —y títulos mezclados como «Finalizada el 17 August 2026 at 12:08 PM»,
/// que además quedan **persistidos** en el título de la compra. La app es
/// monolingüe en español, de modo que el locale se fija en vez de heredarse.
enum AppDateFormatting {
    static let locale = Locale(identifier: "es_CL")

    /// «17 ago 2026» — para títulos de compra.
    static func short(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)
        )
    }

    /// «17 ago 2026, 12:08» — para listados.
    static func shortWithTime(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale)
        )
    }

    /// «17 de agosto de 2026, 12:08» — para el detalle.
    static func longWithTime(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .long, time: .shortened).locale(locale)
        )
    }

    /// «17-08-2026, 12:08» — compacto, para exportar.
    static func numericWithTime(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .numeric, time: .shortened).locale(locale)
        )
    }
}
