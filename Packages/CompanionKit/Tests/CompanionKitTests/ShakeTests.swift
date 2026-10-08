import Foundation
import HubCore
import Testing

@testable import CompanionKit

@Suite struct ShakeTests {
    @Test func boxingGetsPumpedAndSleepWakes() {
        #expect(ShakeReaction.pick(mode: .work, asleep: false) == .dizzy)
        #expect(ShakeReaction.pick(mode: .chill, asleep: false) == .dizzy)
        #expect(ShakeReaction.pick(mode: .money, asleep: false) == .dizzy)
        #expect(ShakeReaction.pick(mode: .boxing, asleep: false) == .pumped)
        #expect(ShakeReaction.pick(mode: .boxing, asleep: true) == .woken)
    }

    @Test func linesFollowTheMode() {
        #expect(ShakeReaction.dizzy.line(for: .work) == "……喂喂喂。")
        #expect(ShakeReaction.dizzy.line(for: .chill) == "……别晃了。我要吐了。")
        #expect(ShakeReaction.pumped.line(for: .boxing) == "再来！")
        #expect(ShakeReaction.woken.line(for: .chill) == nil)
    }

    @Test func threeShakesInAMinuteAreTooMany() {
        let now = Date(timeIntervalSinceReferenceDate: 1000)
        let two = [now.addingTimeInterval(-10), now]
        #expect(!ShakeReaction.isTooMany(two, now: now))
        #expect(ShakeReaction.isTooMany([now.addingTimeInterval(-50)] + two, now: now))
        #expect(!ShakeReaction.isTooMany([now.addingTimeInterval(-ShakeReaction.window)] + two, now: now))
    }

    /// Feeds `detector` one jolt sampled at `rate` per second: `strong` samples at `peak`, then one dip.
    private func jolt(
        _ detector: inout ShakeDetector, at time: TimeInterval, rate: Double = 50, strong: Int = 2, peak: Double = 2.2
    ) -> Bool {
        var fired = false
        for index in 0...strong {
            let shake = detector.add(magnitude: index < strong ? peak : 0.3, at: time + Double(index) / rate)
            fired = fired || shake
        }
        return fired
    }

    @Test func threeJoltsMakeOneShake() {
        var detector = ShakeDetector()
        let shakes = [10, 10.12, 10.24, 10.36, 10.48].map { jolt(&detector, at: $0) }
        // The third jolt completes the shake; still shaking during the cooldown stays one shake.
        #expect(shakes == [false, false, true, false, false])
    }

    @Test func theWatchRateIsEnough() {
        var detector = ShakeDetector()
        // The watch gives about 17 samples a second, so a jolt is one or two of them.
        let shakes = [20, 20.18, 20.36].map { jolt(&detector, at: $0, rate: 17, strong: 1) }
        #expect(shakes == [false, false, true])
    }

    @Test func shakingAgainAfterTheCooldownCountsAgain() {
        var detector = ShakeDetector()
        let first = [10, 10.12, 10.24].map { jolt(&detector, at: $0) }
        #expect(first == [false, false, true])
        let second = [12, 12.12, 12.24].map { jolt(&detector, at: $0) }
        #expect(second == [false, false, true])
    }

    @Test func oneLongJoltIsNotAShake() {
        var detector = ShakeDetector()
        // Held above the threshold without a dip, at the watch's rate and at the phone's: one jolt.
        let watch = stride(from: 5.0, to: 6.0, by: 1.0 / 17).map { detector.add(magnitude: 2.5, at: $0) }
        let phone = stride(from: 8.0, to: 9.0, by: 1.0 / 50).map { detector.add(magnitude: 2.5, at: $0) }
        #expect(!watch.contains(true) && !phone.contains(true))
    }

    @Test func gentleOrSlowMovesAreNotShakes() {
        var detector = ShakeDetector()
        let gentle = [1, 1.12, 1.24, 1.36].map { jolt(&detector, at: $0, peak: 1.2) }
        #expect(!gentle.contains(true))
        // Hard enough but too far apart, like setting the phone down a few times.
        let slow = [5, 5.7, 6.4, 7.1].map { jolt(&detector, at: $0) }
        #expect(!slow.contains(true))
    }

    @Test func walkingIsNotAShake() {
        var detector = ShakeDetector()
        // Swinging arms while walking: under 1 g, two steps a second, sampled at 50 Hz for 10 s.
        let shakes = (0..<500).map { index -> Bool in
            let time = Double(index) / 50
            return detector.add(magnitude: 0.9 * abs(sin(time * 2 * .pi)), at: time)
        }
        #expect(!shakes.contains(true))
    }

    @Test func onePunchIsNotAShake() {
        var detector = ShakeDetector()
        // The push forward, then the stop at the end of the reach, at the phone's and the watch's rate.
        let phone = jolt(&detector, at: 30, strong: 3, peak: 3) || jolt(&detector, at: 30.16, peak: 2.5)
        let watch = jolt(&detector, at: 40, rate: 17, peak: 3) || jolt(&detector, at: 40.18, rate: 17, peak: 2.5)
        #expect(!phone && !watch)
    }

    @Test @MainActor func dizzyShowsSwirlEyesAndStars() {
        var pose = RunnerPose(mode: .work, time: 0, face: .mid, react: 0)
        pose.dizzy(progress: 0.3)
        let parts = Set(RunnerFigure.parts(for: .work, pose: pose))
        #expect(parts.isSuperset(of: [.eyeSwirlL, .eyeSwirlR, .dizzyStar]))
        #expect(!parts.contains(.eyesWork))
        let calm = Set(RunnerFigure.parts(for: .work, pose: RunnerPose(mode: .work, time: 0, face: .mid, react: 0)))
        #expect(!calm.contains(.dizzyStar))
    }
}
