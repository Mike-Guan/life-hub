import Foundation

// Drawn like the approved tap preview: one body reaction per look, a sleepy rub and turning away.
/// What KURO does with her body when tapped.
enum KuroTap: Equatable, Sendable {
    /// Work: the tablet flies up over her face, then lowers for a peek.
    case tablet
    /// Chill: the cup goes to her lips and she blows on it.
    case sip
    /// Tennis: a start, then a backswing and one swing across her body with speed lines, and the racket back.
    case swing
    /// Desk: one finger pushes her glasses up and the lenses glint.
    case glasses
    /// Boxing card: a start, then the gloves tap together twice.
    case bump
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
    /// Asleep at bedtime: eyes shut, she leans over and back as if rolling over.
    case rollOver
    /// Bedtime starting: she rubs an eye, stretches up in a big yawn, then settles with heavy eyes.
    case goodNight

    /// The reaction to a tap in `look`; when `sleepy` she rubs her eyes instead.
    init(look: KuroLook, sleepy: Bool) {
        if sleepy {
            self = .rub
            return
        }
        switch look {
        case .work: self = .tablet
        case .chill: self = .sip
        case .tennis: self = .swing
        case .desk: self = .glasses
        case .box: self = .bump
        case .fitness: self = .hug
        case .study: self = .mark
        case .art: self = .sketch
        // Until each deferred card has its own tap (新角色清单), she shuts her eyes happily like the fitness hug.
        case .dance, .music, .ski, .swimming, .yoga, .ball, .outdoor: self = .hug
        }
    }

    /// How long the reaction plays, in seconds.
    var duration: TimeInterval {
        switch self {
        case .turnAway: 3
        case .rollOver: 1.4
        case .goodNight: 3.2
        default: 1.1
        }
    }

    // 动作展示总表 C9: an idle cut short used to drop in one frame, so a prop put down jumped back into her hand.
    /// How long what a tap cuts short takes to go back, in seconds.
    static let cutBack: TimeInterval = 0.2

    // 动作展示总表 G1: her eyes jumped from the tap's last ones back to her own in one frame.
    /// How long her eyes stay shut at the end of a tap that leaves them different from her own, in seconds.
    static let closing: TimeInterval = 0.07

    // 动作展示总表 G2: she turned around in one frame. Now she squashes edge-on and swaps sides there, like a card.
    /// How long each flip (squash, swap sides, unsquash) of turning away takes, in seconds.
    static let flip: TimeInterval = 0.24

    /// How thin she gets edge-on in a flip, as a share of her width.
    static let edgeOn = 0.12

    /// How long her "…" bubble takes to fade, in seconds; it shows only while she is fully turned.
    static let dotsFade: TimeInterval = 0.1

    /// Her width (`edgeOn`...1) `p` (0..<1) into turning away: edge-on halfway through each flip.
    static func turnWidth(_ p: Double) -> Double {
        let length = KuroTap.turnAway.duration
        let t = p * length
        let half = flip / 2
        let fromEdge = min(abs(t - half), abs(t - (length - half)))
        guard fromEdge < half else { return 1 }
        return edgeOn + (1 - edgeOn) * ease(fromEdge / half)
    }

    /// Whether her back shows `p` (0..<1) into turning away: between the edge-on moments of the two flips.
    static func facesAway(_ p: Double) -> Bool {
        let length = KuroTap.turnAway.duration
        let t = p * length
        return t >= flip / 2 && t < length - flip / 2
    }

    /// How opaque her "…" bubble is `p` (0..<1) into turning away: in after the first flip, out before the second.
    static func dotsOpacity(_ p: Double) -> Double {
        let length = KuroTap.turnAway.duration
        let t = p * length
        return min(max(min((t - flip) / dotsFade, (length - flip - t) / dotsFade), 0), 1)
    }

    // 动作展示总表 G4: what lay on her lap vanished and came back in one frame around the sip.
    /// How long her lap things take to slide down or back up around a sip, in seconds.
    static let lapSlide: TimeInterval = 0.2

    /// How far down her lap things slide, in SVG units: out of the frame.
    static let lapDrop: CGFloat = 44

    /// How far down (0...1) her lap things are `p` (0..<1) into a sip: down in the first `lapSlide`, out of sight
    /// while she drinks, back up in the `lapSlide` after the cup is down (at 75%).
    static func lapDown(_ p: Double) -> Double {
        lapDown(at: p * KuroTap.sip.duration, cupDown: 0.75 * KuroTap.sip.duration)
    }

    /// How far down (0...1) her lap things are `t` seconds into a drink whose cup is back down at `cupDown`
    /// seconds: down in the first `lapSlide`, back up in the `lapSlide` after `cupDown`.
    static func lapDown(at t: TimeInterval, cupDown: TimeInterval) -> Double {
        if t < lapSlide { return ease(t / lapSlide) }
        return 1 - ease((t - cupDown) / lapSlide)
    }

    // 动作展示总表 G15: the tablet dropped from her face back to her lap in one frame as the tap ended.
    /// How long the tablet takes to go back to her lap at the end of the tablet tap, in seconds.
    static let tabletReturn: TimeInterval = 0.2

    /// How far (0...1) the tablet has gone back to her lap `p` (0..<1) into the tablet tap: the one over her face
    /// slides down and fades as the one on her lap fades in, over the last `tabletReturn`.
    static func tabletDown(_ p: Double) -> Double {
        let length = KuroTap.tablet.duration
        return ease((p * length - (length - tabletReturn)) / tabletReturn)
    }

    /// How far the tablet over her face slides down on its way back to her lap, in SVG units.
    static let tabletDrop: CGFloat = 20

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
        pose.heart = heart && tap != .turnAway && tap != .rollOver && tap != .goodNight
        pose.blinking = false
        switch tap {
        case .tablet:
            // Her own wide eyes behind the tablet, not the dot eyes (UI 审核 2026-10-08).
            pose.eyes = p < 0.5 ? .bright : .down
        case .sip:
            // Lifts the cup (0-0.2), blows with her eyes shut (0.2-0.55), puts it down (0.55-0.75).
            pose.eyes = p < 0.2 ? pose.eyes : p < 0.55 ? .closed : .happy
            pose.mouthO = (0.2..<0.55).contains(p)
        case .swing:
            // 第 1 批身份卡 第 3 轮: startled, backswing, eyes shut on the swing, follow through, racket back.
            pose.eyes = p < 0.15 ? .surprised : p < 0.25 ? .bright : p < 0.5 ? .closed : p < 0.7 ? .open : .down
            pose.mouthO = p < 0.15
        case .glasses:
            pose.calm = true
        case .rub:
            pose.eyes = p < 0.65 ? .closed : .drowsy
            pose.mouthO = p < 0.65
            pose.calm = p >= 0.65
        case .chinTap:
            pose.eyes = p < 0.75 ? .open : .drowsy
        case .rollOver:
            pose.eyes = .closed
        case .goodNight:
            // Rubs an eye (0-0.3), yawns with her eyes squeezed shut (0.3-0.65), then settles, drowsy.
            pose.eyes = p < 0.65 ? .closed : .drowsy
            pose.mouthO = (0.3..<0.65).contains(p)
            pose.calm = p < 0.3 || p >= 0.65
        case .bump:
            pose.eyes = p < 0.15 ? .surprised : KuroIdle.together((p - 0.15) / 0.85) > 0.85 ? .closed : .open
            pose.mouthO = p < 0.15
            pose.calm = p >= 0.15
        case .hug:
            pose.eyes = p < 0.8 ? .closed : .happy
        case .mark:
            // Her mouth eases even when she was frowning over the page (TapMovesTests: the focus slot).
            pose.eyes = p < 0.7 ? .down : .happy
            pose.calm = false
        case .sketch:
            pose.eyes = p < 0.4 ? .down : .open
            pose.calm = p >= 0.4
        case .turnAway:
            break
        }
        if tap != .turnAway, (1 - p) * tap.duration < KuroTap.closing, pose.eyes != eyes { pose.eyes = .closed }
        return pose
    }

    /// The same pose with `move`, which a tap cut short, gone `back` (0...1) to where the move starts.
    func cutting(_ move: (KuroIdle, Double)?, back: Double) -> KuroPose {
        var pose = idling(move)
        pose.idleBack = move == nil ? 0 : back
        return pose
    }
}

extension KuroFigure {
    // What she keeps when seen from behind: hair, ears, jackets and things that stay put.
    nonisolated private static let backView: Set<KuroPart> = [
        .itemFlower, .itemLamp, .tennisPonytail, .hairBack, .itemScrunchie, .jacketWork, .jacketChill,
        .itemBlanket, .jacketTennis, .itemBag, .jacketDesk, .earL, .earR, .catEars, .deskBooks, .jacketBox,
        .jacketSmock, .boxSandbag, .danceSpeaker, .weeklyHairMintPony, .weeklyHairCherryPony, .weeklyHairStarPony,
        .weeklyBlanketBear, .weeklyRoomCloud, .weeklyRoomSucculent, .weeklyRoomNightlightGlow, .weeklyRoomNightlight,
        .weeklyHatBeanie, .weeklyHatBeaniePom,
    ]

    /// Keeps in `visible` only what shows from behind, with the back of her head.
    nonisolated static func turnAround(_ visible: inout Set<KuroPart>) {
        visible.formIntersection(backView)
        visible.insert(.backHead)
    }

    /// Her eyes and mouths, which the tap sets even while an idle it cut short goes back.
    nonisolated private static let face: Set<KuroPart> = [
        .eyesOpen, .eyesClosed, .eyesDrowsy, .eyesBright, .eyesDown, .eyesHappy, .eyesSurprised, .eyesLow, .eyesWink,
        .eyesFull, .mouthCat, .mouthFlat, .mouthSmile, .mouthO,
    ]

    /// What an idle cut short by a tap fades out as it goes back: notes, snow, puffs, marks and sparkles.
    nonisolated static let fades: Set<KuroPart> = [
        .speakerNoteA, .speakerNoteB, .snowBits, .sneezePuff, .tapPuff, .studyMark, .tapSparkle, .tapGlint,
    ]

    /// Shows in `visible` what `idle` shows at `progress`, except her face; what it moved out of the frame stays,
    /// to come back.
    nonisolated static func cut(_ idle: KuroIdle, progress p: Double, _ visible: inout Set<KuroPart>) {
        var moved = visible
        idle.apply(p, to: &moved)
        let away = visible.subtracting(moved).filter { idle.shift($0, progress: p) != .zero }
        visible = moved.subtracting(face).union(visible.intersection(face)).union(away)
    }

    /// What lies on her lap; put away when she drinks.
    nonisolated static let lap: Set<KuroPart> = [.itemBlanket, .weeklyBlanketBear, .weeklyRoomCloud]

    /// Changes `visible` for `tap` at `progress`.
    nonisolated static func apply(_ tap: KuroTap, progress p: Double, to visible: inout Set<KuroPart>) {
        switch tap {
        case .tablet:
            visible.insert(.tapTablet)
            if visible.remove(.workTablet) != nil, KuroTap.tabletDown(p) > 0 { visible.insert(.workTablet) }
        case .sip:
            if KuroTap.lapDown(p) >= 1 { visible.subtract(lap) }
            guard p < 0.75 else { return }
            visible.remove(.chillCup)
            visible.insert(.tapCup)
            if (0.2..<0.55).contains(p) { visible.insert(.tapPuff) }
        case .swing:
            if (0.25..<0.5).contains(p) { visible.insert(.swingLines) }
        case .glasses:
            if p < 0.5 {
                visible.remove(.deskPen)
                visible.insert(.tapFinger)
            } else if p < 0.85 {
                visible.insert(.tapGlint)
            }
        case .rub:
            if p < 0.65 { visible.insert(.tapRub) }
        case .goodNight:
            if p < 0.3 { visible.insert(.tapRub) }
        case .mark:
            if p >= 0.5 { visible.insert(.studyMark) }
        case .chinTap, .bump, .hug, .sketch, .rollOver:
            break
        case .turnAway:
            guard KuroTap.facesAway(p) else { return }
            turnAround(&visible)
            if KuroTap.dotsOpacity(p) > 0 { visible.insert(.tapDots) }
        }
    }

    /// How far `part` moves from where the SVG draws it, in SVG units.
    nonisolated static func shift(_ part: KuroPart, pose: KuroPose) -> CGSize {
        let move = moveShift(part, pose: pose)
        let cut = cutShift(part, pose: pose, tapShift: move)
        let scene = pose.scene?.shift(part) ?? .zero
        return CGSize(width: move.width + cut.width + scene.width, height: move.height + cut.height + scene.height)
    }

    /// How far `part` moves for an idle that her tap cut short, on its way back to where the move starts, on top
    /// of `tapShift`.
    nonisolated private static func cutShift(_ part: KuroPart, pose: KuroPose, tapShift: CGSize) -> CGSize {
        guard pose.tap != nil, let idle = pose.idle else { return .zero }
        let now = idle.shift(part, progress: pose.idleProgress)
        // The cup she blows on is already at her lips, so it stays there until her sip has lifted it as high.
        if part == .tapCup, pose.tap == .sip, idle == .blow {
            guard now.height < tapShift.height else { return .zero }
            return CGSize(width: now.width - tapShift.width, height: now.height - tapShift.height)
        }
        let start = idle.shift(part, progress: 0)
        let back = CGFloat(ease(cutPhase(part, back: pose.idleBack)))
        return CGSize(
            width: now.width + (start.width - now.width) * back, height: now.height + (start.height - now.height) * back
        )
    }

    // UI 审核 2026-10-15 (C9 round 1): a hand the idle brought up and the prop it put down showed together, as two
    // right hands. As in the idle, one goes before the other: the hand first, then the prop.
    /// How far (0...1) `part` has gone back when the cut idle is `back` (0...1) back: her idle hands in the first
    /// half, everything else in the second.
    nonisolated static func cutPhase(_ part: KuroPart, back: Double) -> Double {
        idleHands.contains(part) ? back * 2 : back * 2 - 1
    }

    /// The hands and arms her idles bring up from out of sight.
    nonisolated static let idleHands: Set<KuroPart> = [
        .idleReach, .idleTowelWipe, .idleTuckHand, .idleFrameHands, .idleCollarHands, .idlePhone, .mittenArm,
        .mittenHand,
    ]

    /// How far `part` moves for her tap reaction or idle move, in SVG units.
    nonisolated private static func moveShift(_ part: KuroPart, pose: KuroPose) -> CGSize {
        guard let tap = pose.tap else { return pose.idle?.shift(part, progress: pose.idleProgress) ?? .zero }
        let p = pose.tapProgress
        switch (tap, part) {
        case (.tablet, .tapTablet):
            // Up fast, held over her face, then lowered for a peek.
            let dy = p < 0.15 ? 14 * (1 - p / 0.15) : p < 0.6 ? 0 : 12 * (p - 0.6) / 0.4
            return CGSize(width: 0, height: dy + KuroTap.tabletDrop * CGFloat(KuroTap.tabletDown(p)))
        case (.sip, .tapCup):
            // The cup travels from the table to her lips and back instead of jumping (UI 审核 2026-10-08).
            let lift = p < 0.2 ? ease(p / 0.2) : p < 0.55 ? 1 : ease(1 - (p - 0.55) / 0.2)
            return CGSize(width: 26 * (1 - lift), height: 36 * (1 - lift))
        case (.sip, _) where lap.contains(part):
            return CGSize(width: 0, height: KuroTap.lapDrop * CGFloat(KuroTap.lapDown(p)))
        case (.glasses, .deskGlasses):
            return CGSize(width: 0, height: p >= 0.2 ? -2 : 0)
        case (.bump, .boxGloveL), (.bump, .boxGloveR):
            guard p >= 0.15 else { return .zero }
            let side: CGFloat = part == .boxGloveL ? 1 : -1
            return CGSize(width: 4 * side * KuroIdle.together((p - 0.15) / 0.85), height: 0)
        // Batch 2 cards: whatever her right hand holds comes up with the hug, like the block.
        case (.hug, .gymBlock), (.hug, .yogaMat), (.hug, .sportBall), (.hug, .sportBallHand), (.hug, .outPole):
            return CGSize(width: 0, height: -4 * CGFloat(sin(min(p / 0.8, 1) * .pi)))
        case (.mark, .studyHighlighter):
            // Back to the start of the line, then across it.
            let back = p < 0.15 ? p / 0.15 : max(0, 1 - (p - 0.15) / 0.35)
            return CGSize(width: -12 * CGFloat(back), height: 0)
        case (.sketch, .craftPen):
            return CGSize(width: 0, height: -14 * CGFloat(sin(min(p / 0.9, 1) * .pi)))
        case (.goodNight, .tapRub):
            // Comes up from below, rubs side to side, goes back down before the yawn.
            let up = min(p / 0.06, 1, max((0.3 - p) / 0.05, 0))
            return CGSize(width: 1.5 * CGFloat(sin(p * 40)), height: 12 * CGFloat(1 - ease(up)))
        case (.chinTap, .overtimeHand):
            // Two taps on the cheek between 0.15 and 0.75.
            guard (0.15..<0.75).contains(p) else { return .zero }
            return CGSize(width: 0, height: -4 * abs(sin((p - 0.15) / 0.6 * 2 * .pi)))
        default:
            return .zero
        }
    }

    /// How `part` turns for her tap reaction or idle move, or nil when it keeps still.
    nonisolated static func turn(_ part: KuroPart, pose: KuroPose) -> KuroTurn? {
        // About a point inside her head, so the pom swings side to side on top of the beanie.
        if part == .weeklyHatBeaniePom, pose.pom != 0 { return KuroTurn(pivot: CGPoint(x: 60, y: 30), angle: pose.pom) }
        // The yoga stretch bends her whole body about her hips; a tap that cuts it short eases her back upright.
        if let idle = pose.idle, let angle = idle.lean(part, progress: pose.idleProgress) {
            let back = pose.tap == nil ? 0 : ease(pose.idleBack)
            return KuroTurn(pivot: KuroIdle.hips, angle: angle * (1 - back))
        }
        // 动作展示总表 C7: at the end of the juggle the flat racket flips edge-on about her grip.
        if part == .juggleRacket {
            guard pose.tap == nil, pose.idle == .juggle else { return nil }
            let width = KuroIdle.flatRacketWidth(pose.idleProgress)
            return KuroTurn(pivot: CGPoint(x: 94, y: 120), axis: 90, scale: CGFloat(width))
        }
        // The gold racket from the shop is drawn like her own one, so it turns the same way. 动作展示总表 G6: the
        // watch's raised racket stands upright in her hand, so it turns about that hand along its own handle.
        let raised = part == .watchRacket
        guard part == .tennisRacket || part == .itemGoldRacket || raised else { return nil }
        let grip = raised ? CGPoint(x: 111, y: 108) : CGPoint(x: 98, y: 112)
        let handle: Double = raised ? 0 : 20
        // A twirl cut short turns back to the front before the swing starts.
        if pose.tap == .swing, pose.idle != .twirl || pose.tapProgress >= 0.15 {
            let pivot = raised ? grip : CGPoint(x: 91.8, y: 128.9)
            return KuroTurn(pivot: pivot, angle: swingAngle(pose.tapProgress))
        }
        // The gold racket is never juggled on, so it has nothing to open out from.
        if part != .itemGoldRacket, pose.tap == nil, pose.idle == .juggle, pose.idleProgress >= KuroIdle.racketSwap {
            return KuroTurn(pivot: grip, axis: handle, scale: CGFloat(KuroIdle.uprightRacketWidth(pose.idleProgress)))
        }
        guard pose.idle == .twirl else { return nil }
        // One full spin about the handle over the first 70%; never quite edge-on, so the frame stays drawn.
        let width = cos(min(pose.idleProgress / 0.7, 1) * 2 * .pi)
        let spun = width < 0 ? min(width, -0.1) : max(width, 0.1)
        let scale = pose.tap == nil ? spun : spun + (1 - spun) * ease(pose.idleBack)
        return KuroTurn(pivot: grip, axis: handle, scale: CGFloat(scale))
    }

    /// The racket's turn about her hand at `p` into the swing, in degrees: back 4°, across her body to -75°,
    /// -50° on the follow through, then down again.
    nonisolated private static func swingAngle(_ p: Double) -> Double {
        if p < 0.15 { return 0 }
        if p < 0.25 { return 4 * ease((p - 0.15) / 0.1) }
        if p < 0.35 { return 4 - 79 * ease((p - 0.25) / 0.1) }
        if p < 0.5 { return -75 }
        if p < 0.7 { return -75 + 25 * ease((p - 0.5) / 0.2) }
        return -50 * (1 - ease((p - 0.7) / 0.2))
    }
}

/// Smoothstep from 0 to 1 over `x` in 0...1.
private func ease(_ x: Double) -> Double {
    let t = min(max(x, 0), 1)
    return t * t * (3 - 2 * t)
}
