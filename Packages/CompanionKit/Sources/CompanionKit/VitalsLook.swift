import CoreGraphics
import HubCore

// PRD section 19: the hidden params only change how HAKU moves and looks, never with a number or a bar.
// 体能 (stamina) sets posture, bounce and how often HAKU trains on its own; 元气 (spirit) sets speed
// and colour.
extension HakuVitals {
    /// How fast HAKU's idle motion runs: half a beat slow on low spirit.
    var motionSpeed: Double {
        switch spirit {
        case .low: 0.8
        case .mid: 1
        case .high: 1.15
        }
    }

    /// How big HAKU's idle bounce is.
    var bounce: CGFloat {
        switch stamina {
        case .low: 0.8
        case .mid: 1
        case .high: 1.3
        }
    }

    /// How far the head sinks, in SVG units: lounging on low stamina, upright on high.
    var slouch: CGFloat {
        switch stamina {
        case .low: 1.5
        case .mid: 0
        case .high: -1
        }
    }

    /// Colour saturation of the figure: a little washed out on low spirit.
    var saturation: Double { spirit == .low ? 0.8 : 1 }

    /// Extra brightness of the figure on high spirit.
    var brightness: Double { spirit == .high ? 0.03 : 0 }
}
