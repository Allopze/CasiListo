import WidgetKit
import SwiftUI

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
                topItems: ["Leche", "Pan", "Tomates", "Huevos", "Aceite"],
                updatedAt: .now
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PendingItemsEntry) -> Void) {
        completion(PendingItemsEntry(date: .now, snapshot: WidgetSnapshot.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PendingItemsEntry>) -> Void) {
        let entry = PendingItemsEntry(date: .now, snapshot: WidgetSnapshot.read())
        // La app llama WidgetCenter.reloadAllTimelines() al mutar items.
        // El refresh cada 30 min es solo el fallback.
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Widget Views

struct SmallWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        ZStack {
            Color(red: 0.98, green: 0.97, blue: 0.96)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(red: 0.96, green: 0.77, blue: 0.09))
                    Text("CasiListo")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
                }

                Spacer()

                Text("\(snapshot.pendingCount)")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
                    .minimumScaleFactor(0.6)

                Text(snapshot.pendingCount == 1 ? "pendiente" : "pendientes")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))

                if snapshot.purchasedCount > 0 {
                    Label("\(snapshot.purchasedCount) comprados", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.green)
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

struct MediumWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        ZStack {
            Color(red: 0.98, green: 0.97, blue: 0.96)
            HStack(alignment: .top, spacing: 0) {
                // Panel izquierdo: conteo
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(red: 0.96, green: 0.77, blue: 0.09))
                        Text("CasiListo")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
                    }

                    Spacer()

                    Text("\(snapshot.pendingCount)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))

                    Text(snapshot.pendingCount == 1 ? "pendiente" : "pendientes")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.5))

                    if snapshot.purchasedCount > 0 {
                        Label("\(snapshot.purchasedCount)", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.green)
                    }
                }
                .padding(14)
                .frame(maxHeight: .infinity, alignment: .leading)

                // Divider
                Rectangle()
                    .fill(Color(red: 0.9, green: 0.89, blue: 0.87))
                    .frame(width: 1)
                    .padding(.vertical, 14)

                // Panel derecho: lista de ítems
                VStack(alignment: .leading, spacing: 5) {
                    if snapshot.topItems.isEmpty {
                        Text("Lista vacía")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Color(red: 0.6, green: 0.6, blue: 0.6))
                    } else {
                        ForEach(snapshot.topItems.prefix(5), id: \.self) { name in
                            HStack(spacing: 6) {
                                Circle()
                                    .stroke(Color(red: 0.7, green: 0.7, blue: 0.7), lineWidth: 1.5)
                                    .frame(width: 10, height: 10)
                                Text(name)
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15))
                                    .lineLimit(1)
                            }
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
}

struct CasiListoWidgetEntryView: View {
    let entry: PendingItemsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(snapshot: entry.snapshot)
        case .systemMedium:
            MediumWidgetView(snapshot: entry.snapshot)
        default:
            SmallWidgetView(snapshot: entry.snapshot)
        }
    }
}

// MARK: - Widget

struct CasiListoWidget: Widget {
    let kind = "CasiListoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PendingItemsProvider()) { entry in
            CasiListoWidgetEntryView(entry: entry)
                .containerBackground(Color(red: 0.98, green: 0.97, blue: 0.96), for: .widget)
        }
        .configurationDisplayName("CasiListo")
        .description("Productos pendientes en tu lista de compra.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Entry Point

@main
struct CasiListoWidgetBundle: WidgetBundle {
    var body: some Widget {
        CasiListoWidget()
    }
}
