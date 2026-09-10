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
    private(set) var lastError: String?

    func start() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-appStoreScreenshotBoard") {
            store = Self.appStoreScreenshotStore(now: .now)
            return
        }
        #endif
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        if let data = WCSession.default.receivedApplicationContext["store"] as? Data {
            apply(data)
        }
    }

    func confirm(id: UUID) {
        send(["action": "confirm", "id": id.uuidString])
    }

    func clear(id: UUID) {
        send(["action": "clear", "id": id.uuidString])
    }

    func clearError() {
        lastError = nil
    }

    /// Every action round-trips through the phone — the watch has no App
    /// Group access and never guesses at the result. A failure (unreachable
    /// phone, or the phone's own write failing) surfaces as `lastError`
    /// rather than a state that silently doesn't change.
    private func send(_ message: [String: Any]) {
        guard WCSession.default.activationState == .activated else {
            lastError = Copy.watchUnreachable
            return
        }
        WCSession.default.sendMessage(message, replyHandler: { [weak self] reply in
            Task { @MainActor in
                guard let self else { return }
                if reply["ok"] as? Bool == true, let data = reply["store"] as? Data {
                    self.apply(data)
                    self.lastError = nil
                } else {
                    self.lastError = Copy.watchUnreachable
                }
            }
        }, errorHandler: { [weak self] _ in
            Task { @MainActor in self?.lastError = Copy.watchUnreachable }
        })
    }

    #if DEBUG
    private static func appStoreScreenshotStore(now: Date) -> Store {
        let items = Array(Chip.all.prefix(3)).enumerated().map { order, chip in
            var item = chip.item(createdAt: now.addingTimeInterval(-14 * 86_400))
            item.order = order
            return item
        }
        var store = Store(items: items)
        store.confirm(id: items[0].id, at: now.addingTimeInterval(-5 * 60))
        store.confirm(id: items[1].id, at: now.addingTimeInterval(-2 * 3600))
        return store
    }
    #endif

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
