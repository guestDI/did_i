import SwiftUI
import CoreLocation
import UIKit
import DidICore

/// The expiry rule, pushed from `ItemSettingsView`. It edits the parent's draft
/// in place and has no Done of its own: one item, one save, one Done button.
/// Standing alone in the More menu made "Edit item" a decoy — the obvious
/// affordance for changing an item held everything except the rule people came
/// to change — and split the two geofence settings across two screens.
///
/// The configured rule applies to future confirmations; the rule captured by the
/// current confirmation remains untouched (`Store.update`).
struct ConfirmationExpiryView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @Binding var rule: ResetRule
    /// The saved rule, not the draft: an already-chosen coming-home rule stays
    /// visible when the permission behind it is gone, so it can be changed away
    /// from rather than silently vanishing.
    let originalRule: ResetRule
    let hasHome: Bool

    @State private var authorization = LocationMonitor.shared.status

    private var comingHomeAvailable: Bool {
        hasHome && authorization == .authorizedAlways
    }

    private var choices: [ResetRule] {
        var choices = ResetRule.choices(canDetectComingHome: comingHomeAvailable)
        if originalRule == .onComingHome, !choices.contains(.onComingHome) {
            choices.insert(.onComingHome, at: 0)
        }
        return choices
    }

    var body: some View {
        Form {
            Section {
                ForEach(choices, id: \.self) { choice in
                    Button {
                        rule = choice
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Copy.confirmationExpiry(choice))
                                    .foregroundStyle(Palette.text)
                                // The caution belongs on the row, before the tap —
                                // in a footer it only ever arrives after the choice
                                // it is warning about.
                                if choice == .never {
                                    Text(Copy.neverWarning)
                                        .appFont(12, relativeTo: .footnote)
                                        .foregroundStyle(Palette.sub)
                                }
                            }
                            Spacer()
                            if rule == choice {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Palette.amber)
                                    .accessibilityHidden(true)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .disabled(choice == .onComingHome && !comingHomeAvailable)
                    // The footer explaining the dimmed row sits after every other
                    // option, so VoiceOver reaches it long after the row it is about.
                    .accessibilityHint(
                        choice == .onComingHome && !comingHomeAvailable
                            ? Copy.comingHomeExpiryUnavailable : ""
                    )
                    .accessibilityAddTraits(rule == choice ? .isSelected : [])
                }
            } header: {
                Text(Copy.confirmationExpiryPrompt)
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Copy.confirmationExpiryFooter)
                    if originalRule == .onComingHome && !comingHomeAvailable {
                        Text(Copy.comingHomeExpiryUnavailable)
                    }
                }
            }

            if hasHome && !comingHomeAvailable {
                Section {
                    Button(Copy.HomeSettings.openSystemSettings) {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    }
                } footer: {
                    Text(Copy.comingHomeExpiryUnavailable)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.ink)
        .navigationTitle(Copy.confirmationExpiryTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                authorization = LocationMonitor.shared.status
            }
        }
    }
}
