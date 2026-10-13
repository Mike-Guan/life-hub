import Foundation

// Drawn like the approved tap preview: one body reaction per look, a sleepy rub and turning away.
/// What KURO does with her body when tapped.
enum KuroTap: Equatable, Sendable {
    /// Work: the tablet flies up over her face, then lowers for a peek.
    case tablet
    /// Chill: the cup goes to her lips and she blows on it.
    case sip
    /// Tennis: the ball bounces twice on her racket.
    case bounce
    /// Desk: one finger pushes her glasses up and the lenses glint.
    case glasses
    /// Boxing card: a start, one punch out to the side, then a flat "……别闹。" face.
    case punch
    /// Fitness card: she hugs the yoga block a little higher with her eyes shut.
    case hug
    /// Study card: the highlighter runs across the line.
    case mark
    /// Art card: the pen comes up and she tilts her head to look at the drawing.
    case sketch
    /// Tired or sleepy in any look: she rubs an eye.
    case rub
    /// Tapped too often: she turns her back with a "…" thought bubble.
    case turnAway
    /// Chin on her hand at the desk (overtime): she looks up and taps her cheek twice.
    case chinTap

    /// The reaction to a tap in `look`; when `sleepy` she rubs her eyes instead.
    init(look: KuroLook, sleepy: Bool) {
        if sleepy {
            self = .rub
            return
        }
        switch look {
        case .work: self = .tablet
        case .chill: self = .sip
        case .tennis: self = .bounce
        case .desk: self = .glasses
        case .box: self = .punch
        case .fitness: self = .hug
        case .study: self = .mark
        case .art: self = .sketch
        }
    }

    /// How long the reaction plays, in seconds.
    var duration: TimeInterval { self == .turnAway ? 3 : 1.1 }

    /// How many taps within `CompanionView.pesterWindow` turn her away.
    static let tooMany = 5

    /// Whether a tap shows the heart bubble: about one tap in four.
    static func heart(_ roll: Int = Int.random(in: 0..<4)) -> Bool { roll == 0 }
}

extension KuroPose {
    /// The same pose `progress` (0..<1) into `tap`, with the heart bubble when `heart` is true.
    func reacting(_ tap: KuroTap, progress p: Double, heart: Bool = false) -> KuroPose {
        var pose = self
        pose.tap = tap
        pose.tapProgress = p
        pose.heart = heart && tap != .turnAway
        pose.blinking = false
        switch tap {
        case .tablet:
            // Her own wide eyes behind the tablet, not the dot eyes (UI 审核 2026-10-08).
            pose.eyes = p < 0.5 ? .bright : .down
        case .sip:
            // Lifts the cup (0-0.2), blows with her eyes shut (0.2-0.55), puts it down (0.55-0.75).
            pose.eyes = p < 0.2 ? pose.eyes : p < 0.55 ? .closed : .happy
            pose.mouthO = (0.2..<0.55).contains(p)
        case .bounce:
            pose.eyes = p < 0.8 ? .bright : .happy
        case .glasses:
            pose.calm = true
        case .rub:
            pose.eyes = p < 0.65 ? .closed : .drowsy
            pose.mouthO = p < 0.65
            pose.calm = p >= 0.65
        case .chinTap:
            pose.eyes = p < 0.75 ? .open : .drowsy
        case .punch:
            // Startled first (第 1 批身份卡 预览, frame 1), then the punch and a flat face.
            pose.eyes = p < 0.15 ? .surprised : .open
            pose.mouthO = p < 0.15
            pose.calm = p >= 0.15
        case .hug:
            pose.eyes = (0.15..<0.8).contains(p) ? .closed : .happy
        case .mark:
            pose.eyes = p < 0.7 ? .down : .happy
        case .sketch:
            pose.eyes = p < 0.4 ? .down : .open
            pose.calm = p >= 0.4
        case .turnAway:
            break
        }
        return pose
    }
}

extension KuroFigure {
    // What she keeps when seen from behind: hair, ears, jackets and things that stay put.
    nonisolated private static let backView: Set<KuroPart> = [
        .itemFlower, .itemLamp, .tennisPonytail, .hairBack, .itemScrunchie, .jacketWork, .jacketChill,
        .itemBlanket, .jacketTennis, .itemBag, .jacketDesk, .earL, .earR, .catEars, .deskBooks, .jacketBox,
        .jacketSmock, .boxSandbag,
    ]

    /// Changes `visible` for `tap` at `progress`.
    nonisolated static func apply(_ tap: KuroTap, progress p: Double, to visible: inout Set<KuroPart>) {
        switch tap {
        case .tablet:
            visible.remove(.workTablet)
            visible.insert(.tapTablet)
        case .sip:
            guard p < 0.75 else { return }
            visible.remove(.chillCup)
            visible.remove(.itemBlanket)
            visible.insert(.tapCup)
            if (0.2..<0.55).contains(p) { visible.insert(.tapPuff) }
        case .bounce:
            visible.insert(.tapBall)
            if p >= 0.8 { visible.insert(.tapSparkle) }
        case .glasses:
            if p < 0.5 {
                visible.remove(.deskPen)
                visible.insert(.tapFinger)
            } else if p < 0.85 {
                visible.insert(.tapGlint)
            }
        case .rub:
            if p < 0.65 { visible.insert(.tapRub) }
        case .mark:
            if p >= 0.5 { visible.insert(.studyMark) }
        case .chinTap, .punch, .hug, .sketch:
            break
        case .turnAway:
            visible.formIntersection(backView)
            visible.formUnion([.backHead, .tapDots])
        }
    }

    /// How far `part` moves from where the SVG draws it, in SVG units.
    nonisolated static func shift(_ part: KuroPart, pose: KuroPose) -> CGSize {
        guard let tap = pose.tap else { return pose.idle?.shift(part, progress: pose.idleProgress) ?? .zero }
        let p = pose.tapProgress
        switch (tap, part) {
        case (.tablet, .tapTablet):
            // Up fast, held over her face, then lowered for a peek.
            let dy = p < 0.15 ? 14 * (1 - p / 0.15) : p < 0.6 ? 0 : 12 * (p - 0.6) / 0.4
            return CGSize(width: 0, height: dy)
        case (.bounce, .tapBall):
            guard p < 0.8 else { return .zero }
            return CGSize(width: 0, height: -40 * abs(sin(p / 0.8 * 2 * .pi)))
        case (.sip, .tapCup):
            // The cup travels from the table to her lips and back instead of jumping (UI 审核 2026-10-08).
            let lift = p < 0.2 ? ease(p / 0.2) : p < 0.55 ? 1 : ease(1 - (p - 0.55) / 0.2)
            return CGSize(width: 26 * (1 - lift), height: 36 * (1 - lift))
        case (.glasses, .deskGlasses):
            return CGSize(width: 0, height: p >= 0.2 ? -2 : 0)
        case (.punch, .boxGloveR):
            // Out to her side, never across her face.
            let out = CGFloat(p < 0.15 ? 0 : p < 0.3 ? (p - 0.15) / 0.15 : p < 0.55 ? 1 : max(0, 1 - (p - 0.55) / 0.2))
            return CGSize(width: 14 * out, height: -12 * out)
        case (.hug, .gymBlock):
            return CGSize(width: 0, height: -4 * CGFloat(sin(min(p / 0.8, 1) * .pi)))
        case (.mark, .studyHighlighter):
            // Back to the start of the line, then across it.
            let back = p < 0.15 ? p / 0.15 : max(0, 1 - (p - 0.15) / 0.35)
            return CGSize(width: -12 * CGFloat(back), height: 0)
        case (.sketch, .craftPen):
            return CGSize(width: 0, height: -14 * CGFloat(sin(min(p / 0.9, 1) * .pi)))
        case (.chinTap, .overtimeHand):
            // Two taps on the cheek between 0.15 and 0.75.
            guard (0.15..<0.75).contains(p) else { return .zero }
            return CGSize(width: 0, height: -4 * abs(sin((p - 0.15) / 0.6 * 2 * .pi)))
        default:
            return .zero
        }
    }
}

/// Smoothstep from 0 to 1 over `x` in 0...1.
private func ease(_ x: Double) -> Double {
    let t = min(max(x, 0), 1)
    return t * t * (3 - 2 * t)
}
