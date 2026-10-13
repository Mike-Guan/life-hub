import Foundation

// Issue #273 PR 3, 03 Product/onboarding 文案 v0. Every step can be skipped; a skipped answer stays `nil`
// and `apply` leaves that setting at its "not set" default. The draft is saved after each step, so
// leaving halfway picks up at the same step with the answers so far.
/// The first-run setup's answers while the user goes through it.
public struct OnboardingDraft: Codable, Equatable, Sendable {
    /// The screens in order.
    public enum Step: Int, Codable, CaseIterable, Comparable, Sendable {
        case persona
        case intro
        case chill
        case identity
        case bedtime
        case work
        case location
        case places
        case motion
        case sideHustle
        case health
        case cards
        case notifications
        case done

        public static func < (lhs: Step, rhs: Step) -> Bool { lhs.rawValue < rhs.rawValue }

        /// The next screen, `done` after the last one.
        public var next: Step { Step(rawValue: rawValue + 1) ?? .done }
    }

    /// The work days and hours the user set.
    public struct Work: Codable, Equatable, Sendable {
        /// Work days as `Calendar` weekdays (1 is Sunday); empty for 不固定.
        public var workdays: Set<Int>
        public var startMinute: Int
        public var endMinute: Int

        public init(workdays: Set<Int>, startMinute: Int, endMinute: Int) {
            self.workdays = workdays
            self.startMinute = startMinute
            self.endMinute = endMinute
        }

        // PM 2026-10-13: the wheels start at 9:00 and 18:00, Monday to Friday.
        /// What the screen shows before the user moves anything.
        public static let shown = Work(workdays: [2, 3, 4, 5, 6], startMinute: 9 * 60, endMinute: 18 * 60)
        /// 不固定: no work days.
        public static let irregular = Work(workdays: [], startMinute: 9 * 60, endMinute: 18 * 60)
    }

    static let defaultsKey = "onboardingDraft"
    static let doneKey = "onboardingDone"

    public var schemaVersion = 1
    /// The screen to show.
    public var step = Step.persona
    public var persona = Persona.haku
    /// The Chill activities picked, `nil` when the screen was skipped.
    public var chill: Set<ChillActivity>?
    /// The identity card picked, `nil` for none.
    public var identity: IdentityKind?
    /// The bedtime set, `nil` when the screen was skipped.
    public var bedtime: BedtimeSchedule?
    /// The work days and hours set, `nil` when the screen was skipped.
    public var work: Work?
    /// The 副业 states picked, `nil` when the screen was skipped.
    public var sideStates: [SideHustle]?
    /// The names the user gave the common cards on the cards screen.
    public var names: [String: String] = [:]

    public init() {}

    /// The cards the answers make, as the cards screen shows them.
    public var cards: ModeCards {
        var cards = ModeCards(identity: identity, sideStates: [.project])
        if let chill { cards.chill = chill }
        if let sideStates { cards.pickSideStates(sideStates) }
        for (mode, name) in names {
            if let mode = Mode(rawValue: mode) { cards.rename(mode, to: name) }
        }
        return cards
    }

    /// Moves to the next screen, keeping the answers.
    public mutating func advance() {
        step = step.next
    }

    /// Writes the answers into the settings in `defaults` and marks the setup done.
    /// Skipped answers write the "not set" defaults: no bedtime, no work days.
    public func apply(to defaults: UserDefaults) {
        persona.store(in: defaults)
        cards.store(in: defaults)
        if let bedtime { bedtime.store(in: defaults) }
        var rules = ModeRules.stored(in: defaults)
        let work = work ?? .irregular
        rules.workdays = work.workdays
        rules.workStartMinute = work.startMinute
        rules.workEndMinute = work.endMinute
        rules.store(in: defaults)
        defaults.set(true, forKey: Self.doneKey)
        defaults.removeObject(forKey: Self.defaultsKey)
    }

    /// The draft saved in `defaults`, or a new one when none is saved or it can't be read.
    public static func stored(in defaults: UserDefaults) -> OnboardingDraft {
        guard let data = defaults.data(forKey: defaultsKey) else { return OnboardingDraft() }
        return (try? JSONDecoder().decode(OnboardingDraft.self, from: data)) ?? OnboardingDraft()
    }

    /// Saves the draft in `defaults`.
    public func store(in defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }

    // Installs from before the setup existed have their settings already, so they never see it.
    /// Whether the app should show the setup: not done yet on an install with no records.
    public static func isNeeded(in defaults: UserDefaults, existingInstall: Bool) -> Bool {
        if existingInstall { defaults.set(true, forKey: doneKey) }
        return !defaults.bool(forKey: doneKey)
    }
}
