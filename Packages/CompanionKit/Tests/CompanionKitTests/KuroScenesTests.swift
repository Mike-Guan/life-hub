import Foundation
import HubCore
import Testing

@testable import CompanionKit

// KURO 三个场景 规格 v0 (PM 2026-10-13): HAKU had the invite, the walk and the bath call; she had none.
@Suite struct KuroScenesTests {
    static func parts(_ look: KuroLook, _ scene: KuroScene?, items: Set<KuroItem> = []) -> [KuroPart] {
        var pose = KuroPose(look: look, energy: 50)
        pose.items = items
        pose.scene = scene
        return KuroFigure.parts(for: look, pose: pose)
    }

    /// The box `part` covers, leaving out see-through light like the lamp's glow.
    static func box(_ part: KuroPart) -> CGRect {
        KuroArt.inks(part).filter { $0.opacity == 1 }.map { $0.path.boundingRect }.reduce(CGRect.null) { $0.union($1) }
    }

    @Test(arguments: KuroLook.allCases)
    func everySceneChangesHerBody(_ look: KuroLook) {
        let rest = Self.parts(look, nil)
        let scenes: [KuroScene] = [
            .invite(time: 1), .walking(from: .home, time: 0, lookingBack: false), .bath(time: 0.5), .dried(time: 1),
        ]
        for scene in scenes { #expect(Self.parts(look, scene) != rest, "\(look) \(scene)") }
    }

    @Test(arguments: KuroLook.allCases)
    func shePointsAtTheDoorInHerOwnSleeveThenStands(_ look: KuroLook) {
        let pointing = Self.parts(look, .invite(time: 1))
        #expect(pointing.contains(.inviteHand) && pointing.contains(KuroScene.sleeve(look)))
        #expect(pointing.filter { "\($0)".hasPrefix("inviteSleeve") }.count == 1)
        #expect(!Self.parts(look, .invite(time: 0.1)).contains(.inviteHand))
        #expect(!Self.parts(look, .invite(time: 3)).contains(.inviteHand))
        // She looks toward the door on the left while pointing, and back at you after.
        #expect(KuroScene.invite(time: 1).shift(.eyesOpen).width < 0)
        #expect(KuroScene.invite(time: 3).shift(.eyesOpen).width == 0)
    }

    // 位置规划图 v0 §10: her pointing hand must not touch the room items in the left corner.
    @Test func thePointingHandMissesTheRoomCorner() {
        let step = KuroScene.invite(time: 1).shift(.inviteHand).width
        #expect(step == KuroScene.inviteStep)
        // Her lean turns the hand about 1.5 units further left; the boxes keep more room than that.
        let hand = Self.box(.inviteHand).offsetBy(dx: step - 1.5, dy: 0)
        for item in [KuroPart.itemFlower, .itemLamp, .itemBag] { #expect(!hand.intersects(Self.box(item)), "\(item)") }
    }

    @Test func walkingPutsDownWhatSheHoldsAndCarriesHerThings() {
        let home = Self.parts(.chill, .walking(from: .home, time: 0, lookingBack: false), items: [.flower])
        #expect(home.contains(.walkPack) && home.contains(.walkStraps) && home.contains(.walkDust))
        #expect(!home.contains(.chillCup) && !home.contains(.itemFlower))
        let office = Self.parts(.work, .walking(from: .office, time: 0, lookingBack: false))
        #expect(office.contains(.walkTabletHands) && office.contains(.workTablet) && !office.contains(.workStylus))
        // The tennis bag is from her shop: she carries it only when she owns it.
        let court = KuroScene.walking(from: .custom, time: 0, lookingBack: false)
        #expect(Self.parts(.tennis, court, items: [.bag]).contains(.itemBag))
        #expect(!Self.parts(.tennis, court).contains(.itemBag) && Self.parts(.tennis, court).contains(.walkPack))
        #expect(!Self.parts(.tennis, court).contains(.tennisRacket))
    }

    @Test func aTapWhileWalkingTurnsHerEyesToYou() {
        #expect(KuroScene.walking(from: .home, time: 0, lookingBack: false).shift(.eyesOpen).width > 0)
        #expect(KuroScene.walking(from: .home, time: 0, lookingBack: true).shift(.eyesOpen).width == 0)
        #expect(KuroScene.walkLine(from: .office) == "お疲れ。……走了。")
    }

    @Test func theBathCallWalksOffLeavesBubblesAndComesBack() {
        #expect(KuroScene.bath(time: 0).dx == 0)
        #expect(KuroScene.bath(time: 2).dx == KuroScene.bathEdge)
        #expect(KuroScene.bath(time: 4.5).dx > 140)
        #expect(KuroScene.bath(time: 6).dx == 0)
        // She leaves and comes back on the right, and stays put until her 3 s line is over.
        #expect(KuroScene.bath(time: 5.7).dx > 0)
        #expect(KuroScene.bath(time: KuroScene.bathLineAt + 2.99).dx == KuroScene.bathEdge)
        // She stays in the frame while she says her line.
        #expect(KuroScene.bath(time: KuroScene.bathLineAt).dx + 95 < 134)
        #expect(Self.parts(.chill, .bath(time: 4.8)).contains(.bathBubbles))
        #expect(!Self.parts(.chill, .bath(time: 2)).contains(.bathBubbles))
        #expect(Self.parts(.chill, .bath(time: 2)).contains(.bathBundle))
        #expect(!Self.parts(.chill, .bath(time: 2)).contains(.chillCup))
    }

    @Test func washedSheWearsATowelInsteadOfHerCatEars() {
        let dried = Self.parts(.chill, .dried(time: 1))
        #expect(dried.contains(.bathTurban) && dried.contains(.bathTurbanHands) && !dried.contains(.catEars))
        #expect(KuroScene.dried(time: 0.2).eyes == .happy && KuroScene.dried(time: 2).eyes == .open)
        // Drawn over her fringe, so the towel covers it.
        #expect((dried.firstIndex(of: .hairFringe) ?? 99) < (dried.firstIndex(of: .bathTurban) ?? 0))
    }
}
