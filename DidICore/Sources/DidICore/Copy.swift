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
        t("Logged. Your confirmation is on the record."),
        t("Done. Future you has a timestamp now."),
        t("Noted. One less thing to remember."),
        t("Confirmed. Look at you, adulting."),
        t("Got it. The board has your back."),
        t("Recorded for posterity and peace of mind."),
        t("Yep. Consider the check logged."),
        t("Marked. Past you left a receipt."),
        t("Filed under \"confirmed\"."),
        t("Done. That's one less thing rattling around in there."),
        t("Locked in. Go be somewhere else now."),
        t("Confirmed. Genuinely, well done."),
    ]

    /// Used only when the same item is confirmed 3+ times in one day.
    public static let escalation = [
        t("Third confirmation today. Latest one logged."),
        t("Confirmed again. The newest timestamp is on the board."),
        t("Updated. This confirmation replaces the last."),
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

    public static let boardFooter =
        t("Green means a current confirmation · amber means no current record")

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
        /// day-0-install.md says "Nothing leaves your phone." It cannot: App Group
        /// containers are included in iCloud backups, so the store — home
        /// coordinate included — does leave the device, encrypted, in the user's own
        /// backup. Excluding it from backup would make the sentence true at the cost
        /// of wiping the board on every device migration, which is a worse trade for
        /// a promise that can simply be stated accurately instead. No account and no
        /// server is the part that matters, and that part is absolutely true.
        public static let footer = t("No account. Nothing is sent to a server.")
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
        public static let showMe = t("View steps")
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

        /// Deliberately not a sixth numbered step: placement is a sequence, this
        /// is a footnote about a widget that is already there. The gallery now
        /// offers one entry per item, so this only matters for changing your mind.
        public static let whichItem =
            t("The small widget shows one item. Long-press it → Edit Widget to change which.")

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

    /// The small widget's header row is not the confirm button — it opens the app.
    /// Sighted users get that from the layout; VoiceOver needs it said.
    public static let openHint = t("Double tap to open Did I?")

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
        /// Same correction as `Screen1.footer`: the coordinate is in the App Group
        /// container, which iCloud backs up, so "never leaves your phone" was the
        /// one claim in the product that was not true — and this is the screen where
        /// it is doing the most work.
        public static let body =
            t("Instead of a fixed time, we can clear your confirmations when you leave home — so a green tick always means \"since I left\". That needs your location, and it's never sent to a server.")
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
        public static let saved = t("Home saved.")
        public static let confirmed =
            t("Home is set. Leaving home clears the board automatically.")
        /// A fix can fail indoors or in airplane mode. Say so; do not guess.
        public static let noFix = t("Couldn't get a location just now. Try again from here, or later.")
    }

    public enum LocationDeclined {
        public static let message = t("No problem. We'll keep expiring things overnight instead.")
    }

    /// The escape hatch, always available on an unknown item while away.
    public static let cantCheckRightNow = t("Can't check right now")
    public static let askSomeoneAtHome = t("Ask someone at home")
    public static let mutedUntilHome = t("Muted from the summary until you're home.")
    /// No geofence, so "until you're home" would be a promise nothing can keep:
    /// without region entry the mute has to end on the next confirmation instead.
    public static let mutedUntilConfirmed = t("Muted from the summary until you confirm it.")

    /// Pre-fills a share sheet. Names that do not start with an article read a
    /// little clipped ("is front door locked?"); it is an editable draft, not a
    /// sent message, so the user fixes it in the half-second before sending.
    public static func shareMessage(item: Item) -> String {
        t("Random question — is \(item.name) \(item.word.lowercased())?")
    }

    // MARK: - Item settings

    /// Day 2 introduces this editor, and only on Day 2. Named in the app's own
    /// vocabulary — "tick", not "confirmation expiry" — because the row sits in a
    /// menu of plain verb phrases and "forget this" could mean the item or its
    /// history. Each option is a self-contained phrase, not a fragment completing
    /// the header: sentence-completion breaks on two of the five in English and
    /// on case agreement in pl/ru.
    public static let confirmationExpiryTitle = t("How long a tick lasts")
    public static let confirmationExpiryPrompt = t("When a tick stops counting")
    public static let confirmationExpiryFooter =
        t("Applies to future confirmations. The status currently on the board will not change.")
    public static let leavingExpiryUnavailable =
        t("Leaving-home expiry needs Always Location access.")
    public static let editItem = t("Edit item")

    /// The pointer to the editor. Belongs to the reset rule, not to the location
    /// branch it used to live in — someone who granted location needs it too.
    public static let resetRuleHint =
        t("On the board, open an item's More menu → \"Edit item\" → \"How long a tick lasts\".")

    /// Archive, never delete. The footer is the promise that makes the button safe.
    public static let putItAway = t("Put it away")
    public static let putItAwayFooter = t("It leaves the board. You can bring it back any time.")

    /// Confirmation before the menu action takes effect — one tap in a menu has
    /// no undo affordance of its own, so the promise from `putItAwayFooter` has
    /// to land before the tap, not after it.
    public static func putItAwayTitle(item: Item) -> String {
        t("Put \(item.name) away?")
    }

    /// Board order is the widget's tap-target order, so it has to be editable.
    public static let moveUp = t("Move up")
    public static let moreActions = t("More actions")

    public static let widgetHelpRow = t("How to add the widget")

    /// The Control Center control is single-item and offers no in-place way to
    /// say "add another" — the gallery just shows "Did I?" once. Without this,
    /// nothing hints that adding it again with a different item is the way to
    /// cover more than one thing from Control Center.
    public static let controlCenterHint =
        t("Also works from Control Center — add it again for each item you want to confirm from there.")
    public static let neverWarning = t("A tick that never expires is a tick you can't trust.")
    public static let nameFieldTitle = t("Name")
    public static let nameFieldFooter = t("Keep it short — long names break the widget.")
    public static let nameAlreadyUsed = t("That name is already on your board or in Previously.")

    /// The word the board spells out. Not in the docs; the design's board needs it.
    public static let wordFieldTitle = t("Status word")
    public static let wordFieldFooter = t("What the board says when this is confirmed.")
    public static let wordFieldRequired = t("Add a status word so the confirmed state stays clear.")

    /// `locale` is injected for the same reason `now` and `calendar` are: the
    /// hour renders as "4 AM" or "04" depending on the region, so a test that
    /// reads the ambient locale asserts something different on every machine.
    public static func confirmationExpiry(
        _ rule: ResetRule,
        locale: Locale = .current
    ) -> String {
        switch rule {
        case .onLeavingHome: t("When I leave home (24 hours at most)")
        case .afterHours(let n): t("\(n) hours after I confirm")
        case .dailyAt(let hour): t("At \(clockHour(hour, locale: locale)) each day")
        case .never: t("Never (only when I confirm again)")
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
    public static let cancel = t("Cancel")
    public static let close = t("Close")
    public static let back = t("Back")
    public static let addAnItem = t("Add an item")
    public static let pickOne = t("Pick one.")
    public static let whichOneGoes = t("Which one goes?")
    public static let dismiss = t("Dismiss")
    public static let ok = t("OK")
    public static let settings = t("Settings")
    public static let saveFailedTitle = t("Couldn't save that")
    public static let saveFailedBody = t("Your previous record is unchanged. Try again.")
    public static let loadFailedTitle = t("Couldn't open your board")
    public static let loadFailedBody = t("We didn't change your records. Try again.")
    public static let tryAgain = t("Try again")

    /// The board's two column headings.
    public static let columnItem = t("Item")
    public static let columnStatus = t("Status")

    public enum Reminder {
        public static let section = t("Reminders")
        public static let toggle = t("Remind me when I leave")
        public static let footer = t("One notification, when you leave and this has no record.")
        /// Notifications switched off in iOS Settings after a reminder was turned
        /// on. The toggle is left alone — the same call as an unavailable
        /// leaving-home expiry: keep what they chose, say why it cannot run, and
        /// offer the way back. Clearing it silently would hide the failure and
        /// throw away the intent.
        public static let notificationsOff =
            t("Notifications are off, so these reminders can't reach you.")
    }

    public enum HomeSettings {
        public static let section = t("Home")
        public static let notSet = t("Not set")
        public static let isSet = t("Home is set")
        public static let reset = t("Reset home location")
        public static let openSystemSettings = t("Open iOS Settings")
        /// Shown when location was granted and later revoked in iOS Settings.
        public static let revoked = t("Location is off, so we're expiring things on a timer instead.")
        /// `whenInUse` without `always`: exit events only arrive in the foreground.
        public static let foregroundOnly = t("Leaving home clears the board only while the app is open.")

        public static let radiusLabel = t("Home area size")
        /// A flat and a house with a garden are both "home" at different scales,
        /// so the fixed default is explained as a default, not asserted as fact.
        public static let radiusFooter =
            t("How far from the centre point still counts as home. A bigger property may need more room before \"left home\" fires.")
    }

    public enum TipJar {
        public static let section = t("Support")
        /// `%@` is the StoreKit-provided localized price string, not a hardcoded
        /// amount — the product's real price is the source of truth.
        public static func rowTitle(price: String) -> String {
            String(format: t("Buy me a coffee — %@"), price)
        }
        public static let thanksTitle = t("Thanks!")
        public static let thanksBody = t("This app has no ads, no subscription, and never will. A tip like this is the only way to say thanks — genuinely appreciated.")
        public static let errorTitle = t("Something went wrong")
        public static let errorBody = t("The tip didn't go through. Try again later.")
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
    public static let previousConfirmationRestored =
        t("Latest confirmation removed. Previous one remains.")
    public static let undo = t("Undo latest confirmation")

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
            t("Most checked: \(item.name). \(checks) checks.")
        }

        public static func runnerUp(item: Item, checks: Int) -> String {
            t("Next: \(item.name). \(checks) checks.")
        }

        public static func reassurance(item: Item) -> String {
            t("\(item.name): confirmed at least once this week.")
        }

        public static func closing(totalChecks: Int) -> [String] {
            [
                t("\(totalChecks) checks this week. Each one has a timestamp."),
                t("\(totalChecks) checks recorded. The latest ones are on the board."),
                t("A week of confirmations, kept on your phone."),
            ]
        }
    }

    /// One honest sentence, once, and then get out of the way. No resources, no
    /// diagnosis, no follow-up.
    /// The name leads, so the sentences never have to agree with it. The closing
    /// clause used to say "will still be off" for every item, which was wrong for
    /// a door; it takes the item's own word now.
    static func escalatingChecks(item: Item) -> String {
        t("\(item.name). You've been checking this a lot lately. This app is meant to end the checking, not become the thing you check. If it isn't helping, it's fine to put it away.")
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
