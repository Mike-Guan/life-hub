#if os(macOS)
import SwiftUI
import Testing

// Issue #481: CI can't open Control Center, so this measures the 模式卡 control's name instead of a screenshot.
// The system draws the control's title in its own font, about 13 pt semibold, and doesn't shrink it. On the
// smallest iPhone (375 pt wide) a 2×1 control is about 156 pt wide; its symbol and padding leave about 100 pt
// for the title. 1×1 controls and the Lock Screen corners show only the symbol. Keep these numbers in step
// with an on-device check.
@MainActor
@Suite struct ControlLabelFitTests {
    /// The width left for the title in a 2×1 control on the smallest iPhone.
    static let room: CGFloat = 100

    func width(_ text: String) throws -> CGFloat {
        let renderer = ImageRenderer(content: Text(text).font(.system(size: 13, weight: .semibold)).fixedSize())
        renderer.scale = 1
        return CGFloat(try #require(renderer.cgImage).width)
    }

    // The widest four-character name `ModeCards.nameWidth` allows, and the longest ja and en default names of
    // 副业 and the identity cards in HubCore's catalog.
    @Test(arguments: ["一二三四", "Swimming", "Outdoors", "Projects", "スキー・スノボ", "描く・つくる"])
    func theLongestNameFitsWithoutCutting(_ name: String) throws {
        let text = try width(name)
        print("control title \(name): \(text) pt for \(Self.room) pt")
        #expect(text <= Self.room)
    }
}
#endif
