import AppIntents
import Foundation
import HubCore

// Fallback for a payment the card emails miss or bring late. A Shortcuts automation ("when Rakuten
// Pay is closed") can run it. It only posts to the inbox; the app applies it next time it opens.
/// Records a Rakuten Pay payment Mike just made.
struct RecordPaymentIntent: AppIntent {
    static let title: LocalizedStringResource = "记一笔乐天 Pay"

    @Parameter(title: "金额（日元）") var amount: Int
    @Parameter(title: "是外食", default: false) var diningOut: Bool

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else { return .result(dialog: "金额要大于 0，没有记。") }
        let now = Date.now
        let expense = Expense(
            amount: amount,
            category: diningOut ? .diningOut : .other,
            day: Calendar.current.startOfDay(for: now),
            deviceID: HubDevice.id(defaults: AppGroup.defaults),
            now: now
        )
        try AppGroup.container.inbox.post(.expense(expense))
        return .result(dialog: "记下了 ¥\(amount)。")
    }
}
