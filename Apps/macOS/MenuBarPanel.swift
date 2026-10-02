import CompanionKit
import HubCore
import SwiftUI

/// Menu bar popover: a small RUNNER and the four mode buttons.
struct MenuBarPanel: View {
    @Environment(ModeStore.self) private var store
    @State private var cheer = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(store.current.map { "\($0.code) MODE" } ?? "NO MODE")
                    .font(Toy.display(15))
                Spacer()
                if let since = store.currentSince {
                    Text(since, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                        .font(Toy.body(12, weight: .bold).monospacedDigit())
                        .foregroundStyle(Toy.muted)
                }
            }
            .foregroundStyle(Toy.ink)

            CompanionView(mode: store.current, cheer: cheer, showsBubble: false)
                .frame(height: 170)
                .toyCard(shadow: 4)

            ModeSwitcher(current: store.current, compact: true) { mode in
                let changed = withAnimation(.easeInOut(duration: 0.2)) { store.switchTo(mode) }
                if changed, mode == .boxing { cheer += 1 }
            }

            if let error = store.lastError {
                Text(error)
                    .font(Toy.body(11))
                    .foregroundStyle(Toy.alert)
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(Toy.paper)
    }
}
