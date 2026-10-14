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

    @Test func aTapOnTheBoxingCardTapsTheGlovesTogether() {
        let pose = KuroPose(look: .box, energy: 50)
        #expect(pose.reacting(.bump, progress: 0.05).eyes == .surprised)
        #expect(KuroFigure.shift(.boxGloveL, pose: pose.reacting(.bump, progress: 0.05)) == .zero)
        // The gloves meet at a quarter of the way through what follows the start.
        let met = pose.reacting(.bump, progress: 0.15 + 0.85 / 8)
        #expect(KuroFigure.shift(.boxGloveL, pose: met).width > 3 && KuroFigure.shift(.boxGloveR, pose: met).width < -3)
        #expect(met.eyes == .closed)
    }

    // Mike 10/14 (第 1 批身份卡 第 3 轮): boxing is an ordinary card for her; tennis has the new moves.
    @Test func eachCardHasItsOwnIdleMove() {
        #expect(KuroIdle.pool(.box) == [.ears, .gloves, .ponytail])
        #expect(KuroIdle.pool(.fitness).contains(.lap))
        #expect(KuroIdle.pool(.study).contains(.highlight))
        #expect(KuroIdle.pool(.art).contains(.draw))
        #expect(KuroIdle.pool(.tennis) == [.ears, .racket, .ponytail, .juggle, .twirl])
    }
}
