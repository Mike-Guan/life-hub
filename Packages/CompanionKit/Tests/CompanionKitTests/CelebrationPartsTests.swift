import Foundation
import HubCore
import Testing

@testable import CompanionKit

// QA S4 (Mike's bug G4): a boxing celebration grew a third hand making a peace sign. A celebration may add only
// the parts in its own row below; anything else it draws on top of the idle pose fails.
@Suite struct CelebrationPartsTests {
    /// What each workout's celebration may add to HAKU.
    static let hakuAllows: [WorkoutSummary.Kind: Set<RunnerPart>] = [
        .boxing: [.gloveL, .gloveR],
        .running: [.peaceHand],
        .strength: [.dumbbell],
        .walking: [.towel, .dropsL, .dropsR, .mouthYawn, .cheerLegLines, .eyesClosed],
        .cycling: [.eyesSleepy, .cheerHelmet],
        .swimming: [.cheerGoggles, .cheerEarTap, .cheerSplash, .eyesClosed],
        .martialArts: [.cateyeL, .cateyeR, .browsBox, .mouthFang, .cheerKick],
        .racket: [.cheerRacket],
        .ball: [.cheerBallHand, .cheerBall],
        .yoga: [.cheerStretchArms, .cheerCrack, .eyesClosed],
        .dance: [.cheerNotes, .eyesClosed],
        .outdoor: [.cheerMountains, .cheerWind],
        .other: [],
    ]
    /// What every HAKU celebration may add: the sparkle burst and the glint in the eye.
    static let hakuSparkles: Set<RunnerPart> = [.sparkle, .eyeGlint]
    /// What cheering the day's focus done may add: the pumped fist with the eyes shut.
    static let focusAllows: Set<RunnerPart> = [.backFist, .eyesClosed]
    /// What KURO's celebration, her look's tap move, may add besides her face and the heart.
    static let kuroAllows: [KuroLook: Set<KuroPart>] = [
        .work: [.tapTablet],
        .chill: [.tapCup, .tapPuff],
        .tennis: [.tapBall, .tapSparkle],
        .desk: [.tapFinger, .tapGlint],
        .box: [], .fitness: [], .study: [.studyMark], .art: [],
    ]
    static let kuroFace: Set<KuroPart> = [
        .eyesOpen, .eyesClosed, .eyesDrowsy, .eyesBright, .eyesDown, .eyesHappy, .eyesSurprised, .eyesLow,
        .mouthCat, .mouthFlat, .mouthSmile, .mouthO, .tapHeart,
    ]
    static let keepsake = Outfit(Wardrobe(equipped: [.celebration: "celebrate.up"]))
    static let steps = (0..<20).map { CGFloat($0) / 20 }

    @Test(arguments: Mode.allCases)
    func hakusCelebrationsAddOnlyTheirOwnParts(_ mode: Mode) {
        for outfit in [Outfit(), Self.keepsake] {
            let rest = RunnerPose(mode: mode, time: 1, face: .mid, react: 0).wearing(outfit)
            let still = Set(RunnerFigure.parts(for: mode, pose: rest))
            let keepsake: Set<RunnerPart> = outfit.peaceSign ? [.peaceHand] : []
            for kind in WorkoutSummary.Kind.allCases {
                let allowed = (Self.hakuAllows[kind] ?? []).union(Self.hakuSparkles).union(keepsake)
                for progress in Self.steps {
                    var cheer = rest
                    cheer.celebrate(kind, progress: progress)
                    let added = Set(RunnerFigure.parts(for: mode, pose: cheer)).subtracting(still)
                    #expect(added.isSubset(of: allowed), "\(mode) \(kind): \(added.subtracting(allowed))")
                    Self.expectTwoHands(Set(RunnerFigure.parts(for: mode, pose: cheer)))
                }
            }
            // A planned task done cheers with the run's peace sign, or pumps a fist for the day's focus.
            let allowed = Self.focusAllows.union(Self.hakuSparkles).union(keepsake)
            for progress in Self.steps {
                var focus = rest
                focus.cheerFocus(progress: Double(progress))
                let added = Set(RunnerFigure.parts(for: mode, pose: focus)).subtracting(still)
                #expect(added.isSubset(of: allowed), "\(mode) focus: \(added.subtracting(allowed))")
            }
        }
    }

    // Moved from CompanionKitTests: Mike 2026-10-07, a boxing celebration showed a peace sign next to both gloves.
    @Test(arguments: Mode.allCases)
    func glovesNeverGetAThirdHand(_ mode: Mode) {
        var cheer = RunnerPose().wearing(Self.keepsake)
        cheer.celebrate(.boxing, progress: 0.5)
        var daily = RunnerPose()
        daily.celebrate(.running, progress: 0.5)
        for pose in [cheer, daily, RunnerPose(mode: .boxing, time: 1, face: .mid, react: 0)] {
            Self.expectTwoHands(Set(RunnerFigure.parts(for: mode, pose: pose)))
        }
        #expect(!RunnerFigure.parts(for: .boxing, pose: daily).contains(.peaceHand))
    }

    @Test(arguments: KuroLook.allCases)
    func kurosCelebrationAddsOnlyHerMoveAndTheHeart(_ look: KuroLook) throws {
        let rest = KuroPose(look: look, energy: 50)
        let still = Set(KuroFigure.parts(for: look, pose: rest))
        let allowed = try #require(Self.kuroAllows[look]).union(Self.kuroFace)
        // KuroView plays her look's tap move with the heart for every workout.
        let tap = KuroTap(look: look, sleepy: false)
        for progress in Self.steps {
            let pose = rest.reacting(tap, progress: Double(progress), heart: true)
            let added = Set(KuroFigure.parts(for: look, pose: pose)).subtracting(still)
            #expect(added.isSubset(of: allowed), "\(look): \(added.subtracting(allowed))")
        }
    }

    /// Checks that gloves, which fill both hands, never come with the peace sign hand.
    static func expectTwoHands(_ parts: Set<RunnerPart>) {
        if !parts.isDisjoint(with: [.gloveL, .gloveR]) { #expect(!parts.contains(.peaceHand)) }
    }
}
