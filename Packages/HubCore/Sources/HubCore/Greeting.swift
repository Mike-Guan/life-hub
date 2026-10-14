import Foundation

// PM 2026-10-13 (工程 #17): the friends' build asks no name, so the greeting has none. Installs from
// before keep the name they saw, saved on the device and never in the repo's defaults.
/// The home screen's greeting and the name in it.
public enum Greeting {
    static let nameKey = "greetingName"
    static let adoptedKey = "greetingNameAdopted"
    static let legacyName = "MIKE"

    /// The greeting for `hour` (0-23), ending with `name` when there is one.
    public static func text(hour: Int, name: String?) -> String {
        let greeting: String
        switch hour {
        case 5..<12: greeting = "GOOD MORNING"
        case 12..<18: greeting = "GOOD AFTERNOON"
        default: greeting = "GOOD EVENING"
        }
        guard let name, !name.isEmpty else { return greeting }
        return "\(greeting), \(name)"
    }

    /// The name saved in `defaults`, `nil` when there is none.
    public static func name(in defaults: UserDefaults) -> String? {
        defaults.string(forKey: nameKey)
    }

    // Only HAKU's greeting showed the name; the second preset character's install never did.
    /// On the first launch of this build, saves the name the greeting used to show for an install that
    /// already has records with `persona`. Later launches change nothing.
    public static func adopt(in defaults: UserDefaults, persona: Persona, existingInstall: Bool) {
        guard !defaults.bool(forKey: adoptedKey) else { return }
        defaults.set(true, forKey: adoptedKey)
        if existingInstall, persona == .haku { defaults.set(legacyName, forKey: nameKey) }
    }
}
