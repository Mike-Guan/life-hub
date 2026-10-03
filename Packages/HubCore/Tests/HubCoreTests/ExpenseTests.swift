import Foundation
import Testing

@testable import HubCore

// Email samples are made up in the documented format; real ones (masked) come with the Gmail PR.
@Suite struct ExpenseTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    func day(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day)) ?? .distantPast
    }

    let quickSubject = "【速報版】カード利用のお知らせ(本人ご利用分)"
    let quickBody = """
        楽天カードをご利用いただきありがとうございます。
        《ショッピングご利用分》
        ■利用日: 2026/10/03
        ■利用先: -
        ■利用者: 本人
        ■利用金額: 1,280 円

        ■利用日: 2026/10/03
        ■利用先: -
        ■利用者: 本人
        ■利用金額: 1,280 円
        """
    let detailSubject = "カード利用お知らせメール"
    let detailBody = """
        ■利用日：2026/10/03
        ■利用先：ＳＵＫＩＹＡ すき家 大田店
        ■利用金額：1,280 円
        """

    func charges(_ subject: String, _ body: String, id: String) -> [CardCharge] {
        RakutenMail.charges(subject: subject, body: body, messageID: id, calendar: calendar)
    }

    @Test func readsQuickNoticesWithSeveralCharges() {
        let read = charges(quickSubject, quickBody, id: "m1")
        #expect(read.count == 2)
        #expect(read.map(\.id) == ["m1#0", "m1#1"])
        #expect(read.allSatisfy { $0.kind == .quick && $0.amount == 1280 && $0.merchant == nil })
        #expect(read.first?.day == day(10, 3))
    }

    @Test func readsDetailEmailsWithTheShop() {
        let read = charges(detailSubject, detailBody, id: "m2")
        let shop = "ＳＵＫＩＹＡ すき家 大田店"
        #expect(read == [CardCharge(id: "m2#0", kind: .detail, day: day(10, 3), amount: 1280, merchant: shop)])
    }

    @Test func skipsBlocksItCannotRead() {
        #expect(charges(detailSubject, "■利用日: 不明\n■利用金額: 100 円", id: "x").isEmpty)
        #expect(charges(detailSubject, "■利用先: 店\n■利用金額: 100 円", id: "x").isEmpty)
        #expect(charges(detailSubject, "■利用日: 2026/10/03\n■利用先: 店", id: "x").isEmpty)
    }

    @Test func sortsByShopKeywords() {
        let rules = CategoryRules.standard
        #expect(rules.category(for: nil) == .unsorted)
        #expect(rules.category(for: "ＳＵＫＩＹＡ すき家 大田店") == .diningOut)
        #expect(rules.category(for: "Uber Eats Japan") == .diningOut)
        #expect(rules.category(for: "まいばすけっと 駅前店") == .groceries)
        #expect(rules.category(for: "AMAZON.CO.JP") == .other)
    }

    @Test func pairsQuickAndDetailOnce() {
        var log = ExpenseLog()
        let quick = charges(quickSubject, quickBody, id: "q")
        let detail = charges(detailSubject, detailBody, id: "d")
        #expect(log.apply(quick, rules: .standard, deviceID: "t", now: day(10, 3)))
        #expect(log.apply(detail, rules: .standard, deviceID: "t", now: day(10, 4)))
        #expect(!log.apply(quick + detail, rules: .standard, deviceID: "t", now: day(10, 5)))

        #expect(log.active.count == 2)
        let filled = log.expenses.filter { $0.detailSource != nil }
        #expect(filled.count == 1)
        #expect(filled.first?.quickSource == "q#0")
        #expect(filled.first?.category == .diningOut)
        #expect(log.expenses.first { $0.detailSource == nil }?.category == .unsorted)
    }

    @Test func detailFirstThenQuickIsOneExpense() {
        var log = ExpenseLog()
        log.apply(charges(detailSubject, detailBody, id: "d"), rules: .standard, deviceID: "t", now: day(10, 3))
        let quick = Array(charges(quickSubject, quickBody, id: "q").prefix(1))
        log.apply(quick, rules: .standard, deviceID: "t", now: day(10, 4))
        #expect(log.active.count == 1)
        #expect(log.active.first?.merchant != nil)
        #expect(log.active.first?.quickSource == "q#0")
    }

    @Test func sameEmailGivesTheSameIDOnEveryDevice() {
        var phone = ExpenseLog()
        var mac = ExpenseLog()
        let quick = charges(quickSubject, quickBody, id: "q")
        phone.apply(quick, rules: .standard, deviceID: "phone", now: day(10, 3))
        mac.apply(quick, rules: .standard, deviceID: "mac", now: day(10, 3))
        #expect(phone.expenses.map(\.id) == mac.expenses.map(\.id))
        #expect(Set(phone.expenses.map(\.id)).count == 2)
    }

    @Test func diningOutLeftCountsThisMonthOnly() {
        let rules = CategoryRules.standard
        let october = CardCharge(id: "a", kind: .detail, day: day(10, 3), amount: 3000, merchant: "すき家")
        let september = CardCharge(id: "b", kind: .detail, day: day(9, 30), amount: 2000, merchant: "すき家")
        let groceries = CardCharge(id: "c", kind: .detail, day: day(10, 4), amount: 5000, merchant: "ライフ")
        var log = ExpenseLog()
        log.apply([october, september, groceries], rules: rules, deviceID: "t", now: day(10, 5))
        #expect(Budget.diningOutLeft(log.active, cap: 10000, at: day(10, 20), calendar: calendar) == 7000)
        #expect(Budget.diningOutLeft(log.active, cap: 1000, at: day(10, 20), calendar: calendar) == -2000)

        log.expenses[0].deletedAt = day(10, 6)
        #expect(Budget.diningOutLeft(log.expenses, cap: 10000, at: day(10, 20), calendar: calendar) == 10000)
    }

    func gap(target: Int, _ expenses: [Expense]) -> Int {
        Budget.savingsGap(
            balance: 100_000,
            enteredAt: day(9, 25),
            target: target,
            expenses: expenses,
            calendar: calendar
        )
    }

    @Test func savingsGapSubtractsSpendingSincePayday() {
        let rules = CategoryRules.standard
        let before = CardCharge(id: "a", kind: .quick, day: day(9, 24), amount: 9000)
        let after = CardCharge(id: "b", kind: .quick, day: day(9, 26), amount: 4000)
        var log = ExpenseLog()
        log.apply([before, after], rules: rules, deviceID: "t", now: day(9, 27))
        #expect(gap(target: 120_000, log.active) == 24000)
        #expect(gap(target: 50_000, log.active) == 0)
    }

    @Test func expenseRoundTripsAndToleratesMissingFields() throws {
        var log = ExpenseLog()
        log.apply(charges(detailSubject, detailBody, id: "d"), rules: .standard, deviceID: "t", now: day(10, 3))
        let data = try HubJSON.encoder().encode(log)
        #expect(try HubJSON.decoder().decode(ExpenseLog.self, from: data) == log)

        let minimal = """
            {"expenses": [
              {"id": "6F2A1C3E-0000-4000-8000-000000000001", "day": "2026-10-03T00:00:00Z", "amount": 500},
              {"id": "6F2A1C3E-0000-4000-8000-000000000002", "day": "2026-10-03T00:00:00Z", "amount": 1,
               "category": "fromTheFuture"}
            ]}
            """
        let decoded = try HubJSON.decoder().decode(ExpenseLog.self, from: Data(minimal.utf8))
        #expect(decoded.expenses.count == 1)
        #expect(decoded.expenses.first?.category == .unsorted)
        #expect(decoded.expenses.first?.updatedBy == "unknown")
        #expect(decoded.unreadable.count == 1)
        let again = try HubJSON.decoder().decode(ExpenseLog.self, from: HubJSON.encoder().encode(decoded))
        #expect(again.unreadable.count == 1)
    }
}
