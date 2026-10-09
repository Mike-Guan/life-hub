import Foundation
import HubCore
import Testing

@testable import CompanionKit

@Suite struct IdleClockTests {
    /// The first time from 0 s (on a 0.01 s grid) at which a pool beat of `kind` starts.
    static func firstStart(
        kind: Int = 0,
        lengths: [TimeInterval],
        every: TimeInterval = 14,
        spread: TimeInterval = 3,
        seed: UInt64 = RunnerPose.seed
    ) -> TimeInterval? {
        (0..<60_000).lazy.map { Double($0) * 0.01 }.first { t in
            let beat = IdleClock.beat(at: t, every: every, spread: spread, lengths: lengths, seed: seed)
            return beat.map { $0.kind == kind && $0.phase < 0.01 } ?? false
        }
    }

    /// Blinks over ten minutes from `start`: when each one shuts, and whether it is the second of a pair.
    private static func blinks(from start: TimeInterval, seed: UInt64) -> [(time: TimeInterval, double: Bool)] {
        var found: [(time: TimeInterval, double: Bool)] = []
        var open = true
        for step in 0..<60_000 {
            let t = start + Double(step) * 0.01
            let shut = IdleClock.blink(at: t, seed: seed) < 0.5
            if shut, open {
                let double = found.last.map { t - $0.time < 0.5 } ?? false
                found.append((t, double))
            }
            open = !shut
        }
        return found
    }

    // HAKU-20 (UI 审核 2026-10-08): acceptance is 2.5-6 s between blinks and about 15% doubles.
    @Test(arguments: [RunnerPose.seed, 0x4B55, 7], [0.0, 810_000_000])
    func blinksLandTwoAndAHalfToSixSecondsApartWithSomeDoubles(_ seed: UInt64, _ start: TimeInterval) {
        let all = Self.blinks(from: start, seed: seed)
        let singles = all.filter { !$0.double }.map(\.time)
        let gaps = zip(singles, singles.dropFirst()).map { $1 - $0 }
        #expect(gaps.allSatisfy { (2.45...6.05).contains($0) })
        #expect(Set(gaps.map { ($0 * 2).rounded() }).count > 5)
        let doubles = Double(all.count - singles.count) / Double(singles.count)
        #expect((0.08...0.25).contains(doubles))
    }

    @Test func aBlinkShutsAndReopens() {
        let values = (0..<1_000).map { IdleClock.blink(at: Double($0) * 0.01, seed: RunnerPose.seed) }
        #expect(values.allSatisfy { (0.1...1).contains($0) })
        #expect(values.contains { $0 < 0.2 } && values.contains(1))
    }

    @Test func poolBeatsLandEightToTwentySecondsApart() {
        var starts: [TimeInterval] = []
        var last: IdleClock.Beat?
        for step in 0..<12_000 {
            let t = Double(step) * 0.05
            let beat = IdleClock.beat(at: t, lengths: RunnerPose.workBeats, seed: RunnerPose.seed)
            if let beat, last == nil { starts.append(t - beat.phase) }
            last = beat
        }
        let gaps = zip(starts, starts.dropFirst()).map { $1 - $0 }
        #expect(gaps.count > 35)
        #expect(gaps.allSatisfy { (8...20).contains($0) })
        let pool = RunnerPose.workBeats
        let kinds = Set(starts.compactMap { IdleClock.beat(at: $0 + 0.01, lengths: pool, seed: RunnerPose.seed)?.kind })
        #expect(kinds == [0, 1])
    }

    @Test func nodsEaseAndNowAndThenHoldABeat() {
        let beats = (0..<1_200).map { n in
            (0..<10).map { IdleClock.nod(at: Double(n) * 0.5 + Double($0) * 0.05, period: 0.5, seed: RunnerPose.seed) }
        }
        #expect(beats.allSatisfy { $0[0] == 0 && $0.allSatisfy { (0...1.2).contains($0) } })
        let held = Double(beats.filter { $0.allSatisfy { $0 == 0 } }.count) / Double(beats.count)
        #expect((0.08...0.18).contains(held))
        #expect(IdleClock.dip(0.35) == 1 && IdleClock.dip(0) == 0 && IdleClock.dip(1) == 0)
    }

    // Head leads, body follows 0.1 s later.
    @Test func atWorkTheBodyFollowsTheHeadsNod() {
        let head = RunnerPose(mode: .work, time: 5, face: .mid, react: 0).headDy / 1.5
        let body = IdleMotion(mode: .work, time: 5.1).dy / 3
        #expect(abs(head - body) < 0.0001)
    }

    // HAKU-21: closed smiling eyes squeeze on the blink, and slacking or packing up still breathes.
    @Test func smilingEyesBlinkAndStillMomentsBreathe() throws {
        let t = try #require(stride(from: 0.0, to: 10, by: 0.01).first { RunnerPose.blink(at: $0) < 0.2 })
        #expect(RunnerPose(mode: .chill, time: t, face: .mid, react: 0).squeeze < 0.2)
        for moment in [CompanionMoment.slacking, .packingUp] {
            let dys = (0..<40).map { IdleMotion(moment: moment, mode: .work, time: Double($0) * 0.1).dy }
            #expect(dys.max()! - dys.min()! > 2)
        }
    }
}
