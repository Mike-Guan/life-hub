#if os(macOS)
import SwiftUI
import Testing

@testable import CompanionKit

// 第 5 批 晚安: her good night as bedtime starts, frame by frame in two looks, for the UI review.
extension FrameSheets {
    @Test func kuroGoodNight() throws {
        let looks: [(KuroLook, String)] = [(.chill, "下班"), (.work, "上课")]
        let steps = Array(stride(from: 0.0, through: 1.0, by: 1.0 / 9))
        let sheet = VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "第二个预设角色 · 晚安（3.2 s，每格间隔 0.36 s）").font(.system(size: 16, weight: .bold))
            ForEach(looks.indices, id: \.self) { row in
                let (look, name) = looks[row]
                HStack(spacing: 6) {
                    ForEach(steps.indices, id: \.self) { i in
                        VStack(spacing: 2) {
                            Self.goodNightCell(look, progress: min(steps[i], 0.999))
                            Text(verbatim: "\(name) \(String(format: "%.1f", steps[i] * 3.2)) s")
                                .font(.system(size: 10, weight: .bold))
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        try save(sheet, as: "kuro-goodnight", scale: 2)
    }

    /// Her card at bedtime `progress` (0..<1) into her good night.
    private static func goodNightCell(_ look: KuroLook, progress p: Double) -> some View {
        let rest = KuroPose(look: look, energy: 50, bedtime: .on)
        let motion = KuroView.goodNight((.goodNight, p), time: 0) ?? IdleMotion(dy: 0, angle: 0)
        return ZStack {
            RoundedRectangle(cornerRadius: 12).fill(look.color).overlay { Toy.ink.opacity(0.35) }
            KuroFigure(look: look, pose: rest.reacting(.goodNight, progress: p))
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
