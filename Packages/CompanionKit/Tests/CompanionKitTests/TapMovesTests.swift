import Foundation
import HubCore
import Testing

@testable import CompanionKit

// QA S3 (Mike's bug G2): tapping KURO only changed her bubble. Each look and slot is read 0.15 s into the tap.
@Suite struct TapMovesTests {
    /// Seconds into a tap at which the body must already move.
    static let tapAt: TimeInterval = 0.15

    static let slots: [KuroSlot?] = [nil] + KuroSlot.allCases.map { Optional($0) }

    @Test(arguments: KuroLook.allCases)
    func kurosTapMovesHerBodyInEveryLookAndSlot(_ look: KuroLook) {
        for slot in Self.slots {
            for energy in [50.0, 10.0] {
                let rest = KuroPose(look: look, energy: energy)
                let pose = slot?.dressing(rest) ?? rest
                let tap = KuroTap(look: look, sleepy: EnergyFace(energy: energy) == .low)
                let progress = Self.tapAt / tap.duration
                // KuroView offsets her whole figure by this hop.
                #expect(KuroView.hop((tap, progress)) != 0, "\(look) \(String(describing: slot)) \(energy)")
                let drawn = KuroFigure.parts(for: look, pose: pose.reacting(tap, progress: progress))
                #expect(drawn != KuroFigure.parts(for: look, pose: pose), "\(look) \(String(describing: slot))")
            }
        }
    }

    // Overtime at the desk has no hop: her hand taps her cheek. That starts at 0.165 s, so it is read at 0.3 s.
    @Test func kurosTapAtTheDeskMovesHerHand() {
        let pose = KuroView.pose(.work, energy: 50, bedtime: .off, moment: .overtime, overtimeUntil: nil)
        let tapped = pose.reacting(.chinTap, progress: 0.3 / KuroTap.chinTap.duration)
        #expect(KuroFigure.shift(.overtimeHand, pose: tapped) != .zero)
    }

    @Test(arguments: Mode.allCases)
    func hakusTapIsMoreThanABubble(_ mode: Mode) {
        let progress = Self.tapAt / WatchPoke.duration
        for (energy, busy) in [(50.0, false), (50.0, true), (10.0, false)] {
            let kind = WatchPoke.pick(mode: mode, energy: energy, asleep: false, busy: busy)
            let rest = RunnerPose(mode: mode, time: 1, face: EnergyFace(energy: energy), react: 0)
            if kind == .rollOver {
                // Rolling over moves the whole figure through its idle motion.
                let roll = IdleMotion.rollingOver(time: 1, progress: progress)
                #expect(roll.angle != 0 && roll.dy != IdleMotion.sleeping(time: 1).dy, "\(mode)")
                continue
            }
            var tapped = rest
            tapped.poke(kind, progress: progress)
            #expect(Self.moves(tapped) != Self.moves(rest), "\(mode) \(kind)")
        }
    }

    /// What a poke can move: body, head, gloves, can, headset cup and mask LED.
    static func moves(_ pose: RunnerPose) -> [Double] {
        [
            pose.lean, pose.headTilt, Double(pose.bounce), Double(pose.headDy), Double(pose.shift),
            Double(pose.gloveR.width), Double(pose.gloveR.height), Double(pose.canOffset.width),
            Double(pose.canOffset.height), Double(pose.cupRUp), Double(pose.ledFlare),
        ]
    }
}
