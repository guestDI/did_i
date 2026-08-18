import SwiftUI
import WidgetKit
import UserNotifications
import DidICore

/// Screens 1–3 of day-0-install.md. There is no Screen 0 — no splash, no logo,
/// no "Welcome to Did I?". Cold open directly on Screen 1.
struct OnboardingView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var store: Store
    @State private var screen: Int
    @State private var showingSaveError = false
    let finished: () -> Void

    init(store: Store, finished: @escaping () -> Void) {
        _store = State(initialValue: store)
        // An empty board always asks the question again — day-3's empty state is
        // Screen 1 with no shame attached. Otherwise resume at the last completed
        // screen; a force-quit must never restart the flow.
        _screen = State(
            initialValue: store.active.isEmpty ? 1 : min(store.flags.completedScreen + 1, 3)
        )
        self.finished = finished
    }

    var body: some View {
        ZStack {
            Palette.ink.ignoresSafeArea()
            switch screen {
            case 1: PickItemScreen(items: store.items, onPick: pick, onRestore: restore)
            case 2: PracticeScreen(store: $store, onDone: { advance(from: 2) })
            default: WidgetScreen(store: $store, onDone: finish)
            }
        }
        .animation(.snappy, value: screen)
        .alert(Copy.saveFailedTitle, isPresented: $showingSaveError) {
            Button(Copy.ok) {}
        } message: {
            Text(Copy.saveFailedBody)
        }
    }

    // MARK: - Screen 1 → 2

    private func pick(_ chip: Chip, name: String?) {
        // Refilling an emptied board is not a reinstall: take the item and get out
        // of the way. day-3 is explicit that we never re-onboard.
        let returning = store.flags.isComplete
        let item = chip.item(named: name, createdAt: .now)
        guard save({
            if $0.flags.installedAt == nil { $0.flags.installedAt = .now }
            if $0.flags.firstItemType == nil { $0.flags.firstItemType = chip.id }
            $0.add(item)
            if !returning { $0.flags.completedScreen = 1 }
        }) else { return }
        if returning { finished() } else { screen = 2 }
    }

    /// Emptying the board lands here, and the "Previously" list lives in the add
    /// sheet — which an empty board can never reach. Without this, archiving your
    /// last item strands everything you ever archived.
    private func restore(_ item: Item) {
        guard save({ $0.unarchive(item.id) }) else { return }
        if store.flags.isComplete { finished() } else { screen = 2 }
    }

    private func advance(from finishedScreen: Int) {
        guard save({
            $0.flags.completedScreen = max($0.flags.completedScreen, finishedScreen)
        }) else { return }
        screen = finishedScreen + 1
    }

    private func finish() {
        guard save({ $0.flags.completedScreen = OnboardingFlags.lastScreen }) else { return }
        finished()
    }

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

// MARK: - Screen 1

private struct PickItemScreen: View {
    let items: [Item]
    let onPick: (Chip, String?) -> Void
    let onRestore: (Item) -> Void

    private var archived: [Item] { items.filter { $0.archivedAt != nil } }

    @State private var typing = false
    @State private var custom = ""
    @FocusState private var focused: Bool

    private var trimmed: String {
        custom.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var nameIsAvailable: Bool {
        Item.isNameAvailable(trimmed, among: items)
    }

    private var canAddCustom: Bool {
        !trimmed.isEmpty && nameIsAvailable
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Copy.Screen1.title)
                        .font(boardScaled(.title3, .semibold))
                        .foregroundStyle(Palette.text)
                    Text(Copy.Screen1.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Palette.sub)
                        .padding(.top, 12)

                    if typing {
                        Button(Copy.back) { typing = false; custom = "" }
                            .buttonStyle(SecondaryButton(alignment: .leading))
                            .padding(.top, 16)

                        TextField(
                            Copy.nameFieldTitle,
                            text: $custom,
                            prompt: Text(Copy.Screen1.placeholder)
                        )
                        .font(boardScaled(.body))
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .focused($focused)
                        .onChange(of: custom) { _, new in
                            if new.count > Item.maxNameLength {
                                custom = String(new.prefix(Item.maxNameLength))
                            }
                        }
                        .onSubmit { if canAddCustom { onPick(.somethingElse, trimmed) } }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 18)
                        .background(Palette.panel, in: .rect(cornerRadius: 14))
                        .padding(.top, 8)
                        .onAppear { focused = true }
                        .accessibilityLabel(Copy.nameFieldTitle)

                        if !trimmed.isEmpty && !nameIsAvailable {
                            Text(Copy.nameAlreadyUsed)
                                .font(.footnote)
                                .foregroundStyle(Palette.amber)
                                .padding(.top, 8)
                        }

                        Button(Copy.Screen1.returnKey) {
                            onPick(.somethingElse, trimmed)
                        }
                        .buttonStyle(PrimaryButton())
                        .disabled(!canAddCustom)
                        .padding(.top, 14)
                    } else {
                        chips.padding(.top, 28)
                    }

                    Spacer(minLength: 24)
                    PreviouslyList(archived: archived, onRestore: onRestore)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 20)

                    Text(Copy.Screen1.footer)
                        .font(.caption)
                        .foregroundStyle(Palette.dim)
                        .frame(maxWidth: .infinity)
                }
                .frame(minHeight: geometry.size.height)
                .padding(.horizontal, 26)
                .padding(.top, 40)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var chips: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
            ForEach(Chip.available(excluding: items)) { chip in
                Button {
                    // Tapping a chip advances immediately. No Continue button.
                    if chip.id == Chip.somethingElse.id { typing = true } else { onPick(chip, nil) }
                } label: {
                    Text(chip.label)
                        .font(boardScaled(.callout))
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
}

// MARK: - Screen 2

private struct PracticeScreen: View {
    @Binding var store: Store
    let onDone: () -> Void

    @State private var confirmed = false
    @State private var advanceTask: Task<Void, Never>?
    @State private var showingSaveError = false

    private var item: Item? { store.active.first }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Copy.Screen2.title)
                        .font(boardScaled(.title3, .semibold))
                        .foregroundStyle(Palette.text)
                    Text(Copy.Screen2.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Palette.sub)
                        .padding(.top, 12)

                    Spacer(minLength: 36)

                    if let item {
                        BoardRow(
                            item: item,
                            state: confirmed ? .confirmed(age: 0, freshness: .fresh) : .unknown,
                            statusOverride: confirmed ? Copy.Screen2.loggedJustNow : nil,
                            onConfirm: { confirm(item) },
                            onUndo: confirmed ? { undo(item) } : nil
                        )
                        .padding(.horizontal, -26)

                        if confirmed {
                            Text(Copy.onboardingConfirmation)
                                .font(boardScaled(.caption, .medium))
                                .foregroundStyle(Palette.fresh)
                                .padding(.top, 18)
                                .transition(.opacity)
                        }
                    }

                    Spacer(minLength: 36)

                    Text(Copy.Screen2.footer)
                        .font(.caption)
                        .foregroundStyle(Palette.dim)
                        .frame(maxWidth: .infinity)
                }
                .frame(minHeight: geometry.size.height)
                .padding(.horizontal, 26)
                .padding(.top, 40)
                .padding(.bottom, 30)
                .contentShape(.rect)
                // Auto-advance after 2.5s, or on tap of anywhere.
                .onTapGesture { if confirmed { onDone() } }
            }
            .scrollIndicators(.hidden)
        }
        .alert(Copy.saveFailedTitle, isPresented: $showingSaveError) {
            Button(Copy.ok) {}
        } message: {
            Text(Copy.saveFailedBody)
        }
    }

    /// Not a simulation: real haptic, real entry in the real store.
    private func confirm(_ item: Item) {
        guard !confirmed else { return onDone() }
        do {
            try StoreIO.mutate {
                $0.confirm(id: item.id, at: .now)
                $0.flags.practiceTapCompleted = true
            }
            store = try StoreIO.load()
        } catch {
            reportSaveError()
            return
        }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.board)

        withAnimation(.snappy) { confirmed = true }
        UIAccessibility.post(notification: .announcement, argument: Copy.onboardingConfirmation)

        advanceTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            onDone()
        }
    }

    /// Mirrors `BoardView.undo` — same haptic, same store call, same
    /// announcement — so the practice screen teaches the real interaction
    /// rather than a lookalike.
    private func undo(_ item: Item) {
        advanceTask?.cancel()
        do {
            try StoreIO.mutate { $0.undo(id: item.id) }
            store = try StoreIO.load()
        } catch {
            reportSaveError()
            return
        }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.board)
        withAnimation(.snappy) { confirmed = false }
        UIAccessibility.post(notification: .announcement, argument: Copy.undone)
    }

    private func reportSaveError() {
        showingSaveError = true
        UIAccessibility.post(notification: .announcement, argument: Copy.saveFailedBody)
    }
}

// MARK: - Screen 3

private struct WidgetScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @Binding var store: Store
    let onDone: () -> Void

    @State private var showingWalkthrough = false
    @State private var askingAboutNudge = false
    @State private var showingSaveError = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Copy.Screen3.title)
                        .font(boardScaled(.title3, .semibold))
                        .foregroundStyle(Palette.text)
                    Text(Copy.Screen3.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Palette.sub)
                        .padding(.top, 12)

                    Spacer(minLength: 28)
                    widgetPreview
                    Spacer(minLength: 28)

                    Text(Copy.Screen3.steps)
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                        .padding(.bottom, 14)

                    Button(Copy.Screen3.showMe) { showingWalkthrough = true }
                        .buttonStyle(PrimaryButton())

                    Button(Copy.Screen3.later) { askingAboutNudge = true }
                        .buttonStyle(SecondaryButton())
                        .padding(.top, 4)
                }
                .frame(minHeight: geometry.size.height)
                .padding(.horizontal, 26)
                .padding(.top, 40)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showingWalkthrough) { WalkthroughSheet() }
        .sheet(isPresented: $askingAboutNudge) {
            NudgeSheet(
                onYes: { optIn in
                    if record(.later, notificationOptIn: optIn) { onDone() }
                },
                onNo: {
                    if record(.later, notificationOptIn: false) { onDone() }
                }
            )
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { checkForInstalledWidget() }
        }
        .task { await checkForInstalledWidgetAsync() }
        .alert(Copy.saveFailedTitle, isPresented: $showingSaveError) {
            Button(Copy.ok) {}
        } message: {
            Text(Copy.saveFailedBody)
        }
    }

    /// A live preview of what they are being asked to install.
    private var widgetPreview: some View {
        MediumFace(
            items: store.active,
            states: Dictionary(uniqueKeysWithValues: store.active.map {
                ($0.id, store.state($0, now: .now))
            }),
            date: .now
        )
        .padding(15)
        .frame(height: 158)
        .background(Palette.panel, in: .rect(cornerRadius: 24))
        .shadow(color: .black.opacity(0.5), radius: 25, y: 24)
    }

    private func checkForInstalledWidget() {
        Task { await checkForInstalledWidgetAsync() }
    }

    /// Detected via the widget configuration callback. Don't congratulate them —
    /// installing a widget is a preference, not an achievement.
    private func checkForInstalledWidgetAsync() async {
        // The async `currentConfigurations()` is iOS 18; we target 17.
        let installed = await withCheckedContinuation { continuation in
            WidgetCenter.shared.getCurrentConfigurations { result in
                continuation.resume(returning: (try? result.get())?.isEmpty == false)
            }
        }
        guard installed else { return }
        if record(.installed, notificationOptIn: store.flags.notificationOptIn) {
            onDone()
        }
    }

    private func record(_ outcome: OnboardingFlags.WidgetPrompt, notificationOptIn: Bool) -> Bool {
        do {
            try StoreIO.mutate {
                $0.flags.widgetPromptOutcome = outcome
                $0.flags.notificationOptIn = notificationOptIn
                if outcome == .installed, $0.flags.widgetInstalledAt == nil {
                    $0.flags.widgetInstalledAt = .now
                }
            }
            store = try StoreIO.load()
            return true
        } catch {
            showingSaveError = true
            UIAccessibility.post(notification: .announcement, argument: Copy.saveFailedBody)
            return false
        }
    }
}

/// Also reached from the day-1 nudge, which deep-links here rather than to the
/// main screen.
struct WalkthroughSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(Copy.Screen3.walkthrough.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Text("\(index + 1)")
                                .font(boardScaled(.callout, .bold))
                                .foregroundStyle(Palette.amber)
                                .frame(width: 24, alignment: .leading)
                            Text(step)
                                .font(.body)
                                .foregroundStyle(Palette.text)
                        }
                    }
                    Text(Copy.Screen3.whichItem)
                        .font(.footnote)
                        .foregroundStyle(Palette.sub)
                    Spacer(minLength: 20)
                    Button(Copy.done) { dismiss() }
                        .buttonStyle(PrimaryButton())
                }
                .padding(30)
                .frame(minHeight: geometry.size.height, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Palette.ink)
        .presentationDetents([.medium, .large])
    }
}

/// The only permission ask on Day 0, and only down the "Later" branch.
private struct NudgeSheet: View {
    let onYes: (Bool) -> Void
    let onNo: () -> Void

    @State private var checkedExistingDenial = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Copy.Screen3.nudgeTitle)
                        .font(boardScaled(.headline, .semibold))
                        .foregroundStyle(Palette.text)
                    Text(Copy.Screen3.nudgeBody)
                        .font(.subheadline)
                        .foregroundStyle(Palette.sub)
                        .padding(.top, 14)

                    Spacer(minLength: 24)

                    Button(Copy.Screen3.yesOnce) {
                        Task {
                            let granted = (try? await UNUserNotificationCenter.current()
                                .requestAuthorization(options: [.alert, .sound])) ?? false
                            onYes(granted)
                        }
                    }
                    .buttonStyle(PrimaryButton())

                    Button(Copy.Screen3.noThanks) { onNo() }
                        .buttonStyle(SecondaryButton())
                        .padding(.top, 4)
                }
                .padding(30)
                .frame(minHeight: geometry.size.height, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Palette.ink)
        .presentationDetents([.medium, .large])
        .task {
            // Reinstall with a prior OS-level denial: skip the sheet entirely
            // rather than offer something we cannot deliver.
            guard !checkedExistingDenial else { return }
            checkedExistingDenial = true
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .denied { onNo() }
        }
    }
}

// MARK: - Shared

struct PrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(boardScaled(.callout, .bold))
            .tracking(2.5)
            .textCase(.uppercase)
            .foregroundStyle(Palette.onAmber)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Palette.amber, in: .rect(cornerRadius: 14))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .contentShape(.rect)
    }
}

struct SecondaryButton: ButtonStyle {
    var alignment: Alignment = .center

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Palette.muted)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: alignment)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(.rect)
    }
}
