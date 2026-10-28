#if os(macOS)
import HubCore
import SwiftUI
import Testing

@testable import CompanionKit

// KURO-08: her widget, Lock Screen and watch face portrait in each state of the day, for the UI review.
extension FrameSheets {
    @Test func kuroPortraitStates() throws {
        let states: [(String, KuroLook, CompanionNeed?, CompanionMoment?)] = [
            ("平常", .chill, nil, nil), ("需要（久坐）", .chill, .sitting, nil), ("累", .chill, nil, .drowsy),
            ("专注", .desk, nil, .flow), ("加班", .work, nil, .overtime),
        ]
        let sheet = VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "第二个预设角色 · 头像跟状态（彩色小组件 / 锁屏长条单色 / 锁屏圆形单色）")
                .font(.system(size: 16, weight: .bold))
            HStack(alignment: .top, spacing: 12) {
                ForEach(states.indices, id: \.self) { i in
                    let (name, look, need, moment) = states[i]
                    VStack(spacing: 6) {
                        KuroPortrait(look: look, energy: 50, moment: moment, need: need)
                            .frame(width: 120, height: 120)
                            .background(RoundedRectangle(cornerRadius: 20).fill(look.color))
                        KuroPortrait(look: look, energy: 50, moment: moment, need: need, lineArt: true)
                            .frame(width: 120, height: 56)
                            .grayscale(1)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black))
                        KuroPortrait(look: look, energy: 50, moment: moment, need: need, framing: .head, lineArt: true)
                            .frame(width: 56, height: 56)
                            .grayscale(1)
                            .background(Circle().fill(Color.black))
                            .clipShape(Circle())
                        Text(verbatim: name).font(.system(size: 11, weight: .bold))
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        try save(sheet, as: "kuro-portrait-states", scale: 2)
    }
}
#endif
