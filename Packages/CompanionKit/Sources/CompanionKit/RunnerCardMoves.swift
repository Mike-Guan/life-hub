import CoreGraphics
import Foundation
import HubCore

// Owned by UI 四组 (协作看板 2026-10-14): the idles and props for the identity cards other than boxing,
// on top of the base outfits in `CardLook`.
extension RunnerPose {
    /// Moves the fourth slot for `kind` wearing `look` at `t` seconds; `r` runs 0 → 1 → 0 after a tap.
    mutating func cardIdle(_ look: CardLook, kind: IdentityKind, time t: TimeInterval, react r: CGFloat) {}
}

extension RunnerFigure {
    /// Adds the props and parts the fourth slot shows for `kind` wearing `look`.
    nonisolated static func cardParts(
        _ look: CardLook, kind: IdentityKind, pose: RunnerPose, into visible: inout Set<RunnerPart>
    ) {}
}
