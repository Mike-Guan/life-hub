import HubCore
import SwiftUI

// Used by scripts/screenshots.sh to draw the memory page for UI 审核. Debug builds only.
// Every record is made up; the judgements go to a temporary file, the rest stays in memory.
/// The memory page for `ScreenshotMode.persona`, with four weeks of made-up records or none.
struct ScreenshotMemory: View {
    let filled: Bool
    @State private var store: ModeStore
    @State private var energy = EnergyStore(fileURL: nil, deviceID: "screenshot")
    @State private var ledger: CanLedger

    init(filled: Bool) {
        self.filled = filled
        _store = State(initialValue: filled ? Self.store() : ModeStore(fileURL: nil, deviceID: "screenshot"))
        _ledger = State(initialValue: filled ? Self.ledger() : CanLedger())
    }

    var body: some View {
        MemoryView(
            persona: ScreenshotMode.persona,
            store: store,
            energy: energy,
            ledger: ledger,
            places: filled ? Self.places : [],
            decisionLogURL: filled ? Self.decisionLogURL : nil,
            ask: ScreenshotMode.ask
        )
    }

    private static let places = [
        HubPlace(kind: .office, latitude: 0, longitude: 0),
        HubPlace(kind: .gym, latitude: 0, longitude: 0),
    ]

    /// Gym on Tuesdays and Thursdays, the identity card on Saturdays, one 5 km run.
    private static func ledger() -> CanLedger {
        var wins: [(Win, Date)] = [(.run5k, daysAgo(20))]
        wins += days(weekday: 3).map { (Win.gym, $0) }
        wins += days(weekday: 5).map { (Win.gym, $0) }
        wins += days(weekday: 7).map { (Win.boxing, $0) }
        let persona = ScreenshotMode.persona
        return CanLedger(
            entries: wins.map { win, date in
                CanEntry.earned(win, source: "\(date)", at: date, persona: persona, deviceID: "screenshot")
            }
        )
    }

    /// Arrivals at the office on Mondays and at the identity card's place on Saturdays.
    private static func store() -> ModeStore {
        let store = ModeStore(fileURL: nil, deviceID: "screenshot")
        var arrivals: [(Mode, Date)] = days(weekday: 2).map { (Mode.work, $0) }
        arrivals += days(weekday: 7).map { (Mode.boxing, $0) }
        for (mode, date) in arrivals.sorted(by: { $0.1 < $1.1 }) {
            store.switchTo(mode, source: .location, at: date)
            store.switchTo(.chill, source: .location, at: date.addingTimeInterval(3 * 3600))
        }
        return store
    }

    /// 40 judgements over four weeks, 3 of them corrected.
    private static let decisionLogURL: URL? = {
        let url = FileManager.default.temporaryDirectory.appending(path: "screenshot-decisions.json")
        try? FileManager.default.removeItem(at: url)
        let error = DecisionLog.update(at: url) { log in
            for index in 0..<40 {
                var decision = Decision(
                    kind: .invite,
                    action: Decision.noAction,
                    at: daysAgo(index % 28 + 1),
                    deviceID: "screenshot"
                )
                if index < 3 { decision.feedback = .corrected }
                log.append(decision)
            }
            return true
        }
        return error == nil ? url : nil
    }()

    /// The last four days before today that fall on `weekday` (1 is Sunday), at 18:00.
    private static func days(weekday: Int) -> [Date] {
        (1...28).map(daysAgo).filter { Calendar.current.component(.weekday, from: $0) == weekday }
    }

    private static func daysAgo(_ count: Int) -> Date {
        let day = Calendar.current.date(byAdding: .day, value: -count, to: .now) ?? .now
        return Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: day) ?? day
    }
}
