import HubCore
import SwiftUI

// Drawn like the approved preview 第1批 身份卡 (haku-1-底衣, haku-4-身份卡).
/// What HAKU wears for an identity card other than boxing.
enum RunnerCardLook: CaseIterable, Sendable {
    /// Sport base, a visor, a racket in the right hand and a ball.
    case tennis
    /// Sport base, the gym bag on the floor by the door and a small dumbbell in the right hand.
    case fitness
    /// Out base and an open book in both hands.
    case study
    /// Craft base, a sketchbook and a pencil.
    case art

    // The only place the card-to-look mapping lives, like `KuroLook(mode:card:)`.
    /// The look for `card`, or nil for boxing and for cards without a look yet, which keep the boxing kit.
    init?(card: IdentityKind?) {
        switch card {
        case .tennis: self = .tennis
        case .fitness: self = .fitness
        case .study: self = .study
        case .art: self = .art
        default: return nil
        }
    }

    /// Whether this look wears the sport base: the dark jacket with the orange stripe.
    var sporty: Bool { self == .tennis || self == .fitness }

    /// Every part of the look, figure included.
    var parts: Set<RunnerPart> {
        var parts = RunnerFigure.baseParts.union([.maskDown, .earringNeon])
        // The approved art look draws no mouth.
        if self != .art { parts.insert(.mouthSmile) }
        if sporty {
            parts.remove(.stripeNeon)
            parts.insert(.stripeSport)
        }
        switch self {
        case .tennis: parts.formUnion([.eyesChill, .tennisVisor, .tennisRacket, .racketHand, .tennisBall])
        case .fitness: parts.formUnion([.eyesChill, .handWeight])
        case .study: parts.formUnion([.eyesWork, .book, .bookPage])
        case .art: parts.formUnion([.eyesWork, .lidsWork, .browsWork, .apron, .sketchbook, .pencil])
        }
        return parts
    }

    /// What the look holds in its hands.
    var held: Set<RunnerPart> {
        switch self {
        case .tennis: [.tennisRacket, .racketHand, .tennisBall]
        case .fitness: [.handWeight]
        case .study: [.book, .bookPage]
        case .art: [.sketchbook, .pencil]
        }
    }

    /// What the look puts aside while HAKU does something else: what it holds, the visor and the apron.
    var props: Set<RunnerPart> { held.union([.tennisVisor, .apron]) }

    /// The jacket fill: dark for sport, the green off-work jacket for out and craft.
    var jacket: Color { sporty ? RunnerPalette.jacket : RunnerPalette.jacketChill }
}

extension RunnerPose {
    /// The same pose dressed for `card`, which only the identity card mode wears.
    func dressed(for card: IdentityKind?, in mode: Mode) -> RunnerPose {
        var pose = self
        pose.cardLook = mode == .boxing ? RunnerCardLook(card: card) : nil
        // The gym bag shows with `bagLift`; 0 keeps it on the floor by the door.
        if pose.cardLook == .fitness, pose.holdsCardProps, pose.bagLift < 0 { pose.bagLift = 0 }
        return pose
    }

    // Placement map: one thing per place. Whatever else HAKU holds, wears on the head or carries replaces the
    // card's props, the way the can goes away.
    /// Whether HAKU shows the card look's props: nothing else is in its hands, on its head or in the corner.
    var holdsCardProps: Bool {
        need == nil && activity == nil && life == nil && moment == nil && burst < 0 && dailyProp == nil
            && dailyScene == nil && walkFrom == nil && commuteLeg == nil && bathCall < 0 && bathDry < 0
            && thump < 0 && fistPump < 0 && !watchTap
    }
}
