import Foundation

// Issue #164. The persona changes only the look, the lines and the names of three modes. Mode values,
// stored records and every rule stay the same, so switching needs no migration.
/// Which preset character the app draws.
public enum Persona: String, Codable, CaseIterable, Sendable {
    case haku
    /// The second preset character, KURO: cat-eared, whose identity activity is tennis.
    case kuro

    static let defaultsKey = "persona"

    /// The name the Settings picker shows.
    public var title: String {
        switch self {
        case .haku: "HAKU"
        case .kuro: "KURO"
        }
    }

    /// The persona saved in `defaults`, or `.haku` when none is saved or it can't be read.
    public static func stored(in defaults: UserDefaults) -> Persona {
        defaults.string(forKey: defaultsKey).flatMap(Persona.init(rawValue:)) ?? .haku
    }

    /// Saves the persona in `defaults`.
    public func store(in defaults: UserDefaults) {
        defaults.set(rawValue, forKey: Self.defaultsKey)
    }
}

extension Mode {
    /// The mode's name for `persona`: KURO has her own names for the chill, identity and side slots.
    public func title(for persona: Persona) -> String {
        switch (persona, self) {
        // UI-32 (PM 2026-10-08): KURO's chill is plain 下班; work keeps HAKU's name.
        case (.kuro, .chill): "下班"
        case (.kuro, .boxing): "网球日"
        default: title
        }
    }

    /// The mode's short English code for `persona`: KURO's identity slot is TENNIS.
    public func code(for persona: Persona) -> String {
        switch (persona, self) {
        case (.kuro, .boxing): "TENNIS"
        default: code
        }
    }

    /// The line under the home card for `persona`.
    public func tagline(for persona: Persona) -> String {
        switch (persona, self) {
        case (.haku, _): tagline
        case (.kuro, .work): "……开始了"
        case (.kuro, .chill): "热饮，窝着"
        case (.kuro, .boxing): "拍线刚调过"
        case (.kuro, .money): "一件一件来"
        }
    }
}

extension HubPlace.Kind {
    /// The place's name for `persona`: KURO's identity place is a tennis court.
    public func title(for persona: Persona) -> String {
        switch (persona, self) {
        case (.kuro, .gym): "网球场"
        default: title
        }
    }
}

extension HubPlace.Kind {
    /// The presets Settings lists with `cards`: the identity card's place only when a card is picked.
    public static func presets(with cards: ModeCards) -> [HubPlace.Kind] {
        cards.identityName == nil ? presets.filter { $0 != .gym } : presets
    }

    /// The preset's name for `persona` with `cards`: a picked identity card's place is named after the card.
    public func title(for persona: Persona, cards: ModeCards) -> String {
        guard self == .gym, cards.pickedIdentity(for: .boxing, persona: persona) != nil else {
            return title(for: persona)
        }
        return "\(cards.title(for: .boxing, persona: persona))的地方"
    }
}

extension HubPlace.Action {
    /// The actions Settings offers with `cards`: the identity card's only when a card is picked.
    public static func offered(with cards: ModeCards) -> [HubPlace.Action] {
        cards.identityName == nil ? allCases.filter { $0 != .boxing } : allCases
    }

    /// What the action is called for `persona` with `cards`, naming the user's cards.
    public func title(for persona: Persona, cards: ModeCards) -> String {
        switch self {
        case .work: "切到\(cards.title(for: .work, persona: persona))"
        case .chill: "切到\(cards.title(for: .chill, persona: persona))"
        case .sideHustle: "切到\(cards.title(for: .money, persona: persona))"
        case .boxing: "当\(HubPlace.Kind.gym.title(for: persona, cards: cards))"
        case .recordOnly, .fitness: title(for: persona)
        }
    }

    /// What the action is called for `persona`.
    public func title(for persona: Persona) -> String {
        switch (persona, self) {
        case (.kuro, .boxing): "当网球场"
        default: title
        }
    }
}
