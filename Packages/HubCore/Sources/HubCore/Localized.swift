import Foundation

// Issue #350. Chinese is the source language: each key is the Chinese text itself, and the String Catalogs
// hold the Japanese and English. A key with no translation comes back unchanged, so Chinese never changes.
// Lines live in one table per character (Haku, Kuro), so the same Chinese can read differently in each voice;
// everything else is in Localizable.
extension String {
    /// This text in the user's language, from HubCore's `Localizable` table.
    var localized: String {
        guard Languages.isOn else { return self }
        return String(localized: LocalizationValue(self), table: "Localizable", bundle: Languages.bundle(.module))
    }

    /// This line in the user's language, from `persona`'s table in HubCore.
    func localized(for persona: Persona) -> String {
        guard Languages.isOn else { return self }
        let table = persona == .kuro ? "Kuro" : "Haku"
        return String(localized: LocalizationValue(self), table: table, bundle: Languages.bundle(.module))
    }
}
