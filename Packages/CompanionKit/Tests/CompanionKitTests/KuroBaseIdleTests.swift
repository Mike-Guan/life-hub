import Foundation
import HubCore
import Testing

@testable import CompanionKit

// 待机动作 补齐规格 v0 K4-K7, K10-K11: the second character's small moves in her three base outfits.
@Suite struct KuroBaseIdleTests {
    /// Her parts `t` seconds into `idle` in `look`.
    private func parts(_ look: KuroLook, _ idle: KuroIdle, at t: Double) -> Set<KuroPart> {
        Set(KuroFigure.parts(for: look, pose: KuroPose(look: look, energy: 50).idling((idle, t / idle.length))))
    }

    /// How far `part` moves `t` seconds into `idle` in `look`.
    private func shift(_ part: KuroPart, _ look: KuroLook, _ idle: KuroIdle, at t: Double) -> CGSize {
        KuroFigure.shift(part, pose: KuroPose(look: look, energy: 50).idling((idle, t / idle.length)))
    }

    @Test func eachBaseOutfitGetsItsTwoMoves() {
        #expect(KuroIdle.pool(.fitness).contains(.reach) && KuroIdle.pool(.fitness).contains(.towel))
        #expect(KuroIdle.pool(.art).contains(.tuck) && KuroIdle.pool(.art).contains(.frame))
        #expect(KuroIdle.pool(.study).contains(.collar) && KuroIdle.pool(.study).contains(.phone))
        #expect([KuroIdle.reach, .towel, .tuck, .frame, .collar, .phone].map(\.length) == [3, 2, 1.2, 2, 1.5, 2.5])
    }

    // 动作展示总表 §3-3: cards without a look of their own wear her tennis look and add their base outfit's moves.
    @Test func cardsWithoutALookStillGetTheirBaseMoves() {
        for card in [IdentityKind.swimming, .yoga, .ball] {
            #expect(KuroIdle.pool(.tennis, card: card).contains(.reach), "\(card)")
            #expect(KuroIdle.pool(.tennis, card: card).contains(.towel), "\(card)")
        }
        #expect(KuroIdle.pool(.tennis, card: .outdoor).contains(.collar))
        #expect(KuroIdle.pool(.tennis, card: .outdoor).contains(.phone))
        // Her own tennis card keeps its own moves only.
        #expect(KuroIdle.pool(.tennis, card: .tennis) == KuroIdle.pool(.tennis))
        #expect(KuroIdle.pool(.fitness, card: .fitness) == KuroIdle.pool(.fitness))
        // The racket goes down out of the frame first.
        #expect(shift(.tennisRacket, .tennis, .towel, at: 0.2).height > 10)
        #expect(!parts(.tennis, .phone, at: 1.2).contains(.tennisRacket))
    }

    @Test func herHandsAreFreeBeforeTheMove() {
        // The card prop slides down out of the frame first, then is gone while her hands are busy.
        #expect(shift(.gymBlock, .fitness, .reach, at: 0.2).height > 10)
        let reaching = parts(.fitness, .reach, at: 1.2)
        #expect(reaching.contains(.idleReach) && !reaching.contains(.gymBlock))
        let framing = parts(.art, .frame, at: 1)
        #expect(framing.contains(.idleFrameHands) && framing.isDisjoint(with: [.workTablet, .craftPen]))
        let phone = parts(.study, .phone, at: 1.2)
        #expect(phone.contains(.idlePhone) && phone.isDisjoint(with: [.studyNotebook, .studyHighlighter]))
        // And it comes back after.
        #expect(parts(.study, .phone, at: 2.49).contains(.studyNotebook))
    }

    @Test func onHerToesSheRisesButTheFloorStays() {
        #expect(shift(.faceBase, .fitness, .reach, at: 1.25).height < -3.5)
        #expect(shift(.itemFlower, .fitness, .reach, at: 1.25) == .zero)
        #expect(parts(.fitness, .reach, at: 1).contains(.eyesClosed))
    }

    @Test func eachMoveShowsItsOwnHandsAndFace() {
        #expect(parts(.fitness, .towel, at: 1).contains(.idleTowelWipe))
        let tuck = parts(.art, .tuck, at: 0.4)
        #expect(tuck.isSuperset(of: [.idleStrand, .idleTuckHand, .eyesDown]))
        #expect(!parts(.art, .tuck, at: 0.8).contains(.idleStrand))
        #expect(parts(.art, .frame, at: 1).contains(.eyesWink))
        #expect(parts(.study, .collar, at: 0.6).contains(.idleCollarHands))
        #expect(parts(.study, .phone, at: 1.2).contains(.mouthSmile))
        // Between moves nothing of them shows.
        let still = Set(KuroFigure.parts(for: .study, pose: KuroPose(look: .study, energy: 50)))
        #expect(still.isDisjoint(with: [.idlePhone, .idleCollarHands, .eyesWink]))
    }
}
