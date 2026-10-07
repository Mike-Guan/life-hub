import Foundation

/// What the home card acts out at one time besides the mode, energy and need.
public struct HomeScene: Codable, Equatable, Sendable {
    public var activity: CompanionActivity?
    public var moment: CompanionMoment?
    /// The place Mike just left, while HAKU walks from it.
    public var walking: HubPlace.Kind?
    public var bath: Bool
    /// Cans HAKU has coded up in vibe coding.
    public var codingCans: Int

    public init(
        activity: CompanionActivity? = nil,
        moment: CompanionMoment? = nil,
        walking: HubPlace.Kind? = nil,
        bath: Bool = false,
        codingCans: Int = 0
    ) {
        self.activity = activity
        self.moment = moment
        self.walking = walking
        self.bath = bath
        self.codingCans = codingCans
    }

    private enum CodingKeys: String, CodingKey { case activity, moment, walking, bath, codingCans }

    /// Decodes a scene; a missing or unknown value falls back to nothing going on.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        activity = try? values.decodeIfPresent(CompanionActivity.self, forKey: .activity)
        moment = try? values.decodeIfPresent(CompanionMoment.self, forKey: .moment)
        walking = try? values.decodeIfPresent(HubPlace.Kind.self, forKey: .walking)
        bath = (try? values.decodeIfPresent(Bool.self, forKey: .bath)) ?? false
        codingCans = (try? values.decodeIfPresent(Int.self, forKey: .codingCans)) ?? 0
    }
}

/// A scene and when it starts.
public struct TimedScene: Codable, Equatable, Sendable {
    public var from: Date
    public var scene: HomeScene

    public init(from: Date, scene: HomeScene) {
        self.from = from
        self.scene = scene
    }
}

/// Everything the home card reads to work out its scene; the iPhone home and the watch share it.
public struct HomeSceneInputs {
    public var log: ModeLog
    public var rules: ModeRules
    public var bedtime: BedtimeSchedule
    public var need: NeedReading?
    public var signals: ActivitySignals?
    public var days: ActivityDays
    public var departure: GymDeparture?
    public var sit: SitState?
    public var bathDoneAt: Date?

    public init(
        log: ModeLog,
        rules: ModeRules = .standard,
        bedtime: BedtimeSchedule = .standard,
        need: NeedReading? = nil,
        signals: ActivitySignals? = nil,
        days: ActivityDays = .standard,
        departure: GymDeparture? = nil,
        sit: SitState? = nil,
        bathDoneAt: Date? = nil
    ) {
        self.log = log
        self.rules = rules
        self.bedtime = bedtime
        self.need = need
        self.signals = signals
        self.days = days
        self.departure = departure
        self.sit = sit
        self.bathDoneAt = bathDoneAt
    }

    private var mode: Mode? { log.current?.mode }
    private var atHome: Bool { signals?.presence.since(.home) != nil }

    /// The need while it lasts at `date`; the tracker refreshes only on open and on place events.
    public func activeNeed(at date: Date) -> NeedReading? {
        need.flatMap { $0.isActive(at: date) ? $0 : nil }
    }

    /// What HAKU does alongside Mike at `date`, before the gym-day door rule.
    public func activity(at date: Date) -> CompanionActivity? {
        signals.flatMap {
            ActivityEngine.activity($0, mode: mode, days: days, work: rules, bedtime: bedtime, now: date)
        }
    }

    /// Where Mike is at home, `nil` when he isn't.
    public func home(at date: Date) -> HomeSignals? {
        signals?.presence.since(.home).map {
            HomeSignals(
                since: $0,
                workedToday: MomentEngine.workedToday(log, now: date),
                manualAt: log.active.last(where: \.source.isManual)?.at
            )
        }
    }

    /// The moment HAKU plays at `date`.
    public func moment(at date: Date) -> CompanionMoment? {
        let presence = signals?.presence
        return MomentEngine.moment(
            mode: mode,
            sideHustle: log.current?.sideHustle,
            activity: activity(at: date),
            need: activeNeed(at: date)?.need,
            departing: presence.map { departure?.isActive(at: date, presence: $0) ?? false } ?? false,
            officeSince: presence?.since(.office),
            home: home(at: date),
            stiff: sit?.isStiff(mode: mode, at: date) ?? false,
            now: date,
            work: rules
        )
    }

    // On gym days HAKU waits at the door during the invite and walks after 走, instead of the plain bag.
    /// The activity the card shows at `date`.
    public func shownActivity(at date: Date) -> CompanionActivity? {
        let activity = activity(at: date)
        return activity == .gymDay && moment(at: date) != nil ? nil : activity
    }

    /// The place Mike just left at `date`, while HAKU walks from it.
    public func walking(at date: Date) -> HubPlace.Kind? {
        signals.flatMap { PlaceWalk.walk(in: $0.presence, now: date)?.from }
    }

    /// Whether HAKU takes its bath at `date`.
    public func bath(at date: Date) -> Bool {
        BathTime.isOn(at: date, bedtime: bedtime, mode: mode, atHome: atHome, doneAt: bathDoneAt)
    }

    /// Cans HAKU has coded up at `date` in vibe coding.
    public func codingCans(at date: Date) -> Int {
        guard log.current?.sideHustle == .vibeCoding, let since = log.current?.at else { return 0 }
        return SideHustle.codingCans(since: since, now: date)
    }

    /// The scene at `date`.
    public func scene(at date: Date) -> HomeScene {
        HomeScene(
            activity: shownActivity(at: date),
            moment: moment(at: date),
            walking: walking(at: date),
            bath: bath(at: date),
            codingCans: codingCans(at: date)
        )
    }

    /// The scenes from `now` for `hours`, checked every `step`, each kept only where it changes.
    public func timeline(from now: Date, hours: Double = 3, step: TimeInterval = 5 * 60) -> [TimedScene] {
        var scenes: [TimedScene] = []
        var date = now
        while date <= now.addingTimeInterval(hours * 60 * 60) {
            let scene = scene(at: date)
            if scenes.last?.scene != scene { scenes.append(TimedScene(from: date, scene: scene)) }
            date = date.addingTimeInterval(step)
        }
        return scenes
    }
}

extension Array where Element == TimedScene {
    /// The scene at `date`: the last one started by then, or nothing before the first.
    public func scene(at date: Date) -> HomeScene? {
        last { $0.from <= date }?.scene
    }
}
