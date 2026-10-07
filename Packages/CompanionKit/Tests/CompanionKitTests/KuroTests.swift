import Foundation
import HubCore
import Testing

@testable import CompanionKit

@Suite struct KuroTests {
    @Test(arguments: KuroPart.allCases)
    func everyPartHasArt(_ part: KuroPart) {
        #expect(!KuroArt.inks(part).isEmpty)
        #expect(KuroArt.cachedInks(part).count == KuroArt.inks(part).count)
    }

    @Test func herEyesAreClippedWithAGradientIris() {
        let inks = KuroArt.inks(.eyesOpen)
        #expect(inks.filter { $0.gradient != nil }.count == 2)
        #expect(inks.filter { $0.clip != nil }.count == 4)
    }

    @Test(arguments: KuroLook.allCases)
    func eachLookShowsOnlyItsOwnOutfit(_ look: KuroLook) {
        let parts = Set(KuroFigure.parts(for: look, pose: KuroPose(look: look, energy: nil)))
        let jackets: [KuroLook: KuroPart] = [
            .work: .jacketWork, .chill: .jacketChill, .tennis: .jacketTennis, .desk: .jacketDesk,
        ]
        #expect(parts.intersection(Set(jackets.values)) == [jackets[look]!])
        #expect(parts.isSuperset(of: [.hairBack, .faceBase, .hairFringe, .catEars, .blush]))
        #expect(parts.contains(.maskWork) == (look == .work))
        #expect(parts.contains(.tennisPonytail) == (look == .tennis))
        #expect(parts.contains(.deskGlasses) == (look == .desk))
        #expect(parts.contains(.chillCup) == (look == .chill))
    }

    @Test func theMaskHidesHerMouthAtWork() {
        let work = Set(KuroFigure.parts(for: .work, pose: KuroPose(look: .work, energy: nil)))
        #expect(work.isDisjoint(with: [.mouthCat, .mouthFlat, .mouthSmile, .mouthO]))
        let tennis = Set(KuroFigure.parts(for: .tennis, pose: KuroPose(look: .tennis, energy: nil)))
        #expect(tennis.contains(.mouthSmile))
        let chill = Set(KuroFigure.parts(for: .chill, pose: KuroPose(look: .chill, energy: nil)))
        #expect(chill.contains(.mouthCat))
    }

    @Test func energyPicksHerFace() {
        #expect(KuroPose(look: .chill, energy: nil).eyes == .open)
        #expect(KuroPose(look: .tennis, energy: 50).eyes == .bright)
        #expect(KuroPose(look: .desk, energy: 50).eyes == .down)
        #expect(KuroPose(look: .chill, energy: 80).eyes == .bright)
        let low = KuroPose(look: .chill, energy: 10)
        #expect(low.eyes == .low && low.tired)
        let parts = Set(KuroFigure.parts(for: .chill, pose: low))
        #expect(parts.contains(.eyesLow) && parts.contains(.mouthFlat) && !parts.contains(.blush))
    }

    @Test func sheBlinksEveryFourAndAHalfSecondsUnlessTired() {
        let pose = KuroPose(look: .chill, energy: nil)
        #expect(pose.blink(at: 9.05).blinking)
        #expect(!pose.blink(at: 9.5).blinking)
        #expect(!KuroPose(look: .chill, energy: 10).blink(at: 9.05).blinking)
        let parts = KuroFigure.parts(for: .chill, pose: pose.blink(at: 0.05))
        #expect(parts.contains(.eyesClosed) && !parts.contains(.eyesOpen))
    }

    @Test(arguments: KuroEyes.allCases)
    func everyFaceShowsOneSetOfEyes(_ eyes: KuroEyes) {
        let parts = KuroFigure.parts(for: .chill, pose: KuroPose(look: .chill, energy: nil).showing(eyes))
        let eyeParts: Set<KuroPart> = [
            .eyesOpen, .eyesClosed, .eyesDrowsy, .eyesBright, .eyesDown, .eyesHappy, .eyesSurprised, .eyesLow,
        ]
        #expect(parts.filter { eyeParts.contains($0) }.count == 1)
    }

    @Test(arguments: KuroLook.allCases)
    func partsKeepDrawingOrder(_ look: KuroLook) {
        let parts = KuroFigure.parts(for: look, pose: KuroPose(look: look, energy: nil))
        let order = parts.compactMap { KuroPart.allCases.firstIndex(of: $0) }
        #expect(order == order.sorted())
    }

    @Test func modesPickHerLooks() {
        #expect(Mode.allCases.map(KuroLook.init(mode:)) == [.work, .chill, .tennis, .desk])
    }

    @Test func bedtimeMakesHerSleepy() {
        let pose = KuroPose(look: .tennis, energy: 90, bedtime: .on)
        #expect(pose.eyes == .drowsy && !pose.blink(at: 0.05).blinking)
        #expect(KuroFigure.parts(for: .tennis, pose: pose).contains(.eyesDrowsy))
        #expect(KuroView.accessibilityLabel(.tennis, bedtime: .on) == "KURO 困了")
    }

    @Test func sheSharesHakusFrame() {
        #expect(KuroArt.bounds == RunnerArt.bounds)
    }
}
