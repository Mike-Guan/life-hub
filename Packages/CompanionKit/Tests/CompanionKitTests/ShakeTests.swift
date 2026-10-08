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

    /// Feeds `detector` a jolt (three samples above the threshold) followed by a dip, starting at `time`.
    private func jolt(_ detector: inout ShakeDetector, at time: TimeInterval, peak: Double = 2.2) -> Bool {
        var fired = false
        for (offset, magnitude) in [(0.0, peak), (0.033, peak), (0.066, 0.3)] {
            let shake = detector.add(magnitude: magnitude, at: time + offset)
            fired = fired || shake
        }
        return fired
    }

    @Test func threeJoltsInARowMakeOneShake() {
        var detector = ShakeDetector()
        // A real shake: jolts 0.1 s apart, each a few samples long.
        let first = jolt(&detector, at: 10)
        #expect(!first)
        let second = jolt(&detector, at: 10.1)
        #expect(!second)
        let third = jolt(&detector, at: 10.2)
        #expect(third)
        // Still shaking: cooling down, so it stays one shake.
        let fourth = jolt(&detector, at: 10.3)
        #expect(!fourth)
        let fifth = jolt(&detector, at: 10.4)
        #expect(!fifth)
    }

    @Test func shakingAgainAfterTheCooldownCountsAgain() {
        var detector = ShakeDetector()
        let first = [10, 10.1, 10.2].map { jolt(&detector, at: $0) }
        #expect(first == [false, false, true])
        let second = [12, 12.1, 12.2].map { jolt(&detector, at: $0) }
        #expect(second == [false, false, true])
    }

    @Test func oneLongJoltIsNotAShake() {
        var detector = ShakeDetector()
        // Held above the threshold without a dip: one jolt, however long.
        let samples = stride(from: 5.0, to: 6.0, by: 0.033).map { detector.add(magnitude: 2.5, at: $0) }
        #expect(!samples.contains(true))
    }

    @Test func gentleOrSlowMovesAreNotShakes() {
        var detector = ShakeDetector()
        // Too gentle.
        let gentle = [1, 1.1, 1.2, 1.3].map { jolt(&detector, at: $0, peak: 1.2) }
        #expect(!gentle.contains(true))
        // Hard enough but too far apart, like setting the phone down twice.
        let slow = [5, 5.7, 6.4, 7.1].map { jolt(&detector, at: $0) }
        #expect(!slow.contains(true))
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
