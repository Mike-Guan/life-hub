import AppIntents
import CompanionKit
import HubCore
import SwiftUI
import WidgetKit

/// Four buttons that switch mode without opening the app.
struct ModeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "mode", provider: HubProvider()) { entry in
            ModeButtons(current: entry.mode, persona: entry.persona, cards: entry.names)
                .containerBackground(Toy.paper, for: .widget)
                .environment(\.locale, Languages.locale)
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
                .environment(\.locale, Languages.locale)
        }
        .configurationDisplayName("今天电量")
        .description("觉得和睡眠算的不一样时，点一下自己选。")
        .supportedFamilies([.systemSmall])
    }
}

private struct ModeButtons: View {
    let current: Mode?
    let persona: Persona
    let cards: ModeCards

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                button(.work)
                button(.chill)
            }
            // Without an identity card, 副业 takes the whole row instead of leaving a gap.
            GridRow {
                if cards.modes.contains(.boxing) {
                    button(.boxing)
                    button(.money)
                } else {
                    button(.money).gridCellColumns(2)
                }
            }
        }
    }

    private func button(_ mode: Mode) -> some View {
        Button(intent: SwitchModeIntent(mode: mode)) {
            Label(
                cards.title(for: mode, persona: persona),
                systemImage: cards.pickedIdentity(for: mode, persona: persona)?.symbol ?? mode.symbol(for: persona)
            )
            .font(Toy.body(14, weight: .heavy))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(ToyButtonStyle(fill: mode.color(for: persona), isSelected: mode == current))
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

/// A Lock Screen, Control Center or Action button control that starts the walk to the gym.
struct GoToGymControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "goToGym") {
            ControlWidgetButton(action: GoToGymIntent()) {
                Label("出发去健身", systemImage: "figure.strengthtraining.traditional")
            }
        }
        .displayName("出发去健身")
        .description("背着包陪你走过去。")
    }
}

/// A Control Center, Lock Screen or Action button control that switches to the picked card and back.
struct CardControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: "modeCard", provider: CardControlProvider()) { value in
            ControlWidgetToggle(value.title, isOn: value.isOn, action: CardToggleIntent(card: value.card)) { isOn in
                Label(isOn ? "在这张卡" : "点一下切过去", systemImage: value.symbol)
            }
        }
        .displayName("模式卡")
        .description("点一下切到副业或身份卡，再点一下切回去。")
    }
}

/// The card a `CardControl` switches, picked when the control is added.
struct CardControlConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "模式卡"

    @Parameter(title: "模式卡", default: .money) var card: ControlCard
}

/// What a `CardControl` shows: the card's own name and symbol, on while in its mode.
struct CardControlValue: Sendable {
    var card: ControlCard
    var isOn: Bool
    var title: String
    var symbol: String
}

struct CardControlProvider: AppIntentControlValueProvider {
    func previewValue(configuration: CardControlConfiguration) -> CardControlValue {
        value(for: configuration.card, current: nil)
    }

    func currentValue(configuration: CardControlConfiguration) async throws -> CardControlValue {
        let snapshot = AppGroup.container.snapshotURL.flatMap(WidgetSnapshot.read(from:))
        return value(for: configuration.card, current: snapshot?.mode)
    }

    private func value(for card: ControlCard, current: Mode?) -> CardControlValue {
        let persona = Persona.stored(in: AppGroup.defaults)
        let cards = ModeCards.current(in: AppGroup.defaults, persona: persona)
        let mode = card.mode
        return CardControlValue(
            card: card,
            isOn: current == mode,
            title: cards.title(for: mode, persona: persona),
            symbol: cards.pickedIdentity(for: mode, persona: persona)?.symbol ?? mode.symbol(for: persona)
        )
    }
}
