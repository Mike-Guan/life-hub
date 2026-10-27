#if os(macOS)
import SwiftUI
import Testing

@testable import CompanionKit

// 商店扩充 v1 §2.3: her room items as the home draws them, each close up on a patch of its place, for the UI review.
extension FrameSheets {
    @Test func kuroRoomItems() throws {
        let cells: [(KuroRoomItem, String, GridPoint, RoomPatch)] = [
            (.posterCat, "猫咪海报", GridPoint(x: 0, y: 1.35, z: 3.4), .wall),
            (.posterStars, "星空海报", GridPoint(x: 0, y: 2.6, z: 3.4), .wall),
            (.clockCat, "小猫闹钟", GridPoint(x: 0.6, y: 2.0, z: 1.35), .desk),
            (.jar, "香薰小罐", GridPoint(x: 0.6, y: 2.0, z: 1.35), .desk),
            (.mugStrawberry, "草莓牛奶杯", GridPoint(x: 0.6, y: 2.0, z: 1.35), .desk),
            (.mirror, "小圆镜", GridPoint(x: 0.6, y: 2.0, z: 1.35), .desk),
            (.yarn, "毛线篮", GridPoint(x: 2.6, y: 8.5), .floor),
            (.plush, "猫猫玩偶", GridPoint(x: 2.6, y: 8.5), .floor),
            (.sakura, "樱花盆栽", GridPoint(x: 1.5, y: 9.3), .floor),
            (.easel, "小画架", GridPoint(x: 1.6, y: 9.0), .floor),
        ]
        let sheet = VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "家 · 第二个预设角色的房间物品（代码画，每格放大 2 倍）")
                .font(.system(size: 16, weight: .bold))
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(200)), count: 4), spacing: 10) {
                ForEach(cells.indices, id: \.self) { i in
                    let (item, label, spot, place) = cells[i]
                    VStack(spacing: 2) {
                        Self.roomCell(item, at: spot, place: place).frame(width: 200, height: 160)
                        Text(verbatim: label).font(.system(size: 12, weight: .bold))
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        try save(sheet, as: "kuro-room-items", scale: 2)
    }

    enum RoomPatch { case wall, desk, floor }

    /// `item` at `spot` on a patch of wall, desk or floor, centred on the spot and drawn twice the room's size.
    private static func roomCell(_ item: KuroRoomItem, at spot: GridPoint, place: RoomPatch) -> some View {
        Canvas { context, size in
            let lift = place == .floor ? 0.6 : place == .desk ? 0.35 : 0
            let centre = HomeGrid.plan(spot.x, spot.y, spot.z + lift)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0xFFF6E5)))
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.scaleBy(x: 2, y: 2)
            context.translateBy(x: -centre.x, y: -centre.y)
            let pen = IsoPen(context: context)
            switch place {
            case .wall:
                pen.onLeftWall(x: 0, -1, 1.4, 5, 6, Color(hex: 0xF4E6CC), line: 0)
                pen.box(0, 0.4, 1.25, 1.5, 3.4, 1.35, HomeColors.wood, top: tone(HomeColors.wood, 0.25))
            case .desk:
                pen.onLeftWall(x: 0, -1, 1.2, 5, 4, Color(hex: 0xF4E6CC), line: 0)
                pen.box(0, 0.4, 1.25, 1.5, 3.4, 1.35, HomeColors.wood, top: tone(HomeColors.wood, 0.25))
            case .floor:
                pen.floor(-1, 5, 6, 12, Color(hex: HomeColors.floor), line: 0)
            }
            KuroRoomArt.draw(item, pen, at: spot)
        }
    }
}
#endif
