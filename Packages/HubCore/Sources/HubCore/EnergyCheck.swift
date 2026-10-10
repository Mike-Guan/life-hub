import Foundation

// Issue #236 (PM V0.1 details in 干预策略 §6, 2026-10-08). A long press on the character asks whether her read of
// today's energy is right. A correction is a self-report, which StateEngine already lets win for the
// rest of the day; an answer that agrees writes nothing but the record.
/// The user's answer when the character says what she thinks today's energy is.
public enum EnergyAnswer: String, Codable, CaseIterable, Sendable {
    case lessTired
    case actuallyTired

    /// The button title.
    public var title: String {
        switch self {
        case .lessTired: "没那么累"
        case .actuallyTired: "其实很累"
        }
    }
}

/// The "不对" card: what the character asks, what each answer sets, and the record it leaves.
public enum EnergyCheck {
    /// The signal value in the decision log that marks an energy guess.
    static let subject = "energy"

    /// The level `answer` sets when the guess was `guess`, or `nil` when the answer agrees with it.
    /// At full energy both answers lower it.
    public static func level(after answer: EnergyAnswer, guess: EnergyLevel) -> EnergyLevel? {
        switch (guess, answer) {
        case (.low, .actuallyTired), (.okay, .lessTired): nil
        case (.low, .lessTired), (.full, .lessTired): .okay
        case (.okay, .actuallyTired), (.full, .actuallyTired): .low
        }
    }

    /// What `persona` says about `guess` when the card opens.
    public static func question(for guess: EnergyLevel, persona: Persona) -> String {
        switch (persona, guess) {
        case (.haku, .low): "我觉得你今天没睡够。"
        case (.haku, .okay): "我觉得你今天还行。"
        case (.haku, .full): "我觉得你今天电挺满。"
        case (.kuro, .low): "……今天好像没睡够。"
        case (.kuro, .okay): "……今天还可以吧。"
        case (.kuro, .full): "……今天状态不错。"
        }
    }

    /// What `persona` says after the answer.
    public static func reply(corrected: Bool, persona: Persona) -> String {
        switch persona {
        case .haku: corrected ? "哦。" : "嗯。"
        case .kuro: "……嗯。"
        }
    }

    // Bands and enums only: the reading's reasons hold last night's sleep time, which stays out of the log.
    /// The decision-log record of `answer` to `guess`. A correction shares its id with the self-report it wrote.
    public static func decision(
        guess: EnergyReading,
        answer: EnergyAnswer,
        report: EnergyEvent?,
        at date: Date,
        deviceID: String
    ) -> Decision {
        let signals = [
            DecisionLog.subjectKey: subject,
            "source": guess.source.rawValue,
            "answer": answer.rawValue,
            "set": report?.level?.rawValue ?? Decision.noAction,
        ]
        var decision = Decision(
            id: report?.id ?? UUID(),
            kind: .guess,
            action: guess.level.rawValue,
            signals: signals,
            at: date,
            deviceID: deviceID
        )
        decision.feedback = report == nil ? .confirmed : .corrected
        return decision
    }

    /// Answers the guess: records a self-report when the answer corrects it, and the decision either way.
    /// - Returns: the self-report written, or `nil` when the answer agreed; and a decision-log error message.
    @MainActor
    @discardableResult
    public static func answer(
        _ answer: EnergyAnswer,
        to guess: EnergyReading,
        energy: EnergyStore,
        decisionLogURL: URL?,
        at date: Date = .now
    ) -> (report: EnergyEvent?, error: String?) {
        var report: EnergyEvent?
        if let level = Self.level(after: answer, guess: guess.level) {
            let event = EnergyEvent.selfReport(level, at: date, deviceID: energy.deviceID)
            if energy.record(event) { report = event }
        }
        let record = Self.decision(guess: guess, answer: answer, report: report, at: date, deviceID: energy.deviceID)
        let error = DecisionLog.update(at: decisionLogURL, now: date) { $0.appendOnce(record) }
        return (report, error)
    }
}
