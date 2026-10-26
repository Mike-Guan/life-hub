import CompanionKit
import HubCore
import SwiftUI
import WidgetKit

@main
struct LifeHubWatchWidgets: WidgetBundle {
    init() {
        // Like the watch app, the complications follow the watch's system language.
        Languages.load(from: .standard)
    }

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
                .environment(\.locale, Languages.locale)
        }
        .configurationDisplayName("Life Hub")
        .description("角色现在在干什么。")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular])
    }
}

struct WatchStatusView: View {
    let entry: WatchEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        content.containerBackground(.clear, for: .widget)
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCorner:
            if let title {
                head.widgetLabel(title)
            } else {
                head.widgetLabel(placeholder)
            }
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
        if let title, let since = entry.payload?.snapshot.since {
            Text("\(title) · \(Text(since, style: .relative))")
        } else if let title {
            Text(title)
        } else {
            Text(placeholder)
        }
    }

    // UI 二组 预览 6: once the iPhone has sent, there is nothing to open; the mode just isn't set yet.
    /// What shows instead of the mode: nothing received yet, or no mode yet.
    private var placeholder: LocalizedStringKey {
        entry.payload == nil ? "打开 iPhone" : "还没有模式"
    }

    private var title: String? {
        guard let payload = entry.payload, let mode = entry.mode else { return nil }
        return payload.title(for: mode)
    }

    // A tinted face keeps only each pixel's alpha, so the filled figure would read as one flat blob.
    // There the outlines become the opaque part and light fills fade, like a line drawing in the face's tint.
    /// The character's head, in colour on full-colour faces and as tinted line art on the others.
    @ViewBuilder private var head: some View {
        if entry.payload == nil || entry.mode == nil {
            Image(systemName: "circle.dashed")
        } else if renderingMode == .fullColor {
            portrait
        } else {
            portrait
                .colorInvert()
                .luminanceToAlpha()
                .widgetAccentable()
        }
    }

    @ViewBuilder private var portrait: some View {
        if let payload = entry.payload, let mode = entry.mode, payload.persona == .kuro {
            KuroPortrait(
                look: KuroLook(mode: mode, card: payload.card(for: mode)),
                energy: payload.snapshot.energy(at: entry.date)?.value,
                bedtime: payload.bedtime.state(at: entry.date),
                moment: payload.scene(at: entry.date)?.moment,
                wearing: payload.wardrobe.worn(in: mode),
                framing: .head,
                lineArt: renderingMode != .fullColor
            )
        } else if let payload = entry.payload, let mode = entry.mode {
            let snapshot = payload.snapshot
            // The same scene the watch app plays, like the iPhone Lock Screen (PM 动作展示总表 C9).
            let scene = payload.scene(at: entry.date)
            CompanionPortrait(
                mode: mode,
                card: payload.card(for: mode),
                energy: snapshot.energy(at: entry.date)?.value,
                need: snapshot.need(at: entry.date),
                needSince: snapshot.needSince(at: entry.date),
                activity: scene?.activity,
                moment: scene?.moment,
                traces: snapshot.traces(at: entry.date),
                vitals: snapshot.vitals ?? HakuVitals(),
                date: entry.date,
                bedtime: payload.bedtime.state(at: entry.date),
                wardrobe: payload.wardrobe,
                daily: scene?.daily,
                walking: scene?.walking,
                bath: scene?.bath ?? false,
                framing: .head
            )
        } else {
            Image(systemName: "circle.dashed")
        }
    }
}
