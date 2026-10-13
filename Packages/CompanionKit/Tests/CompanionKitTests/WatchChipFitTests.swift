#if os(macOS)
import SwiftUI
import Testing

@testable import CompanionKit

// QA S5 (00 团队/QA/Mike 找过的错 自动测试对照.md): the mode chip sits left of the system clock in the
// watch's top row. The watch app has no test target, so this measures the same text and font as `ModeChip`
// in Apps/Watch/LifeHubWatchApp.swift and repeats its layout numbers; keep the two in step.
@MainActor
@Suite struct WatchChipFitTests {
    /// The 40 mm watch's screen width in points, the smallest watch.
    static let screenWidth: CGFloat = 162
    /// `ModeChip.widthShare`: the share of the width the chip may take, its leading inset included.
    static let widthShare: CGFloat = 0.64
    /// The chip's leading inset.
    static let leading: CGFloat = 14
    /// The chip's horizontal padding, both sides.
    static let padding: CGFloat = 16
    /// How far `ModeChip` may shrink its text.
    static let minimumScale: CGFloat = 0.7

    func width(_ view: some View) throws -> CGFloat {
        let renderer = ImageRenderer(content: view.fixedSize())
        renderer.scale = 1
        return CGFloat(try #require(renderer.cgImage).width)
    }

    // The watch draws its clock in the system font; "10:09" is about as wide as times get.
    // The macOS stand-in is the system font at the watch clock's size.
    @Test func theChipEndsBeforeTheClock() throws {
        let clock = try width(Text("10:09").font(.system(size: 16, weight: .semibold)))
        #expect(Self.screenWidth * Self.widthShare + 4 <= Self.screenWidth - clock)
    }

    // The two widest names `ModeCards.nameWidth` allows, and the chip's text with no mode.
    @Test(arguments: ["一二三四", "WWWWWWWW", "还没有模式"])
    func theWidestNameFitsWithoutCutting(_ name: String) throws {
        let text = try width(Text(name).font(Toy.body(12, weight: .heavy)).lineLimit(1))
        let room = Self.screenWidth * Self.widthShare - Self.leading - Self.padding
        print("watch chip \(name): \(text) pt for \(room) pt, scale \(min(1, room / text))")
        #expect(text * Self.minimumScale <= room)
    }
}
#endif
