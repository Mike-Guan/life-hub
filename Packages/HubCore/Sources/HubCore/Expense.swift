import CryptoKit
import Foundation

/// What a card payment was for. Only eating out counts against the monthly cap.
public enum ExpenseCategory: String, Codable, CaseIterable, Sendable {
    case diningOut
    case groceries
    case other
    /// The shop isn't known yet (only the quick notice has arrived).
    case unsorted
}

/// One card payment. Stored, never sent anywhere; the email it came from isn't kept.
public struct Expense: Codable, Identifiable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var id: UUID
    /// Local midnight of the day the card was used.
    public var day: Date
    /// Yen.
    public var amount: Int
    /// The shop, `nil` until the detail email arrives.
    public var merchant: String?
    public var category: ExpenseCategory
    /// The quick-notice charge this came from, so re-reading the email adds nothing.
    public var quickSource: String?
    /// The detail-email charge this came from.
    public var detailSource: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var updatedBy: String
    public var deletedAt: Date?

    /// A new expense from `charge`, sorted by `rules`.
    public init(_ charge: CardCharge, rules: CategoryRules, deviceID: String, now: Date) {
        self.schemaVersion = Self.currentSchemaVersion
        self.id = Self.id(for: charge.id)
        self.day = charge.day
        self.amount = charge.amount
        self.merchant = charge.merchant
        self.category = rules.category(for: charge.merchant)
        self.quickSource = charge.kind == .quick ? charge.id : nil
        self.detailSource = charge.kind == .detail ? charge.id : nil
        self.createdAt = now
        self.updatedAt = now
        self.updatedBy = deviceID
        self.deletedAt = nil
    }

    // Derived from the email, so two devices reading the same email make the same record.
    static func id(for chargeID: String) -> UUID {
        let bytes = Array(SHA256.hash(data: Data(chargeID.utf8)).prefix(16))
        return UUID(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
            ))
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, day, amount, merchant, category, quickSource, detailSource
        case createdAt, updatedAt, updatedBy, deletedAt
    }

    // Defaults let records from an older or newer build still load. An unknown category throws,
    // so the log keeps the raw record instead of guessing.
    /// Decodes an expense. Only `id`, `day` and `amount` are required.
    /// - Throws: `DecodingError` when a required field is missing or invalid.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        id = try values.decode(UUID.self, forKey: .id)
        day = try values.decode(Date.self, forKey: .day)
        amount = try values.decode(Int.self, forKey: .amount)
        merchant = try values.decodeIfPresent(String.self, forKey: .merchant)
        category = try values.decodeIfPresent(ExpenseCategory.self, forKey: .category) ?? .unsorted
        quickSource = try values.decodeIfPresent(String.self, forKey: .quickSource)
        detailSource = try values.decodeIfPresent(String.self, forKey: .detailSource)
        createdAt = try values.decodeIfPresent(Date.self, forKey: .createdAt) ?? day
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        updatedBy = try values.decodeIfPresent(String.self, forKey: .updatedBy) ?? "unknown"
        deletedAt = try values.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

/// Shop keywords that sort expenses. Rules, not a model (tier T0); Mike can edit them.
public struct CategoryRules: Codable, Equatable, Sendable {
    public var diningOut: [String]
    public var groceries: [String]

    public init(diningOut: [String], groceries: [String]) {
        self.diningOut = diningOut
        self.groceries = groceries
    }

    // Starting guesses for common Tokyo chains; Mike adjusts them in settings.
    /// Common restaurant and supermarket chains.
    public static let standard = CategoryRules(
        diningOut: [
            "マクドナルド", "スターバックス", "すき家", "松屋", "吉野家",
            "サイゼリヤ", "ガスト", "UBER EATS", "出前館", "ドトール",
            "タリーズ", "モスバーガー", "CoCo壱番屋",
        ],
        groceries: [
            "まいばすけっと", "ライフ", "イオン", "西友", "オーケー",
            "サミット", "成城石井",
        ]
    )

    /// The category for `merchant`: unsorted when unknown, eating out or groceries on a keyword
    /// match (ignoring case and width), else other.
    public func category(for merchant: String?) -> ExpenseCategory {
        guard let merchant else { return .unsorted }
        let name = Self.normalized(merchant)
        if diningOut.contains(where: { name.contains(Self.normalized($0)) }) { return .diningOut }
        if groceries.contains(where: { name.contains(Self.normalized($0)) }) { return .groceries }
        return .other
    }

    private static func normalized(_ text: String) -> String {
        let narrow = text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text
        return narrow.lowercased()
    }
}
