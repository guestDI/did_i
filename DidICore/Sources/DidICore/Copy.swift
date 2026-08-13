import Foundation

/// Every string in this file goes through here.
///
/// `bundle: .module` matters: the widget extension links DidICore, so the
/// catalog has to be looked up in the package's bundle and not in whichever
/// executable happens to be running. One helper rather than a `String(localized:)`
/// at each of ~70 sites, so the bundle can never be forgotten at one of them.
func t(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}

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
        t("Nice. Now go about your day, you magnificent adult.")

    /// The general pool, used everywhere after onboarding.
    public static let general = [
        t("Logged. The stove is off. The world is safe. Ish."),
        t("Done. Future you says thanks and means it."),
        t("Noted. You're doing better than you think."),
        t("Confirmed. Look at you, adulting."),
        t("Got it. Nothing is on fire, probably because of you."),
        t("Recorded for posterity and for your peace of mind."),
        t("Yep. Consider it handled."),
        t("Marked. Your past self was reliable after all."),
        t("Filed under \"things that are fine\"."),
        t("Done. That's one less thing rattling around in there."),
        t("Locked in. Go be somewhere else now."),
        t("Confirmed. Genuinely, well done."),
    ]

    /// Used only when the same item is confirmed 3+ times in one day.
    public static let escalation = [
        t("Third time today. It was off the first time too, but sure."),
        t("We've done this. I'm not judging. I'm barely even counting."),
        t("Still off. Still fine. Still you."),
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

    public static let unknownAtHome = t("No record yet. Easy fix.")
    public static let unknownAway = t("No record since you left. That's not the same as leaving it on.")

    /// Mild, no jokes: "Off, 6 hours ago."
    public static func confirmedAgo(word: String, age: TimeInterval) -> String {
        let subject = word.prefix(1).uppercased() + word.dropFirst().lowercased()
        return t("\(subject), \(elapsed(age)) ago.")
    }

    /// The `s`-or-nothing ternary this replaces was English-only: Russian has
    /// three plural forms and Arabic six. The catalog carries the variants.
    static func elapsed(_ age: TimeInterval) -> String {
        let minutes = max(0, Int(age / 60))
        if minutes < 1 { return t("a moment") }
        if minutes < 60 { return t("\(minutes) minutes") }
        return t("\(minutes / 60) hours")
    }

    /// The board's clipped corner units: "14M", "6H". Design chrome, not prose.
    public static func shortAge(_ age: TimeInterval) -> String {
        let minutes = max(0, Int(age / 60))
        if minutes < 1 { return t("NOW") }
        if minutes < 60 { return t("\(minutes)M") }
        return t("\(minutes / 60)H")
    }

    public static let boardFooter = t("Ticks expire overnight · green means since you left")

    /// accessoryRectangular's whole content. Counts records, never behaviour —
    /// "handled" means there is a confirmation, not that anything was done.
    public static func summary(handled: Int, of total: Int) -> String {
        if total == 0 { return t("Nothing on the board") }
        if handled == total { return t("All \(total) handled") }
        return t("\(handled) of \(total) handled")
    }

    // MARK: - Onboarding (day-0-install.md, verbatim)

    /// There is no Screen 0. No splash, no logo animation, no "Welcome to Did I?".
    public enum Screen1 {
        public static let title = t("What did you last go back home to check?")
        public static let subtitle = t("Pick one. You can add more later, but you probably won't.")
        public static let footer = t("No account. Nothing leaves your phone.")
        /// A real example, not a repeat of the label.
        public static let placeholder = t("The garage door")
        public static let returnKey = t("Add")
    }

    public enum Screen2 {
        public static let title = t("Try it once")
        public static let subtitle = t("This is the whole app. There's no step four.")
        public static let footer = t("Hold to undo. Everything resets overnight.")
        public static let loggedJustNow = t("logged just now")
    }

    public enum Screen3 {
        public static let title = t("Put it where you'll look")
        public static let subtitle = t("The widget answers without opening anything.")
        public static let steps = t("Long-press your home screen → Edit → Add widget → search \"Did I?\"")
        public static let showMe = t("Show me")
        public static let later = t("Later")

        /// The doc calls for a 4–6s looping video here. There is no asset, so the
        /// same five beats are shown as captions. See decisions.md.
        public static let walkthrough = [
            t("Long-press an empty part of your home screen."),
            t("Tap Edit in the corner."),
            t("Tap Add widget."),
            t("Search for \"Did I?\"."),
            t("Pick a size and place it."),
        ]

        public static let nudgeTitle = t("Want a nudge tomorrow morning?")
        public static let nudgeBody =
            t("We'll remind you once, around the time you'd be leaving the house. Once. Then never again.")
        public static let yesOnce = t("Yes, once")
        public static let noThanks = t("No thanks")
    }

    /// VoiceOver, per the Day 0 edge cases: the practice tap is one button.
    public static func confirmLabel(item: Item) -> String {
        t("Confirm \(item.name) is \(item.word.lowercased())")
    }

    public static let confirmHint = t("Double tap to log")

    // MARK: - Day 2 (day-2-decay-and-location.md, verbatim)

    public enum Lesson {
        /// Four whole sentences, not one sentence assembled from fragments.
        ///
        /// This used to build the title by appending " at 4am" and by stripping a
        /// leading "The " off the name to make it read as a possessive. Both are
        /// English-only: clause order moves between languages, and no other
        /// language forms a possessive by deleting its article. The name now sits
        /// in a label position, and each variant is its own key.
        public static func title(items: [Item], hour: Int?, locale: Locale = .current) -> String {
            switch (items.count == 1 ? items.first : nil, hour) {
            case (let only?, let hour?):
                t("\(only.name): confirmation aged out at \(clockHour(hour, locale: locale))")
            case (let only?, nil):
                t("\(only.name): confirmation aged out")
            case (nil, let hour?):
                t("Your confirmations aged out at \(clockHour(hour, locale: locale))")
            case (nil, nil):
                t("Your confirmations aged out")
            }
        }

        public static let body =
            t("Old checkmarks lie. A green tick from yesterday tells you nothing about today, so we expire them overnight and start fresh.")
        /// Waking up to "unknown" reads as failure. It isn't, and it can't know.
        public static let footer = t("Nothing went wrong. This is the app working.")
        public static let button = t("Makes sense")
    }

    public enum LocationAsk {
        public static let title = t("Want it to reset when you actually leave?")
        public static let body =
            t("Instead of a fixed time, we can clear your confirmations when you leave home — so a green tick always means \"since I left\". That needs your location, and it never leaves your phone.")
        public static let use = t("Use my location")
        public static let keepTimer = t("Keep the timer")

        /// architecture §6: background region events require `always`, so this is
        /// a second, later ask rather than optional politeness.
        public static let alwaysReason =
            t("so we can clear the board when you leave, even with the app closed")
        public static let alwaysTitle = t("One more thing")
        public static let alwaysButton = t("Allow while closed")
        public static let alwaysSkip = t("Not now")
    }

    public enum HomeSetup {
        public static let title = t("Where's home?")
        public static let body =
            t("Tap \"Set as home\" while you're there. We'll remember the spot, not the address.")
        public static let set = t("Set as home")
        public static let notHome = t("I'm not home right now")
        public static let confirmed = t("Home set. From now on, leaving the house clears the board.")
        /// A fix can fail indoors or in airplane mode. Say so; do not guess.
        public static let noFix = t("Couldn't get a location just now. Try again from here, or later.")
    }

    public enum LocationDeclined {
        public static let message = t("No problem. We'll keep expiring things overnight instead.")
    }

    /// The escape hatch, always available on an unknown item while away.
    public static let cantCheckRightNow = t("Can't check right now")
    public static let askSomeoneAtHome = t("Ask someone at home")

    /// Pre-fills a share sheet. Names that do not start with an article read a
    /// little clipped ("is front door locked?"); it is an editable draft, not a
    /// sent message, so the user fixes it in the half-second before sending.
    public static func shareMessage(item: Item) -> String {
        t("Random question — is \(item.name) \(item.word.lowercased())?")
    }

    // MARK: - Item settings

    /// day-2 introduces this editor, and only on day 2: "How long until this
    /// expires?" is unanswerable about a thing you've owned for nine seconds.
    public static let forgetAfterTitle = t("Forget this after")

    /// The pointer to the editor. Belongs to the reset rule, not to the location
    /// branch it used to live in — someone who granted location needs it too.
    public static let resetRuleHint =
        t("You can change how each item expires in Settings → any item → \"Forget this after\".")

    /// Archive, never delete. The footer is the promise that makes the button safe.
    public static let putItAway = t("Put it away")
    public static let putItAwayFooter = t("It leaves the board. You can bring it back any time.")

    /// Board order is the widget's tap-target order, so it has to be editable.
    public static let moveUp = t("Move up")

    public static let widgetHelpRow = t("How to add the widget")
    public static let neverWarning = t("A tick that never expires is a tick you can't trust.")
    public static let nameFieldTitle = t("Name")
    public static let nameFieldFooter = t("Keep it short — long names break the widget.")

    /// The word the board spells out. Not in the docs; the design's board needs it.
    public static let wordFieldTitle = t("Status word")
    public static let wordFieldFooter = t("What the board says when this is confirmed.")

    /// `locale` is injected for the same reason `now` and `calendar` are: the
    /// hour renders as "4 AM" or "04" depending on the region, so a test that
    /// reads the ambient locale asserts something different on every machine.
    public static func forgetAfter(_ rule: ResetRule, locale: Locale = .current) -> String {
        switch rule {
        case .onLeavingHome: t("When I leave home")
        case .afterHours(let n): t("\(n) hours")
        case .dailyAt(let hour): t("Every night at \(clockHour(hour, locale: locale))")
        case .never: t("Never")
        }
    }

    /// "4am" in English, "04:00" where the locale runs a 24-hour clock. Built by
    /// the formatter rather than by gluing a number to a translated "am", which
    /// assumed every locale has a meridiem and puts it on the right.
    static func clockHour(_ hour: Int, locale: Locale = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let date = calendar.date(from: DateComponents(hour: hour, minute: 0)) ?? Date()
        return date.formatted(.dateTime.hour().locale(locale))
    }

    // MARK: - Chrome
    //
    // These lived inline in the views until the localization pass found them.
    // "Did I?" itself is the product name and is deliberately absent: it is not
    // translated, in the header flaps or in the widget gallery.

    public static let done = t("Done")
    public static let close = t("Close")
    public static let addAnItem = t("Add an item")
    public static let pickOne = t("Pick one.")
    public static let whichOneGoes = t("Which one goes?")
    public static let dismiss = t("Dismiss")
    public static let settings = t("Settings")

    /// The board's two column headings.
    public static let columnItem = t("Item")
    public static let columnStatus = t("Status")

    public enum Reminder {
        public static let toggle = t("Remind me when I leave")
        public static let footer = t("One notification, when you leave and this has no record.")
    }

    public enum HomeSettings {
        public static let section = t("Home")
        public static let notSet = t("Not set")
        public static let isSet = t("Home is set")
        public static let reset = t("Reset home location")
        /// Shown when location was granted and later revoked in iOS Settings.
        public static let revoked = t("Location is off, so we're expiring things on a timer instead.")
        /// `whenInUse` without `always`: exit events only arrive in the foreground.
        public static let foregroundOnly = t("Leaving home clears the board only while the app is open.")
    }

    /// The widget's gallery entry. Its *configuration* strings are not here: the
    /// AppIntents metadata extractor rejects any bundle but the extension's own,
    /// so they live in DidIWidget/<locale>.lproj/Localizable.strings.
    public enum Widget {
        public static let description = t("One tap on your way out.")
    }

    /// Spoken after a hold-to-undo. Not in the docs — invented, and deliberately
    /// flat: undoing is a correction, not an achievement.
    public static let undone = t("Undone. No record now.")

    // MARK: - Notifications

    /// Two categories exist in the whole app. These are their strings.
    public struct Notification: Sendable, Equatable {
        public let title: String
        public let body: String
    }

    /// day-1: the one-shot widget nudge. One picked at random at schedule time.
    public static let widgetNudges = [
        Notification(
            title: t("Your widget is still homeless"),
            body: t("Two taps and it lives on your home screen. Long-press → Edit → Add widget.")
        ),
        Notification(
            title: t("The app works better when you can see it"),
            body: t("Long-press your home screen, hit Edit, add the widget. Ten seconds.")
        ),
        Notification(
            title: t("Quick one before you head out"),
            body: t("Add the widget so you never have to open this app again. Long-press → Edit → Add widget.")
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
            title: t("No record for \(item.name.lowercased())"),
            body: unknownAway
        )
    }
}

// MARK: - Day 3+ (day-3-plus-repeat-use.md, verbatim)

public extension Copy {
    /// There is deliberately no `withArticle` helper any more.
    ///
    /// It lowercased a user-typed noun and prefixed "the ", which is English-only
    /// grammar applied to a word we do not know the gender, number or case of.
    /// German needs der/die/das; Polish and Russian decline it differently per
    /// sentence. Every sentence that used to interpolate a name mid-clause now
    /// puts the name in a label position instead, where no language needs to
    /// agree with it. See decisions.md.

    enum SecondItemPrompt {
        public static let title = t("You've opened this a few times today")
        public static let body = t("Anything else worth keeping an eye on?")
        public static let decline = t("Not right now")
    }

    enum Cap {
        public static let title = t("That's six things")
        public static let body =
            t("This app works because the list is short enough to trust at a glance. Want to swap something out instead?")
        public static let swap = t("Swap one out")
        public static let neverMind = t("Never mind")

        /// "Windows — last confirmed 12 days ago." Shown so the choice is informed.
        public static func usage(item: Item, now: Date) -> String {
            guard let last = item.lastConfirmedAt else {
                return t("\(item.name) — never confirmed")
            }
            let days = Int(now.timeIntervalSince(last) / 86_400)
            if days < 1 { return t("\(item.name) — last confirmed today") }
            return "\(item.name) — last confirmed \(t("\(days) days")) ago"
        }
    }

    enum Paranoia {
        public static let title = t("This week")

        public static func topWorry(item: Item, checks: Int) -> String {
            t("Top worry: \(item.name). \(checks) checks.")
        }

        public static func runnerUp(item: Item, checks: Int) -> String {
            t("Runner-up: \(item.name), a modest \(checks).")
        }

        public static func reassurance(item: Item) -> String {
            t("\(item.name): fine every single time. It always is.")
        }

        public static let closing = [
            t("You checked 61 times. It was off 61 times. Just saying."),
            t("Perfect record. Zero disasters. One slightly tired phone."),
            t("Everything was fine, every time, all week."),
        ]
    }

    /// One honest sentence, once, and then get out of the way. No resources, no
    /// diagnosis, no follow-up.
    /// The name leads, so the sentences never have to agree with it. The closing
    /// clause used to say "will still be off" for every item, which was wrong for
    /// a door; it takes the item's own word now.
    static func escalatingChecks(item: Item) -> String {
        t("\(item.name). You've been checking this a lot lately. This app is meant to end the checking, not become the thing you check. If it isn't helping, it's fine to delete it — it'll still be \(item.word.lowercased()).")
    }

    enum StaleItem {
        public static func title(item: Item) -> String {
            t("\(item.name) hasn't come up in a month")
        }
        public static let body = t("Want to put it away? You can bring it back any time.")
        public static let archive = t("Archive it")
        public static let keep = t("Keep it")
    }

    static let previouslySection = t("Previously")
}

public extension Copy {
    /// The bundle every string in this file is looked up in.
    ///
    /// Exposed because AppIntents resolves `LocalizedStringResource` lazily,
    /// against a bundle it must be handed explicitly — and the widget extension
    /// has no `Bundle.module` of its own. Without this its gallery and
    /// configuration strings would be the only untranslated text in the product.
    static var bundle: Bundle { .module }
}
