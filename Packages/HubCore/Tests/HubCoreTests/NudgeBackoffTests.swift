import Foundation
import Testing

@testable import HubCore

@Suite struct NudgeBackoffTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let parts = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? .distantPast
    }

    @Test func threeIgnoredInARowPauseThatInviteForAWeek() {
        var backoff = NudgeBackoff()
        backoff.record(.couchScroll, followed: false, sentAt: date(5, 21), now: date(5, 21, 40))
        backoff.record(.couchScroll, followed: false, sentAt: date(6, 21), now: date(6, 21, 40))
        #expect(!backoff.isPaused(.couchScroll, at: date(7, 12)))
        backoff.record(.couchScroll, followed: false, sentAt: date(7, 21), now: date(7, 21, 40))
        #expect(backoff.isPaused(.couchScroll, at: date(8, 21)))
        #expect(backoff.isPaused(.couchScroll, at: date(14, 21, 39)))
        #expect(!backoff.isPaused(.couchScroll, at: date(14, 21, 40)))
        // Other invites keep going.
        #expect(!backoff.isPaused(.gymDay, at: date(8, 20)))
        #expect(backoff.judgedSentAt == date(7, 21))
    }

    @Test func aFollowedInviteStartsTheCountAgain() {
        var backoff = NudgeBackoff()
        backoff.record(.gymDay, followed: false, sentAt: date(5, 20), now: date(5, 22))
        backoff.record(.gymDay, followed: false, sentAt: date(6, 20), now: date(6, 22))
        backoff.record(.gymDay, followed: true, sentAt: date(7, 20), now: date(7, 22))
        backoff.record(.gymDay, followed: false, sentAt: date(8, 20), now: date(8, 22))
        #expect(!backoff.isPaused(.gymDay, at: date(9, 20)))
        #expect(backoff.ignored["gymDay"] == 1)
    }

    @Test func hakuSaysItOnceOnThePauseDay() {
        var backoff = NudgeBackoff()
        #expect(backoff.notice(at: date(5, 22), calendar: calendar) == nil)
        backoff.pausedAt["slacking"] = date(5, 14)
        #expect(backoff.notice(at: date(5, 22), calendar: calendar) == "行，我不念了。")
        #expect(backoff.notice(at: date(6, 4), calendar: calendar) == "行，我不念了。")
        #expect(backoff.notice(at: date(6, 6), calendar: calendar) == nil)
    }

    @Test func couchInviteIsJudgedByWalkingAndScrolling() {
        let sent = date(5, 21)
        func followed(_ signals: NeedSignals, at now: Date) -> Bool? {
            NudgeBackoff.followed(.couchScroll, sentAt: sent, signals: signals, departedAt: nil, now: now)
        }
        #expect(followed(NeedSignals(stillSince: date(5, 20)), at: date(5, 21, 20)) == nil)
        #expect(followed(NeedSignals(stillSince: date(5, 20)), at: date(5, 21, 30)) == false)
        #expect(followed(NeedSignals(stillSince: date(5, 21, 25)), at: date(5, 21, 40)) == true)
        #expect(followed(NeedSignals(scrollSeenAt: date(5, 21, 35)), at: date(5, 21, 40)) == false)
        // Unknown stillness can't tell; a day later the signals describe another evening.
        #expect(followed(NeedSignals(), at: date(5, 21, 40)) == nil)
        #expect(followed(NeedSignals(stillSince: date(5, 20)), at: date(6, 12)) == nil)
        let walk = WorkoutSummary(id: "w", kind: .other, start: date(5, 21, 10), end: date(5, 21, 40))
        #expect(followed(NeedSignals(stillSince: date(5, 20), workouts: [walk]), at: date(6, 12)) == true)
    }

    @Test func gymInviteIsFollowedByGoingThere() {
        let sent = date(6, 20)
        func followed(_ signals: NeedSignals = NeedSignals(), departedAt: Date? = nil, at now: Date) -> Bool? {
            NudgeBackoff.followed(.gymDay, sentAt: sent, signals: signals, departedAt: departedAt, now: now)
        }
        #expect(followed(at: date(6, 21)) == nil)
        #expect(followed(at: date(6, 21, 30)) == false)
        #expect(followed(departedAt: date(6, 20, 5), at: date(6, 21, 30)) == true)
        #expect(followed(departedAt: date(5, 20, 5), at: date(6, 21, 30)) == false)
        #expect(followed(NeedSignals(fitnessSeenAt: date(6, 20, 40)), at: date(7, 9)) == true)
    }

    @Test func slackingIsFollowedWhenTheReportsStop() {
        let sent = date(5, 11)
        func followed(_ seen: Date?, at now: Date) -> Bool? {
            let signals = NeedSignals(slackThresholdAt: sent, slackSeenAt: seen)
            return NudgeBackoff.followed(.slacking, sentAt: sent, signals: signals, departedAt: nil, now: now)
        }
        #expect(followed(date(5, 11, 10), at: date(5, 11, 30)) == true)
        #expect(followed(date(5, 11, 30), at: date(5, 11, 35)) == false)
        #expect(followed(nil, at: date(5, 15)) == nil)
        let warmup = NudgeBackoff.followed(
            .boxingWarmup,
            sentAt: sent,
            signals: NeedSignals(),
            departedAt: nil,
            now: date(6, 1)
        )
        #expect(warmup == nil)
    }

    @Test func settlingTheLogKeepsWhichInviteWentOut() {
        let log = InviteLog(pendingAt: date(5, 21), pendingNeed: .couchScroll).settled(now: date(5, 21, 1))
        #expect(log.lastSentAt == date(5, 21))
        #expect(log.lastNeed == .couchScroll)
        #expect(log.pendingNeed == nil)
    }
}
