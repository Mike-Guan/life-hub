import HubCore
import SwiftUI

// Scene library v0 (Mike approved the preview 2026-10-05). Each scene replaces the Daily prop with its own
// props and a short loop; the timings follow the preview page.
extension DailyScene {
    /// The parts HAKU shows for this scene.
    var parts: Set<RunnerPart> {
        switch self {
        case .coffee: [.coffeeSteam, .blowLines, .coffeeCup]
        case .meal: [.riceBowl, .chopsticks]
        case .meeting: [.screenGlow, .macbook, .typeHandL, .typeHandR]
        case .call: [.phoneEar, .talkDots]
        case .grocery: [.toteBag]
        case .shopping: [.shopShine, .paperBagL, .paperBagR]
        case .cook: [.apron, .spatula]
        case .gym: [.gymBag, .dumbbell]
        case .run: [.speedLines, .walkDust]
        case .stroll: [.sunIcon, .walkDust, .earbud]
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
        case (.meal, .chopsticks):
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
        case (.run, .walkDust), (.stroll, .walkDust):
            let p = frac(t * (scene == .run ? 1.9 : 0.6) / 0.9)
            move.offset = CGSize(width: -10 * p, height: -4 * p)
            move.scale = 0.6 + 0.6 * p
            move.anchor = anchor(22, 128)
            move.opacity = Double(1 - p)
        case (.stroll, .sunIcon):
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

extension RunnerPose {
    /// HAKU's head and body in `scene` at `time` seconds, eased in by `propRaise`.
    mutating func playScene(_ scene: DailyScene, time t: CGFloat) {
        let r = propRaise
        switch scene {
        case .meal:
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
        case .run, .stroll:
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
