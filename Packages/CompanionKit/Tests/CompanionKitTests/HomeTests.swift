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
                let stops = to.path(from: from.point, leaving: from)
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
        let walk = HomeWalk(stops: HomeSpot.box.path(from: HomeSpot.hub, leaving: .idle))
        #expect(walk.position(after: 0).point == HomeSpot.hub)
        #expect(walk.position(after: walk.length + 1).point == HomeSpot.box.point)
        #expect(walk.length > 3)
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
        let before = model.timeline.count
        model.switchMode(.work, at: "10:00")
        #expect(model.spot == .work)
        model.switchMode(.chill, at: "18:00")
        #expect(model.spot == .sofa)
        model.switchMode(.boxing, at: "19:00")
        #expect(model.spot == .shadowbox)
        model.switchMode(.money, at: "21:00")
        #expect(model.spot == .side)
        #expect(model.timeline.count == before + 4)
        #expect(model.timeline.last?.mode == .money)
    }

    @Test func otherCardsDoNotBox() {
        let model = HomeModel(night: false, card: .tennis)
        model.switchMode(.boxing)
        #expect(model.spot == .idle)
        #expect(!HomeProduct.offered(card: .tennis).contains(.item(.bag)))
        #expect(HomeProduct.offered(card: .boxing).contains(.item(.bag)))
    }

    @Test func withTheBagBoxingDayHitsIt() {
        let model = HomeModel(night: false)
        #expect(model.buy(.item(.bag)))
        model.switchMode(.boxing)
        #expect(model.spot == .box)
    }

    @Test func buyingSpendsCansOnceAndPlacesTheItem() {
        let model = HomeModel(night: false, cans: 30)
        #expect(model.buy(.item(.plant)))
        #expect(model.cans == 22)
        #expect(model.items.contains(.plant))
        #expect(model.takeCues() == [.placed(.plant)])
        #expect(!model.buy(.item(.plant)))
        #expect(!model.buy(.outfit(.flame)))
        #expect(model.cans == 22)
    }

    @Test func onlyOwnedOutfitsCanBeWorn() {
        let model = HomeModel(night: false, cans: 100)
        model.wear(.flame)
        #expect(model.outfit == .jacket)
        #expect(model.buy(.outfit(.flame)))
        model.wear(.flame)
        #expect(model.outfit == .flame)
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

    @Test func droppedOnTheSofaHeSitsAndOnTheFloorHeStaysOnTheRug() {
        let model = HomeModel(night: false)
        model.drop(on: .sofa, at: GridPoint(x: 1, y: 6))
        #expect(model.spot == .sofa)
        model.drop(on: nil, at: GridPoint(x: 9.5, y: 0.5))
        let p = model.dropPoint
        #expect(p == GridPoint(x: 6.2, y: 3.2))
    }

    @Test func energyComesBackOnlyInBed() {
        let model = HomeModel(night: true)
        let start = model.energy
        model.tick(10)
        #expect(model.energy == start)
        model.tap(.bed)
        model.tick(10)
        #expect(model.energy > start)
    }

    @Test func paintingPicksASwatch() {
        let model = HomeModel(night: false)
        model.paint(.sofa, 2)
        #expect(model.color(.sofa) == HomePaintable.sofa.swatches[2])
        model.paint(.sofa, 9)
        #expect(model.color(.sofa) == HomePaintable.sofa.swatches[2])
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

    @Test func tapsFindTheFurniture() {
        let scene = HomeScene(model: HomeModel(night: false))
        #expect(scene.hotspot(at: HomeGrid.scene(HomeGrid.plan(8.5, 7.5, 0.6)), includingHaku: false) == .bed)
        #expect(scene.hotspot(at: HomeGrid.scene(HomeGrid.plan(9.5, 0.6, 3.0)), includingHaku: false) == .shop)
        #expect(scene.hotspot(at: HomeGrid.scene(HomeGrid.plan(1.4, 6.0, 0.5)), includingHaku: false) == .sofa)
    }
}
#endif
