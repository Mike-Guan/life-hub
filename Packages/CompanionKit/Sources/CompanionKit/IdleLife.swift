import Foundation

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
    /// Wiping the room with a cloth, Sunday afternoons.
    case tidying

    /// How long one bit lasts before HAKU picks another, in seconds.
    static let slotLength: TimeInterval = 15 * 60

    /// The bit for `date`, or nil for plain chilling.
    ///
    /// Sunday 13:00-17:00 is always tidying. Other times pick from the rest, changing every
    /// `slotLength`; the same slot always gives the same bit.
    static func at(_ date: Date, calendar: Calendar = .current) -> IdleLife? {
        let parts = calendar.dateComponents([.weekday, .hour], from: date)
        if parts.weekday == 1, let hour = parts.hour, (13..<17).contains(hour) { return .tidying }
        let slot = UInt64(bitPattern: Int64(floor(date.timeIntervalSinceReferenceDate / slotLength)))
        // A multiplicative hash so neighbouring slots don't step through the list in order.
        let mixed = (slot &* 0x9E37_79B9_7F4A_7C15) >> 33
        return rotation[Int(mixed % UInt64(rotation.count))]
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
