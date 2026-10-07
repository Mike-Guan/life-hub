import Foundation

// Issue #91 and PRD §19: did Life Hub ever change what Mike did? The app notes it by itself, with no logging.
/// A time Mike acted on something HAKU did.
public struct ChangeMoment: Codable, Identifiable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public enum Kind: String, Codable, Sendable {
        /// Got moving within the window after the couch or gym-day invite.
        case gotUp
        /// Reached the fitness gym after tapping 走, before the walk ran out.
        case wentAfterGo
        /// Earned the last win for a keepsake within 24 hours of being one win away.
        case nearUnlock
    }

    public var schemaVersion: Int
    /// The kind and source, so each moment is noted once.
    public var id: String
    public var kind: Kind
    public var at: Date
    public var createdAt: Date
    public var updatedAt: Date
    public var updatedBy: String
    public var deletedAt: Date?

    /// - Parameters:
    ///   - source: what the moment came from, such as the invite's send time; the same source gives the same id.
    public init(kind: Kind, source: String, at: Date, deviceID: String) {
        self.schemaVersion = Self.currentSchemaVersion
        self.id = "\(kind.rawValue):\(source)"
        self.kind = kind
        self.at = at
        self.createdAt = at
        self.updatedAt = at
        self.updatedBy = deviceID
        self.deletedAt = nil
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, kind, at, createdAt, updatedAt, updatedBy, deletedAt
    }

    /// Decodes a moment; fields missing in older data get defaults.
    /// - Throws: `DecodingError` when `id`, `kind` or `at` is missing or has the wrong type.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        kind = try values.decode(Kind.self, forKey: .kind)
        at = try values.decode(Date.self, forKey: .at)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        createdAt = try values.decodeIfPresent(Date.self, forKey: .createdAt) ?? at
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        updatedBy = try values.decodeIfPresent(String.self, forKey: .updatedBy) ?? "unknown"
        deletedAt = try values.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

// The app and its extensions both note moments, so the log lives in the App Group's defaults.
/// The change moments noted so far, append-only.
public struct ChangeLog: Codable, Equatable, Sendable {
    static let defaultsKey = "changeMoments"

    public var moments: [ChangeMoment]

    public init(moments: [ChangeMoment] = []) {
        self.moments = moments
    }

    /// Adds `moment` unless one with its id is already there.
    /// - Returns: `true` when it was added.
    @discardableResult
    public mutating func record(_ moment: ChangeMoment) -> Bool {
        guard !moments.contains(where: { $0.id == moment.id }) else { return false }
        moments.append(moment)
        return true
    }

    /// The log saved in `defaults`, or an empty one when nothing is saved or it can't be read.
    public static func stored(in defaults: UserDefaults) -> ChangeLog {
        guard let data = defaults.data(forKey: defaultsKey) else { return ChangeLog() }
        return (try? HubJSON.decoder().decode(ChangeLog.self, from: data)) ?? ChangeLog()
    }

    /// Saves the log in `defaults`.
    public func store(in defaults: UserDefaults) {
        defaults.set(try? HubJSON.encoder().encode(self), forKey: Self.defaultsKey)
    }

    /// Notes `moment` in the log saved in `defaults`, once.
    public static func note(_ moment: ChangeMoment, in defaults: UserDefaults) {
        var log = stored(in: defaults)
        if log.record(moment) { log.store(in: defaults) }
    }
}

/// Rules that find change moments and the Sunday line about them. T0, no models.
public enum ChangeEngine {
    /// How soon after being one win away the last win must come for a near-unlock moment.
    public static let unlockWindow: TimeInterval = 24 * 60 * 60

    /// The moment for a judged invite, `nil` unless Mike followed the couch or gym-day invite.
    public static func gotUp(_ need: CompanionNeed, followed: Bool, sentAt: Date, deviceID: String) -> ChangeMoment? {
        guard followed, need == .couchScroll || need == .gymDay else { return nil }
        return ChangeMoment(kind: .gotUp, source: source(sentAt), at: sentAt, deviceID: deviceID)
    }

    /// The moment for arriving at the fitness gym at `arrivedAt`, `nil` unless a 走 walk was still on.
    public static func wentAfterGo(departure: GymDeparture?, arrivedAt: Date, deviceID: String) -> ChangeMoment? {
        guard let departure, arrivedAt >= departure.at, arrivedAt < departure.until else { return nil }
        return ChangeMoment(kind: .wentAfterGo, source: source(departure.at), at: arrivedAt, deviceID: deviceID)
    }

    // Derived from the ledger each time, so nothing extra is stored and older grants count too.
    /// When Mike earned a keepsake's last win within `unlockWindow` of the win before it.
    public static func nearUnlocks(in ledger: CanLedger) -> [Date] {
        let granted = Set(ledger.active.filter { $0.kind == .granted }.compactMap(\.itemID))
        // KURO's keepsakes share HAKU's milestones, so counting HAKU's alone keeps each unlock once.
        return ShopItem.catalog(for: .haku).compactMap { item -> Date? in
            guard granted.contains(item.id), let keepsake = item.keepsake, keepsake.count >= 2 else { return nil }
            let wins = ledger.active.filter { $0.kind == .earned && $0.win == keepsake.win }.map(\.at).sorted()
            guard wins.count >= keepsake.count else { return nil }
            let last = wins[keepsake.count - 1]
            return last.timeIntervalSince(wins[keepsake.count - 2]) <= unlockWindow ? last : nil
        }
    }

    /// HAKU's line about this week's moments, only on Sunday and only when there are some.
    /// - Parameter times: when each moment happened.
    public static func sundayLine(times: [Date], now: Date, calendar: Calendar = .current) -> String? {
        let today = StateEngine.dayStart(for: now, calendar: calendar)
        guard calendar.component(.weekday, from: today) == 1,
            let weekStart = calendar.date(byAdding: .day, value: -6, to: today)
        else { return nil }
        let count = times.filter { $0 >= weekStart && $0 <= now }.count
        switch count {
        case 0: return nil
        case 1: return "这周有一次，你真的起来了。我记着。"
        case 2: return "这周你被我叫起来两次。还行。"
        default: return "这周你起来了 \(count) 次。……我可没在数。"
        }
    }

    // A followed gym-day invite and the walk after 走 are one evening, so the Sunday count is per day.
    /// The first moment of each hub day: the noted ones and the near unlocks in `ledger`.
    public static func times(log: ChangeLog, ledger: CanLedger, calendar: Calendar = .current) -> [Date] {
        let all = log.moments.filter { $0.deletedAt == nil }.map(\.at) + nearUnlocks(in: ledger)
        var days = Set<Date>()
        return all.sorted().filter { days.insert(StateEngine.dayStart(for: $0, calendar: calendar)).inserted }
    }

    private static func source(_ date: Date) -> String {
        String(Int(date.timeIntervalSince1970))
    }
}
