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
    }

    // MARK: - Screen 1 → 2

    private func pick(_ chip: Chip, name: String?) {
        // Refilling an emptied board is not a reinstall: take the item and get out
        // of the way. day-3 is explicit that we never re-onboard.
        let returning = store.flags.isComplete
        let item = chip.item(named: name, createdAt: .now)
        save {
            if $0.flags.installedAt == nil { $0.flags.installedAt = .now }
            if $0.flags.firstItemType == nil { $0.flags.firstItemType = chip.id }
            $0.add(item)
            if !returning { $0.flags.completedScreen = 1 }
        }
        if returning { finished() } else { screen = 2 }
    }

    /// Emptying the board lands here, and the "Previously" list lives in the add
    /// sheet — which an empty board can never reach. Without this, archiving your
    /// last item strands everything you ever archived.
    private func restore(_ item: Item) {
        save { $0.unarchive(item.id) }
        if store.flags.isComplete { finished() } else { screen = 2 }
    }

    private func advance(from finishedScreen: Int) {
        save { $0.flags.completedScreen = max($0.flags.completedScreen, finishedScreen) }
        screen = finishedScreen + 1
    }

    private func finish() {
        save { $0.flags.completedScreen = OnboardingFlags.lastScreen }
        finished()
    }

    private func save(_ change: (inout Store) -> Void) {
        try? StoreIO.mutate(change)
        store = StoreIO.read()
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.board)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Copy.Screen1.title)
                .font(board(21, .semibold))
                .foregroundStyle(Palette.text)
            Text(Copy.Screen1.subtitle)
                .font(.system(size: 13.5))
                .foregroundStyle(Palette.sub)
                .padding(.top, 12)

            if typing {
                // Return key stays disabled when empty. No error, no red border.
                TextField(Copy.Screen1.placeholder, text: $custom)
                    .font(board(15))
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .focused($focused)
                    .onChange(of: custom) { _, new in
                        if new.count > Item.maxNameLength {
                            custom = String(new.prefix(Item.maxNameLength))
                        }
                    }
                    .onSubmit { if !trimmed.isEmpty { onPick(.somethingElse, trimmed) } }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 18)
                    .background(Palette.panel, in: .rect(cornerRadius: 14))
                    .padding(.top, 28)
                    .onAppear { focused = true }
                    .accessibilityLabel(Copy.Screen1.returnKey)
            } else {
                chips.padding(.top, 28)
            }

            if archived.isEmpty {
                Spacer()
            } else {
                // Can grow past the screen, unlike the fixed chip grid.
                ScrollView {
                    PreviouslyList(archived: archived, onRestore: onRestore)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.bottom, 20)
            }

            Text(Copy.Screen1.footer)
                .font(.system(size: 11))
                .foregroundStyle(Palette.dim)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 26)
        .padding(.top, 40)
        .padding(.bottom, 30)
    }

    private var chips: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
            ForEach(Chip.available(excluding: items)) { chip in
                Button {
                    // Tapping a chip advances immediately. No Continue button.
                    if chip.id == Chip.somethingElse.id { typing = true } else { onPick(chip, nil) }
                } label: {
                    Text(chip.label)
                        .font(board(12))
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

    private var item: Item? { store.active.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Copy.Screen2.title)
                .font(board(21, .semibold))
                .foregroundStyle(Palette.text)
            Text(Copy.Screen2.subtitle)
                .font(.system(size: 13.5))
                .foregroundStyle(Palette.sub)
                .padding(.top, 12)

            Spacer()

            if let item {
                BoardRow(
                    item: item,
                    state: confirmed ? .confirmed(age: 0, freshness: .fresh) : .unknown,
                    statusOverride: confirmed ? Copy.Screen2.loggedJustNow : nil,
                    onConfirm: { confirm(item) }
                )
                .padding(.horizontal, -26)

                if confirmed {
                    Text(Copy.onboardingConfirmation)
                        .font(board(11, .medium))
                        .foregroundStyle(Palette.fresh)
                        .padding(.top, 18)
                        .transition(.opacity)
                }
            }

            Spacer()

            Text(Copy.Screen2.footer)
                .font(.system(size: 11))
                .foregroundStyle(Palette.dim)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 26)
        .padding(.top, 40)
        .padding(.bottom, 30)
        .contentShape(.rect)
        // Auto-advance after 2.5s, or on tap of anywhere.
        .onTapGesture { if confirmed { onDone() } }
    }

    /// Not a simulation: real haptic, real entry in the real store.
    private func confirm(_ item: Item) {
        guard !confirmed else { return onDone() }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        try? StoreIO.mutate {
            $0.confirm(id: item.id, at: .now)
            $0.flags.practiceTapCompleted = true
        }
        store = StoreIO.read()
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.board)

        withAnimation(.snappy) { confirmed = true }
        UIAccessibility.post(notification: .announcement, argument: Copy.onboardingConfirmation)

        Task {
            try? await Task.sleep(for: .seconds(2.5))
            onDone()
        }
    }
}

// MARK: - Screen 3

private struct WidgetScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @Binding var store: Store
    let onDone: () -> Void

    @State private var showingWalkthrough = false
    @State private var askingAboutNudge = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Copy.Screen3.title)
                .font(board(21, .semibold))
                .foregroundStyle(Palette.text)
            Text(Copy.Screen3.subtitle)
                .font(.system(size: 13.5))
                .foregroundStyle(Palette.sub)
                .padding(.top, 12)

            Spacer()
            widgetPreview
            Spacer()

            Text(Copy.Screen3.steps)
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .padding(.bottom, 22)

            Button(Copy.Screen3.showMe) { showingWalkthrough = true }
                .buttonStyle(PrimaryButton())

            Button(Copy.Screen3.later) { askingAboutNudge = true }
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
        }
        .padding(.horizontal, 26)
        .padding(.top, 40)
        .padding(.bottom, 30)
        .sheet(isPresented: $showingWalkthrough) { WalkthroughSheet() }
        .sheet(isPresented: $askingAboutNudge) {
            NudgeSheet(
                onYes: { optIn in
                    record(.later, notificationOptIn: optIn)
                    onDone()
                },
                onNo: {
                    record(.later, notificationOptIn: false)
                    onDone()
                }
            )
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { checkForInstalledWidget() }
        }
        .task { await checkForInstalledWidgetAsync() }
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
        record(.installed, notificationOptIn: store.flags.notificationOptIn)
        onDone()
    }

    private func record(_ outcome: OnboardingFlags.WidgetPrompt, notificationOptIn: Bool) {
        try? StoreIO.mutate {
            $0.flags.widgetPromptOutcome = outcome
            $0.flags.notificationOptIn = notificationOptIn
            if outcome == .installed, $0.flags.widgetInstalledAt == nil {
                $0.flags.widgetInstalledAt = .now
            }
        }
        store = StoreIO.read()
    }
}

/// Also reached from the day-1 nudge, which deep-links here rather than to the
/// main screen.
struct WalkthroughSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(Copy.Screen3.walkthrough.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text("\(index + 1)")
                        .font(board(12, .bold))
                        .foregroundStyle(Palette.amber)
                        .frame(width: 18, alignment: .leading)
                    Text(step)
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.text)
                }
            }
            Spacer()
            Button(Copy.done) { dismiss() }
                .buttonStyle(PrimaryButton())
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Palette.ink)
        .presentationDetents([.medium])
    }
}

/// The only permission ask on Day 0, and only down the "Later" branch.
private struct NudgeSheet: View {
    let onYes: (Bool) -> Void
    let onNo: () -> Void

    @State private var checkedExistingDenial = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Copy.Screen3.nudgeTitle)
                .font(board(18, .semibold))
                .foregroundStyle(Palette.text)
            Text(Copy.Screen3.nudgeBody)
                .font(.system(size: 14))
                .foregroundStyle(Palette.sub)
                .padding(.top, 14)

            Spacer()

            Button(Copy.Screen3.yesOnce) {
                Task {
                    let granted = (try? await UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .sound])) ?? false
                    onYes(granted)
                }
            }
            .buttonStyle(PrimaryButton())

            Button(Copy.Screen3.noThanks) { onNo() }
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Palette.ink)
        .presentationDetents([.height(280)])
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(board(12, .bold))
            .tracking(2.5)
            .textCase(.uppercase)
            .foregroundStyle(Palette.onAmber)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Palette.amber, in: .rect(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
