import Foundation
import HubCore
import Testing

@testable import CompanionKit

// Identity cards, batch 1 (第 1 批身份卡 预览): the second character dresses for the card the user picked.
@Suite struct KuroCardsTests {
    @Test func theCardSlotDressesHerForThePickedCard() {
        #expect(KuroLook(mode: .boxing, card: .boxing) == .box)
        #expect(KuroLook(mode: .boxing, card: .fitness) == .fitness)
        #expect(KuroLook(mode: .boxing, card: .study) == .study)
        #expect(KuroLook(mode: .boxing, card: .art) == .art)
        #expect(KuroLook(mode: .boxing, card: .tennis) == .tennis)
        // No card, or one she has no look for yet, keeps her tennis day.
        #expect(KuroLook(mode: .boxing) == .tennis && KuroLook(mode: .boxing, card: .swimming) == .tennis)
        // The card only changes the card slot.
        #expect(KuroLook(mode: .work, card: .boxing) == .work && KuroLook(mode: .money, card: .art) == .desk)
    }

    @Test func eachCardLookDrawsItsOwnThings() {
        let expected: [KuroLook: Set<KuroPart>] = [
            .box: [.jacketBox, .boxHeadband, .boxGloveL, .boxGloveR, .boxSandbag],
            .fitness: [.jacketTennis, .gymBlock, .tennisPonytail],
            .study: [.jacketChill, .studyNotebook, .studyHighlighter],
            .art: [.jacketSmock, .workTablet, .craftPen],
        ]
        for (look, things) in expected {
            let parts = Set(KuroFigure.parts(for: look, pose: KuroPose(look: look, energy: 50)))
            #expect(parts.isSuperset(of: things), "\(look)")
            // Her tennis racket, cup and glasses stay with their own looks.
            #expect(parts.isDisjoint(with: [.tennisRacket, .chillCup, .deskGlasses, .tennisHeadband]), "\(look)")
        }
    }

    @Test func thePunchGoesOutToHerSideAndBack() {
        let pose = KuroPose(look: .box, energy: 50)
        let out = KuroFigure.shift(.boxGloveR, pose: pose.reacting(.punch, progress: 0.4))
        #expect(out.width > 0 && out.height < 0)
        #expect(KuroFigure.shift(.boxGloveR, pose: pose.reacting(.punch, progress: 0.05)) == .zero)
        #expect(KuroFigure.shift(.boxGloveR, pose: pose.reacting(.punch, progress: 0.95)) == .zero)
        #expect(pose.reacting(.punch, progress: 0.05).eyes == .surprised)
    }

    @Test func eachCardHasItsOwnIdleMove() {
        #expect(KuroIdle.pool(.box) == [.ears, .strap, .gloves])
        #expect(KuroIdle.pool(.fitness).contains(.lap))
        #expect(KuroIdle.pool(.study).contains(.highlight))
        #expect(KuroIdle.pool(.art).contains(.draw))
        // The strap flips up only on the boxing look's left glove.
        let pose = KuroPose(look: .box, energy: 50).idling((.strap, 0.1))
        #expect(KuroFigure.parts(for: .box, pose: pose).contains(.boxStrap))
    }
}
