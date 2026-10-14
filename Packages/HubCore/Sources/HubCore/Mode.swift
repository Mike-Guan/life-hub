import Foundation

// Separate from energy/state on purpose (see CLAUDE.md, "Core model rules").
/// What Mike is doing right now.
public enum Mode: String, Codable, CaseIterable, Identifiable, Sendable {
    case work
    case chill
    case boxing
    case money

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .work: "上班"
        case .chill: "下班 Chill"
        case .boxing: "拳击日"
        case .money: "副业"
        }
    }

    public var code: String {
        switch self {
        case .work: "WORK"
        case .chill: "CHILL"
        case .boxing: "BOXING"
        case .money: "SIDE"
        }
    }

    public var tagline: String {
        switch self {
        case .work: "耳机戴上，开工"
        case .chill: "开一罐能量饮料"
        case .boxing: "头带系紧"
        case .money: "自己的事，开工"
        }
    }
}
