import Foundation
import Testing

@testable import CompanionKit

@Suite struct PartnerTests {
    @Test(arguments: PartnerPart.allCases)
    func everyPartHasArt(_ part: PartnerPart) {
        #expect(!PartnerArt.inks(part).isEmpty)
        #expect(PartnerArt.cachedInks(part).count == PartnerArt.inks(part).count)
    }

    @Test func herEyesAreClippedWithAGradientIris() {
        let inks = PartnerArt.inks(.eyesOpen)
        #expect(inks.filter { $0.gradient != nil }.count == 2)
        #expect(inks.filter { $0.clip != nil }.count == 4)
    }

    @Test(arguments: PartnerLook.allCases)
    func eachLookShowsOnlyItsOwnOutfit(_ look: PartnerLook) {
        let parts = Set(PartnerFigure.parts(for: look, pose: PartnerPose(look: look, energy: nil)))
        let jackets: [PartnerLook: PartnerPart] = [
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
        let work = Set(PartnerFigure.parts(for: .work, pose: PartnerPose(look: .work, energy: nil)))
        #expect(work.isDisjoint(with: [.mouthCat, .mouthFlat, .mouthSmile, .mouthO]))
        let tennis = Set(PartnerFigure.parts(for: .tennis, pose: PartnerPose(look: .tennis, energy: nil)))
        #expect(tennis.contains(.mouthSmile))
        let chill = Set(PartnerFigure.parts(for: .chill, pose: PartnerPose(look: .chill, energy: nil)))
        #expect(chill.contains(.mouthCat))
    }

    @Test func energyPicksHerFace() {
        #expect(PartnerPose(look: .chill, energy: nil).eyes == .open)
        #expect(PartnerPose(look: .tennis, energy: 50).eyes == .bright)
        #expect(PartnerPose(look: .desk, energy: 50).eyes == .down)
        #expect(PartnerPose(look: .chill, energy: 80).eyes == .bright)
        let low = PartnerPose(look: .chill, energy: 10)
        #expect(low.eyes == .low && low.tired)
        let parts = Set(PartnerFigure.parts(for: .chill, pose: low))
        #expect(parts.contains(.eyesLow) && parts.contains(.mouthFlat) && !parts.contains(.blush))
    }

    @Test func sheBlinksEveryFourAndAHalfSecondsUnlessTired() {
        let pose = PartnerPose(look: .chill, energy: nil)
        #expect(pose.blink(at: 9.05).blinking)
        #expect(!pose.blink(at: 9.5).blinking)
        #expect(!PartnerPose(look: .chill, energy: 10).blink(at: 9.05).blinking)
        let parts = PartnerFigure.parts(for: .chill, pose: pose.blink(at: 0.05))
        #expect(parts.contains(.eyesClosed) && !parts.contains(.eyesOpen))
    }

    @Test(arguments: PartnerEyes.allCases)
    func everyFaceShowsOneSetOfEyes(_ eyes: PartnerEyes) {
        let parts = PartnerFigure.parts(for: .chill, pose: PartnerPose(look: .chill, energy: nil).showing(eyes))
        let eyeParts: Set<PartnerPart> = [
            .eyesOpen, .eyesClosed, .eyesDrowsy, .eyesBright, .eyesDown, .eyesHappy, .eyesSurprised, .eyesLow,
        ]
        #expect(parts.filter { eyeParts.contains($0) }.count == 1)
    }

    @Test(arguments: PartnerLook.allCases)
    func partsKeepDrawingOrder(_ look: PartnerLook) {
        let parts = PartnerFigure.parts(for: look, pose: PartnerPose(look: look, energy: nil))
        let order = parts.compactMap { PartnerPart.allCases.firstIndex(of: $0) }
        #expect(order == order.sorted())
    }

    @Test func sheSharesHakusFrame() {
        #expect(PartnerArt.bounds == RunnerArt.bounds)
    }
}
