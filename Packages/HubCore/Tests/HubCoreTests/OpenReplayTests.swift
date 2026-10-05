import Foundation
import Testing

@testable import HubCore

@Suite struct OpenReplayTests {
    let now = Date(timeIntervalSince1970: 1_790_000_000)

    func log(_ changes: (Mode, ModeChange.Source, TimeInterval)...) -> ModeLog {
        let records = changes.map { mode, source, offset in
            ModeChange(mode: mode, source: source, at: now.addingTimeInterval(offset), deviceID: "t")
        }
        return ModeLog(changes: records)
    }

    @Test func aSwitchWhileAwayReplaysWithinTheWindow() {
        let left = log((.work, .location, -8 * 3600), (.chill, .location, -3600))
        #expect(OpenReplay.switchFrom(log: left, lastSeen: now.addingTimeInterval(-2 * 3600), now: now) == .work)
        // Seen after the switch, or the switch is older than the window.
        #expect(OpenReplay.switchFrom(log: left, lastSeen: now.addingTimeInterval(-1800), now: now) == nil)
        let old = log((.work, .location, -8 * 3600), (.chill, .location, -4 * 3600))
        #expect(OpenReplay.switchFrom(log: old, lastSeen: now.addingTimeInterval(-6 * 3600), now: now) == nil)
        #expect(OpenReplay.switchFrom(log: left, lastSeen: nil, now: now) == nil)
    }

    @Test func aManualSwitchIsNotReplayed() {
        let manual = log((.work, .location, -8 * 3600), (.chill, .manual, -3600))
        #expect(OpenReplay.switchFrom(log: manual, lastSeen: now.addingTimeInterval(-2 * 3600), now: now) == nil)
    }

    @Test func aMissedOffWorkNoticePlaysOnlyOutsideWork() {
        let shown = now.addingTimeInterval(-3600)
        #expect(OpenReplay.offWork(deliveredAt: shown, mode: .chill, now: now))
        #expect(!OpenReplay.offWork(deliveredAt: shown, mode: .work, now: now))
        #expect(!OpenReplay.offWork(deliveredAt: now.addingTimeInterval(-4 * 3600), mode: .chill, now: now))
        #expect(!OpenReplay.offWork(deliveredAt: nil, mode: .chill, now: now))
    }
}
