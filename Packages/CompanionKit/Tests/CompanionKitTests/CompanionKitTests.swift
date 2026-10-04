import Foundation
import HubCore
import Testing

@testable import CompanionKit

@Suite struct CompanionKitTests {
    @Test(arguments: RunnerPart.allCases)
    func everyPartHasArt(_ part: RunnerPart) {
        #expect(!RunnerArt.inks(part).isEmpty || RunnerArt.text(part) != nil)
    }

    @Test(arguments: RunnerPart.allCases)
    func cachedInksMatchTheGeneratedArt(_ part: RunnerPart) {
        #expect(RunnerArt.cachedInks(part).count == RunnerArt.inks(part).count)
    }

    @Test(arguments: Mode.allCases)
    func everyModeShowsTheBaseParts(_ mode: Mode) {
        let parts = Set(RunnerFigure.parts(for: mode, pose: RunnerPose()))
        #expect(RunnerFigure.baseParts.isSubset(of: parts))
    }

    @Test(arguments: Mode.allCases)
    func visiblePartsKeepDrawingOrder(_ mode: Mode) {
        let parts = RunnerFigure.parts(for: mode, pose: RunnerPose())
        let order = parts.compactMap { RunnerPart.allCases.firstIndex(of: $0) }
        #expect(order == order.sorted())
    }

    @Test func ledDotsReplaceTheLedLine() {
        var pose = RunnerPose()
        #expect(RunnerFigure.parts(for: .work, pose: pose).contains(.ledLine))
        pose.ledDots = true
        #expect(!RunnerFigure.parts(for: .work, pose: pose).contains(.ledLine))
    }

    @Test func lowEnergyAddsEyeBags() {
        #expect(!RunnerFigure.parts(for: .money, pose: RunnerPose()).contains(.eyebags))
        #expect(RunnerFigure.parts(for: .money, pose: RunnerPose(face: .low)).contains(.eyebags))
    }

    @Test func energyPicksTheFace() {
        #expect(EnergyFace(energy: 10) == .low)
        #expect(EnergyFace(energy: 30) == .mid)
        #expect(EnergyFace(energy: 69) == .mid)
        #expect(EnergyFace(energy: 70) == .high)
        #expect(EnergyFace(energy: nil) == .mid)
        #expect(EnergyFace.low.speed < EnergyFace.mid.speed)
        #expect(EnergyFace.high.speed > EnergyFace.mid.speed)
    }

    @Test(arguments: Mode.allCases)
    func highEnergyAddsSparkles(_ mode: Mode) {
        let mid = Set(RunnerFigure.parts(for: mode, pose: RunnerPose()))
        let high = Set(RunnerFigure.parts(for: mode, pose: RunnerPose(face: .high)))
        #expect(mid.isDisjoint(with: [.sparkle, .eyeGlint]))
        #expect(high.contains(.sparkle))
        // Chill's eyes are closed in a smile, so there is nothing to glint.
        #expect(high.contains(.eyeGlint) == (mode != .chill))
    }

    @Test(arguments: Mode.allCases)
    func boxingWarmupPutsTheGlovesOn(_ mode: Mode) {
        let parts = Set(RunnerFigure.parts(for: mode, pose: RunnerPose(need: .boxingWarmup)))
        #expect(parts.isSuperset(of: [.headband, .gloveL, .gloveR]))
        #expect(!parts.contains(.monsterCan))
        #expect(RunnerFigure.baseParts.isSubset(of: parts))
    }

    @Test func warmupLooksAtTheDoorNowAndThen() {
        let glances = (0..<80).map {
            RunnerPose(mode: .chill, time: Double($0) * 0.05, face: .mid, need: .boxingWarmup, react: 0).eyesDx
        }
        #expect(glances.contains { $0 < -1 })
        #expect(glances.contains(0))
        #expect(glances.allSatisfy { (-3...0).contains($0) })
        #expect(RunnerPose(mode: .chill, time: 3.3, face: .mid, react: 0).eyesDx == 0)
    }

    @Test func bedtimeTakesTheGlovesOff() {
        var pose = RunnerPose.bedtimeStill()
        pose.need = .boxingWarmup
        let parts = Set(RunnerFigure.parts(for: .chill, pose: pose))
        #expect(parts.isDisjoint(with: [.gloveL, .gloveR, .headband]))
        #expect(parts.contains(.monsterCan))
    }

    @Test func warmupHasItsOwnLinesAndLabel() {
        #expect(CompanionLines.lines(for: .chill, need: .boxingWarmup) != CompanionLines.lines(for: .chill))
        #expect(CompanionLines.accessibilityLabel(mode: .chill, need: .boxingWarmup, bedtime: .off).contains("热身"))
        #expect(CompanionLines.accessibilityLabel(mode: .chill, need: .boxingWarmup, bedtime: .on) == "HAKU，困了")
    }

    @Test(arguments: Mode.allCases)
    func couchScrollHoldsThePhone(_ mode: Mode) {
        let parts = Set(RunnerFigure.parts(for: mode, pose: RunnerPose(need: .couchScroll)))
        #expect(parts.isSuperset(of: [.phone, .phoneFeed, .phoneHand, .eyesSleepy]))
        #expect(parts.isDisjoint(with: [.eyesWork, .eyesChill, .cateyeL, .eyesMoney, .mouthSmile, .monsterCan]))
        #expect(RunnerFigure.baseParts.isSubset(of: parts))
        let high = Set(RunnerFigure.parts(for: mode, pose: RunnerPose(face: .high, need: .couchScroll)))
        #expect(!high.contains(.eyeGlint))
    }

    @Test func couchFeedFlicksAndStaysInRange() {
        let feeds = (0..<100).map {
            RunnerPose(mode: .chill, time: Double($0) * 0.05, face: .mid, need: .couchScroll, react: 0).feed
        }
        #expect(feeds.allSatisfy { (0...1).contains($0) })
        #expect(feeds.contains(0) && feeds.contains(1))
        let still = RunnerPose(need: .couchScroll)
        #expect(still.headDy == 3 && still.eyesDy == 1.5)
    }

    @Test func bedtimePutsThePhoneDown() {
        var pose = RunnerPose.bedtimeStill()
        pose.need = .couchScroll
        let parts = Set(RunnerFigure.parts(for: .chill, pose: pose))
        #expect(parts.isDisjoint(with: [.phone, .phoneFeed, .phoneHand]))
    }

    @Test func slumpedMotionLeansBack() {
        let motion = IdleMotion.slumped(time: 1)
        #expect(motion.angle < 0)
        #expect((3...5).contains(motion.dy))
        #expect(CompanionLines.accessibilityLabel(mode: .chill, need: .couchScroll, bedtime: .off).contains("手机"))
    }

    @Test func eachCelebrationPlaysOnce() {
        #expect(CompanionView.newCelebration(.celebrate(id: "run-1"), last: "") == "run-1")
        #expect(CompanionView.newCelebration(.celebrate(id: "run-1"), last: "run-1") == nil)
        #expect(CompanionView.newCelebration(.celebrate(id: "box-2"), last: "run-1") == "box-2")
        #expect(CompanionView.newCelebration(nil, last: "") == nil)
    }

    @Test func celebrationBurstsSparklesButNotAtBedtime() {
        var pose = RunnerPose()
        pose.burst = 0.5
        #expect(RunnerFigure.parts(for: .chill, pose: pose).contains(.sparkle))
        var sleepy = RunnerPose.bedtimeStill()
        sleepy.burst = 0.5
        #expect(!RunnerFigure.parts(for: .chill, pose: sleepy).contains(.sparkle))
    }

    @Test func celebrationHopsAndLands() {
        let hops = (0..<20).map { IdleMotion.celebrating(progress: Double($0) / 20) }
        #expect(hops.allSatisfy { $0.dy <= 0 && $0.dy >= -22 && abs($0.angle) <= 3 })
        #expect(hops.contains { $0.dy < -15 })
        #expect(abs(IdleMotion.celebrating(progress: 0).dy) < 0.01)
    }

    @Test func bedtimeHidesTheHighEnergyLook() {
        var pose = RunnerPose.bedtimeStill()
        pose.face = .high
        let parts = Set(RunnerFigure.parts(for: .work, pose: pose))
        #expect(parts.isDisjoint(with: [.sparkle, .eyeGlint]))
    }

    @Test(arguments: Mode.allCases)
    func posesStayInRange(_ mode: Mode) {
        for step in 0..<200 {
            for react in [0.0, 0.5, 1.0] {
                let time = Double(step) * 0.05
                let face: EnergyFace = [.low, .mid, .high][step % 3]
                let pose = RunnerPose(mode: mode, time: time, face: face, react: react)
                #expect((0...1).contains(pose.blink))
                #expect((0...1).contains(pose.ledOpacity))
                #expect(abs(pose.headDy) <= 2)
                #expect(abs(pose.canAngle) <= 60)
                #expect(abs(pose.gloveR.width) <= 14)
                #expect(pose.glint <= 1)
                #expect((0...1).contains(pose.sparkle))
            }
        }
    }

    @Test(arguments: Mode.allCases)
    func bedtimeSwapsTheAwakeFace(_ mode: Mode) {
        let parts = Set(RunnerFigure.parts(for: mode, pose: RunnerPose.bedtimeStill()))
        #expect(parts.isSuperset(of: [.eyesSleepy, .maskDown, .zzz]))
        #expect(parts.isDisjoint(with: [.maskUp, .ledLine, .ledYen, .eyesWork, .cateyeL, .mouthSmile, .headset]))
        #expect(RunnerFigure.baseParts.isSubset(of: parts))
    }

    @Test func headsetComesOffDuringGoodnight() {
        let start = RunnerPose.bedtime(time: 0, goodnight: 0.1, liesDown: true)
        let end = RunnerPose.bedtime(time: 0, goodnight: 1, liesDown: true)
        #expect(RunnerFigure.parts(for: .work, pose: start).contains(.headset))
        #expect(!RunnerFigure.parts(for: .work, pose: end).contains(.headset))
    }

    @Test func onlyTheHomeVersionLiesDown() {
        let home = RunnerPose.bedtime(time: 0, goodnight: 1, liesDown: true)
        let notification = RunnerPose.bedtime(time: 0, goodnight: 1, liesDown: false)
        #expect(home.lie == 1)
        #expect(RunnerFigure.parts(for: .chill, pose: home).contains(.pillow))
        #expect(notification.lie == 0)
        #expect(!RunnerFigure.parts(for: .chill, pose: notification).contains(.pillow))
    }

    @Test func sleepyLoopYawns() {
        let yawns = (0..<120).map { RunnerPose.bedtime(time: Double($0) * 0.05, goodnight: 1, liesDown: true).yawn }
        #expect(yawns.contains { $0 > 0.5 })
        #expect(yawns.contains { $0 == 0 })
    }

    @Test func bedtimePosesStayInRange() {
        for step in 0..<200 {
            let time = Double(step) * 0.05
            let pose = RunnerPose.bedtime(time: time, goodnight: Double(step) / 150, liesDown: true)
            #expect((0...1).contains(pose.headsetOff))
            #expect((0...1).contains(pose.yawn))
            #expect((0...1).contains(pose.stretch))
            #expect((0...1).contains(pose.lie))
            #expect(pose.zzz == -1 || (0...1).contains(pose.zzz))
            #expect((0.1...1).contains(pose.blink))
        }
    }

    @Test func goodnightPlaysOncePerNight() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        #expect(!CompanionView.playedTonight(last: 0, now: now))
        #expect(CompanionView.playedTonight(last: 1_000_000 - 3600, now: now))
        #expect(!CompanionView.playedTonight(last: 1_000_000 - 13 * 3600, now: now))
    }

    @Test func headBoxFitsInsideTheFigure() {
        #expect(RunnerArt.bounds.contains(RunnerFigure.headBox))
    }

    @Test func riveValuesMatchTheRunnerViewModel() {
        #expect(Mode.allCases.map(\.riveValue) == ["work", "chill", "box", "money"])
    }

    @Test(arguments: Mode.allCases)
    func idleMotionStaysSmall(_ mode: Mode) {
        for step in 0..<200 {
            let motion = IdleMotion(mode: mode, time: Double(step) * 0.05)
            #expect(abs(motion.dy) <= 8)
            #expect(abs(motion.angle) <= 3)
        }
    }

    @Test func everyModeHasLines() {
        for mode in Mode.allCases {
            #expect(!CompanionLines.lines(for: mode).isEmpty)
        }
        #expect(!CompanionLines.lines(for: nil).isEmpty)
    }
}
