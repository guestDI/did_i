import Foundation

/// Every user-facing string, identical in both processes.
///
/// The pools are a designed artefact, not placeholder text — see day-0-install.md.
/// Strings are stored in the case the docs wrote them. Where the design renders the
/// board in caps, the *view* applies `.textCase(.uppercase)`; this file never
/// pre-shouts, so the copy stays greppable against the docs.
public enum Copy {

    // MARK: - Confirmation lines

    /// Shown once, on the onboarding practice tap only.
    public static let onboardingConfirmation =
        "Nice. Now go about your day, you magnificent adult."

    /// The general pool, used everywhere after onboarding.
    public static let general = [
        "Logged. The stove is off. The world is safe. Ish.",
        "Done. Future you says thanks and means it.",
        "Noted. You're doing better than you think.",
        "Confirmed. Look at you, adulting.",
        "Got it. Nothing is on fire, probably because of you.",
        "Recorded for posterity and for your peace of mind.",
        "Yep. Consider it handled.",
        "Marked. Your past self was reliable after all.",
        "Filed under \"things that are fine\".",
        "Done. That's one less thing rattling around in there.",
        "Locked in. Go be somewhere else now.",
        "Confirmed. Genuinely, well done.",
    ]

    /// Used only when the same item is confirmed 3+ times in one day.
    public static let escalation = [
        "Third time today. It was off the first time too, but sure.",
        "We've done this. I'm not judging. I'm barely even counting.",
        "Still off. Still fine. Still you.",
    ]

    /// Rotating and random, never the same line twice in a row.
    ///
    /// No-repeat is enforced by removing `avoiding` from the candidates rather than
    /// by resampling, so it is a guarantee rather than a probability. The caller
    /// persists the result — see `Store.confirm` — because the line has to stay put
    /// across every widget timeline entry for one confirmation.
    public static func confirmationLine(escalating: Bool, avoiding previous: String?) -> String {
        let pool = escalating ? escalation : general
        return pool.filter { $0 != previous }.randomElement() ?? pool[0]
    }

    // MARK: - Item status

    /// day-2 tone rules. Humour is a reward for being fine, never a comment on
    /// being uncertain, so the joke pool reaches only `.fresh`.
    ///
    /// `isAway` defaults to `false` because the away line — "No record *since you
    /// left*" — presupposes a geofence that knows they left. With no home set that
    /// sentence is not merely risky, it is untrue, so the light line is both the
    /// safe answer and the correct one. Phase 5 passes `true` after a region exit.
    ///
    /// Note the light line is light, not funny: the joke pool never reaches
    /// `.unknown` in either direction.
    public static func status(for state: ItemState, item: Item, isAway: Bool = false) -> String {
        switch state {
        case .unknown:
            isAway ? unknownAway : unknownAtHome
        case .confirmed(let age, .fresh):
            item.confirmationLine ?? confirmedAgo(word: item.word, age: age)
        case .confirmed(let age, .aging):
            confirmedAgo(word: item.word, age: age)
        }
    }

    public static let unknownAtHome = "No record yet. Easy fix."
    public static let unknownAway = "No record since you left. That's not the same as leaving it on."

    /// Mild, no jokes: "Off, 6 hours ago."
    public static func confirmedAgo(word: String, age: TimeInterval) -> String {
        let subject = word.prefix(1).uppercased() + word.dropFirst().lowercased()
        return "\(subject), \(elapsed(age)) ago."
    }

    static func elapsed(_ age: TimeInterval) -> String {
        let minutes = max(0, Int(age / 60))
        if minutes < 1 { return "a moment" }
        if minutes < 60 { return "\(minutes) minute\(minutes == 1 ? "" : "s")" }
        let hours = minutes / 60
        return "\(hours) hour\(hours == 1 ? "" : "s")"
    }

    /// The board's clipped corner units: "14M", "6H". Design chrome, not prose.
    public static func shortAge(_ age: TimeInterval) -> String {
        let minutes = max(0, Int(age / 60))
        if minutes < 1 { return "NOW" }
        if minutes < 60 { return "\(minutes)M" }
        return "\(minutes / 60)H"
    }

    public static let boardFooter = "Ticks expire overnight · green means since you left"

    /// accessoryRectangular's whole content. Counts records, never behaviour —
    /// "handled" means there is a confirmation, not that anything was done.
    public static func summary(handled: Int, of total: Int) -> String {
        if total == 0 { return "Nothing on the board" }
        if handled == total { return "All \(total) handled" }
        return "\(handled) of \(total) handled"
    }

    // MARK: - Onboarding (day-0-install.md, verbatim)

    /// There is no Screen 0. No splash, no logo animation, no "Welcome to Did I?".
    public enum Screen1 {
        public static let title = "What did you last go back home to check?"
        public static let subtitle = "Pick one. You can add more later, but you probably won't."
        public static let footer = "No account. Nothing leaves your phone."
        /// A real example, not a repeat of the label.
        public static let placeholder = "The garage door"
        public static let returnKey = "Add"
    }

    public enum Screen2 {
        public static let title = "Try it once"
        public static let subtitle = "This is the whole app. There's no step four."
        public static let footer = "Hold to undo. Everything resets overnight."
        public static let loggedJustNow = "logged just now"
    }

    public enum Screen3 {
        public static let title = "Put it where you'll look"
        public static let subtitle = "The widget answers without opening anything."
        public static let steps = "Long-press your home screen → Edit → Add widget → search \"Did I?\""
        public static let showMe = "Show me"
        public static let later = "Later"

        /// The doc calls for a 4–6s looping video here. There is no asset, so the
        /// same five beats are shown as captions. See decisions.md.
        public static let walkthrough = [
            "Long-press an empty part of your home screen.",
            "Tap Edit in the corner.",
            "Tap Add widget.",
            "Search for \"Did I?\".",
            "Pick a size and place it.",
        ]

        public static let nudgeTitle = "Want a nudge tomorrow morning?"
        public static let nudgeBody =
            "We'll remind you once, around the time you'd be leaving the house. Once. Then never again."
        public static let yesOnce = "Yes, once"
        public static let noThanks = "No thanks"
    }

    /// VoiceOver, per the Day 0 edge cases: the practice tap is one button.
    public static func confirmLabel(item: Item) -> String {
        "Confirm \(item.name.lowercased()) is \(item.word.lowercased())"
    }

    public static let confirmHint = "Double tap to log"

    // MARK: - Day 2 (day-2-decay-and-location.md, verbatim)

    /// "Your stove confirmation aged out at 4am". The doc writes the possessive
    /// without the article, so a leading "The " is dropped and the first letter
    /// lowercased — "The stove" reads as "Your stove confirmation".
    static func bareName(_ name: String) -> String {
        var bare = name
        for article in ["The ", "the "] where bare.hasPrefix(article) {
            bare = String(bare.dropFirst(article.count))
        }
        return bare.prefix(1).lowercased() + bare.dropFirst()
    }

    public enum Lesson {
        /// Item name interpolated. If several aged out, the name is dropped.
        public static func title(items: [Item], hour: Int?) -> String {
            let when = hour.map { " at \(clockHour($0))" } ?? ""
            guard items.count == 1, let only = items.first else {
                return "Your confirmations aged out\(when)"
            }
            return "Your \(bareName(only.name)) confirmation aged out\(when)"
        }

        public static let body =
            "Old checkmarks lie. A green tick from yesterday tells you nothing about today, so we expire them overnight and start fresh."
        /// Waking up to "unknown" reads as failure. It isn't, and it can't know.
        public static let footer = "Nothing went wrong. This is the app working."
        public static let button = "Makes sense"
    }

    public enum LocationAsk {
        public static let title = "Want it to reset when you actually leave?"
        public static let body =
            "Instead of a fixed time, we can clear your confirmations when you leave home — so a green tick always means \"since I left\". That needs your location, and it never leaves your phone."
        public static let use = "Use my location"
        public static let keepTimer = "Keep the timer"

        /// architecture §6: background region events require `always`, so this is
        /// a second, later ask rather than optional politeness.
        public static let alwaysReason =
            "so we can clear the board when you leave, even with the app closed"
        public static let alwaysTitle = "One more thing"
        public static let alwaysButton = "Allow while closed"
        public static let alwaysSkip = "Not now"
    }

    public enum HomeSetup {
        public static let title = "Where's home?"
        public static let body =
            "Tap \"Set as home\" while you're there. We'll remember the spot, not the address."
        public static let set = "Set as home"
        public static let notHome = "I'm not home right now"
        public static let confirmed = "Home set. From now on, leaving the house clears the board."
    }

    public enum LocationDeclined {
        public static let message = "No problem. We'll keep expiring things overnight instead."
        /// Shown silently, once.
        public static let settingsHint =
            "You can change how each item expires in Settings → any item → \"Forget this after\"."
    }

    /// The escape hatch, always available on an unknown item while away.
    public static let cantCheckRightNow = "Can't check right now"
    public static let askSomeoneAtHome = "Ask someone at home"

    /// Pre-fills a share sheet. Names that do not start with an article read a
    /// little clipped ("is front door locked?"); it is an editable draft, not a
    /// sent message, so the user fixes it in the half-second before sending.
    public static func shareMessage(item: Item) -> String {
        "Random question — is \(item.name.lowercased()) \(item.word.lowercased())?"
    }

    // MARK: - Item settings

    /// day-2 introduces this editor, and only on day 2: "How long until this
    /// expires?" is unanswerable about a thing you've owned for nine seconds.
    public static let forgetAfterTitle = "Forget this after"
    public static let neverWarning = "A tick that never expires is a tick you can't trust."
    public static let nameFieldTitle = "Name"
    public static let nameFieldFooter = "Keep it short — long names break the widget."

    /// The word the board spells out. Not in the docs; the design's board needs it.
    public static let wordFieldTitle = "Status word"
    public static let wordFieldFooter = "What the board says when this is confirmed."

    public static func forgetAfter(_ rule: ResetRule) -> String {
        switch rule {
        case .onLeavingHome: "When I leave home"
        case .afterHours(let n): "\(n) hours"
        case .dailyAt(let hour): "Every night at \(clockHour(hour))"
        case .never: "Never"
        }
    }

    static func clockHour(_ hour: Int) -> String {
        let suffix = hour < 12 ? "am" : "pm"
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return "\(twelve)\(suffix)"
    }

    /// Spoken after a hold-to-undo. Not in the docs — invented, and deliberately
    /// flat: undoing is a correction, not an achievement.
    public static let undone = "Undone. No record now."

    // MARK: - Notifications

    /// Two categories exist in the whole app. These are their strings.
    public struct Notification: Sendable, Equatable {
        public let title: String
        public let body: String
    }

    /// day-1: the one-shot widget nudge. One picked at random at schedule time.
    public static let widgetNudges = [
        Notification(
            title: "Your widget is still homeless",
            body: "Two taps and it lives on your home screen. Long-press → Edit → Add widget."
        ),
        Notification(
            title: "The app works better when you can see it",
            body: "Long-press your home screen, hit Edit, add the widget. Ten seconds."
        ),
        Notification(
            title: "Quick one before you head out",
            body: "Add the widget so you never have to open this app again. Long-press → Edit → Add widget."
        ),
    ]

    public static func widgetNudge() -> Notification {
        widgetNudges.randomElement() ?? widgetNudges[0]
    }

    /// The per-item leaving-home reminder. The docs specify the trigger and the
    /// tone but never wrote the string — invented, and kept to the day-2 away
    /// register: plain, factual, zero jokes. See decisions.md.
    public static func leavingHomeReminder(item: Item) -> Notification {
        Notification(
            title: "No record for \(item.name.lowercased())",
            body: unknownAway
        )
    }
}

// MARK: - Day 3+ (day-3-plus-repeat-use.md, verbatim)

public extension Copy {
    /// "checking the iron", "is the front door locked?" — item names come from
    /// the Day 0 chips as "The stove", "Front door", "Iron", so an article is
    /// added unless one is already there.
    static func withArticle(_ name: String) -> String {
        let lower = name.lowercased()
        return lower.hasPrefix("the ") ? lower : "the \(lower)"
    }

    static func sentenceCased(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    enum SecondItemPrompt {
        public static let title = "You've opened this a few times today"
        public static let body = "Anything else worth keeping an eye on?"
        public static let decline = "Not right now"
    }

    enum Cap {
        public static let title = "That's six things"
        public static let body =
            "This app works because the list is short enough to trust at a glance. Want to swap something out instead?"
        public static let swap = "Swap one out"
        public static let neverMind = "Never mind"

        /// "Windows — last confirmed 12 days ago." Shown so the choice is informed.
        public static func usage(item: Item, now: Date) -> String {
            guard let last = item.lastConfirmedAt else {
                return "\(item.name) — never confirmed"
            }
            let days = Int(now.timeIntervalSince(last) / 86_400)
            if days < 1 { return "\(item.name) — last confirmed today" }
            return "\(item.name) — last confirmed \(days) day\(days == 1 ? "" : "s") ago"
        }
    }

    enum Paranoia {
        public static let title = "This week"

        public static func topWorry(item: Item, checks: Int) -> String {
            "Top worry: \(withArticle(item.name)). \(checks) checks."
        }

        public static func runnerUp(item: Item, checks: Int) -> String {
            "Runner-up: \(withArticle(item.name)), a modest \(checks)."
        }

        public static func reassurance(item: Item) -> String {
            "\(sentenceCased(withArticle(item.name))) was fine every single time. It's always fine."
        }

        public static let closing = [
            "You checked 61 times. It was off 61 times. Just saying.",
            "Perfect record. Zero disasters. One slightly tired phone.",
            "Everything was fine, every time, all week.",
        ]
    }

    /// One honest sentence, once, and then get out of the way. No resources, no
    /// diagnosis, no follow-up.
    static func escalatingChecks(item: Item) -> String {
        let name = withArticle(item.name)
        return "You've been checking \(name) a lot lately. This app is meant to end the checking, not become the thing you check. If it isn't helping, it's fine to delete it — \(name) will still be off."
    }

    enum StaleItem {
        public static func title(item: Item) -> String {
            "\(item.name) hasn't come up in a month"
        }
        public static let body = "Want to put it away? You can bring it back any time."
        public static let archive = "Archive it"
        public static let keep = "Keep it"
    }

    static let previouslySection = "Previously"
}
