import Foundation

/// The situation a HAKU line is picked for.
public enum LineScene: String, CaseIterable, Sendable {
    case work
    case chill
    case boxing
    case money
    case couchScroll
    case boxingWarmup
    case bedtime
    case lowEnergy
}

// Persona spec: 03 Product/companion/RUNNER 人设.md. Rules pick the line (T0); no model is used.
// Lock-screen lines stay around 14 characters and never name an app.
/// HAKU's short lines for the Lock Screen and widgets.
public enum HakuLines {
    /// Lines per scene, in rotation order.
    public static let library: [LineScene: [String]] = [
        .work: ["又上班。", "耳机戴上，灵魂下线。", "今天也在假装认真。", "摸鱼……不是，在工作。"],
        .chill: ["回来了？", "饭呢。", "瘫着呢，别叫我。", "你看你的。我就在这。", "喂。"],
        .boxing: ["今天手有点痒。", "来几组？", "……其实还挺想打的。"],
        .money: ["在数罐子。", "搞钱中，勿扰。", "今天也想变有钱。"],
        .couchScroll: ["再刷五分钟。", "……我们今天真不动了？", "要不就下楼？", "走到门口就算赢。"],
        .boxingWarmup: ["拳套我都戴好了，你随意啊。", "我热身热得都快累了。", "拳馆在等你。"],
        .bedtime: ["我先睡了。你也别熬。", "你不会又要和天花板开会吧。", "眼皮在打架。", "晚安。真的晚安。"],
        .lowEnergy: ["……别跟我说话。", "我也只睡了一点点。", "今天省电模式。"],
    ]

    // One line per scene per hub day, moving to the next each day, so a line only comes back
    // after all the others in its scene have had a day. No history to store, and widgets get the
    // same answer as the app.
    /// The line for `scene` on the hub day containing `date`.
    public static func line(_ scene: LineScene, at date: Date, calendar: Calendar = .current) -> String {
        let lines = library[scene] ?? []
        guard !lines.isEmpty else { return "" }
        let day = StateEngine.dayStart(for: date, calendar: calendar)
        let origin = Date(timeIntervalSinceReferenceDate: 0)
        let days = calendar.dateComponents([.day], from: origin, to: day).day ?? 0
        return lines[((days % lines.count) + lines.count) % lines.count]
    }

    /// The scene for HAKU's state: bedtime, then the need, then low energy, then the mode.
    /// - Returns: `nil` before any mode is set and with nothing else to say.
    public static func scene(
        mode: Mode?,
        need: CompanionNeed?,
        energy: EnergyLevel?,
        bedtime: Bedtime
    ) -> LineScene? {
        if bedtime == .on { return .bedtime }
        switch need {
        case .couchScroll: return .couchScroll
        case .boxingWarmup: return .boxingWarmup
        case nil: break
        }
        if energy == .low { return .lowEnergy }
        switch mode {
        case .work: return .work
        case .chill: return .chill
        case .boxing: return .boxing
        case .money: return .money
        case nil: return nil
        }
    }
}
