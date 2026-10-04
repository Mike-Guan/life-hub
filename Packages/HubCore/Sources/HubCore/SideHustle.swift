import Foundation

// Stored as the `tag` of a 副业 mode change, so it keeps its source like the mode does.
/// What Mike does in 副业 mode. Tapping HAKU cycles through these.
public enum SideHustle: String, Codable, CaseIterable, Sendable {
    case vibeCoding
    case shooting
    case operating

    /// The state of a 副业 change with `tag`. Changes without a known tag are vibe coding.
    public init(tag: String?) {
        self = tag.flatMap(SideHustle.init(rawValue:)) ?? .vibeCoding
    }

    public var title: String {
        switch self {
        case .vibeCoding: "vibe coding"
        case .shooting: "拍摄"
        case .operating: "运营"
        }
    }

    /// The state after this one when Mike taps HAKU.
    public var next: SideHustle {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? all.startIndex
        return all[(index + 1) % all.count]
    }

    /// The look HAKU takes in this state.
    public var moment: CompanionMoment {
        self == .vibeCoding ? .vibeCoding : .shooting
    }

    /// How long one more can joins the pile next to HAKU while vibe coding.
    public static let canEvery: TimeInterval = 30 * 60

    /// The cans piled up next to HAKU after vibe coding since `since`, 0 to 3. Only for the look.
    public static func codingCans(since: Date, now: Date) -> Int {
        let elapsed = now.timeIntervalSince(since)
        guard elapsed > 0 else { return 0 }
        return min(Int(elapsed / canEvery), 3)
    }
}

extension ModeChange {
    /// The 副业 state of this change, `nil` in other modes.
    public var sideHustle: SideHustle? {
        mode == .money ? SideHustle(tag: tag) : nil
    }

    /// Whether `other` puts Mike in the same mode and, in 副业, the same state.
    public func isSameState(as other: ModeChange?) -> Bool {
        mode == other?.mode && sideHustle == other?.sideHustle
    }
}
