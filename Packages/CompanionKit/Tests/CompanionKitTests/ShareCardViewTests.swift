#if os(macOS)
import CoreGraphics
import Foundation
import HubCore
import ImageIO
import Testing

@testable import CompanionKit

// Issue #352 PR B: the card is drawn at the export size and saved as a PNG with no metadata to give away.
@Suite @MainActor struct ShareCardViewTests {
    let look = Look(mode: .work, wardrobe: Wardrobe(), card: .boxing)

    func make(_ id: String, persona: Persona = .haku) throws -> ShareCard {
        let item = try #require(ShopItem.item(id))
        return try #require(ShareCard(persona: persona, look: look, item: item))
    }

    @Test(arguments: ShareCard.Shape.allCases)
    func aCardDrawsAtTheExportSize(_ shape: ShareCard.Shape) throws {
        let card = try make("gloves.gold")
        let image = try #require(ShareCardView(card: card, words: card.words(counting: "拳击"), shape: shape).image())
        #expect(image.width == Int(shape.size.width) * 3)
        #expect(image.height == Int(shape.size.height) * 3)
    }

    @Test func thePictureIsAPNGWithNoPlaceOrTime() throws {
        let card = try make("gloves.gold")
        let image = try #require(ShareCardView(card: card, words: card.words(counting: "拳击"), shape: .square).image())
        let data = try #require(SharePNG.data(image))
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        #expect(CGImageSourceGetType(source) as String? == "public.png")
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        // ImageIO reports the pixel size in an Exif dictionary of its own; nothing else may be there.
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        #expect(exif[kCGImagePropertyExifDateTimeOriginal] == nil)
        #expect(exif[kCGImagePropertyExifDateTimeDigitized] == nil)
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        #expect(tiff[kCGImagePropertyTIFFDateTime] == nil)
        #expect(tiff[kCGImagePropertyTIFFMake] == nil)
        #expect(tiff[kCGImagePropertyTIFFModel] == nil)
    }

    // The card's colour is the mode that shows the item, so the item is on the character.
    @Test func aCardTakesTheModeThatShowsItsItem() throws {
        #expect(try make("gloves.gold").mode == .boxing)
        #expect(try make("haku.top.chill.aloha").mode == .chill)
        #expect(try make("kuro.top.work.blouse", persona: .kuro).mode == .work)
        #expect(ShareCard(persona: .haku, look: look, subject: .outfit("future.item")).mode == .work)
    }

    // 日语文案 10/15: a Japanese name breaks only between its marked phrases; other languages keep their breaks.
    @Test func japaneseNamesBreakOnlyBetweenPhrases() {
        let ja = Locale.Language(identifier: "ja")
        let (joiner, space) = ("\u{2060}", "\u{200B}")
        let cushion = ["雲", joiner, "の", space, ["ク", "ッ", "シ", "ョ", "ン"].joined(separator: joiner)].joined()
        #expect(ShareCardView.breakable("雲のクッション", language: ja) == cushion)
        #expect(ShareCardView.breakable("観葉植物", language: ja) == ["観", "葉", "植", "物"].joined(separator: joiner))
        let zh = Locale.Language(identifier: "zh-Hans")
        #expect(ShareCardView.breakable("雲のクッション", language: zh) == "雲のクッション")
        #expect(ShareCardView.breakable("新しい名前", language: ja) == "新しい名前")
    }
}
#endif
