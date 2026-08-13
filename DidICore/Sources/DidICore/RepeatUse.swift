import Foundation

/// day-3+. Everything that decides whether the app is allowed to speak up.
///
/// Keyed by `uuidString` rather than `UUID` as architecture §3 writes it: a
/// `[UUID: [Date]]` encodes to a flat alternating array, and the store is meant
/// to be readable when you open it during development.
public struct Usage: Codable, Sendable, Equatable {
    /// Item views, not confirmations. Trimmed to 30 days — the only structure
    /// here that grows.
    public var checks: [String: [Date]]
    public var appOpens: [Date]

    public var lastSuggestedAt: Date?
    public var lastDeclinedAt: Date?
    public var declineCount: Int

    /// Set permanently by the escalating-checks guardrail.
    public var paranoiaSuppressed: Bool
    public var guardrailShown: Bool
    public var weeklyCardDismissedAt: Date?
    public var lastReviewPromptAt: Date?

    public init(
        checks: [String: [Date]] = [:],
        appOpens: [Date] = [],
        lastSuggestedAt: Date? = nil,
        lastDeclinedAt: Date? = nil,
        declineCount: Int = 0,
        paranoiaSuppressed: Bool = false,
        guardrailShown: Bool = false,
        weeklyCardDismissedAt: Date? = nil,
        lastReviewPromptAt: Date? = nil
    ) {
        self.checks = checks
        self.appOpens = appOpens
        self.lastSuggestedAt = lastSuggestedAt
        self.lastDeclinedAt = lastDeclinedAt
        self.declineCount = declineCount
        self.paranoiaSuppressed = paranoiaSuppressed
        self.guardrailShown = guardrailShown
        self.weeklyCardDismissedAt = weeklyCardDismissedAt
        self.lastReviewPromptAt = lastReviewPromptAt
    }

    /// Forgiving, for the same reason as `Store` and `OnboardingFlags`.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        checks = try c.decodeIfPresent([String: [Date]].self, forKey: .checks) ?? [:]
        appOpens = try c.decodeIfPresent([Date].self, forKey: .appOpens) ?? []
        lastSuggestedAt = try c.decodeIfPresent(Date.self, forKey: .lastSuggestedAt)
        lastDeclinedAt = try c.decodeIfPresent(Date.self, forKey: .lastDeclinedAt)
        declineCount = try c.decodeIfPresent(Int.self, forKey: .declineCount) ?? 0
        paranoiaSuppressed = try c.decodeIfPresent(Bool.self, forKey: .paranoiaSuppressed) ?? false
        guardrailShown = try c.decodeIfPresent(Bool.self, forKey: .guardrailShown) ?? false
        weeklyCardDismissedAt = try c.decodeIfPresent(Date.self, forKey: .weeklyCardDismissedAt)
        lastReviewPromptAt = try c.decodeIfPresent(Date.self, forKey: .lastReviewPromptAt)
    }
}

private let day: TimeInterval = 86_400
private let retention: TimeInterval = 30 * day

public extension Store {
    /// The hard cap. Six items, and not a paywall — making anxiety relief a
    /// subscription tier is a bad thing to do to people.
    static let itemCap = 6

    var isFull: Bool { active.count >= Self.itemCap }

    /// A look at an item, not a confirmation.
    mutating func recordCheck(_ id: UUID, at date: Date) {
        let key = id.uuidString
        var seen = usage.checks[key] ?? []
        seen.append(date)
        usage.checks[key] = seen.filter { $0 > date.addingTimeInterval(-retention) }
    }

    /// Opening the board is a look at whatever was still in question.
    ///
    /// Attributing it to every item made "checks" a copy of the app-open count,
    /// so every item tied and the counter's ranking meant nothing. If the stove
    /// already reads green, opening the board was not checking the stove.
    mutating func recordBoardView(at date: Date, calendar: Calendar = .current) {
        usage.appOpens = (usage.appOpens + [date])
            .filter { $0 > date.addingTimeInterval(-retention) }
        for item in active where state(item, now: date, calendar: calendar) == .unknown {
            recordCheck(item.id, at: date)
        }
    }

    func checks(_ id: UUID, since: Date, until: Date) -> Int {
        (usage.checks[id.uuidString] ?? []).count { $0 >= since && $0 < until }
    }

    func confirmations(_ id: UUID, since: Date, until: Date) -> Int {
        guard let item = items.first(where: { $0.id == id }) else { return 0 }
        return (item.confirmations ?? []).count { $0 >= since && $0 < until }
    }

    /// Swaps an item with the one above it. Board order is also the medium
    /// widget's tap-target order, so a position assigned once at add time is not
    /// something the user can be stuck with.
    mutating func moveUp(_ id: UUID) {
        let ordered = active
        guard let position = ordered.firstIndex(where: { $0.id == id }), position > 0,
              let lower = items.firstIndex(where: { $0.id == id }),
              let upper = items.firstIndex(where: { $0.id == ordered[position - 1].id })
        else { return }
        let above = items[upper].order
        items[upper].order = items[lower].order
        items[lower].order = above
    }

    /// Archive, never delete. Deleting a user's data on our own initiative is not
    /// our call to make.
    mutating func archive(_ id: UUID, at date: Date) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].archivedAt = date
    }

    mutating func unarchive(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].archivedAt = nil
    }

    /// Surfaced in the add-item sheet under a quiet "Previously" section, so
    /// seasonal items are one tap to bring back.
    var archived: [Item] {
        items.filter { $0.archivedAt != nil }.sorted { $0.order < $1.order }
    }
}

// MARK: - The second item

/// Signal-driven, never scheduled. Prompt when behaviour says something is
/// missing from the list — not on "day 3".
public enum SecondItem {
    public enum Trigger: String, Sendable, Equatable {
        /// They're looking for something the widget can't answer.
        case twoAppOpensInADay
        /// Rumination about something adjacent, not about that item.
        case oneItemCheckedFiveTimes
        /// Usually means they tapped the wrong thing and a neighbour is missing.
        case reconfirmedWithinAMinute
    }

    public static func trigger(
        in store: Store, now: Date, calendar: Calendar = .current
    ) -> Trigger? {
        let opens = store.usage.appOpens.count { calendar.isDate($0, inSameDayAs: now) }
        if opens >= 2 { return .twoAppOpensInADay }

        for item in store.active {
            let confirmations = (item.confirmations ?? [])
                .filter { calendar.isDate($0, inSameDayAs: now) }
                .sorted()

            let checks = (store.usage.checks[item.id.uuidString] ?? [])
                .count { calendar.isDate($0, inSameDayAs: now) }
            if checks >= 5, confirmations.isEmpty { return .oneItemCheckedFiveTimes }

            for (earlier, later) in zip(confirmations, confirmations.dropFirst())
            where later.timeIntervalSince(earlier) <= 60 {
                return .reconfirmedWithinAMinute
            }
        }
        return nil
    }

    /// The cooldowns are the whole design. Without them this becomes nagging.
    public static func shouldSuggest(
        in store: Store, now: Date, calendar: Calendar = .current
    ) -> Trigger? {
        guard !store.isFull else { return nil }
        // They know where the plus button is.
        guard store.usage.declineCount < 3 else { return nil }
        guard let installedAt = store.flags.installedAt,
              now >= installedAt.addingTimeInterval(2 * day) else { return nil }

        if store.usage.declineCount >= 2,
           let declined = store.usage.lastDeclinedAt,
           now < declined.addingTimeInterval(30 * day) { return nil }

        if let suggested = store.usage.lastSuggestedAt,
           now < suggested.addingTimeInterval(7 * day) { return nil }

        return trigger(in: store, now: now, calendar: calendar)
    }
}

// MARK: - The escalating-checks guardrail

/// Runs before the paranoia counter, and can permanently silence it.
public enum EscalatingChecks {
    /// Checks per day for each of the last three whole weeks, oldest first.
    static func weeklyRates(_ store: Store, _ id: UUID, now: Date) -> [Double] {
        (0..<3).reversed().map { weeksAgo in
            let end = now.addingTimeInterval(-Double(weeksAgo) * 7 * day)
            let start = end.addingTimeInterval(-7 * day)
            return Double(store.checks(id, since: start, until: end)) / 7
        }
    }

    /// Below this, a rising trend is not "checking a lot" — it is someone using
    /// the app slightly more than last week.
    ///
    /// The doc gives no magnitude, only the direction: "if checks-per-day for a
    /// single item trend upward across three consecutive weeks". Taken literally,
    /// 1 → 2 → 3 checks in three weeks would trip it, permanently suppress the
    /// weekly card, and tell a light user that the app has become the thing they
    /// check. That is the most harmful sentence in the product and it must not
    /// fire on noise. The floor reuses the counter's own idea of "a lot" — the
    /// 10-checks-a-week that unlocks it. See decisions.md.
    static let floor = 10

    /// An item whose checks-per-day rose across three consecutive weeks, and
    /// which is being checked enough for that to mean anything.
    /// Strictly increasing — a flat week breaks the trend.
    public static func escalating(
        in store: Store, now: Date
    ) -> Item? {
        guard !store.usage.guardrailShown else { return nil }
        return store.active.first { item in
            let rates = weeklyRates(store, item.id, now: now)
            let latestWeek = store.checks(
                item.id, since: now.addingTimeInterval(-7 * day), until: now
            )
            return rates[0] < rates[1] && rates[1] < rates[2]
                && rates[0] > 0
                && latestWeek >= floor
        }
    }
}

// MARK: - The paranoia counter

/// Only ever shown as a joke about a *good* record. A stat that reads as "look
/// how anxious you were" is not a feature.
public enum ParanoiaCounter {
    public struct Card: Sendable, Equatable {
        public let topWorry: Item
        public let topChecks: Int
        public let runnerUp: Item?
        public let runnerUpChecks: Int
        public let reassurance: Item
        public let closingLine: String
    }

    /// Unlocked quietly at the first week's end, and only if there is something
    /// amusing to show.
    public static func card(
        for store: Store, now: Date, calendar: Calendar = .current
    ) -> Card? {
        guard !store.usage.paranoiaSuppressed else { return nil }
        guard let installedAt = store.flags.installedAt,
              now >= installedAt.addingTimeInterval(7 * day) else { return nil }
        if let dismissed = store.usage.weeklyCardDismissedAt,
           now < dismissed.addingTimeInterval(7 * day) { return nil }

        let weekStart = now.addingTimeInterval(-7 * day)
        let previousStart = now.addingTimeInterval(-14 * day)

        // Hard rule: nothing may have genuinely gone unconfirmed this week.
        let everythingWasFine = store.active.allSatisfy {
            store.confirmations($0.id, since: weekStart, until: now) > 0
        }
        guard everythingWasFine else { return nil }

        // Hard rule: not while the check count is climbing week over week.
        let thisWeek = store.active.reduce(0) {
            $0 + store.checks($1.id, since: weekStart, until: now)
        }
        let lastWeek = store.active.reduce(0) {
            $0 + store.checks($1.id, since: previousStart, until: weekStart)
        }
        guard lastWeek == 0 || thisWeek <= lastWeek else { return nil }

        let ranked = store.active
            .map { ($0, store.checks($0.id, since: weekStart, until: now)) }
            .sorted { $0.1 > $1.1 }

        // Something amusing to show means at least one item checked 10+ times.
        guard let top = ranked.first, top.1 >= 10 else { return nil }

        return Card(
            topWorry: top.0,
            topChecks: top.1,
            runnerUp: ranked.count > 1 ? ranked[1].0 : nil,
            runnerUpChecks: ranked.count > 1 ? ranked[1].1 : 0,
            reassurance: ranked.last?.0 ?? top.0,
            closingLine: Copy.Paranoia.closing.randomElement() ?? Copy.Paranoia.closing[0]
        )
    }
}

// MARK: - Items that go stale

/// day-3: offer to put away anything that hasn't come up in a month. Once.
public enum StaleItem {
    public static let threshold: TimeInterval = 30 * day

    /// Never-confirmed items count from creation — those have not "come up"
    /// either, and are the likeliest thing on the board to be dead weight.
    public static func needingArchiveOffer(in store: Store, now: Date) -> Item? {
        store.active.first { item in
            guard item.archiveOfferedAt == nil else { return false }
            let last = item.lastConfirmedAt ?? item.createdAt
            return now.timeIntervalSince(last) >= threshold
        }
    }
}

// MARK: - The review prompt

/// Ask people for a favour when things are good, never while they're wondering
/// about the stove.
public enum ReviewPrompt {
    public static func shouldAsk(in store: Store, now: Date) -> Bool {
        // Away means possibly anxious. With no geofence we cannot tell, and the
        // "just confirmed" trigger is itself the signal that things are fine.
        guard !store.isAway else { return false }
        guard let installedAt = store.flags.installedAt,
              now >= installedAt.addingTimeInterval(15 * day) else { return false }
        if let last = store.usage.lastReviewPromptAt,
           now < last.addingTimeInterval(120 * day) { return false }
        return true
    }
}
