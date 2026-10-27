import AVFoundation
import HubCore

// Plan: energy-bank/03 Product/音效与家的音乐 v0.md. The ambient session follows the silent switch and mixes with
// whatever the user is listening to, so a tap never stops their music.
/// Plays the short tap sounds and 家's music, quietly.
@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    private static let effectsVolume: Float = 0.6
    private static let musicVolume: Float = 0.35
    // Taps on the same sound closer than this play it once.
    private static let minGap: TimeInterval = 0.12

    private var players: [SoundCue: AVAudioPlayer] = [:]
    private var lastPlayed: [SoundCue: Date] = [:]
    private var music: AVAudioPlayer?
    private var fadeOut: Task<Void, Never>?

    private init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
        } catch {
            Dogfood.note("sound", "声音设置失败：\(error.localizedDescription)")
        }
    }

    /// Plays `cue` unless the user turned sounds off or it just played.
    func play(_ cue: SoundCue) {
        guard SoundSettings.stored(in: AppGroup.defaults).effects else { return }
        let now = Date.now
        if let last = lastPlayed[cue], now.timeIntervalSince(last) < Self.minGap { return }
        lastPlayed[cue] = now
        guard let player = player(for: cue) else { return }
        player.currentTime = 0
        player.play()
    }

    /// Fades 家's music in, when the settings, the bedtime and other audio allow it.
    func startHomeMusic(bedtime: Bedtime) {
        let otherAudio = AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
        guard SoundSettings.stored(in: AppGroup.defaults).playsHomeMusic(bedtime: bedtime, otherAudio: otherAudio),
            let music = musicPlayer()
        else { return }
        fadeOut?.cancel()
        if !music.isPlaying {
            music.volume = 0
            music.play()
        }
        music.setVolume(Self.musicVolume, fadeDuration: 1.2)
    }

    /// Fades 家's music out and pauses it.
    /// - Parameter now: pauses at once, for leaving the app.
    func stopHomeMusic(now: Bool = false) {
        guard let music, music.isPlaying else { return }
        fadeOut?.cancel()
        if now {
            music.pause()
            return
        }
        music.setVolume(0, fadeDuration: 0.6)
        fadeOut = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.6))
            guard !Task.isCancelled else { return }
            self?.music?.pause()
        }
    }

    private func player(for cue: SoundCue) -> AVAudioPlayer? {
        if let player = players[cue] { return player }
        guard let player = load(cue.fileName, extension: "wav") else { return nil }
        player.volume = Self.effectsVolume
        players[cue] = player
        return player
    }

    private func musicPlayer() -> AVAudioPlayer? {
        if let music { return music }
        let player = load("home-loop", extension: "caf")
        player?.numberOfLoops = -1
        music = player
        return player
    }

    private func load(_ name: String, extension ext: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            Dogfood.note("sound", "缺声音文件 \(name).\(ext)")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            Dogfood.note("sound", "\(name) 打不开：\(error.localizedDescription)")
            return nil
        }
    }
}
