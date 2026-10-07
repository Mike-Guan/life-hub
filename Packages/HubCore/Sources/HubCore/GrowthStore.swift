import Foundation
import Observation

/// Owns the can ledger on this device. Single writer for `CanLedger`.
@MainActor
@Observable
public final class GrowthStore {
    /// Why a purchase didn't happen.
    public enum BuyError: Error, Equatable {
        case notForSale
        case alreadyOwned
        case notEnoughCans
    }

    public private(set) var ledger: CanLedger
    /// Last load or save failure, for the UI to show.
    public private(set) var lastError: String?
    public let deviceID: String

    @ObservationIgnored private var file: LogFile<CanLedger>

    /// - Parameter fileURL: where the ledger lives; `nil` keeps everything in memory (previews, tests).
    public init(fileURL: URL?, deviceID: String) {
        var file = LogFile<CanLedger>(url: fileURL, name: "能量罐记录")
        var ledger = CanLedger()
        let error = file.load(into: &ledger)
        self.file = file
        self.deviceID = deviceID
        self.ledger = ledger
        self.lastError = error
    }

    // Both characters' keepsakes are granted, so switching character later finds them already earned.
    /// Records `win` once per `source`, then grants any keepsake it completes.
    /// - Returns: keepsakes granted by this win; empty when it was already recorded.
    @discardableResult
    public func record(_ win: Win, source: String, at date: Date = .now) -> [ShopItem] {
        let entry = CanEntry.earned(win, source: source, at: date, deviceID: deviceID)
        guard !ledger.entries.contains(where: { $0.id == entry.id }) else { return [] }
        ledger.entries.append(entry)
        let granted = ShopItem.catalog.filter { item in
            guard let keepsake = item.keepsake, keepsake.win == win else { return false }
            return !ledger.owned.contains(item.id) && ledger.count(win) >= keepsake.count
        }
        for item in granted {
            let id = UUID.derived(from: "granted:\(item.id)")
            let grant = CanEntry(id: id, kind: .granted, at: date, cans: 0, itemID: item.id, deviceID: deviceID)
            ledger.entries.append(grant)
        }
        lastError = file.save(&ledger)
        return granted
    }

    /// Buys `item` with cans.
    /// - Throws: `BuyError` when the item has no price, is owned already or costs more than the balance.
    public func buy(_ item: ShopItem, at date: Date = .now) throws(BuyError) {
        guard let price = item.price else { throw .notForSale }
        guard !ledger.owned.contains(item.id) else { throw .alreadyOwned }
        guard ledger.balance >= price else { throw .notEnoughCans }
        let id = UUID.derived(from: "bought:\(item.id)")
        let entry = CanEntry(id: id, kind: .bought, at: date, cans: price, itemID: item.id, deviceID: deviceID)
        ledger.entries.append(entry)
        lastError = file.save(&ledger)
    }

    /// Wins still needed for `item`'s keepsake; `nil` when it isn't a keepsake or is already owned.
    public func remaining(for item: ShopItem) -> Int? {
        guard let keepsake = item.keepsake, !ledger.owned.contains(item.id) else { return nil }
        return max(keepsake.count - ledger.count(keepsake.win), 0)
    }
}

extension GrowthStore {
    /// The store the apps use, in `container` with this device's id from `defaults`.
    public static func live(
        in container: HubContainer = .applicationSupport(),
        defaults: UserDefaults = .standard
    ) -> GrowthStore {
        GrowthStore(fileURL: container.canLedgerURL, deviceID: HubDevice.id(defaults: defaults))
    }
}
