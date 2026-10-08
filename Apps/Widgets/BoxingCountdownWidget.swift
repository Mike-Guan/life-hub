import ActivityKit
import CompanionKit
import HubCore
import SwiftUI
import WidgetKit

/// The Sunday boxing countdown on the Lock Screen and in the Dynamic Island.
struct BoxingCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BoxingActivityAttributes.self) { context in
            HStack(spacing: 12) {
                head.frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("拳击 \(context.state.start, style: .time) 开始").font(Toy.body(14, weight: .bold))
                    countdown(to: context.state.start, started: context.isStale).font(Toy.display(28))
                }
                Spacer()
            }
            .padding()
            // The tint is always light coral, so the text stays ink even when the system is dark.
            .foregroundStyle(Toy.ink)
            .activityBackgroundTint(Mode.boxing.color)  // HAKU only: KURO has no countdown.
            .activitySystemActionForegroundColor(Toy.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    head.frame(width: 44, height: 44)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(to: context.state.start, started: context.isStale).font(Toy.display(22))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("拳套戴好了，\(context.state.start, style: .time) 开始").font(Toy.body(13, weight: .bold))
                }
            } compactLeading: {
                head
            } compactTrailing: {
                countdown(to: context.state.start, started: context.isStale).frame(maxWidth: 52)
            } minimal: {
                head
            }
        }
    }

    private var head: some View {
        CompanionPortrait(mode: .boxing, need: .boxingWarmup, framing: .head)
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
