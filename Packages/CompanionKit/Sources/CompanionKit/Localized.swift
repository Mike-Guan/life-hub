import Foundation
import HubCore

// Issue #350, as in HubCore: each key is the Chinese text itself, and a key with no translation comes back
// unchanged. Bubble lines live in one table per character (Haku, Kuro). In Chinese, every line stays as
// it is.
extension String {
    /// This text in the user's language, from CompanionKit's `Localizable` table.
    var localized: String {
        guard Languages.isOn else { return self }
        return String(localized: LocalizationValue(self), table: "Localizable", bundle: Languages.bundle(.module))
    }

    /// This line in the user's language, from `persona`'s table in CompanionKit.
    func localized(for persona: Persona) -> String {
        guard Languages.isOn else { return self }
        let table = persona == .kuro ? "Kuro" : "Haku"
        return String(localized: LocalizationValue(self), table: table, bundle: Languages.bundle(.module))
    }
}
