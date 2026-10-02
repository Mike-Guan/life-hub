import CompanionKit
import HubCore
import SwiftUI

struct HomeView: View {
    @Environment(ModeStore.self) private var store
    @State private var cheer = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Header(mode: store.current, error: store.lastError)

                CompanionView(mode: store.current, cheer: cheer)
                    .frame(height: 340)
                    .toyCard()

                if let mode = store.current {
                    Text(mode.tagline)
                        .font(Toy.body(16, weight: .bold))
                        .foregroundStyle(Toy.ink)
                }

                ModeSwitcher(current: store.current) { mode in
                    switchTo(mode)
                }

                TimelineView(.periodic(from: .now, by: 60)) { context in
                    TodayTimeline(segments: store.segments(on: context.date, now: context.date))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Toy.paper.ignoresSafeArea())
        .modeSwitchHaptic(trigger: store.current)
    }

    private func switchTo(_ mode: Mode) {
        let changed = withAnimation(.easeInOut(duration: 0.2)) {
            store.switchTo(mode)
        }
        // Boxing day gets a pep jump on entry.
        if changed, mode == .boxing { cheer += 1 }
    }
}

extension View {
    /// A tap on iPhone when the mode changes; nothing on Mac.
    @ViewBuilder func modeSwitchHaptic(trigger: Mode?) -> some View {
        #if os(iOS)
        sensoryFeedback(.impact(weight: .medium), trigger: trigger)
        #else
        self
        #endif
    }
}

private struct Header: View {
    let mode: Mode?
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(greeting)
                    .font(Toy.display(26))
                    .foregroundStyle(Toy.ink)
                Spacer()
                if let error {
                    Circle()
                        .fill(Toy.alert)
                        .overlay(Circle().stroke(Toy.ink, lineWidth: 2))
                        .frame(width: 14, height: 14)
                        .help(error)
                        .accessibilityLabel(error)
                }
            }
            Text(subtitle)
                .font(Toy.body(13, weight: .bold))
                .foregroundStyle(Toy.muted)
            if let error {
                Text(error)
                    .font(Toy.body(12))
                    .foregroundStyle(Toy.alert)
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "GOOD MORNING, MIKE"
        case 12..<18: return "GOOD AFTERNOON, MIKE"
        default: return "GOOD EVENING, MIKE"
        }
    }

    private var subtitle: String {
        let date = Date.now.formatted(.dateTime.month().day().weekday(.wide))
        return "\(date) · \(mode?.code ?? "NO MODE") MODE"
    }
}

#Preview {
    HomeView().environment(ModeStore.preview())
}
