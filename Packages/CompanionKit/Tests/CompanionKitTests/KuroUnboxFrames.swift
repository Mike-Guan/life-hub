#if os(macOS)
import SwiftUI
import Testing

@testable import CompanionKit

// KURO-25: her pop out of the gift box and the spin, frame by frame, for the UI review.
extension FrameSheets {
    @Test func kuroUnbox() throws {
        let items: [(KuroItem, String)] = [(.spin, "转一圈"), (.scrunchie, "发圈")]
        let steps = Array(stride(from: 0.3, through: 0.8, by: 0.05))
        let sheet = VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "第二个预设角色 · 开箱冒出来和转一圈（3.2 s，每格间隔 0.16 s）")
                .font(.system(size: 16, weight: .bold))
            ForEach(items.indices, id: \.self) { row in
                let (item, name) = items[row]
                HStack(spacing: 6) {
                    ForEach(steps.indices, id: \.self) { i in
                        VStack(spacing: 2) {
                            Self.unboxCell(item, progress: steps[i])
                            Text(verbatim: "\(name) \(String(format: "%.2f", steps[i] * 3.2)) s")
                                .font(.system(size: 10, weight: .bold))
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        try save(sheet, as: "kuro-unbox", scale: 2)
    }

    /// Her card `progress` (0..<1) into unboxing `item`, posed as `KuroView` poses her.
    private static func unboxCell(_ item: KuroItem, progress p: Double) -> some View {
        let unbox = KuroUnbox(item, progress: p)
        var pose = KuroPose(look: .chill, energy: nil).showing(.low)
        pose.calm = true
        pose.facingAway = unbox.spin < 0
        pose.items = [item]
        return ZStack {
            RoundedRectangle(cornerRadius: 12).fill(KuroLook.chill.color)
            ZStack {
                KuroFigure(look: .chill, pose: pose)
                    .scaleEffect(x: unbox.spin * unbox.popOut, y: max(unbox.popOut, 0.001), anchor: .bottom)
                GiftBox(progress: unbox.box, fill: RunnerPalette.cardboard, ribbon: KuroPalette.pink)
            }
            .aspectRatio(KuroArt.bounds.width / KuroArt.bounds.height, contentMode: .fit)
            .padding(.top, 20)
            .padding(.horizontal, 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(width: 96, height: 120)
    }
}
#endif
