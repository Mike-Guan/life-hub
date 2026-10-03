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

    var artName: String { "runner-\(rawValue)" }
}
