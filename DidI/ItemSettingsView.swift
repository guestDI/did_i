import SwiftUI
import DidICore

/// Reached by tapping an item's name. day-2 is explicit that this is where the
/// reset rule becomes discoverable, and not before: "how long until this expires?"
/// is an easy question about something that already happened to you this morning.
struct ItemSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Item
    /// Kept to tell an edit from an untouched field on the way out.
    private let original: Item
    let hasHome: Bool
    let existingItems: [Item]
    let save: (Item) -> Bool
    @State private var showingSaveError = false

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
                    // `hasHome` alone would drop "leaving home" off the list the
                    // moment home is removed in Settings — for an item already
                    // using it, that reads as the rule silently vanishing rather
                    // than the picker honestly showing what it's still set to.
                    ForEach(
                        ResetRule.choices(hasHome: hasHome || draft.resetRule == .onLeavingHome),
                        id: \.self
                    ) { rule in
                        Button {
                            draft.resetRule = rule
                        } label: {
                            HStack {
                                Text(Copy.forgetAfter(rule))
                                    .foregroundStyle(Palette.text)
                                Spacer()
                                if draft.resetRule == rule {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Palette.amber)
                                }
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(Copy.forgetAfterTitle)
                } footer: {
                    if draft.resetRule == .never {
                        Text(Copy.neverWarning)
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
                    } footer: {
                        Text(Copy.Reminder.footer)
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
        .alert(Copy.saveFailedTitle, isPresented: $showingSaveError) {
            Button(Copy.ok) {}
        } message: {
            Text(Copy.saveFailedBody)
        }
    }

    private func requestAlwaysLocation() async -> Bool {
        await withCheckedContinuation { continuation in
            LocationMonitor.shared.requestAlways { status in
                continuation.resume(returning: status == .authorizedAlways)
            }
        }
    }
}
