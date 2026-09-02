import SwiftUI
import CoreLocation
import UIKit
import DidICore

/// Only what Phase 5 forces into existence: home, and the one-line note day-2
/// asks for when location is revoked. Tone and reminders arrive with Phase 6.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Binding var store: Store

    @State private var showingWalkthrough = false
    @State private var settingHome = false
    @State private var authorization = LocationMonitor.shared.status
    @State private var notificationsAllowed = true
    @State private var showingSaveError = false
    @State private var showingTipThanks = false
    @State private var showingTipError = false
    @State private var draftRadius: Double = HomeLocation.defaultRadius

    /// Surfaced only when there is something broken to report: reminders are on
    /// for at least one item and notifications cannot deliver them. Finding this
    /// out required opening an item's editor before — the one place nobody looks
    /// once the toggle is set and believed.
    private var remindersCannotFire: Bool {
        !notificationsAllowed && store.active.contains { $0.leavingHomeReminder == true }
    }

    private var locationRevoked: Bool {
        store.home != nil && authorization != .authorizedAlways
            && authorization != .authorizedWhenInUse
    }

    private var homeStep: DayTwoFlow.Step {
        authorization == .authorizedAlways || authorization == .authorizedWhenInUse
            ? .homeSetup : .locationAsk
    }

    /// `Measurement.formatted()` renders in the user's own locale — feet for a
    /// US region, metres elsewhere — for free. No unit-conversion code to get
    /// wrong or to keep in sync with the metres the geofence itself is built in.
    private var radiusMeasurement: Measurement<UnitLength> {
        Measurement(value: draftRadius, unit: .meters)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if store.home == nil {
                        // Dead text before this: the only route to home setup was
                        // the day-2 sheet, which fires once. Anyone who tapped
                        // "I'm not home right now" — or opened Settings first —
                        // could read "Not set" forever with nothing to tap.
                        if authorization == .denied {
                            Button(Copy.HomeSettings.openSystemSettings) { openSystemSettings() }
                        } else {
                            Button(Copy.HomeSetup.set) { settingHome = true }
                        }
                    } else {
                        Text(Copy.HomeSettings.isSet)
                            .foregroundStyle(Palette.text)
                        if authorization == .denied {
                            Button(Copy.HomeSettings.openSystemSettings) { openSystemSettings() }
                        }
                        Button(Copy.HomeSettings.reset) { resetHome() }
                    }
                } header: {
                    Text(Copy.HomeSettings.section)
                } footer: {
                    // A one-line note here, never a banner on the main screen.
                    if locationRevoked {
                        Text(Copy.HomeSettings.revoked)
                    } else if store.home != nil, authorization == .authorizedWhenInUse {
                        Text(Copy.HomeSettings.foregroundOnly)
                    } else if store.home != nil {
                        Text(Copy.HomeSetup.confirmed)
                    }
                }

                // A fixed radius cannot fit every home: a flat and a house with a
                // garden both read as "home" at different scales. Editable only
                // once a home exists — there is nothing to size before then.
                if store.home != nil {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(Copy.HomeSettings.radiusLabel)
                                    .foregroundStyle(Palette.text)
                                Spacer()
                                Text(radiusMeasurement.formatted(.measurement(width: .abbreviated)))
                                    .foregroundStyle(Palette.sub)
                                    .monospacedDigit()
                            }
                            Slider(
                                value: $draftRadius,
                                in: HomeLocation.radiusRange,
                                step: 25,
                                onEditingChanged: { editing in
                                    if !editing { saveRadius() }
                                }
                            )
                            .tint(Palette.amber)
                            .accessibilityValue(radiusMeasurement.formatted(.measurement(width: .abbreviated)))
                        }
                    } footer: {
                        Text(Copy.HomeSettings.radiusFooter)
                    }
                }

                Section {
                    Picker(Copy.Tone.congratulations, selection: toneBinding) {
                        Text(Copy.Tone.deadpan).tag(false)
                        Text(Copy.Tone.plain).tag(true)
                    }
                } header: {
                    Text(Copy.Tone.section)
                } footer: {
                    Text(Copy.Tone.footer)
                }

                if remindersCannotFire {
                    Section {
                        Button(Copy.HomeSettings.openSystemSettings) { openSystemSettings() }
                    } header: {
                        Text(Copy.Reminder.section)
                    } footer: {
                        Text(Copy.Reminder.notificationsOff)
                    }
                }

                // Day 0's "Skip for now" closes the only other
                // route to these instructions, and the widget is the product.
                Section {
                    Button(Copy.widgetHelpRow) { showingWalkthrough = true }
                } footer: {
                    Text(Copy.controlCenterHint)
                }

                Section {
                    Link(Copy.privacyPolicy, destination: AppLinks.privacy)
                    Link(Copy.supportWebsite, destination: AppLinks.support)
                }

                if let price = TipJar.shared.product?.displayPrice {
                    Section {
                        Button(Copy.TipJar.rowTitle(price: price)) {
                            Task { await sendTip() }
                        }
                    } header: {
                        Text(Copy.TipJar.section)
                    }
                }

                Section {
                    Text(Copy.resetRuleHint)
                        .appFont(13, relativeTo: .footnote)
                        .foregroundStyle(Palette.sub)
                }

                Section {
                    Text(Copy.versionFooter(version: Self.version))
                        .boardFont(8.5, .medium, relativeTo: .caption2)
                        .tracking(2.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.dim)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            }
            .sheet(isPresented: $showingWalkthrough) { WalkthroughSheet() }
            .sheet(isPresented: $settingHome) {
                // Reuses the day-2 sheet rather than duplicating capture, the
                // failure line, and the `always` escalation. Skip straight to
                // the capture step if location was already granted.
                DayTwoFlow(step: homeStep) {
                    settingHome = false
                    do {
                        store = try StoreIO.load()
                    } catch {
                        showingSaveError = true
                    }
                    authorization = LocationMonitor.shared.status
                }
            }
            .task {
                draftRadius = store.home?.radius ?? HomeLocation.defaultRadius
                await refreshNotificationStatus()
                // ponytail: tip jar hidden for 1.0 (not loading the product keeps
                // the row, which is already gated on product != nil, from showing).
                // Restore this call once the IAP product is live in App Store Connect.
            }
            .onChange(of: store.home) { _, home in
                draftRadius = home?.radius ?? HomeLocation.defaultRadius
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    authorization = LocationMonitor.shared.status
                    Task { await refreshNotificationStatus() }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.ink)
            .navigationTitle(Copy.settings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(Copy.done) { dismiss() }
                }
            }
            .alert(Copy.saveFailedTitle, isPresented: $showingSaveError) {
                Button(Copy.ok) {}
            } message: {
                Text(Copy.saveFailedBody)
            }
            .alert(Copy.TipJar.thanksTitle, isPresented: $showingTipThanks) {
                Button(Copy.ok) {}
            } message: {
                Text(Copy.TipJar.thanksBody)
            }
            .alert(Copy.TipJar.errorTitle, isPresented: $showingTipError) {
                Button(Copy.ok) {}
            } message: {
                Text(Copy.TipJar.errorBody)
            }
        }
    }

    private static let version =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    /// Tone is one bit on the store, so the picker writes through `StoreIO`
    /// rather than holding its own draft state.
    private var toneBinding: Binding<Bool> {
        Binding(
            get: { store.plainTone },
            set: { plain in
                do {
                    try StoreIO.mutate { $0.plainTone = plain }
                    store = try StoreIO.load()
                } catch {
                    showingSaveError = true
                }
            }
        )
    }

    /// Written on drag release, not on every tick — a `mutate` per pixel of
    /// slider travel would be a coordinated file write per pixel of slider
    /// travel. Re-registers the geofence immediately rather than waiting for
    /// the next foreground, so the new size takes effect before the user
    /// leaves the house they just resized it for.
    private func saveRadius() {
        guard let home = store.home, home.radius != draftRadius else { return }
        do {
            try StoreIO.mutate { $0.home?.radius = draftRadius }
            store = try StoreIO.load()
            if let updated = store.home { LocationMonitor.shared.monitor(updated) }
        } catch {
            showingSaveError = true
            UIAccessibility.post(notification: .announcement, argument: Copy.saveFailedBody)
        }
    }

    /// day-2: "They set home at the office by mistake." Provide the reset; do not
    /// try to detect it.
    private func resetHome() {
        do {
            try StoreIO.mutate {
                $0.home = nil
                $0.lastLeftHomeAt = nil
                $0.lastEnteredHomeAt = nil
                $0.flags.homeSetupPending = true
                $0.flags.homeSetupDeferredUntil = nil
            }
            LocationMonitor.shared.stopMonitoring()
            store = try StoreIO.load()
        } catch {
            showingSaveError = true
            UIAccessibility.post(notification: .announcement, argument: Copy.saveFailedBody)
        }
    }

    private func refreshNotificationStatus() async {
        notificationsAllowed = await Notifications.authorizationStatus() == .authorized
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func sendTip() async {
        do {
            let completed = try await TipJar.shared.purchase()
            if completed {
                showingTipThanks = true
            }
        } catch {
            showingTipError = true
        }
    }
}

private enum AppLinks {
    static let privacy = URL(string: "https://guestdi.github.io/did_i/privacy/")!
    static let support = URL(string: "https://guestdi.github.io/did_i/support/")!
}

/// Pre-filled share sheet for "Ask someone at home".
struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
