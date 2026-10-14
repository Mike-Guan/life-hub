import Foundation

// Issue #350. Chinese is the source language: each key is the Chinese text itself, and the String Catalogs
// hold the Japanese and English. A key with no translation comes back unchanged, so Chinese never changes.
// Lines live in one table per character (Haku, Kuro), so the same Chinese can read differently in each voice;
// everything else is in Localizable.
extension String {
    /// This text in the user's language, from HubCore's `Localizable` table.
    var localized: String {
        String(localized: LocalizationValue(self), table: "Localizable", bundle: .module)
    }

    /// This line in the user's language, from `persona`'s table in HubCore.
    func localized(for persona: Persona) -> String {
        String(localized: LocalizationValue(self), table: persona == .kuro ? "Kuro" : "Haku", bundle: .module)
    }
}
