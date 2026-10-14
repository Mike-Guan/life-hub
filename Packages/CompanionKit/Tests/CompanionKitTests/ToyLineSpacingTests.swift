import Foundation
import Testing

@testable import CompanionKit

@Suite struct ToyLineSpacingTests {
    @Test(arguments: ["zh-Hans", "ja"])
    func cjkGetsMoreRoom(identifier: String) {
        let language = Locale.Language(identifier: identifier)
        #expect(Toy.lineSpacing(15, language: language) == 4)
        #expect(Toy.lineSpacing(16, language: language) == 4)
        #expect(Toy.lineSpacing(12, language: language) == 3)
        #expect(Toy.lineSpacing(13, language: language) == 3)
    }

    @Test func englishGetsTwoPoints() {
        let language = Locale.Language(identifier: "en")
        #expect(Toy.lineSpacing(15, language: language) == 2)
        #expect(Toy.lineSpacing(12, language: language) == 2)
    }
}
