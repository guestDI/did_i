import Foundation

public enum ResetRule: Codable, Sendable, Equatable, Hashable {
    case dailyAt(hour: Int)   // default: 4
    case afterHours(Int)      // 4 or 12
    case onLeavingHome        // requires geofence
    case never                // discouraged in UI

    public static let `default` = ResetRule.dailyAt(hour: 4)

    /// The confirmation-expiry menu, in the Day 2 doc's order.
    /// `onLeavingHome` only appears when background exit detection is actually
    /// available; a saved coordinate alone cannot fulfil that promise.
    public static func choices(canDetectLeavingHome: Bool) -> [ResetRule] {
        (canDetectLeavingHome ? [.onLeavingHome] : []) + [
            .afterHours(4), .afterHours(12), .default, .never,
        ]
    }
}

/// Where "home" is. Radius is 150m by default: smaller drifts indoors, larger
/// fires the leaving-home nudge too late to be useful.
public struct HomeLocation: Codable, Sendable, Equatable {
    public var latitude: Double
    public var longitude: Double
    public var radius: Double

    public init(latitude: Double, longitude: Double, radius: Double = 150) {
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
    }
}
