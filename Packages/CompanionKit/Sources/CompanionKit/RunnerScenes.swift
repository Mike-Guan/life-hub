import HubCore
import SwiftUI

// Scene library v0 (Mike approved the preview 2026-10-05). Each scene replaces the Daily prop with its own
// props and a short loop; the timings follow the preview page.
extension DailyScene {
    /// The parts HAKU shows for this scene.
    var parts: Set<RunnerPart> {
        switch self {
        case .coffee: [.coffeeSteam, .blowLines, .coffeeCup]
        case .meal, .drinks: [.riceBowl, .chopsticks]
        case .meeting: [.screenGlow, .macbook, .typeHandL, .typeHandR]
        case .call: [.phoneEar, .talkDots]
        case .grocery: [.toteBag]
        case .shopping: [.shopShine, .paperBagL, .paperBagR]
        case .cook: [.apron, .spatula]
        case .gym: [.gymBag, .dumbbell]
        case .run: [.speedLines, .walkDust]
        case .walk: [.sunIcon, .walkDust]
        case .photo: [.cameraFlash, .camera]
        case .friends: [.waveArcs, .waveHand]
        case .haircut: [.hairBits, .clipArm, .clipper, .buzzLines]
        case .doctor: [.cheekHand, .ouchLines]
        }
    }

    /// Parts the scene's props would clash with: what the hands held and, by the ear, the headset.
    var hides: Set<RunnerPart> {
        let held: Set<RunnerPart> = [
            .monsterCan, .phone, .phoneFeed, .phoneHand, .laptop, .typingHands, .handheld, .sketchbook,
            .pencil, .onigiri, .cloth,
        ]
        switch self {
        case .call, .haircut, .doctor: return held.union([.headset, .cupL, .cupR, .mic])
        default: return held
        }
    }
}

/// How one scene part moves at a moment of its loop.
struct SceneMove {
    var offset = CGSize.zero
    var angle = 0.0
    var scale: CGFloat = 1
    var anchor = UnitPoint.center
    var opacity = 1.0
    /// Vertical squash on top of `scale`.
    var scaleY: CGFloat = 1

    /// The move of `part` in `scene` at `time` seconds, or nil when the scene doesn't show the part.
    static func of(_ part: RunnerPart, in scene: DailyScene, at time: CGFloat) -> SceneMove? {
        guard scene.parts.contains(part) else { return nil }
        let t = time
        var move = SceneMove()
        let box = RunnerArt.bounds
        let anchor = { (x: CGFloat, y: CGFloat) in
            UnitPoint(x: (x - box.minX) / box.width, y: (y - box.minY) / box.height)
        }
        switch (scene, part) {
        case (.coffee, .coffeeCup), (.coffee, .coffeeSteam):
            let sip = bump(loop(t, 3.4), from: 2.2, to: 3.2)
            move.offset = CGSize(width: -8 * sip, height: -10 * sip)
            if part == .coffeeCup {
                move.angle = -14 * Double(sip)
                move.anchor = anchor(90, 112)
            } else {
                move.offset.height -= 3 * frac(t * 1.5)
                move.opacity = 0.5 + 0.5 * Double(sin(t * 4))
            }
        case (.coffee, .blowLines):
            let c = loop(t, 3.4)
            move.opacity = c > 0.5 && c < 1.8 && sin(t * 12) > -0.3 ? 1 : 0
        case (.meal, .chopsticks), (.drinks, .chopsticks):
            let k = bump(loop(t, 1.6), from: 0, to: 1.1)
            move.offset = CGSize(width: -4 * k, height: -10 * k)
            move.angle = -8 * Double(k)
            move.anchor = anchor(92, 122)
        case (.meeting, .typeHandL):
            move.offset.height = -2.5 * max(0, sin(t * 15))
        case (.meeting, .typeHandR):
            move.offset.height = -2.5 * max(0, sin(t * 15 + 2))
        case (.meeting, .screenGlow):
            move.opacity = 0.5 + 0.4 * Double(sin(t * 3))
        case (.call, .talkDots):
            move.opacity = 0.35 + 0.65 * Double(abs(sin(t * 2)))
        case (.grocery, .toteBag):
            move.angle = 6 * Double(sin(t / 2.4 * 2 * .pi))
            move.anchor = anchor(22, 100)
        case (.shopping, .paperBagL), (.shopping, .paperBagR):
            let swing = 7 * Double(sin(t / 1.2 * .pi))
            move.angle = part == .paperBagL ? swing : -swing
            move.anchor = part == .paperBagL ? anchor(21, 99) : anchor(99, 99)
        case (.shopping, .shopShine):
            move.opacity = sin(t * 5) > 0 ? 1 : 0.2
        case (.cook, .spatula):
            move.angle = -24 * Double(bump(loop(t, 1.4), from: 0, to: 0.7))
            move.anchor = anchor(93, 122)
        case (.gym, .dumbbell):
            move.offset.height = -12 * bump(loop(t, 2), from: 0.2, to: 1.6)
        case (.run, .speedLines):
            let d = frac(t * 1.9 / 0.5)
            move.offset.width = -8 * d
            move.opacity = Double(1 - 0.6 * d)
        case (.run, .walkDust), (.walk, .walkDust):
            move = dust(at: t * (scene == .run ? 1.9 : 0.6))
        case (.walk, .sunIcon):
            move.angle = Double(t) * 20
            move.anchor = anchor(20, 8)
        case (.photo, .camera):
            move.offset = CGSize(width: 0.6 * sin(t * 7), height: 2 * bump(loop(t, 2.4), from: 1.5, to: 1.8))
        case (.photo, .cameraFlash):
            let c = loop(t, 2.4)
            move.opacity = c > 1.5 && c < 1.9 ? 1 : 0
        case (.friends, .waveHand):
            move.angle = 14 * Double(sin(t / 0.8 * .pi))
            move.anchor = anchor(90, 104)
        case (.friends, .waveArcs):
            move.opacity = sin(t / 0.8 * .pi) > 0 ? 1 : 0.2
        case (.haircut, .clipArm), (.haircut, .clipper):
            move.offset.height = 5 * sin(t * .pi)
            move.angle = -2 * Double(sin(t * .pi))
            move.anchor = anchor(98, 66)
        case (.haircut, .hairBits):
            let p = frac(t)
            move.offset = CGSize(width: -2 * p, height: 16 * p)
            move.opacity = Double(1 - p)
        case (.haircut, .buzzLines):
            move.opacity = sin(t * 20) > 0 ? 1 : 0.3
        case (.doctor, .cheekHand):
            move.offset.height = sin(t * 5)
        case (.doctor, .ouchLines):
            move.opacity = sin(t * 6) > 0 ? 1 : 0.2
        default:
            break
        }
        return move
    }
}

extension SceneMove {
    /// The puff of dust kicked up behind HAKU's feet at `time` seconds of walking at normal pace.
    static func dust(at time: CGFloat) -> SceneMove {
        let p = frac(time / 0.9)
        let box = RunnerArt.bounds
        return SceneMove(
            offset: CGSize(width: -10 * p, height: -4 * p),
            scale: 0.6 + 0.6 * p,
            anchor: UnitPoint(x: (22 - box.minX) / box.width, y: (128 - box.minY) / box.height),
            opacity: Double(1 - p)
        )
    }
}

extension RunnerPose {
    /// Walking away from `place` at `time` seconds: leaning in, hopping each step, with speed lines behind.
    mutating func walk(from place: HubPlace.Kind, time t: CGFloat) {
        walkFrom = place
        walkTime = t
        let step = abs(sin(t * .pi / 0.45))
        lean = 4
        bounce = -1.5 * step
        headDy += 2 * step
        dash = frac(t / 0.5)
        if place == .office { bagLift = 1 }
    }

    /// On the way between home and the office at `time` seconds: a brisk walk to work with a yawn every 4 s, a
    /// slow drag home with sleepy eyes. On a train or bus HAKU stands and sways with the ride instead of stepping.
    mutating func commute(_ phase: CommutePhase, time t: CGFloat) {
        let toWork = phase.leg == .toWork
        switch phase.stage {
        case .walking:
            walk(from: toWork ? .home : .office, time: toWork ? t : 0.6 * t)
        case .onTransit:
            lean = 2 * Double(sin(t * .pi / 1.6))
            headDy += toWork ? 0 : 1.5 * abs(sin(t * .pi / 3))
        case .arrived:
            // The arrival moment is drawn in the UI thread's next round; until then the leg's mood alone shows.
            break
        }
        commuteLeg = phase.leg
        if toWork {
            yawn = max(yawn, bump(loop(t, 4), from: 0, to: 1.2))
        } else {
            blink = min(blink, 0.35)
            headDy += 1.5
        }
    }

    /// HAKU's head and body in `scene` at `time` seconds, eased in by `propRaise`.
    mutating func playScene(_ scene: DailyScene, time t: CGFloat) {
        let r = propRaise
        switch scene {
        case .meal, .drinks:
            headDy += 1.5 * bump(loop(t, 1.6), from: 0, to: 1.1) * r
        case .meeting:
            headDy += 1.6 * bump(loop(t, 3.2), from: 2.2, to: 2.9) * r
        case .call:
            eyesDx = 3 * sin(t * 1.4) * r
        case .grocery:
            bounce = -abs(sin(t * .pi / 0.6)) * r
        case .shopping:
            bounce = -1.5 * abs(sin(t * .pi / 0.6)) * r
        case .cook:
            headDy += bump(loop(t, 1.4), from: 0, to: 0.7) * r
        case .gym:
            headDy += 1.2 * bump(loop(t, 2), from: 0.2, to: 1.6) * r
        case .run, .walk:
            let pace: CGFloat = scene == .run ? 1.9 : 0.6
            let step = abs(sin(t * pace * .pi / 0.45))
            lean = (scene == .run ? 8 : 4) * Double(r)
            bounce = (scene == .run ? -3 : -1.5) * step * r
            headDy += 2 * step * r
        case .haircut:
            headTilt = -3 * Double(r)
        case .doctor:
            headTilt = (-6 + 2 * Double(sin(t / 2.6 * 2 * .pi))) * Double(r)
            eyesShut = r > 0.5
        case .coffee, .photo, .friends:
            break
        }
    }
}

private func loop(_ t: CGFloat, _ length: CGFloat) -> CGFloat {
    t.truncatingRemainder(dividingBy: length)
}

private func frac(_ x: CGFloat) -> CGFloat {
    x - x.rounded(.down)
}

private func bump(_ x: CGFloat, from a: CGFloat, to b: CGFloat) -> CGFloat {
    sin(min(max((x - a) / (b - a), 0), 1) * .pi)
}

// Bath call (Mike approved the preview 2026-10-05): before bedtime HAKU carries shampoo and a rubber duck
// out of the frame; a tap switches to drying its hair.
extension RunnerPose {
    /// How long one bath call loop lasts: the line, the walk out and a short wait off screen.
    static let bathCallLength: CGFloat = 6
    /// How long drying the hair lasts after a tap.
    static let bathDryLength: TimeInterval = 4

    /// Calling Mike to the bath at `time` seconds: stands for the line, walks off to the right, then comes back.
    mutating func callToBath(time t: CGFloat) {
        let c = loop(t, Self.bathCallLength)
        bathCall = c
        let w = max(0, c - 1.8)
        let away = min(w / 2.4, 1)
        let walking = c > 1.8 && c < 4.2
        let step = walking ? abs(sin(w * .pi / 0.4)) : 0
        shift = 90 * away * away
        lean = walking ? 5 : 0
        bounce = -2 * step
        headDy += 2 * step
        presence = c > 5.6 ? Double((c - 5.6) / 0.4) : 1
        if c > 5.6 { shift = 0 }
    }

    /// Drying the hair `time` seconds after the tap: both hands rub the towel and water flicks off.
    mutating func dryHair(time t: CGFloat) {
        bathDry = t
        headDy += abs(sin(t * 9))
    }
}

extension SceneMove {
    /// The move of a bath part while calling (`call` seconds into the loop) or drying (`dry` seconds after the
    /// tap), or nil when `part` isn't one or neither plays.
    static func bath(_ part: RunnerPart, call: CGFloat, dry: CGFloat, shift: CGFloat) -> SceneMove? {
        var move = SceneMove()
        if call >= 0, part == .bathBubbles {
            let b = frac(call / 1.5)
            // The bubbles stay behind as HAKU walks off.
            move.offset = CGSize(width: -0.6 * shift, height: -14 * b)
            move.opacity = call > 1.8 ? Double(1 - b) : 0
            return move
        }
        guard dry >= 0 else { return nil }
        let a = sin(dry * 9)
        let box = RunnerArt.bounds
        let towelAnchor = UnitPoint(x: (60 - box.minX) / box.width, y: (40 - box.minY) / box.height)
        switch part {
        case .rubTowelL: move.offset.height = 3 * a
        case .rubTowelR: move.offset.height = -3 * a
        case .bathTowel:
            move.angle = 2.5 * Double(a)
            move.anchor = towelAnchor
        case .headSteam:
            let s = frac(dry / 1.6)
            move.offset.height = -4 * s
            move.opacity = Double(sin(s * .pi))
        case .dropsL, .dropsR:
            let f = frac(dry / 0.9)
            let left = Int(dry / 0.9) % 2 == 0
            move.offset = CGSize(width: (part == .dropsL ? -8 : 8) * f, height: -3 * f)
            move.opacity = left == (part == .dropsL) ? Double(1 - f) : 0
        default:
            return nil
        }
        return move
    }
}

// Getting up from the sofa (Mike approved the preview 2026-10-06): after long couch scrolling, as the bath or
// vibe coding starts, HAKU drops the phone, stretches and pulls the mask up.
extension RunnerPose {
    /// How long getting up from the sofa lasts, in seconds.
    static let reviveLength: CGFloat = 7
    /// Seconds in when the eyes open.
    static let reviveWake: CGFloat = 1.7
    /// Seconds in when the dropped phone is gone.
    static let revivePhoneGone: CGFloat = 1.9
    /// Seconds in when the sofa has slid out of view.
    static let reviveSofaGone: CGFloat = 3
    /// Seconds in when HAKU says its line.
    static let reviveLine: CGFloat = 5.3

    /// Getting up from the sofa `time` seconds in: slumped scrolling, the phone drops, a stretch with the arms
    /// over the head and the eyes shut, then the mask comes up from the chin and the </> lights.
    static func revive(time t: CGFloat, face: EnergyFace) -> RunnerPose {
        var pose = RunnerPose(face: face)
        pose.revive = t
        let sit = 1 - ease(ramp(t, from: 2, to: 2.8))
        pose.stretch = ease(ramp(t, from: 2, to: 2.7)) * (1 - ease(ramp(t, from: 4.2, to: 4.8)))
        pose.armsUp = ramp(t, from: 2.7, to: 3.5) * (1 - ramp(t, from: 4, to: 4.5))
        pose.bounce = (4 + sin(t * 1.25)) * sit
        pose.lean = -3 * Double(sit)
        pose.headDy = 6 * sit - 2 * bump(t, from: 2.9, to: 4.4)
        pose.eyesShut = t > 2.9 && t < 4.4
        pose.maskDrop = 1 - ease(ramp(t, from: 4.6, to: 5.2))
        pose.feed = frac(t * 0.8)
        return pose
    }
}

extension SceneMove {
    /// The move of the phone or the sofa `t` seconds into getting up, or nil when `part` isn't one or HAKU
    /// isn't getting up.
    static func revive(_ part: RunnerPart, at t: CGFloat) -> SceneMove? {
        guard t >= 0 else { return nil }
        var move = SceneMove()
        let box = RunnerArt.bounds
        switch part {
        case .phone, .phoneFeed, .phoneHand:
            let drop = ease(RunnerPose.ramp(t, from: 1.4, to: 1.9))
            move.offset.height = 30 * drop - (part == .phoneFeed ? 5 * frac(t * 0.8) : 0)
            move.angle = 25 * Double(drop)
            move.anchor = UnitPoint(x: (59 - box.minX) / box.width, y: (104 - box.minY) / box.height)
            move.opacity = Double(1 - drop)
        case .sofaArm:
            move.offset.height = 24 * ease(RunnerPose.ramp(t, from: 2.2, to: 3))
        default:
            return nil
        }
        return move
    }
}

// Coming back after days away (Mike approved the preview 2026-10-07, Issue #177): HAKU looks up from the
// phone, or dozes, sits up, turns the phone face down and pushes over a crate whose cans open together. With
// nothing recorded it scoots over and pats the seat.
/// What HAKU acts out when Mike comes back after days away.
enum WelcomeScene: Sendable {
    /// A short absence: a look up from the phone on the sofa.
    case glance
    /// A long absence: dozing on the sofa under the blanket, then the crate.
    case sofa
    /// A long absence in work mode: dozing at the desk with the headset on, then the crate.
    case desk
    /// Nothing recorded: HAKU scoots over and pats the seat.
    case quiet

    /// The scene for `replay` while in `mode`.
    init(_ replay: ReturnReplay, mode: Mode) {
        if replay.isQuiet {
            self = .quiet
        } else if replay.tier == .glance {
            self = .glance
        } else {
            self = mode == .work ? .desk : .sofa
        }
    }

    /// Whether HAKU pushes over the crate.
    var crate: Bool { self == .sofa || self == .desk }

    /// Seconds in when the first card flips over.
    var firstCard: CGFloat { crate ? 6 : 2.4 }

    /// Seconds in when HAKU says its line, and how long the bubble stays.
    var line: (at: Double, hold: Double) {
        switch self {
        case .glance: (1.7, 2.5)
        case .sofa, .desk: (3, 1.7)
        case .quiet: (3.6, 3)
        }
    }

    /// Seconds in when the crate opens after `cards` cards, or nil when there are no cans to open.
    func open(cards: Int, cans: Int) -> CGFloat? {
        guard crate, cans > 0 else { return nil }
        return firstCard + CGFloat(cards) * Self.cardGap + 0.2
    }

    /// How long the scene lasts with `cards` cards and `cans` cans, in seconds.
    func length(cards: Int, cans: Int) -> CGFloat {
        if self == .quiet { return 7.5 }
        if let open = open(cards: cards, cans: cans) { return open + 3.3 }
        return firstCard + CGFloat(cards) * Self.cardGap + 3
    }

    /// The card showing `time` seconds in, as an index into `count` cards, or nil before the first one and
    /// once the crate opens.
    func card(at time: CGFloat, count: Int, open: CGFloat?) -> Int? {
        guard count > 0, time >= firstCard, time < open ?? .infinity else { return nil }
        return min(Int((time - firstCard) / Self.cardGap), count - 1)
    }

    /// Seconds between two cards.
    static let cardGap: CGFloat = 1.1
    /// Seconds after the crate opens when the cans chip shows.
    static let cansChip: CGFloat = 0.7
}

extension RunnerPose {
    /// What the welcome back scene shows besides HAKU.
    struct Welcome {
        var scene: WelcomeScene
        /// At the desk with the headset on instead of on the sofa under the blanket.
        var atDesk = false
        /// Seconds into the scene.
        var time: CGFloat
        /// Eyes open; before that they are sleepy.
        var awake = false
        /// How far the phone and the hands holding it have dropped, in SVG units.
        var phoneDrop: CGFloat = 0
        /// 0 = phone screen up, 1 = turned face down.
        var phoneFlip: CGFloat = 0
        /// How far the crate has slid in: 0 = off to the right, 1 = in front, -1 = hidden.
        var crate: CGFloat = -1
        /// 0 = flaps shut, 1 = folded open.
        var crateOpen: CGFloat = 0
        /// Whether the cans have popped up out of the crate.
        var cansOut = false
        /// How far the cans sit below their pile, in SVG units.
        var canSink: CGFloat = 0
        /// Opacity of the sparkles over the open crate.
        var glow: Double = 0
        /// Height of the hand patting the seat, 0...1, or -1 when it isn't patting.
        var pat: CGFloat = -1
    }

    /// HAKU `time` seconds into `scene`; the crate opens at `open`, or stays shut when nil. In `mode` work the
    /// glance and the quiet scene play at the desk.
    static func welcome(
        _ scene: WelcomeScene, time t: CGFloat, open: CGFloat?, face: EnergyFace, mode: Mode = .chill
    ) -> RunnerPose {
        var pose = RunnerPose(face: face)
        // HAKU-17 (UI 审核 2026-10-08): opening the app at the office showed the sofa and blanket.
        var w = Welcome(scene: scene, atDesk: scene == .desk || mode == .work, time: t)
        pose.feed = frac(t * 0.8)
        let slump = 5 + sin(t * 1.2)
        switch scene {
        case .glance:
            let look = ease(ramp(t, from: 1.2, to: 1.6))
            pose.bounce = slump * (1 - 0.4 * look)
            pose.lean = -3 * Double(1 - 0.4 * look)
            pose.headDy = 4 - 6 * look
            w.phoneDrop = 6 * look
            w.awake = t >= 1.3
        case .sofa, .desk:
            let desk = scene == .desk
            let up = ease(ramp(t, from: 2.4, to: 2.9))
            let doze = 1 - ease(ramp(t, from: 1.5, to: 1.7))
            let twitch = t > 1.5 && t < 1.8 ? 2.5 * sin(t * 90) : 0
            let push = bump(t, from: 4.4, to: 5.9)
            pose.bounce = slump * (1 - up) - 2 * up
            pose.lean = -3 * Double(1 - up) + 6 * Double(push)
            pose.shift = 6 * push
            pose.headDy = ((desk ? 10 : 6) * doze + 2 * (1 - doze)) * (1 - up) - 3 * bump(t, from: 1.5, to: 2.2)
            pose.headTilt = Double(twitch + (desk ? 8 : 4) * doze)
            pose.eyesShut = t < 1.55 && loop(t, 2.4) < 0.9
            w.awake = t >= 1.55
            w.phoneFlip = ease(ramp(t, from: 2.5, to: 2.9))
            if t >= 4.6 { w.crate = ease(ramp(t, from: 4.6, to: 5.6)) }
            if let open {
                w.crateOpen = ease(ramp(t, from: open, to: open + 0.5))
                let pop = ease(ramp(t, from: open + 0.3, to: open + 1.1))
                w.cansOut = pop > 0
                w.canSink = 26 * (1 - pop) - 10 * bump(t, from: open + 0.3, to: open + 1.4)
                w.glow = t > open + 0.8 ? Double(0.6 + 0.4 * abs(sin(t * 5))) : 0
            }
        case .quiet:
            let look = ease(ramp(t, from: 1.4, to: 1.8))
            let scoot = ease(ramp(t, from: 2.1, to: 2.9))
            pose.shift = -18 * scoot
            pose.bounce = slump * (1 - 0.6 * look) + 2 * bump(t, from: 2.1, to: 2.9)
            pose.lean = -3 * Double(1 - look)
            pose.headDy = 4 - 6 * look
            w.awake = t >= 1.5
            w.phoneDrop = 14 * ease(ramp(t, from: 2.9, to: 3.2))
            if t > 3.2 { w.pat = abs(sin((t - 3.2) * .pi * 2.2)) }
        }
        pose.welcome = w
        return pose
    }
}

extension SceneMove {
    /// The move of the phone, the hands holding it or the furniture in the welcome back scene, or nil when
    /// `part` isn't one.
    static func welcome(_ part: RunnerPart, pose: RunnerPose) -> SceneMove? {
        guard let w = pose.welcome else { return nil }
        var move = SceneMove()
        let box = RunnerArt.bounds
        let anchor = { (x: CGFloat, y: CGFloat) in
            UnitPoint(x: (x - box.minX) / box.width, y: (y - box.minY) / box.height)
        }
        switch part {
        case .phone, .phoneFeed, .phoneBack:
            // Squashed flat halfway through the flip, then the back shows, lying on the lap.
            let f = w.phoneFlip
            move.offset.height = w.phoneDrop + 30 * f - (part == .phoneFeed ? 5 * pose.feed : 0)
            move.scaleY = abs(1 - 2 * f) * (1 - 0.4 * f) + 0.01
            move.anchor = anchor(59, 102)
            if part == .phoneFeed { move.opacity = Double(1 - 0.6 * pose.feed) }
        case .phoneHand:
            move.offset.height = w.phoneDrop + 22 * w.phoneFlip
            move.opacity = Double(1 - w.phoneFlip)
        case .sofaArm, .desk:
            // The furniture stays put while HAKU leans and scoots.
            move.offset = CGSize(width: -pose.shift, height: -pose.bounce)
            move.angle = -pose.lean
            move.anchor = anchor(60, 140)
        default:
            return nil
        }
        return move
    }
}

private func ease(_ x: CGFloat) -> CGFloat {
    x * x * (3 - 2 * x)
}
