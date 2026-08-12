import SwiftUI
import CoreLocation
import DidICore

/// Only what Phase 5 forces into existence: home, and the one-line note day-2
/// asks for when location is revoked. Tone and reminders arrive with Phase 6.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var store: Store

    private var authorization: CLAuthorizationStatus { LocationMonitor.shared.status }

    private var locationRevoked: Bool {
        store.home != nil && authorization != .authorizedAlways
            && authorization != .authorizedWhenInUse
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if store.home == nil {
                        Text("Not set")
                            .foregroundStyle(Palette.muted)
                    } else {
                        Text("Home is set")
                            .foregroundStyle(Palette.text)
                        Button("Reset home location", role: .destructive) { resetHome() }
                    }
                } header: {
                    Text("Home")
                } footer: {
                    // A one-line note here, never a banner on the main screen.
                    if locationRevoked {
                        Text("Location is off, so we're expiring things on a timer instead.")
                    } else if store.home != nil, authorization == .authorizedWhenInUse {
                        Text("Leaving home clears the board only while the app is open.")
                    } else if store.home != nil {
                        Text(Copy.HomeSetup.confirmed)
                    }
                }

                Section {
                    Text(Copy.LocationDeclined.settingsHint)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.sub)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.ink)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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
