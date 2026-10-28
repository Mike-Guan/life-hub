import Foundation
import HubCore

extension String {
    /// This text in the user's language, from the app's `Localizable` table.
    var localized: String {
        guard Languages.isOn else { return self }
        return String(localized: LocalizationValue(self), table: "Localizable", bundle: Languages.bundle(.main))
    }
}
