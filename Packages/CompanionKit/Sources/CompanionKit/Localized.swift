import Foundation
import HubCore

// Issue #350, as in HubCore: each key is the Chinese text itself, and a key with no translation comes back
// unchanged. Bubble lines live in one table per character (Haku, Kuro). Until `Languages` is on, every line
// stays Chinese.
extension String {
    /// This line in the user's language, from `persona`'s table in CompanionKit.
    func localized(for persona: Persona) -> String {
        guard Languages.isOn else { return self }
        return String(localized: LocalizationValue(self), table: persona == .kuro ? "Kuro" : "Haku", bundle: .module)
    }
}
