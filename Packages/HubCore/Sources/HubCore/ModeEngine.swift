import Foundation

/// The rules automatic mode changes follow. Times are minutes after local midnight.
public struct ModeRules: Codable, Equatable, Sendable {
    /// Work days as `Calendar` weekdays (1 is Sunday).
    public var workdays: Set<Int>
    public var workStartMinute: Int
    public var workEndMinute: Int
    /// How long after a manual change nothing automatic may switch, except the gym.
    public var manualHold: TimeInterval
    /// How long Mike must stay at the gym before leaving restores the earlier mode.
    public var gymMinimumStay: TimeInterval
    /// When the evening extension ends on work days, `nil` when it is off.
    public var eveningUntilMinute: Int?

    // Defaults from Issue #4, approved by Mike on 2026-10-03.
    /// Monday to Friday 9:30 to 18:30 is work, other times chill; 2 h hold; 30 min gym stay.
    public static let standard = ModeRules(
        workdays: [2, 3, 4, 5, 6],
        workStartMinute: 9 * 60 + 30,
        workEndMinute: 18 * 60 + 30,
        manualHold: 2 * 60 * 60,
        gymMinimumStay: 30 * 60
    )

    public init(
        workdays: Set<Int>,
        workStartMinute: Int,
        workEndMinute: Int,
        manualHold: TimeInterval,
        gymMinimumStay: TimeInterval,
        eveningUntilMinute: Int? = nil
    ) {
        self.workdays = workdays
        self.workStartMinute = workStartMinute
        self.workEndMinute = workEndMinute
        self.manualHold = manualHold
        self.gymMinimumStay = gymMinimumStay
        self.eveningUntilMinute = eveningUntilMinute
    }
}

extension ModeRules {
    /// Minutes before the end of work hours that the off-work notice goes out.
    public static let offWorkLead = 15

    // Mike, 2026-10-05: only when he is really at work, so a day off or working elsewhere gets no notice.
    /// When today's off-work notice goes out, or `nil` when it shouldn't: not a work day, already past,
    /// or Mike is neither in work mode nor at the office.
    public func offWorkNotice(
        on now: Date,
        mode: Mode?,
        atOffice: Bool,
        calendar: Calendar = .current
    ) -> Date? {
        guard workdays.contains(calendar.component(.weekday, from: now)), mode == .work || atOffice else { return nil }
        let minute = max(workEndMinute - Self.offWorkLead, 0)
        let midnight = calendar.startOfDay(for: now)
        guard let time = calendar.date(byAdding: .minute, value: minute, to: midnight), time > now else { return nil }
        return time
    }

    /// The end time a newly turned on evening extension starts with.
    public static let eveningDefaultMinute = 19 * 60

    // Issue #164: some work days go on into the evening. The off-work notice stays at the end of work hours.
    /// When today's evening extension ends, if `date` falls in it: a work day with the extension on, from
    /// the end of work hours to `eveningUntilMinute`. Else `nil`.
    public func eveningUntil(at date: Date, calendar: Calendar = .current) -> Date? {
        guard let until = eveningUntilMinute, isEvening(date, calendar: calendar) else { return nil }
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        guard (parts.hour ?? 0) * 60 + (parts.minute ?? 0) < until else { return nil }
        return calendar.date(byAdding: .minute, value: until, to: calendar.startOfDay(for: date))
    }

    /// Whether `date` is at or after the start of today's evening extension: a work day with the
    /// extension on, from the end of work hours.
    public func isEvening(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard eveningUntilMinute != nil, workdays.contains(calendar.component(.weekday, from: date)) else {
            return false
        }
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0) >= workEndMinute
    }

    static let defaultsKey = "modeRules"

    /// The rules saved in `defaults`, or `.standard` when none are saved or they can't be read.
    public static func stored(in defaults: UserDefaults) -> ModeRules {
        guard let data = defaults.data(forKey: defaultsKey) else { return .standard }
        return (try? JSONDecoder().decode(ModeRules.self, from: data)) ?? .standard
    }

    /// Saves the rules in `defaults`.
    public func store(in defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }
}

/// Something that may change the mode without Mike tapping.
public enum ModeTrigger: Equatable, Sendable {
    case enteredGym
    case leftGym
    case enteredOffice
    case leftOffice
    /// Arriving at the fitness gym, or a place that counts as one.
    case enteredFitness
    /// Arriving at a place Mike added that switches to `mode`.
    case enteredPlace(Mode, name: String)
    /// An iOS Focus with the 副业 filter turned on, for vibe coding.
    case codingFocus
    /// Leaving a place within `PlacePresence.bounce` of arriving at `arrivedAt`.
    case passedBy(arrivedAt: Date)
}

/// An automatic change the engine wants, with the reason to show Mike.
public struct ModeDecision: Equatable, Sendable {
    public var mode: Mode
    public var source: ModeChange.Source
    public var reason: String
    /// The 副业 state for `mode`, `nil` for none.
    public var tag: String?
}

// Modes change by place or by hand only; Mike turned off switching by the clock (PRD §16, 2026-10-05).
/// Rules for automatic mode changes. Manual changes always win, except arriving at the gym.
public enum ModeEngine {
    /// The mode the weekday schedule gives at `date`.
    public static func scheduledMode(at date: Date, rules: ModeRules, calendar: Calendar = .current) -> Mode {
        let weekday = calendar.component(.weekday, from: date)
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let inHours = minute >= rules.workStartMinute && minute < rules.workEndMinute
        return rules.workdays.contains(weekday) && inHours ? .work : .chill
    }

    /// What `trigger` should do to the mode in `log` at `now`.
    /// - Returns: the change to make, or `nil` to leave the mode alone.
    public static func decide(
        _ trigger: ModeTrigger,
        log: ModeLog,
        now: Date,
        rules: ModeRules = .standard,
        calendar: Calendar = .current
    ) -> ModeDecision? {
        let changes = log.active.filter { $0.at <= now }
        let current = changes.last
        switch trigger {
        case .enteredGym:
            guard current?.mode != .boxing else { return nil }
            return ModeDecision(mode: .boxing, source: .location, reason: "到拳馆了")

        case .leftGym:
            // Only undo our own switch: the gym entry must still be the latest change.
            guard let entry = current, isGymVisit(entry) else { return nil }
            guard now.timeIntervalSince(entry.at) >= rules.gymMinimumStay else { return nil }
            // A mode Mike picked comes back. An automatic one came from where he was before, so it's chill now.
            let previous = changes.dropLast().last
            let before = previous.map { $0.source.isManual ? $0.mode : .chill } ?? .chill
            guard before != .boxing else { return nil }
            return ModeDecision(mode: before, source: .location, reason: "离开拳馆，回到「\(before.title)」")

        case .enteredOffice:
            guard !isHeld(changes, now: now, rules: rules), current?.mode != .work else { return nil }
            return ModeDecision(mode: .work, source: .location, reason: "到公司了")

        case .leftOffice:
            guard !isHeld(changes, now: now, rules: rules), current?.mode == .work else { return nil }
            // Mike, 2026-10-05: stepping out for lunch isn't the end of work; only a leave from 17:30 is.
            let parts = calendar.dateComponents([.hour, .minute], from: now)
            guard (parts.hour ?? 0) * 60 + (parts.minute ?? 0) >= offWorkFromMinute else { return nil }
            return ModeDecision(mode: .chill, source: .location, reason: "离开公司了")

        case .enteredFitness:
            // PRD section 16, Mike 2026-10-05: lifting happens in Chill, so the gym ends Work or 副业.
            // Leaving the gym keeps the mode.
            let settled: [Mode?] = [.chill, .boxing]
            guard !isHeld(changes, now: now, rules: rules), !settled.contains(current?.mode) else { return nil }
            return ModeDecision(mode: .chill, source: .location, reason: "到健身房了")

        case .enteredPlace(let mode, let name):
            guard !isHeld(changes, now: now, rules: rules), current?.mode != mode else { return nil }
            return ModeDecision(mode: mode, source: .location, reason: "到\(name)了")

        case .codingFocus:
            guard !isHeld(changes, now: now, rules: rules), current?.sideHustle != .vibeCoding else { return nil }
            let tag = SideHustle.vibeCoding.rawValue
            return ModeDecision(mode: .money, source: .focus, reason: "编程专注模式开了", tag: tag)

        case .passedBy(let arrived):
            // Only undo a switch this visit made: it must still be the latest change.
            guard let entry = current, entry.source == .location, entry.at >= arrived else { return nil }
            guard now.timeIntervalSince(arrived) < PlacePresence.bounce else { return nil }
            let before = changes.dropLast().last
            let mode = before?.mode ?? .chill
            guard mode != entry.mode || before?.tag != entry.tag else { return nil }
            return ModeDecision(mode: mode, source: .location, reason: "只是路过", tag: before?.tag)
        }
    }

    /// Leaving the office ends work only from this minute after midnight.
    public static let offWorkFromMinute = 17 * 60 + 30

    // Mike, 2026-10-07: place comes first. A leave can be held by a manual change, come before 17:30, or be
    // reported before he really left, and then no second event comes. So the app checks again at every place
    // event and every open, not only at the moment of leaving.
    /// Ends work when, from 17:30 today, Mike left the office or came home and nothing changed the mode since.
    /// - Returns: the switch to chill, or `nil` to leave the mode alone.
    public static func settle(
        log: ModeLog,
        presence: PlacePresence,
        now: Date,
        calendar: Calendar = .current
    ) -> ModeDecision? {
        guard let current = log.active.last(where: { $0.at <= now }), current.mode == .work,
            presence.since(.office) == nil,
            let evening = calendar.date(
                bySettingHour: offWorkFromMinute / 60, minute: offWorkFromMinute % 60, second: 0, of: now
            )
        else { return nil }
        let moves = [(presence.left(.office), "离开公司了"), (presence.since(.home), "到家了")]
            .compactMap { at, reason in at.map { (at: $0, reason: reason) } }
            .filter { $0.at >= evening && $0.at <= now && $0.at > current.at }
        guard let move = moves.max(by: { $0.at < $1.at }) else { return nil }
        return ModeDecision(mode: .chill, source: .location, reason: move.reason)
    }

    private static func isGymVisit(_ change: ModeChange) -> Bool {
        change.mode == .boxing && change.source == .location
    }

    private static func isHeld(_ changes: [ModeChange], now: Date, rules: ModeRules) -> Bool {
        guard let manual = changes.last(where: { $0.source.isManual }) else { return false }
        return now.timeIntervalSince(manual.at) < rules.manualHold
    }
}
