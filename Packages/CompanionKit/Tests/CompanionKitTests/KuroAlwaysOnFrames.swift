#if os(macOS)
import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// 第 5 批 常亮: her still face with the watch screen dimmed, in each of her own looks, for the UI review.
extension FrameSheets {
    @Test func kuroAlwaysOn() throws {
        let looks: [(KuroLook, String)] = [(.chill, "下班"), (.work, "上课"), (.tennis, "网球日"), (.desk, "备课")]
        let sheet = VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "第二个预设角色 · 手表常亮（静态，一分钟一帧）").font(.system(size: 16, weight: .bold))
            HStack(spacing: 8) {
                ForEach(looks.indices, id: \.self) { i in
                    let (look, name) = looks[i]
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Self.alwaysOnCell(look, dimmed: false)
                            Self.alwaysOnCell(look, dimmed: true)
                        }
                        Text(verbatim: "\(name)：亮屏 / 常亮").font(.system(size: 10, weight: .bold))
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        try save(sheet, as: "kuro-always-on", scale: 2)
    }

    /// Her watch card in `look`, with the screen dimmed when `dimmed`.
    private static func alwaysOnCell(_ look: KuroLook, dimmed: Bool) -> some View {
        let awake = KuroPose(look: look, energy: 50)
        let pose = dimmed ? KuroView.dozed(awake, look: look, bedtime: .off) : awake
        return ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Color.black)
            KuroFigure(look: look, pose: pose, watch: true)
                .aspectRatio(KuroArt.bounds.width / KuroArt.bounds.height, contentMode: .fit)
                .opacity(dimmed ? 0.6 : 1)
                .padding(.top, 16)
                .padding(.horizontal, 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(width: 90, height: 110)
    }
}
#endif
