import Foundation

public struct Store: Codable, Sendable {
    public var items: [Item]

    /// Set once the user picks a home. `nil` means location was never granted or
    /// was declined, which hides the "when I leave home" reset option.
    public var home: HomeLocation?

    /// Set by the region-exit background wake. `nil` until the geofence exists.
    public var lastLeftHomeAt: Date?

    /// The last confirmation line shown, so the next one can avoid it.
    /// Global rather than per-item: "never twice in a row" is about what the
    /// person just read, and they read one line at a time.
    public var lastConfirmationLine: String?

    public var flags: OnboardingFlags

    public init(
        items: [Item] = [],
        home: HomeLocation? = nil,
        lastLeftHomeAt: Date? = nil,
        lastConfirmationLine: String? = nil,
        flags: OnboardingFlags = OnboardingFlags()
    ) {
        self.items = items
        self.home = home
        self.lastLeftHomeAt = lastLeftHomeAt
        self.lastConfirmationLine = lastConfirmationLine
        self.flags = flags
    }

    /// Hand-written so a store file missing any newer key still decodes rather
    /// than throwing away someone's board. Synthesised `Decodable` ignores
    /// property defaults, which is the trap this avoids.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decodeIfPresent([Item].self, forKey: .items) ?? []
        home = try c.decodeIfPresent(HomeLocation.self, forKey: .home)
        lastLeftHomeAt = try c.decodeIfPresent(Date.self, forKey: .lastLeftHomeAt)
        lastConfirmationLine = try c.decodeIfPresent(String.self, forKey: .lastConfirmationLine)
        flags = try c.decodeIfPresent(OnboardingFlags.self, forKey: .flags) ?? OnboardingFlags()
    }

    enum CodingKeys: String, CodingKey {
        case items, home, lastLeftHomeAt, lastConfirmationLine, flags
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

        let today = (items[i].todaysConfirmations ?? [])
            .filter { calendar.isDate($0, inSameDayAs: date) } + [date]

        let line = Copy.confirmationLine(
            escalating: today.count >= 3,
            avoiding: lastConfirmationLine
        )

        items[i].todaysConfirmations = today
        items[i].lastConfirmedAt = date
        items[i].confirmationLine = line
        lastConfirmationLine = line
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
        var history = items[i].todaysConfirmations ?? []
        if !history.isEmpty { history.removeLast() }
        items[i].todaysConfirmations = history
        items[i].lastConfirmedAt = history.last
        items[i].confirmationLine = nil
    }

    public func state(_ item: Item, now: Date, calendar: Calendar = .current) -> ItemState {
        resolve(item, lastLeftHome: lastLeftHomeAt, now: now, calendar: calendar)
    }

    /// Every future instant at which any item's state changes.
    public func allBoundaries(after date: Date, calendar: Calendar = .current) -> [Date] {
        items.flatMap { boundaries(for: $0, after: date, calendar: calendar) }.sorted()
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

    /// Reads the store, seeding it if the file does not exist yet.
    /// Never throws: an unreadable store is indistinguishable from a fresh one,
    /// and the widget has no way to surface an error anyway.
    public static func read() -> Store {
        var result: Store?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: storeURL, error: &coordinationError) { url in
            guard let data = try? Data(contentsOf: url) else { return }
            result = try? decoder.decode(Store.self, from: data)
        }
        return result ?? Store()
    }

    public static func write(_ store: Store) throws {
        let data = try encoder.encode(store)
        var writeError: Error?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(
            writingItemAt: storeURL, options: .forReplacing, error: &coordinationError
        ) { url in
            do { try data.write(to: url, options: .atomic) } catch { writeError = error }
        }
        if let coordinationError { throw coordinationError }
        if let writeError { throw writeError }

        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(changeNotification as CFString),
            nil, nil, true
        )
    }

    /// Read, mutate, write. Last write wins — two writes racing means two taps
    /// milliseconds apart, and either outcome is correct.
    public static func mutate(_ body: (inout Store) -> Void) throws {
        var store = read()
        body(&store)
        try write(store)
    }

    static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601   // inspectable during development
        e.outputFormatting = .prettyPrinted
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
