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
    /// How each character looked when an item reached her.
    public private(set) var looks: LookLog
    /// Last load or save failure, for the UI to show.
    public private(set) var lastError: String?
    public let deviceID: String
    /// The character new cans and items go to.
    public var persona: Persona = .haku
    /// The look `persona` had at a moment, `nil` when it isn't known. Unset, no look is kept.
    @ObservationIgnored public var lookAt: (@MainActor (Persona, Date) -> Look?)?

    @ObservationIgnored private var file: LogFile<CanLedger>
    @ObservationIgnored private var lookFile: LogFile<LookLog>

    /// - Parameters:
    ///   - fileURL: where the ledger lives; `nil` keeps everything in memory (previews, tests).
    ///   - lookURL: where the look snapshots live; `nil` keeps them in memory.
    public init(fileURL: URL?, lookURL: URL? = nil, deviceID: String) {
        var file = LogFile<CanLedger>(url: fileURL, name: "能量罐记录")
        var ledger = CanLedger()
        let error = file.load(into: &ledger)
        var lookFile = LogFile<LookLog>(url: lookURL, name: "那天的样子记录")
        var looks = LookLog()
        let lookError = lookFile.load(into: &looks)
        self.file = file
        self.lookFile = lookFile
        self.deviceID = deviceID
        self.ledger = ledger
        self.looks = looks
        self.lastError = error ?? lookError
    }

    /// Records `win` for `persona` once per `source`, then grants any of her keepsakes it completes.
    /// - Parameter card: the identity card a `boxing` win was earned with.
    /// - Returns: keepsakes granted by this win; empty when it was already recorded.
    @discardableResult
    public func record(_ win: Win, source: String, at date: Date = .now, card: IdentityKind? = nil) -> [ShopItem] {
        let entry = CanEntry.earned(win, source: source, at: date, persona: persona, card: card, deviceID: deviceID)
        guard !ledger.entries.contains(where: { $0.id == entry.id }) else { return [] }
        ledger.entries.append(entry)
        let mine = ledger.only(persona)
        // A keepsake whose art isn't done yet waits: the first matching win after it is drawn grants it.
        let granted = ShopItem.catalog(for: persona).filter { item in
            guard item.isDrawn, let keepsake = item.keepsake, keepsake.win == win else { return false }
            return !mine.owned.contains(item.id) && mine.count(win, card: keepsake.card) >= keepsake.count
        }
        for item in granted {
            let id = UUID.derived(from: "granted:\(item.id)")
            guard !ledger.entries.contains(where: { $0.id == id }) else { continue }
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
            keepLook(for: grant)
        }
        lastError = file.save(&ledger) ?? saveLooks()
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
        keepLook(for: entry)
        lastError = file.save(&ledger) ?? saveLooks()
    }

    /// Wins its character still needs for `item`'s keepsake; `nil` when it isn't a keepsake or is owned.
    public func remaining(for item: ShopItem) -> Int? {
        let theirs = ledger.only(item.persona)
        guard let keepsake = item.keepsake, !theirs.owned.contains(item.id) else { return nil }
        return max(keepsake.count - theirs.count(keepsake.win, card: keepsake.card), 0)
    }

    /// Deletes every record and the file, as on a fresh install.
    public func eraseAll() {
        ledger = CanLedger()
        looks = LookLog()
        let ledgerError = file.remove()
        let lookError = lookFile.remove()
        lastError = ledgerError ?? lookError
    }

    @ObservationIgnored private var looksChanged = false

    /// Keeps `persona`'s look for the item `entry` gave her, once per entry, when the look is known.
    private func keepLook(for entry: CanEntry) {
        guard let itemID = entry.itemID, !looks.snapshots.contains(where: { $0.id == entry.id }),
            let look = lookAt?(entry.persona, entry.at)
        else { return }
        let snapshot = LookSnapshot(
            entry: entry.id,
            persona: entry.persona,
            itemID: itemID,
            look: look,
            at: entry.at,
            deviceID: deviceID
        )
        looks.snapshots.append(snapshot)
        looksChanged = true
    }

    /// Writes the looks when `keepLook` added one.
    /// - Returns: an error message for the UI, or `nil` on success or when nothing changed.
    private func saveLooks() -> String? {
        guard looksChanged else { return nil }
        looksChanged = false
        return lookFile.save(&looks)
    }
}

extension GrowthStore {
    /// The store the apps use, in `container` with this device's id from `defaults`.
    public static func live(
        in container: HubContainer = .applicationSupport(),
        defaults: UserDefaults = .standard
    ) -> GrowthStore {
        GrowthStore(
            fileURL: container.canLedgerURL,
            lookURL: container.lookLogURL,
            deviceID: HubDevice.id(defaults: defaults)
        )
    }
}
