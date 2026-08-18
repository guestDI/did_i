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
    @State private var showingSaveError = false

    private var locationRevoked: Bool {
        store.home != nil && authorization != .authorizedAlways
            && authorization != .authorizedWhenInUse
    }

    private var homeStep: DayTwoFlow.Step {
        authorization == .authorizedAlways || authorization == .authorizedWhenInUse
            ? .homeSetup : .locationAsk
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

                // Day 0's "Later" plus a declined nudge closes the only other
                // route to these instructions, and the widget is the product.
                Section {
                    Button(Copy.widgetHelpRow) { showingWalkthrough = true }
                }

                Section {
                    Text(Copy.resetRuleHint)
                        .font(.footnote)
                        .foregroundStyle(Palette.sub)
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
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    authorization = LocationMonitor.shared.status
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

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

/// Pre-filled share sheet for "Ask someone at home".
struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
