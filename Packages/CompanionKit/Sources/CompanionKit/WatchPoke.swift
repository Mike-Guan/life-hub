import HubCore
import SwiftUI

// Approved Apple Watch preview (Issue #160): a poke never switches the mode, gives cans or counts anything.
/// HAKU's body move when tapped, the same on the phone and the Apple Watch.
enum WatchPoke: Sendable, Equatable, CaseIterable {
    /// A startled hop, then a glare.
    case glare
    /// One headset cup pushed up.
    case headsetUp
    /// The can held out to clink the screen.
    case clink
    /// A punch toward the screen.
    case punch
    /// The mask flashes `</>`.
    case codeFlash
    /// Rolling over and sleeping on.
    case rollOver

    /// How long one reaction plays, in seconds.
    static let duration: TimeInterval = 1.6
    /// Pokes within `CompanionView.pesterWindow` that make HAKU turn its back.
    static let tooMany = 5
    /// What HAKU says as it turns its back.
    static let tooManyLine = "……够了。"
    /// How long HAKU keeps its back turned, turning included, in seconds.
    static let turnAwayDuration: TimeInterval = 3.6

    /// The reaction for HAKU in `mode`.
    /// - Parameters:
    ///   - energy: energy 0-100, or nil when unknown; below 30 HAKU rolls over.
    ///   - asleep: bedtime or a nap; HAKU rolls over.
    ///   - busy: HAKU acts out a need, activity, moment or task instead of the plain mode.
    static func pick(mode: Mode, energy: Double?, asleep: Bool, busy: Bool) -> WatchPoke {
        if asleep || EnergyFace(energy: energy) == .low { return .rollOver }
        if busy { return .glare }
        switch mode {
        case .work: return .headsetUp
        case .chill: return .clink
        case .boxing: return .punch
        case .money: return .codeFlash
        }
    }

    /// What HAKU says, or nil for a silent reaction.
    var line: String? {
        switch self {
        case .glare: "……干嘛。"
        case .headsetUp: "在上班。"
        case .clink: "叮。"
        case .punch, .codeFlash, .rollOver: nil
        }
    }

    /// How far the reaction is held out at `progress` (0...1): quick out, held, then back by 0.85.
    static func hold(_ progress: CGFloat) -> CGFloat {
        RunnerPose.ramp(progress, from: 0, to: 0.15) * (1 - RunnerPose.ramp(progress, from: 0.6, to: 0.85))
    }
}

extension RunnerPose {
    /// Reacting to a watch poke at `progress` (0...1). Rolling over moves the whole figure, so `IdleMotion`
    /// plays it.
    mutating func poke(_ kind: WatchPoke, progress: Double) {
        let p = CGFloat(min(max(progress, 0), 1))
        let out = WatchPoke.hold(p)
        pokeKind = kind
        pokeProgress = p
        switch kind {
        case .glare:
            if p < 0.25 {
                bounce -= 6 * sin(p / 0.25 * .pi)
                blink = 1
            } else {
                blink = min(blink, 0.6)
                headTilt -= 4 * Double(RunnerPose.ramp(p, from: 0.25, to: 0.4))
            }
        case .headsetUp:
            cupRUp = out
            eyesDx += 2 * out
        case .clink:
            canAngle = Double(-20 * out)
            canOffset = CGSize(width: -30 * out, height: -28 * out)
            canScale = 1 + 0.55 * out
        case .punch:
            gloveR = CGSize(width: -26 * out, height: -28 * out)
            gloveRScale = 1 + 1.3 * out
            lean += 4 * Double(out)
        case .codeFlash:
            ledFlare = max(ledFlare, out)
        case .rollOver:
            break
        }
    }
}

extension RunnerFigure {
    /// Swaps the parts a watch poke changes: glaring eyes, the `</>` LED, impact lines by the punch.
    nonisolated static func poked(_ visible: inout Set<RunnerPart>, pose: RunnerPose) {
        guard let poke = pose.pokeKind, pose.pokeProgress >= 0, !pose.bedtime else { return }
        let out = WatchPoke.hold(pose.pokeProgress)
        switch poke {
        case .glare:
            visible.subtract(glareHides)
            visible.formUnion([.eyesWork, .lidsWork, .browsWork])
            if pose.pokeProgress < 0.3 { visible.insert(.ouchLines) }
        case .codeFlash where out > 0.05 && visible.contains(.ledYen):
            visible.remove(.ledYen)
            visible.formUnion([.ledCode, .codeBits])
        case .punch where out > 0.5 && visible.contains(.gloveR):
            visible.insert(.thumpLines)
        default:
            break
        }
    }

    nonisolated private static let glareHides: Set<RunnerPart> = [
        .eyesChill, .cateyeL, .cateyeR, .eyesMoney, .eyesSleepy, .eyeGlint, .browsBox, .mouthSmile,
    ]
}
