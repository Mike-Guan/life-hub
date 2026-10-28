import Foundation
import HubCore
import Testing

@testable import CompanionKit

// Identity cards, batch 1 (第 1 批身份卡 预览): HAKU dresses for the card the user picked.
@Suite struct RunnerCardLookTests {
    /// Every card with a look of its own.
    private let looks: [IdentityKind] = [
        .tennis, .fitness, .study, .art, .dance, .music, .ski, .swimming, .yoga, .ball, .outdoor,
    ]

    private func parts(_ mode: Mode, card: IdentityKind?) -> Set<RunnerPart> {
        Set(RunnerFigure.parts(for: mode, pose: RunnerPose(face: .mid).dressed(for: card, in: mode)))
    }

    @Test func theCardSlotDressesHakuForThePickedCard() {
        #expect(RunnerCardLook(card: .tennis) == .tennis)
        #expect(RunnerCardLook(card: .fitness) == .fitness)
        #expect(RunnerCardLook(card: .study) == .study)
        #expect(RunnerCardLook(card: .art) == .art)
        #expect(RunnerCardLook(card: .dance) == .dance)
        #expect(RunnerCardLook(card: .music) == .music)
        #expect(RunnerCardLook(card: .ski) == .ski)
        #expect(RunnerCardLook(card: .swimming) == .swimming)
        #expect(RunnerCardLook(card: .yoga) == .yoga)
        #expect(RunnerCardLook(card: .ball) == .ball)
        #expect(RunnerCardLook(card: .outdoor) == .outdoor)
        // No card or boxing keeps the boxing kit.
        for card: IdentityKind? in [nil, .boxing] {
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

    // Mike 2026-10-15: a card's own backdrop holds no items, so nothing stands on the floor or in the corner.
    @Test func cardBackdropsHoldNoItems() {
        for card in looks {
            for watch in [false, true] {
                let pose = RunnerPose().dressed(for: card, in: .boxing, watch: watch)
                #expect(pose.bagLift < 0, "\(card)")
                let shown = Set(RunnerFigure.parts(for: .boxing, pose: pose))
                #expect(shown.isDisjoint(with: [.gymBag, .danceSpeaker, .ukulele, .heavyBag]), "\(card)")
            }
        }
        let watch = RunnerPose().dressed(for: .fitness, in: .boxing, watch: true)
        #expect(Set(RunnerFigure.parts(for: .boxing, pose: watch)).contains(.handWeight))
    }

    @Test func eachCardLookDrawsItsOwnThings() {
        let expected: [IdentityKind: Set<RunnerPart>] = [
            .tennis: [.stripeSport, .tennisVisor, .tennisRacket, .racketHand, .tennisBall],
            .fitness: [.stripeSport, .handWeight],
            .study: [.stripeNeon, .book, .bookPage],
            .art: [.stripeNeon, .apron, .sketchbook, .pencil],
            .dance: [.stripeSport, .wristbandHand],
            .music: [.stripeNeon, .eyesWork],
            .ski: [.stripeSport, .wristbandHand, .skiGoggles],
            .swimming: [.stripeSport, .cheerGoggles],
            .yoga: [.stripeSport, .yogaMat, .matHand],
            .ball: [.stripeSport, .wristbandHand, .sportBall],
            .outdoor: [.stripeNeon, .outPack, .outStraps, .outPole, .poleFist],
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
        for card in looks {
            let dressed = pose.dressed(for: card, in: .boxing)
            let shown = Set(RunnerFigure.parts(for: .boxing, pose: dressed))
            #expect(shown.isDisjoint(with: RunnerCardLook(card: card)!.props), "\(card)")
            #expect(shown.contains(.stickyNote), "\(card)")
            #expect(dressed.bagLift < 0, "\(card)")
        }
    }

    // 顺延身份卡 (UI 审核 10/14): the watch draws no fist with the wristband.
    @Test func theWatchLeavesOutTheWristband() {
        for card: IdentityKind in [.dance, .ski, .ball] {
            let pose = RunnerPose().dressed(for: card, in: .boxing, watch: true)
            #expect(pose.watchFrame)
            let shown = Set(RunnerFigure.parts(for: .boxing, pose: pose))
            // The ball on the fist goes with it.
            #expect(shown.isDisjoint(with: [.wristbandHand, .sportBall]), "\(card)")
        }
    }

    private func beat(_ card: IdentityKind, at t: CGFloat) -> Set<RunnerPart> {
        var pose = RunnerPose(face: .mid).dressed(for: card, in: .boxing)
        pose.cardBeat = t
        return Set(RunnerFigure.parts(for: .boxing, pose: pose))
    }

    @Test func danceShrugsUntilHakuIsCaught() {
        #expect(beat(.dance, at: 0.5).contains(.eyesChill))
        #expect(beat(.dance, at: 1.3).isDisjoint(with: [.speakerNoteA, .speakerNoteB, .danceSpeaker]))
        // Caught: it stops and looks at you.
        let caught = beat(.dance, at: 2.8)
        #expect(!caught.contains(.eyesChill))
        #expect(caught.contains(.eyesWork))
    }

    @Test func musicPlaysAirChordsAndCountsSilently() {
        #expect(beat(.music, at: 0.4).isSuperset(of: [.chordHandA, .countMouth]))
        #expect(!beat(.music, at: 0.4).contains(.mouthSmile))
        #expect(beat(.music, at: 0.95).contains(.chordHandB))
        #expect(beat(.music, at: 0.95).isDisjoint(with: [.chordHandA, .countMouth]))
        #expect(beat(.music, at: 2.99).isDisjoint(with: [.chordHandA, .chordHandB]))
    }

    @Test func skiGogglesComeDownWithOneRightHand() {
        let pulling = beat(.ski, at: 1.2)
        #expect(pulling.contains(.goggleHand))
        #expect(!pulling.contains(.wristbandHand))
        // The lenses cover the eyes.
        #expect(!pulling.contains(.eyesChill))
        let breath = beat(.ski, at: 2.5)
        #expect(breath.isSuperset(of: [.breathPuff, .countMouth, .wristbandHand, .eyesChill]))
        #expect(!breath.contains(.goggleHand))
    }

    // 第2批 身份卡 (HAKU 第2批 说明): all four idles are 动态.
    @Test func swimmingGogglesComeDownOverEyesThatStillShow() {
        let down = beat(.swimming, at: 1.2)
        #expect(down.isSuperset(of: [.goggleHand, .cheerGoggles, .eyesClosed]))
        #expect(beat(.swimming, at: 0.8).contains(.eyesChill))
        // Pushed back up, the eyes squint.
        let up = beat(.swimming, at: 2.5)
        #expect(up.contains(.eyesWork) && !up.contains(.goggleHand))
    }

    @Test func yogaPressesThePalmsAndSwaysWhileTheMatStands() {
        let palms = beat(.yoga, at: 1.5)
        #expect(palms.isSuperset(of: [.yogaPalms, .yogaMat, .eyesClosed]))
        #expect(!palms.contains(.matHand))
        #expect(beat(.yoga, at: 3.2).contains(.eyesWork))
        #expect(beat(.yoga, at: 3.9).isSuperset(of: [.matHand, .yogaMat]))
        #expect(RunnerCardLook.yoga.move(.yogaMat, at: 1.2) == nil)
        #expect(RunnerCardLook.yoga.head(at: 1.3).tilt < -5)
    }

    @Test func theBallSpinsDropsAndComesBackToTheFist() {
        let spin = beat(.ball, at: 1.0)
        #expect(spin.isSuperset(of: [.cheerBallHand, .sportBall]))
        #expect(!spin.contains(.wristbandHand))
        let away = beat(.ball, at: 2.8)
        #expect(away.isSuperset(of: [.wristbandHand, .sportBall, .eyesWork]))
        // It ends where it started, on the fist.
        let end = RunnerCardLook.ball.move(.sportBall, at: 3.4)
        #expect(abs(end?.offset.width ?? 1) < 0.01 && abs(end?.offset.height ?? 1) < 0.01)
        // On the floor it stays inside the frame.
        let floor = RunnerCardLook.ball.move(.sportBall, at: 2.45)?.offset ?? .zero
        #expect(104.5 + 9 + floor.width < RunnerArt.bounds.maxX)
        #expect(106 + 9 + floor.height < RunnerArt.bounds.maxY)
    }

    @Test func outdoorShadesTheEyesWithThePoleLeaning() {
        let looking = beat(.outdoor, at: 1.5)
        #expect(looking.isSuperset(of: [.browHand, .outPole, .windGust, .eyesWork, .outPack]))
        #expect(!looking.contains(.poleFist))
        #expect(beat(.outdoor, at: 2.0).contains(.eyesClosed))
        #expect((RunnerCardLook.outdoor.move(.outPole, at: 1.5)?.angle ?? 0) < -10)
        #expect(beat(.outdoor, at: 3.5).isSuperset(of: [.poleFist, .outPole]))
        #expect(!beat(.outdoor, at: 3.5).contains(.browHand))
    }

    @Test func aWornBackpackStaysOnThroughTheShrug() {
        for t in stride(from: 0.0, to: 1.2, by: 0.1) {
            #expect(RunnerBaseIdle.hitchPack.move(.outPack, .outdoor, at: t)?.opacity == 1)
        }
    }

    @Test func theCardIdlePlaysNowAndThenOnlyWithFreeHands() {
        let times = stride(from: 0.0, to: 120, by: 0.25)
        let beats = times.map { RunnerPose(face: .mid).dressed(for: .dance, in: .boxing, time: $0).cardBeat }
        #expect(beats.contains { $0 >= 0 })
        #expect(beats.contains { $0 < 0 })
        var busy = RunnerPose(face: .mid)
        busy.dailyProp = .note
        #expect(times.allSatisfy { busy.dressed(for: .dance, in: .boxing, time: $0).cardBeat < 0 })
        // A look without its own idle still plays its base outfit's moves.
        #expect(times.contains { RunnerPose(face: .mid).dressed(for: .tennis, in: .boxing, time: $0).baseIdle != nil })
    }

    // 动作展示总表 C12: the boxing idle's slip and glove bump never play over a card look's idles.
    @Test func aCardLookSkipsTheBoxingIdle() {
        let times = Array(stride(from: 0.0, to: 600, by: 0.05))
        func boxing(_ pose: RunnerPose) -> Bool {
            pose.shift != 0 || pose.lean != 0 || pose.puff || pose.gloveL.width != 0
        }
        func pose(_ card: IdentityKind?, at t: Double) -> RunnerPose {
            RunnerPose(mode: .boxing, time: t, face: .mid, card: card, react: 0)
                .dressed(for: card, in: .boxing, time: t)
        }
        #expect(times.contains { boxing(pose(nil, at: $0)) })
        for card in IdentityKind.allCases where RunnerCardLook(card: card) != nil {
            #expect(times.contains { pose(card, at: $0).cardBeat >= 0 })
            #expect(!times.contains { boxing(pose(card, at: $0)) })
        }
    }

    private func base(_ card: IdentityKind, _ idle: RunnerBaseIdle, at t: CGFloat) -> Set<RunnerPart> {
        var pose = RunnerPose(face: .mid).dressed(for: card, in: .boxing)
        pose.cardBeat = t
        pose.baseIdle = idle
        return Set(RunnerFigure.parts(for: .boxing, pose: pose))
    }

    // 待机动作 补齐规格 v0 H6-H11: each base outfit has its two moves.
    @Test func eachBaseOutfitHasItsTwoMoves() {
        #expect(RunnerBaseIdle.pool(.fitness) == [.stretch, .drink])
        #expect(RunnerBaseIdle.pool(.study) == [.checkWrist, .hitchPack])
        #expect(RunnerBaseIdle.pool(.art) == [.twirlPencil, .wipeHands])
        // They share the stream with the look's own idle.
        let moves = Set(
            stride(from: 0.0, to: 2400, by: 0.5).compactMap {
                RunnerPose(face: .mid).dressed(for: .dance, in: .boxing, time: $0).baseIdle
            })
        #expect(moves == [.stretch, .drink])
    }

    @Test func heldThingsGoDownBeforeTheHandsMove() {
        // At the start the dumbbell is still in hand and nothing new shows.
        let start = base(.fitness, .stretch, at: 0)
        #expect(start.contains(.handWeight))
        #expect(start.isDisjoint(with: [.crossArm, .crossArmL]))
        // Then it is down out of the frame while the arm crosses.
        let crossing = (0..<30).map { base(.fitness, .stretch, at: CGFloat($0) / 10) }
        #expect(crossing.contains { $0.contains(.crossArm) && !$0.contains(.handWeight) })
        #expect(crossing.contains { $0.isSuperset(of: [.crossArmL, .wristbandPull]) })
        // The fist with the wristband is the hand itself, so it stays until the arm crosses.
        #expect(base(.dance, .stretch, at: 0).contains(.wristbandHand))
    }

    @Test func drinkingTakesTheCapOffAndShutsTheEyes() {
        let frames = (0...25).map { base(.ski, .drink, at: CGFloat($0) / 10) }
        // A hand always shows, and the bottle only in the fist.
        #expect(frames.allSatisfy { $0.contains(.wristbandHand) != $0.contains(.bottleFist) })
        #expect(frames.allSatisfy { $0.contains(.waterBottle) == $0.contains(.bottleFist) })
        #expect(frames.first?.contains(.wristbandHand) == true)
        #expect(frames.last?.contains(.wristbandHand) == true)
        #expect(frames.contains { $0.contains(.eyesClosed) && !$0.contains(.bottleCap) })
        #expect(frames.contains { $0.isSuperset(of: [.waterBottle, .bottleCap]) })
    }

    @Test func outMovesLookAtTheWristAndShrugTheBackpack() {
        let wrist = (0..<15).map { base(.study, .checkWrist, at: CGFloat($0) / 10) }
        #expect(wrist.contains { $0.contains(.wristArm) && !$0.contains(.book) })
        let pack = (0..<12).map { base(.music, .hitchPack, at: CGFloat($0) / 10) }
        #expect(pack.allSatisfy { $0.isSuperset(of: [.outPack, .outStraps]) })
        #expect(pack.contains { $0.contains(.eyesClosed) })
        let shrug = stride(from: 0.0, to: 1.2, by: 0.05).map { RunnerBaseIdle.hitchPack.shrug(.music, at: $0) }
        #expect((shrug.min() ?? 0) < -3.5)
        #expect(shrug.first == 0)
    }

    @Test func thePencilDropsAndComesBackAtTheEnd() {
        let twirl = RunnerBaseIdle.twirlPencil
        #expect(base(.art, twirl, at: 0.5).contains(.pencil))
        let dropped = base(.art, twirl, at: 1.6)
        #expect(dropped.isSuperset(of: [.pencilLoose, .chinHand]) && !dropped.contains(.pencil))
        // The sketchbook stays in the other hand.
        #expect(dropped.contains(.sketchbook))
        #expect(base(.art, twirl, at: 1.95).contains(.pencil))
        let wipe = (0..<15).map { base(.art, .wipeHands, at: CGFloat($0) / 10) }
        #expect(wipe.contains { $0.contains(.paintHand) && $0.isDisjoint(with: [.sketchbook, .pencil]) })
    }
}
