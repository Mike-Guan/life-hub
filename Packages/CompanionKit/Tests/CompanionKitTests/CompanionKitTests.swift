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
        #expect(CompanionView.newCelebration(.celebrate(id: "run-1", kind: .running), last: "") == "run-1")
        #expect(CompanionView.newCelebration(.celebrate(id: "run-1", kind: .running), last: "run-1") == nil)
        #expect(CompanionView.newCelebration(.celebrate(id: "box-2", kind: .boxing), last: "run-1") == "box-2")
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

    @Test func offWorkPlaysOncePerDay() {
        #expect(CompanionView.newOffWork(.offWork(id: "2026-10-05"), last: "") == "2026-10-05")
        #expect(CompanionView.newOffWork(.offWork(id: "2026-10-05"), last: "2026-10-05") == nil)
        #expect(CompanionView.newOffWork(.celebrate(id: "run-1", kind: .running), last: "") == nil)
        #expect(CompanionView.newCelebration(.offWork(id: "2026-10-05"), last: "") == nil)
    }

    @Test(arguments: Mode.allCases)
    func offWorkGoesFromHeadsetToMonster(_ mode: Mode) {
        let start = Set(RunnerFigure.parts(for: mode, pose: RunnerPose.offWork(time: 0, progress: 0, face: .mid)))
        #expect(start.isSuperset(of: [.headset, .maskUp, .eyesWork]))
        #expect(!start.contains(.monsterCan))
        let end = Set(RunnerFigure.parts(for: mode, pose: RunnerPose.offWork(time: 0, progress: 0.99, face: .mid)))
        #expect(end.isSuperset(of: [.maskDown, .eyesChill, .monsterCan]))
        #expect(end.isDisjoint(with: [.headset, .maskUp, .eyesWork, .ledLine]))
        #expect(RunnerFigure.baseParts.isSubset(of: end))
    }

    @Test func offWorkPoseStaysInRange() {
        for step in 0...100 {
            let pose = RunnerPose.offWork(time: Double(step) * 0.04, progress: Double(step) / 100, face: .mid)
            #expect((0...1).contains(pose.headsetOff))
            #expect((0...1).contains(pose.maskDrop))
            #expect((0...1).contains(pose.stretch))
            #expect((0...1).contains(pose.canOpacity))
            #expect((0.1...1).contains(pose.blink))
        }
        let stretching = RunnerPose.offWork(time: 0, progress: 0.45, face: .mid)
        #expect(stretching.stretch > 0.9 && stretching.maskDrop == 1 && stretching.headsetOff == 1)
    }

    @Test func stayHomePlaysOncePerDay() {
        #expect(CompanionView.newStayHome(.stayHome(id: "2026-10-05"), last: "") == "2026-10-05")
        #expect(CompanionView.newStayHome(.stayHome(id: "2026-10-05"), last: "2026-10-05") == nil)
        #expect(CompanionView.newStayHome(.offWork(id: "2026-10-05"), last: "") == nil)
        #expect(CompanionView.newOffWork(.stayHome(id: "2026-10-05"), last: "") == nil)
    }

    @Test(arguments: Mode.allCases)
    func stayHomeGoesFromDoorToSofa(_ mode: Mode) {
        let start = Set(RunnerFigure.parts(for: mode, pose: RunnerPose.stayHome(time: 0, progress: 0, face: .mid)))
        #expect(start.isSuperset(of: [.door, .watchWrist, .headset, .maskUp, .eyesWork]))
        #expect(!start.contains(.sofaArm))
        let end = Set(RunnerFigure.parts(for: mode, pose: RunnerPose.stayHome(time: 0, progress: 0.99, face: .mid)))
        #expect(end.isSuperset(of: [.sofaArm, .maskDown, .eyesSleepy]))
        #expect(end.isDisjoint(with: [.door, .watchWrist, .headset, .maskUp, .eyesWork, .ledLine]))
        #expect(RunnerFigure.baseParts.isSubset(of: end))
    }

    @Test func stayHomePoseStaysInRange() {
        for step in 0...100 {
            let pose = RunnerPose.stayHome(time: Double(step) * 0.04, progress: Double(step) / 100, face: .mid)
            #expect((0...1).contains(pose.headsetOff))
            #expect((0...1).contains(pose.maskDrop))
            #expect((-0.5...0).contains(pose.stretch))
            #expect((0.1...1).contains(pose.blink))
        }
    }

    @Test func lastingTracesFollowTheirProps() {
        let all: Set<CompanionTrace> = [.wornGloves, .deskMonitor, .runningShoes]
        let boxing = Set(RunnerFigure.parts(for: .boxing, pose: RunnerPose().leaving(all)))
        #expect(boxing.isSuperset(of: [.gloveTapeLeft, .gloveTapeRight]))
        #expect(boxing.isDisjoint(with: [.deskMonitor, .runningShoes]))
        let coding = Set(RunnerFigure.parts(for: .money, pose: RunnerPose(moment: .vibeCoding).leaving(all)))
        #expect(coding.contains(.deskMonitor))
        #expect(coding.isDisjoint(with: [.gloveTapeLeft, .runningShoes]))
        let home = Set(RunnerFigure.parts(for: .chill, pose: RunnerPose().leaving(all)))
        #expect(home.contains(.runningShoes))
        #expect(home.isDisjoint(with: [.gloveTapeLeft, .deskMonitor]))
        let plain = Set(RunnerFigure.parts(for: .boxing, pose: RunnerPose()))
        #expect(plain.isDisjoint(with: [.gloveTapeLeft, .gloveTapeRight]))
    }

    @Test func eyesDriftNowAndThenAndComeBack() {
        #expect(RunnerPose.drift(at: 5) == 0)
        #expect(RunnerPose.drift(at: 9.7) > 2.9)
        #expect(RunnerPose.drift(at: 13 + 9.7) < -2.9)
        #expect(RunnerPose.drift(at: 11) == 0)
        let plain = RunnerPose(mode: .work, time: 9.7, face: .mid, react: 0)
        #expect(plain.eyesDx > 2.9)
        let peeking = RunnerPose(mode: .work, time: 9.7, face: .mid, moment: .slacking, react: 0)
        #expect(peeking.eyesDx != plain.eyesDx)
    }

    @Test func noticeTurnsToYouHalfABeatLate() {
        var start = RunnerPose()
        start.notice(progress: 0.3)
        #expect(start.eyesDx == 3 && start.headDy == 0)
        var turning = RunnerPose()
        turning.notice(progress: 0.75)
        #expect(turning.eyesDx == 0 && turning.headDy < 0)
        var done = RunnerPose()
        done.notice(progress: 1)
        #expect(done.eyesDx == 0 && done.headDy == 0)
    }

    @Test func boxingHakuShakesOutAndFixesTheHeadband() {
        // Cycle 1 of 10 s starts at 10 s; the fidget runs from 16 s to 19.5 s.
        let shaking = RunnerPose(mode: .boxing, time: 16.5, face: .mid, react: 0)
        #expect(shaking.gloveL.height == 8 && shaking.gloveR.height == 8)
        let fixing = RunnerPose(mode: .boxing, time: 18.5, face: .mid, react: 0)
        #expect(fixing.gloveR.height < -69 && fixing.gloveL == .zero)
        let guarding = RunnerPose(mode: .boxing, time: 28.5, face: .mid, react: 0)
        #expect(guarding.gloveR.height > -4)
        let jab = RunnerPose(mode: .boxing, time: 18.5, face: .mid, react: 0.5)
        #expect(jab.gloveR.height > -69)
    }

    @Test func atWorkHakuSneaksALookAtThePhone() {
        // Cycle 3 of 12 s starts at 36 s; the glance runs from 40.3 s to 41.5 s.
        let glance = RunnerPose(mode: .work, time: 41, face: .mid, react: 0)
        #expect(glance.phoneGlance && glance.eyesDy == 2)
        let parts = Set(RunnerFigure.parts(for: .work, pose: glance))
        #expect(parts.isSuperset(of: [.phone, .phoneHand]) && !parts.contains(.phoneFeed))
        let after = RunnerPose(mode: .work, time: 42, face: .mid, react: 0)
        #expect(!after.phoneGlance && !RunnerFigure.parts(for: .work, pose: after).contains(.phone))
        #expect(!RunnerPose(mode: .work, time: 5, face: .mid, react: 0).phoneGlance)
        #expect(!RunnerPose(mode: .work, time: 41, face: .mid, moment: .drowsy, react: 0).phoneGlance)
    }

    @Test func atWorkHakuPausesAndPushesTheHeadset() {
        // Cycle 2 of 12 s starts at 24 s; the pause runs from 32 s to 35 s.
        let nod = RunnerPose(mode: .work, time: 32.25, face: .mid, react: 0)
        #expect(nod.headDy > 2.4)
        let still = RunnerPose(mode: .work, time: 33.5, face: .mid, react: 0)
        #expect(still.headDy == 0 && still.headsetOff == 0)
        let push = RunnerPose(mode: .work, time: 34.5, face: .mid, react: 0)
        #expect(push.headsetOff > 0.09 && push.headsetOff < 1)
        #expect(RunnerFigure.parts(for: .work, pose: push) == RunnerFigure.parts(for: .work, pose: still))
        let otherCycle = RunnerPose(mode: .work, time: 22.5, face: .mid, react: 0)
        #expect(otherCycle.headsetOff == 0)
        let slacking = RunnerPose(mode: .work, time: 34.5, face: .mid, moment: .slacking, react: 0)
        #expect(slacking.headsetOff == 0)
    }

    @Test func afterMidnightHakuSaysItOnceANight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let late = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 0, minute: 40)))
        #expect(CompanionView.newLateNight(at: late, last: "", calendar: calendar) == "2026-10-05")
        #expect(CompanionView.newLateNight(at: late, last: "2026-10-05", calendar: calendar) == nil)
        let evening = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 23, minute: 50))
        )
        #expect(CompanionView.newLateNight(at: evening, last: "", calendar: calendar) == nil)
        let morning = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 5)))
        #expect(CompanionView.newLateNight(at: morning, last: "", calendar: calendar) == nil)
    }

    @Test func caughtSnackingHakuWhistles() {
        var hiding = RunnerPose(mode: .chill, time: 3, face: .mid, life: .snack, react: 0)
        hiding.whistle(progress: 0.1)
        #expect(hiding.propHidden == 0 && hiding.eyesDx == 0 && hiding.whistle < 0)
        #expect(!RunnerFigure.parts(for: .chill, pose: hiding).contains(.musicNote))
        var whistling = RunnerPose(mode: .chill, time: 3, face: .mid, life: .drawing, react: 0)
        whistling.whistle(progress: 0.65)
        #expect(whistling.propHidden == 1 && whistling.eyesDx == 3)
        #expect(abs(whistling.whistle - 0.5) < 0.001)
        #expect(RunnerFigure.parts(for: .chill, pose: whistling).contains(.musicNote))
    }

    @Test func stiffHakuTwistsThenThumpsItsBack() {
        let still = Set(RunnerFigure.parts(for: .work, pose: RunnerPose(moment: .stiff)))
        #expect(still.isSuperset(of: [.backFist, .thumpLines, .eyesWork]))
        let twisting = RunnerPose(mode: .work, time: 0.4, face: .mid, moment: .stiff, react: 0)
        #expect(twisting.thump < 0 && !twisting.thumpHit && abs(twisting.headTilt + 3) < 0.001)
        #expect(!RunnerFigure.parts(for: .work, pose: twisting).contains(.backFist))
        let thumping = RunnerPose(mode: .work, time: 1.9, face: .mid, moment: .stiff, react: 0)
        #expect(thumping.thump > 0.99 && thumping.thumpHit && thumping.blink <= 0.4)
        #expect(abs(RunnerPose.stiffSway(at: 0.4).angle - 4) < 0.001)
        #expect(RunnerPose.stiffSway(at: 1.9).angle == 0 && RunnerPose.stiffSway(at: 1.9).dy > 1.49)
    }

    @Test func openingOnAStiffHakuStretches() {
        var arms = RunnerPose(mode: .work, time: 1.9, face: .mid, moment: .stiff, react: 0)
        arms.stretchUp(progress: 2.0 / 6)
        #expect(arms.armsUp == 1 && arms.eyesShut && arms.thump < 0 && arms.headTilt == 0)
        let parts = Set(RunnerFigure.parts(for: .work, pose: arms))
        #expect(parts.contains(.eyesClosed) && !parts.contains(.eyesWork) && !parts.contains(.backFist))
        var look = RunnerPose(mode: .work, time: 1.9, face: .mid, moment: .stiff, react: 0)
        look.stretchUp(progress: 3.6 / 6)
        #expect(look.armsUp == 0 && !look.eyesShut && look.blink == 1)
        let now = Date(timeIntervalSinceReferenceDate: 100_000)
        #expect(CompanionView.stretchUpDue(last: 0, now: now))
        #expect(!CompanionView.stretchUpDue(last: 100_000 - 29 * 60, now: now))
    }

    @Test func standingUpLetsHakuRollItsShoulders() {
        let rolling = RunnerPose.limber(time: 0, progress: 0.2, face: .mid)
        #expect(rolling.eyesShut && rolling.stretch > 0)
        #expect(RunnerFigure.parts(for: .work, pose: rolling).contains(.eyesClosed))
        let done = RunnerPose.limber(time: 0, progress: 0.9, face: .mid)
        #expect(!done.eyesShut && done.shift == 0 && done.blink <= 0.7)
        #expect(CompanionView.newStretched(.stretched(id: "10"), last: "") == "10")
        #expect(CompanionView.newStretched(.stretched(id: "10"), last: "10") == nil)
        #expect(CompanionView.newStretched(.stayHome(id: "10"), last: "") == nil)
    }

    @Test func hakuPacksUpBeforeTheEndOfWork() {
        let still = Set(RunnerFigure.parts(for: .work, pose: RunnerPose(moment: .packingUp)))
        #expect(still.isSuperset(of: [.laptopClosed, .gymBag, .watchWrist, .tapHand, .desk]))
        #expect(!still.contains(.headset) && !still.contains(.laptop))
        var closing = RunnerPose(mode: .work, time: 0, face: .mid, moment: .packingUp, react: 0)
        closing.packUp(elapsed: 1.5)
        let closingParts = Set(RunnerFigure.parts(for: .work, pose: closing))
        #expect(closing.lidClose > 0 && closing.lidClose < 1 && closingParts.contains(.laptop))
        #expect(closingParts.contains(.headset) && !closingParts.contains(.gymBag))
        var wiping = RunnerPose(mode: .work, time: 0, face: .mid, moment: .packingUp, react: 0)
        wiping.packUp(elapsed: 3)
        let wipingParts = Set(RunnerFigure.parts(for: .work, pose: wiping))
        #expect(wipingParts.isSuperset(of: [.cloth, .laptopClosed]) && !wipingParts.contains(.watchWrist))
        var bagging = RunnerPose(mode: .work, time: 0, face: .mid, moment: .packingUp, react: 0)
        bagging.packUp(elapsed: 5.5)
        #expect(bagging.headsetOff == 1 && bagging.bagLift > 0 && bagging.bagLift < 1)
        let now = Date(timeIntervalSinceReferenceDate: 100_000)
        #expect(CompanionView.packUpDue(last: 0, now: now))
        #expect(!CompanionView.packUpDue(last: 100_000 - 19 * 60, now: now))
    }

    @Test @MainActor func hakuHoldsUpThePlannedTasksProp() {
        var tapping = RunnerPose(mode: .work, time: 0, face: .mid, react: 0)
        tapping.cue(DailyCue(stage: .soon, prop: .note, id: "a"), time: 1, slap: nil)
        let tappingParts = Set(RunnerFigure.parts(for: .work, pose: tapping))
        #expect(tapping.watchTap && tapping.propRaise == 0)
        #expect(tappingParts.isSuperset(of: [.watchWrist, .tapHand]) && !tappingParts.contains(.stickyNote))
        var holding = RunnerPose(mode: .chill, time: 0, face: .mid, react: 0)
        holding.cue(DailyCue(stage: .soon, prop: .bag, id: "a"), time: 5, slap: nil)
        let holdingParts = Set(RunnerFigure.parts(for: .chill, pose: holding))
        #expect(holding.propRaise == 1 && holdingParts.contains(.shopBag) && !holdingParts.contains(.monsterCan))
        let gym = CompanionPortrait(mode: .work, daily: DailyCue(stage: .now, prop: .gymBag, id: "b")).pose
        #expect(gym.bagLift == 1 && RunnerFigure.parts(for: .work, pose: gym).contains(.gymBag))
        var slapping = RunnerPose(mode: .work, time: 0, face: .mid, react: 0)
        slapping.cue(DailyCue(stage: .now, prop: .headphones, id: "b"), time: 0, slap: 0.15)
        let slapParts = Set(RunnerFigure.parts(for: .work, pose: slapping))
        #expect(slapParts.isSuperset(of: [.bigNote, .noteHit, .headset]))
        #expect(RunnerPose.noteSize(at: 0.25) > 1 && abs(RunnerPose.noteSize(at: 1) - 1) < 0.001)
        let soon = DailyCue(stage: .soon, prop: .note, id: "a")
        #expect(CompanionView.newCue(soon, stage: .soon, last: "") == "a")
        #expect(CompanionView.newCue(soon, stage: .soon, last: "a") == nil)
        #expect(CompanionView.newCue(soon, stage: .now, last: "") == nil)
    }

    @Test func hakuActsOutTheTasksScene() {
        var call = RunnerPose(mode: .work, time: 0, face: .mid, react: 0)
        call.cue(DailyCue(stage: .soon, prop: .note, scene: .call, id: "a"), time: 5, slap: nil)
        let callParts = Set(RunnerFigure.parts(for: .work, pose: call))
        #expect(callParts.isSuperset(of: [.phoneEar, .talkDots]))
        #expect(callParts.isDisjoint(with: [.stickyNote, .headset, .cupR]))
        var tapping = RunnerPose(mode: .chill, time: 0, face: .mid, react: 0)
        tapping.cue(DailyCue(stage: .soon, prop: .bag, scene: .grocery, id: "a"), time: 1, slap: nil)
        #expect(!RunnerFigure.parts(for: .chill, pose: tapping).contains(.toteBag))
        var run = RunnerPose(mode: .chill, time: 0, face: .mid, react: 0)
        run.cue(DailyCue(stage: .now, prop: .gymBag, scene: .run, id: "b"), time: 0.3, slap: nil)
        #expect(run.lean == 8 && run.bounce < 0)
        for scene in DailyScene.allCases {
            for part in scene.parts {
                #expect(SceneMove.of(part, in: scene, at: 1.3) != nil)
            }
            #expect(scene.parts.isDisjoint(with: scene.hides))
        }
        #expect(SceneMove.of(.camera, in: .coffee, at: 0) == nil)
    }

    @Test @MainActor func hakuWalksAwayFromAPlace() {
        var home = RunnerPose(mode: .chill, time: 0, face: .mid, react: 0)
        home.walk(from: .home, time: 0.2)
        let homeParts = Set(RunnerFigure.parts(for: .chill, pose: home))
        #expect(home.lean == 4 && home.bounce < 0)
        #expect(homeParts.isSuperset(of: [.speedLines, .walkDust, .earbud]))
        let office = CompanionPortrait(mode: .work, walking: .office).pose
        #expect(office.bagLift == 1 && RunnerFigure.parts(for: .work, pose: office).contains(.gymBag))
        let boxing = CompanionPortrait(mode: .chill, walking: .gym).pose
        #expect(RunnerFigure.parts(for: .chill, pose: boxing).contains(.bandage))
        let scene = DailyCue(stage: .now, prop: .note, scene: .coffee, id: "a")
        let busy = CompanionPortrait(mode: .chill, daily: scene, walking: .fitness).pose
        #expect(busy.walkFrom == nil && !RunnerFigure.parts(for: .chill, pose: busy).contains(.towel))
    }

    @Test @MainActor func hakuCallsMikeToTheBathThenDriesItsHair() {
        let calling = CompanionPortrait(mode: .chill, bath: true).pose
        let callParts = Set(RunnerFigure.parts(for: .chill, pose: calling))
        #expect(callParts.isSuperset(of: [.bathTowel, .shampoo, .rubberDuck]) && !callParts.contains(.monsterCan))
        var leaving = RunnerPose(mode: .chill, time: 0, face: .mid, react: 0)
        leaving.callToBath(time: 3)
        #expect(leaving.shift > 0 && leaving.lean == 5)
        var gone = RunnerPose(mode: .chill, time: 0, face: .mid, react: 0)
        gone.callToBath(time: 5.8)
        #expect(gone.shift == 0 && gone.presence < 1)
        var drying = RunnerPose(mode: .chill, time: 0, face: .mid, react: 0)
        drying.dryHair(time: 0.3)
        let dryParts = Set(RunnerFigure.parts(for: .chill, pose: drying))
        #expect(dryParts.isSuperset(of: [.rubTowelL, .rubTowelR, .dropsL, .dropsR]) && !dryParts.contains(.shampoo))
        #expect(SceneMove.bath(.dropsL, call: -1, dry: 0.3, shift: 0)?.opacity ?? 0 > 0)
        #expect(SceneMove.bath(.dropsR, call: -1, dry: 0.3, shift: 0)?.opacity == 0)
        #expect(SceneMove.bath(.camera, call: 1, dry: -1, shift: 0) == nil)
    }

    @Test func hakuGetsUpFromTheSofa() {
        let slumped = RunnerPose.revive(time: 0.5, face: .mid)
        let slumpedParts = Set(RunnerFigure.parts(for: .money, pose: slumped))
        #expect(slumpedParts.isSuperset(of: [.phone, .sofaArm, .eyesSleepy, .maskDown]))
        #expect(!slumpedParts.contains(.ledCode))
        let stretching = RunnerPose.revive(time: 3.6, face: .mid)
        let stretchParts = Set(RunnerFigure.parts(for: .money, pose: stretching))
        #expect(stretching.armsUp > 0 && stretchParts.contains(.eyesClosed) && !stretchParts.contains(.phone))
        let masked = RunnerPose.revive(time: 6, face: .mid)
        let maskedParts = Set(RunnerFigure.parts(for: .money, pose: masked))
        #expect(maskedParts.isSuperset(of: [.maskUp, .ledCode, .eyesChill]) && !maskedParts.contains(.maskDown))
        #expect(!maskedParts.contains(.sofaArm) && masked.armsUp == 0)
        #expect(SceneMove.revive(.phone, at: 1.8)?.opacity ?? 1 < 1)
        #expect(SceneMove.revive(.phone, at: -1) == nil && SceneMove.revive(.camera, at: 1) == nil)
        #expect(CompanionView.newRevived(.revived(id: "r"), last: "") == "r")
        #expect(CompanionView.newRevived(.revived(id: "r"), last: "r") == nil)
        #expect(CompanionView.newRevived(.stretched(id: "r"), last: "") == nil)
    }

    @Test func hakuCheersAPlannedTaskDone() {
        var focus = RunnerPose(mode: .work, time: 0, face: .mid, react: 0)
        focus.cheerFocus(progress: 0.1)
        #expect(focus.ledFlare > 0 && focus.fistPump < 0 && !focus.eyesShut)
        focus.cheerFocus(progress: 0.5)
        let parts = Set(RunnerFigure.parts(for: .work, pose: focus))
        #expect(focus.eyesShut && focus.fistPump >= 0 && focus.burst >= 0)
        #expect(parts.isSuperset(of: [.backFist, .eyesClosed, .sparkle]) && !parts.contains(.headBack))
        #expect(CompanionView.newTaskDone(.taskDone(id: "t", focus: true), last: "") == "t")
        #expect(CompanionView.newTaskDone(.taskDone(id: "t", focus: false), last: "t") == nil)
        #expect(CompanionView.newTaskDone(.stretched(id: "t"), last: "") == nil)
    }

    @Test func atHomeHakuScratchesItsHead() {
        let scratching = RunnerPose(mode: .chill, time: 6, face: .mid, react: 0)
        #expect(scratching.scratch == 0.5 && scratching.tuft > 0)
        let parts = Set(RunnerFigure.parts(for: .chill, pose: scratching))
        #expect(parts.isSuperset(of: [.scratchHand, .hairTuft]))
        let settling = RunnerPose(mode: .chill, time: 9, face: .mid, react: 0)
        #expect(settling.scratch < 0 && settling.tuft > 0 && settling.tuft < 1)
        #expect(!RunnerFigure.parts(for: .chill, pose: settling).contains(.scratchHand))
        let calm = RunnerPose(mode: .chill, time: 14, face: .mid, react: 0)
        #expect(calm.tuft == 0 && !RunnerFigure.parts(for: .chill, pose: calm).contains(.hairTuft))
        let napping = RunnerPose(mode: .chill, time: 6, face: .mid, life: .nap, react: 0)
        #expect(napping.scratch < 0)
    }

    @Test func highSpiritHumsANote() throws {
        #expect(CompanionView.hum(at: 5) == nil)
        #expect(abs(try #require(CompanionView.hum(at: 25.6)) - 0.25) < 0.001)
        #expect(CompanionView.hum(at: 11.4) == nil)
        var pose = RunnerPose(mode: .chill, time: 3, face: .high, react: 0)
        #expect(!RunnerFigure.parts(for: .chill, pose: pose).contains(.musicNote))
        pose.hum = 0.5
        #expect(RunnerFigure.parts(for: .chill, pose: pose).contains(.musicNote))
        pose.turnedAway = true
        #expect(!RunnerFigure.parts(for: .chill, pose: pose).contains(.musicNote))
    }

    @Test func lowSpiritRubsAnEye() {
        #expect(CompanionView.rubEyes(at: 10, mode: .work) == nil)
        #expect(CompanionView.rubEyes(at: 35.25, mode: .work) == 0.5)
        #expect(CompanionView.rubEyes(at: 16.5, mode: .chill) == nil)
        #expect(CompanionView.rubEyes(at: 35.25, mode: .boxing) == nil)
        var pose = RunnerPose(mode: .work, time: 3, face: .mid, react: 0)
        let headDy = pose.headDy
        #expect(!RunnerFigure.parts(for: .work, pose: pose).contains(.rubHand))
        pose.rubEyes(progress: 0.5)
        #expect(pose.rubEye == 0.5 && pose.blink <= 0.25 && pose.headDy == headDy + 1)
        #expect(RunnerFigure.parts(for: .work, pose: pose).contains(.rubHand))
    }

    @Test func tappedTooOftenHakuTurnsItsBack() {
        let now = Date(timeIntervalSinceReferenceDate: 1000)
        let two = [now.addingTimeInterval(-10), now]
        #expect(!CompanionView.pestered(two, now: now))
        #expect(CompanionView.pestered([now.addingTimeInterval(-20)] + two, now: now))
        #expect(!CompanionView.pestered([now.addingTimeInterval(-CompanionView.pesterWindow)] + two, now: now))
        var turning = RunnerPose()
        turning.turnAway(progress: 0.12)
        #expect(!turning.turnedAway && turning.turnSqueeze == 0.05)
        var away = RunnerPose()
        away.turnAway(progress: 0.5)
        #expect(away.turnedAway && away.turnSqueeze == 1)
        var back = RunnerPose()
        back.turnAway(progress: 1)
        #expect(!back.turnedAway && back.turnSqueeze > 0.99)
        var pose = RunnerPose()
        pose.turnedAway = true
        let parts = Set(RunnerFigure.parts(for: .work, pose: pose))
        #expect(parts.isSuperset(of: [.headBack, .hairBack, .headset, .jacket]))
        #expect(parts.isDisjoint(with: [.faceBase, .eyesWork, .maskUp, .hairFringe, .mic, .stripeNeon]))
        #expect(Set(RunnerFigure.parts(for: .chill, pose: RunnerPose())).contains(.headBack) == false)
    }

    @Test func afterHalfADayHakuLooksUp() {
        let now = Date(timeIntervalSinceReferenceDate: 100_000)
        let seen = now.timeIntervalSinceReferenceDate
        #expect(!CompanionView.backAfterLongAway(lastSeen: 0, now: now))
        #expect(!CompanionView.backAfterLongAway(lastSeen: seen - 3600, now: now))
        #expect(CompanionView.backAfterLongAway(lastSeen: seen - CompanionView.longAwayGap, now: now))
        #expect(!CompanionView.noticePlaying(since: nil, now: now, duration: 1.6))
        #expect(CompanionView.noticePlaying(since: now.addingTimeInterval(-0.2), now: now, duration: 1.6))
        #expect(!CompanionView.noticePlaying(since: now.addingTimeInterval(-1.6), now: now, duration: 1.6))
        var down = RunnerPose()
        down.notice(progress: 0.2, lookUp: true)
        #expect(down.eyesDy == 2 && down.headDy == 1.5 && down.eyesDx == 0)
        var up = RunnerPose()
        up.notice(progress: 0.7, lookUp: true)
        #expect(up.eyesDy == 0 && up.headDy < -2)
        var done = RunnerPose()
        done.notice(progress: 1, lookUp: true)
        #expect(done.eyesDy == 0 && done.headDy == 0)
    }

    @Test func aNapMumblesNowAndThen() {
        let snoring = RunnerPose(mode: .chill, time: 1.5, face: .mid, life: .nap, react: 0)
        #expect(snoring.zzz >= 0 && snoring.sleepTalk < 0)
        let mumbling = RunnerPose(mode: .chill, time: 10.5, face: .mid, life: .nap, react: 0)
        #expect(mumbling.zzz < 0 && mumbling.sleepTalk > 0.4)
        let woken = RunnerPose(mode: .chill, time: 10.5, face: .mid, life: .nap, react: 0.5)
        #expect(woken.sleepTalk < 0)
    }

    @Test func aNapNeedsTwoTapsToWake() {
        let roll = Date(timeIntervalSinceReferenceDate: 1000)
        #expect(!CompanionView.napWakes(lastTap: nil, now: roll))
        #expect(CompanionView.napWakes(lastTap: roll, now: roll.addingTimeInterval(3)))
        #expect(!CompanionView.napWakes(lastTap: roll, now: roll.addingTimeInterval(CompanionView.napWakeWindow)))
        let rolling = IdleMotion.rollingOver(time: 0, progress: 0.5)
        #expect(rolling.angle > 7.9)
        #expect(IdleMotion.rollingOver(time: 0, progress: 0).angle == 0)
    }

    @Test func everyFourthSipTheCanIsEmpty() {
        // Cycle 4 (32 s) follows the fourth sip: shake, then stare.
        let shaking = RunnerPose(mode: .chill, time: 32.5, face: .mid, react: 0)
        #expect(!shaking.emptyCan && shaking.canOffset.height == -10)
        let staring = RunnerPose(mode: .chill, time: 34, face: .mid, react: 0)
        #expect(staring.emptyCan)
        let parts = Set(RunnerFigure.parts(for: .chill, pose: staring))
        #expect(parts.isSuperset(of: [.eyesWork, .monsterCan]))
        #expect(!parts.contains(.eyesChill))
        #expect(!RunnerPose(mode: .chill, time: 36, face: .mid, react: 0).emptyCan)
        #expect(!RunnerPose(mode: .chill, time: 2, face: .mid, react: 0).emptyCan)
        #expect(!RunnerPose(mode: .chill, time: 34, face: .mid, life: .snack, react: 0).emptyCan)
    }

    @Test func staminaNudgesWhatHakuDoesOnItsOwn() {
        let start = Date(timeIntervalSinceReferenceDate: IdleLife.slotLength * 1000)
        let slots = (0..<(7 * 96)).map { start.addingTimeInterval(Double($0) * IdleLife.slotLength) }
        let fit = slots.map { IdleLife.at($0, stamina: .high) }
        let lazy = slots.map { IdleLife.at($0, stamina: .low) }
        #expect(!fit.contains(.nap) && fit.contains(.practice))
        #expect(!lazy.contains(.practice) && lazy.contains(.nap))
        #expect(slots.map { IdleLife.at($0, stamina: .mid) } == slots.map { IdleLife.at($0) })
    }

    @Test func vitalsOnlyChangeTheLook() {
        let tired = HakuVitals(stamina: .low, spirit: .low)
        let fit = HakuVitals(stamina: .high, spirit: .high)
        let usual = HakuVitals()
        #expect(tired.motionSpeed < usual.motionSpeed && usual.motionSpeed < fit.motionSpeed)
        #expect(tired.bounce < usual.bounce && usual.bounce < fit.bounce)
        #expect(tired.slouch > 0 && usual.slouch == 0 && fit.slouch < 0)
        #expect(tired.saturation < 1 && usual.saturation == 1 && usual.brightness == 0 && fit.brightness > 0)
        #expect(IdleMotion(dy: 2, angle: 1).bouncing(1.5).dy == 3)
    }

    @Test func sundayAfternoonIsForTidying() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        // 2026-10-04 is a Sunday.
        let sunday = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 14)))
        #expect(IdleLife.at(sunday, calendar: calendar) == .tidying)
        let saturday = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 14)))
        #expect(IdleLife.at(saturday, calendar: calendar) != .tidying)
    }

    @Test func idleLifeHoldsForASlotAndVaries() {
        let start = Date(timeIntervalSinceReferenceDate: IdleLife.slotLength * 1000)
        #expect(IdleLife.at(start) == IdleLife.at(start.addingTimeInterval(IdleLife.slotLength - 1)))
        let week = (0..<(7 * 96)).map { IdleLife.at(start.addingTimeInterval(Double($0) * IdleLife.slotLength)) }
        for life in IdleLife.allCases { #expect(week.contains(life)) }
        #expect(week.contains(nil))
    }

    @Test func portraitStillHoldsForASlotAndVaries() {
        let start = Date(timeIntervalSinceReferenceDate: IdleLife.slotLength * 1000)
        #expect(PortraitStill.at(start) == PortraitStill.at(start.addingTimeInterval(IdleLife.slotLength - 1)))
        let day = (0..<96).map { PortraitStill.at(start.addingTimeInterval(Double($0) * IdleLife.slotLength)) }
        for still in PortraitStill.allCases { #expect(day.contains(still)) }
    }

    @Test @MainActor func portraitAtHomeDoesWhatTheAppDoes() throws {
        let start = Date(timeIntervalSinceReferenceDate: IdleLife.slotLength * 1000)
        let slots = (0..<96).map { start.addingTimeInterval(Double($0) * IdleLife.slotLength) }
        let nap = try #require(slots.first { IdleLife.at($0) == .nap })
        let napping = CompanionPortrait(mode: .chill, date: nap).pose
        #expect(napping.life == .nap)
        #expect(Set(RunnerFigure.parts(for: .chill, pose: napping)).contains(.zzz))
        // Anything else HAKU is doing replaces its own time.
        #expect(CompanionPortrait(mode: .chill, need: .couchScroll, date: nap).pose.life == nil)
        #expect(CompanionPortrait(mode: .work, date: nap).pose.life == nil)
    }

    @Test(arguments: Mode.allCases)
    func portraitStillsDiffer(_ mode: Mode) {
        var glance = RunnerPose()
        glance.show(.glance, mode: mode)
        var alt = RunnerPose()
        alt.show(.alt, mode: mode)
        let plain = RunnerPose()
        #expect(glance.eyesDx != plain.eyesDx || glance.canAngle != plain.canAngle)
        #expect(
            alt.headDy != plain.headDy || alt.eyesDx != plain.eyesDx || alt.gloveL != plain.gloveL
                || alt.eyesDy != plain.eyesDy
        )
    }

    @Test(arguments: IdleLife.allCases)
    func idleLifeSwapsTheCanForItsProp(_ life: IdleLife) {
        let parts = Set(RunnerFigure.parts(for: .chill, pose: RunnerPose(life: life)))
        #expect(!parts.contains(.monsterCan))
        #expect(RunnerFigure.baseParts.isSubset(of: parts))
        let expected: Set<RunnerPart> =
            switch life {
            case .nap: [.pillow, .eyesSleepy, .zzz]
            case .handheld: [.handheld, .eyesWork]
            case .snack: [.onigiri, .eyesChill]
            case .drawing: [.sketchbook, .pencil, .eyesWork]
            case .practice: [.gloveL, .gloveR]
            case .tidying: [.cloth]
            }
        #expect(parts.isSuperset(of: expected))
        if parts.contains(.eyesWork) || parts.contains(.eyesSleepy) { #expect(!parts.contains(.eyesChill)) }
        #expect(!CompanionLines.lines(for: .chill, life: life).isEmpty)
        let label = CompanionLines.accessibilityLabel(mode: .chill, need: nil, life: life, bedtime: .off)
        #expect(label.hasPrefix("HAKU，"))
    }

    @Test func needsAndBedtimeOverrideIdleLife() {
        let needed = Set(RunnerFigure.parts(for: .chill, pose: RunnerPose(need: .couchScroll, life: .handheld)))
        #expect(!needed.contains(.handheld))
        var night = RunnerPose.bedtimeStill()
        night.life = .snack
        #expect(!RunnerFigure.parts(for: .chill, pose: night).contains(.onigiri))
    }

    @Test(arguments: IdleLife.allCases)
    func lookingCatchesHaku(_ life: IdleLife) {
        for step in 0..<60 {
            let time = Double(step) * 0.05
            let caught = RunnerPose(mode: .chill, time: time, face: .mid, life: life, react: 1)
            #expect((0...1).contains(caught.propHidden))
            #expect((0.1...1).contains(caught.blink))
            switch life {
            case .snack, .drawing: #expect(caught.propHidden == 1)
            case .nap: #expect(caught.blink > 0.99 && caught.lie == 0)
            case .practice: #expect(caught.gloveL.height >= 18)
            case .handheld, .tidying: break
            }
        }
    }

    @Test func eachWorkoutHasItsOwnCelebration() {
        func cheering(_ kind: WorkoutSummary.Kind, mode: Mode = .chill) -> Set<RunnerPart> {
            var pose = RunnerPose()
            pose.celebrate(kind, progress: 0.25)
            return Set(RunnerFigure.parts(for: mode, pose: pose))
        }
        #expect(cheering(.running).contains(.peaceHand))
        #expect(cheering(.strength).contains(.dumbbell))
        #expect(cheering(.boxing).isSuperset(of: [.gloveL, .gloveR]))
        #expect(!cheering(.running).contains(.monsterCan))
        #expect(cheering(.other).isDisjoint(with: [.peaceHand, .dumbbell]))
        #expect(cheering(.other).contains(.sparkle))
        var boxing = RunnerPose()
        boxing.celebrate(.boxing, progress: 0.25)
        #expect(boxing.gloveR.height < -20)
        let kinds: [WorkoutSummary.Kind] = [.boxing, .running, .strength, .other]
        let lines = Set(kinds.map { CompanionLines.celebration($0) })
        #expect(lines.count == 4)
    }

    @Test func couchStagesFollowTimeAndInvite() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        #expect(CouchStage.at(start.addingTimeInterval(10 * 60), since: start, inviting: false) == .scrolling)
        let later = start.addingTimeInterval(CouchStage.peekAfter)
        #expect(CouchStage.at(later, since: start, inviting: false) == .peeking)
        #expect(CouchStage.at(start, since: nil, inviting: false) == .scrolling)
        #expect(CouchStage.at(start, since: start, inviting: true) == .up)
    }

    @Test func gymBagShowsWhilePeekingAndCarrying() {
        var peeking = RunnerPose(need: .couchScroll)
        #expect(!RunnerFigure.parts(for: .chill, pose: peeking).contains(.gymBag))
        peeking.peekAtBag(time: 4.2)
        #expect(peeking.bagLift == 0 && peeking.eyesDx < 0)
        #expect(RunnerFigure.parts(for: .chill, pose: peeking).contains(.gymBag))
        var up = RunnerPose()
        up.bagLift = 1
        #expect(RunnerFigure.parts(for: .work, pose: up).contains(.gymBag))
        var night = RunnerPose.bedtimeStill()
        night.bagLift = 1
        #expect(!RunnerFigure.parts(for: .chill, pose: night).contains(.gymBag))
        let peekLines = CompanionLines.lines(for: .chill, need: .couchScroll, peeking: true)
        #expect(peekLines != CompanionLines.lines(for: .chill, need: .couchScroll))
        let label = CompanionLines.accessibilityLabel(mode: .chill, need: .couchScroll, peeking: true, bedtime: .off)
        #expect(label.contains("运动包"))
    }

    @Test func activityReplacesTheNeedAndOwnTime() {
        let pose = RunnerPose(need: .couchScroll, life: .nap, activity: .running)
        #expect(pose.need == nil)
        #expect(pose.life == nil)
        #expect(pose.activity == .running)
    }

    @Test(arguments: [
        (CompanionActivity.boxingAtGym, RunnerPart.heavyBag),
        (.gymSession, .dumbbell),
        (.running, .speedLines),
        (.gymDay, .gymBag),
        (.runDay, .runShoe),
    ])
    func eachActivityShowsItsProp(_ activity: CompanionActivity, prop: RunnerPart) {
        let parts = Set(RunnerFigure.parts(for: .chill, pose: RunnerPose(activity: activity)))
        #expect(parts.contains(prop))
        #expect(!parts.contains(.monsterCan))
        #expect(!CompanionLines.lines(for: .chill, activity: activity).isEmpty)
        #expect(CompanionLines.accessibilityLabel(mode: .chill, need: nil, activity: activity, bedtime: .off) != "HAKU")
    }

    @Test func heavyBagWorkWearsTheGloves() {
        let parts = Set(RunnerFigure.parts(for: .boxing, pose: RunnerPose(activity: .boxingAtGym)))
        #expect(parts.isSuperset(of: [.gloveL, .gloveR, .headband, .heavyBag]))
    }

    @Test func bedtimeHidesTheActivity() {
        var pose = RunnerPose.bedtimeStill()
        pose.activity = .running
        #expect(!RunnerFigure.parts(for: .chill, pose: pose).contains(.speedLines))
    }

    @Test func outfitFollowsTheEquippedItems() {
        var wardrobe = Wardrobe()
        wardrobe.equipped[.gloves] = "gloves.gold"
        wardrobe.equipped[.headband] = "keepsake.headband.runner"
        wardrobe.equipped[.mask] = "mask.stripes"
        wardrobe.equipped[.room] = "room.bag"
        let outfit = Outfit(wardrobe)
        #expect(outfit.gloves == RunnerPalette.gold)
        #expect(outfit.headband == RunnerPalette.white)
        #expect(outfit.stripedMask)
        #expect(outfit.room == .roomBag)
    }

    @Test func unknownItemsKeepTheDefaultLook() {
        #expect(Outfit(Wardrobe(equipped: [.gloves: "gloves.someday", .room: "room.someday"])) == Outfit())
    }

    @Test(arguments: ShopItem.catalog)
    func everyWornItemChangesTheLook(_ item: ShopItem) {
        var wardrobe = Wardrobe()
        wardrobe.equip(item)
        #expect(Outfit(wardrobe) != Outfit())
    }

    @Test func stripedMaskShowsOnBothMasks() {
        var wardrobe = Wardrobe()
        wardrobe.equipped[.mask] = "mask.stripes"
        let pose = RunnerPose().wearing(Outfit(wardrobe))
        let work = Set(RunnerFigure.parts(for: .work, pose: pose))
        #expect(work.contains(.maskStripes))
        #expect(!work.contains(.panelLines))
        #expect(Set(RunnerFigure.parts(for: .chill, pose: pose)).contains(.maskStripesDown))
    }

    @Test func roomItemShowsOnlyAtHome() {
        var wardrobe = Wardrobe()
        wardrobe.equipped[.room] = "room.plant"
        var pose = RunnerPose().wearing(Outfit(wardrobe))
        #expect(RunnerFigure.parts(for: .chill, pose: pose).contains(.roomPlant))
        #expect(!RunnerFigure.parts(for: .work, pose: pose).contains(.roomPlant))
        pose.bagLift = 0
        #expect(!RunnerFigure.parts(for: .chill, pose: pose).contains(.roomPlant))
        let running = RunnerPose(activity: .running).wearing(Outfit(wardrobe))
        #expect(!RunnerFigure.parts(for: .chill, pose: running).contains(.roomPlant))
    }

    @Test(arguments: ShopItem.catalog)
    func everyItemIconDrawsSomething(_ item: ShopItem) {
        var wardrobe = Wardrobe()
        wardrobe.equip(item)
        let picture = ItemPicture(slot: item.slot, outfit: Outfit(wardrobe), itemID: item.id)
        #expect(!picture.parts.isEmpty)
        #expect(picture != ItemPicture(slot: item.slot, outfit: Outfit(), itemID: nil))
    }

    @Test func defaultIconsShowTheStandardLook() {
        #expect(ItemPicture(slot: .gloves, outfit: Outfit(), itemID: nil).red == nil)
        #expect(ItemPicture(slot: .mask, outfit: Outfit(), itemID: nil).parts.contains(.panelLines))
        #expect(ItemPicture(slot: .room, outfit: Outfit(), itemID: nil).parts.isEmpty)
    }

    @Test func slotsHaveTheirOwnTileColors() {
        #expect(Set(Slot.allCases.map(\.tileColor)).count == Slot.allCases.count)
    }

    @Test func eachUnboxingPlaysOnce() {
        #expect(CompanionView.newUnlock(.unlock(id: "e1", item: "gloves.gold"), last: "") == "e1")
        #expect(CompanionView.newUnlock(.unlock(id: "e1", item: "gloves.gold"), last: "e1") == nil)
        #expect(CompanionView.newUnlock(.offWork(id: "2026-10-05"), last: "") == nil)
        #expect(CompanionView.newCelebration(.unlock(id: "e1", item: "gloves.gold"), last: "") == nil)
    }

    @Test func keepsakesAndPurchasesGetTheirOwnLine() {
        #expect(CompanionLines.unlock("gloves.gold") == "……给你的。才不是特意挑的。")
        #expect(CompanionLines.unlock("room.plant") != CompanionLines.unlock("gloves.gold"))
    }

    @Test func hakuPopsOutOfTheBoxAndSettles() {
        var pose = RunnerPose()
        #expect(pose.popOut == 1)
        pose.unbox(progress: 0.1)
        #expect(pose.popOut == 0)
        #expect(pose.burst == -1)
        pose.unbox(progress: 0.42)
        #expect(pose.popOut > 1)
        #expect(pose.burst >= 0)
        pose.unbox(progress: 0.9)
        #expect(pose.popOut == 1)
        #expect(pose.gloveR.height < 0)
    }

    @Test func peaceSignKeepsakeJoinsEveryCelebration() {
        let outfit = Outfit(Wardrobe(equipped: [.celebration: "celebrate.up"]))
        var pose = RunnerPose().wearing(outfit)
        #expect(!RunnerFigure.parts(for: .work, pose: pose).contains(.peaceHand))
        pose.celebrate(.boxing, progress: 0.5)
        #expect(RunnerFigure.parts(for: .work, pose: pose).contains(.peaceHand))
        pose.bedtime = true
        #expect(!RunnerFigure.parts(for: .work, pose: pose).contains(.peaceHand))
    }

    @Test func everySlotHasAShowcaseMode() {
        #expect(Slot.gloves.showcaseMode == .boxing)
        #expect(Slot.room.showcaseMode == .chill)
    }

    @Test(arguments: CompanionMoment.allCases)
    func everyMomentHasALookLinesAndALabel(_ moment: CompanionMoment) {
        let parts = Set(RunnerFigure.parts(for: .money, pose: RunnerPose(moment: moment)))
        #expect(parts != Set(RunnerFigure.parts(for: .money, pose: RunnerPose())) || moment == .shooting)
        #expect(!CompanionLines.lines(for: .money, moment: moment).isEmpty)
        let label = CompanionLines.accessibilityLabel(mode: .money, need: nil, moment: moment, bedtime: .off)
        #expect(label != "HAKU，\(Mode.money.title)")
    }

    @Test func vibeCodingStopsForAStretch() {
        let typing = RunnerPose(mode: .money, time: 5, face: .mid, moment: .vibeCoding, react: 0)
        #expect(typing.stretch == 0 && typing.headDy == 2)
        let stretching = RunnerPose(mode: .money, time: 12.25, face: .mid, moment: .vibeCoding, react: 0)
        #expect(stretching.stretch > 0.59 && stretching.headDy < 0 && stretching.typing.height < -3.9)
        let flow = RunnerPose(mode: .money, time: 12.25, face: .mid, moment: .flow, react: 0)
        #expect(flow.stretch == 0)
    }

    @Test func vibeCodingWearsTheHoodieAndPilesUpCans() {
        var pose = RunnerPose(moment: .vibeCoding)
        let parts = Set(RunnerFigure.parts(for: .money, pose: pose))
        #expect(parts.isSuperset(of: [.hoodieStrings, .ledCode, .laptop, .typingHands]))
        #expect(!parts.contains(.ledYen))
        #expect(parts.isDisjoint(with: [.canStackOne, .canStackTwo, .canStackThree]))
        pose.codingCans = 2
        let two = Set(RunnerFigure.parts(for: .money, pose: pose))
        #expect(two.isSuperset(of: [.canStackOne, .canStackTwo]))
        #expect(!two.contains(.canStackThree))
        pose.codingCans = 9
        #expect(Set(RunnerFigure.parts(for: .money, pose: pose)).contains(.canStackThree))
    }

    @Test func shootingKeepsTheMoneyLookInAnyMode() {
        let shooting = RunnerPose(moment: .shooting)
        #expect(RunnerFigure.parts(for: .chill, pose: shooting) == RunnerFigure.parts(for: .money, pose: RunnerPose()))
    }

    @Test func momentReplacesTheNeedButNotTheActivity() {
        let pose = RunnerPose(need: .couchScroll, life: .snack, moment: .gymInvite)
        #expect(pose.need == nil)
        #expect(pose.life == nil)
        #expect(pose.bagLift == 1)
        #expect(Set(RunnerFigure.parts(for: .chill, pose: pose)).isSuperset(of: [.door, .towel, .handWeight]))
        #expect(RunnerPose(activity: .running, moment: .gymInvite).moment == nil)
    }

    @Test func overtimeSlumpsOntoTheDeskAndTheSoulLeaves() {
        let pose = RunnerPose(mode: .work, time: 1, face: .mid, moment: .overtime, react: 0)
        #expect(pose.slump == 1)
        #expect((0..<1).contains(pose.soulRise))
        let parts = Set(RunnerFigure.parts(for: .work, pose: pose))
        #expect(parts.isSuperset(of: [.desk, .soul, .eyesSleepy]))
        #expect(!parts.contains(.laptop))
    }

    @Test func flowHandsOverACanNowAndThen() {
        let typing = RunnerPose(mode: .money, time: 2, face: .mid, moment: .flow, react: 0)
        #expect(typing.canOpacity == 0)
        let handing = RunnerPose(mode: .money, time: 9, face: .mid, moment: .flow, react: 0)
        #expect(handing.canOpacity == 1)
    }

    @Test func bedtimeStillOverlaysTheMoment() {
        var pose = RunnerPose(moment: .lateCoding)
        pose.bedtime = true
        let parts = Set(RunnerFigure.parts(for: .money, pose: pose))
        #expect(parts.contains(.laptop))
        #expect(parts.contains(.eyesSleepy))
        // The mask comes down at bedtime, so its </> goes with it.
        #expect(!parts.contains(.ledCode))
    }

    @Test func bandageGoesEverywhereButTheRoomTracesStayHome() {
        let pose = RunnerPose().leaving(Set(CompanionTrace.allCases))
        let boxing = Set(RunnerFigure.parts(for: .boxing, pose: pose))
        #expect(boxing.contains(.bandage))
        #expect(boxing.isDisjoint(with: [.roomPc, .sunlight]))
        let home = Set(RunnerFigure.parts(for: .chill, pose: pose))
        #expect(home.isSuperset(of: [.bandage, .roomPc, .sunlight]))
        let heading = RunnerPose(moment: .heading).leaving([.sunlight])
        #expect(!RunnerFigure.parts(for: .chill, pose: heading).contains(.sunlight))
        #expect(RunnerFigure.parts(for: .chill, pose: RunnerPose()).contains(.roomPc) == false)
    }

    @Test func collapsedDropsTheHeadOntoTheSofaArm() {
        let pose = RunnerPose(moment: .collapsed)
        #expect(pose.slump > 0.5)
        #expect(Set(RunnerFigure.parts(for: .chill, pose: pose)).isSuperset(of: [.sofaArm, .eyesSleepy]))
    }

    @Test func morningBrushesAndTimeToLeaveTapsTheWatch() {
        let brushing = Set(RunnerFigure.parts(for: .chill, pose: RunnerPose(moment: .morning)))
        #expect(brushing.contains(.toothbrush))
        let leaving = Set(RunnerFigure.parts(for: .chill, pose: RunnerPose(moment: .timeToLeave)))
        #expect(leaving.isSuperset(of: [.headset, .door, .watchWrist, .tapHand]))
        #expect(CompanionLines.lines(for: .chill, moment: .timeToLeave).contains("……公司还在等你。"))
    }
}
