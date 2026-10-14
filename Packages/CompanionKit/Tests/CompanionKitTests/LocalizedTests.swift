import HubCore
import Testing

@testable import CompanionKit

struct LocalizedTests {
    // Issue #350: with Japanese and English off (the default), bubble lines stay Chinese.
    @Test func bubbleLinesStayChineseWhileLanguagesAreOff() {
        #expect(!Languages.isOn)
        #expect(CompanionLines.celebration(.boxing).localized(for: .haku) == "……其实还挺爽的。")
        #expect(KuroBubbleLines.celebration(.boxing).localized(for: .kuro) == KuroBubbleLines.celebration(.boxing))
    }
}
