import Foundation

/// When invites went out and when the next one is scheduled, so there is at most one a day.
public struct InviteLog: Codable, Equatable, Sendable {
    static let defaultsKey = "inviteLog"

    /// When the last invite went out, `nil` if never.
    public var lastSentAt: Date?
    /// When the scheduled invite goes out, `nil` when none is scheduled.
    public var pendingAt: Date?
    /// The need the last invite was for, `nil` if unknown.
    public var lastNeed: CompanionNeed?
    /// The need the scheduled invite is for.
    public var pendingNeed: CompanionNeed?

    public init(
        lastSentAt: Date? = nil,
        pendingAt: Date? = nil,
        lastNeed: CompanionNeed? = nil,
        pendingNeed: CompanionNeed? = nil
    ) {
        self.lastSentAt = lastSentAt
        self.pendingAt = pendingAt
        self.lastNeed = lastNeed
        self.pendingNeed = pendingNeed
    }

    // A local notification can't report that it was shown, so one whose time has passed counts as sent.
    /// This log with a scheduled invite whose time has passed counted as sent.
    public func settled(now: Date) -> InviteLog {
        guard let pendingAt, pendingAt <= now else { return self }
        return InviteLog(lastSentAt: pendingAt, lastNeed: pendingNeed)
    }

    /// The log saved in `defaults`, or an empty one when nothing is saved or it can't be read.
    public static func stored(in defaults: UserDefaults) -> InviteLog {
        guard let data = defaults.data(forKey: defaultsKey) else { return InviteLog() }
        return (try? JSONDecoder().decode(InviteLog.self, from: data)) ?? InviteLog()
    }

    /// Saves the log in `defaults`.
    public func store(in defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }
}
