import Foundation

// PRD section 19 (Mike, 2026-10-05): a nudge ignored three times in a row stops for a week, with one
// line. Nothing is made up afterwards. When the signals can't tell, the invite isn't judged at all.
/// Which invites Mike keeps ignoring, and which are paused because of it.
public struct NudgeBackoff: Codable, Equatable, Sendable {
    static let defaultsKey = "nudgeBackoff"
    /// How many ignored invites in a row pause that invite.
    public static let limit = 3
    /// How long a paused invite stays off.
    public static let pause: TimeInterval = 7 * 24 * 60 * 60
    /// What HAKU says on the day an invite is paused.
    public static let line = "行，我不念了。"

    /// Ignored invites in a row, by `CompanionNeed` raw value.
    public var ignored: [String: Int]
    /// When each paused invite was paused, by `CompanionNeed` raw value.
    public var pausedAt: [String: Date]
    /// When the last judged invite went out, so each invite is judged once.
    public var judgedSentAt: Date?

    public init(ignored: [String: Int] = [:], pausedAt: [String: Date] = [:], judgedSentAt: Date? = nil) {
        self.ignored = ignored
        self.pausedAt = pausedAt
        self.judgedSentAt = judgedSentAt
    }

    private enum CodingKeys: String, CodingKey { case ignored, pausedAt, judgedSentAt }

    /// Decodes the state; missing fields fall back to empty, so an active pause survives other builds.
    /// - Throws: `DecodingError` when a field has the wrong type.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        ignored = try values.decodeIfPresent([String: Int].self, forKey: .ignored) ?? [:]
        pausedAt = try values.decodeIfPresent([String: Date].self, forKey: .pausedAt) ?? [:]
        judgedSentAt = try values.decodeIfPresent(Date.self, forKey: .judgedSentAt)
    }

    /// Whether the invite for `need` is paused at `date`.
    public func isPaused(_ need: CompanionNeed, at date: Date) -> Bool {
        guard let at = pausedAt[need.rawValue] else { return false }
        return date >= at && date < at.addingTimeInterval(Self.pause)
    }

    /// HAKU's line on the hub day an invite was paused, else `nil`.
    public func notice(at date: Date, calendar: Calendar = .current) -> String? {
        let today = StateEngine.dayStart(for: date, calendar: calendar)
        let pausedToday = pausedAt.values.contains { StateEngine.dayStart(for: $0, calendar: calendar) == today }
        return pausedToday ? Self.line : nil
    }

    /// Records whether the invite for `need` sent at `sentAt` was followed. The third ignored one in a
    /// row pauses that invite from `now`; a followed one starts the count again.
    public mutating func record(_ need: CompanionNeed, followed: Bool, sentAt: Date, now: Date) {
        judgedSentAt = sentAt
        let key = need.rawValue
        guard !followed else {
            ignored[key] = 0
            return
        }
        let count = (ignored[key] ?? 0) + 1
        if count >= Self.limit {
            ignored[key] = 0
            pausedAt[key] = now
        } else {
            ignored[key] = count
        }
    }

    /// Whether Mike followed the invite for `need` sent at `sentAt`.
    /// - Parameters:
    ///   - signals: what the app knows now.
    ///   - departedAt: when Mike last tapped 走, `nil` if never.
    /// - Returns: `nil` while it's too early to tell, when the signals can't tell, or for invites
    ///   that aren't nudges.
    public static func followed(
        _ need: CompanionNeed,
        sentAt: Date,
        signals: NeedSignals,
        departedAt: Date?,
        now: Date
    ) -> Bool? {
        let end = sentAt.addingTimeInterval(need == .gymDay ? gymWindow : window)
        guard now >= end else { return nil }
        let inWindow = { (date: Date?) in date.map { $0 >= sentAt && $0 < end } ?? false }
        let moved = signals.workouts.contains { inWindow($0.start) } || inWindow(signals.fitnessSeenAt)
        if moved { return true }
        // Only the latest Screen Time report and stillness are kept, so later they describe another evening.
        let fresh = now < end.addingTimeInterval(freshFor)
        switch need {
        case .couchScroll:
            guard fresh else { return nil }
            // Still on the picked apps after the window, or hasn't walked since the invite: ignored.
            if let seen = signals.scrollSeenAt, seen >= end { return false }
            return signals.stillSince.map { $0 > sentAt }
        case .gymDay:
            return inWindow(departedAt)
        case .slacking:
            // Reports come every 10 minutes of use, so none after the window means Mike stopped.
            guard fresh, let seen = signals.slackSeenAt ?? signals.slackThresholdAt else { return nil }
            return seen < end
        case .sitting:
            // Stand hours come late; stood in or after the hour of the invite, or still the same stiff stretch.
            guard let sit = signals.sit else { return nil }
            if let stood = sit.stoodAt, stood.addingTimeInterval(60 * 60) > sentAt { return true }
            guard let stiff = sit.stiffSince, stiff <= sentAt, sit.checkedAt >= end.addingTimeInterval(60 * 60) else {
                return nil
            }
            return false
        case .boxingWarmup:
            return nil
        }
    }

    /// How long after an invite Mike has to act on it.
    static let window: TimeInterval = 30 * 60
    /// How long after the gym-day invite Mike has to set off.
    static let gymWindow: TimeInterval = 90 * 60
    /// How long after the window Screen Time and stillness still say something about the invite.
    static let freshFor: TimeInterval = 3 * 60 * 60

    /// The state saved in `defaults`, or an empty one when nothing is saved or it can't be read.
    public static func stored(in defaults: UserDefaults) -> NudgeBackoff {
        guard let data = defaults.data(forKey: defaultsKey) else { return NudgeBackoff() }
        return (try? JSONDecoder().decode(NudgeBackoff.self, from: data)) ?? NudgeBackoff()
    }

    /// Saves the state in `defaults`.
    public func store(in defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }
}
