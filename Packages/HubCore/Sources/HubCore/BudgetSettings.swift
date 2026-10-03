import Foundation

// Privacy rule: amounts live in the App Group's user defaults on the iPhone, never in the repo or on a network.
/// The money figures Mike enters in settings.
public struct BudgetSettings: Codable, Equatable, Sendable {
    static let defaultsKey = "budget"

    /// The savings target in yen, if set.
    public var savingsTarget: Int?
    /// The bank balance in yen Mike last entered, if any.
    public private(set) var balance: Int?
    /// When `balance` was entered.
    public private(set) var balanceEnteredAt: Date?

    public init(savingsTarget: Int? = nil) {
        self.savingsTarget = savingsTarget
    }

    /// Records `amount` as the bank balance on `date`. `nil` clears it.
    public mutating func enterBalance(_ amount: Int?, at date: Date) {
        balance = amount
        balanceEnteredAt = amount == nil ? nil : date
    }

    /// How far the savings are from the target, or `nil` until both the target and a balance are set.
    public func savingsGap(expenses: [Expense], calendar: Calendar = .current) -> Int? {
        guard let savingsTarget, let balance, let balanceEnteredAt else { return nil }
        return Budget.savingsGap(
            balance: balance,
            enteredAt: balanceEnteredAt,
            target: savingsTarget,
            expenses: expenses,
            calendar: calendar
        )
    }

    /// The settings saved in `defaults`, or none when nothing is saved or it can't be read.
    public static func stored(in defaults: UserDefaults) -> BudgetSettings {
        guard let data = defaults.data(forKey: defaultsKey) else { return BudgetSettings() }
        return (try? JSONDecoder().decode(BudgetSettings.self, from: data)) ?? BudgetSettings()
    }

    /// Saves the settings in `defaults`.
    public func store(in defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }
}
