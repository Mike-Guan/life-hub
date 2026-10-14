import Foundation
import HubCore
import Testing

@testable import CompanionKit

// Identity cards, batch 1 (第 1 批身份卡 预览): HAKU dresses for the card the user picked.
@Suite struct RunnerCardLookTests {
    private func parts(_ mode: Mode, card: IdentityKind?) -> Set<RunnerPart> {
        Set(RunnerFigure.parts(for: mode, pose: RunnerPose(face: .mid).dressed(for: card, in: mode)))
    }

    @Test func theCardSlotDressesHakuForThePickedCard() {
        #expect(RunnerCardLook(card: .tennis) == .tennis)
        #expect(RunnerCardLook(card: .fitness) == .fitness)
        #expect(RunnerCardLook(card: .study) == .study)
        #expect(RunnerCardLook(card: .art) == .art)
        // No card, boxing, or a card without a look yet keeps the boxing kit.
        for card: IdentityKind? in [nil, .boxing, .swimming, .ski] {
            #expect(RunnerCardLook(card: card) == nil)
            #expect(parts(.boxing, card: card).isSuperset(of: [.gloveL, .gloveR, .headband]))
        }
    }

    @Test func theCardOnlyChangesTheCardSlot() {
        for mode in [Mode.work, .chill, .money] {
            #expect(parts(mode, card: .tennis) == parts(mode, card: nil), "\(mode)")
            #expect(RunnerPose().dressed(for: .fitness, in: mode).bagLift < 0, "\(mode)")
        }
    }

    @Test func eachCardLookDrawsItsOwnThings() {
        let expected: [IdentityKind: Set<RunnerPart>] = [
            .tennis: [.stripeSport, .tennisVisor, .tennisRacket, .racketHand, .tennisBall],
            .fitness: [.stripeSport, .gymBag, .handWeight],
            .study: [.stripeNeon, .book, .bookPage],
            .art: [.stripeNeon, .apron, .sketchbook, .pencil],
        ]
        for (card, things) in expected {
            let shown = parts(.boxing, card: card)
            #expect(shown.isSuperset(of: things), "\(card)")
            // The boxing kit stays with boxing.
            #expect(shown.isDisjoint(with: [.gloveL, .gloveR, .headband, .mouthFang]), "\(card)")
        }
        // The sport base swaps the neon stripe for the orange one.
        #expect(!parts(.boxing, card: .tennis).contains(.stripeNeon))
        #expect(!parts(.boxing, card: .art).contains(.mouthSmile))
    }

    @Test func somethingElseInHandReplacesTheCardProps() {
        var pose = RunnerPose(face: .mid)
        pose.dailyProp = .note
        pose.propRaise = 1
        for card: IdentityKind in [.tennis, .fitness, .study, .art] {
            let dressed = pose.dressed(for: card, in: .boxing)
            let shown = Set(RunnerFigure.parts(for: .boxing, pose: dressed))
            #expect(shown.isDisjoint(with: RunnerCardLook(card: card)!.props), "\(card)")
            #expect(shown.contains(.stickyNote), "\(card)")
            #expect(dressed.bagLift < 0, "\(card)")
        }
    }
}
