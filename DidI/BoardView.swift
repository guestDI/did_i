import SwiftUI
import WidgetKit
import StoreKit
import DidICore

struct BoardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = StoreIO.read()
    @State private var editing: Item?
    @State private var dayTwo: DayTwoFlow.Step?
    @State private var sharing: Item?
    @State private var showingSettings = false
    @State private var showingWalkthrough = false
    @State private var adding: AddItemSheet.Presentation?
    @State private var weeklyCard: ParanoiaCounter.Card?
    @State private var guardrailItem: Item?
    @State private var staleItem: Item?
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        // TimelineView supplies `now`. Nothing stores display state.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 0) {
                header(now: context.date)
                // The board is top-anchored, not bottom-anchored as design 1a
                // draws it: day-2 requires the list stay visible behind the
                // lesson sheet, and the sheet lands exactly where the design
                // parks the rows.
                if let weeklyCard {
                    ParanoiaCard(card: weeklyCard) { dismissWeeklyCard() }
                        .padding(.top, 22)
                }
                columnHeadings
                    .padding(.top, 26)
                ForEach(store.active) { item in
                    row(item: item, now: context.date)
                }
                footer
                Spacer(minLength: 0)
            }
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.ink)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: StoreChange.name)) { _ in
            reload()
        }
        .sheet(item: $editing) { item in
            ItemSettingsView(
                item: item,
                hasHome: store.home != nil,
                save: { updated in
                    save { store in
                        guard let i = store.items.firstIndex(where: { $0.id == updated.id })
                        else { return }
                        store.items[i] = updated
                    }
                },
                archive: { save { $0.archive(item.id, at: .now) } }
            )
        }
        .sheet(item: $sharing) { item in
            ShareSheet(text: Copy.shareMessage(item: item))
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(store: $store)
        }
        .sheet(isPresented: $showingWalkthrough) { WalkthroughSheet() }
        .sheet(item: $adding) { presentation in
            AddItemSheet(store: $store, suggestion: presentation.suggestion)
        }
        .alert(
            "",
            isPresented: Binding(get: { guardrailItem != nil }, set: { if !$0 { guardrailItem = nil } })
        ) {
            Button("OK") { dismissGuardrail() }
        } message: {
            if let guardrailItem { Text(Copy.escalatingChecks(item: guardrailItem)) }
        }
        .alert(
            staleItem.map { Copy.StaleItem.title(item: $0) } ?? "",
            isPresented: Binding(get: { staleItem != nil }, set: { if !$0 { staleItem = nil } })
        ) {
            if let staleItem {
                Button(Copy.StaleItem.archive) { answerStaleOffer(staleItem, archiving: true) }
                Button(Copy.StaleItem.keep) { answerStaleOffer(staleItem, archiving: false) }
            }
        } message: {
            Text(Copy.StaleItem.body)
        }
        .onReceive(NotificationCenter.default.publisher(for: AppDelegate.openWalkthrough)) { _ in
            // The nudge deep-links to the install instructions, not here.
            showingWalkthrough = true
        }
        .sheet(item: $dayTwo) { step in
            DayTwoFlow(step: step) {
                dayTwo = nil
                reload()
            }
        }
        .task { await onOpen() }
    }

    /// day-2 fires on the first open where something has aged out — not on a
    /// schedule. If they do not open the app for a week, it fires the day they do.
    private func onOpen() async {
        await Notifications.reconcileWidgetNudge()
        try? StoreIO.mutate { $0.recordBoardView(at: .now) }
        reload()

        let aged = DecayLesson.agedOut(in: store, now: .now)
        if !aged.isEmpty {
            dayTwo = .lesson(aged)
            return
        }
        if store.flags.homeSetupPending, !store.flags.locationDeclined {
            dayTwo = .homeSetup
            return
        }

        // The guardrail runs first and can permanently silence the counter.
        if let escalating = EscalatingChecks.escalating(in: store, now: .now) {
            guardrailItem = escalating
            return
        }
        if let card = ParanoiaCounter.card(for: store, now: .now) {
            weeklyCard = card
            return
        }
        if let trigger = SecondItem.shouldSuggest(in: store, now: .now) {
            try? StoreIO.mutate { $0.usage.lastSuggestedAt = .now }
            adding = .init(suggestion: trigger)
            return
        }
        // Housekeeping last, and only ever one prompt per open.
        staleItem = StaleItem.needingArchiveOffer(in: store, now: .now)
    }

    /// Offered once, whatever they answer.
    private func answerStaleOffer(_ item: Item, archiving: Bool) {
        save { store in
            guard let i = store.items.firstIndex(where: { $0.id == item.id }) else { return }
            store.items[i].archiveOfferedAt = .now
            if archiving { store.archive(item.id, at: .now) }
        }
        staleItem = nil
    }

    /// One honest sentence, once, and then get out of the way.
    private func dismissGuardrail() {
        save {
            $0.usage.guardrailShown = true
            $0.usage.paranoiaSuppressed = true
        }
        guardrailItem = nil
    }

    private func dismissWeeklyCard() {
        save { $0.usage.weeklyCardDismissedAt = .now }
        weeklyCard = nil
    }

    // MARK: - Chrome

    private func header(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 5) {
                ForEach(Array("DID".enumerated()), id: \.offset) { _, c in
                    FlapCell(String(c), color: Palette.text, width: 32, height: 46, fontSize: 24)
                }
                Spacer().frame(width: 10)
                ForEach(Array("I?".enumerated()), id: \.offset) { _, c in
                    FlapCell(String(c), color: Palette.text, width: 32, height: 46, fontSize: 24)
                }
            }
            HStack {
                Text(now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(board(10, .medium))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.muted)
                Spacer()
                Button { adding = .init(suggestion: nil) } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.muted)
                }
                .accessibilityLabel(Copy.addAnItem)
                Button { showingSettings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.muted)
                }
                .accessibilityLabel(Copy.settings)
                .padding(.leading, 14)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
    }

    private var columnHeadings: some View {
        HStack {
            Text(Copy.columnItem)
            Spacer()
            Text(Copy.columnStatus)
        }
        .font(board(9))
        .tracking(3)
        .textCase(.uppercase)
        .foregroundStyle(Palette.dim)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.ruleStrong).frame(height: 1)
        }
    }

    private var footer: some View {
        Text(Copy.boardFooter)
            .font(board(8.5, .medium))
            .tracking(2.2)
            .textCase(.uppercase)
            .foregroundStyle(Palette.dim)
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
    }

    // MARK: - Rows

    /// The row is shared with the Day 0 practice card, so onboarding shows the
    /// same view the main screen does rather than a lookalike.
    private func row(item: Item, now: Date) -> some View {
        BoardRow(
            item: item,
            state: store.state(item, now: now),
            isAway: store.isAway,
            onConfirm: { confirm(item) },
            onUndo: item.lastConfirmedAt == nil ? nil : { undo(item) },
            onEditName: { editing = item }
        )
        .contextMenu {
            if store.isAway, store.state(item, now: now) == .unknown {
                Button(Copy.cantCheckRightNow) { mute(item) }
                Button(Copy.askSomeoneAtHome) { sharing = item }
            }
            // Position matters: this is also the order of the widget's cells.
            if store.active.first?.id != item.id {
                Button(Copy.moveUp) { save { $0.moveUp(item.id) } }
            }
            Button(Copy.forgetAfterTitle) { editing = item }
        }
    }

    private func mute(_ item: Item) {
        save { store in
            guard let i = store.items.firstIndex(where: { $0.id == item.id }) else { return }
            store.items[i].mutedUntilHome = true
        }
    }

    // MARK: - Actions

    private func confirm(_ item: Item) {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        save { $0.confirm(id: item.id, at: .now) }
        if let line = store.items.first(where: { $0.id == item.id })?.confirmationLine {
            UIAccessibility.post(notification: .announcement, argument: line)
        }
        askForReviewIfThingsAreGood()
    }

    /// day-3: only just after a confirmation, only at home, only after 15 days,
    /// and at most once every 120. Never while they're wondering about the stove.
    private func askForReviewIfThingsAreGood() {
        guard ReviewPrompt.shouldAsk(in: store, now: .now) else { return }
        save { $0.usage.lastReviewPromptAt = .now }
        requestReview()
    }

    private func undo(_ item: Item) {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        save { $0.undo(id: item.id) }
        UIAccessibility.post(notification: .announcement, argument: Copy.undone)
    }

    private func save(_ change: (inout Store) -> Void) {
        try? StoreIO.mutate(change)
        withAnimation(.snappy(duration: 0.28)) { store = StoreIO.read() }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.board)
    }

    private func reload() {
        store = StoreIO.read()
    }
}
