import Foundation

public extension Store {
    /// Derived, not stored: they are away if the last thing the geofence saw was
    /// them leaving. No home, or no events yet, means we do not know — and not
    /// knowing is treated as being home, because the away copy claims "since you
    /// left" and that has to be true when it is shown.
    var isAway: Bool {
        guard home != nil, let left = lastLeftHomeAt else { return false }
        guard let returned = lastEnteredHomeAt else { return true }
        return left > returned
    }

    /// Region exit. The three things architecture §6 permits on a background wake
    /// start here; scheduling the reminders is the caller's job.
    mutating func leftHome(at date: Date) {
        lastLeftHomeAt = date
    }

    /// Region entry. Clears the "can't check right now" mutes — the state they
    /// were an escape from is over.
    mutating func arrivedHome(at date: Date) {
        lastEnteredHomeAt = date
        for i in items.indices where items[i].mutedUntilHome == true {
            items[i].mutedUntilHome = false
        }
    }

    /// Items the widget's summary counts. Muted items drop out, per day-2.
    var counted: [Item] {
        active.filter { $0.mutedUntilHome != true }
    }

    /// Unconfirmed items whose owner asked to be reminded on leaving.
    func needingLeavingHomeReminder(now: Date, calendar: Calendar = .current) -> [Item] {
        active.filter {
            $0.leavingHomeReminder == true
                && $0.mutedUntilHome != true
                && state($0, now: now, calendar: calendar) == .unknown
        }
    }
}

/// day-2's decay lesson. Fires on the first open where something has aged out —
/// not on a schedule, and not on "day 2" literally. If they do not open the app
/// for a week, it fires on the day they do.
public enum DecayLesson {
    /// The items the lesson is about. Empty means do not show it.
    public static func agedOut(
        in store: Store,
        now: Date,
        calendar: Calendar = .current
    ) -> [Item] {
        guard !store.flags.decayLessonShown else { return [] }
        return store.active.filter {
            // Confirmed at least once, so they have seen it green, and unknown now.
            $0.lastConfirmedAt != nil
                && store.state($0, now: now, calendar: calendar) == .unknown
        }
    }
}

/// day-1's one-shot widget nudge. Exactly one notification, ever.
public enum WidgetNudge {
    /// All four conditions from the day-1 doc, minus the one only the system can
    /// answer (is a widget installed) — the caller checks that against
    /// `WidgetCenter` and passes the result.
    public static func shouldSchedule(
        flags: OnboardingFlags,
        widgetInstalled: Bool,
        notificationsGranted: Bool
    ) -> Bool {
        !flags.widgetNudgeFired
            && !widgetInstalled
            && notificationsGranted
            && flags.notificationOptIn
            && flags.installedAt != nil
    }

    /// 08:00 local, weekdays only — nobody is rushing out the door on a Saturday,
    /// and the nudge only makes sense at the moment its value is obvious.
    ///
    /// Normally the first 08:00 at least 12 hours after install. An install after
    /// 20:00 waives the 12-hour minimum and takes the *next* morning instead of
    /// waiting an extra full day, which is how the doc's "rather than the one 12
    /// hours later" reads.
    public static func fireDate(
        installedAt: Date,
        calendar: Calendar = .current
    ) -> Date? {
        let installedLate = calendar.component(.hour, from: installedAt) >= 20
        let earliest = installedLate
            ? installedAt
            : installedAt.addingTimeInterval(12 * 3600)

        let morning = DateComponents(hour: 8, minute: 0, second: 0)
        var candidate = calendar.nextDate(
            after: earliest, matching: morning, matchingPolicy: .nextTime
        )
        // At most a week of weekend-skipping; the loop cannot run away.
        for _ in 0..<7 {
            guard let found = candidate else { return nil }
            if !calendar.isDateInWeekend(found) { return found }
            candidate = calendar.nextDate(
                after: found, matching: morning, matchingPolicy: .nextTime
            )
        }
        return nil
    }
}
