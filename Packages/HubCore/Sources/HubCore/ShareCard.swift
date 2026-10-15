import Foundation

// Issue #352 PR B, 人生收藏 分享卡 方案 v1. A share card is the one picture meant to leave the device, so it holds
// only what the card shows: the character, her look and the item. No date, place, health number, can count or
// schedule fits in it; ShareCardTests checks every stored property.

/// What one share card shows.
public struct ShareCard: Equatable, Sendable {
    /// What the card is about.
    public enum Subject: Equatable, Sendable {
        /// A keepsake, by item id.
        case keepsake(String)
        /// A top or full set, by item id.
        case outfit(String)
    }

    /// The picture's proportions.
    public enum Shape: String, CaseIterable, Sendable {
        /// 9:16, for stories.
        case story
        /// 1:1, for posts.
        case square

        /// The card's size in points. Rendered at scale 3, that is 1080 × 1920 or 1080 × 1080 pixels.
        public var size: CGSize {
            switch self {
            case .story: CGSize(width: 360, height: 640)
            case .square: CGSize(width: 360, height: 360)
            }
        }
    }

    /// The text on a card.
    public struct Words: Equatable, Sendable {
        /// The character's name.
        public var name: String
        /// The small line above the title, `nil` for none.
        public var eyebrow: String?
        /// The item's name.
        public var title: String
        /// The count line under the title, `nil` for none.
        public var subtitle: String?
        /// The character's line in the bubble.
        public var line: String

        public init(name: String, eyebrow: String? = nil, title: String, subtitle: String? = nil, line: String) {
            self.name = name
            self.eyebrow = eyebrow
            self.title = title
            self.subtitle = subtitle
            self.line = line
        }
    }

    public var persona: Persona
    /// How the character looks on the card: the snapshot from the day the item arrived, else her look now.
    public var look: Look
    public var subject: Subject

    public init(persona: Persona, look: Look, subject: Subject) {
        self.persona = persona
        self.look = look
        self.subject = subject
    }

    // 分享卡方案 v1 §2: a card for a keepsake, or for a top or full set put on. Other bought items get none.
    /// A card for `item`, `nil` when the item gets no card.
    public init?(persona: Persona, look: Look, item: ShopItem) {
        if item.keepsake != nil {
            self.init(persona: persona, look: look, subject: .keepsake(item.id))
        } else if item.slot == .top || item.slot == .fullSet {
            self.init(persona: persona, look: look, subject: .outfit(item.id))
        } else {
            return nil
        }
    }

    /// The item the card is about.
    public var item: ShopItem? {
        switch subject {
        case .keepsake(let id), .outfit(let id): ShopItem.item(id)
        }
    }

    // 分享卡方案 v1 附表 (PM 2026-10-13); HAKU's keepsake line from the PM line scan of 10-15. Lines speak about
    // the character only and carry no number.
    /// The character's line for this card, in the user's language.
    public var line: String {
        switch (subject, persona) {
        case (.keepsake, .haku): "……给你的。顺手。".localized(for: persona)
        case (.keepsake, .kuro): "……这个，留着。".localized(for: persona)
        case (.outfit, .haku): "……别盯着看。".localized(for: persona)
        case (.outfit, .kuro): "……换好了。".localized(for: persona)
        }
    }

    // Only the cumulative count the keepsake was earned at: never a streak, a day count or a date.
    /// The card's text in the user's language.
    /// - Parameter counted: what the keepsake counts, such as the identity card's name.
    public func words(counting counted: String) -> Words {
        let title = item?.title ?? ""
        switch subject {
        case .keepsake:
            let subtitle = item?.keepsake.map { String(format: "第 %lld 次%@".localized, $0.count, counted) }
            return Words(name: persona.title, title: title, subtitle: subtitle, line: line)
        case .outfit:
            return Words(name: persona.title, eyebrow: "换上了".localized, title: title, line: line)
        }
    }

    /// The look with the card's item worn, so a card about an item shows the character wearing it.
    public var wornLook: Look {
        guard let item else { return look }
        var worn = look
        worn.wardrobe.equip(item)
        return worn
    }
}
