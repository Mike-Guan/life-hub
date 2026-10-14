import Foundation

// Issue #350. Chinese is the source language: each key is the Chinese text itself, and Localizable.xcstrings
// holds the Japanese and English. A key with no translation comes back unchanged, so Chinese never changes.
// `scripts/strings.py` collects the keys from `"…".localized` in the source into the catalog.
extension String {
    /// This text in the user's language, from HubCore's String Catalog.
    var localized: String {
        String(localized: LocalizationValue(self), bundle: .module)
    }
}
