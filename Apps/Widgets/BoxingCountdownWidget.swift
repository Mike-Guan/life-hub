import ActivityKit
import CompanionKit
import HubCore
import SwiftUI
import WidgetKit

// Lock Screen surfaces keep the system font in every language (Japanese font plan C), so no Toy fonts here.
/// The Sunday boxing countdown on the Lock Screen and in the Dynamic Island.
struct BoxingCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BoxingActivityAttributes.self) { context in
            HStack(spacing: 12) {
                head(context.attributes).frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(context.attributes.title ?? "拳击") \(context.state.start, style: .time) 开始")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    countdown(to: context.state.start, started: context.isStale)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                }
                Spacer()
            }
            .padding()
            // The tint is always light coral, so the text stays ink even when the system is dark.
            .foregroundStyle(Toy.ink)
            .activityBackgroundTint(Mode.boxing.color(for: context.attributes.persona ?? .haku))
            .activitySystemActionForegroundColor(Toy.ink)
            .environment(\.locale, Languages.locale)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    head(context.attributes).frame(width: 44, height: 44)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(to: context.state.start, started: context.isStale)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.attributes.title ?? "拳击") \(context.state.start, style: .time) 开始")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .environment(\.locale, Languages.locale)
                }
            } compactLeading: {
                head(context.attributes)
            } compactTrailing: {
                countdown(to: context.state.start, started: context.isStale).frame(maxWidth: 52)
            } minimal: {
                head(context.attributes)
            }
        }
    }

    /// The character who started the countdown, in the identity card's look.
    @ViewBuilder private func head(_ attributes: BoxingActivityAttributes) -> some View {
        if attributes.persona == .kuro {
            KuroPortrait(look: KuroLook(mode: .boxing, card: attributes.card), framing: .head)
        } else {
            CompanionPortrait(mode: .boxing, card: attributes.card, need: .boxingWarmup, framing: .head)
        }
    }

    // The activity goes stale at class start (its staleDate), so the timer gives way to a word
    // instead of sitting at 0:00 until the app ends it. A timer range must not end before it starts.
    @ViewBuilder
    private func countdown(to start: Date, started: Bool) -> some View {
        if started {
            Text("已开始")
        } else {
            Text(timerInterval: min(Date.now, start)...start, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
    }
}
