import HubCore
import SwiftUI

extension Mode {
    /// Background color from the RUNNER v5 sheet.
    public var color: Color {
        switch self {
        case .work: Color(hex: 0x7FB7FF)
        case .chill: Color(hex: 0x8FDB9E)
        case .boxing: Color(hex: 0xFF7A6B)
        case .money: Color(hex: 0xFFD25C)
        }
    }

    public var symbol: String {
        switch self {
        case .work: "headphones"
        case .chill: "takeoutbag.and.cup.and.straw.fill"
        case .boxing: "figure.boxing"
        case .money: "yensign.circle.fill"
        }
    }

    /// The mode's color for `persona`: KURO's are her card colors from the approved preview.
    public func color(for persona: Persona) -> Color {
        persona == .kuro ? KuroLook(mode: self).color : color
    }

    // UI-32 (UI 审核 2026-10-08): KURO showed HAKU's headphones, can and yen sign.
    /// The SF Symbol for the mode as `persona` lives it: KURO's are her own props.
    public func symbol(for persona: Persona) -> String {
        guard persona == .kuro else { return symbol }
        switch self {
        case .work: return "ipad"
        case .chill: return "cup.and.saucer.fill"
        case .boxing: return "figure.tennis"
        case .money: return "pencil.and.ruler.fill"
        }
    }

    // The only place the Swift-to-Rive mode mapping lives (see Rive 搭建步骤).
    /// Value of the Rive view model `mode` enum.
    var riveValue: String {
        switch self {
        case .work: "work"
        case .chill: "chill"
        case .boxing: "box"
        case .money: "money"
        }
    }
}
