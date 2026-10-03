import Foundation
import HubCore
import Testing

@testable import CompanionKit

@Suite struct CompanionKitTests {
    @Test(arguments: RunnerPart.allCases)
    func everyPartHasArt(_ part: RunnerPart) {
        #expect(!RunnerArt.inks(part).isEmpty || RunnerArt.text(part) != nil)
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
        #expect(RunnerFigure.parts(for: .money, pose: RunnerPose(tired: true)).contains(.eyebags))
        #expect(RunnerPose.isTired(10))
        #expect(!RunnerPose.isTired(30))
        #expect(!RunnerPose.isTired(nil))
    }

    @Test(arguments: Mode.allCases)
    func posesStayInRange(_ mode: Mode) {
        for step in 0..<200 {
            for react in [0.0, 0.5, 1.0] {
                let time = Double(step) * 0.05
                let pose = RunnerPose(mode: mode, time: time, tired: step.isMultiple(of: 2), react: react)
                #expect((0...1).contains(pose.blink))
                #expect((0...1).contains(pose.ledOpacity))
                #expect(abs(pose.headDy) <= 2)
                #expect(abs(pose.canAngle) <= 60)
                #expect(abs(pose.gloveR.width) <= 14)
                #expect(pose.glint <= 1)
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
