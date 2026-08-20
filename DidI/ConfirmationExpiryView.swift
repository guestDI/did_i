import SwiftUI
import CoreLocation
import UIKit
import DidICore

/// A focused editor for the one trust-sensitive item setting. The configured
/// rule applies to future confirmations; the rule captured by the current
/// confirmation remains untouched.
struct ConfirmationExpiryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    let item: Item
    let hasHome: Bool
    let save: (ResetRule) -> Bool

    @State private var draftRule: ResetRule
    @State private var authorization = LocationMonitor.shared.status
    @State private var showingSaveError = false

    init(item: Item, hasHome: Bool, save: @escaping (ResetRule) -> Bool) {
        self.item = item
        self.hasHome = hasHome
        self.save = save
        _draftRule = State(initialValue: item.resetRule)
    }

    private var leavingHomeAvailable: Bool {
        hasHome && authorization == .authorizedAlways
    }

    private var choices: [ResetRule] {
        var choices = ResetRule.choices(canDetectLeavingHome: leavingHomeAvailable)
        if item.resetRule == .onLeavingHome, !choices.contains(.onLeavingHome) {
            choices.insert(.onLeavingHome, at: 0)
        }
        return choices
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(choices, id: \.self) { rule in
                        Button {
                            draftRule = rule
                        } label: {
                            HStack {
                                Text(Copy.confirmationExpiry(rule))
                                    .foregroundStyle(Palette.text)
                                Spacer()
                                if draftRule == rule {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Palette.amber)
                                        .accessibilityHidden(true)
                                }
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .disabled(rule == .onLeavingHome && !leavingHomeAvailable)
                        .accessibilityAddTraits(draftRule == rule ? .isSelected : [])
                    }
                } header: {
                    Text(Copy.confirmationExpiryPrompt)
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Copy.confirmationExpiryFooter)
                        if draftRule == .never {
                            Text(Copy.neverWarning)
                        }
                        if item.resetRule == .onLeavingHome && !leavingHomeAvailable {
                            Text(Copy.leavingExpiryUnavailable)
                        }
                    }
                }

                if hasHome && !leavingHomeAvailable {
                    Section {
                        Button(Copy.HomeSettings.openSystemSettings) {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            openURL(url)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.ink)
            .navigationTitle(Copy.confirmationExpiryTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Copy.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Copy.done) {
                        if save(draftRule) {
                            dismiss()
                        } else {
                            showingSaveError = true
                        }
                    }
                    .disabled(draftRule == item.resetRule)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(draftRule != item.resetRule)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                authorization = LocationMonitor.shared.status
            }
        }
        .alert(Copy.saveFailedTitle, isPresented: $showingSaveError) {
            Button(Copy.ok) {}
        } message: {
            Text(Copy.saveFailedBody)
        }
    }
}
