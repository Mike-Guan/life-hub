import Foundation
import Observation

/// Owns the expense log on this device. Single writer for `ExpenseLog`.
@MainActor
@Observable
public final class ExpenseStore {
    public private(set) var log: ExpenseLog
    /// Last load or save failure, for the UI to show.
    public private(set) var lastError: String?
    public let deviceID: String

    @ObservationIgnored private var file: LogFile<ExpenseLog>

    /// - Parameter fileURL: where the log lives; `nil` keeps everything in memory (previews, tests).
    public init(fileURL: URL?, deviceID: String) {
        var file = LogFile<ExpenseLog>(url: fileURL, name: "消费记录")
        var log = ExpenseLog()
        let error = file.load(into: &log)
        self.file = file
        self.deviceID = deviceID
        self.log = log
        self.lastError = error
    }

    /// Adds `expense` unless an expense with the same id is already stored.
    /// - Returns: `false` when the expense was already there.
    @discardableResult
    public func record(_ expense: Expense) -> Bool {
        guard !log.expenses.contains(where: { $0.id == expense.id }) else { return false }
        log.expenses.append(expense)
        lastError = file.save(&log)
        return true
    }
}

extension ExpenseStore {
    /// The store the apps use, in `container` with this device's id from `defaults`.
    public static func live(
        in container: HubContainer = .applicationSupport(),
        defaults: UserDefaults = .standard
    ) -> ExpenseStore {
        ExpenseStore(fileURL: container.expenseLogURL, deviceID: HubDevice.id(defaults: defaults))
    }
}
