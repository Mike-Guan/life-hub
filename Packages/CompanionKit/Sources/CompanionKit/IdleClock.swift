import Foundation

// HAKU-20 / KURO-12 (UI 审核 2026-10-08): fixed-period loops read as a metronome. Each idle rhythm
// is cut into cells and every cell gets its own seeded jitter, so nothing repeats on a cycle, yet the
// same instant always draws the same frame (frame sheets, widgets and the app agree).
/// Seeded idle timing: blinks, nods and occasional beats with no fixed cycle.
enum IdleClock {
    /// One beat from a pool: which `kind` plays, how far into it `phase` is, in seconds, and a
    /// `variant` in 0..<1 that stays fixed for the beat (a side, a size).
    struct Beat: Equatable {
        var kind: Int
        var phase: TimeInterval
        var variant: Double
    }

    /// Mean gap between blinks, in seconds.
    static let blinkCell: TimeInterval = 4.25
    /// How far a blink may land from the start of its cell, either way, in seconds.
    static let blinkJitter: TimeInterval = 0.875
    /// Share of blinks followed by a second one.
    static let doubleBlinkShare = 0.15
    /// Gap from a blink to its double, in seconds.
    static let doubleBlinkGap: TimeInterval = 0.3
    /// Length of one blink, in seconds.
    static let blinkLength: TimeInterval = 0.16
    /// Share of nod beats held still.
    static let heldNodShare = 0.125

    /// A value in 0..<1 for cell `n` of the stream `seed`.
    static func noise(_ n: Int, seed: UInt64) -> Double {
        // SplitMix64.
        var z = (UInt64(bitPattern: Int64(n)) ^ (seed &* 0xD6E8_FEB8_6659_FD93)) &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(UInt64(1) << 53)
    }

    /// Eyelid openness at `t`: 1 open, 0.1 shut. Blinks land 2.5-6 s apart; about 15% come in pairs.
    static func blink(at t: TimeInterval, seed: UInt64) -> CGFloat {
        let n = Int((t / blinkCell).rounded(.down))
        var open: CGFloat = 1
        for cell in n...(n + 1) {
            let start = Double(cell) * blinkCell + (noise(cell, seed: seed) * 2 - 1) * blinkJitter
            open = min(open, lid(t - start))
            if noise(cell, seed: seed &+ 1) < doubleBlinkShare {
                open = min(open, lid(t - start - doubleBlinkGap))
            }
        }
        return open
    }

    /// A nod to the beat at `t`, 0 (up) to about 1 (down): eased down and up once per `period`,
    /// each beat a little deeper or shallower, about one in eight held still.
    static func nod(at t: TimeInterval, period: TimeInterval, seed: UInt64) -> CGFloat {
        let n = Int((t / period).rounded(.down))
        guard noise(n, seed: seed &+ 2) >= heldNodShare else { return 0 }
        return CGFloat(0.8 + 0.4 * noise(n, seed: seed &+ 3)) * dip(CGFloat(t / period - Double(n)))
    }

    /// One eased nod over `p` (0...1): quickly down, slowly back up; 0 at both ends.
    static func dip(_ p: CGFloat) -> CGFloat {
        let down: CGFloat = 0.35
        guard p > 0, p < 1 else { return 0 }
        return p < down ? smooth(p / down) : 1 - smooth((p - down) / (1 - down))
    }

    /// The pool beat playing at `t`, if any. Beats start `every` ± `spread` s apart (8-20 s by
    /// default); each picks one of `lengths.count` kinds and lasts that kind's length.
    static func beat(
        at t: TimeInterval,
        every: TimeInterval = 14,
        spread: TimeInterval = 3,
        lengths: [TimeInterval],
        seed: UInt64
    ) -> Beat? {
        guard !lengths.isEmpty else { return nil }
        let n = Int((t / every).rounded(.down))
        for cell in (n - 1)...(n + 1) {
            let start = Double(cell) * every + (noise(cell, seed: seed &+ 4) * 2 - 1) * spread
            let kind = min(lengths.count - 1, Int(noise(cell, seed: seed &+ 5) * Double(lengths.count)))
            let phase = t - start
            if phase >= 0, phase < lengths[kind] {
                return Beat(kind: kind, phase: phase, variant: noise(cell, seed: seed &+ 6))
            }
        }
        return nil
    }

    private static func lid(_ p: TimeInterval) -> CGFloat {
        guard p >= 0, p < blinkLength else { return 1 }
        return max(0.1, CGFloat(abs(p - blinkLength / 2) / (blinkLength / 2)))
    }

    private static func smooth(_ x: CGFloat) -> CGFloat {
        x * x * (3 - 2 * x)
    }
}
