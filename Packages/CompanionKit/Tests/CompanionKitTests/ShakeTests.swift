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

    @Test func threeJoltsMakeOneShake() {
        var detector = ShakeDetector()
        // Samples of the same jolt are close together; the third jolt completes the shake, then it cools down.
        let samples: [(Double, TimeInterval)] = [
            (2.5, 10), (2.5, 10.03), (2.4, 10.3), (2.6, 10.55), (3, 10.8), (3, 11.2),
        ]
        let shakes = samples.map { detector.add(magnitude: $0.0, at: $0.1) }
        #expect(shakes == [false, false, false, true, false, false])
    }

    @Test func aQuickBackAndForthIsAShake() {
        var detector = ShakeDetector()
        // Jolts of two or three samples at 50 Hz, a new one every 0.12 s.
        let samples: [TimeInterval] = [20, 20.02, 20.04, 20.12, 20.14, 20.24, 20.26]
        let shakes = samples.map { detector.add(magnitude: 1.6, at: $0) }
        #expect(shakes == [false, false, false, false, false, true, false])
    }

    @Test func gentleOrSlowMovesAreNotShakes() {
        var detector = ShakeDetector()
        let gentle = [1, 1.3, 1.6].map { detector.add(magnitude: 1.2, at: $0) }
        #expect(gentle == [false, false, false])
        let slow = [5, 6, 7, 8].map { detector.add(magnitude: 2.5, at: $0) }
        #expect(slow == [false, false, false, false])
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
        // The push forward, then the stop at the end of the reach.
        let samples: [(Double, TimeInterval)] = [(3, 30), (3.2, 30.02), (2.8, 30.04), (2.5, 30.16), (2.2, 30.18)]
        let shakes = samples.map { detector.add(magnitude: $0.0, at: $0.1) }
        #expect(!shakes.contains(true))
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
