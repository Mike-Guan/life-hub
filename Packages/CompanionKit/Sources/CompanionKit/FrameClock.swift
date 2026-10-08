import SwiftUI

extension EnvironmentValues {
    /// The time the companion views draw instead of the live clock, or nil for the live clock.
    // Frame sheets for the UI review set this so each frame is the real drawing code at a known time.
    @Entry var frameClock: Date?
}
