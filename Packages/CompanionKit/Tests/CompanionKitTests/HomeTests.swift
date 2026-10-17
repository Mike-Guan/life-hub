import Foundation
import HubCore
import Testing

@testable import CompanionKit

@Suite struct HomeGridTests {
    @Test func theFloorUnderAPlanPointIsWhereItCameFrom() {
        for p in [GridPoint(x: 0, y: 0), GridPoint(x: 3.5, y: 7.25), GridPoint(x: 10, y: 2)] {
            let back = HomeGrid.floor(at: HomeGrid.plan(p))
            #expect(abs(back.x - p.x) < 1e-9)
            #expect(abs(back.y - p.y) < 1e-9)
        }
    }

    @Test func sceneAndPlanPointsConvertBothWays() {
        let p = CGPoint(x: 300, y: 120)
        #expect(HomeGrid.plan(scene: HomeGrid.scene(p)) == p)
    }

    @Test func walksGoAroundTheFurniture() {
        let seats: Set<HomeSpot> = [.work, .side, .sofa, .rest]
        let solid = HomePiece.allCases.filter { $0.depth > 1 && $0 != .blanket }
        for from in HomeSpot.allCases {
            for to in HomeSpot.allCases {
                let stops = to.path(from: from.point, leaving: from, nav: .room())
                for (a, b) in zip(stops, stops.dropFirst()) {
                    // Getting off or onto a seat crosses its own furniture; everything else stays clear.
                    if seats.contains(from), a == from.point { continue }
                    if seats.contains(to), b == to.point { continue }
                    for k in 1..<20 {
                        let f = Double(k) / 20
                        let p = GridPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
                        let hit = solid.first { piece in piece.boxes.contains { $0.covers(p) } }
                        #expect(hit == nil, "\(from) → \(to) walks through \(String(describing: hit))")
                    }
                }
            }
        }
    }

    @Test func seatedHakuSitsBetweenTheSeatAndWhatIsInFrontOfIt() throws {
        let sofa = try #require(HomeSpot.sofa.depth)
        #expect(sofa > HomePiece.sofaSeat.depth && sofa < HomePiece.sofaNearArm.depth)
        let desk = try #require(HomeSpot.work.depth)
        #expect(desk > HomePiece.chairSeat.depth && desk < HomePiece.chairBack.depth)
        let bed = try #require(HomeSpot.rest.depth)
        #expect(bed > HomePiece.bed.depth && bed < HomePiece.blanket.depth)
    }

    @Test func aWalkEndsAtItsLastStop() {
        let walk = HomeWalk(stops: HomeSpot.box.path(from: HomeSpot.hub, leaving: .idle, nav: .room()))
        #expect(walk.position(after: 0).point == HomeSpot.hub)
        #expect(walk.position(after: walk.length + 1).point == HomeSpot.box.point)
        #expect(walk.length > 2)
    }

    @Test func everySpotIsReachedFromOpenFloor() {
        let nav = HomeNav.room(items: Set(HomeItem.allCases))
        for spot in HomeSpot.allCases {
            #expect(nav.isOpen(spot.approach), "\(spot) steps on from blocked floor")
        }
    }

    @Test func walksGoStraightThereInsteadOfThroughTheRug() {
        let stops = HomeSpot.window.path(from: HomeSpot.box.point, leaving: .box, nav: .room())
        let walk = HomeWalk(stops: stops)
        #expect(!stops.contains(HomeSpot.hub))
        #expect(walk.length < HomeSpot.box.point.distance(to: HomeSpot.window.point) + 0.5)
    }

    @Test func walksBetweenSeatsStepOffAndOn() {
        let stops = HomeSpot.rest.path(from: HomeSpot.sofa.point, leaving: .sofa, nav: .room())
        #expect(stops[1] == HomeSpot.sofa.approach)
        #expect(stops[stops.count - 2] == HomeSpot.rest.approach)
        #expect(stops.last == HomeSpot.rest.point)
    }

    @Test func aBlockedPointMovesToTheNearestOpenFloor() {
        let nav = HomeNav.room()
        let inWardrobe = GridPoint(x: 7.8, y: 0.6)
        #expect(!nav.isOpen(inWardrobe))
        let landed = nav.nearestOpen(to: inWardrobe)
        #expect(nav.isOpen(landed))
        #expect(landed.distance(to: inWardrobe) < 1.6)
    }

    @Test func aPolygonHoldsItsMiddle() {
        let shape = HomeGrid.silhouette(HomePiece.bed.boxes[0])
        #expect(HomeGrid.contains(shape, HomeGrid.plan(8, 6.5, 0.5)))
        #expect(!HomeGrid.contains(shape, HomeGrid.plan(2, 2)))
    }
}

@MainActor
@Suite struct HomeModelTests {
    @Test func eachModeSendsHakuSomewhere() {
        let model = HomeModel(night: true)
        #expect(model.spot == .idle)
        model.switchMode(.work)
        #expect(model.spot == .work)
        model.switchMode(.chill)
        #expect(model.spot == .sofa)
        model.switchMode(.boxing)
        #expect(model.spot == .shadowbox)
        model.switchMode(.money)
        #expect(model.spot == .side)
    }

    @Test func hakuFollowsTheModeInANewSnapshot() {
        let model = HomeModel(night: false, mode: .work)
        #expect(model.spot == .work)
        var next = model.snapshot
        next.mode = .chill
        model.apply(next)
        #expect(model.spot == .sofa)
        #expect(model.line.hasSuffix("今天到此为止。"))
        // The same mode again, after he was sent elsewhere, leaves him there.
        model.tap(.bed)
        model.apply(next)
        #expect(model.spot == .rest)
    }

    @Test func theCardsNameAndTodayComeFromTheSnapshot() throws {
        let calendar = Calendar.current
        let day = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let start = try #require(calendar.date(bySettingHour: 9, minute: 5, second: 0, of: day))
        var snapshot = HomeSnapshot.preview()
        snapshot.cards = ModeCards(names: [Mode.money.rawValue: "写作"], identity: .tennis)
        let log = ModeLog(changes: [ModeChange(mode: .work, at: start, deviceID: "test")])
        snapshot.today = log.segments(on: start, now: start + 3600, calendar: calendar)
        let model = HomeModel(snapshot: snapshot, night: false)
        #expect(model.title(.money) == "写作")
        #expect(model.title(.boxing) == IdentityKind.tennis.title)
        #expect(model.timeline.map(\.mode) == [.work])
        #expect(model.timeline.first?.time == HomeModel.clock(start))
    }

    @Test func otherCardsDoNotBox() {
        let model = HomeModel(night: false, card: .tennis)
        model.switchMode(.boxing)
        #expect(model.spot == .idle)
    }

    @Test func withTheBagBoxingDayHitsIt() {
        let model = HomeModel(night: false)
        model.own(.bag)
        model.switchMode(.boxing)
        #expect(model.spot == .box)
    }

    @Test func fitnessDayPressesOnTheBenchOnceThereIsOne() {
        let model = HomeModel(night: false, card: .fitness)
        model.switchMode(.boxing)
        #expect(model.spot == .idle)
        model.own(.bench)
        model.switchMode(.boxing)
        #expect(model.spot == .bench)
        #expect(HomeSpot.bench.pose == .press)
    }

    @Test func tappingTheBenchIsAShortVisit() {
        let model = HomeModel(night: false)
        model.switchMode(.chill)
        model.tap(.bench)
        #expect(model.spot == .bench)
        model.tick(HomeModel.visitLength + 1)
        #expect(model.spot == .sofa)
    }

    @Test func ownedRoomItemsStandInTheRoomAndNewOnesPopIn() {
        let model = HomeModel(night: false)
        #expect(model.items.isEmpty)
        var next = model.snapshot
        next.owned = ["room.plant", "haku.weekly.room.cactus", "headband.cyan"]
        model.apply(next)
        #expect(model.items == [.plant, .cactus])
        let cues = model.takeCues()
        #expect(cues.count == 2 && cues.contains(.placed(.plant)) && cues.contains(.placed(.cactus)))
        model.apply(next)
        #expect(model.takeCues().isEmpty)
    }

    @Test func hakuWearsWhatIsWornWhenItIsDrawnAndTheJacketOtherwise() {
        #expect(HomeOutfit(worn: ["haku.top.chill.aloha"]) == .aloha)
        #expect(HomeOutfit(worn: ["haku.top.work.blazer", "headband.cyan"]) == .blazer)
        #expect(HomeOutfit(worn: ["some.top.not.drawn"]) == .jacket)
        let model = HomeModel(night: false)
        #expect(model.ownedOutfits == [.jacket])
        model.wear(.flame)
        #expect(model.outfit == .flame)
        #expect(model.ownedOutfits == [.jacket, .flame])
    }

    @Test func lowEnergyIsTheOnlyTiredness() {
        #expect(HomeModel(night: false, energy: .low).isLow)
        #expect(!HomeModel(night: false, energy: .okay).isLow)
        #expect(!HomeModel(night: false).isLow)
    }

    @Test func threeQuickTapsAreEnough() {
        let model = HomeModel(night: false)
        let now = Date(timeIntervalSinceReferenceDate: 0)
        model.tap(.haku, at: now)
        model.tap(.haku, at: now.addingTimeInterval(0.5))
        model.tap(.haku, at: now.addingTimeInterval(1))
        #expect(model.line == "够了。")
        #expect(model.takeCues().last == .annoyed)
    }

    @Test func droppedOnASeatHeUsesItAndElsewhereHeLandsOnOpenFloor() throws {
        let model = HomeModel(night: false)
        model.drop(on: .sofa, at: GridPoint(x: 1, y: 6))
        #expect(model.spot == .sofa)
        model.drop(on: .bed, at: GridPoint(x: 9, y: 5))
        #expect(model.spot == .rest)
        model.drop(on: .shop, at: GridPoint(x: 9.5, y: 0.5))
        let p = try #require(model.dropPoint)
        #expect(HomeNav.room().isOpen(p))
    }

    @Test func aVisitEndsBackAtTheModesSpot() {
        let model = HomeModel(night: true)
        model.switchMode(.work)
        model.tap(.bed)
        #expect(model.spot == .rest)
        model.tick(HomeModel.visitLength - 1)
        #expect(model.spot == .rest)
        model.tick(2)
        #expect(model.spot == .work)
    }

    @Test func droppedOnTheFloorHeWalksBackAfterAMoment() {
        let model = HomeModel(night: true)
        model.switchMode(.chill)
        model.drop(on: nil, at: GridPoint(x: 5, y: 8))
        #expect(model.dropPoint != nil)
        model.tick(HomeModel.landingPause + 0.1)
        #expect(model.dropPoint == nil)
        #expect(model.spot == .sofa)
    }

    @Test func paintingSavesTheColourInTheRoomLayout() {
        let model = HomeModel(night: false)
        let saved = model.paint(.sofa, 2, deviceID: "test")
        #expect(model.color(.sofa) == HomePaintable.sofa.swatches[2])
        #expect(
            saved.placements.first { $0.piece == "home.sofa" }?.color
                == String(format: "%06X", HomePaintable.sofa.swatches[2]))
        #expect(saved.updatedBy == "test")
        model.paint(.sofa, 9)
        #expect(model.color(.sofa) == HomePaintable.sofa.swatches[2])
        model.paint(.walls, 1)
        #expect(model.layout.wallpaper == String(format: "%06X", HomePaintable.walls.swatches[1]))
        // A colour this build doesn't know shows the default.
        var next = model.snapshot
        next.room.wallpaper = "123456"
        model.apply(next)
        #expect(model.color(.walls) == HomePaintable.walls.swatches[0])
    }

    @Test func keepsakesComeFromWhatWasEarnedOldestFirst() {
        let model = HomeModel(night: false)
        #expect(model.keepsakes.isEmpty)
        var next = model.snapshot
        next.keepsakes = [
            EarnedKeepsake(id: "keepsake.headband.runner", at: Date(timeIntervalSince1970: 100)),
            EarnedKeepsake(id: "keepsake.unknown", at: Date(timeIntervalSince1970: 200)),
        ]
        model.apply(next)
        #expect(model.keepsakes.map(\.id) == ["keepsake.headband.runner", "keepsake.unknown"])
        #expect(model.keepsakes[0].name == ShopItem.item("keepsake.headband.runner")?.title)
    }

    @Test func thePreviewShowsEveryItemWithoutOwningIt() {
        let model = HomeModel(night: false)
        model.togglePreviewItems()
        #expect(model.items == Set(HomeItem.allCases))
        #expect(model.snapshot.owned.isEmpty)
        model.togglePreviewItems()
        #expect(model.items.isEmpty)
    }
}

@Suite struct HomeZoneTests {
    @Test func everyItemStandsInsideItsZone() throws {
        for item in HomeItem.allCases {
            let box = try #require(item.zone.box, "\(item)")
            let s = item.spot
            #expect(s.x >= box.x0 && s.x <= box.x1 && s.y >= box.y0 && s.y <= box.y1, "\(item)")
        }
    }

    @Test func wallHooksAreNotHiddenByTheWardrobe() {
        // The wardrobe's front-left corner, (6.8, 1.3), hides the back wall from x - y = 5.5 on.
        for hook in HomeZone.sportWall.slots + [HomeItem.racket.spot, HomeItem.snowboard.spot] {
            #expect(hook.x - hook.y + 0.25 < 5.5, "\(hook)")
        }
    }

    @Test func zonesHoldAsManyItemsAsPlanned() {
        #expect(HomeZone.sportFloor.slots.count == 1)
        #expect(HomeZone.sportWall.slots.count == 2)
        #expect(HomeZone.desk.slots.count == 2)
        #expect(HomeZone.sofaSide.slots.count == 1)
        #expect(HomeZone.corner.slots.count == 1)
        for zone in HomeZone.allCases {
            guard let box = zone.box else { continue }
            for slot in zone.slots {
                #expect(slot.x >= box.x0 && slot.x <= box.x1 && slot.y >= box.y0 && slot.y <= box.y1, "\(zone)")
            }
        }
    }
}

#if os(macOS)
@MainActor
@Suite struct HomeSceneTests {
    @Test func hakuWalksToTheDeskAndSitsDown() {
        let model = HomeModel(night: true)
        let scene = HomeScene(model: model)
        model.switchMode(.work)
        scene.sync(animated: false)
        #expect(scene.isWalking)
        for _ in 0..<400 { scene.step(0.05) }
        #expect(!scene.isWalking)
        #expect(scene.spotReached == .work)
    }

    @Test func everyLayerIsDrawnInsideTheRoom() {
        var layers: [HomeLayer] = HomePaintable.walls.swatches.map { .shell(walls: $0) }
        for piece in HomePiece.allCases {
            layers.append(.piece(piece, color: HomePaintable.sofa.swatches[0], covering: false))
        }
        layers.append(.piece(.blanket, color: HomePaintable.bed.swatches[0], covering: true))
        layers += HomeItem.allCases.map { .item($0) } + [.barbell]
        for layer in layers {
            #expect(!layer.rect.isEmpty, "\(layer) has no place")
            #expect(HomeGrid.canvas.insetBy(dx: -40, dy: -40).contains(layer.rect), "\(layer) leaves the room")
        }
    }

    @Test func theBarIsPressedAllTheWayUpAndBackDown() {
        let reaches = stride(from: 0.0, to: 2.6, by: 0.1).map(HakuNode.pressReach)
        #expect((reaches.min() ?? 1) < 0.01)
        #expect(abs((reaches.max() ?? 0) - 1) < 0.01)
    }

    @Test func pressingHakuTakesTheBarOffTheRack() {
        let model = HomeModel(night: false)
        let scene = HomeScene(model: model)
        model.own(.bench)
        scene.sync(animated: false)
        let bench = HomeGrid.scene(HomeGrid.plan(4.6, 2.2, 0.5))
        #expect(scene.hotspot(at: bench, includingHaku: false) == .bench)
        model.tap(.bench)
        scene.sync(animated: false)
        for _ in 0..<400 { scene.step(0.05) }
        #expect(scene.spotReached == .bench)
        scene.pose(at: 1.3)
        let up = scene.haku.barCenter
        scene.pose(at: 0.05)
        let down = scene.haku.barCenter
        #expect(up.y > down.y + 5)
        #expect(up != HomeScene.rackedBar)
    }

    @Test func tapsFindTheFurniture() {
        let scene = HomeScene(model: HomeModel(night: false))
        #expect(scene.hotspot(at: HomeGrid.scene(HomeGrid.plan(8.5, 7.5, 0.6)), includingHaku: false) == .bed)
        #expect(scene.hotspot(at: HomeGrid.scene(HomeGrid.plan(9.5, 0.6, 3.0)), includingHaku: false) == .shop)
        #expect(scene.hotspot(at: HomeGrid.scene(HomeGrid.plan(1.4, 6.0, 0.5)), includingHaku: false) == .sofa)
    }

    @Test func everyTapTargetIsAtLeast44PointsOnTheSmallestPhone() {
        // iPhone SE: 375 pt wide, 16 pt margins each side.
        let side = HomeGrid.minTap / (343 / HomeGrid.canvas.width)
        let model = HomeModel(night: false, card: .fitness)
        let scene = HomeScene(model: model)
        model.own(.bag)
        model.own(.bench)
        scene.sync(animated: false)
        scene.settle()
        let haku = scene.haku.calculateAccumulatedFrame()
        // Just right of his drawing, still within a finger's width of him.
        let beside = CGPoint(x: haku.maxX + 2, y: haku.midY)
        #expect(scene.hotspot(at: beside) != .haku)
        #expect(scene.hotspot(at: beside, minSide: side) == .haku)
        for hotspot in Set(scene.tapTargets().map(\.hotspot)) {
            let outlines = scene.tapTargets().filter { $0.hotspot == hotspot }.map(\.outline)
            let box = outlines.map { HomeScene.grown($0, to: side) }.reduce(CGRect.null) { $0.union($1) }
            #expect(box.width >= side - 0.01 && box.height >= side - 0.01, "\(hotspot)")
        }
        // Open floor on the rug, away from anything small, stays empty.
        #expect(
            scene.hotspot(at: HomeGrid.scene(HomeGrid.plan(4.8, 7.2, 0)), includingHaku: false, minSide: side) == nil)
    }

    @Test func shopIDsNameTheRoomItems() {
        #expect(HomeItem(shopID: "room.bench") == .bench)
        #expect(HomeItem(shopID: "room.snowboard") == .snowboard)
        #expect(HomeItem(shopID: "haku.weekly.room.cactus") == .cactus)
        #expect(HomeItem(shopID: "room.") == nil)
        #expect(HomeItem(shopID: "gloves.gold") == nil)
        #expect(HomeItemIcon(itemID: "room.bag") != nil)
        #expect(HomeItemPreview(itemID: "headband.red") == nil)
    }

    @Test func theRoomDrawsAStillWithoutAGPU() throws {
        let scene = HomeScene(model: HomeModel(night: false))
        let still = try #require(scene.still(scale: 2))
        #expect(still.width == Int(HomeGrid.canvas.width * 2) && still.height == Int(HomeGrid.canvas.height * 2))
        // The middle of the floor is drawn, not left clear.
        let data = try #require(still.dataProvider?.data as Data?)
        let middle = (still.height / 2) * still.bytesPerRow + (still.width / 2) * 4
        #expect(data[middle + 3] > 0)
    }

    @Test func everyDrawnRoomItemHasAHomePicture() {
        for item in ShopItem.catalog(for: .haku) where item.isDrawn && item.slot == .room {
            #expect(HomeItemIcon(itemID: item.id) != nil, "\(item.id)")
        }
    }

    @Test func thePreviewShowsHakuStandingNextToTheItem() throws {
        for item in [HomeItem.plant, .bag, .speaker, .bench, .snowboard, .cactus] {
            let model = HomeModel(night: false)
            model.own(item)
            model.standBeside(item)
            let at = try #require(model.dropPoint)
            #expect(HomeNav.room(items: model.items).nearestOpen(to: at) == at, "\(item)")
            #expect(at.distance(to: item.spot) < 3, "\(item)")
            let crop = HomeItemPreview.crop(item, haku: at)
            #expect(crop.contains(HomeItemPreview.ring(item)), "\(item)")
            #expect(crop.contains(HomeGrid.plan(at)), "\(item)")
        }
    }

    @Test func hakuStandsBesideTheBenchAndTheCactusNotInFrontOfThem() throws {
        for item in [HomeItem.bench, .cactus] {
            let x = HomeGrid.plan(HomeModel.previewSpot(item)).x
            let ring = HomeItemPreview.ring(item)
            #expect(x < ring.minX + 8 || x > ring.maxX - 8, "\(item)")
        }
    }

    @Test func hakuNodsOffOverThePhoneEveryTenSeconds() {
        #expect(HakuNode.dozeNod(2) == 0)
        #expect(HakuNode.dozeNod(8.5) == 1)
        #expect(HakuNode.dozeNod(18.5) == 1)
        #expect(HakuNode.dozeNod(9.8) == 0)
    }

    @Test func atNightHakuHoldsThePhoneInBedAndByDayHeDoesNot() {
        for night in [true, false] {
            let model = HomeModel(night: night)
            let scene = HomeScene(model: model)
            model.tap(.bed)
            scene.sync(animated: false)
            scene.settle()
            scene.pose(at: 2)
            #expect((scene.haku.heldPhone != nil) == night)
            // At night he lies on the blanket, so he is drawn over it; by day he is under it.
            #expect((scene.haku.zPosition > CGFloat(HomePiece.blanket.depth)) == night)
            if night {
                let up = scene.haku.heldPhone
                scene.pose(at: 8.5)
                let down = scene.haku.heldPhone
                #expect(up != nil && down != nil && up != down)
            }
        }
    }
}
#endif
