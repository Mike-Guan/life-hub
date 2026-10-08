import Foundation
import HubCore

// KURO-01 (UI 审核 2026-10-08): needs, activities and moments only changed her line. Until she has her own move
// for each slot (新角色清单), every slot plays one of these fallback families, built from her tap moves.
/// The fallback body language KURO plays for a need, an activity or a moment.
enum KuroSlot: CaseIterable, Sendable {
    /// Asking you to get moving: bright eyes, and every 6 s a hop with her look's move.
    case invite
    /// Worn out: drowsy eyes, a slow breath, and every 7 s she rubs an eye.
    case tired
    /// Busy with something: eyes down, a calm mouth, and every 9 s her look's move without a hop.
    case focus
    /// You are out doing it: bright eyes, the tennis-day bounce, and every 5 s a hop with her look's move.
    case active
    /// The day is wrapping up: happy eyes, and every 6 s her look's move.
    case packingUp

    /// The slot for the inputs, picked in the order her lines use: activity, then moment, then need.
    /// Nil when there is none, or for `.overtime` in the work look, which has its own chin-on-hand pose.
    init?(need: CompanionNeed?, activity: CompanionActivity?, moment: CompanionMoment?, look: KuroLook) {
        if let activity {
            switch activity {
            case .boxingAtGym, .gymSession, .running: self = .active
            case .gymDay, .runDay: self = .invite
            }
            return
        }
        if let moment {
            switch moment {
            case .overtime:
                guard look != .work else { return nil }
                self = .tired
            case .drowsy, .collapsed, .lateCoding, .stiff, .morning, .blanket: self = .tired
            case .slacking, .vibeCoding, .flow, .shooting: self = .focus
            case .gymInvite, .timeToLeave, .heading: self = .invite
            case .packingUp: self = .packingUp
            }
            return
        }
        guard need != nil else { return nil }
        self = .invite
    }

    /// Seconds from the start of one move to the next.
    var period: TimeInterval {
        switch self {
        case .invite, .packingUp: 6
        case .tired: 7
        case .focus: 9
        case .active: 5
        }
    }

    /// Whether she hops at the start of each move.
    var hops: Bool { self == .invite || self == .active }

    /// The move she plays in `look`.
    func move(in look: KuroLook) -> KuroTap {
        self == .tired ? .rub : KuroTap(look: look, sleepy: false)
    }

    /// The move playing at `time` (seconds since the reference date) and its progress (0..<1),
    /// or nil between moves.
    func move(in look: KuroLook, at time: TimeInterval) -> (KuroTap, Double)? {
        let tap = move(in: look)
        let phase = time - (time / period).rounded(.down) * period
        return phase < tap.duration ? (tap, phase / tap.duration) : nil
    }

    /// `pose` with the slot's eyes and mouth. Low energy keeps her low eyes, except when she is worn out anyway.
    func dressing(_ pose: KuroPose) -> KuroPose {
        var pose = pose
        switch self {
        case .tired:
            pose.eyes = .drowsy
            pose.calm = true
        case .focus:
            pose.eyes = .down
            pose.calm = true
        case .invite, .active:
            if !pose.tired { pose.eyes = .bright }
        case .packingUp:
            if !pose.tired { pose.eyes = .happy }
        }
        return pose
    }
}
