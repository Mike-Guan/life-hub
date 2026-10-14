import Foundation
import HubCore

/// What HAKU does on its own at home when nothing is needed.
enum IdleLife: CaseIterable, Sendable {
    /// Asleep in the sofa corner.
    case nap
    /// Playing a handheld console.
    case handheld
    /// Eating a snack, hidden when someone looks.
    case snack
    /// Drawing in a sketchbook, closed when someone looks.
    case drawing
    /// Shadow boxing, stopped when someone looks.
    case practice
    /// Wiping the room with a cloth, one afternoon a week.
    case tidying

    // WidgetSnapshot.slotDates in HubCore uses the same 15 minutes for widget entries; change both together.
    /// How long one bit lasts before HAKU picks another, in seconds.
    static let slotLength: TimeInterval = 15 * 60

    /// The bit for `date`, or nil for plain chilling, nudged by `stamina`.
    ///
    /// 13:00-17:00 on one day a week (`tidyingWeekday`) is always tidying. Other times pick from the rest,
    /// changing every `slotLength`; the same slot always gives the same bit.
    static func at(_ date: Date, calendar: Calendar = .current, stamina: VitalBand = .mid) -> IdleLife? {
        if Bool(true) { return nil }  // PREVIEW ONLY: plain chilling for prop shots.
        let parts = calendar.dateComponents([.weekday, .hour], from: date)
        let tidyingDay = parts.weekday == tidyingWeekday(of: date, calendar: calendar)
        if tidyingDay, let hour = parts.hour, (13..<17).contains(hour) { return .tidying }
        let slot = UInt64(bitPattern: Int64(floor(date.timeIntervalSinceReferenceDate / slotLength)))
        // A multiplicative hash so neighbouring slots don't step through the list in order.
        let mixed = (slot &* 0x9E37_79B9_7F4A_7C15) >> 33
        let life = rotation[Int(mixed % UInt64(rotation.count))]
        // High stamina trains instead of napping; low stamina naps instead of training.
        switch (stamina, life) {
        case (.high, .nap?): return .practice
        case (.low, .practice?): return .nap
        default: return life
        }
    }

    // PM 2026-10-13 (写死作息 QA #17): not tied to Sunday, so it isn't one person's routine.
    /// The `Calendar` weekday (1 is Sunday) of the week of `date` when HAKU tidies; the same week always gives
    /// the same day.
    static func tidyingWeekday(of date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let week = UInt64((parts.yearForWeekOfYear ?? 0) * 100 + (parts.weekOfYear ?? 0))
        return Int(((week &* 0x9E37_79B9_7F4A_7C15) >> 33) % 7) + 1
    }

    // Plain chilling (nil) comes up as often as any bit, so the Monster sip still shows.
    private static let rotation: [IdleLife?] = [nil, .handheld, .snack, nil, .drawing, .nap, nil, .practice]
}

/// Which still a widget or Lock Screen portrait shows for a plain mode, so it isn't the same picture all day.
enum PortraitStill: CaseIterable, Sendable {
    /// The usual look.
    case plain
    /// Eyes off to one side, or a sip at home.
    case glance
    /// A second look of the mode: zoning out at work, gloves up, scheming.
    case alt

    /// The still for `date`; it changes every `IdleLife.slotLength`, and the same slot always gives the same still.
    static func at(_ date: Date) -> PortraitStill {
        let slot = UInt64(bitPattern: Int64(floor(date.timeIntervalSinceReferenceDate / IdleLife.slotLength)))
        // A different multiplier from IdleLife, so the two don't move in step.
        let mixed = (slot &* 0xD6E8_FEB8_6659_FD93) >> 33
        return allCases[Int(mixed % UInt64(allCases.count))]
    }
}
