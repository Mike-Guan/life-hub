import Foundation

// Issue #129: every rule decision the companion makes, the ones to do nothing included, with what
// happened afterwards. The rules stay T0; this is the data a later model could learn from. It stays
// on the iPhone and is never synced or sent.
/// One rule decision and, once known, its outcome.
public struct Decision: Codable, Identifiable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    /// What kind of decision it was.
    public enum Kind: String, Codable, Sendable {
        case invite
        case push
        case line
        case animation
        case backoff
        /// The character's read of the user's state, answered on the "不对" card.
        case guess
    }

    /// What happened after the decision.
    public enum Outcome: String, Codable, Sendable {
        /// Mike moved within the window.
        case yes
        /// Mike didn't move within the window.
        case no
        /// The signals can't tell, or nobody checks this kind yet.
        case unknown
    }

    /// What the user said about the guess behind the decision.
    public enum Feedback: String, Codable, Sendable {
        /// The user overrode the guess.
        case corrected
        /// The user picked the option that matches the guess.
        case confirmed
    }

    /// What the action is when the rules chose to do nothing.
    public static let noAction = "none"

    public var schemaVersion: Int
    public var id: UUID
    public var kind: Kind
    /// When the decision was made.
    public var at: Date
    /// When the action takes effect, such as the time a notification goes out.
    public var target: Date?
    // Bands and enums only: never raw health values or coordinates.
    /// What the rules saw, by signal name.
    public var signals: [String: String]
    /// What the rules did, or `Decision.noAction`.
    public var action: String
    /// `nil` until someone judges it.
    public var outcome: Outcome?
    public var feedback: Feedback?
    public var createdAt: Date
    public var updatedAt: Date
    public var updatedBy: String
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        kind: Kind,
        action: String,
        target: Date? = nil,
        signals: [String: String] = [:],
        at: Date = .now,
        deviceID: String
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.id = id
        self.kind = kind
        self.at = at
        self.target = target
        self.signals = signals
        self.action = action
        self.outcome = nil
        self.feedback = nil
        self.createdAt = at
        self.updatedAt = at
        self.updatedBy = deviceID
        self.deletedAt = nil
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, kind, at, target, signals, action, outcome, feedback
        case createdAt, updatedAt, updatedBy, deletedAt
    }

    // Defaults let records written by an older or newer build still load.
    /// Decodes a decision. Only `id`, `kind`, `at` and `action` are required.
    /// - Throws: `DecodingError` when a required field is missing or invalid.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        id = try values.decode(UUID.self, forKey: .id)
        kind = try values.decode(Kind.self, forKey: .kind)
        at = try values.decode(Date.self, forKey: .at)
        target = try values.decodeIfPresent(Date.self, forKey: .target)
        signals = try values.decodeIfPresent([String: String].self, forKey: .signals) ?? [:]
        action = try values.decode(String.self, forKey: .action)
        // An outcome or feedback this build doesn't know reads as not judged.
        outcome = try values.decodeIfPresent(String.self, forKey: .outcome).flatMap(Outcome.init(rawValue:))
        feedback = try values.decodeIfPresent(String.self, forKey: .feedback).flatMap(Feedback.init(rawValue:))
        createdAt = try values.decodeIfPresent(Date.self, forKey: .createdAt) ?? at
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        updatedBy = try values.decodeIfPresent(String.self, forKey: .updatedBy) ?? "unknown"
        deletedAt = try values.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

/// The append-only list of decisions. This is the on-disk document.
public struct DecisionLog: RecordLog, Equatable {
    public static let currentSchemaVersion = 1
    /// How long decisions are kept.
    public static let keep: TimeInterval = 90 * 24 * 60 * 60

    public var schemaVersion: Int
    public var decisions: [Decision]
    // Kept as-is and written back on save, so an older build never deletes newer data (DW-02).
    /// Records this build can't read.
    public var unreadable: [JSONValue]

    public var records: [Decision] {
        get { decisions }
        set { decisions = newValue }
    }

    public init() { self.init(decisions: []) }

    public init(decisions: [Decision]) {
        self.schemaVersion = Self.currentSchemaVersion
        self.decisions = decisions
        self.unreadable = []
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, decisions }

    /// Decodes the log, moving records that fail to decode into `unreadable`.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        let items = try values.decodeIfPresent([LossyRecord<Decision>].self, forKey: .decisions) ?? []
        decisions = items.compactMap(\.value)
        unreadable = items.filter { $0.value == nil }.map(\.raw)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        var list = values.nestedUnkeyedContainer(forKey: .decisions)
        for decision in decisions { try list.encode(decision) }
        for raw in unreadable { try list.encode(raw) }
    }

    /// The signal name that says what a decision was about, such as a need or "offWork".
    public static let subjectKey = "for"

    /// Adds `decision` at the end.
    public mutating func append(_ decision: Decision) {
        decisions.append(decision)
    }

    /// Adds `decision` unless one with its id is already stored.
    /// - Returns: whether it was added.
    @discardableResult
    public mutating func appendOnce(_ decision: Decision) -> Bool {
        guard !decisions.contains(where: { $0.id == decision.id }) else { return false }
        decisions.append(decision)
        return true
    }

    // Planners run on every refresh; only a changed plan is a new decision.
    /// Adds `decision` unless the latest one of its kind about the same subject has the same action and target.
    /// - Returns: whether it was added.
    @discardableResult
    public mutating func appendIfChanged(_ decision: Decision) -> Bool {
        let subject = decision.signals[Self.subjectKey]
        let last = decisions.last {
            $0.deletedAt == nil && $0.kind == decision.kind && $0.signals[Self.subjectKey] == subject
        }
        if let last, last.action == decision.action, last.target == decision.target { return false }
        decisions.append(decision)
        return true
    }

    // Each decision is judged once; a later call for the same one changes nothing.
    /// Sets the outcome of the decision with `id` if it has none yet.
    /// - Returns: whether the decision was found and changed.
    @discardableResult
    public mutating func judge(_ id: UUID, _ outcome: Decision.Outcome, by deviceID: String, at date: Date) -> Bool {
        guard let index = decisions.firstIndex(where: { $0.id == id }), decisions[index].outcome == nil else {
            return false
        }
        decisions[index].outcome = outcome
        decisions[index].updatedAt = date
        decisions[index].updatedBy = deviceID
        return true
    }

    /// The latest decision of `kind`, matching `action` and `target` when they are given.
    public func latest(_ kind: Decision.Kind, action: String? = nil, target: Date? = nil) -> Decision? {
        decisions.last { decision in
            decision.deletedAt == nil && decision.kind == kind
                && (action == nil || decision.action == action) && (target == nil || decision.target == target)
        }
    }

    // Unreadable records have no date this build can read, so they stay.
    /// Drops decisions made more than `keep` before `now`.
    public mutating func trim(now: Date) {
        let cutoff = now.addingTimeInterval(-Self.keep)
        decisions.removeAll { $0.at < cutoff }
    }

    /// The decisions as plain text, one per line, oldest first, with times in `timeZone`.
    public func text(in timeZone: TimeZone = .current) -> String {
        let format = Date.ISO8601FormatStyle(timeZone: timeZone).year().month().day()
            .time(includingFractionalSeconds: false)
        return decisions.filter { $0.deletedAt == nil }.map { decision in
            let signals = decision.signals.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
            let target = decision.target.map { " → \($0.formatted(format))" } ?? ""
            let outcome = decision.outcome.map { " 结果=\($0.rawValue)" } ?? ""
            return "\(decision.at.formatted(format)) [\(decision.kind.rawValue)] \(decision.action)\(target)"
                + " \(signals.joined(separator: " "))\(outcome)"
        }.joined(separator: "\n")
    }

    // Several processes write it (the app and its extensions); each change reads the file first.
    /// Reads the file at `url`, applies `change` and, when it reports a change, drops old decisions
    /// and writes the file back.
    /// - Returns: an error message, or `nil` on success or when `url` is `nil`.
    @discardableResult
    public static func update(at url: URL?, now: Date = .now, _ change: (inout DecisionLog) -> Bool) -> String? {
        var file = LogFile<DecisionLog>(url: url, name: "决策记录")
        var log = DecisionLog()
        if let error = file.load(into: &log) { return error }
        guard change(&log) else { return nil }
        log.trim(now: now)
        return file.save(&log)
    }

    // The writers include extensions with no UI, so the message waits in shared defaults for the app.
    static let errorKey = "decisionLogError"

    /// Keeps `error` in `defaults` for the app to show, or clears the kept one when `error` is `nil`.
    public static func keep(_ error: String?, in defaults: UserDefaults) {
        if let error {
            defaults.set(error, forKey: errorKey)
        } else {
            defaults.removeObject(forKey: errorKey)
        }
    }

    /// The last error kept in `defaults`, or `nil` when the latest update succeeded.
    public static func lastError(in defaults: UserDefaults) -> String? {
        defaults.string(forKey: errorKey)
    }

    /// The log in the file at `url`, or an empty one when there is none or it can't be read.
    public static func read(from url: URL?) -> DecisionLog {
        guard let url, let data = try? Data(contentsOf: url) else { return DecisionLog() }
        return (try? HubJSON.decoder().decode(DecisionLog.self, from: data)) ?? DecisionLog()
    }
}
