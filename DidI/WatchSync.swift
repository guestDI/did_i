import Foundation
import WatchConnectivity
import WidgetKit
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

    /// The watch has no App Group access, so every confirm/clear it makes
    /// arrives here to actually apply. Runs through the same `StoreIO.mutate`
    /// the app and widget already share — this is just one more caller of
    /// it, on the phone process, so no new race is introduced.
    ///
    /// Stays fully `nonisolated` rather than hopping to `@MainActor`:
    /// `StoreIO` and `WidgetCenter` need no actor, and under Swift 6 strict
    /// concurrency, capturing the task-isolated `replyHandler` into a
    /// `Task { @MainActor in }` closure is flagged as a data race — calling
    /// it directly, synchronously, in this method's own isolation avoids
    /// that entirely.
    nonisolated func session(
        _ session: WCSession, didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let action = WatchActionDecoding.decode(message) else {
            replyHandler(["ok": false])
            return
        }
        guard let store = try? StoreIO.mutate({ store -> Store in
            WatchActionDecoding.apply(action, to: &store, at: .now)
            // `Store.usage` is documented "local only, never transmitted" — strip
            // it from the reply so the watch never receives local-only counters.
            var strippedStore = store
            strippedStore.usage = Usage()
            return strippedStore
        }) else {
            replyHandler(["ok": false])
            return
        }
        WidgetCenter.shared.reloadAllTimelines()
        guard let data = try? StoreIO.encoded(store) else {
            replyHandler(["ok": false])
            return
        }
        replyHandler(["ok": true, "store": data])
    }
}
