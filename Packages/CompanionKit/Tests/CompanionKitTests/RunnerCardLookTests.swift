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
        #expect(RunnerCardLook(card: .dance) == .dance)
        #expect(RunnerCardLook(card: .music) == .music)
        #expect(RunnerCardLook(card: .ski) == .ski)
        // No card, boxing, or a card without a look yet keeps the boxing kit.
        for card: IdentityKind? in [nil, .boxing, .swimming, .yoga] {
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
        for card: IdentityKind in [.tennis, .fitness, .study, .art, .dance, .music, .ski] {
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
        for card: IdentityKind in [.tennis, .fitness, .study, .art, .dance, .music, .ski] {
            let dressed = pose.dressed(for: card, in: .boxing)
            let shown = Set(RunnerFigure.parts(for: .boxing, pose: dressed))
            #expect(shown.isDisjoint(with: RunnerCardLook(card: card)!.props), "\(card)")
            #expect(shown.contains(.stickyNote), "\(card)")
            #expect(dressed.bagLift < 0, "\(card)")
        }
    }

    // 顺延身份卡 (UI 审核 10/14): the watch draws no fist with the wristband.
    @Test func theWatchLeavesOutTheWristband() {
        for card: IdentityKind in [.dance, .ski] {
            let pose = RunnerPose().dressed(for: card, in: .boxing, watch: true)
            #expect(pose.watchFrame)
            #expect(!Set(RunnerFigure.parts(for: .boxing, pose: pose)).contains(.wristbandHand), "\(card)")
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

    @Test func theCardIdlePlaysNowAndThenOnlyWithFreeHands() {
        let times = stride(from: 0.0, to: 120, by: 0.25)
        let beats = times.map { RunnerPose(face: .mid).dressed(for: .dance, in: .boxing, time: $0).cardBeat }
        #expect(beats.contains { $0 >= 0 })
        #expect(beats.contains { $0 < 0 })
        var busy = RunnerPose(face: .mid)
        busy.dailyProp = .note
        #expect(times.allSatisfy { busy.dressed(for: .dance, in: .boxing, time: $0).cardBeat < 0 })
        // Looks without their own idle yet stay still.
        #expect(times.allSatisfy { RunnerPose(face: .mid).dressed(for: .tennis, in: .boxing, time: $0).cardBeat < 0 })
    }

    // 动作展示总表 C12: the boxing idle's slip and glove bump never play over a card look's own idle.
    @Test func aCardWithItsOwnIdleSkipsTheBoxingIdle() {
        let times = Array(stride(from: 0.0, to: 600, by: 0.05))
        func boxing(_ pose: RunnerPose) -> Bool {
            pose.shift != 0 || pose.lean != 0 || pose.puff || pose.eyesDy != 0 || pose.gloveL.width != 0
        }
        func pose(_ card: IdentityKind?, at t: Double) -> RunnerPose {
            RunnerPose(mode: .boxing, time: t, face: .mid, card: card, react: 0)
                .dressed(for: card, in: .boxing, time: t)
        }
        #expect(times.contains { boxing(pose(nil, at: $0)) })
        #expect(times.contains { boxing(pose(.tennis, at: $0)) })
        for card in [IdentityKind.dance, .music, .ski] {
            #expect(times.contains { pose(card, at: $0).cardBeat >= 0 })
            #expect(!times.contains { boxing(pose(card, at: $0)) })
        }
    }
}
