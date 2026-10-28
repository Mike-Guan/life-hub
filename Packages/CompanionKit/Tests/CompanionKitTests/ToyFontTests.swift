import Foundation
import SwiftUI
import Testing

@testable import CompanionKit

@Suite struct ToyFontTests {
    @Test func japaneseUsesZenMaruGothicForBoldAndBlack() {
        let japanese = Locale.Language(identifier: "ja")
        #expect(Toy.japaneseFace(.semibold, language: japanese) == AppFonts.japaneseBold)
        #expect(Toy.japaneseFace(.bold, language: japanese) == AppFonts.japaneseBold)
        #expect(Toy.japaneseFace(.heavy, language: japanese) == AppFonts.japaneseBlack)
        #expect(Toy.japaneseFace(.black, language: japanese) == AppFonts.japaneseBlack)
        #expect(Toy.japaneseFace(.regular, language: japanese) == nil)
    }

    @Test(arguments: ["zh-Hans", "en"])
    func otherLanguagesKeepTheSystemFont(identifier: String) {
        let language = Locale.Language(identifier: identifier)
        #expect(Toy.japaneseFace(.black, language: language) == nil)
        #expect(Toy.japaneseFace(.semibold, language: language) == nil)
    }
}
