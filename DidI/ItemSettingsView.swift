import SwiftUI
import UIKit
import UserNotifications
import DidICore

/// Everything about one item: name, status word, expiry rule, leaving-home
/// reminder. The expiry rule pushes to its own screen — five options with a
/// warning on one of them do not belong inline — but it saves with this sheet's
/// Done, so an item is never half-edited.
struct ItemSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var draft: Item
    /// Kept to tell an edit from an untouched field on the way out.
    private let original: Item
    let hasHome: Bool
    let existingItems: [Item]
    let save: (Item) -> Bool
    @State private var showingSaveError = false
    @State private var notificationsAllowed = true

    /// The reminder is delivered by a notification. Revoke that in iOS Settings
    /// and `center.add` starts failing silently, leaving a toggle that reads on
    /// and a promise nothing keeps — so the state is re-read on every appearance
    /// rather than trusted from the moment permission was granted.
    private var reminderCannotFire: Bool {
        draft.leavingHomeReminder == true && !notificationsAllowed
    }

    init(
        item: Item,
        hasHome: Bool,
        existingItems: [Item],
        save: @escaping (Item) -> Bool
    ) {
        _draft = State(initialValue: item)
        self.original = item
        self.hasHome = hasHome
        self.existingItems = existingItems
        self.save = save
    }

    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedWord: String {
        draft.word.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var nameIsAvailable: Bool {
        Item.isNameAvailable(trimmedName, among: existingItems, excluding: draft.id)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !trimmedWord.isEmpty && nameIsAvailable
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(Copy.nameFieldTitle, text: $draft.name)
                        .onChange(of: draft.name) { _, new in
                            if new.count > Item.maxNameLength {
                                draft.name = String(new.prefix(Item.maxNameLength))
                            }
                        }
                } header: {
                    Text(Copy.nameFieldTitle)
                } footer: {
                    if !trimmedName.isEmpty && !nameIsAvailable {
                        Text(Copy.nameAlreadyUsed)
                            .foregroundStyle(Palette.amber)
                    } else {
                        Text(Copy.nameFieldFooter)
                    }
                }

                Section {
                    TextField(Copy.wordFieldTitle, text: $draft.word)
                        .textInputAutocapitalization(.never)
                        .onChange(of: draft.word) { _, new in
                            // The board spells this out in flap cells; past a
                            // handful of characters they stop being readable.
                            if new.count > 10 { draft.word = String(new.prefix(10)) }
                        }
                } header: {
                    Text(Copy.wordFieldTitle)
                } footer: {
                    if trimmedWord.isEmpty {
                        Text(Copy.wordFieldRequired)
                            .foregroundStyle(Palette.amber)
                    } else {
                        Text(Copy.wordFieldFooter)
                    }
                }

                Section {
                    NavigationLink {
                        ConfirmationExpiryView(
                            rule: $draft.resetRule,
                            hasHome: hasHome
                        )
                    } label: {
                        LabeledContent(
                            Copy.confirmationExpiryTitle,
                            value: Copy.confirmationExpiry(draft.resetRule)
                        )
                    }
                }

                // Only offered once a home exists — there is nothing to leave
                // otherwise. Permission is asked at the moment it buys something.
                if hasHome {
                    Section {
                        Toggle(
                            Copy.Reminder.toggle,
                            isOn: Binding(
                                get: { draft.leavingHomeReminder == true },
                                set: { on in
                                    draft.leavingHomeReminder = on
                                    if on {
                                        Task {
                                            let granted = await Notifications.requestAuthorization()
                                            guard granted else {
                                                draft.leavingHomeReminder = false
                                                return
                                            }
                                            // The reminder is delivered from a region-exit
                                            // background wake, which never arrives on "When
                                            // In Use" — this is the first moment asking for
                                            // "Always" buys the user something concrete.
                                            if LocationMonitor.shared.status != .authorizedAlways {
                                                let always = await requestAlwaysLocation()
                                                if !always { draft.leavingHomeReminder = false }
                                            }
                                        }
                                    }
                                }
                            )
                        )
                        .tint(Palette.amber)
                        if reminderCannotFire {
                            Button(Copy.HomeSettings.openSystemSettings) { openSystemSettings() }
                        }
                    } footer: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Copy.Reminder.footer)
                            if reminderCannotFire {
                                Text(Copy.Reminder.notificationsOff)
                                    .foregroundStyle(Palette.amber)
                            }
                        }
                    }
                }

            }
            .scrollContentBackground(.hidden)
            .background(Palette.ink)
            .navigationTitle(draft.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(Copy.done) {
                        var edited = draft
                        edited.name = trimmedName
                        edited.word = trimmedWord
                        // Once they have written their own words, the text is
                        // theirs and must never be relocalized out from under them.
                        if edited.name != original.name || edited.word != original.word {
                            edited.chipID = nil
                        }
                        if save(edited) {
                            dismiss()
                        } else {
                            showingSaveError = true
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task { await refreshNotificationStatus() }
        .onChange(of: scenePhase) { _, phase in
            // They may have just left for iOS Settings to switch it back on.
            if phase == .active { Task { await refreshNotificationStatus() } }
        }
        .alert(Copy.saveFailedTitle, isPresented: $showingSaveError) {
            Button(Copy.ok) {}
        } message: {
            Text(Copy.saveFailedBody)
        }
    }

    private func refreshNotificationStatus() async {
        notificationsAllowed = await Notifications.authorizationStatus() == .authorized
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private func requestAlwaysLocation() async -> Bool {
        await withCheckedContinuation { continuation in
            LocationMonitor.shared.requestAlways { status in
                continuation.resume(returning: status == .authorizedAlways)
            }
        }
    }
}
