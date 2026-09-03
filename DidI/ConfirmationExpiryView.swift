import SwiftUI
import CoreLocation
import UIKit
import DidICore

/// The reset rule, pushed from `ItemSettingsView`. It edits the parent's draft
/// in place and has no Done of its own: one item, one save, one Done button.
/// The persisted enum already accepts arbitrary whole-hour durations and clock
/// hours; this screen exposes that flexibility without changing the store format.
struct ConfirmationExpiryView: View {
    private enum Mode: Hashable {
        case duration
        case daily
        case comingHome
        case manual
    }

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @Binding private var rule: ResetRule

    @State private var durationHours: Int
    @State private var dailyHour: Int
    @State private var hasConfiguredHome: Bool
    @State private var authorization = LocationMonitor.shared.status
    @State private var settingHome = false
    @State private var showingHomeSetupError = false

    init(
        rule: Binding<ResetRule>,
        hasHome: Bool
    ) {
        _rule = rule
        _hasConfiguredHome = State(initialValue: hasHome)

        if case .afterHours(let hours) = rule.wrappedValue {
            _durationHours = State(initialValue: min(max(hours, 1), 72))
        } else {
            _durationHours = State(initialValue: 12)
        }

        if case .dailyAt(let hour) = rule.wrappedValue {
            _dailyHour = State(initialValue: min(max(hour, 0), 23))
        } else {
            _dailyHour = State(initialValue: 4)
        }
    }

    private var mode: Mode {
        switch rule {
        case .afterHours: .duration
        case .dailyAt: .daily
        case .onComingHome: .comingHome
        case .never: .manual
        }
    }

    private var comingHomeAvailable: Bool {
        hasConfiguredHome && authorization == .authorizedAlways
    }

    private var homeStep: DayTwoFlow.Step {
        authorization == .authorizedAlways || authorization == .authorizedWhenInUse
            ? .homeSetup : .locationAsk
    }

    private var durationBinding: Binding<Int> {
        Binding(
            get: { durationHours },
            set: { hours in
                durationHours = hours
                rule = .afterHours(hours)
            }
        )
    }

    private var dailyHourBinding: Binding<Int> {
        Binding(
            get: { dailyHour },
            set: { hour in
                dailyHour = hour
                rule = .dailyAt(hour: hour)
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Text(Copy.confirmationExpiryPrompt)
                    .foregroundStyle(Palette.sub)
            }

            Section {
                choice(
                    .duration,
                    title: Copy.resetAfterDuration,
                    detail: Copy.durationLabel(durationHours)
                )
                choice(
                    .daily,
                    title: Copy.resetEveryDay,
                    detail: Copy.clockTime(dailyHour)
                )
                choice(
                    .comingHome,
                    title: Copy.resetWhenHome,
                    detail: Copy.resetWhenHomeDetail,
                    enabled: comingHomeAvailable
                )
            } header: {
                Text(Copy.resetAutomatically)
            }

            Section {
                choice(
                    .manual,
                    title: Copy.resetOnlyWhenCleared,
                    detail: Copy.manualResetDetail
                )
            } header: {
                Text(Copy.resetManually)
            }

            if mode == .duration {
                Section {
                    Picker(Copy.duration, selection: durationBinding) {
                        ForEach(1...72, id: \.self) { hours in
                            Text(Copy.durationLabel(hours)).tag(hours)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            }

            if mode == .daily {
                Section {
                    Picker(Copy.resetTime, selection: dailyHourBinding) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(Copy.clockTime(hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            }

            if !comingHomeAvailable {
                Section {
                    if authorization == .denied || hasConfiguredHome {
                        Button(Copy.HomeSettings.openSystemSettings) {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                                return
                            }
                            openURL(url)
                        }
                    } else {
                        Button(Copy.setUpHome) { settingHome = true }
                    }
                } footer: {
                    Text(Copy.comingHomeExpiryUnavailable)
                }
            }

            Section {
                Text(Copy.resetPreview(rule))
                    .foregroundStyle(Palette.sub)
            } footer: {
                Text(Copy.confirmationExpiryFooter)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.ink)
        .navigationTitle(Copy.confirmationExpiryTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $settingHome) {
            DayTwoFlow(step: homeStep) {
                settingHome = false
                do {
                    hasConfiguredHome = try StoreIO.load().home != nil
                    authorization = LocationMonitor.shared.status
                    if comingHomeAvailable { rule = .onComingHome }
                } catch {
                    showingHomeSetupError = true
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                authorization = LocationMonitor.shared.status
            }
        }
        .alert(Copy.loadFailedTitle, isPresented: $showingHomeSetupError) {
            Button(Copy.ok) {}
        } message: {
            Text(Copy.loadFailedBody)
        }
    }

    private func select(_ mode: Mode) {
        switch mode {
        case .duration:
            rule = .afterHours(durationHours)
        case .daily:
            rule = .dailyAt(hour: dailyHour)
        case .comingHome:
            guard comingHomeAvailable else { return }
            rule = .onComingHome
        case .manual:
            rule = .never
        }
    }

    private func choice(
        _ choice: Mode,
        title: String,
        detail: String,
        enabled: Bool = true
    ) -> some View {
        Button { select(choice) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .foregroundStyle(enabled ? Palette.text : Palette.dim)
                    Text(detail)
                        .appFont(12, relativeTo: .footnote)
                        .foregroundStyle(Palette.sub)
                }
                Spacer()
                if mode == choice {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Palette.amber)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityAddTraits(mode == choice ? .isSelected : [])
        .accessibilityHint(!enabled ? Copy.comingHomeExpiryUnavailable : "")
    }
}
