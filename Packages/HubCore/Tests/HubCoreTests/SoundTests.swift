import Foundation
import Testing

@testable import HubCore

@Suite struct SoundTests {
    @Test func eachModeHasItsOwnSound() {
        let cues = Mode.allCases.map { SoundCue.forMode($0, changed: true) }
        #expect(cues == [.modeWork, .modeChill, .modeCard, .modeMoney])
        #expect(Set(cues).count == Mode.allCases.count)
    }

    @Test func aTapThatChangesNothingOnlyTicks() {
        for mode in Mode.allCases {
            #expect(SoundCue.forMode(mode, changed: false) == .tap)
        }
    }

    @Test func everyCueHasAFileInTheApp() {
        let sounds = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "../../../../Apps/iOS/Sounds")
            .standardizedFileURL
        for cue in SoundCue.allCases {
            let file = sounds.appending(path: "\(cue.fileName).wav")
            #expect(FileManager.default.fileExists(atPath: file.path), "\(file.path)")
        }
        #expect(FileManager.default.fileExists(atPath: sounds.appending(path: "home-loop.caf").path))
    }

    @Test func bothSwitchesStartOnAndRoundTrip() throws {
        let defaults = try #require(UserDefaults(suiteName: "sound-\(UUID().uuidString)"))
        #expect(SoundSettings.stored(in: defaults) == SoundSettings())
        SoundSettings(effects: false, homeMusic: true).store(in: defaults)
        #expect(SoundSettings.stored(in: defaults) == SoundSettings(effects: false, homeMusic: true))
        SoundSettings(effects: true, homeMusic: false).store(in: defaults)
        #expect(SoundSettings.stored(in: defaults) == SoundSettings(effects: true, homeMusic: false))
    }

    @Test func homeMusicStaysQuietAtBedtimeOrOverOtherAudio() {
        let on = SoundSettings()
        #expect(on.playsHomeMusic(bedtime: .off, otherAudio: false))
        #expect(!on.playsHomeMusic(bedtime: .on, otherAudio: false))
        #expect(!on.playsHomeMusic(bedtime: .off, otherAudio: true))
        #expect(!SoundSettings(homeMusic: false).playsHomeMusic(bedtime: .off, otherAudio: false))
    }
}
