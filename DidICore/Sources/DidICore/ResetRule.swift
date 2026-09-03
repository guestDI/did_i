import Foundation

public enum ResetRule: Codable, Sendable, Equatable, Hashable {
    case dailyAt(hour: Int)   // default: 4
    case afterHours(Int)      // UI supports 1...72 whole hours
    case onComingHome         // requires geofence
    case never                // discouraged in UI

    public static let `default` = ResetRule.dailyAt(hour: 4)

}

/// Where "home" is, and how big a circle around it counts as "home".
///
/// One fixed radius cannot be right for everyone: a flat and a house with a
/// garden are both "home" at wildly different scales. 75m is a reasonable
/// starting guess — smaller drifts indoors on GPS noise, larger fires the
/// leaving-home nudge too late to be useful — but it is a default, not a
/// ceiling; `radius` is user-adjustable from Settings (`Copy.HomeSettings`)
/// once a home exists.
public struct HomeLocation: Codable, Sendable, Equatable {
    public static let defaultRadius: Double = 75
    /// The slider's range in Settings. CoreLocation permits far more, but
    /// nothing this app monitors needs it: below this, ordinary GPS drift
    /// starts producing false exits; above it, "left home" stops meaning
    /// anything close to the front door.
    public static let radiusRange: ClosedRange<Double> = 50...250

    public var latitude: Double
    public var longitude: Double
    public var radius: Double

    public init(latitude: Double, longitude: Double, radius: Double = defaultRadius) {
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
    }
}
