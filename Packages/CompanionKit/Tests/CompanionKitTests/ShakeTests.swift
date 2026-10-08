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

    /// Feeds `detector` `seconds` of samples at `rate` per second from `start`, with `magnitude` at each time.
    private func feed(
        _ detector: inout ShakeDetector, from start: TimeInterval, seconds: Double, rate: Double = 51,
        magnitude: (TimeInterval) -> Double
    ) -> [TimeInterval] {
        (0..<Int(seconds * rate)).compactMap { index in
            let time = start + Double(index) / rate
            return detector.add(magnitude: magnitude(time), at: time) ? time : nil
        }
    }

    @Test func aRoundOfShakingIsOneShake() {
        var detector = ShakeDetector()
        // Like a real shake on the watch: 7 to 12 g for a 2.5 s round, never dropping in between.
        let shakes = feed(&detector, from: 10, seconds: 2.5) { 7 + 5 * abs(sin($0 * 20)) }
        #expect(shakes.count == 1)
        #expect(shakes.first.map { $0 - 10 < 0.3 } == true)
    }

    @Test func shakingAgainAfterTheCooldownCountsAgain() {
        var detector = ShakeDetector()
        let first = feed(&detector, from: 10, seconds: 0.5) { _ in 8 }
        let second = feed(&detector, from: 12.5, seconds: 0.5) { _ in 8 }
        #expect(first.count == 1 && second.count == 1)
    }

    @Test func theSlowerRateWorksToo() {
        var detector = ShakeDetector()
        let shakes = feed(&detector, from: 20, seconds: 0.5, rate: 17) { _ in 8 }
        #expect(shakes.count == 1)
    }

    @Test func aKnockIsNotAShake() {
        var detector = ShakeDetector()
        // Shaking once and stopping: under 0.2 s above the threshold.
        let shakes = feed(&detector, from: 5, seconds: 1) { $0 < 5.12 ? 8 : 0.2 }
        #expect(shakes.isEmpty)
    }

    @Test func everydayMovesAreNotShakes() {
        var detector = ShakeDetector()
        // Raising the wrist, typing: measured at 0.8 g at most.
        let shakes = feed(&detector, from: 0, seconds: 30) { 0.8 * abs(sin($0 * 3)) }
        #expect(shakes.isEmpty)
    }

    @Test func aLightFlickIsOneShake() {
        var detector = ShakeDetector()
        // Like the lightest real flick: three short flicks a second peaking at 2.6 g, with about 40% of the samples
        // above the threshold, for a 2.5 s round.
        let shakes = feed(&detector, from: 10, seconds: 2.5) { 0.8 + 1.8 * pow(sin($0 * 3 * .pi), 2) }
        #expect(shakes.count == 1)
    }

    @Test func armSwingBelowTheThresholdIsNotAShake() {
        var detector = ShakeDetector()
        // Three swings a second, each a 0.15 s peak of 1.8 g, for 10 s.
        let shakes = feed(&detector, from: 0, seconds: 10) { time in
            time.truncatingRemainder(dividingBy: 1.0 / 3) < 0.15 ? 1.8 : 0.5
        }
        #expect(shakes.isEmpty)
    }

    @Test func walkingIsNotAShake() {
        var detector = ShakeDetector()
        // Swinging arms while walking: under 1 g, two steps a second, for 10 s.
        let shakes = feed(&detector, from: 0, seconds: 10) { 0.9 * abs(sin($0 * 2 * .pi)) }
        #expect(shakes.isEmpty)
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
