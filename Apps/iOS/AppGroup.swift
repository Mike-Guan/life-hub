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

    /// The gym and run days now, with the gym days learned from `ledger` (the stored one when `nil`) since
    /// they were last forgotten.
    static func activityDays(ledger: CanLedger? = nil, now: Date = .now) -> ActivityDays {
        let ledger = ledger ?? CanLedger.read(from: container.canLedgerURL)
        let since = MemoryResets.stored(in: defaults).since(.gymDays)
        return ActivityDays.stored(in: defaults).learningGym(from: ledger.since(since), now: now)
    }

    /// The need rules for the chosen character, with KURO's tennis day learned from the can ledger since
    /// it was last forgotten.
    static func needRules(now: Date = .now) -> NeedRules {
        let ledger = CanLedger.read(from: container.canLedgerURL)
        let since = MemoryResets.stored(in: defaults).since(.identityDay)
        return NeedRules.standard(for: Persona.stored(in: defaults), ledger: ledger.since(since), now: now)
    }

    /// User defaults both processes read, so they share one device id.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
