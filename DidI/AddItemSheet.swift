import SwiftUI
import WidgetKit
import DidICore

/// The add-item flow, and the cap that guards it. Also the shape the second-item
/// suggestion takes — day-3 frames that as *them* having something on their mind,
/// never as the app wanting more data.
struct AddItemSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var store: Store
    /// Set when this was opened by a behavioural trigger rather than the button.
    let suggestion: SecondItem.Trigger?

    @State private var swapping = false
    @State private var custom = ""
    @State private var typing = false
    @State private var showingSaveError = false
    @FocusState private var focused: Bool

    /// Chips they do not already have, on the board or in the archive.
    private var available: [Chip] { Chip.available(excluding: store.items) }

    private var trimmedCustom: String {
        custom.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var customNameIsAvailable: Bool {
        Item.isNameAvailable(trimmedCustom, among: store.items)
    }

    private var canAddCustom: Bool {
        !trimmedCustom.isEmpty && customNameIsAvailable
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.isFull && !swapping {
                    capReached
                } else if swapping {
                    swapList
                } else {
                    picker
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Palette.ink)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(suggestion != nil ? Copy.SecondItemPrompt.decline : Copy.close) {
                        if suggestion == nil || decline() { dismiss() }
                    }
                    .foregroundStyle(Palette.muted)
                }
            }
        }
        .alert(Copy.saveFailedTitle, isPresented: $showingSaveError) {
            Button(Copy.ok) {}
        } message: {
            Text(Copy.saveFailedBody)
        }
    }

    // MARK: - Picker

    private var picker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(suggestion != nil ? Copy.SecondItemPrompt.title : Copy.addAnItem)
                    .boardFont(18, .semibold, relativeTo: .headline)
                    .foregroundStyle(Palette.text)
                Text(suggestion != nil ? Copy.SecondItemPrompt.body : Copy.pickOne)
                    .appFont(14, relativeTo: .subheadline)
                    .foregroundStyle(Palette.sub)
                    .padding(.top, 10)

                if typing {
                    TextField(
                        Copy.nameFieldTitle,
                        text: $custom,
                        prompt: Text(Copy.Screen1.placeholder)
                    )
                        .boardFont(15, relativeTo: .body)
                        .submitLabel(.done)
                        .focused($focused)
                        .onChange(of: custom) { _, new in
                            if new.count > Item.maxNameLength {
                                custom = String(new.prefix(Item.maxNameLength))
                            }
                        }
                        .onSubmit {
                            if canAddCustom { add(.somethingElse, named: trimmedCustom) }
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 18)
                        .background(Palette.panel, in: .rect(cornerRadius: 14))
                        .padding(.top, 22)
                        .onAppear { focused = true }
                        .accessibilityLabel(Copy.nameFieldTitle)

                    if !trimmedCustom.isEmpty && !customNameIsAvailable {
                        Text(Copy.nameAlreadyUsed)
                            .appFont(12, relativeTo: .footnote)
                            .foregroundStyle(Palette.amber)
                            .padding(.top, 8)
                    }

                    Button(Copy.Screen1.returnKey) {
                        add(.somethingElse, named: trimmedCustom)
                    }
                    .buttonStyle(PrimaryButton())
                    .disabled(!canAddCustom)
                    .padding(.top, 14)
                } else {
                    chips.padding(.top, 22)
                }

                // Seasonal items come and go. Quiet section, one tap to re-add.
                PreviouslyList(archived: store.archived, onRestore: restore)
            }
            .padding(26)
        }
    }

    private var chips: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
            ForEach(available) { chip in
                Button {
                    if chip.id == Chip.somethingElse.id { typing = true } else { add(chip) }
                } label: {
                    Text(chip.label)
                        .boardFont(12, relativeTo: .callout)
                        .tracking(1.6)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Palette.panel, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - The cap

    private var capReached: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Copy.Cap.title)
                .boardFont(18, .semibold, relativeTo: .headline)
                .foregroundStyle(Palette.text)
            Text(Copy.Cap.body)
                .appFont(14, relativeTo: .subheadline)
                .foregroundStyle(Palette.sub)
                .padding(.top, 14)
            Spacer()
            // Never a paywall. Making anxiety relief a subscription tier is a bad
            // thing to do to people.
            Button(Copy.Cap.swap) { swapping = true }
                .buttonStyle(PrimaryButton())
            Button(Copy.Cap.neverMind) { dismiss() }
                .buttonStyle(SecondaryButton())
                .padding(.top, 4)
        }
        .padding(30)
    }

    /// Shown with usage counts so the choice is informed.
    private var swapList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(Copy.whichOneGoes)
                    .boardFont(18, .semibold, relativeTo: .headline)
                    .foregroundStyle(Palette.text)
                    .padding(.bottom, 8)

                ForEach(store.active) { item in
                    Button { swapOut(item) } label: {
                        HStack {
                            Text(Copy.Cap.usage(item: item, now: .now))
                                .appFont(14, relativeTo: .subheadline)
                                .foregroundStyle(Palette.text)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Palette.rule).frame(height: 1)
                    }
                }
            }
            .padding(26)
        }
    }

    // MARK: - Actions

    private func add(_ chip: Chip, named name: String? = nil) {
        guard save({ $0.add(chip.item(named: name, createdAt: .now)) }) else { return }
        dismiss()
    }

    private func restore(_ item: Item) {
        guard save({ $0.unarchive(item.id) }) else { return }
        dismiss()
    }

    /// Archive, never delete.
    private func swapOut(_ item: Item) {
        guard save({ $0.archive(item.id, at: .now) }) else { return }
        swapping = false
    }

    private func decline() -> Bool {
        save {
            $0.usage.declineCount += 1
            $0.usage.lastDeclinedAt = .now
        }
    }

    @discardableResult
    private func save(_ change: (inout Store) -> Void) -> Bool {
        do {
            try StoreIO.mutate(change)
            store = try StoreIO.load()
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.board)
            return true
        } catch {
            showingSaveError = true
            UIAccessibility.post(notification: .announcement, argument: Copy.saveFailedBody)
            return false
        }
    }
}

/// The "Previously" section. Shared with onboarding Screen 1, which an emptied
/// board falls back to — that path has no add sheet, so without it here the
/// archive becomes unreachable exactly when it is needed.
struct PreviouslyList: View {
    let archived: [Item]
    let onRestore: (Item) -> Void

    var body: some View {
        if !archived.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text(Copy.previouslySection)
                    .boardFont(9, relativeTo: .caption2)
                    .tracking(3)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.dim)
                    .padding(.bottom, 4)

                ForEach(archived) { item in
                    Button { onRestore(item) } label: {
                        HStack {
                            Text(item.name)
                                .boardFont(13, relativeTo: .subheadline)
                                .foregroundStyle(Palette.text)
                            Spacer()
                            Image(systemName: "arrow.uturn.backward")
                                .foregroundStyle(Palette.muted)
                        }
                        .padding(.vertical, 14)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Palette.rule).frame(height: 1)
                    }
                }
            }
            .padding(.top, 30)
        }
    }
}

/// The weekly card. Dismissible, never a notification, and only ever a joke about
/// a good record.
struct ParanoiaCard: View {
    let card: ParanoiaCounter.Card
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Copy.Paranoia.title)
                    .boardFont(9, relativeTo: .caption2)
                    .tracking(3)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.dim)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.dim)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .accessibilityLabel(Copy.dismiss)
            }
            Text(Copy.Paranoia.topWorry(item: card.topWorry, checks: card.topChecks))
                .foregroundStyle(Palette.text)
            if let runnerUp = card.runnerUp {
                Text(Copy.Paranoia.runnerUp(item: runnerUp, checks: card.runnerUpChecks))
                    .foregroundStyle(Palette.text)
            }
            Text(Copy.Paranoia.reassurance(item: card.reassurance))
                .foregroundStyle(Palette.sub)
            Text(card.closingLine)
                .foregroundStyle(Palette.amber)
                .padding(.top, 6)
        }
        .appFont(13, relativeTo: .footnote)
        // Every line here is a joke; a clipped punchline is worse than no card.
        .fixedSize(horizontal: false, vertical: true)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.panel, in: .rect(cornerRadius: 16))
        .padding(.horizontal, 22)
    }
}

extension AddItemSheet {
    /// `sheet(item:)` needs identity; the trigger alone is not enough because a
    /// manual add carries none.
    struct Presentation: Identifiable {
        let suggestion: SecondItem.Trigger?
        var id: String { suggestion?.rawValue ?? "manual" }
    }
}
