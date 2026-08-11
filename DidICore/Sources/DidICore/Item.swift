import Foundation

public struct Item: Codable, Identifiable, Sendable, Equatable {
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

    /// Confirmations of this item so far today, trimmed on each write. Feeds the
    /// 3+-in-one-day escalation pool. Optional so files written before this field
    /// existed still decode.
    public var todaysConfirmations: [Date]?

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
        todaysConfirmations: [Date]? = nil
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
        self.todaysConfirmations = todaysConfirmations
    }
}
