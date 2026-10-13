import ActivityKit
import Foundation

// Shared by the app (which starts and ends it) and the widget extension (which draws it).
/// The Sunday boxing countdown on the Lock Screen and in the Dynamic Island.
struct BoxingActivityAttributes: ActivityAttributes {
    // Optional, so an activity started by an older build still decodes.
    /// The identity card's name; `nil` shows 拳击.
    var title: String?

    struct ContentState: Codable, Hashable {
        /// When boxing class starts.
        var start: Date
    }
}
