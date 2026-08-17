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
    let save: (Item) -> Void
    /// The only way off the board short of hitting the six-item cap. Without it
    /// a three-item list is permanent.
    let archive: () -> Void

    init(
        item: Item,
        hasHome: Bool,
        save: @escaping (Item) -> Void,
        archive: @escaping () -> Void
    ) {
        _draft = State(initialValue: item)
        self.original = item
        self.hasHome = hasHome
        self.save = save
        self.archive = archive
    }

    private let maxNameLength = 24

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(Copy.nameFieldTitle, text: $draft.name)
                        .onChange(of: draft.name) { _, new in
                            if new.count > maxNameLength {
                                draft.name = String(new.prefix(maxNameLength))
                            }
                        }
                } header: {
                    Text(Copy.nameFieldTitle)
                } footer: {
                    Text(Copy.nameFieldFooter)
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
                    Text(Copy.wordFieldFooter)
                }

                Section {
                    ForEach(ResetRule.choices(hasHome: hasHome), id: \.self) { rule in
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
                                            if !granted { draft.leavingHomeReminder = false }
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

                Section {
                    Button(Copy.putItAway, role: .destructive) {
                        // Dismiss first: archiving the last item swaps the whole
                        // hierarchy out from under this sheet.
                        dismiss()
                        archive()
                    }
                } footer: {
                    Text(Copy.putItAwayFooter)
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
                        // Once they have written their own words, the text is
                        // theirs and must never be relocalized out from under them.
                        if edited.name != original.name || edited.word != original.word {
                            edited.chipID = nil
                        }
                        save(edited)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
