import CoreLocation
import WidgetKit
import DidICore

/// One `CLCircularRegion`, 150m, entry and exit. The allowance is 20 regions;
/// we use one.
///
/// **Construction must be synchronous during launch.** A region exit relaunches a
/// terminated app with `UIApplication.LaunchOptionsKey.location`, and if the
/// manager and its delegate are not in place before the first `await`, the event
/// is dropped. That is why this is built from an app delegate and not a `.task`.
@MainActor
final class LocationMonitor: NSObject {
    static let shared = LocationMonitor()

    private let manager = CLLocationManager()
    private let regionID = "home"

    /// Called once a one-shot fix arrives, for "Set as home".
    private var pendingHomeCapture: ((CLLocationCoordinate2D?) -> Void)?
    /// Called when the authorization dialog resolves.
    private var pendingAuthorization: ((CLAuthorizationStatus) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var status: CLAuthorizationStatus { manager.authorizationStatus }

    var hasAlways: Bool { status == .authorizedAlways }

    /// Re-registers the geofence at launch. Regions survive termination, but
    /// re-registering is cheap and covers a restore onto a new device.
    func start() {
        guard hasAlways, let home = StoreIO.read().home else { return }
        monitor(home)
    }

    // MARK: - Authorization, in two steps

    /// Step one, at the "Use my location" tap. Enough to capture the coordinate.
    func requestWhenInUse(_ completion: @escaping (CLAuthorizationStatus) -> Void) {
        guard status == .notDetermined else { return completion(status) }
        pendingAuthorization = completion
        manager.requestWhenInUseAuthorization()
    }

    /// Step two, once home is set. Background region events do not arrive without
    /// it, so this is required for the feature to work at all — but a refusal is
    /// silent: the geofence degrades to the 24h ceiling and nobody is badgered.
    func requestAlways(_ completion: @escaping (CLAuthorizationStatus) -> Void) {
        guard status == .authorizedWhenInUse else { return completion(status) }
        pendingAuthorization = completion
        manager.requestAlwaysAuthorization()
    }

    // MARK: - Home

    /// One-shot fix for "Set as home".
    func captureHome(_ completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            return completion(nil)
        }
        pendingHomeCapture = completion
        manager.requestLocation()
    }

    func monitor(_ home: HomeLocation) {
        stopMonitoring()
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude),
            // Clamped: stores written before the 100m default still hold 150.
            radius: min(home.radius, 100),
            identifier: regionID
        )
        region.notifyOnExit = true
        region.notifyOnEntry = true
        manager.startMonitoring(for: region)
    }

    func stopMonitoring() {
        for region in manager.monitoredRegions where region.identifier == regionID {
            manager.stopMonitoring(for: region)
        }
    }
}

extension LocationMonitor: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Read the status out before the isolation hop — the manager itself is
        // not Sendable and must not cross.
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            pendingAuthorization?(status)
            pendingAuthorization = nil
            if status == .authorizedAlways { start() }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        MainActor.assumeIsolated {
            pendingHomeCapture?(locations.last?.coordinate)
            pendingHomeCapture = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            pendingHomeCapture?(nil)
            pendingHomeCapture = nil
        }
    }

    /// The background wake. Architecture §6 permits exactly three things here and
    /// gives us a few seconds with no guarantees: record the exit, reload the
    /// widgets, schedule any opted-in reminders. No cleanup, no trimming, no
    /// counters.
    nonisolated func locationManager(
        _ manager: CLLocationManager, didExitRegion region: CLRegion
    ) {
        MainActor.assumeIsolated {
            do {
                try StoreIO.mutate { $0.leftHome(at: .now) }
            } catch {
                return
            }
            WidgetCenter.shared.reloadAllTimelines()
            Notifications.scheduleLeavingHomeReminders()
        }
    }

    /// Entry clears the "can't check right now" mutes.
    nonisolated func locationManager(
        _ manager: CLLocationManager, didEnterRegion region: CLRegion
    ) {
        MainActor.assumeIsolated {
            do {
                try StoreIO.mutate { $0.arrivedHome(at: .now) }
            } catch {
                return
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
