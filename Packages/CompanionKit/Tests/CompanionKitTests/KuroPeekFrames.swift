#if os(macOS)
import SwiftUI
import Testing

@testable import CompanionKit

// 第 5 批 偷看: her peek for a need, frame by frame in three looks, for the UI review.
extension FrameSheets {
    @Test func kuroPeek() throws {
        let looks: [(KuroLook, String)] = [(.chill, "下班"), (.work, "上课"), (.desk, "备课")]
        let steps = Array(stride(from: 0.0, through: 1.0, by: 1.0 / 8))
        let sheet = VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "第二个预设角色 · 偷看（2 s，每 6 s 一次，每格间隔 0.25 s）").font(.system(size: 16, weight: .bold))
            ForEach(looks.indices, id: \.self) { row in
                let (look, name) = looks[row]
                HStack(spacing: 6) {
                    ForEach(steps.indices, id: \.self) { i in
                        VStack(spacing: 2) {
                            Self.peekCell(look, progress: min(steps[i], 0.999))
                            Text(verbatim: "\(name) \(String(format: "%.2f", steps[i] * 2)) s")
                                .font(.system(size: 10, weight: .bold))
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        try save(sheet, as: "kuro-peek", scale: 2)
    }

    /// Her card `progress` (0..<1) into her peek, with a need showing.
    private static func peekCell(_ look: KuroLook, progress p: Double) -> some View {
        let rest = KuroSlot.peek.dressing(KuroPose(look: look, energy: 50))
        let still = IdleMotion(dy: 0, angle: 0)
        let motion = KuroView.peek((.peek, p), motion: still) ?? still
        return ZStack {
            RoundedRectangle(cornerRadius: 12).fill(look.color)
            KuroFigure(look: look, pose: rest.reacting(.peek, progress: p))
                .aspectRatio(KuroArt.bounds.width / KuroArt.bounds.height, contentMode: .fit)
                .rotationEffect(.degrees(motion.angle), anchor: .bottom)
                .offset(y: motion.dy)
                .padding(.top, 20)
                .padding(.horizontal, 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(width: 96, height: 120)
    }
}
#endif
