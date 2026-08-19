import Foundation
import WatchConnectivity
import DidICore
import Observation

/// The watch's only source of truth: whatever the phone last pushed. No file,
/// no App Group — `WCSession.default.applicationContext` already caches the
/// last delivery, so a relaunch has something to show before any new message
/// arrives.
@MainActor
@Observable
final class WatchStore: NSObject {
    static let shared = WatchStore()

    private(set) var store = Store()

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        if let data = WCSession.default.receivedApplicationContext["store"] as? Data {
            apply(data)
        }
    }

    private func apply(_ data: Data) {
        guard let decoded = try? StoreIO.decoded(data) else { return }
        store = decoded
    }
}

extension WatchStore: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?
    ) {
        guard let data = session.receivedApplicationContext["store"] as? Data else { return }
        Task { @MainActor in self.apply(data) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["store"] as? Data else { return }
        Task { @MainActor in self.apply(data) }
    }
}
