import CompanionKit
import HubCore
import SwiftUI
import WidgetKit

@main
struct LifeHubWatchWidgets: WidgetBundle {
    var body: some Widget {
        WatchStatusWidget()
    }
}

/// What the watch widgets draw from: the iPhone's last payload at one point in time.
struct WatchEntry: TimelineEntry {
    let date: Date
    let payload: WatchPayload?

    var mode: Mode? { payload?.snapshot.mode }
}

// Widgets only read what the watch app stored (lessons DW-04).
/// Reads the stored payload and redraws when the iPhone widgets would.
struct WatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchEntry {
        let snapshot = WidgetSnapshot(mode: .work, since: nil, energy: .okay, updatedAt: .now)
        return WatchEntry(date: .now, payload: WatchPayload(snapshot: snapshot))
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchEntry) -> Void) {
        let payload = WatchPayload.read(from: AppGroup.container.watchPayloadURL)
        completion(context.isPreview ? placeholder(in: context) : WatchEntry(date: .now, payload: payload))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchEntry>) -> Void) {
        let payload = WatchPayload.read(from: AppGroup.container.watchPayloadURL)
        let dates = payload?.timelineDates(after: .now) ?? [.now]
        completion(Timeline(entries: dates.map { WatchEntry(date: $0, payload: payload) }, policy: .atEnd))
    }
}

/// HAKU on the watch face, like the iPhone Lock Screen widget.
struct WatchStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "status", provider: WatchProvider()) { entry in
            WatchStatusView(entry: entry)
        }
        .configurationDisplayName("HAKU")
        .description("HAKU 现在在干什么。")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular])
    }
}

struct WatchStatusView: View {
    let entry: WatchEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content.containerBackground(.clear, for: .widget)
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCorner:
            head.widgetLabel(title ?? "打开 iPhone")
        case .accessoryRectangular:
            HStack(spacing: 6) {
                head.frame(width: 40)
                modeAndTime.font(.headline).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            }
        default:
            ZStack {
                AccessoryWidgetBackground()
                head.padding(4)
            }
        }
    }

    // PM spec (Issue #160): one line, the mode and how long it has run.
    @ViewBuilder private var modeAndTime: some View {
        if let mode = entry.mode, let since = entry.payload?.snapshot.since {
            Text("\(mode.title(for: persona)) · \(Text(since, style: .relative))")
        } else {
            Text(title ?? "打开 iPhone")
        }
    }

    private var persona: Persona { entry.payload?.persona ?? .haku }
    private var title: String? { entry.mode?.title(for: persona) }

    @ViewBuilder private var head: some View {
        if let payload = entry.payload, let mode = entry.mode, payload.persona == .kuro {
            KuroPortrait(
                look: KuroLook(mode: mode),
                energy: payload.snapshot.energy(at: entry.date)?.value,
                bedtime: payload.bedtime.state(at: entry.date),
                framing: .head
            )
        } else if let payload = entry.payload, let mode = entry.mode {
            let snapshot = payload.snapshot
            CompanionPortrait(
                mode: mode,
                energy: snapshot.energy(at: entry.date)?.value,
                need: snapshot.need(at: entry.date),
                needSince: snapshot.needSince(at: entry.date),
                traces: snapshot.traces(at: entry.date),
                vitals: snapshot.vitals ?? HakuVitals(),
                date: entry.date,
                bedtime: payload.bedtime.state(at: entry.date),
                wardrobe: payload.wardrobe,
                framing: .head
            )
        } else {
            Image(systemName: "circle.dashed")
        }
    }
}
