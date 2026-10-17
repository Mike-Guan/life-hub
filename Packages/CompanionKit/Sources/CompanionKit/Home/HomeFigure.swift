#if os(iOS) || os(macOS)
import SpriteKit

// Mike 2026-10-17: both preset characters have a home. They share the room, its spots and its rules; each draws
// her own figure. Clothes are dressed per character, outside `apply`.
/// A character's full-body figure in the home scene.
@MainActor
protocol HomeFigure: SKNode {
    /// Poses the figure for time `t`.
    func apply(_ pose: HakuPose, face: HakuFace, facingRight: Bool, gloves: Bool, t: TimeInterval)
    /// The middle of the bar the figure presses, in the coordinates of its parent.
    var barCenter: CGPoint { get }
    /// Where the middle of the phone or tablet the figure holds is, in the coordinates of its parent; `nil` when
    /// she holds none.
    var heldPhone: CGPoint? { get }
    /// The middle of the figure's face, in the coordinates of its parent.
    var faceCenter: CGPoint { get }
    /// The figure's shadow on the floor.
    var shadow: SKSpriteNode { get }
}

extension HakuNode: HomeFigure {}
#endif
