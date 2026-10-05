import Foundation

// PRD v1: opening the app replays what HAKU did while Mike was away. Mode switches and the off-work
// notice mostly happen with the app closed, so their animations never played (Mike, 2026-10-05).
/// Which missed animation to play when the app opens.
public enum OpenReplay {
    /// How old a missed animation may be and still play; older ones would no longer fit the moment.
    public static let window: TimeInterval = 3 * 60 * 60

    /// The mode to show briefly before the current one, so the switch animation plays.
    /// - Parameters:
    ///   - log: the mode log.
    ///   - lastSeen: when the app last went to the background, `nil` if unknown.
    ///   - now: the time the app opens.
    /// - Returns: the mode before the latest automatic switch made while the app was closed and within
    ///   `window`, or `nil`.
    public static func switchFrom(log: ModeLog, lastSeen: Date?, now: Date) -> Mode? {
        guard let lastSeen else { return nil }
        return log.switchedFrom(since: max(lastSeen, now.addingTimeInterval(-window)))
    }

    /// Whether to play the off-work animation for a notice Mike didn't tap.
    /// - Parameters:
    ///   - deliveredAt: when the off-work notice was shown, `nil` if it is not in Notification Center.
    ///   - mode: the current mode; back in work mode the animation doesn't fit.
    ///   - now: the time the app opens.
    public static func offWork(deliveredAt: Date?, mode: Mode?, now: Date) -> Bool {
        guard let deliveredAt, mode != .work else { return false }
        let age = now.timeIntervalSince(deliveredAt)
        return age >= 0 && age < window
    }
}
