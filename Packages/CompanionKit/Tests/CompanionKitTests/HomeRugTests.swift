import HubCore
import Testing

@testable import CompanionKit

@Suite struct HomeRugTests {
    @Test func everyRugLiesUnderHakusWaitingSpot() {
        for rug in HomeRug.allCases {
            #expect(rug.box.covers(HomeSpot.hub), "\(rug)")
        }
        #expect(HomeSpot.hub.distance(to: HomeRug.centre) < HomeRug.radius)
    }

    @Test func aRugsShopIDNamesItsStyle() {
        #expect(HomeRug(shopID: "room.rug.stripe") == .stripe)
        #expect(HomeRug(shopID: "kuro.room.rug.round") == .round)
        for id in ["room.rug.fringe", "room.bench", nil] { #expect(HomeRug(shopID: id) == nil) }
        for persona in Persona.allCases {
            #expect(HomeRug.fringe.shopID(for: persona) == nil)
            for rug in HomeRug.allCases {
                guard let id = rug.shopID(for: persona) else { continue }
                #expect(ShopItem.item(id)?.persona == persona, "\(id)")
                #expect(HomeRug(shopID: id) == rug)
            }
        }
    }

    @MainActor @Test func theRoomOffersTheBoughtRugsAndSavesTheOneLaid() {
        let model = HomeModel(snapshot: .preview(owning: ["room.rug.round"]), night: false)
        #expect(model.rugs == [.fringe, .round])
        #expect(model.rug == .fringe)
        let saved = model.lay(.round, deviceID: "a")
        #expect(saved.rug == "room.rug.round")
        #expect(model.rug == .round)
        #expect(model.lay(.fringe).rug == nil)
    }
}

#if os(macOS)
@MainActor
@Suite struct HomeRugSceneTests {
    @Test func aRugsPreviewCirclesTheFloorItCovers() {
        #expect(HomeItemPreview(itemID: "room.rug.stripe") != nil)
        #expect(HomeItemPreview(itemID: "kuro.room.rug.round") != nil)
        #expect(HomeItemPreview(itemID: "room.rug.fringe") == nil)
        for rug in HomeRug.allCases {
            let ring = HomeItemPreview.ring(rug)
            #expect(ring.contains(HomeLayer.rug(rug, color: HomePaintable.rug.swatches[0]).rect.insetBy(dx: 4, dy: 4)))
            #expect(HomeItemPreview.crop(ring, haku: HomeSpot.hub).contains(ring), "\(rug)")
        }
    }

    @Test func everyRugIsDrawnInsideTheRoom() {
        for rug in HomeRug.allCases {
            let rect = HomeLayer.rug(rug, color: HomePaintable.rug.swatches[0]).rect
            #expect(HomeGrid.canvas.contains(rect), "\(rug)")
        }
    }

    @Test func layingARugRedrawsItInItsStyleAndColour() throws {
        let model = HomeModel(night: false)
        let scene = HomeScene(model: model)
        scene.sync(animated: false)
        func rugLayer() -> HomeLayer? {
            scene.children.compactMap { ($0 as? HomeLayerNode)?.layer }.first {
                if case .rug = $0 { true } else { false }
            }
        }
        #expect(rugLayer() == .rug(.fringe, color: HomePaintable.rug.swatches[0]))
        model.lay(.round)
        model.paint(.rug, 2)
        scene.sync(animated: false)
        #expect(rugLayer() == .rug(.round, color: HomePaintable.rug.swatches[2]))
    }

    @Test func aNewStyleAloneRedrawsTheRug() {
        let model = HomeModel(night: false)
        let scene = HomeScene(model: model)
        scene.sync(animated: false)
        model.lay(.stripe)
        scene.sync(animated: false)
        let rug = scene.children.compactMap { $0 as? HomeLayerNode }.first {
            if case .rug = $0.layer { true } else { false }
        }
        #expect(rug?.layer == .rug(.stripe, color: HomePaintable.rug.swatches[0]))
        #expect(rug?.alpha == 1)
    }
}
#endif
