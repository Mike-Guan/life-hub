import Foundation

// Issue #164. The persona changes only the look, the lines and the names of two modes. Mode values,
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
    /// The mode's name for `persona`: KURO has her own names for the identity and side slots.
    public func title(for persona: Persona) -> String {
        switch (persona, self) {
        case (.kuro, .boxing): "网球日"
        case (.kuro, .money): "备课"
        default: title
        }
    }

    /// The line under the home card for `persona`.
    public func tagline(for persona: Persona) -> String {
        switch (persona, self) {
        case (.haku, _): tagline
        case (.kuro, .work): "面罩戴好，平板在手"
        case (.kuro, .chill): "面罩摘下，热饮捧着"
        case (.kuro, .boxing): "头带扎好，拍子拎上"
        case (.kuro, .money): "眼镜戴上，红笔就位"
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

extension HubPlace.Action {
    /// What the action is called for `persona`.
    public func title(for persona: Persona) -> String {
        switch (persona, self) {
        case (.kuro, .boxing): "当网球场"
        default: title
        }
    }
}
