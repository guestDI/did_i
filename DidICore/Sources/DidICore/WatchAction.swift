import Foundation

/// A watch-initiated action, decoded from a `WCSession` message dictionary.
/// The watch has no App Group access, so it never mutates `Store` itself —
/// it sends one of these to the phone, which applies it via `StoreIO.mutate`
/// and replies with the result. See `WatchSync.session(_:didReceiveMessage:replyHandler:)`.
public enum WatchAction: Equatable, Sendable {
    case confirm(id: UUID)
    case clear(id: UUID)
}

public enum WatchActionDecoding {
    /// `nil` for anything malformed — an unknown action, a missing or
    /// non-UUID id. The caller replies with failure rather than guessing.
    public static func decode(_ message: [String: Any]) -> WatchAction? {
        guard let action = message["action"] as? String,
              let idString = message["id"] as? String,
              let id = UUID(uuidString: idString)
        else { return nil }
        switch action {
        case "confirm": return .confirm(id: id)
        case "clear": return .clear(id: id)
        default: return nil
        }
    }

    public static func apply(_ action: WatchAction, to store: inout Store, at date: Date) {
        switch action {
        case .confirm(let id): store.confirm(id: id, at: date)
        case .clear(let id): store.clearCurrentStatus(id: id)
        }
    }
}
