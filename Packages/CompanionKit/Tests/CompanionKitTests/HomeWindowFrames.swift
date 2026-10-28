#if os(macOS)
import Foundation
import HubCore
import SpriteKit
import SwiftUI
import Testing

@testable import CompanionKit

// Throwaway: stills of the whole room per mode, for the home-screen window design (UI 二组).
extension FrameSheets {
    @Test func homeWindowStills() throws {
        let folder = try #require(ProcessInfo.processInfo.environment["FRAME_SHEETS"])
        var spots: [String: [Double]] = [:]
        let states: [(String, Bool, (HomeModel) -> Void)] = [
            ("work-day", false, { $0.switchMode(.work) }),
            ("work-night", true, { $0.switchMode(.work) }),
            ("chill-day", false, { $0.switchMode(.chill) }),
            ("chill-night", true, { $0.switchMode(.chill) }),
            ("box-day", false, { $0.switchMode(.boxing) }),
            ("money-night", true, { $0.switchMode(.money) }),
            ("bed-night", true, { $0.tap(.bed) }),
            ("none-day", false, { _ in }),
        ]
        for persona in [Persona.haku, .kuro] {
            for (label, night, setup) in states {
                var snapshot = HomeSnapshot.preview()
                snapshot.persona = persona
                snapshot.cards = ModeCards(identity: persona == .kuro ? .tennis : .boxing)
                let model = HomeModel(snapshot: snapshot, night: night, now: HomeModel.start)
                let scene = HomeScene(model: model)
                setup(model)
                scene.sync(animated: false)
                scene.settle()
                scene.pose(at: 1.3)
                let image = try #require(scene.still(scale: 2))
                let name = "win-\(persona.rawValue)-\(label)"
                try save(Image(decorative: image, scale: 2), as: name, scale: 2)
                spots[name] = [
                    Double(scene.haku.position.x), Double(scene.haku.position.y), Double(scene.size.width),
                    Double(scene.size.height),
                ]
            }
        }
        let data = try JSONSerialization.data(withJSONObject: spots, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: folder).appendingPathComponent("win-spots.json"))
    }
}
#endif
