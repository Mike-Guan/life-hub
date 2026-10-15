import Foundation
import HubCore
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

// Issue #352 PR B. Layout from 分享卡与合影样张 v3.1 (UI 二组, passed by UI 审核 10/15); sizes in points from its
// table. Cards are static: the export is one picture.

extension ShareCard {
    // 样张 v3.1: the card takes the colour of its item's mode, and the character stands in that mode so the item
    // shows on her, as on the unboxing.
    /// The mode the card is coloured with and the character drawn in.
    public var mode: Mode {
        guard let item else { return look.mode ?? .chill }
        if let mode = item.mode { return mode }
        if let kuro = KuroItem(rawValue: item.id) {
            return Mode.allCases.first { KuroLook(mode: $0) == kuro.look } ?? .chill
        }
        return item.slot.showcaseMode
    }
}

/// One share card: the character wearing the item, its name and her line, on the mode's colour.
public struct ShareCardView: View {
    let card: ShareCard
    let words: ShareCard.Words
    let shape: ShareCard.Shape
    let language: Locale.Language

    /// - Parameters:
    ///   - card: what the card shows.
    ///   - words: the card's text, usually `card.words(counting:)`.
    ///   - shape: 9:16 or 1:1.
    ///   - language: the language of the text, which picks the font.
    public init(
        card: ShareCard,
        words: ShareCard.Words,
        shape: ShareCard.Shape,
        language: Locale.Language = Languages.locale.language
    ) {
        self.card = card
        self.words = words
        self.shape = shape
        self.language = language
    }

    private var isStory: Bool { shape == .story }
    private var isKeepsake: Bool {
        if case .keepsake = card.subject { return true }
        return false
    }

    public var body: some View {
        Group {
            if isStory {
                if isKeepsake { keepsakeStory } else { outfitStory }
            } else {
                square
            }
        }
        .foregroundStyle(Toy.ink)
        .frame(width: shape.size.width, height: shape.size.height)
        .background(card.mode.color(for: card.persona))
    }

    /// The card drawn at scale 3, `nil` when it can't be drawn.
    @MainActor public func image() -> CGImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3
        return renderer.cgImage
    }

    // Name top left, the item tilted top right, then the character, the title, the count and the line.
    // UI 审核 10/15 round 1: the item hangs off the character's top right, so a two-line title lifts both
    // together and the item never covers her hair.
    private var keepsakeStory: some View {
        VStack(alignment: .leading, spacing: 0) {
            name(15)
            Spacer(minLength: 0)
            sticker(253)
                .background(alignment: .topTrailing) {
                    if let item = card.item {
                        ShopItemIcon(item: item)
                            .frame(width: 167, height: 167)
                            .rotationEffect(.degrees(14))
                            .offset(x: 57, y: -138)
                    }
                }
                .padding(.leading, 6)
            title(50)
            subtitle(19)
            bubble(15)
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 27)
        .padding(.top, 32)
        .padding(.bottom, 44)
    }

    // Name, "put on", the title, then the character in the lower half and her line.
    private var outfitStory: some View {
        VStack(alignment: .leading, spacing: 0) {
            name(15)
            if let eyebrow = words.eyebrow {
                Text(eyebrow)
                    .font(font(19, .heavy))
                    .padding(.top, 14)
            }
            title(50)
            Spacer(minLength: 0)
            sticker(233)
                .padding(.leading, 22)
            bubble(15)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 27)
        .padding(.top, 32)
        .padding(.bottom, 44)
    }

    // UI 审核 10/15 condition 2: the name sits top left and everything else is one group, centred in the height
    // left below it. An outfit card puts the name in its eyebrow instead.
    private var square: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isKeepsake { name(13) }
            HStack(alignment: .center, spacing: 10) {
                sticker(isKeepsake ? 157 : 167)
                VStack(alignment: .leading, spacing: 0) {
                    if isKeepsake, let item = card.item {
                        ShopItemIcon(item: item)
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(14))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    if let eyebrow = words.eyebrow {
                        Text(verbatim: "\(words.name) \(eyebrow)")
                            .font(font(13, .black))
                            .tracking(13 * 0.06)
                            .padding(.bottom, 4)
                    }
                    title(37, lines: 3)
                    subtitle(16)
                    bubble(13)
                        .padding(.top, 12)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 21)
        .padding(.top, 21)
        .padding(.bottom, 21)
    }

    private func name(_ size: CGFloat) -> some View {
        Text(words.name)
            .font(font(size, .black))
            .tracking(size * 0.06)
    }

    // 样张 v3.1: at most two lines, then the text shrinks to 85% and no further. UI 审核 10/15 round 1: a 1:1 card
    // takes three lines, so the longest Japanese name never ends in "…".
    private func title(_ size: CGFloat, lines: Int = 2) -> some View {
        Text(Self.breakable(words.title, language: language))
            .font(font(size, .black))
            .lineLimit(lines)
            .minimumScaleFactor(0.85)
    }

    @ViewBuilder private func subtitle(_ size: CGFloat) -> some View {
        if let subtitle = words.subtitle {
            Text(subtitle)
                .font(font(size, .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.top, 4)
        }
    }

    private func bubble(_ size: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return Text(words.line)
            .font(font(size, .heavy))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(shape.fill(Toy.card))
            .overlay(shape.stroke(Toy.ink, lineWidth: 2))
            .background(shape.fill(Toy.ink).offset(x: 3.3, y: 3.3))
    }

    private func sticker(_ width: CGFloat) -> some View {
        let look = card.wornLook
        return PersonaPortrait(persona: card.persona, mode: card.mode, card: look.card, wardrobe: look.wardrobe)
            .frame(width: width, height: width)
            .stickerOutline()
    }

    // The card's language may differ from the app's while drawing review sheets, so the Japanese face is
    // picked from `language` rather than the app's locale.
    private func font(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        if let face = Toy.japaneseFace(weight, language: language) {
            return .custom(face, fixedSize: size)
        }
        return .system(size: size, weight: weight, design: .rounded)
    }
}

extension View {
    // 样张 v3.1 sticker: a 3 pt white edge so it reads on dark photos, and a soft shadow for light ones.
    /// Draws a white edge `width` points wide around the view's shape, and a soft drop shadow.
    public func stickerOutline(_ width: CGFloat = 3) -> some View {
        modifier(StickerOutline(width: width))
    }
}

private struct StickerOutline: ViewModifier {
    var width: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    ForEach(0..<16, id: \.self) { step in
                        let angle = Double(step) * .pi / 8
                        content.offset(x: cos(angle) * width, y: sin(angle) * width)
                    }
                }
                .colorMultiply(.black)
                .colorInvert()
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.28), radius: 3, x: 0, y: 2.7)
    }
}

/// PNG data for share pictures, written without any metadata.
public enum SharePNG {
    /// `image` encoded as PNG, `nil` when it can't be encoded.
    public static func data(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}

/// A shop item's icon, drawn the way its character shows it.
public struct ShopItemIcon: View {
    let item: ShopItem

    public init(item: ShopItem) {
        self.item = item
    }

    public var body: some View {
        if let kuro = KuroItem(rawValue: item.id) {
            KuroItemIcon(item: kuro)
        } else {
            WardrobeItemIcon(item: item)
        }
    }
}

/// `persona` standing still in `mode`'s look, dressed for `card` in the identity card mode, wearing `wardrobe`.
public struct PersonaPortrait: View {
    let persona: Persona
    let mode: Mode
    let card: IdentityKind?
    let wardrobe: Wardrobe

    public init(persona: Persona, mode: Mode, card: IdentityKind? = nil, wardrobe: Wardrobe = Wardrobe()) {
        self.persona = persona
        self.mode = mode
        self.card = card
        self.wardrobe = wardrobe
    }

    public var body: some View {
        if persona == .kuro {
            KuroPortrait(look: KuroLook(mode: mode, card: card), wearing: wardrobe.worn(in: mode))
        } else {
            // C18 (动作展示总表): the shop, the wardrobe and the cards show the clothes, so no nap or handheld.
            CompanionPortrait(mode: mode, card: card, wardrobe: wardrobe, idles: false)
        }
    }
}
