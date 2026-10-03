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
        case .money: "MONEY"
        }
    }

    public var tagline: String {
        switch self {
        case .work: "死人眼上线，耳机戴好"
        case .chill: "面罩拉下，开一罐 Monster"
        case .boxing: "头带系紧，今天打谁"
        case .money: "¥¥ 模式，搞钱"
        }
    }
}
