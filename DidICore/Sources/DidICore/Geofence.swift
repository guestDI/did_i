import Foundation

/// Pure description of one geofence ring — radius and notify flags only, no
/// CoreLocation dependency, so `LocationMonitor`'s ring math and registration
/// grace window are testable without a location manager or a real device.
public struct GeofenceRing: Equatable, Sendable {
    public let identifier: String
    public let radius: Double
    public let notifyOnEntry: Bool
    public let notifyOnExit: Bool
}

public enum Geofence {
    /// Mirrors `LocationMonitor.regions(for:)`: an outer entry+exit ring at the
    /// user's radius, plus an exit-only inner ring at `innerFactor` of it,
    /// floored at `radiusRange.lowerBound` so it never drops below the
    /// slider's own minimum. Collapses to just the outer ring if the inner
    /// one would not be smaller (radius already at the floor).
    public static func rings(
        radius: Double,
        radiusRange: ClosedRange<Double>,
        innerFactor: Double,
        outerID: String,
        innerID: String
    ) -> [GeofenceRing] {
        let clamped = min(max(radius, radiusRange.lowerBound), radiusRange.upperBound)
        let outer = GeofenceRing(
            identifier: outerID, radius: clamped, notifyOnEntry: true, notifyOnExit: true
        )
        let innerRadius = max(clamped * innerFactor, radiusRange.lowerBound)
        guard innerRadius < clamped else { return [outer] }
        let inner = GeofenceRing(
            identifier: innerID, radius: innerRadius, notifyOnEntry: false, notifyOnExit: true
        )
        return [outer, inner]
    }

    /// True while a boundary callback is more likely a registration echo than
    /// a real crossing. See `LocationMonitor.monitoringStartedAt`.
    public static func withinRegistrationGrace(
        startedAt: Date?, now: Date, window: TimeInterval
    ) -> Bool {
        guard let startedAt else { return false }
        return now.timeIntervalSince(startedAt) < window
    }
}
