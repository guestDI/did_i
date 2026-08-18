import Foundation

public struct Item: Codable, Identifiable, Sendable, Equatable {
    public static let maxNameLength = 24

    public let id: UUID
    public var name: String            // max 24 chars, widget-safe
    public var word: String            // board status word: OFF, LOCKED, DOWN
    public var symbol: String          // SF Symbol name
    public var resetRule: ResetRule
    public var lastConfirmedAt: Date?  // nil = never confirmed
    public var createdAt: Date
    public var archivedAt: Date?       // archive, never delete
    public var order: Int

    /// The joke chosen when this item was last confirmed, held so it stays put
    /// across every widget timeline entry for that confirmation. This is stored
    /// *copy*, not stored state — nothing here says the item is green.
    public var confirmationLine: String?

    /// Confirmation history, trimmed to 30 days on each write. Feeds the
    /// 3+-in-one-day escalation pool and the weekly card. Optional so files
    /// written before this field existed still decode.
    public var confirmations: [Date]?

    /// Opt-in, per item: notify me when I leave home and this has no record.
    /// One of only two notification categories in the app.
    public var leavingHomeReminder: Bool?

    /// day-2's escape hatch. Mutes the item until the geofence says they are home
    /// again, and drops it out of the widget's summary count. Not a state flag —
    /// it records a choice the user made, not what colour anything is.
    public var mutedUntilHome: Bool?

    /// When we offered to put this away. Offered once, ever — nagging about an
    /// unused item is worse than the unused item.
    public var archiveOfferedAt: Date?

    /// The Day 0 chip this came from, while `name` and `word` are still the ones
    /// the chip supplied. Those two are app copy in that case, not user data, so
    /// they follow the device language — see `Store.localizeChipCopy`. Cleared
    /// the moment the user edits either field, after which the text is theirs and
    /// is never touched again.
    public var chipID: String?

    public init(
        id: UUID = UUID(),
        name: String,
        word: String,
        symbol: String,
        resetRule: ResetRule,
        lastConfirmedAt: Date? = nil,
        createdAt: Date,
        archivedAt: Date? = nil,
        order: Int,
        confirmationLine: String? = nil,
        confirmations: [Date]? = nil,
        leavingHomeReminder: Bool? = nil,
        mutedUntilHome: Bool? = nil,
        archiveOfferedAt: Date? = nil,
        chipID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.word = word
        self.symbol = symbol
        self.resetRule = resetRule
        self.lastConfirmedAt = lastConfirmedAt
        self.createdAt = createdAt
        self.archivedAt = archivedAt
        self.order = order
        self.confirmationLine = confirmationLine
        self.confirmations = confirmations
        self.leavingHomeReminder = leavingHomeReminder
        self.mutedUntilHome = mutedUntilHome
        self.archiveOfferedAt = archiveOfferedAt
        self.chipID = chipID
    }

    /// Widget configuration is a name-only picker. Two visually identical names
    /// make it impossible to know which item a widget will confirm, so uniqueness
    /// is checked across both the board and Previously.
    public static func isNameAvailable(
        _ candidate: String,
        among items: [Item],
        excluding excludedID: UUID? = nil,
        locale: Locale = .current
    ) -> Bool {
        let normalized = normalizedName(candidate, locale: locale)
        guard !normalized.isEmpty else { return false }
        return !items.contains {
            $0.id != excludedID && normalizedName($0.name, locale: locale) == normalized
        }
    }

    private static func normalizedName(_ value: String, locale: Locale) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
    }
}
