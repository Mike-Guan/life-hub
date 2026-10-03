import Foundation

/// One card use read from a Rakuten Card email.
public struct CardCharge: Equatable, Sendable {
    public enum Kind: String, Sendable {
        /// 【速報版】カード利用のお知らせ: date and amount, no shop.
        case quick
        /// カード利用お知らせメール: date, amount and shop, a day or so later.
        case detail
    }

    /// The email id and the charge's position in it, so each charge is applied once.
    public var id: String
    public var kind: Kind
    /// Local midnight of the day the card was used.
    public var day: Date
    /// Yen.
    public var amount: Int
    /// The shop, `nil` when the email doesn't name one.
    public var merchant: String?

    public init(id: String, kind: Kind, day: Date, amount: Int, merchant: String? = nil) {
        self.id = id
        self.kind = kind
        self.day = day
        self.amount = amount
        self.merchant = merchant
    }
}

// Read on the device only; the email text isn't stored or sent anywhere.
/// Reads card charges out of Rakuten Card notification emails.
public enum RakutenMail {
    /// The charges in one email, in order. Each starts at a 利用日 line.
    /// - Parameters:
    ///   - subject: tells a quick notice (速報) from a detail email.
    ///   - messageID: the email's id, used in each charge's id.
    public static func charges(
        subject: String,
        body: String,
        messageID: String,
        calendar: Calendar = .current
    ) -> [CardCharge] {
        let kind: CardCharge.Kind = subject.contains("速報") ? .quick : .detail
        var blocks: [[String: String]] = []
        for line in body.components(separatedBy: .newlines) {
            guard case (let label, let value)? = field(in: line) else { continue }
            if label == "利用日" { blocks.append([:]) }
            guard !blocks.isEmpty else { continue }
            blocks[blocks.count - 1][label] = value
        }
        return blocks.enumerated().compactMap { index, block in
            guard let day = block["利用日"].flatMap({ date($0, calendar: calendar) }) else { return nil }
            guard let amount = block["利用金額"].flatMap(yen) else { return nil }
            let shop = block["利用先"].map { $0.trimmingCharacters(in: .whitespaces) }
            let merchant = shop.flatMap { $0.isEmpty || $0 == "-" ? nil : $0 }
            return CardCharge(id: "\(messageID)#\(index)", kind: kind, day: day, amount: amount, merchant: merchant)
        }
    }

    private static let labels = ["利用日", "利用先", "利用金額"]

    // Lines look like "■利用日: 2026/10/03" or "利用金額：1,234 円".
    private static func field(in line: String) -> (String, String)? {
        let text = line.trimmingCharacters(in: CharacterSet(charactersIn: "■・ \t"))
        guard let label = labels.first(where: { text.hasPrefix($0) }) else { return nil }
        let rest = text.dropFirst(label.count).drop { $0 == " " || $0 == ":" || $0 == "：" }
        return (label, String(rest).trimmingCharacters(in: .whitespaces))
    }

    private static func date(_ text: String, calendar: Calendar) -> Date? {
        let parts = text.prefix(10).split(separator: "/").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    private static func yen(_ text: String) -> Int? {
        Int(text.filter { $0.isASCII && $0.isNumber })
    }
}
