import SwiftUI
import DidICore

/// Reached by tapping an item's name. day-2 is explicit that this is where the
/// reset rule becomes discoverable, and not before: "how long until this expires?"
/// is an easy question about something that already happened to you this morning.
struct ItemSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Item
    let hasHome: Bool
    let save: (Item) -> Void

    init(item: Item, hasHome: Bool, save: @escaping (Item) -> Void) {
        _draft = State(initialValue: item)
        self.hasHome = hasHome
        self.save = save
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
                            "Remind me when I leave",
                            isOn: Binding(
                                get: { draft.leavingHomeReminder == true },
                                set: { on in
                                    draft.leavingHomeReminder = on
                                    if on { Task { _ = await Notifications.requestAuthorization() } }
                                }
                            )
                        )
                        .tint(Palette.amber)
                    } footer: {
                        Text("One notification, when you leave and this has no record.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.ink)
            .navigationTitle(draft.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        save(draft)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
