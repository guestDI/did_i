import UIKit
import UserNotifications
import DidICore

/// Exists for one reason: a region exit relaunches a terminated app, and the
/// `CLLocationManager` and its delegate must be constructed **synchronously
/// during launch**, before any `await`, or the event is dropped. In SwiftUI that
/// means an `@UIApplicationDelegateAdaptor`, not a `.task` modifier.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Set when a notification tap asked for the widget walkthrough.
    static let openWalkthrough = Notification.Name("DidIOpenWalkthrough")

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
            [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Synchronous. No await above this line.
        MainActor.assumeIsolated {
            LocationMonitor.shared.start()
        }
        UNUserNotificationCenter.current().delegate = self
        return true
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// The nudge deep-links to the install walkthrough, not the main screen.
    /// `nonisolated` because `UIApplicationDelegate` conformance pulls the class
    /// onto the main actor, and these callbacks arrive from outside it.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let wantsWalkthrough =
            response.notification.request.content.userInfo[Notifications.walkthroughKey]
                as? Bool == true
        guard wantsWalkthrough else { return }
        await MainActor.run {
            NotificationCenter.default.post(name: Self.openWalkthrough, object: nil)
        }
    }

    /// Shown even in the foreground: the leaving-home reminder arrives seconds
    /// after the exit, and the app may still be warm in the user's hand.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
