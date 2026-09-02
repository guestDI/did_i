import Foundation

public struct Store: Codable, Sendable {
    public var items: [Item]

    /// Set once the user picks a home. `nil` means location was never granted or
    /// was declined, which hides the "when I leave home" reset option.
    public var home: HomeLocation?

    /// Set by the region-exit background wake. `nil` until the geofence exists.
    public var lastLeftHomeAt: Date?

    /// Set by the region-entry event. Paired with `lastLeftHomeAt` it derives
    /// `isAway` — two timestamps rather than a stored "currently away" flag.
    public var lastEnteredHomeAt: Date?

    /// The last confirmation line shown, so the next one can avoid it.
    /// Global rather than per-item: "never twice in a row" is about what the
    /// person just read, and they read one line at a time.
    public var lastConfirmationLine: String?

    public var flags: OnboardingFlags

    /// day-3+ counters. Local only, never transmitted.
    public var usage: Usage

    /// Design `2a`, TONE. `true` drops the joke pool: confirmations then read as
    /// the plain "Off, 6 hours ago." line the aging state already uses.
    public var plainTone: Bool

    public init(
        items: [Item] = [],
        home: HomeLocation? = nil,
        lastLeftHomeAt: Date? = nil,
        lastEnteredHomeAt: Date? = nil,
        lastConfirmationLine: String? = nil,
        flags: OnboardingFlags = OnboardingFlags(),
        usage: Usage = Usage(),
        plainTone: Bool = false
    ) {
        self.items = items
        self.home = home
        self.lastLeftHomeAt = lastLeftHomeAt
        self.lastEnteredHomeAt = lastEnteredHomeAt
        self.lastConfirmationLine = lastConfirmationLine
        self.flags = flags
        self.usage = usage
        self.plainTone = plainTone
    }

    /// Hand-written so a store file missing any newer key still decodes rather
    /// than throwing away someone's board. Synthesised `Decodable` ignores
    /// property defaults, which is the trap this avoids.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decodeIfPresent([Item].self, forKey: .items) ?? []
        home = try c.decodeIfPresent(HomeLocation.self, forKey: .home)
        lastLeftHomeAt = try c.decodeIfPresent(Date.self, forKey: .lastLeftHomeAt)
        lastEnteredHomeAt = try c.decodeIfPresent(Date.self, forKey: .lastEnteredHomeAt)
        lastConfirmationLine = try c.decodeIfPresent(String.self, forKey: .lastConfirmationLine)
        flags = try c.decodeIfPresent(OnboardingFlags.self, forKey: .flags) ?? OnboardingFlags()
        usage = try c.decodeIfPresent(Usage.self, forKey: .usage) ?? Usage()
        plainTone = try c.decodeIfPresent(Bool.self, forKey: .plainTone) ?? false
    }

    enum CodingKeys: String, CodingKey {
        case items, home, lastLeftHomeAt, lastEnteredHomeAt, lastConfirmationLine, flags, usage, plainTone
    }

    /// Adds the first item onboarding produced.
    public mutating func add(_ item: Item) {
        var item = item
        item.order = (items.map(\.order).max() ?? -1) + 1
        items.append(item)
    }

    /// Items on the board, in order. Archived items are kept but not shown.
    public var active: [Item] {
        items.filter { $0.archivedAt == nil }.sorted { $0.order < $1.order }
    }

    /// Records a confirmation and picks the line that goes with it.
    ///
    /// `calendar` is injected so the day-rollover in the escalation count is
    /// testable; nothing here reads the clock.
    public mutating func confirm(id: UUID, at date: Date, calendar: Calendar = .current) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }

        let fallbackRule = items[i].lastConfirmationRule ?? items[i].resetRule
        let existingHistory = items[i].confirmations ?? []
        let existingRules = items[i].confirmationRules ?? []
        let retained: [(date: Date, rule: ResetRule)] = existingHistory.enumerated().compactMap {
            index, confirmation in
            guard confirmation > date.addingTimeInterval(-30 * 86_400) else { return nil }
            let rule = existingRules.indices.contains(index) ? existingRules[index] : fallbackRule
            return (date: confirmation, rule: rule)
        }
        let history = retained.map(\.date) + [date]
        let rules = retained.map(\.rule) + [items[i].resetRule]
        let today = history.filter { calendar.isDate($0, inSameDayAs: date) }

        // Plain tone leaves the line unset, so `Copy.status` falls back to the
        // timestamp sentence for fresh confirmations too.
        let line = plainTone ? nil : Copy.confirmationLine(
            escalating: today.count >= 3,
            avoiding: lastConfirmationLine
        )

        items[i].confirmations = history
        items[i].confirmationRules = rules
        items[i].lastConfirmedAt = date
        items[i].lastConfirmationRule = items[i].resetRule
        items[i].confirmationLine = line
        // The mute was an escape from not knowing; a confirmation ends that.
        // Without a geofence `arrivedHome` never fires, so this is the only thing
        // that can lift a mute for someone who declined location.
        items[i].mutedUntilHome = false
        if let line { lastConfirmationLine = line }

        // A tap is a look you can actually observe, and the only one the widget
        // ever gives us. Without this a widget-only user has no check history at
        // all and the counter reads their week as empty.
        recordCheck(id, at: date)
    }

    /// Reverses the most recent confirmation. The promise on the Day 0 practice
    /// screen — "hold to undo" — is about the in-app card, and this is it.
    ///
    /// Falls back to the previous confirmation if there is one, otherwise to no
    /// record at all. The joke is dropped rather than restored: the line that went
    /// with the undone tap is gone, and inventing a new one would read as a reward
    /// for undoing.
    public mutating func undo(id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        var history = items[i].confirmations ?? []
        let storedRules = items[i].confirmationRules ?? []
        let fallbackRule = items[i].lastConfirmationRule ?? items[i].resetRule
        var rules = history.indices.map { index in
            storedRules.indices.contains(index) ? storedRules[index] : fallbackRule
        }
        if !history.isEmpty {
            history.removeLast()
            if !rules.isEmpty { rules.removeLast() }
        }
        items[i].confirmations = history
        items[i].confirmationRules = rules
        items[i].lastConfirmedAt = history.last
        items[i].lastConfirmationRule = rules.last
        items[i].confirmationLine = nil
    }

    /// Replaces editable item settings without reinterpreting the confirmation
    /// already on the board. Legacy stores have no rule snapshot, so capture the
    /// old configured rule before accepting the new one.
    public mutating func update(_ updated: Item) {
        guard let i = items.firstIndex(where: { $0.id == updated.id }) else { return }
        let existing = items[i]
        var updated = updated
        if existing.lastConfirmedAt != nil, existing.lastConfirmationRule == nil {
            updated.lastConfirmationRule = existing.resetRule
        }
        if let confirmations = existing.confirmations {
            let storedRules = existing.confirmationRules ?? []
            let fallbackRule = existing.lastConfirmationRule ?? existing.resetRule
            updated.confirmationRules = confirmations.indices.map { index in
                storedRules.indices.contains(index) ? storedRules[index] : fallbackRule
            }
        }
        items[i] = updated
    }

    public func state(_ item: Item, now: Date, calendar: Calendar = .current) -> ItemState {
        resolve(item, lastEnteredHome: lastEnteredHomeAt, now: now, calendar: calendar)
    }

    /// Re-applies the current language to items still carrying chip copy.
    ///
    /// Chip labels and words are app strings, but adding an item copies them into
    /// the store as literals — so without this, switching the device language
    /// leaves the board in the old one forever, and every chip reappears as
    /// "available" because `Chip.available(excluding:)` matches on name.
    ///
    /// Only ever touches items whose `chipID` is still set, which by definition
    /// means the user has not edited either field. Anything they typed is theirs.
    mutating func localizeChipCopy() {
        for i in items.indices {
            guard let chipID = items[i].chipID,
                  let chip = Chip.all.first(where: { $0.id == chipID })
            else { continue }
            items[i].name = chip.label
            items[i].word = chip.word
        }
    }

    /// Every future instant at which any item's state changes, once each.
    ///
    /// `active`, not `items`: a just-archived item keeps its `lastConfirmedAt` and
    /// so kept generating boundaries for a day after it left the board, spending
    /// timeline entries on a state change nothing renders. Deduplicated because the
    /// timeline is capped at 20 — six items all resetting at 04:00 produced six
    /// identical timestamps and crowded out later ones.
    public func allBoundaries(after date: Date, calendar: Calendar = .current) -> [Date] {
        Set(active.flatMap { boundaries(for: $0, after: date, calendar: calendar) }).sorted()
    }
}

public enum StoreIO {
    public static let appGroupID = "group.com.dihnatovich.didi"
    public static let changeNotification = "com.dihnatovich.didi.storechanged"

    public static var storeURL: URL {
        guard let root = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            fatalError("App Group \(appGroupID) is not configured on this target")
        }
        return root.appending(path: "items.json")
    }

    /// Reads the store for display, flattening any failure to an empty board.
    ///
    /// Safe here because nothing is written back: a widget cannot surface an error
    /// and an empty face is a better answer than a crash. **Never build a write on
    /// top of this** — see `mutate`.
    public static func read() -> Store {
        (try? load()) ?? Store()
    }

    /// The honest read: seeds a genuinely absent file, throws for one that exists
    /// and will not decode.
    ///
    /// The distinction is the whole point. Treating an undecodable store as a fresh
    /// one let `mutate` overwrite every item with nothing — a total, silent wipe in
    /// an app whose first rule is that items are archived and never deleted.
    public static func load() throws -> Store {
        var result: Result<Store, Error>?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: storeURL, error: &coordinationError) { url in
            result = Result { try decode(from: url) }
        }
        if let coordinationError { throw coordinationError }
        // The accessor did not run and the coordinator did not say why.
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return try result.get()
    }

    public static func write(_ store: Store) throws {
        try coordinatedWrite { _ in (store, ()) }
    }

    /// Read, mutate, write **inside a single coordinated write** — and hand back
    /// whatever `body` computed from the mutated store.
    ///
    /// Previously this was `read()` then `write()`, two separate coordinations with
    /// a gap between them, and the gap lost updates: tap the stove and then the
    /// door on the medium widget and the second read could precede the first write,
    /// dropping a confirmation the button had already acknowledged. Same race
    /// between the app and the extension — an archive could vanish under a tap.
    ///
    /// The return value exists so a caller working under a tight budget — a
    /// background wake, not a full app launch — can derive what it needs (e.g.
    /// which items now need a notification) from this access instead of opening
    /// a second one. A second `read()` after `mutate()` is not just wasteful:
    /// `read()` flattens any failure to an empty store, so a caller that treats
    /// that read as a decision cannot tell "nothing is due" from "the read failed".
    @discardableResult
    public static func mutate<T>(_ body: (inout Store) -> T) throws -> T {
        try coordinatedWrite { url in
            var store = try decode(from: url)
            let result = body(&store)
            return (store, result)
        }
    }

    /// One coordinated write around the whole read-modify-write.
    private static func coordinatedWrite<T>(_ body: (URL) throws -> (Store, T)) throws -> T {
        var thrown: Error?
        var coordinationError: NSError?
        var result: T?
        NSFileCoordinator().coordinate(
            writingItemAt: storeURL, options: .forReplacing, error: &coordinationError
        ) { url in
            do {
                let (store, value) = try body(url)
                try encode(store, to: url)
                result = value
            } catch { thrown = error }
        }
        if let coordinationError { throw coordinationError }
        if let thrown { throw thrown }

        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(changeNotification as CFString),
            nil, nil, true
        )
        // Reachable only once `thrown` is confirmed nil above: `body` always
        // returns a `result` on that path.
        return result!
    }

    /// Uncoordinated: both callers are already inside a coordination block, and
    /// nesting a second coordinator on the same file deadlocks.
    ///
    /// Internal rather than private so the absent-versus-corrupt distinction can be
    /// tested against a temp file. The coordination around it still needs an App
    /// Group container and stays untestable here.
    static func decode(from url: URL) throws -> Store {
        // Absent is not corrupt. This is first run, and an empty store is correct.
        guard FileManager.default.fileExists(atPath: url.path) else { return Store() }
        var store = try decoder.decode(Store.self, from: migratingLegacyResetRuleKey(Data(contentsOf: url)))
        // Both processes read through here, so the board and the widget can never
        // disagree about which language they are in. Not written back on its own —
        // the next `mutate` persists it.
        store.localizeChipCopy()
        return store
    }

    private static func encode(_ store: Store, to url: URL) throws {
        // The protection class was previously whatever the container defaulted to.
        // Stated outright now, because the choice is load-bearing: `complete` would
        // be stronger but would stop the lock screen widget reading while locked,
        // which is the only reason that widget exists.
        try encoder.encode(store).write(
            to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }

    /// For carrying a `Store` somewhere with no App Group container of its own —
    /// the watch, over `WCSession`. Same wire format as the file on disk, just
    /// without the file.
    public static func encoded(_ store: Store) throws -> Data {
        try encoder.encode(store)
    }

    /// The watch has no file to coordinate around, so this is `decode(from:)`
    /// without the `NSFileCoordinator` half.
    public static func decoded(_ data: Data) throws -> Store {
        var store = try decoder.decode(Store.self, from: migratingLegacyResetRuleKey(data))
        store.localizeChipCopy()
        return store
    }

    /// `ResetRule.onLeavingHome` was renamed to `.onComingHome` (the reset trigger
    /// moved from departure to arrival — see decisions.md). The old case name is a
    /// literal JSON key (`{"onLeavingHome":{}}`) in any store written before this
    /// change, and Swift's synthesized `Decodable` throws on an unrecognised case
    /// rather than skipping it — which `load()`'s absent-vs-corrupt distinction
    /// then reports as a corrupt file, taking the whole board down.
    ///
    /// Rewriting the raw bytes rather than hand-rolling `ResetRule`'s `Decodable`
    /// conformance: the key only ever appears as this exact quoted enum tag, never
    /// as user-typed content, so a plain substring replace is precise and avoids
    /// reproducing Swift's synthesized wire format by hand.
    private static func migratingLegacyResetRuleKey(_ data: Data) -> Data {
        guard let text = String(data: data, encoding: .utf8), text.contains("\"onLeavingHome\"")
        else { return data }
        return Data(text.replacingOccurrences(of: "\"onLeavingHome\"", with: "\"onComingHome\"").utf8)
    }

    static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        #if DEBUG
        e.outputFormatting = .prettyPrinted   // inspectable during development
        #endif
        return e
    }

    static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

/// Widget kind, shared so the app and the extension cannot drift apart.
public enum WidgetKind {
    public static let board = "DidIWidget"
}
