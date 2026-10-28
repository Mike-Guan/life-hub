import SwiftUI

// 待机动作 补齐规格 v0 H6-H11. Six keyframes each from UI 一组's approved preview (haku-idle-3-运动,
// haku-idle-4-外出创作); Mike approved the idle page 2026-10-15. All 动态: each is something the hands do.
// Like KURO's base idles, what the card look holds goes down out of the frame first, so the hands are free.
/// A small move HAKU makes now and then in a card look's base outfit.
enum RunnerBaseIdle: CaseIterable, Sendable {
    /// Sport (H6): one arm across the chest, pulled in, then the other side, and a shake of the hand.
    case stretch
    /// Sport (H7): a bottle in the fist, the cap comes off, a sip, the cap goes back on.
    case drink
    /// Out (H8): the left wrist comes up, a look at it, then a look ahead.
    case checkWrist
    /// Out (H9): a tug on the backpack strap and a shrug.
    case hitchPack
    /// Craft (H10): the pencil spins once, slips on the second turn and drops; HAKU looks at it.
    case twirlPencil
    /// Craft (H11): paint on the hand, wiped twice on the apron, then a look at the hand.
    case wipeHands

    /// How long the move lasts, in seconds.
    var length: CGFloat {
        switch self {
        case .stretch: 3
        case .drink: 2.5
        case .checkWrist, .wipeHands: 1.5
        case .hitchPack: 1.2
        case .twirlPencil: 2
        }
    }

    /// The base-outfit moves `look` draws from.
    static func pool(_ look: RunnerCardLook) -> [RunnerBaseIdle] {
        switch look {
        case .tennis, .fitness, .dance, .ski, .swimming, .yoga, .ball: [.stretch, .drink]
        case .study, .music, .outdoor: [.checkWrist, .hitchPack]
        case .art: [.twirlPencil, .wipeHands]
        }
    }

    /// What `look` holds that goes down out of the frame for this move.
    func putDown(_ look: RunnerCardLook) -> Set<RunnerPart> {
        // The pencil twirl uses the pencil in hand; the fist with the wristband is the hand the sport moves use.
        self == .twirlPencil ? [] : look.held.subtracting([.wristbandHand])
    }

    /// The parts `t` seconds into the move in `look`, starting from `visible`.
    func parts(_ look: RunnerCardLook, at t: CGFloat, _ visible: inout Set<RunnerPart>) {
        let down = putDown(look)
        if !down.isEmpty {
            // Nothing new shows until the held things are all the way down.
            guard hold(at: t) >= 1 else { return }
            visible.subtract(down)
        }
        let u = clock(look, at: t)
        let k = frame(at: u)
        switch self {
        case .stretch:
            if k == 1 || k == 5 { Self.swapEyes(&visible, to: .eyesWork) }
            if k == 2 || k == 4 { Self.swapEyes(&visible, to: .eyesClosed) }
            if k == 1 || k == 2 {
                visible.remove(.wristbandHand)
                visible.insert(.crossArm)
            }
            // The other side: the wristband stays on the right wrist, under the pulling hand.
            if k == 4 {
                visible.remove(.wristbandHand)
                visible.formUnion([.crossArmL, .wristbandPull])
            }
        case .drink:
            // UI 审核 2026-10-15: the bottle shows only while the fist holds it; the hand never vanishes on its own.
            guard (1...4).contains(k) else { return }
            visible.remove(.wristbandHand)
            visible.formUnion([.waterBottle, .bottleFist, .chinHand])
            // The cap is in the closed left hand while HAKU drinks.
            if k != 2, k != 3 { visible.insert(.bottleCap) }
            Self.swapEyes(&visible, to: k == 3 ? .eyesClosed : .eyesWork)
        case .checkWrist:
            if (1...4).contains(k) {
                visible.insert(.wristArm)
                Self.swapEyes(&visible, to: .eyesWork)
            }
        case .hitchPack:
            visible.formUnion([.outPack, .outStraps])
            if (1...4).contains(k) { visible.insert(.chinHand) }
            if k == 1 || k == 2 { Self.swapEyes(&visible, to: .eyesWork) }
            if k == 3 { Self.swapEyes(&visible, to: .eyesClosed) }
        case .twirlPencil:
            guard u > 2.5 * step else { return }
            if t < length - Self.fade {
                visible.remove(.pencil)
                visible.insert(.chinHand)
            }
            visible.insert(.pencilLoose)
        case .wipeHands:
            if k <= 3 { visible.insert(.paintHand) }
            if k == 4 { visible.insert(.chinHand) }
            if k == 2 || k == 3 { Self.swapEyes(&visible, to: .eyesClosed) }
        }
    }

    /// How `part` moves `t` seconds into the move in `look`, or nil when it stays put.
    func move(_ part: RunnerPart, _ look: RunnerCardLook, at t: CGFloat) -> SceneMove? {
        var move = SceneMove()
        if putDown(look).contains(part) {
            // It fades as it goes, so it never rests below her feet where the frame has room.
            move.offset.height = 45 * hold(at: t)
            move.opacity = Double(1 - hold(at: t))
            return move
        }
        let u = clock(look, at: t)
        switch (self, part) {
        case (.stretch, .crossArm):
            move.offset.width = key([5, 5, 0, 0, 0, 0], at: u)
        case (.stretch, .wristbandHand):
            move.offset = CGSize(width: key([0, 0, 0, 0, 0, 1], at: u), height: key([0, 0, 0, 0, 0, -2], at: u))
        case (.drink, .waterBottle), (.drink, .bottleCap):
            // Rotated about the bottle's own centre, as the preview draws it.
            move.angle = Double(key([0, -14, -76, -89, -14, 0], at: u))
            move.anchor = Self.point(97, 121)
            move.offset = CGSize(
                width: key([0, 1, -20, -21, 1, 0], at: u), height: key([0, -18, -32, -34, -18, 0], at: u))
            let shown = Self.ramp(u, 0.5 * step, 0.5 * step + Self.fade)
            move.opacity = Double(shown * (1 - Self.ramp(u, 4.5 * step - Self.fade, 4.5 * step)))
        case (.drink, .bottleFist):
            move.offset = CGSize(
                width: key([-1, -1, -12, -12, -1, -1], at: u), height: key([-1, -1, -20, -22, -1, -1], at: u))
        case (.drink, .chinHand):
            move.offset = CGSize(
                width: key([31, 31, -22, -22, 31, 31], at: u), height: key([-1.5, -1.5, 30.5, 30.5, -1.5, -1.5], at: u))
        case (.checkWrist, .wristArm):
            move.offset.height = key([30, 4, 0, 0, 6, 30], at: u)
        case (.hitchPack, .outPack), (.hitchPack, .outStraps):
            move.offset.height = key([0, 0, -3, -7, -1, 0], at: u)
            // A look that already wears the backpack keeps it on.
            move.opacity = look.parts.contains(.outPack) ? 1 : Double(fadeInOut(at: t))
        case (.hitchPack, .chinHand):
            move.offset = CGSize(width: 12, height: key([22.5, 22.5, 19.5, 15.5, 21.5, 21.5], at: u))
        case (.twirlPencil, .pencil):
            // Round the palm, a turn and a half before it slips; it comes back into the hand at the end.
            move.angle = Double(key([0, -75, -180, -270, -270, -270], at: u))
            move.anchor = Self.point(96, 108)
            if u > 2.5 * step {
                move.angle = 0
                move.opacity = Double(Self.ramp(t, length - Self.fade, length))
            }
        case (.twirlPencil, .chinHand):
            move.offset = CGSize(width: 30, height: key([20.5, 20.5, 20.5, 20.5, 22.5, 22.5], at: u))
        case (.twirlPencil, .pencilLoose):
            // Falls from beside the hand to the floor by the foot.
            let fall = Self.ramp(u, 3 * step, 4 * step)
            move.angle = Double(-30 + 16 * fall)
            move.anchor = Self.point(95, 128)
            move.offset = CGSize(width: 4 + 6.5 * fall, height: -10 + 11 * fall)
            move.opacity = Double(1 - Self.ramp(t, length - Self.fade, length))
        case (.wipeHands, .paintHand):
            move.offset = CGSize(
                width: key([0, -18, -26, -14, -14, -14], at: u), height: key([0, 22, 22, 22, 22, 22], at: u))
        case (.wipeHands, .chinHand):
            move.offset = CGSize(width: 24, height: 14.5)
        default:
            return nil
        }
        return move
    }

    /// The eye offset `t` seconds into the move in `look`, in SVG units.
    func eyes(_ look: RunnerCardLook, at t: CGFloat) -> CGSize {
        let u = clock(look, at: t)
        switch self {
        case .drink: return CGSize(width: key([0, 3, 0, 0, 3, 0], at: u), height: key([0, 2, 0, 0, 2, 0], at: u))
        case .checkWrist:
            return CGSize(width: key([0, 0, -3, -3, 0, 0], at: u), height: key([0, 0, 3, 3, -2, 0], at: u))
        case .twirlPencil:
            return CGSize(width: key([0, 3, 3, 3, 3, 3], at: u), height: key([0, 2, 2, 2, 4, 4], at: u))
        case .wipeHands:
            return CGSize(width: key([3, 1, 0, 0, 3, 0], at: u), height: key([3, 4, 0, 0, 3, 0], at: u))
        default: return .zero
        }
    }

    /// The head tilt `t` seconds into the move in `look`, in degrees.
    func tilt(_ look: RunnerCardLook, at t: CGFloat) -> Double {
        let u = clock(look, at: t)
        switch self {
        case .stretch: return Double(key([0, 0, 3, 0, -3, 0], at: u))
        case .drink: return Double(key([0, 0, 0, -3, 0, 0], at: u))
        case .checkWrist: return Double(key([0, 0, -3, -3, 0, 0], at: u))
        case .twirlPencil: return Double(key([0, 0, 0, 0, 3, 3], at: u))
        default: return 0
        }
    }

    /// How far the body rises in the shrug `t` seconds into the move in `look`, in SVG units.
    func shrug(_ look: RunnerCardLook, at t: CGFloat) -> CGFloat {
        self == .hitchPack ? key([0, 0, 0, -4, 0, 0], at: clock(look, at: t)) : 0
    }

    /// Seconds between two keyframes.
    private var step: CGFloat { length / 5 }

    /// How far the held things are down, 0...1: down over the first eighth of the move, back up over the last.
    private func hold(at t: CGFloat) -> CGFloat {
        Self.ramp(t, 0, 0.12 * length) * (1 - Self.ramp(t, 0.88 * length, length))
    }

    // With something to put down first, the six keyframes play while the hands are free.
    /// The keyframe clock `t` seconds into the move in `look`.
    private func clock(_ look: RunnerCardLook, at t: CGFloat) -> CGFloat {
        guard !putDown(look).isEmpty else { return t }
        return min(max((t - 0.12 * length) / 0.76, 0), length)
    }

    /// The keyframe (0...5) nearest to `u`.
    private func frame(at u: CGFloat) -> Int {
        min(5, max(0, Int((u / step).rounded())))
    }

    /// `values` at the six keyframes, eased from one to the next at `u`.
    private func key(_ values: [CGFloat], at u: CGFloat) -> CGFloat {
        let i = min(4, max(0, Int((u / step).rounded(.down))))
        return values[i] + (values[i + 1] - values[i]) * Self.ramp(u, CGFloat(i) * step, CGFloat(i + 1) * step)
    }

    /// The backpack fades in at the start and out at the end.
    private func fadeInOut(at t: CGFloat) -> CGFloat {
        Self.ramp(t, 0, Self.fade) * (1 - Self.ramp(t, length - Self.fade, length))
    }

    /// Seconds a part takes to fade in or out.
    private static let fade: CGFloat = 0.15

    /// Swaps whichever eyes are showing for `eyes`.
    private static func swapEyes(_ visible: inout Set<RunnerPart>, to eyes: RunnerPart) {
        let all: Set<RunnerPart> = [.eyesChill, .eyesWork, .lidsWork, .eyesClosed]
        guard !visible.contains(eyes), !visible.isDisjoint(with: all) else { return }
        visible.subtract(all)
        visible.insert(eyes)
    }

    /// 0 before `a`, 1 after `b`, eased in between.
    private static func ramp(_ x: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let p = min(max((x - a) / (b - a), 0), 1)
        return p * p * (3 - 2 * p)
    }

    /// An SVG point as a unit point of the figure's frame.
    private static func point(_ x: CGFloat, _ y: CGFloat) -> UnitPoint {
        let box = RunnerArt.bounds
        return UnitPoint(x: (x - box.minX) / box.width, y: (y - box.minY) / box.height)
    }
}
