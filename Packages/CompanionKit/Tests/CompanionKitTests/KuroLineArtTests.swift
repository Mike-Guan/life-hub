import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

@Suite struct KuroLineArtTests {
    // UI-03 (UI 审核 2026-10-08): on a tinted Lock Screen her dark hair, mask and top came out as one solid block.
    @Test(arguments: KuroLook.allCases)
    func herLineArtHasNoDarkFills(_ look: KuroLook) {
        let parts = KuroFigure.parts(for: look, pose: KuroPose(look: look, energy: 50))
        let fills = parts.flatMap { KuroArt.lineArt(KuroArt.cachedInks($0)) }.compactMap(\.fill)
        #expect(fills.allSatisfy { !KuroArt.darkFills.contains($0) })
    }

    @Test func lineArtKeepsOutlinesAndLightFills() {
        let inks = KuroArt.cachedInks(.hairFringe)
        let lines = KuroArt.lineArt(inks)
        #expect(inks.contains { $0.fill == KuroPalette.hair })
        #expect(lines.map(\.stroke) == inks.map(\.stroke))
        #expect(KuroArt.lineArt(KuroArt.cachedInks(.faceBase)).map(\.fill) == KuroArt.cachedInks(.faceBase).map(\.fill))
    }
}
