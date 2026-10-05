import CompanionKit
import HubCore
import SwiftUI
import WidgetKit

/// RUNNER with the current mode and today's energy, for the Lock Screen and Home Screen.
struct StatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "status", provider: HubProvider()) { entry in
            StatusView(entry: entry)
        }
        .configurationDisplayName("HAKU")
        .description("现在的模式和今天的电量。")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular, .systemSmall])
    }
}

struct StatusView: View {
    let entry: HubEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if family == .systemSmall {
                    entry.mode?.color ?? Toy.paper
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                head.padding(4)
            }
        case .accessoryInline:
            if let mode = entry.mode {
                Label("\(mode.title) · \(entry.detail)", systemImage: mode.symbol)
            } else {
                Text("打开一次 Life Hub")
            }
        case .accessoryRectangular:
            HStack(spacing: 6) {
                head.frame(width: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.mode?.title ?? "还没有模式").font(.headline)
                    Text(entry.mode == nil ? "打开一次 Life Hub" : entry.detail).font(.caption).lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        default:
            small
        }
    }

    @ViewBuilder private var head: some View {
        if let mode = entry.mode {
            CompanionPortrait(
                mode: mode,
                energy: entry.energy?.value,
                need: entry.need,
                needSince: entry.needSince,
                activity: entry.activity,
                moment: entry.moment,
                traces: entry.traces,
                vitals: entry.vitals,
                date: entry.date,
                bedtime: entry.bedtime,
                wardrobe: entry.wardrobe,
                framing: .head
            )
        } else {
            Image(systemName: "circle.dashed").font(.title2)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let mode = entry.mode {
                CompanionPortrait(
                    mode: mode,
                    energy: entry.energy?.value,
                    need: entry.need,
                    needSince: entry.needSince,
                    activity: entry.activity,
                    moment: entry.moment,
                    traces: entry.traces,
                    vitals: entry.vitals,
                    date: entry.date,
                    bedtime: entry.bedtime,
                    wardrobe: entry.wardrobe
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text("\(mode.code) MODE").font(Toy.display(14))
                Text(entry.detail).font(Toy.body(12, weight: .bold))
            } else {
                Spacer()
                Text("NO MODE").font(Toy.display(14))
                Text("打开一次 Life Hub").font(Toy.body(12, weight: .bold))
            }
        }
        .foregroundStyle(Toy.ink)
    }
}
