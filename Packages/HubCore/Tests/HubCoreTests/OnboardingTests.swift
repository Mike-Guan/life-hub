import Foundation
import Testing

@testable import HubCore

@Suite struct OnboardingTests {
    private func defaults() throws -> (UserDefaults, String) {
        let suite = "OnboardingTests-\(UUID().uuidString)"
        return (try #require(UserDefaults(suiteName: suite)), suite)
    }

    @Test func skippingEverythingLeavesTheNotSetDefaults() throws {
        let (defaults, suite) = try defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        OnboardingDraft().apply(to: defaults)
        #expect(Persona.stored(in: defaults) == .haku)
        let cards = try #require(ModeCards.stored(in: defaults))
        #expect(cards.identity == nil && cards.modes == [.work, .chill, .money])
        #expect(cards.sideStates == [.project])
        #expect(ModeRules.stored(in: defaults).workdays.isEmpty)
        #expect(defaults.data(forKey: BedtimeSchedule.defaultsKey) == nil)
        #expect(!OnboardingDraft.isNeeded(in: defaults, existingInstall: false))
    }

    @Test func answersBecomeTheSettings() throws {
        let (defaults, suite) = try defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        var draft = OnboardingDraft()
        draft.persona = .kuro
        draft.chill = [.running]
        draft.identity = .tennis
        draft.bedtime = BedtimeSchedule(startMinute: 0, endMinute: 7 * 60)
        draft.work = .shown
        draft.sideStates = [.shooting, .writing]
        draft.names = [Mode.work.rawValue: "上学"]
        draft.apply(to: defaults)
        #expect(Persona.stored(in: defaults) == .kuro)
        let cards = try #require(ModeCards.stored(in: defaults))
        #expect(cards.identity == .tennis && cards.chill == [.running])
        #expect(cards.sideStates == [.shooting, .writing])
        #expect(cards.title(for: .work, persona: .kuro) == "上学")
        #expect(BedtimeSchedule.stored(in: defaults).startMinute == 0)
        let rules = ModeRules.stored(in: defaults)
        #expect(rules.workdays == [2, 3, 4, 5, 6] && rules.workStartMinute == 9 * 60 && rules.workEndMinute == 18 * 60)
        #expect(defaults.data(forKey: OnboardingDraft.defaultsKey) == nil)
    }

    @Test func leavingHalfwayPicksUpAtTheSameStep() throws {
        let (defaults, suite) = try defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(OnboardingDraft.isNeeded(in: defaults, existingInstall: false))
        var draft = OnboardingDraft.stored(in: defaults)
        draft.advance()
        draft.advance()
        draft.chill = [.walking]
        draft.advance()
        draft.store(in: defaults)
        let resumed = OnboardingDraft.stored(in: defaults)
        #expect(resumed.step == .identity && resumed.chill == [.walking])
        #expect(OnboardingDraft.isNeeded(in: defaults, existingInstall: false))
    }

    @Test func installsWithRecordsSkipTheSetup() throws {
        let (defaults, suite) = try defaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(!OnboardingDraft.isNeeded(in: defaults, existingInstall: true))
        #expect(!OnboardingDraft.isNeeded(in: defaults, existingInstall: false))
    }

    @Test func theStepsRunInOrderToDone() {
        var step = OnboardingDraft.Step.persona
        var seen = [step]
        while step != .done {
            step = step.next
            seen.append(step)
        }
        #expect(seen == OnboardingDraft.Step.allCases)
        #expect(OnboardingDraft.Step.done.next == .done && OnboardingDraft.Step.chill < .identity)
    }

    @Test func doingProjectsLooksLikeCoding() {
        #expect(SideHustle.project.title == "做项目" && SideHustle.project.moment == .vibeCoding)
    }

    @Test func withoutLocationTheMotionScreenIsSkipped() {
        var draft = OnboardingDraft()
        draft.step = .places
        draft.allowsLocation = false
        draft.advance()
        #expect(draft.step == .sideHustle)
        draft.step = .places
        draft.allowsLocation = true
        draft.advance()
        #expect(draft.step == .motion)
    }
}
