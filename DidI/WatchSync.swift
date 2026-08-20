import Foundation
import WatchConnectivity
import DidICore

/// Pushes the store to a paired watch whenever it changes. One-way,
/// phone-to-watch: the watch is a glance, not a second place to write from —
/// see day-3's "the glance is even cheaper" note. `updateApplicationContext`
/// replaces whatever it last sent rather than queuing, which is exactly the
/// right delivery semantic for "just tell the watch the current state."
@MainActor
final class WatchSync: NSObject {
    static let shared = WatchSync()

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        NotificationCenter.default.addObserver(
            forName: StoreChange.name, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in self?.push() }
        }
    }

    private func push() {
        guard WCSession.default.activationState == .activated else { return }
        var store = StoreIO.read()
        // `Store.usage` is documented "local only, never transmitted" — the
        // watch glance has no use for check counts or paranoia-counter data
        // anyway, so it never leaves the phone.
        store.usage = Usage()
        guard let data = try? StoreIO.encoded(store) else { return }
        try? WCSession.default.updateApplicationContext(["store": data])
    }
}

extension WatchSync: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?
    ) {
        Task { @MainActor in self.push() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
