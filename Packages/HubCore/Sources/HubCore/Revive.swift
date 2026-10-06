import Foundation

// PRD section 16 addendum (Mike approved 2026-10-06): when Mike leaves couch scrolling for the bath or
// vibe coding, HAKU gets up from the sofa once a day. Couch scrolling here is the couch need itself, which
// starts after 30 minutes of Screen Time on the chosen apps, so a short look at the phone doesn't count.
/// When HAKU gets up from the sofa. T0, no models.
public enum ReviveEngine {
    /// How long after the switch HAKU still gets up when the app opens.
    public static let lasts: TimeInterval = 30 * 60

    /// When Mike started the bath or vibe coding, the later of the two, or `nil` for neither.
    /// - Parameters:
    ///   - change: the current mode change; counts when it is 副业 with vibe coding.
    ///   - bath: the bath window, when HAKU is taking its bath now.
    public static func switchedAt(change: ModeChange?, bath: DateInterval?) -> Date? {
        let coding = change.flatMap { $0.mode == .money && SideHustle(tag: $0.tag) == .vibeCoding ? $0.at : nil }
        return [coding, bath?.start].compactMap { $0 }.max()
    }

    /// HAKU getting up from the sofa at `now`, or `nil`. The id is the hub day, so it plays once a day.
    /// - Parameters:
    ///   - switchedAt: when Mike started the bath or vibe coding.
    ///   - scrollSeenAt: the last Screen Time report of couch scrolling, `nil` when there was none.
    ///   - atHome: whether Mike is at home.
    public static func revived(
        switchedAt: Date?,
        scrollSeenAt: Date?,
        atHome: Bool,
        now: Date,
        rules: NeedRules = .standard,
        calendar: Calendar = .current
    ) -> CompanionEvent? {
        guard atHome, let switchedAt, let seen = scrollSeenAt else { return nil }
        // Couch scrolling lasts `scrollQuiet` after the last report, so the switch must land inside it.
        guard seen <= switchedAt, switchedAt.timeIntervalSince(seen) < rules.scrollQuiet else { return nil }
        guard switchedAt <= now, now < switchedAt.addingTimeInterval(lasts) else { return nil }
        return .revived(id: StateEngine.dayStart(for: switchedAt, calendar: calendar).ISO8601Format())
    }
}
