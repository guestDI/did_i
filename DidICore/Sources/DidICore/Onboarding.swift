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

    public static let all: [Chip] = [
        Chip(id: "stove", label: "The stove", word: "Off",
             symbol: "flame", resetRule: .dailyAt(hour: 4)),
        Chip(id: "door", label: "Front door", word: "Locked",
             symbol: "lock", resetRule: .dailyAt(hour: 4)),
        Chip(id: "iron", label: "Iron", word: "Unplugged",
             symbol: "powerplug", resetRule: .afterHours(12)),
        Chip(id: "windows", label: "Windows", word: "Shut",
             symbol: "window.vertical.closed", resetRule: .dailyAt(hour: 4)),
        Chip(id: "straightener", label: "Straightener", word: "Off",
             symbol: "flame", resetRule: .afterHours(12)),
        Chip(id: "other", label: "Something else", word: "Done",
             symbol: "checkmark", resetRule: .dailyAt(hour: 4)),
    ]

    public static var somethingElse: Chip { all[all.count - 1] }

    /// Builds the real item. `name` overrides the label for "Something else".
    public func item(named name: String? = nil, createdAt: Date) -> Item {
        Item(
            name: String((name ?? label).prefix(Item.maxNameLength)),
            word: word,
            symbol: symbol,
            resetRule: resetRule,
            createdAt: createdAt,
            order: 0
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

    public init(
        installedAt: Date? = nil,
        completedScreen: Int = 0,
        firstItemType: String? = nil,
        practiceTapCompleted: Bool = false,
        widgetPromptOutcome: WidgetPrompt? = nil,
        notificationOptIn: Bool = false,
        widgetNudgeFired: Bool = false,
        widgetInstalledAt: Date? = nil
    ) {
        self.installedAt = installedAt
        self.completedScreen = completedScreen
        self.firstItemType = firstItemType
        self.practiceTapCompleted = practiceTapCompleted
        self.widgetPromptOutcome = widgetPromptOutcome
        self.notificationOptIn = notificationOptIn
        self.widgetNudgeFired = widgetNudgeFired
        self.widgetInstalledAt = widgetInstalledAt
    }

    public static let lastScreen = 3

    public var isComplete: Bool { completedScreen >= Self.lastScreen }
}
