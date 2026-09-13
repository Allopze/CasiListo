import AppIntents
import WidgetKit
import SwiftUI
import UIKit

// MARK: - Timeline Entry

struct PendingItemsEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

// MARK: - Provider

struct PendingItemsProvider: TimelineProvider {
    func placeholder(in context: Context) -> PendingItemsEntry {
        PendingItemsEntry(
            date: .now,
            snapshot: WidgetSnapshot(
                pendingCount: 5,
                purchasedCount: 2,
                topItems: ["Leche", "Pan", "Tomates", "Huevos", "Aceite"].map { WidgetItemSnapshot(id: UUID(), name: $0) },
                updatedAt: .now
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PendingItemsEntry) -> Void) {
        completion(PendingItemsEntry(date: .now, snapshot: WidgetSnapshot.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PendingItemsEntry>) -> Void) {
        let entry = PendingItemsEntry(date: .now, snapshot: WidgetSnapshot.read())
        // La app solicita un refresh coalescido del kind tras un commit.
        // El refresh cada 30 min es solo el fallback.
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Widget Views

struct SmallWidgetView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.colorScheme) private var colorScheme

    private var textColorPrimary: Color {
        colorScheme == .dark ? .white : Color(red: 0.1, green: 0.1, blue: 0.1)
    }

    private var textColorSecondary: Color {
        colorScheme == .dark ? Color(red: 0.6, green: 0.6, blue: 0.64) : Color(red: 0.5, green: 0.5, blue: 0.5)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetHeader(textColor: textColorPrimary)

            Spacer()

            if snapshot.isPlaceholder {
                // Sin snapshot todavía, «0 pendientes» afirma algo falso: se ve
                // igual que una compra terminada cuando en realidad la app
                // nunca se ha abierto.
                Text("Abre CasiListo para empezar")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(textColorSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            } else {
                Text("\(snapshot.pendingCount)")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(textColorPrimary)
                    .minimumScaleFactor(0.6)

                Text(snapshot.pendingCount == 1 ? "pendiente" : "pendientes")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(textColorSecondary)

                if snapshot.purchasedCount > 0 {
                    Label("\(snapshot.purchasedCount) comprados", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(WidgetPalette.purchased)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct MediumWidgetView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.colorScheme) private var colorScheme

    private var textColorPrimary: Color {
        colorScheme == .dark ? .white : Color(red: 0.1, green: 0.1, blue: 0.1)
    }

    private var textColorItemName: Color {
        colorScheme == .dark ? Color(red: 0.9, green: 0.9, blue: 0.9) : Color(red: 0.15, green: 0.15, blue: 0.15)
    }

    private var textColorSecondary: Color {
        colorScheme == .dark ? Color(red: 0.6, green: 0.6, blue: 0.64) : Color(red: 0.5, green: 0.5, blue: 0.5)
    }

    private var dividerColor: Color {
        colorScheme == .dark ? Color(red: 0.22, green: 0.22, blue: 0.24) : Color(red: 0.9, green: 0.89, blue: 0.87)
    }

    private var checkboxBorderColor: Color {
        colorScheme == .dark ? Color(red: 0.4, green: 0.4, blue: 0.45) : Color(red: 0.7, green: 0.7, blue: 0.7)
    }

    var body: some View {
        if snapshot.isPlaceholder {
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader(textColor: textColorPrimary)
                Spacer()
                Text("Abre CasiListo para empezar")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(textColorSecondary)
                Text("Tus productos pendientes aparecerán aquí.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(textColorSecondary)
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            contentColumns
        }
    }

    private var contentColumns: some View {
        HStack(alignment: .top, spacing: 0) {
            // Panel izquierdo: conteo
            VStack(alignment: .leading, spacing: 4) {
                WidgetHeader(textColor: textColorPrimary)

                Spacer()

                Text("\(snapshot.pendingCount)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(textColorPrimary)

                Text(snapshot.pendingCount == 1 ? "pendiente" : "pendientes")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(textColorSecondary)

                if snapshot.purchasedCount > 0 {
                    Label("\(snapshot.purchasedCount)", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(WidgetPalette.purchased)
                }
            }
            .padding(14)
            .frame(maxHeight: .infinity, alignment: .leading)

            // Divider
            Rectangle()
                .fill(dividerColor)
                .frame(width: 1)
                .padding(.vertical, 14)

            // Panel derecho: lista de ítems
            VStack(alignment: .leading, spacing: 5) {
                if snapshot.topItems.isEmpty {
                    Text("Lista vacía")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(textColorSecondary)
                } else {
                    ForEach(snapshot.topItems.prefix(5)) { item in
                        // Cada fila es un botón: marca el producto sin abrir
                        // la app. El resto del widget sigue abriendo la lista
                        // vía `widgetURL`.
                        Button(intent: MarkPurchasedIntent(itemID: item.id)) {
                            HStack(spacing: 6) {
                                Circle()
                                    .stroke(checkboxBorderColor, lineWidth: 1.5)
                                    .frame(width: 10, height: 10)
                                Text(item.name)
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(textColorItemName)
                                    .lineLimit(1)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Marcar \(item.name) como comprado")
                    }
                }
                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Pantalla bloqueada / StandBy

/// Las familias `.accessory*` se renderizan en un solo color que decide el
/// sistema (esfera de Lock Screen, texto junto al reloj): los colores
/// propios de `WidgetPalette` no aplican aquí y `.foregroundStyle` con un
/// color explícito puede incluso ignorarse. Todo el contenido usa el estilo
/// por defecto a propósito.
struct AccessoryCircularView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if snapshot.isPlaceholder {
            Image(systemName: "cart")
                .font(.system(size: 20, weight: .semibold))
        } else {
            VStack(spacing: 0) {
                Image(systemName: "cart.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("\(snapshot.pendingCount)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

struct AccessoryRectangularView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("CasiListo", systemImage: "cart.fill")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)

            if snapshot.isPlaceholder {
                Text("Abre CasiListo para empezar")
                    .font(.system(size: 12))
                    .lineLimit(1)
            } else {
                Text(snapshot.pendingCount == 1 ? "1 pendiente" : "\(snapshot.pendingCount) pendientes")
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                if let firstItem = snapshot.topItems.first {
                    Text(firstItem.name)
                        .font(.system(size: 12))
                        .lineLimit(1)
                }
            }
        }
    }
}

struct AccessoryInlineView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if snapshot.isPlaceholder {
            Label("CasiListo", systemImage: "cart")
        } else {
            Label(
                snapshot.pendingCount == 1 ? "1 pendiente" : "\(snapshot.pendingCount) pendientes",
                systemImage: "cart.fill"
            )
        }
    }
}

// MARK: - Home Screen

/// Cabecera común de los dos tamaños.
private struct WidgetHeader: View {
    let textColor: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "cart.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(WidgetPalette.brand)
            Text("CasiListo")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(textColor)
        }
    }
}

/// El widget no comparte fuentes con la app, así que los colores viven aquí.
/// `Color.green` del sistema rendía ~1.9:1 sobre el crema del fondo.
private enum WidgetPalette {
    static let brand = Color(red: 0.96, green: 0.77, blue: 0.09)
    static let purchased = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.44, green: 0.82, blue: 0.55, alpha: 1)
                : UIColor(red: 0.11, green: 0.43, blue: 0.20, alpha: 1)
        }
    )
}

struct CasiListoWidgetEntryView: View {
    let entry: PendingItemsEntry
    @Environment(\.widgetFamily) private var family

    /// Fondo opaco solo en Home Screen: la pantalla bloqueada y StandBy ponen
    /// su propio material detrás, y pintar uno propio ahí se ve como un
    /// bloque de color fuera de lugar en vez de integrarse con el sistema.
    private var containerBackground: Color {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            return .clear
        default:
            return Color(uiColor: UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
                    : UIColor(red: 0.98, green: 0.97, blue: 0.96, alpha: 1.0)
            })
        }
    }

    var body: some View {
        let content = Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(snapshot: entry.snapshot)
            case .systemMedium:
                MediumWidgetView(snapshot: entry.snapshot)
            case .accessoryCircular:
                AccessoryCircularView(snapshot: entry.snapshot)
            case .accessoryRectangular:
                AccessoryRectangularView(snapshot: entry.snapshot)
            case .accessoryInline:
                AccessoryInlineView(snapshot: entry.snapshot)
            default:
                SmallWidgetView(snapshot: entry.snapshot)
            }
        }
        content
            .widgetAccentable()
            .widgetURL(URL(string: "casilisto://list"))
            .containerBackground(containerBackground, for: .widget)
    }
}

// MARK: - Widget

struct CasiListoWidget: Widget {
    let kind = WidgetContract.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PendingItemsProvider()) { entry in
            CasiListoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("CasiListo")
        .description("Productos pendientes en tu lista de compra.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}

// MARK: - Entry Point

@main
struct CasiListoWidgetBundle: WidgetBundle {
    var body: some Widget {
        CasiListoWidget()
    }
}
