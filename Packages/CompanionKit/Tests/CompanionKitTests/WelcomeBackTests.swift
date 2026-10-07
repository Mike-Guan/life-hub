import Foundation
import HubCore
import Testing

@testable import CompanionKit

@Suite struct WelcomeBackTests {
    let cards = [
        ReturnCard(kind: .boxing, count: 2, text: "打了 2 次拳。"),
        ReturnCard(kind: .sleptWell, count: 3, text: "有几天睡得挺好。"),
        ReturnCard(kind: .trace, count: 1, item: CompanionTrace.runningShoes.rawValue, text: "门口多了双跑鞋。"),
    ]

    @Test func theSceneFollowsTheTierAndTheMode() {
        let box = ReturnReplay(tier: .box, cards: cards, cans: 9)
        #expect(WelcomeScene(box, mode: .chill) == .sofa)
        #expect(WelcomeScene(box, mode: .boxing) == .sofa)
        #expect(WelcomeScene(box, mode: .work) == .desk)
        #expect(WelcomeScene(ReturnReplay(tier: .glance, cards: cards, cans: 9), mode: .work) == .glance)
        #expect(WelcomeScene(ReturnReplay(tier: .box, cards: [], cans: 0), mode: .work) == .quiet)
    }

    @Test func cardsFlipOneByOneThenTheCrateOpens() {
        let open = WelcomeScene.sofa.open(cards: 3, cans: 9)
        #expect(open == 6 + 3 * WelcomeScene.cardGap + 0.2)
        #expect(WelcomeScene.sofa.length(cards: 3, cans: 9) == (open ?? 0) + 3.3)
        #expect(WelcomeScene.sofa.card(at: 5.9, count: 3, open: open) == nil)
        #expect(WelcomeScene.sofa.card(at: 6, count: 3, open: open) == 0)
        #expect(WelcomeScene.sofa.card(at: 6 + WelcomeScene.cardGap, count: 3, open: open) == 1)
        #expect(WelcomeScene.sofa.card(at: open ?? 0, count: 3, open: open) == nil)
        // No cans: the crate stays shut and the last card stays up.
        #expect(WelcomeScene.desk.open(cards: 3, cans: 0) == nil)
        #expect(WelcomeScene.desk.card(at: 30, count: 3, open: nil) == 2)
        #expect(WelcomeScene.glance.open(cards: 3, cans: 9) == nil)
        #expect(WelcomeScene.glance.card(at: 2.4, count: 3, open: nil) == 0)
        #expect(WelcomeScene.quiet.length(cards: 0, cans: 0) == 7.5)
    }

    @Test func hakuDozesThenTurnsThePhoneDown() {
        let dozing = RunnerPose.welcome(.sofa, time: 0.5, open: 9.5, face: .mid)
        let dozeParts = Set(RunnerFigure.parts(for: .chill, pose: dozing))
        #expect(dozeParts.isSuperset(of: [.sofaArm, .blanket, .phone, .phoneHand, .eyesClosed]))
        #expect(dozing.welcome?.crate == -1)
        let up = RunnerPose.welcome(.sofa, time: 3.2, open: 9.5, face: .mid)
        let upParts = Set(RunnerFigure.parts(for: .chill, pose: up))
        #expect(upParts.isSuperset(of: [.phoneBack, .eyesChill]) && !upParts.contains(.phone))
        #expect(!upParts.contains(.phoneHand))
        let opened = RunnerPose.welcome(.sofa, time: 11, open: 9.5, face: .mid)
        #expect(opened.welcome?.crate == 1 && opened.welcome?.crateOpen == 1 && opened.welcome?.cansOut == true)
        let shut = RunnerPose.welcome(.sofa, time: 11, open: nil, face: .mid)
        #expect(shut.welcome?.crateOpen == 0 && shut.welcome?.cansOut == false)
    }

    @Test func atTheDeskHakuKeepsTheHeadsetOn() {
        let parts = Set(RunnerFigure.parts(for: .work, pose: RunnerPose.welcome(.desk, time: 4, open: nil, face: .mid)))
        #expect(parts.isSuperset(of: [.desk, .headset, .cupL, .cupR, .maskUp, .eyesWork, .phoneBack]))
        #expect(!parts.contains(.sofaArm) && !parts.contains(.blanket))
    }

    @Test func withNothingRecordedHakuPatsTheSeat() {
        let before = RunnerPose.welcome(.quiet, time: 3, open: nil, face: .mid)
        #expect(before.welcome?.pat == -1)
        let patting = RunnerPose.welcome(.quiet, time: 4, open: nil, face: .mid)
        #expect((patting.welcome?.pat ?? -1) >= 0 && patting.shift == -18)
        #expect(Set(RunnerFigure.parts(for: .chill, pose: patting)).isSuperset(of: [.sofaArm, .phone, .eyesChill]))
        // The sofa stays put while HAKU scoots over.
        #expect(SceneMove.welcome(.sofaArm, pose: patting)?.offset.width == 18)
        #expect(SceneMove.welcome(.camera, pose: patting) == nil)
        #expect(SceneMove.welcome(.phone, pose: RunnerPose(face: .mid)) == nil)
    }

    @Test func eachWelcomePlaysOnce() {
        let replay = ReturnReplay(tier: .glance, cards: cards, cans: 0)
        #expect(CompanionView.newWelcome(.welcomeBack(id: "w", replay: replay), last: "") == "w")
        #expect(CompanionView.newWelcome(.welcomeBack(id: "w", replay: replay), last: "w") == nil)
        #expect(CompanionView.newWelcome(.revived(id: "w"), last: "") == nil)
    }

    @Test func cardsShowWhatHappenedWithHakusParts() {
        #expect(ReturnCardIcon.parts(cards[0]) == [.backFist])
        #expect(ReturnCardIcon.parts(cards[2]) == [.runningShoes])
        let crop = ReturnCardIcon.crop([.backFist])
        #expect(crop.width == crop.height && crop.width < RunnerArt.bounds.width)
        let label = CompanionLines.welcomeLabel(ReturnReplay(tier: .box, cards: cards, cans: 9))
        #expect(label.hasPrefix("HAKU：……又不是在等你。") && label.contains("打了 2 次拳。") && label.contains("9 罐"))
    }
}
