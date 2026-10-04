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

    /// The oldest item in `ledger` still to unbox.
    static func next(in ledger: CanLedger) -> CanEntry? {
        ledger.unboxings(seen: seen).first
    }
}
