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
    static func scheduleLeavingHomeReminders() {
        let store = StoreIO.read()
        let due = store.needingLeavingHomeReminder(now: .now)
        guard !due.isEmpty else { return }

        for item in due {
            let copy = Copy.leavingHomeReminder(item: item)
            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body

            let request = UNNotificationRequest(
                identifier: leavingHomePrefix + item.id.uuidString,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            )
            center.add(request)
        }
    }

    /// Asked only when a per-item reminder is switched on — the first moment the
    /// permission buys the user something concrete.
    static func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }
}
