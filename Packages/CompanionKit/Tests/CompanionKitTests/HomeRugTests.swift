import Testing

@testable import CompanionKit

@Suite struct HomeRugTests {
    @Test func everyRugLiesUnderHakusWaitingSpot() {
        for rug in HomeRug.allCases {
            #expect(rug.box.covers(HomeSpot.hub), "\(rug)")
        }
        #expect(HomeSpot.hub.distance(to: HomeRug.centre) < HomeRug.radius)
    }
}

#if os(macOS)
@MainActor
@Suite struct HomeRugSceneTests {
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
}
#endif
