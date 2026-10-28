import ActivityKit
import Foundation
import HubCore

// Shared by the app (which starts and ends it) and the widget extension (which draws it).
/// The Sunday boxing countdown on the Lock Screen and in the Dynamic Island.
struct BoxingActivityAttributes: ActivityAttributes {
    // Optional, so an activity started by an older build still decodes.
    /// The identity card's name; `nil` shows 拳击.
    var title: String?
    /// The character shown; `nil` (an older build) shows HAKU.
    var persona: Persona?
    /// The identity card worn when it differs from the character's default one.
    var card: IdentityKind?

    struct ContentState: Codable, Hashable {
        /// When boxing class starts.
        var start: Date
    }
}
