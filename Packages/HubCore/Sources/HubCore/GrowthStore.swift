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
    /// The character new cans and items go to.
    public var persona: Persona = .haku

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

    /// Records `win` for `persona` once per `source`, then grants any of her keepsakes it completes.
    /// - Returns: keepsakes granted by this win; empty when it was already recorded.
    @discardableResult
    public func record(_ win: Win, source: String, at date: Date = .now) -> [ShopItem] {
        let entry = CanEntry.earned(win, source: source, at: date, persona: persona, deviceID: deviceID)
        guard !ledger.entries.contains(where: { $0.id == entry.id }) else { return [] }
        ledger.entries.append(entry)
        let mine = ledger.only(persona)
        let granted = ShopItem.catalog(for: persona).filter { item in
            guard let keepsake = item.keepsake, keepsake.win == win else { return false }
            return !mine.owned.contains(item.id) && mine.count(win) >= keepsake.count
        }
        for item in granted {
            let id = UUID.derived(from: "granted:\(item.id)")
            let grant = CanEntry(
                id: id,
                kind: .granted,
                at: date,
                cans: 0,
                itemID: item.id,
                persona: persona,
                deviceID: deviceID
            )
            ledger.entries.append(grant)
        }
        lastError = file.save(&ledger)
        return granted
    }

    /// Buys `item` with `persona`'s cans.
    /// - Throws: `BuyError` when the item has no price, isn't hers, is owned already or costs more than
    ///   her balance.
    public func buy(_ item: ShopItem, at date: Date = .now) throws(BuyError) {
        let mine = ledger.only(persona)
        guard let price = item.price, item.persona == persona else { throw .notForSale }
        guard !mine.owned.contains(item.id) else { throw .alreadyOwned }
        guard mine.balance >= price else { throw .notEnoughCans }
        let id = UUID.derived(from: "bought:\(item.id)")
        let entry = CanEntry(
            id: id,
            kind: .bought,
            at: date,
            cans: price,
            itemID: item.id,
            persona: persona,
            deviceID: deviceID
        )
        ledger.entries.append(entry)
        lastError = file.save(&ledger)
    }

    /// Wins its character still needs for `item`'s keepsake; `nil` when it isn't a keepsake or is owned.
    public func remaining(for item: ShopItem) -> Int? {
        let theirs = ledger.only(item.persona)
        guard let keepsake = item.keepsake, !theirs.owned.contains(item.id) else { return nil }
        return max(keepsake.count - theirs.count(keepsake.win), 0)
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
