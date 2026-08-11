import Foundation
import DidICore

/// Bridges the Darwin notification `StoreIO.write` posts into `NotificationCenter`,
/// so the board refreshes when the widget writes while the app is in the
/// foreground — the one collision architecture §2 calls out.
enum StoreChange {
    static let name = Notification.Name("DidIStoreChanged")

    static func startListening() {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                NotificationCenter.default.post(name: StoreChange.name, object: nil)
            },
            StoreIO.changeNotification as CFString,
            nil,
            .deliverImmediately
        )
    }
}
