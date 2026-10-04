import Foundation
import HubCore
import Testing

@testable import CompanionKit

@Suite struct CompanionKitTests {
    @Test(arguments: RunnerPart.allCases)
    func everyPartHasArt(_ part: RunnerPart) {
        #expect(!RunnerArt.inks(part).isEmpty || RunnerArt.text(part) != nil)
    }

    @Test(arguments: RunnerPart.allCases)
    func cachedInksMatchTheGeneratedArt(_ part: RunnerPart) {
        #expect(RunnerArt.cachedInks(part).count == RunnerArt.inks(part).count)
    }

    @Test(arguments: Mode.allCases)
    func everyModeShowsTheBaseParts(_ mode: Mode) {
        let parts = Set(RunnerFigure.parts(for: mode, pose: RunnerPose()))
        #expect(RunnerFigure.baseParts.isSubset(of: parts))
    }

    @Test(arguments: Mode.allCases)
    func visiblePartsKeepDrawingOrder(_ mode: Mode) {
        let parts = RunnerFigure.parts(for: mode, pose: RunnerPose())
        let order = parts.compactMap { RunnerPart.allCases.firstIndex(of: $0) }
        #expect(order == order.sorted())
    }

    @Test func ledDotsReplaceTheLedLine() {
        var pose = RunnerPose()
        #expect(RunnerFigure.parts(for: .work, pose: pose).contains(.ledLine))
        pose.ledDots = true
        #expect(!RunnerFigure.parts(for: .work, pose: pose).contains(.ledLine))
    }

    @Test func lowEnergyAddsEyeBags() {
        #expect(!RunnerFigure.parts(for: .money, pose: RunnerPose()).contains(.eyebags))
        #expect(RunnerFigure.parts(for: .money, pose: RunnerPose(face: .low)).contains(.eyebags))
    }

    @Test func energyPicksTheFace() {
        #expect(EnergyFace(energy: 10) == .low)
        #expect(EnergyFace(energy: 30) == .mid)
        #expect(EnergyFace(energy: 69) == .mid)
        #expect(EnergyFace(energy: 70) == .high)
        #expect(EnergyFace(energy: nil) == .mid)
        #expect(EnergyFace.low.speed < EnergyFace.mid.speed)
        #expect(EnergyFace.high.speed > EnergyFace.mid.speed)
    }

    @Test(arguments: Mode.allCases)
    func highEnergyAddsSparkles(_ mode: Mode) {
        let mid = Set(RunnerFigure.parts(for: mode, pose: RunnerPose()))
        let high = Set(RunnerFigure.parts(for: mode, pose: RunnerPose(face: .high)))
        #expect(mid.isDisjoint(with: [.sparkle, .eyeGlint]))
        #expect(high.contains(.sparkle))
        // Chill's eyes are closed in a smile, so there is nothing to glint.
        #expect(high.contains(.eyeGlint) == (mode != .chill))
    }

    @Test(arguments: Mode.allCases)
    func boxingWarmupPutsTheGlovesOn(_ mode: Mode) {
        let parts = Set(RunnerFigure.parts(for: mode, pose: RunnerPose(need: .boxingWarmup)))
        #expect(parts.isSuperset(of: [.headband, .gloveL, .gloveR]))
        #expect(!parts.contains(.monsterCan))
        #expect(RunnerFigure.baseParts.isSubset(of: parts))
    }

    @Test func warmupLooksAtTheDoorNowAndThen() {
        let glances = (0..<80).map {
            RunnerPose(mode: .chill, time: Double($0) * 0.05, face: .mid, need: .boxingWarmup, react: 0).eyesDx
        }
        #expect(glances.contains { $0 < -1 })
        #expect(glances.contains(0))
        #expect(glances.allSatisfy { (-3...0).contains($0) })
        #expect(RunnerPose(mode: .chill, time: 3.3, face: .mid, react: 0).eyesDx == 0)
    }

    @Test func bedtimeTakesTheGlovesOff() {
        var pose = RunnerPose.bedtimeStill()
        pose.need = .boxingWarmup
        let parts = Set(RunnerFigure.parts(for: .chill, pose: pose))
        #expect(parts.isDisjoint(with: [.gloveL, .gloveR, .headband]))
        #expect(parts.contains(.monsterCan))
    }

    @Test func warmupHasItsOwnLinesAndLabel() {
        #expect(CompanionLines.lines(for: .chill, need: .boxingWarmup) != CompanionLines.lines(for: .chill))
        #expect(CompanionLines.accessibilityLabel(mode: .chill, need: .boxingWarmup, bedtime: .off).contains("热身"))
        #expect(CompanionLines.accessibilityLabel(mode: .chill, need: .boxingWarmup, bedtime: .on) == "HAKU，困了")
    }

    @Test(arguments: Mode.allCases)
    func couchScrollHoldsThePhone(_ mode: Mode) {
        let parts = Set(RunnerFigure.parts(for: mode, pose: RunnerPose(need: .couchScroll)))
        #expect(parts.isSuperset(of: [.phone, .phoneFeed, .phoneHand, .eyesSleepy]))
        #expect(parts.isDisjoint(with: [.eyesWork, .eyesChill, .cateyeL, .eyesMoney, .mouthSmile, .monsterCan]))
        #expect(RunnerFigure.baseParts.isSubset(of: parts))
        let high = Set(RunnerFigure.parts(for: mode, pose: RunnerPose(face: .high, need: .couchScroll)))
        #expect(!high.contains(.eyeGlint))
    }

    @Test func couchFeedFlicksAndStaysInRange() {
        let feeds = (0..<100).map {
            RunnerPose(mode: .chill, time: Double($0) * 0.05, face: .mid, need: .couchScroll, react: 0).feed
        }
        #expect(feeds.allSatisfy { (0...1).contains($0) })
        #expect(feeds.contains(0) && feeds.contains(1))
        let still = RunnerPose(need: .couchScroll)
        #expect(still.headDy == 3 && still.eyesDy == 1.5)
    }

    @Test func bedtimePutsThePhoneDown() {
        var pose = RunnerPose.bedtimeStill()
        pose.need = .couchScroll
        let parts = Set(RunnerFigure.parts(for: .chill, pose: pose))
        #expect(parts.isDisjoint(with: [.phone, .phoneFeed, .phoneHand]))
    }

    @Test func slumpedMotionLeansBack() {
        let motion = IdleMotion.slumped(time: 1)
        #expect(motion.angle < 0)
        #expect((3...5).contains(motion.dy))
        #expect(CompanionLines.accessibilityLabel(mode: .chill, need: .couchScroll, bedtime: .off).contains("手机"))
    }

    @Test func eachCelebrationPlaysOnce() {
        #expect(CompanionView.newCelebration(.celebrate(id: "run-1", kind: .running), last: "") == "run-1")
        #expect(CompanionView.newCelebration(.celebrate(id: "run-1", kind: .running), last: "run-1") == nil)
        #expect(CompanionView.newCelebration(.celebrate(id: "box-2", kind: .boxing), last: "run-1") == "box-2")
        #expect(CompanionView.newCelebration(nil, last: "") == nil)
    }

    @Test func celebrationBurstsSparklesButNotAtBedtime() {
        var pose = RunnerPose()
        pose.burst = 0.5
        #expect(RunnerFigure.parts(for: .chill, pose: pose).contains(.sparkle))
        var sleepy = RunnerPose.bedtimeStill()
        sleepy.burst = 0.5
        #expect(!RunnerFigure.parts(for: .chill, pose: sleepy).contains(.sparkle))
    }

    @Test func celebrationHopsAndLands() {
        let hops = (0..<20).map { IdleMotion.celebrating(progress: Double($0) / 20) }
        #expect(hops.allSatisfy { $0.dy <= 0 && $0.dy >= -22 && abs($0.angle) <= 3 })
        #expect(hops.contains { $0.dy < -15 })
        #expect(abs(IdleMotion.celebrating(progress: 0).dy) < 0.01)
    }

    @Test func bedtimeHidesTheHighEnergyLook() {
        var pose = RunnerPose.bedtimeStill()
        pose.face = .high
        let parts = Set(RunnerFigure.parts(for: .work, pose: pose))
        #expect(parts.isDisjoint(with: [.sparkle, .eyeGlint]))
    }

    @Test(arguments: Mode.allCases)
    func posesStayInRange(_ mode: Mode) {
        for step in 0..<200 {
            for react in [0.0, 0.5, 1.0] {
                let time = Double(step) * 0.05
                let face: EnergyFace = [.low, .mid, .high][step % 3]
                let pose = RunnerPose(mode: mode, time: time, face: face, react: react)
                #expect((0...1).contains(pose.blink))
                #expect((0...1).contains(pose.ledOpacity))
                #expect(abs(pose.headDy) <= 2)
                #expect(abs(pose.canAngle) <= 60)
                #expect(abs(pose.gloveR.width) <= 14)
                #expect(pose.glint <= 1)
                #expect((0...1).contains(pose.sparkle))
            }
        }
    }

    @Test(arguments: Mode.allCases)
    func bedtimeSwapsTheAwakeFace(_ mode: Mode) {
        let parts = Set(RunnerFigure.parts(for: mode, pose: RunnerPose.bedtimeStill()))
        #expect(parts.isSuperset(of: [.eyesSleepy, .maskDown, .zzz]))
        #expect(parts.isDisjoint(with: [.maskUp, .ledLine, .ledYen, .eyesWork, .cateyeL, .mouthSmile, .headset]))
        #expect(RunnerFigure.baseParts.isSubset(of: parts))
    }

    @Test func headsetComesOffDuringGoodnight() {
        let start = RunnerPose.bedtime(time: 0, goodnight: 0.1, liesDown: true)
        let end = RunnerPose.bedtime(time: 0, goodnight: 1, liesDown: true)
        #expect(RunnerFigure.parts(for: .work, pose: start).contains(.headset))
        #expect(!RunnerFigure.parts(for: .work, pose: end).contains(.headset))
    }

    @Test func onlyTheHomeVersionLiesDown() {
        let home = RunnerPose.bedtime(time: 0, goodnight: 1, liesDown: true)
        let notification = RunnerPose.bedtime(time: 0, goodnight: 1, liesDown: false)
        #expect(home.lie == 1)
        #expect(RunnerFigure.parts(for: .chill, pose: home).contains(.pillow))
        #expect(notification.lie == 0)
        #expect(!RunnerFigure.parts(for: .chill, pose: notification).contains(.pillow))
    }

    @Test func sleepyLoopYawns() {
        let yawns = (0..<120).map { RunnerPose.bedtime(time: Double($0) * 0.05, goodnight: 1, liesDown: true).yawn }
        #expect(yawns.contains { $0 > 0.5 })
        #expect(yawns.contains { $0 == 0 })
    }

    @Test func bedtimePosesStayInRange() {
        for step in 0..<200 {
            let time = Double(step) * 0.05
            let pose = RunnerPose.bedtime(time: time, goodnight: Double(step) / 150, liesDown: true)
            #expect((0...1).contains(pose.headsetOff))
            #expect((0...1).contains(pose.yawn))
            #expect((0...1).contains(pose.stretch))
            #expect((0...1).contains(pose.lie))
            #expect(pose.zzz == -1 || (0...1).contains(pose.zzz))
            #expect((0.1...1).contains(pose.blink))
        }
    }

    @Test func goodnightPlaysOncePerNight() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        #expect(!CompanionView.playedTonight(last: 0, now: now))
        #expect(CompanionView.playedTonight(last: 1_000_000 - 3600, now: now))
        #expect(!CompanionView.playedTonight(last: 1_000_000 - 13 * 3600, now: now))
    }

    @Test func headBoxFitsInsideTheFigure() {
        #expect(RunnerArt.bounds.contains(RunnerFigure.headBox))
    }

    @Test func riveValuesMatchTheRunnerViewModel() {
        #expect(Mode.allCases.map(\.riveValue) == ["work", "chill", "box", "money"])
    }

    @Test(arguments: Mode.allCases)
    func idleMotionStaysSmall(_ mode: Mode) {
        for step in 0..<200 {
            let motion = IdleMotion(mode: mode, time: Double(step) * 0.05)
            #expect(abs(motion.dy) <= 8)
            #expect(abs(motion.angle) <= 3)
        }
    }

    @Test func everyModeHasLines() {
        for mode in Mode.allCases {
            #expect(!CompanionLines.lines(for: mode).isEmpty)
        }
        #expect(!CompanionLines.lines(for: nil).isEmpty)
    }

    @Test func offWorkPlaysOncePerDay() {
        #expect(CompanionView.newOffWork(.offWork(id: "2026-10-05"), last: "") == "2026-10-05")
        #expect(CompanionView.newOffWork(.offWork(id: "2026-10-05"), last: "2026-10-05") == nil)
        #expect(CompanionView.newOffWork(.celebrate(id: "run-1", kind: .running), last: "") == nil)
        #expect(CompanionView.newCelebration(.offWork(id: "2026-10-05"), last: "") == nil)
    }

    @Test(arguments: Mode.allCases)
    func offWorkGoesFromHeadsetToMonster(_ mode: Mode) {
        let start = Set(RunnerFigure.parts(for: mode, pose: RunnerPose.offWork(time: 0, progress: 0, face: .mid)))
        #expect(start.isSuperset(of: [.headset, .maskUp, .eyesWork]))
        #expect(!start.contains(.monsterCan))
        let end = Set(RunnerFigure.parts(for: mode, pose: RunnerPose.offWork(time: 0, progress: 0.99, face: .mid)))
        #expect(end.isSuperset(of: [.maskDown, .eyesChill, .monsterCan]))
        #expect(end.isDisjoint(with: [.headset, .maskUp, .eyesWork, .ledLine]))
        #expect(RunnerFigure.baseParts.isSubset(of: end))
    }

    @Test func offWorkPoseStaysInRange() {
        for step in 0...100 {
            let pose = RunnerPose.offWork(time: Double(step) * 0.04, progress: Double(step) / 100, face: .mid)
            #expect((0...1).contains(pose.headsetOff))
            #expect((0...1).contains(pose.maskDrop))
            #expect((0...1).contains(pose.stretch))
            #expect((0...1).contains(pose.canOpacity))
            #expect((0.1...1).contains(pose.blink))
        }
        let stretching = RunnerPose.offWork(time: 0, progress: 0.45, face: .mid)
        #expect(stretching.stretch > 0.9 && stretching.maskDrop == 1 && stretching.headsetOff == 1)
    }

    @Test func sundayAfternoonIsForTidying() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        // 2026-10-04 is a Sunday.
        let sunday = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 14)))
        #expect(IdleLife.at(sunday, calendar: calendar) == .tidying)
        let saturday = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 14)))
        #expect(IdleLife.at(saturday, calendar: calendar) != .tidying)
    }

    @Test func idleLifeHoldsForASlotAndVaries() {
        let start = Date(timeIntervalSinceReferenceDate: IdleLife.slotLength * 1000)
        #expect(IdleLife.at(start) == IdleLife.at(start.addingTimeInterval(IdleLife.slotLength - 1)))
        let week = (0..<(7 * 96)).map { IdleLife.at(start.addingTimeInterval(Double($0) * IdleLife.slotLength)) }
        for life in IdleLife.allCases { #expect(week.contains(life)) }
        #expect(week.contains(nil))
    }

    @Test(arguments: IdleLife.allCases)
    func idleLifeSwapsTheCanForItsProp(_ life: IdleLife) {
        let parts = Set(RunnerFigure.parts(for: .chill, pose: RunnerPose(life: life)))
        #expect(!parts.contains(.monsterCan))
        #expect(RunnerFigure.baseParts.isSubset(of: parts))
        let expected: Set<RunnerPart> =
            switch life {
            case .nap: [.pillow, .eyesSleepy, .zzz]
            case .handheld: [.handheld, .eyesWork]
            case .snack: [.onigiri, .eyesChill]
            case .drawing: [.sketchbook, .pencil, .eyesWork]
            case .practice: [.gloveL, .gloveR]
            case .tidying: [.cloth]
            }
        #expect(parts.isSuperset(of: expected))
        if parts.contains(.eyesWork) || parts.contains(.eyesSleepy) { #expect(!parts.contains(.eyesChill)) }
        #expect(!CompanionLines.lines(for: .chill, life: life).isEmpty)
        let label = CompanionLines.accessibilityLabel(mode: .chill, need: nil, life: life, bedtime: .off)
        #expect(label.hasPrefix("HAKU，"))
    }

    @Test func needsAndBedtimeOverrideIdleLife() {
        let needed = Set(RunnerFigure.parts(for: .chill, pose: RunnerPose(need: .couchScroll, life: .handheld)))
        #expect(!needed.contains(.handheld))
        var night = RunnerPose.bedtimeStill()
        night.life = .snack
        #expect(!RunnerFigure.parts(for: .chill, pose: night).contains(.onigiri))
    }

    @Test(arguments: IdleLife.allCases)
    func lookingCatchesHaku(_ life: IdleLife) {
        for step in 0..<60 {
            let time = Double(step) * 0.05
            let caught = RunnerPose(mode: .chill, time: time, face: .mid, life: life, react: 1)
            #expect((0...1).contains(caught.propHidden))
            #expect((0.1...1).contains(caught.blink))
            switch life {
            case .snack, .drawing: #expect(caught.propHidden == 1)
            case .nap: #expect(caught.blink > 0.99 && caught.lie == 0)
            case .practice: #expect(caught.gloveL.height >= 18)
            case .handheld, .tidying: break
            }
        }
    }

    @Test func eachWorkoutHasItsOwnCelebration() {
        func cheering(_ kind: WorkoutSummary.Kind, mode: Mode = .chill) -> Set<RunnerPart> {
            var pose = RunnerPose()
            pose.celebrate(kind, progress: 0.25)
            return Set(RunnerFigure.parts(for: mode, pose: pose))
        }
        #expect(cheering(.running).contains(.peaceHand))
        #expect(cheering(.strength).contains(.dumbbell))
        #expect(cheering(.boxing).isSuperset(of: [.gloveL, .gloveR]))
        #expect(!cheering(.running).contains(.monsterCan))
        #expect(cheering(.other).isDisjoint(with: [.peaceHand, .dumbbell]))
        #expect(cheering(.other).contains(.sparkle))
        var boxing = RunnerPose()
        boxing.celebrate(.boxing, progress: 0.25)
        #expect(boxing.gloveR.height < -20)
        let lines = Set([WorkoutSummary.Kind.boxing, .running, .strength, .other].map(CompanionLines.celebration))
        #expect(lines.count == 4)
    }

    @Test func couchStagesFollowTimeAndInvite() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        #expect(CouchStage.at(start.addingTimeInterval(10 * 60), since: start, inviting: false) == .scrolling)
        let later = start.addingTimeInterval(CouchStage.peekAfter)
        #expect(CouchStage.at(later, since: start, inviting: false) == .peeking)
        #expect(CouchStage.at(start, since: nil, inviting: false) == .scrolling)
        #expect(CouchStage.at(start, since: start, inviting: true) == .up)
    }

    @Test func gymBagShowsWhilePeekingAndCarrying() {
        var peeking = RunnerPose(need: .couchScroll)
        #expect(!RunnerFigure.parts(for: .chill, pose: peeking).contains(.gymBag))
        peeking.peekAtBag(time: 4.2)
        #expect(peeking.bagLift == 0 && peeking.eyesDx < 0)
        #expect(RunnerFigure.parts(for: .chill, pose: peeking).contains(.gymBag))
        var up = RunnerPose()
        up.bagLift = 1
        #expect(RunnerFigure.parts(for: .work, pose: up).contains(.gymBag))
        var night = RunnerPose.bedtimeStill()
        night.bagLift = 1
        #expect(!RunnerFigure.parts(for: .chill, pose: night).contains(.gymBag))
        let peekLines = CompanionLines.lines(for: .chill, need: .couchScroll, peeking: true)
        #expect(peekLines != CompanionLines.lines(for: .chill, need: .couchScroll))
        let label = CompanionLines.accessibilityLabel(mode: .chill, need: .couchScroll, peeking: true, bedtime: .off)
        #expect(label.contains("运动包"))
    }

    @Test func activityReplacesTheNeedAndOwnTime() {
        let pose = RunnerPose(need: .couchScroll, life: .nap, activity: .running)
        #expect(pose.need == nil)
        #expect(pose.life == nil)
        #expect(pose.activity == .running)
    }

    @Test(arguments: [
        (CompanionActivity.boxingAtGym, RunnerPart.heavyBag),
        (.gymSession, .dumbbell),
        (.running, .speedLines),
        (.gymDay, .gymBag),
        (.runDay, .runShoe),
    ])
    func eachActivityShowsItsProp(_ activity: CompanionActivity, prop: RunnerPart) {
        let parts = Set(RunnerFigure.parts(for: .chill, pose: RunnerPose(activity: activity)))
        #expect(parts.contains(prop))
        #expect(!parts.contains(.monsterCan))
        #expect(!CompanionLines.lines(for: .chill, activity: activity).isEmpty)
        #expect(CompanionLines.accessibilityLabel(mode: .chill, need: nil, activity: activity, bedtime: .off) != "HAKU")
    }

    @Test func heavyBagWorkWearsTheGloves() {
        let parts = Set(RunnerFigure.parts(for: .boxing, pose: RunnerPose(activity: .boxingAtGym)))
        #expect(parts.isSuperset(of: [.gloveL, .gloveR, .headband, .heavyBag]))
    }

    @Test func bedtimeHidesTheActivity() {
        var pose = RunnerPose.bedtimeStill()
        pose.activity = .running
        #expect(!RunnerFigure.parts(for: .chill, pose: pose).contains(.speedLines))
    }

    @Test func outfitFollowsTheEquippedItems() {
        var wardrobe = Wardrobe()
        wardrobe.equipped[.gloves] = "gloves.gold"
        wardrobe.equipped[.headband] = "keepsake.headband.runner"
        wardrobe.equipped[.mask] = "mask.stripes"
        wardrobe.equipped[.room] = "room.bag"
        let outfit = Outfit(wardrobe)
        #expect(outfit.gloves == RunnerPalette.gold)
        #expect(outfit.headband == RunnerPalette.white)
        #expect(outfit.stripedMask)
        #expect(outfit.room == .roomBag)
    }

    @Test func unknownItemsKeepTheDefaultLook() {
        #expect(Outfit(Wardrobe(equipped: [.gloves: "gloves.someday", .room: "room.someday"])) == Outfit())
    }

    @Test(arguments: ShopItem.catalog.filter { $0.slot != .celebration })
    func everyWornItemChangesTheLook(_ item: ShopItem) {
        var wardrobe = Wardrobe()
        wardrobe.equip(item)
        #expect(Outfit(wardrobe) != Outfit())
    }

    @Test func stripedMaskShowsOnBothMasks() {
        var wardrobe = Wardrobe()
        wardrobe.equipped[.mask] = "mask.stripes"
        let pose = RunnerPose().wearing(Outfit(wardrobe))
        let work = Set(RunnerFigure.parts(for: .work, pose: pose))
        #expect(work.contains(.maskStripes))
        #expect(!work.contains(.panelLines))
        #expect(Set(RunnerFigure.parts(for: .chill, pose: pose)).contains(.maskStripesDown))
    }

    @Test func roomItemShowsOnlyAtHome() {
        var wardrobe = Wardrobe()
        wardrobe.equipped[.room] = "room.plant"
        var pose = RunnerPose().wearing(Outfit(wardrobe))
        #expect(RunnerFigure.parts(for: .chill, pose: pose).contains(.roomPlant))
        #expect(!RunnerFigure.parts(for: .work, pose: pose).contains(.roomPlant))
        pose.bagLift = 0
        #expect(!RunnerFigure.parts(for: .chill, pose: pose).contains(.roomPlant))
        let running = RunnerPose(activity: .running).wearing(Outfit(wardrobe))
        #expect(!RunnerFigure.parts(for: .chill, pose: running).contains(.roomPlant))
    }

    @Test(arguments: ShopItem.catalog)
    func everyItemIconDrawsSomething(_ item: ShopItem) {
        var wardrobe = Wardrobe()
        wardrobe.equip(item)
        let picture = ItemPicture(slot: item.slot, outfit: Outfit(wardrobe), itemID: item.id)
        #expect(!picture.parts.isEmpty)
        #expect(picture != ItemPicture(slot: item.slot, outfit: Outfit(), itemID: nil))
    }

    @Test func defaultIconsShowTheStandardLook() {
        #expect(ItemPicture(slot: .gloves, outfit: Outfit(), itemID: nil).red == nil)
        #expect(ItemPicture(slot: .mask, outfit: Outfit(), itemID: nil).parts.contains(.panelLines))
        #expect(ItemPicture(slot: .room, outfit: Outfit(), itemID: nil).parts.isEmpty)
    }

    @Test func slotsHaveTheirOwnTileColors() {
        #expect(Set(Slot.allCases.map(\.tileColor)).count == Slot.allCases.count)
    }
}
