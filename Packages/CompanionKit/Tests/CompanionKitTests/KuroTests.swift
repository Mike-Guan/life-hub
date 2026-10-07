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

    @Test func eachLookHasItsOwnCardColor() {
        #expect(Set(KuroLook.allCases.map(\.color)).count == KuroLook.allCases.count)
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
        #expect(KuroView.accessibilityLabel(.tennis, bedtime: .on) == "KURO，困了")
    }

    @Test func sheSharesHakusFrame() {
        #expect(KuroArt.bounds == RunnerArt.bounds)
    }

    @Test func sheHasHerOwnLines() {
        for mode in [Mode?.none] + Mode.allCases.map(Optional.some) {
            let hers = CompanionLines.lines(for: mode, persona: .kuro)
            #expect(!hers.isEmpty && hers != CompanionLines.lines(for: mode))
        }
        #expect(CompanionLines.lines(for: .boxing, persona: .kuro).contains("正手，反手。"))
        #expect(CompanionLines.lines(for: .chill, need: .boxingWarmup, persona: .kuro).contains("先拍两下球。"))
        let peeking = CompanionLines.lines(for: .chill, need: .couchScroll, peeking: true, persona: .kuro)
        #expect(peeking != CompanionLines.lines(for: .chill, need: .couchScroll, persona: .kuro))
        #expect(CompanionLines.lines(for: .money, moment: .flow, persona: .kuro) == ["……"])
        #expect(CompanionLines.lines(for: .chill, activity: .boxingAtGym, persona: .kuro).contains("……别看我，看球。"))
        for life in IdleLife.allCases {
            #expect(!CompanionLines.lines(for: .chill, life: life, persona: .kuro).isEmpty)
        }
    }

    @Test func herMomentLinesDifferFromHakus() {
        // Flow and blanket lines are the same for both.
        for moment in CompanionMoment.allCases where ![.flow, .blanket].contains(moment) {
            let hers = CompanionLines.lines(for: .chill, moment: moment, persona: .kuro)
            #expect(!hers.isEmpty && hers != CompanionLines.lines(for: .chill, moment: moment))
        }
    }

    @Test func sheCelebratesAndUnboxesQuietly() {
        let kinds: [WorkoutSummary.Kind] = [.boxing, .running, .strength, .other]
        let hers = kinds.map { CompanionLines.celebration($0, persona: .kuro) }
        #expect(Set(hers).count == kinds.count && hers != kinds.map { CompanionLines.celebration($0) })
        #expect(CompanionLines.unlock("gloves.gold", persona: .kuro) == "……给你的。不是特意挑的。")
        #expect(CompanionLines.unlock("room.plant", persona: .kuro) == "……还行吧。")
    }

    @Test func eachLookMapsBackToItsMode() {
        #expect(KuroLook.allCases.allSatisfy { KuroLook(mode: $0.mode) == $0 })
    }

    @Test func aTapNeverRepeatsTheShownLine() {
        let lines = CompanionLines.lines(for: .work, persona: .kuro)
        for shown in lines {
            #expect(KuroView.line(after: shown, from: lines) != shown)
        }
        #expect(KuroView.line(after: "……", from: ["……"]) == "……")
        #expect(KuroView.line(after: nil, from: []) == nil)
    }

    @Test func overtimeSitsHerAtTheDeskWithHerSign() throws {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let until = try #require(tokyo.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 20, minute: 30)))
        let pose = KuroView.pose(
            .work, energy: 60, bedtime: .off, moment: .overtime, overtimeUntil: until, calendar: tokyo)
        #expect(pose.overtime && pose.eyes == .drowsy && pose.sign == "20:30")
        let parts = Set(KuroFigure.parts(for: .work, pose: pose))
        #expect(parts.isSuperset(of: [.overtimeDesk, .overtimeHand, .overtimeSign, .maskWork]))
        #expect(!parts.contains(.workTablet))
        #expect(KuroView.accessibilityLabel(.work, bedtime: .off, pose: pose) == "KURO，托着腮等到 20:30")
    }

    @Test func overtimeWithoutAnEndHasNoSign() {
        let pose = KuroView.pose(.work, energy: nil, bedtime: .off, moment: .overtime, overtimeUntil: nil)
        let parts = KuroFigure.parts(for: .work, pose: pose)
        #expect(parts.contains(.overtimeDesk) && !parts.contains(.overtimeSign))
        #expect(KuroView.accessibilityLabel(.work, bedtime: .off, pose: pose) == "KURO，托着腮等着")
    }

    @Test func overtimeOnlyShowsInTheWorkLookBeforeBedtime() {
        for look in KuroLook.allCases where look != .work {
            #expect(!KuroView.pose(look, energy: nil, bedtime: .off, moment: .overtime, overtimeUntil: .now).overtime)
        }
        #expect(!KuroView.pose(.work, energy: nil, bedtime: .on, moment: .overtime, overtimeUntil: .now).overtime)
        #expect(!KuroView.pose(.work, energy: nil, bedtime: .off, moment: .drowsy, overtimeUntil: .now).overtime)
    }

    @Test func signTextUsesA24HourClock() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        #expect(KuroView.signText(Date(timeIntervalSince1970: 21 * 3600 + 5 * 60), calendar: utc) == "21:05")
        #expect(KuroView.signText(Date(timeIntervalSince1970: 0), calendar: utc) == "00:00")
    }
}
