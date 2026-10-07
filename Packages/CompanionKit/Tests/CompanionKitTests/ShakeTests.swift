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

    @Test func twoJoltsMakeOneShake() {
        var detector = ShakeDetector()
        #expect(!detector.add(magnitude: 2.5, at: 10))
        // Samples of the same jolt are too close together.
        #expect(!detector.add(magnitude: 2.5, at: 10.03))
        #expect(detector.add(magnitude: 2.4, at: 10.3))
        // Cooling down after a shake.
        #expect(!detector.add(magnitude: 3, at: 10.6))
        #expect(!detector.add(magnitude: 3, at: 10.9))
    }

    @Test func gentleOrSlowMovesAreNotShakes() {
        var detector = ShakeDetector()
        #expect(!detector.add(magnitude: 1.2, at: 1))
        #expect(!detector.add(magnitude: 1.2, at: 1.3))
        #expect(!detector.add(magnitude: 2.5, at: 5))
        #expect(!detector.add(magnitude: 2.5, at: 6))
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
