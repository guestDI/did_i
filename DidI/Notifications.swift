import UserNotifications
import WidgetKit
import DidICore

/// Two categories exist in the entire app. This file is all of them.
/// No badge count, ever — a permanent number on the home screen is an anxiety
/// generator and this app has a specific obligation not to be one.
enum Notifications {
    static let widgetNudgeID = "widget-nudge"
    static let leavingHomePrefix = "leaving-home-"

    /// Set on the nudge so tapping it deep-links to the install walkthrough
    /// rather than the main screen.
    static let walkthroughKey = "opensWalkthrough"

    static var center: UNUserNotificationCenter { .current() }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - The one-shot widget nudge

    /// Runs on every foreground. Resolves the nudge to exactly one of: scheduled,
    /// cancelled forever, or already dealt with.
    static func reconcileWidgetNudge() async {
        let store = StoreIO.read()
        guard !store.flags.widgetNudgeFired else { return }

        let widgetInstalled = await hasInstalledWidget()
        let granted = await authorizationStatus() == .authorized

        // Installed already, or permission revoked in Settings: retire the nudge.
        // iOS drops a notification silently when permission is gone, so marking it
        // fired on next open is the honest bookkeeping. Never surface either as a
        // warning banner — it is their phone.
        if widgetInstalled || !granted {
            center.removePendingNotificationRequests(withIdentifiers: [widgetNudgeID])
            try? StoreIO.mutate {
                $0.flags.widgetNudgeFired = true
                if widgetInstalled, $0.flags.widgetInstalledAt == nil {
                    $0.flags.widgetInstalledAt = .now
                }
            }
            return
        }

        guard WidgetNudge.shouldSchedule(
            flags: store.flags, widgetInstalled: false, notificationsGranted: granted
        ),
            let installedAt = store.flags.installedAt,
            let fireDate = WidgetNudge.fireDate(installedAt: installedAt)
        else { return }

        // Already queued from a previous launch.
        let pending = await center.pendingNotificationRequests()
        guard !pending.contains(where: { $0.identifier == widgetNudgeID }) else { return }

        let copy = Copy.widgetNudge()
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body = copy.body
        content.userInfo = [walkthroughKey: true]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fireDate
        )
        let request = UNNotificationRequest(
            identifier: widgetNudgeID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try? await center.add(request)
    }

    static func hasInstalledWidget() async -> Bool {
        await withCheckedContinuation { continuation in
            WidgetCenter.shared.getCurrentConfigurations { result in
                continuation.resume(returning: (try? result.get())?.isEmpty == false)
            }
        }
    }

    // MARK: - The leaving-home reminder

    /// Scheduled from the region-exit wake, a few seconds out. Opt-in per item.
    ///
    /// `due` is computed by the caller inside the same `StoreIO.mutate` that
    /// records the exit — a second `StoreIO.read()` here was a second file
    /// coordination in the tightest budget in the app, and its failure mode (an
    /// empty store) was indistinguishable from "nothing was due".
    ///
    /// `await`ed per request rather than fire-and-forget: nothing else in the
    /// background-wake call stack holds the process alive, so a request that
    /// `usernotificationsd` has not yet acknowledged when the wake ends may
    /// never be delivered. The caller pairs this with a background task
    /// assertion for exactly that reason.
    static func scheduleLeavingHomeReminders(for due: [Item]) async {
        for item in due {
            let copy = Copy.leavingHomeReminder(item: item)
            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            // The whole point is to arrive while turning back is still cheap, and
            // a Focus mode or the scheduled summary would otherwise hold it until
            // the evening. This is the only notification in the app that earns
            // the entitlement — the widget nudge deliberately does not use it.
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1

            let request = UNNotificationRequest(
                identifier: leavingHomePrefix + item.id.uuidString,
                content: content,
                // `nil`, not a 5-second interval. The five seconds bought nothing
                // and were spent at the worst possible moment — already a few
                // hundred metres from the door, waiting on region-exit latency.
                trigger: nil
            )
            try? await center.add(request)
        }
    }

    /// Backstop for the exit-triggered path above, which depends on a single
    /// background wake running to completion before the process is suspended.
    /// If that wake was skipped entirely — the app never launched for the
    /// region event, or was killed before the background task began — nothing
    /// else ever retries it, so this runs on every foreground alongside the
    /// widget nudge reconciliation.
    ///
    /// Read against iOS's own notification state, not a store flag: that is
    /// the actual source of truth for "was this ever scheduled", and matches
    /// how the widget nudge already treats iOS as the ground truth for
    /// permission and delivery state. *Delivered* counts as well as *pending* —
    /// the reminder is scheduled with no trigger, so it leaves the pending list
    /// within a second of the exit and a pending-only check would re-fire it as
    /// a duplicate banner on the next foreground.
    static func reconcileLeavingHomeReminders() async {
        let store = StoreIO.read()
        guard store.isAway else { return }
        let due = store.needingLeavingHomeReminder(now: .now)
        guard !due.isEmpty else { return }

        let queued = await Set(center.pendingNotificationRequests().map(\.identifier))
            .union(center.deliveredNotifications().map(\.request.identifier))
        let missing = due.filter { !queued.contains(leavingHomePrefix + $0.id.uuidString) }
        guard !missing.isEmpty else { return }

        await scheduleLeavingHomeReminders(for: missing)
    }

    /// Asked only when a per-item reminder is switched on — the first moment the
    /// permission buys the user something concrete.
    static func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }
}
