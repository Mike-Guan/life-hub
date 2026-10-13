import Foundation
import HubCore

/// Which bought or granted items have had their unboxing. Stored only on this iPhone.
enum UnboxLog {
    private static let key = "unboxedEntries"

    /// The ledger entries whose unboxing was shown.
    static var seen: Set<UUID> {
        Set((AppGroup.defaults.stringArray(forKey: key) ?? []).compactMap(UUID.init(uuidString:)))
    }

    // Items owned before the unboxing existed shouldn't all pop open on the first launch.
    /// Marks everything in `ledger` as shown, the first time only.
    static func start(with ledger: CanLedger) {
        guard AppGroup.defaults.stringArray(forKey: key) == nil else { return }
        AppGroup.defaults.set(ledger.active.map(\.id.uuidString), forKey: key)
    }

    /// Remembers that the unboxing of `entry` was shown.
    static func markSeen(_ entry: CanEntry) {
        var ids = AppGroup.defaults.stringArray(forKey: key) ?? []
        guard !ids.contains(entry.id.uuidString) else { return }
        ids.append(entry.id.uuidString)
        AppGroup.defaults.set(ids, forKey: key)
    }

    // An item from a newer build isn't in this catalog. Skipping it, rather than marking it seen,
    // avoids an empty cover now and keeps its unboxing for the build that knows it.
    /// The oldest item of `persona` in `ledger` still to unbox that this build's catalog has.
    static func next(in ledger: CanLedger, persona: Persona) -> CanEntry? {
        ledger.unboxings(seen: seen, persona: persona).first { $0.itemID.flatMap(ShopItem.item) != nil }
    }
}
