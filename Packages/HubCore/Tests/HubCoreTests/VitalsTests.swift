import Foundation
import Testing

@testable import HubCore

@Suite struct VitalsTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    func date(_ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour)) ?? .distantPast
    }

    func ledger(_ wins: (Win, Date)...) -> CanLedger {
        CanLedger(entries: wins.enumerated().map { index, win in
            CanEntry.earned(win.0, source: "s\(index)", at: win.1, deviceID: "t")
        })
    }

    func nights(_ nights: (Int, Int)...) -> EnergyLog {
        EnergyLog(events: nights.map { EnergyEvent.sleep(minutes: $0.1, endedAt: date($0.0, 7), deviceID: "t") })
    }

    @Test func staminaRisesWithAWeekOfTrainingAndFallsSlowly() {
        let now = date(31)
        #expect(VitalsEngine.stamina(ledger: CanLedger(), now: now, calendar: calendar) == .low)
        // Two sessions on one day count once.
        let oneDay = ledger((.boxing, date(30, 10)), (.gym, date(30, 19)))
        #expect(VitalsEngine.stamina(ledger: oneDay, now: now, calendar: calendar) == .low)
        let twoDays = ledger((.boxing, date(30)), (.run5k, date(28)))
        #expect(VitalsEngine.stamina(ledger: twoDays, now: now, calendar: calendar) == .mid)
        let week = ledger((.boxing, date(30)), (.gym, date(29)), (.gym, date(27)))
        #expect(VitalsEngine.stamina(ledger: week, now: now, calendar: calendar) == .high)
        // The same week three weeks later still counts half: mid, not back to the floor.
        let later = date(31).addingTimeInterval(14 * 86_400)
        #expect(VitalsEngine.stamina(ledger: week, now: later, calendar: calendar) == .mid)
        // Other wins, such as sleeping on time, aren't training.
        let other = ledger((.earlySleep, date(30)), (.daylight, date(29)), (.gotUp, date(28)))
        #expect(VitalsEngine.stamina(ledger: other, now: now, calendar: calendar) == .low)
    }

    @Test func spiritTakesTheBetterOfLastNightAndThreeNights() {
        func spirit(_ log: EnergyLog, at now: Date) -> VitalBand {
            VitalsEngine.spirit(energy: log, ledger: CanLedger(), now: now, calendar: calendar)
        }
        let now = date(10)
        #expect(spirit(EnergyLog(), at: now) == .mid)
        #expect(spirit(nights((8, 300), (9, 320), (10, 340)), at: now) == .low)
        // One good night lifts it at once.
        #expect(spirit(nights((8, 300), (9, 320), (10, 480)), at: now) == .high)
        // One short night after good ones doesn't drop it to the floor.
        #expect(spirit(nights((8, 480), (9, 480), (10, 300)), at: now) == .mid)
        // Nights older than three days don't count.
        #expect(spirit(nights((5, 480), (10, 300)), at: now) == .low)
    }

    @Test func daylightLiftsSpiritOneStep() {
        let short = nights((10, 300))
        let sunny = ledger((.daylight, date(10, 13)))
        #expect(VitalsEngine.spirit(energy: short, ledger: sunny, now: date(10, 18), calendar: calendar) == .mid)
        let okay = nights((10, 400))
        #expect(VitalsEngine.spirit(energy: okay, ledger: sunny, now: date(10, 18), calendar: calendar) == .high)
        let yesterday = ledger((.daylight, date(9, 13)))
        #expect(VitalsEngine.spirit(energy: short, ledger: yesterday, now: date(10, 18), calendar: calendar) == .low)
    }

    @Test func bandsAreOrdered() {
        #expect(VitalBand.low < .mid && VitalBand.mid < .high)
        #expect(HakuVitals() == HakuVitals(stamina: .mid, spirit: .mid))
    }
}
