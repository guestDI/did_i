import UIKit
import UserNotifications
import DidICore

/// Exists for one reason: a region exit relaunches a terminated app, and the
/// `CLLocationManager` and its delegate must be constructed **synchronously
/// during launch**, before any `await`, or the event is dropped. In SwiftUI that
/// means an `@UIApplicationDelegateAdaptor`, not a `.task` modifier.
final class AppDelegate: NSObject, UIApplicationDelegate {
    enum NotificationDestination: Equatable {
        case board
        case walkthrough
        case item(workspaceID: UUID, itemID: UUID)
    }

    static let notificationDestinationRequested =
        Notification.Name("DidINotificationDestinationRequested")

    /// Notification responses can arrive before SwiftUI has mounted `BoardView`.
    /// Keep the route until a live board consumes it; the broadcast alone is not
    /// the source of truth.
    @MainActor private static var pendingNotificationDestination: NotificationDestination?

    @MainActor static func requestNotificationDestination(_ destination: NotificationDestination) {
        pendingNotificationDestination = destination
        NotificationCenter.default.post(name: notificationDestinationRequested, object: nil)
    }

    @MainActor static func consumeNotificationDestination() -> NotificationDestination? {
        defer { pendingNotificationDestination = nil }
        return pendingNotificationDestination
    }

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
        let userInfo = response.notification.request.content.userInfo
        let wantsWalkthrough = userInfo[Notifications.walkthroughKey] as? Bool == true
        let workspaceID = (userInfo[Notifications.workspaceIDKey] as? String)
            .flatMap(UUID.init(uuidString:))
        let itemID = (userInfo[Notifications.itemIDKey] as? String)
            .flatMap(UUID.init(uuidString:))
        await MainActor.run {
            if wantsWalkthrough {
                Self.requestNotificationDestination(.walkthrough)
            } else if let workspaceID, let itemID {
                Self.requestNotificationDestination(.item(workspaceID: workspaceID, itemID: itemID))
            } else {
                Self.requestNotificationDestination(.board)
            }
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
