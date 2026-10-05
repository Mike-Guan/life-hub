import Foundation

// PRD section 15. The app picks the cue from Daily Widget's tasks; CompanionKit draws it.
/// What HAKU holds up for a planned Daily Widget task.
public enum DailyProp: String, Codable, CaseIterable, Sendable {
    /// Headphones on.
    case headphones
    /// A shopping bag.
    case bag
    /// The gym bag over the shoulder.
    case gymBag
    /// A sticky note with a clock.
    case note
}

/// A planned Daily Widget task HAKU reacts to: one starting soon, or one that just started.
public struct DailyCue: Equatable, Sendable {
    /// Where the task is in time.
    public enum Stage: String, Codable, Sendable {
        /// From 15 minutes before the start until the start.
        case soon
        /// Up to 10 minutes after the start.
        case now
    }

    public var stage: Stage
    public var prop: DailyProp
    /// The task's id, with the day for a repeating task, so the start plays once.
    public var id: String

    public init(stage: Stage, prop: DailyProp, id: String) {
        self.stage = stage
        self.prop = prop
        self.id = id
    }
}
