import Foundation

// Plan: energy-bank/03 Product/音效与家的音乐 v0.md. Every file is synthesised by scripts/make-sounds.py.
/// One short sound the app plays after a tap.
public enum SoundCue: String, CaseIterable, Sendable {
    case modeWork = "mode-work"
    case modeChill = "mode-chill"
    case modeMoney = "mode-money"
    /// The identity card (boxing, tennis, gym…) in the fourth slot.
    case modeCard = "mode-card"
    /// A tap that changes nothing, such as the card already on.
    case tap
    case buy
    case unbox
    case homeOpen = "home-open"
    /// A colour change on a room item in 家.
    case place

    /// The file name in the app bundle, without its extension.
    public var fileName: String { rawValue }

    /// The sound for a tap on a mode card.
    /// - Parameter changed: whether the tap switched the mode; a tap on the card already on only ticks.
    public static func forMode(_ mode: Mode, changed: Bool) -> SoundCue {
        guard changed else { return .tap }
        switch mode {
        case .work: return .modeWork
        case .chill: return .modeChill
        case .money: return .modeMoney
        case .boxing: return .modeCard
        }
    }
}

/// The two sound switches in Settings. Both start on; the silent switch still mutes everything on iPhone.
public struct SoundSettings: Equatable, Sendable {
    public var effects: Bool
    public var homeMusic: Bool

    public init(effects: Bool = true, homeMusic: Bool = true) {
        self.effects = effects
        self.homeMusic = homeMusic
    }

    static let effectsKey = "soundEffectsOff"
    static let musicKey = "homeMusicOff"

    // Stored as "off" so a missing key reads as on.
    /// The switches saved in `defaults`.
    public static func stored(in defaults: UserDefaults) -> SoundSettings {
        SoundSettings(effects: !defaults.bool(forKey: effectsKey), homeMusic: !defaults.bool(forKey: musicKey))
    }

    /// Saves the switches to `defaults`.
    public func store(in defaults: UserDefaults) {
        defaults.set(!effects, forKey: Self.effectsKey)
        defaults.set(!homeMusic, forKey: Self.musicKey)
    }

    /// Whether 家's music plays.
    /// - Parameters:
    ///   - bedtime: the bedtime overlay now; the room is quiet while the character sleeps.
    ///   - otherAudio: whether another app is playing audio the user started.
    public func playsHomeMusic(bedtime: Bedtime, otherAudio: Bool) -> Bool {
        homeMusic && bedtime == .off && !otherAudio
    }
}
