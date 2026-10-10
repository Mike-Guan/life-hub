import HubCore
import SwiftUI

// Used by scripts/check-card-shots.sh to draw the memory page for UI 审核. Debug builds only.
// Every record is made up and kept in memory.
/// The memory page for `ScreenshotMode.persona`, with four weeks of made-up records or none.
struct ScreenshotMemory: View {
    let filled: Bool
    @State private var store = ModeStore(fileURL: nil, deviceID: "screenshot")
    @State private var energy = EnergyStore(fileURL: nil, deviceID: "screenshot")
    @State private var ledger = CanLedger()

    var body: some View {
        MemoryView(
            persona: ScreenshotMode.persona,
            store: store,
            energy: energy,
            ledger: ledger,
            places: filled ? Self.places : [],
            decisionLogURL: nil
        )
        .onAppear {
            guard filled else { return }
            // Gym on Tuesdays and Thursdays, the identity card on Saturdays, one 5 km run.
            var wins: [(Win, Date)] = [(.run5k, Self.daysAgo(20))]
            wins += Self.days(weekday: 3).map { (Win.gym, $0) }
            wins += Self.days(weekday: 5).map { (Win.gym, $0) }
            wins += Self.days(weekday: 7).map { (Win.boxing, $0) }
            let persona = ScreenshotMode.persona
            ledger = CanLedger(
                entries: wins.map { win, date in
                    CanEntry.earned(win, source: "\(date)", at: date, persona: persona, deviceID: "screenshot")
                }
            )
            // Arrivals at the office on Mondays and at the identity card's place on Saturdays.
            var arrivals: [(Mode, Date)] = Self.days(weekday: 2).map { (Mode.work, $0) }
            arrivals += Self.days(weekday: 7).map { (Mode.boxing, $0) }
            for (mode, date) in arrivals.sorted(by: { $0.1 < $1.1 }) {
                store.switchTo(mode, source: .location, at: date)
                store.switchTo(.chill, source: .location, at: date.addingTimeInterval(3 * 3600))
            }
        }
    }

    private static let places = [
        HubPlace(kind: .office, latitude: 0, longitude: 0),
        HubPlace(kind: .gym, latitude: 0, longitude: 0),
    ]

    /// The last four days before today that fall on `weekday` (1 is Sunday), at 18:00.
    private static func days(weekday: Int) -> [Date] {
        (1...28).map(daysAgo).filter { Calendar.current.component(.weekday, from: $0) == weekday }
    }

    private static func daysAgo(_ count: Int) -> Date {
        let day = Calendar.current.date(byAdding: .day, value: -count, to: .now) ?? .now
        return Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: day) ?? day
    }
}
