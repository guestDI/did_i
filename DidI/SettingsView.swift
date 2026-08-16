import SwiftUI
import CoreLocation
import DidICore

/// Only what Phase 5 forces into existence: home, and the one-line note day-2
/// asks for when location is revoked. Tone and reminders arrive with Phase 6.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var store: Store

    @State private var showingWalkthrough = false
    @State private var settingHome = false

    private var authorization: CLAuthorizationStatus { LocationMonitor.shared.status }

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
                        Button(Copy.HomeSetup.set) { settingHome = true }
                    } else {
                        Text(Copy.HomeSettings.isSet)
                            .foregroundStyle(Palette.text)
                        Button(Copy.HomeSettings.reset, role: .destructive) { resetHome() }
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
                        .font(.system(size: 13))
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
                    store = StoreIO.read()
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
        }
    }

    /// day-2: "They set home at the office by mistake." Provide the reset; do not
    /// try to detect it.
    private func resetHome() {
        LocationMonitor.shared.stopMonitoring()
        try? StoreIO.mutate {
            $0.home = nil
            $0.lastLeftHomeAt = nil
            $0.lastEnteredHomeAt = nil
            $0.flags.homeSetupPending = true
        }
        store = StoreIO.read()
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
