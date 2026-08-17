import Foundation

/// Screen 1's chips, in the doc's order. The icon and reset rule are assigned
/// silently per chip — the user is never asked about either.
///
/// The doc names icons conceptually ("iron", "window", "check"); those are not
/// SF Symbol names, so they are mapped to real ones here and every mapping is
/// asserted against the SF Symbols catalogue in the snapshot target.
public struct Chip: Identifiable, Sendable, Equatable {
    public let id: String
    public let label: String
    public let word: String
    public let symbol: String
    public let resetRule: ResetRule

    public static var all: [Chip] { [
        Chip(id: "stove", label: t("The stove"), word: t("Off"),
             symbol: "flame", resetRule: .dailyAt(hour: 4)),
        Chip(id: "door", label: t("Front door"), word: t("Locked"),
             symbol: "lock", resetRule: .dailyAt(hour: 4)),
        Chip(id: "iron", label: t("Iron"), word: t("Unplugged"),
             symbol: "powerplug", resetRule: .afterHours(12)),
        Chip(id: "windows", label: t("Windows"), word: t("Shut"),
             symbol: "window.vertical.closed", resetRule: .dailyAt(hour: 4)),
        Chip(id: "straightener", label: t("Straightener"), word: t("Off"),
             symbol: "flame", resetRule: .afterHours(12)),
        Chip(id: "other", label: t("Something else"), word: t("Done"),
             symbol: "checkmark", resetRule: .dailyAt(hour: 4)),
    ] }

    public static var somethingElse: Chip { all[all.count - 1] }

    /// Chips for a board that already knows about some of them.
    ///
    /// Archived counts as known: the item is one tap away under "Previously",
    /// and offering its chip alongside would add a second copy under the same
    /// name while stranding the original's history. Matched by name, so a
    /// renamed item resurfaces its chip — acceptable, and better than hiding it.
    public static func available(excluding items: [Item]) -> [Chip] {
        let taken = Set(items.map { $0.name.lowercased() })
        return all.filter {
            $0.id == somethingElse.id || !taken.contains($0.label.lowercased())
        }
    }

    /// Builds the real item. `name` overrides the label for "Something else".
    ///
    /// `chipID` is recorded only when the label and word came from the chip
    /// untouched — that text is app copy and should follow the device language.
    /// A typed name is the user's, so it is never tagged and never rewritten.
    public func item(named name: String? = nil, createdAt: Date) -> Item {
        Item(
            name: String((name ?? label).prefix(Item.maxNameLength)),
            word: word,
            symbol: symbol,
            resetRule: resetRule,
            createdAt: createdAt,
            order: 0,
            chipID: name == nil && id != Chip.somethingElse.id ? id : nil
        )
    }
}

public extension Item {
    /// Longer names break the widget.
    static let maxNameLength = 24
}

/// Local-only counters (day-1 doc). Never transmitted — there is no backend and
/// that is a selling point. They exist to gate the Day 1, 2 and 3 logic.
public struct OnboardingFlags: Codable, Sendable, Equatable {
    public enum WidgetPrompt: String, Codable, Sendable {
        case installed, later, dismissed
    }

    public var installedAt: Date?
    /// Highest onboarding screen finished. A force-quit resumes here rather than
    /// restarting — making someone redo a setup is how you lose them twice.
    public var completedScreen: Int
    public var firstItemType: String?
    public var practiceTapCompleted: Bool
    public var widgetPromptOutcome: WidgetPrompt?
    public var notificationOptIn: Bool
    public var widgetNudgeFired: Bool
    public var widgetInstalledAt: Date?

    // MARK: day-2

    public var decayLessonShown: Bool
    /// Set when the user picks "Keep the timer". Never ask again — not on day 5,
    /// not on a settings banner, not with a "you're missing out" card.
    public var locationDeclined: Bool
    /// The one-time "Settings → any item → Forget this after" pointer.
    public var settingsHintShown: Bool
    /// "I'm not home right now" — ask again after a quiet period, not on the
    /// very next open.
    public var homeSetupPending: Bool
    public var homeSetupDeferredUntil: Date?

    public init(
        installedAt: Date? = nil,
        completedScreen: Int = 0,
        firstItemType: String? = nil,
        practiceTapCompleted: Bool = false,
        widgetPromptOutcome: WidgetPrompt? = nil,
        notificationOptIn: Bool = false,
        widgetNudgeFired: Bool = false,
        widgetInstalledAt: Date? = nil,
        decayLessonShown: Bool = false,
        locationDeclined: Bool = false,
        settingsHintShown: Bool = false,
        homeSetupPending: Bool = false,
        homeSetupDeferredUntil: Date? = nil
    ) {
        self.installedAt = installedAt
        self.completedScreen = completedScreen
        self.firstItemType = firstItemType
        self.practiceTapCompleted = practiceTapCompleted
        self.widgetPromptOutcome = widgetPromptOutcome
        self.notificationOptIn = notificationOptIn
        self.widgetNudgeFired = widgetNudgeFired
        self.widgetInstalledAt = widgetInstalledAt
        self.decayLessonShown = decayLessonShown
        self.locationDeclined = locationDeclined
        self.settingsHintShown = settingsHintShown
        self.homeSetupPending = homeSetupPending
        self.homeSetupDeferredUntil = homeSetupDeferredUntil
    }

    /// Hand-written for the same reason `Store`'s is: synthesised `Decodable`
    /// ignores property defaults, so every field added here would otherwise make
    /// an existing store file undecodable and silently reset someone's board.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func flag(_ key: CodingKeys) throws -> Bool {
            try c.decodeIfPresent(Bool.self, forKey: key) ?? false
        }
        installedAt = try c.decodeIfPresent(Date.self, forKey: .installedAt)
        completedScreen = try c.decodeIfPresent(Int.self, forKey: .completedScreen) ?? 0
        firstItemType = try c.decodeIfPresent(String.self, forKey: .firstItemType)
        practiceTapCompleted = try flag(.practiceTapCompleted)
        widgetPromptOutcome = try c.decodeIfPresent(WidgetPrompt.self, forKey: .widgetPromptOutcome)
        notificationOptIn = try flag(.notificationOptIn)
        widgetNudgeFired = try flag(.widgetNudgeFired)
        widgetInstalledAt = try c.decodeIfPresent(Date.self, forKey: .widgetInstalledAt)
        decayLessonShown = try flag(.decayLessonShown)
        locationDeclined = try flag(.locationDeclined)
        settingsHintShown = try flag(.settingsHintShown)
        homeSetupPending = try flag(.homeSetupPending)
        homeSetupDeferredUntil = try c.decodeIfPresent(Date.self, forKey: .homeSetupDeferredUntil)
    }

    public static let lastScreen = 3
    public static let homeSetupDeferral: TimeInterval = 24 * 60 * 60

    public var isComplete: Bool { completedScreen >= Self.lastScreen }

    public mutating func deferHomeSetup(at date: Date) {
        homeSetupPending = true
        homeSetupDeferredUntil = date.addingTimeInterval(Self.homeSetupDeferral)
    }

    public func shouldPromptForHomeSetup(at date: Date) -> Bool {
        guard homeSetupPending, !locationDeclined else { return false }
        return homeSetupDeferredUntil.map { date >= $0 } ?? true
    }
}
