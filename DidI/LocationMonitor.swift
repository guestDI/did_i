import CoreLocation
import UIKit
import WidgetKit
import DidICore

/// Two concentric `CLCircularRegion`s on the same centre: the user-sized one
/// (75m default) for entry and exit, and an exit-only inner ring at two thirds
/// of it. The allowance is 20 regions; we use two.
///
/// The inner ring exists purely to shorten the leaving-home reminder's latency.
/// iOS adds its own hysteresis buffer on top of whatever radius is configured
/// before it calls a departure an exit, so the reminder was landing a few
/// hundred metres from the door — reported as "too late to turn back". Crossing
/// the inner ring happens earlier, which moves the whole chain earlier; it does
/// not make iOS evaluate the boundary any sooner, which is the other half of the
/// delay and is not ours to tune. Whichever ring reports first wins and the
/// other's exit is a no-op (see `beginLeavingHomeWake`).
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
    private let innerRegionID = "home-inner"
    /// The inner ring's share of the user's radius. Never below the slider's own
    /// floor: under 50m, ordinary GPS drift indoors starts producing false exits.
    private static let innerRadiusFactor = 0.66

    /// Held across the exit wake so `usernotificationsd` has time to acknowledge
    /// the reminder before iOS is free to suspend the process. See
    /// `beginLeavingHomeWake`.
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    /// Called once a one-shot fix arrives, for "Set as home".
    private var pendingHomeCapture: ((CLLocationCoordinate2D?) -> Void)?
    /// Called when the authorization dialog resolves.
    private var pendingAuthorization: ((CLAuthorizationStatus) -> Void)?

    /// Set whenever `monitor()` (re)registers the region. A boundary callback
    /// delivered within `registrationGraceWindow` of that is far more likely to be
    /// CoreLocation reporting the region's already-known state on a fresh
    /// registration than an actual crossing — observed on first setup, a
    /// permission grant, or a radius change, not just the redundant
    /// re-registration `isMonitoring` already skips. Reported bug: confirming an
    /// item and then opening the app reset it seconds later, because a same-day
    /// reinstall had cleared the previously-monitored region and re-registering it
    /// while genuinely at home fired an immediate, spurious entry.
    private var monitoringStartedAt: Date?
    private static let registrationGraceWindow: TimeInterval = 10

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var status: CLAuthorizationStatus { manager.authorizationStatus }

    var hasAlways: Bool { status == .authorizedAlways }

    /// Re-registers the geofence at launch, and again on every foreground in
    /// case "Always" was granted from iOS Settings while backgrounded. Skips
    /// re-registering when the same region is already monitored: re-adding an
    /// identical `CLCircularRegion` makes CoreLocation re-evaluate the
    /// boundary against whatever location fix it currently has, which can be
    /// stale or GPS-noisy — and fire a spurious exit for someone who never
    /// left, sending a false "you're leaving and this isn't confirmed"
    /// reminder even though `.onComingHome` no longer resets on exit at all.
    func start() {
        guard hasAlways, let home = StoreIO.read().home else { return }
        guard !isMonitoring(home) else { return }
        monitor(home)
    }

    private func isMonitoring(_ home: HomeLocation) -> Bool {
        let monitored = manager.monitoredRegions.compactMap { $0 as? CLCircularRegion }
        return regions(for: home).allSatisfy { want in
            monitored.contains {
                $0.identifier == want.identifier
                    && $0.center.latitude == want.center.latitude
                    && $0.center.longitude == want.center.longitude
                    && $0.radius == want.radius
            }
        }
    }

    /// The outer ring carries entry as well as exit: arriving is still "reached
    /// the place I call home", and widening what counts as an arrival — clearing
    /// confirmations for someone merely walking past — is not a trade the
    /// latency fix is allowed to make. The inner ring is exit-only for the same
    /// reason.
    private func regions(for home: HomeLocation) -> [CLCircularRegion] {
        let center = CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude)
        let radius = Self.clampedRadius(home.radius)

        let outer = CLCircularRegion(center: center, radius: radius, identifier: regionID)
        outer.notifyOnEntry = true
        outer.notifyOnExit = true

        let innerRadius = max(radius * Self.innerRadiusFactor, HomeLocation.radiusRange.lowerBound)
        guard innerRadius < radius else { return [outer] }
        let inner = CLCircularRegion(center: center, radius: innerRadius, identifier: innerRegionID)
        inner.notifyOnEntry = false
        inner.notifyOnExit = true
        return [outer, inner]
    }

    private static func clampedRadius(_ radius: Double) -> Double {
        min(max(radius, HomeLocation.radiusRange.lowerBound), HomeLocation.radiusRange.upperBound)
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

    /// `radius` is user-adjustable (Settings → Home area size) — trusted as-is,
    /// clamped only against corrupt or pre-slider data, never against the app's
    /// own shrinking defaults. Overriding a deliberate choice on every relaunch
    /// would make the control a lie.
    func monitor(_ home: HomeLocation) {
        stopMonitoring()
        monitoringStartedAt = .now
        for region in regions(for: home) {
            manager.startMonitoring(for: region)
        }
    }

    /// True while a boundary callback is more likely a registration echo than a
    /// real crossing. See `monitoringStartedAt`.
    private var withinRegistrationGrace: Bool {
        guard let started = monitoringStartedAt else { return false }
        return Date.now.timeIntervalSince(started) < Self.registrationGraceWindow
    }

    func stopMonitoring() {
        for region in manager.monitoredRegions
        where region.identifier == regionID || region.identifier == innerRegionID {
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
            guard !withinRegistrationGrace else { return }
            beginLeavingHomeWake()
        }
    }

    /// `UNUserNotificationCenter.add` is XPC to a daemon with no synchronous
    /// counterpart — the call returning does not mean the request landed. With
    /// nothing else holding the process open, the exit handler used to fire the
    /// request and return, racing an iOS suspend it sometimes lost. A background
    /// task assertion buys the time; `await`ing `add` (in
    /// `Notifications.scheduleLeavingHomeReminders`) is what the assertion is
    /// held *for*.
    private func beginLeavingHomeWake() {
        endBackgroundTaskIfNeeded()
        backgroundTask = UIApplication.shared.beginBackgroundTask(
            withName: "leaving-home-exit"
        ) { [weak self] in
            // Time ran out. Release the assertion rather than being killed
            // outright — whatever notification work is still in flight loses
            // its guarantee, but the process survives to try again next time.
            Task { @MainActor in self?.endBackgroundTaskIfNeeded() }
        }

        Task { @MainActor [weak self] in
            defer { self?.endBackgroundTaskIfNeeded() }

            // One store access for both the write and the read that used to
            // follow it: `leftHome` and the due-item list are computed inside
            // the same `mutate`, so a stale-but-successful widget refresh can
            // never mask a reminder list that silently came from nothing.
            let due: [Item]
            if let result = try? StoreIO.mutate({ store -> [Item] in
                // The second ring reporting the same departure: `leftHome` has
                // already landed and the reminders have already gone out. Only
                // an arrival in between makes an exit a new one, which is
                // exactly what `isAway` reads.
                guard !store.isAway else { return [] }
                store.leftHome(at: .now)
                return store.needingLeavingHomeReminder(now: .now)
            }) {
                due = result
            } else {
                // The write itself failed — `leftHome` never landed, so `isAway`
                // and the 24h ceiling are unaffected until the next successful
                // access. That is recoverable on the next open; a reminder that
                // never fired is not, so it is still worth salvaging from a
                // plain read against whatever rule state already exists.
                let store = StoreIO.read()
                due = store.isAway ? [] : store.needingLeavingHomeReminder(now: .now)
            }

            // Notification before widget: the widget can be a few minutes stale
            // for free, the reminder cannot.
            await Notifications.scheduleLeavingHomeReminders(for: due)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func endBackgroundTaskIfNeeded() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    /// Entry expires coming-home confirmations and clears the "can't check right now" mutes.
    nonisolated func locationManager(
        _ manager: CLLocationManager, didEnterRegion region: CLRegion
    ) {
        MainActor.assumeIsolated {
            guard !withinRegistrationGrace else { return }
            do {
                try StoreIO.mutate { $0.arrivedHome(at: .now) }
            } catch {
                return
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
