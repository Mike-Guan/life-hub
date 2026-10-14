import Foundation
import HubCore

// KURO 三个场景 规格 v0 (PM 2026-10-13): the invite, the walk after leaving a place and the bath call start and
// stop exactly like HAKU's; only her moves and lines are her own. Drawn from the UI preview of 2026-10-13.
/// A home scene KURO plays, with how far into it she is.
enum KuroScene: Equatable, Sendable {
    /// Today's invite, `time` seconds after it started: she turns to the door on the left and points at it.
    case invite(time: TimeInterval)
    /// Walking away from `place` with small steps, at `time` seconds; `lookingBack` turns her eyes to you.
    case walking(from: HubPlace.Kind, time: TimeInterval, lookingBack: Bool)
    /// Carrying her towel and clothes off to the bath, `time` seconds after the call started.
    case bath(time: TimeInterval)
    /// Out of the bath with a towel round her head, `time` seconds after the tap.
    case dried(time: TimeInterval)

    /// When the pointing arm comes up and goes down, in seconds into the invite.
    static let pointing: Range<TimeInterval> = 0.45..<2.35
    /// How long one step takes while walking.
    static let step: TimeInterval = 0.32
    /// How long one bath loop lasts: walking to the edge, the line, walking off, bubbles, coming back.
    static let bathLength: TimeInterval = 6
    // UI 审核 2026-10-13: the line ends before she walks off, so it never hangs over an empty frame.
    /// When she has stopped at the edge and says her line for 3 s, in seconds into the bath loop.
    static let bathLineAt: TimeInterval = 1
    /// How long she shows the towel round her head after a tap.
    static let driedLength: TimeInterval = 4
    /// How far she walks before stopping at the edge, in SVG units.
    static let bathEdge: CGFloat = 30
    /// How far she steps right while pointing, in SVG units.
    static let inviteStep: CGFloat = 9

    /// Her line on leaving `place`, shown once for 3 s.
    static func walkLine(from place: HubPlace.Kind) -> String {
        switch place {
        case .home: "……出门了。"
        case .office: "お疲れ。……走了。"
        case .gym, .fitness, .custom: "……回去了。"
        }
    }

    static let bathLine = "……我先去洗澡了。"
    static let driedLine = "……洗好了。"

    /// The room items she leaves behind when she walks off.
    static let room: Set<KuroPart> = [.itemFlower, .itemLamp, .itemBlanket, .itemBag, .boxSandbag]

    /// Shows and hides the scene's parts in `look`; `items` are the shop items she owns and wears.
    func dress(_ look: KuroLook, items: Set<KuroItem>, _ visible: inout Set<KuroPart>) {
        switch self {
        case .invite(let t):
            if Self.pointing.contains(t) {
                // Her left hand points, so whatever it holds in the identity-card looks is set down.
                visible.subtract(Self.leftHanded)
                visible.formUnion([Self.sleeve(look), .inviteHand])
            }
        case .walking(let place, _, _):
            visible.subtract(Self.room.union(Self.handheld))
            visible.formUnion(Self.carried(from: place, look: look, items: items).union([.walkLines, .walkDust]))
        case .bath(let t):
            visible.subtract(Self.room.union(Self.handheld))
            visible.insert(.bathBundle)
            if Self.bubbles(at: t) != nil { visible.insert(.bathBubbles) }
        case .dried:
            visible.subtract(Self.room.union(Self.handheld).union([.catEars]))
            visible.formUnion([.bathTurban, .bathTurbanHands])
        }
    }

    /// What her left hand holds in the identity-card looks.
    static let leftHanded: Set<KuroPart> = [.boxGloveL, .gymBlock, .studyNotebook]

    /// What she holds in her looks; put away when her hands are busy.
    static let handheld: Set<KuroPart> = [
        .chillCup, .tennisRacket, .itemGoldRacket, .workStylus, .deskPen, .deskBooks,
        .boxGloveL, .boxGloveR, .gymBlock, .studyNotebook, .studyHighlighter, .craftPen,
    ]

    // The tennis bag is a shop item, so she carries it only when she owns it; otherwise her backpack.
    /// What she carries walking away from `place` in `look`.
    static func carried(from place: HubPlace.Kind, look: KuroLook, items: Set<KuroItem>) -> Set<KuroPart> {
        if place == .office, look == .work { return [.walkTabletHands] }
        if place != .home, look == .tennis, items.contains(.bag) { return [.itemBag] }
        return [.walkPack, .walkStraps]
    }

    /// The sleeve of her pointing arm in `look`.
    static func sleeve(_ look: KuroLook) -> KuroPart {
        switch look {
        case .work: .inviteSleeveWork
        case .chill: .inviteSleeveChill
        case .tennis: .inviteSleeveTennis
        case .desk: .inviteSleeveDesk
        case .box: .inviteSleeveBox
        case .fitness: .inviteSleeveTennis
        case .study: .inviteSleeveChill
        case .art: .inviteSleeveSmock
        }
    }

    /// Her eyes in the scene, or nil to keep her pose's eyes.
    var eyes: KuroEyes? {
        guard case .dried(let t) = self else { return nil }
        return t < 0.8 ? .happy : .open
    }

    /// How far she has moved sideways, in SVG units; past 140 she is out of the frame.
    var dx: CGFloat {
        // While pointing she steps right to keep her hand clear of the room corner (位置规划图 v0 §10).
        if case .invite(let t) = self { return Self.inviteStep * turn(t) }
        guard case .bath(let time) = self else { return 0 }
        let t = Self.loop(time, Self.bathLength)
        switch t {
        case ..<1: return Self.bathEdge * ease(t)
        case ..<4: return Self.bathEdge
        case ..<4.6: return Self.bathEdge + 130 * ease((t - 4) / 0.6)
        case ..<5.4: return 200
        // UI 审核 2026-10-13: she comes back the way she left, from the right.
        default: return 160 * (1 - ease((t - 5.4) / 0.6))
        }
    }

    /// Where her eyes look, in SVG units: negative toward the door on the left, positive the way she walks.
    var eyesDx: CGFloat {
        switch self {
        case .invite(let t):
            return Self.pointing.contains(t) ? -3.5 * turn(t) : 0
        case .walking(_, _, let back):
            return back ? 0 : 3
        case .bath(let time):
            let t = Self.loop(time, Self.bathLength)
            return t >= 1.1 && t < 4 ? -3 : t >= 5.4 ? -3 : 3
        case .dried:
            return 0
        }
    }

    /// The body's bob and lean on top of her idle; nil keeps her idle motion.
    var motion: IdleMotion? {
        switch self {
        case .invite(let t):
            // Gets up quickly, then leans toward the door while she points.
            let rise = t < 0.35 ? ease(t / 0.35) : 1 - 0.4 * ease((t - 0.35) / 0.2)
            return IdleMotion(dy: -3 * CGFloat(t < 0.55 ? rise : 0.6), angle: -1.5 * turn(t))
        case .walking(_, let t, _):
            return Self.stepping(t, angle: 2)
        case .bath(let time):
            let t = Self.loop(time, Self.bathLength)
            let walking = t < 1 || (4..<4.6).contains(t) || t >= 5.4
            return walking ? Self.stepping(t, angle: t >= 5.4 ? -2 : 2) : nil
        case .dried:
            return IdleMotion(dy: 0, angle: 0)
        }
    }

    /// How far each part moves, in SVG units.
    func shift(_ part: KuroPart) -> CGSize {
        switch self {
        case .walking(_, let t, _):
            let sway = CGFloat(sin(t * .pi / Self.step))
            switch part {
            case .hairBack: return CGSize(width: 1.2 * sway, height: 0)
            case .tennisPonytail: return CGSize(width: 2.5 * sway, height: abs(sway))
            case .walkLines: return CGSize(width: -4 * CGFloat(Self.loop(t, 0.5) / 0.5), height: 0)
            case .walkDust:
                // A puff behind each foot, kicked back and fading as the step ends.
                let p = CGFloat(Self.loop(t, Self.step) / Self.step)
                let foot: CGFloat = Int(t / Self.step) % 2 == 0 ? 10 : 0
                return CGSize(width: foot - 6 * p, height: -2 * p)
            case .itemBag: return CGSize(width: 4, height: -6 + abs(sway))
            default: return eyeShift(part)
            }
        case .bath(let time):
            if part == .bathBubbles, let rise = Self.bubbles(at: time) { return CGSize(width: 0, height: -80 * rise) }
            return CGSize(width: dx, height: 0) + eyeShift(part)
        case .invite(let t):
            // The room stays put; her ears prick toward the door.
            if Self.room.contains(part) { return .zero }
            let ears = part == .catEars ? -1.5 * turn(t) : 0
            return CGSize(width: dx + ears, height: ears) + eyeShift(part)
        default:
            return eyeShift(part)
        }
    }

    /// How far the bubbles have risen (0...1) at `time` into the bath call, or nil before and after they show.
    static func bubbles(at time: TimeInterval) -> CGFloat? {
        let t = loop(time, bathLength)
        guard (4.3..<5.6).contains(t) else { return nil }
        return CGFloat((t - 4.3) / 1.3)
    }

    private func eyeShift(_ part: KuroPart) -> CGSize {
        Self.eyeParts.contains(part) ? CGSize(width: eyesDx, height: 0) : .zero
    }

    static let eyeParts: Set<KuroPart> = [
        .eyesOpen, .eyesClosed, .eyesDrowsy, .eyesBright, .eyesDown, .eyesHappy, .eyesSurprised, .eyesLow,
    ]

    /// How far she has turned toward the door during the invite (0...1).
    private func turn(_ t: TimeInterval) -> CGFloat {
        CGFloat(ease((t - 0.45) / 0.35) * (1 - ease((t - 2.0) / 0.35)))
    }

    private static func stepping(_ t: TimeInterval, angle: Double) -> IdleMotion {
        IdleMotion(dy: -2 * CGFloat(abs(sin(t * .pi / step))), angle: angle + 1.2 * sin(t * .pi / step))
    }

    private static func loop(_ t: TimeInterval, _ length: TimeInterval) -> TimeInterval {
        t - (t / length).rounded(.down) * length
    }
}

extension CGSize {
    fileprivate static func + (a: CGSize, b: CGSize) -> CGSize {
        CGSize(width: a.width + b.width, height: a.height + b.height)
    }
}

/// Smoothstep from 0 to 1 over `x` in 0...1.
private func ease(_ x: Double) -> Double {
    let t = min(max(x, 0), 1)
    return t * t * (3 - 2 * t)
}
