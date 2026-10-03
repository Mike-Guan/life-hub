import Foundation

/// Card expenses read from email. This is the on-disk document.
public struct ExpenseLog: RecordLog, Equatable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var expenses: [Expense]
    // Kept as-is and written back on save, so an older build never deletes newer data (DW-02).
    /// Records this build can't read.
    public var unreadable: [JSONValue]

    public var records: [Expense] {
        get { expenses }
        set { expenses = newValue }
    }

    public init() { self.init(expenses: []) }

    public init(expenses: [Expense]) {
        self.schemaVersion = Self.currentSchemaVersion
        self.expenses = expenses
        self.unreadable = []
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, expenses }

    /// Decodes the log, moving records that fail to decode into `unreadable`.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        let items = try values.decodeIfPresent([LossyRecord<Expense>].self, forKey: .expenses) ?? []
        expenses = items.compactMap(\.value)
        unreadable = items.filter { $0.value == nil }.map(\.raw)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        var list = values.nestedUnkeyedContainer(forKey: .expenses)
        for expense in expenses { try list.encode(expense) }
        for raw in unreadable { try list.encode(raw) }
    }

    /// Non-deleted expenses, oldest day first.
    public var active: [Expense] {
        expenses.filter { $0.deletedAt == nil }.sorted { $0.day < $1.day }
    }

    // The quick notice and the detail email describe the same payment. They are paired by day and
    // amount; two same-day payments of the same amount pair in the order they arrive.
    /// Applies `charges`: a charge already applied is skipped, one that pairs with an expense from
    /// the other kind of email fills it in, any other is a new expense.
    /// - Returns: `true` when the log changed.
    @discardableResult
    public mutating func apply(_ charges: [CardCharge], rules: CategoryRules, deviceID: String, now: Date) -> Bool {
        var changed = false
        for charge in charges where !contains(charge) {
            if let index = pairIndex(for: charge) {
                Self.fill(&expenses[index], with: charge, rules: rules, deviceID: deviceID, now: now)
            } else {
                expenses.append(Expense(charge, rules: rules, deviceID: deviceID, now: now))
            }
            changed = true
        }
        return changed
    }

    private func contains(_ charge: CardCharge) -> Bool {
        expenses.contains { $0.quickSource == charge.id || $0.detailSource == charge.id }
    }

    private func pairIndex(for charge: CardCharge) -> Int? {
        let candidates = expenses.indices.filter { index in
            let expense = expenses[index]
            let open = charge.kind == .quick ? expense.quickSource == nil : expense.detailSource == nil
            return open && expense.deletedAt == nil && expense.day == charge.day && expense.amount == charge.amount
        }
        return candidates.min { expenses[$0].createdAt < expenses[$1].createdAt }
    }

    private static func fill(
        _ expense: inout Expense,
        with charge: CardCharge,
        rules: CategoryRules,
        deviceID: String,
        now: Date
    ) {
        switch charge.kind {
        case .quick:
            expense.quickSource = charge.id
        case .detail:
            expense.detailSource = charge.id
            expense.merchant = charge.merchant ?? expense.merchant
            // A category Mike picked himself wins over the shop rules.
            if expense.category == .unsorted {
                expense.category = rules.category(for: expense.merchant)
            }
        }
        expense.updatedAt = now
        expense.updatedBy = deviceID
    }
}

/// The two money numbers on the iPhone: eating out left this month, and the gap to the savings target.
public enum Budget {
    /// `cap` minus this month's eating-out expenses. Negative when over.
    public static func diningOutLeft(
        _ expenses: [Expense],
        cap: Int,
        at date: Date,
        calendar: Calendar = .current
    ) -> Int {
        let eatingOut = expenses.filter { $0.deletedAt == nil && $0.category == .diningOut }
        let thisMonth = eatingOut.filter { calendar.isDate($0.day, equalTo: date, toGranularity: .month) }
        return cap - thisMonth.map(\.amount).reduce(0, +)
    }

    // The balance is entered once on payday; card spending since then comes off it.
    /// How far the savings are from `target`, 0 once reached.
    /// - Parameters:
    ///   - balance: the bank balance Mike entered.
    ///   - enteredAt: when he entered it.
    public static func savingsGap(
        balance: Int,
        enteredAt: Date,
        target: Int,
        expenses: [Expense],
        calendar: Calendar = .current
    ) -> Int {
        let since = calendar.startOfDay(for: enteredAt)
        let spent = expenses.filter { $0.deletedAt == nil && $0.day >= since }.map(\.amount).reduce(0, +)
        return max(target - (balance - spent), 0)
    }
}
