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
        let shake1 = detector.add(magnitude: 2.5, at: 10)
        #expect(!shake1)
        // Samples of the same jolt are too close together.
        let shake2 = detector.add(magnitude: 2.5, at: 10.03)
        #expect(!shake2)
        let shake3 = detector.add(magnitude: 2.4, at: 10.3)
        #expect(shake3)
        // Cooling down after a shake.
        let shake4 = detector.add(magnitude: 3, at: 10.6)
        #expect(!shake4)
        let shake5 = detector.add(magnitude: 3, at: 10.9)
        #expect(!shake5)
    }

    @Test func aQuickBackAndForthIsAShake() {
        var detector = ShakeDetector()
        // Two jolts of three samples each at 50 Hz, the second starting 0.12 s after the first.
        let samples: [TimeInterval] = [20, 20.02, 20.04, 20.12, 20.14]
        let shakes = samples.map { detector.add(magnitude: 1.6, at: $0) }
        #expect(shakes == [false, false, false, true, false])
    }

    @Test func gentleOrSlowMovesAreNotShakes() {
        var detector = ShakeDetector()
        let shake6 = detector.add(magnitude: 1.2, at: 1)
        #expect(!shake6)
        let shake7 = detector.add(magnitude: 1.2, at: 1.3)
        #expect(!shake7)
        let shake8 = detector.add(magnitude: 2.5, at: 5)
        #expect(!shake8)
        let shake9 = detector.add(magnitude: 2.5, at: 6)
        #expect(!shake9)
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
