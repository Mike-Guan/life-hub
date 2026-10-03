import CompanionKit
import HubCore
import SwiftUI
import WidgetKit

/// Four buttons that switch mode without opening the app.
struct ModeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "mode", provider: HubProvider()) { entry in
            ModeButtons(current: entry.mode)
                .containerBackground(Toy.paper, for: .widget)
        }
        .configurationDisplayName("切换模式")
        .description("点一下切到别的模式。")
        .supportedFamilies([.systemMedium])
    }
}

/// Three buttons for how Mike feels today.
struct EnergyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "energy", provider: HubProvider()) { entry in
            EnergyButtons(current: entry.energy)
                .containerBackground(Toy.paper, for: .widget)
        }
        .configurationDisplayName("今天电量")
        .description("觉得和睡眠算的不一样时，点一下自己选。")
        .supportedFamilies([.systemSmall])
    }
}

private struct ModeButtons: View {
    let current: Mode?

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                button(.work)
                button(.chill)
            }
            GridRow {
                button(.boxing)
                button(.money)
            }
        }
    }

    private func button(_ mode: Mode) -> some View {
        Button(intent: SwitchModeIntent(mode: mode)) {
            Label(mode.title, systemImage: mode.symbol)
                .font(Toy.body(14, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(ToyButtonStyle(fill: mode.color, isSelected: mode == current))
    }
}

private struct EnergyButtons: View {
    let current: EnergyLevel?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今天电量")
                .font(Toy.display(14))
                .foregroundStyle(Toy.ink)
            ForEach(EnergyLevel.allCases, id: \.self) { level in
                Button(intent: ReportEnergyIntent(level: level)) {
                    Text(level.title)
                        .font(Toy.body(13, weight: .heavy))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(ToyButtonStyle(fill: Toy.pink, isSelected: level == current))
            }
        }
    }
}
