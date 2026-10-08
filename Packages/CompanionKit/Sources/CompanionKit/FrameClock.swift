import SwiftUI

extension EnvironmentValues {
    /// The time the companion views draw instead of the live clock, or nil for the live clock.
    // Frame sheets for the UI review set this so each frame is the real drawing code at a known time.
    @Entry var frameClock: Date?
    /// Whether the companion views draw as with Reduce Motion on, or nil to follow the system setting.
    // The system value is read-only, so frame sheets set this to draw the reduced-motion frame.
    @Entry var frameReduceMotion: Bool?
}
