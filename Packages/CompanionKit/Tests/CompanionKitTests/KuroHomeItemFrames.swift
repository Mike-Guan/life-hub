#if os(macOS)
import HubCore
import SpriteKit
import SwiftUI
import Testing

@testable import CompanionKit

// 商店扩充 v1 §2.3: her ten room items standing in her home, in two halves since each zone shows one or two at once.
extension FrameSheets {
    @Test func kuroHomeRoomItems() throws {
        let halves: [[HomeItem]] = [
            [.catPoster, .catClock, .jar, .yarn, .sakura],
            [.starsPoster, .strawberryMug, .mirror, .plush, .easel],
        ]
        var cells: [(String, CGImage)] = []
        var sceneHeight: CGFloat = 0
        for night in [false, true] {
            for (i, items) in halves.enumerated() {
                var snapshot = HomeSnapshot.preview()
                snapshot.persona = .kuro
                let model = HomeModel(snapshot: snapshot, night: night, now: HomeModel.start)
                let scene = HomeScene(model: model)
                model.stand(items)
                scene.sync(animated: false)
                scene.settle()
                scene.pose(at: 1.3)
                sceneHeight = scene.size.height
                cells.append(("第 \(i + 1) 组 · \(night ? "夜" : "白天")", try #require(Self.composite(scene, scale: 2))))
            }
        }
        // The corner close up, where the sakura and the easel stand by the floor lamp.
        let corner = HomeGrid.bounds(
            HomePiece.floorLamp.boxes + HomeArt.boxes(.sakura) + HomeArt.boxes(.easel), margin: 16)
        let close = try cells.map { label, image in
            let a = HomeGrid.scene(CGPoint(x: corner.minX, y: corner.minY))
            let b = HomeGrid.scene(CGPoint(x: corner.maxX, y: corner.maxY))
            let rect = CGRect(
                x: min(a.x, b.x) * 2, y: (sceneHeight - max(a.y, b.y)) * 2, width: abs(b.x - a.x) * 2,
                height: abs(b.y - a.y) * 2)
            return (label, try #require(image.cropping(to: rect)))
        }
        let closeSheet = HStack(alignment: .top, spacing: 12) {
            ForEach(close.indices, id: \.self) { i in
                VStack(spacing: 6) {
                    Image(decorative: close[i].1, scale: 1)
                    Text(verbatim: close[i].0).font(.system(size: 14, weight: .bold))
                }
            }
        }
        .padding(12)
        .background(Color.white)
        try save(closeSheet, as: "kuro-home-3-corner", scale: 1)
        let sheet = VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: "家 · 她的房间物品 10 件（两组）").font(.system(size: 20, weight: .bold))
            LazyVGrid(columns: [GridItem(.fixed(500)), GridItem(.fixed(500))], spacing: 14) {
                ForEach(cells.indices, id: \.self) { i in
                    VStack(spacing: 4) {
                        Image(decorative: cells[i].1, scale: 2).resizable().aspectRatio(contentMode: .fit)
                            .frame(width: 500).background(Toy.paper)
                        Text(verbatim: cells[i].0).font(.system(size: 13, weight: .bold))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        try save(sheet, as: "kuro-home-2-room-items", scale: 1)
    }
}
#endif
