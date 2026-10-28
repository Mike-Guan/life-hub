import Foundation
import HubCore

/// The App Group the iOS app and its widgets share. Matches `APP_GROUP_ID` in project.yml.
enum AppGroup {
    static var identifier: String {
        #if ENV_DEV
        "group.com.guanshiyang.lifehub.dev"
        #elseif ENV_STG
        "group.com.guanshiyang.lifehub.stg"
        #else
        "group.com.guanshiyang.lifehub"
        #endif
    }

    /// `true` when this build can reach the shared container.
    static var isAvailable: Bool { HubContainer.appGroup(identifier) != nil }

    // Without the entitlement (an unsigned build) the app still works on its own files;
    // widgets then show their empty state.
    /// The shared container, or the app's own folder when the group is unavailable.
    static var container: HubContainer {
        HubContainer.appGroup(identifier) ?? .applicationSupport()
    }

    /// The gym and run days now, learned from `ledger` (the stored one when `nil`): gym days since they
    /// were last forgotten, the run day since all memories were.
    static func activityDays(ledger: CanLedger? = nil, now: Date = .now) -> ActivityDays {
        let ledger = ledger ?? CanLedger.read(from: container.canLedgerURL)
        let resets = MemoryResets.stored(in: defaults)
        return ActivityDays.stored(in: defaults)
            .learningGym(from: ledger.since(resets.since(.gymDays)), now: now)
            .learningRun(from: ledger.since(resets.all), now: now)
    }

    /// The need rules for the chosen character, with the identity day learned from the can ledger and the
    /// switches to the identity card since it was last forgotten, and the evening times following the stored
    /// work hours.
    static func needRules(now: Date = .now) -> NeedRules {
        let ledger = CanLedger.read(from: container.canLedgerURL)
        let since = MemoryResets.stored(in: defaults).since(.identityDay)
        let arrivals = ModeLog.read(from: container.modeLogURL).active
            .filter { $0.mode == .boxing && $0.at >= (since ?? .distantPast) }
            .map(\.at)
        let rules = NeedRules.standard(
            for: Persona.stored(in: defaults),
            ledger: ledger.since(since),
            arrivals: arrivals,
            cards: ModeCards.stored(in: defaults),
            now: now
        )
        return rules.following(ModeRules.stored(in: defaults), bedtime: BedtimeSchedule.stored(in: defaults))
    }

    /// User defaults both processes read, so they share one device id.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
