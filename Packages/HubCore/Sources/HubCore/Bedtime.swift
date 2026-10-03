import Foundation

// An overlay on the current mode, not a fifth mode (see CLAUDE.md, "Core model rules").
/// Whether the bedtime window is on.
public enum Bedtime: String, Codable, Sendable {
    case off
    case on
}
