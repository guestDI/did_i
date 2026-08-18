import SwiftUI
import WidgetKit
import StoreKit
import DidICore

struct BoardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: Store
    @State private var editing: Item?
    @State private var dayTwo: DayTwoFlow.Step?
    @State private var sharing: Item?
    @State private var showingSettings = false
    @State private var showingWalkthrough = false
    @State private var adding: AddItemSheet.Presentation?
    @State private var weeklyCard: ParanoiaCounter.Card?
    @State private var guardrailItem: Item?
    @State private var staleItem: Item?
    @State private var removing: Item?
    @State private var undoFeedback: [UUID: String] = [:]
    @State private var showingSaveError = false
    @Environment(\.requestReview) private var requestReview

    init(initialStore: Store) {
        _store = State(initialValue: initialStore)
    }

    var body: some View {
        // TimelineView supplies `now`. Nothing stores display state.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
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
                }
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
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
                existingItems: store.items,
                save: { updated in
                    save { store in
                        guard let i = store.items.firstIndex(where: { $0.id == updated.id })
                        else { return }
                        store.items[i] = updated
                    }
                }
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
            Button(Copy.ok) { dismissGuardrail() }
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
        .confirmationDialog(
            removing.map { Copy.putItAwayTitle(item: $0) } ?? "",
            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
            titleVisibility: .visible
        ) {
            if let removing {
                Button(Copy.putItAway) { archive(removing) }
            }
        } message: {
            Text(Copy.putItAwayFooter)
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
        .alert(Copy.saveFailedTitle, isPresented: $showingSaveError) {
            Button(Copy.ok) {}
        } message: {
            Text(Copy.saveFailedBody)
        }
        .task { await onOpen() }
    }

    /// day-2 fires on the first open where something has aged out — not on a
    /// schedule. If they do not open the app for a week, it fires the day they do.
    private func onOpen() async {
        await Notifications.reconcileWidgetNudge()
        do {
            try StoreIO.mutate { $0.recordBoardView(at: .now) }
            reload()
        } catch {
            reportSaveError()
        }

        let aged = DecayLesson.agedOut(in: store, now: .now)
        if !aged.isEmpty {
            dayTwo = .lesson(aged)
            return
        }
        if store.flags.shouldPromptForHomeSetup(at: .now) {
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
            guard save({ $0.usage.lastSuggestedAt = .now }) else { return }
            adding = .init(suggestion: trigger)
            return
        }
        // Housekeeping last, and only ever one prompt per open.
        staleItem = StaleItem.needingArchiveOffer(in: store, now: .now)
    }

    /// Offered once, whatever they answer.
    private func answerStaleOffer(_ item: Item, archiving: Bool) {
        guard save({ store in
            guard let i = store.items.firstIndex(where: { $0.id == item.id }) else { return }
            store.items[i].archiveOfferedAt = .now
            if archiving { store.archive(item.id, at: .now) }
        }) else { return }
        staleItem = nil
    }

    /// One honest sentence, once, and then get out of the way.
    private func dismissGuardrail() {
        guard save({
            $0.usage.guardrailShown = true
            $0.usage.paranoiaSuppressed = true
        }) else { return }
        guardrailItem = nil
    }

    private func dismissWeeklyCard() {
        guard save({ $0.usage.weeklyCardDismissedAt = .now }) else { return }
        weeklyCard = nil
    }

    // MARK: - Chrome

    private func header(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 5) {
                ForEach(Array("DID".enumerated()), id: \.offset) { _, c in
                    FlapCell(String(c), color: Palette.text, width: 32, height: 46, fontSize: 24)
                        .accessibilityHidden(true)
                }
                Spacer().frame(width: 10)
                ForEach(Array("I?".enumerated()), id: \.offset) { _, c in
                    FlapCell(String(c), color: Palette.text, width: 32, height: 46, fontSize: 24)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityHidden(true)
            HStack {
                Text(now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .boardFont(10, .medium, relativeTo: .caption2)
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.muted)
                    .accessibilityHidden(true)
                Spacer()
                Button { adding = .init(suggestion: nil) } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.muted)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .accessibilityLabel(Copy.addAnItem)
                Button { showingSettings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.muted)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
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
        .boardFont(9, relativeTo: .caption2)
        .tracking(3)
        .textCase(.uppercase)
        .foregroundStyle(Palette.dim)
        .accessibilityHidden(true)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.ruleStrong).frame(height: 1)
        }
    }

    private var footer: some View {
        Text(Copy.boardFooter)
            .boardFont(8.5, .medium, relativeTo: .caption2)
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
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                BoardRow(
                    item: item,
                    state: store.state(item, now: now),
                    statusOverride: undoFeedback[item.id],
                    isAway: store.isAway,
                    onConfirm: { confirm(item) },
                    onUndo: item.lastConfirmedAt == nil ? nil : { undo(item) }
                )
                rowActions(item: item, now: now)
                    .offset(x: rowActionOffset(for: item), y: 13)
            }
            if store.isAway, store.state(item, now: now) == .unknown {
                awayActions(item)
            }
        }
    }

    @ViewBuilder
    private func awayActions(_ item: Item) -> some View {
        HStack(spacing: 8) {
            if item.mutedUntilHome == true {
                Text(Copy.mutedUntilHome)
                    .appFont(12, relativeTo: .footnote)
                    .foregroundStyle(Palette.sub)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Button(Copy.cantCheckRightNow) { mute(item) }
                    .buttonStyle(ContextButton())
            }
            Button(Copy.askSomeoneAtHome) { sharing = item }
                .buttonStyle(ContextButton())
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 6)
    }

    private func rowActions(item: Item, now: Date) -> some View {
        Menu {
            Button(Copy.forgetAfterTitle) { editing = item }
            if item.lastConfirmedAt != nil {
                Button(Copy.undo, systemImage: "arrow.uturn.backward") { undo(item) }
            }
            Button(Copy.putItAway, systemImage: "archivebox") { removing = item }
            if store.isAway, store.state(item, now: now) == .unknown {
                Button(Copy.cantCheckRightNow) { mute(item) }
                Button(Copy.askSomeoneAtHome) { sharing = item }
            }
            // Position matters: this is also the order of the widget's cells.
            if store.active.first?.id != item.id {
                Button(Copy.moveUp) { save { $0.moveUp(item.id) } }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.dim)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Copy.moreActions)
    }

    /// The title is monospaced. Cap the menu before the flap column so custom
    /// 24-character names never collide with status cells on compact phones.
    private func rowActionOffset(for item: Item) -> CGFloat {
        min(22 + CGFloat(item.name.count) * 11.8, 170)
    }

    private func archive(_ item: Item) {
        // Dismiss first: archiving the last item swaps the whole hierarchy
        // (board → onboarding) out from under this dialog.
        removing = nil
        save { $0.archive(item.id, at: .now) }
    }

    private func mute(_ item: Item) {
        save { store in
            guard let i = store.items.firstIndex(where: { $0.id == item.id }) else { return }
            store.items[i].mutedUntilHome = true
        }
    }

    // MARK: - Actions

    private func confirm(_ item: Item) {
        guard save({ $0.confirm(id: item.id, at: .now) }) else { return }
        undoFeedback[item.id] = nil
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        if let line = store.items.first(where: { $0.id == item.id })?.confirmationLine {
            UIAccessibility.post(notification: .announcement, argument: line)
        }
        askForReviewIfThingsAreGood()
    }

    /// day-3: only just after a confirmation, only at home, only after 15 days,
    /// and at most once every 120. Never while they're wondering about the stove.
    private func askForReviewIfThingsAreGood() {
        guard ReviewPrompt.shouldAsk(in: store, now: .now) else { return }
        guard save({ $0.usage.lastReviewPromptAt = .now }) else { return }
        requestReview()
    }

    private func undo(_ item: Item) {
        guard save({ $0.undo(id: item.id) }) else { return }
        let previousRemains = store.items
            .first(where: { $0.id == item.id })?
            .lastConfirmedAt != nil
        if previousRemains {
            showUndoFeedback(for: item.id)
        } else {
            undoFeedback[item.id] = nil
        }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        UIAccessibility.post(
            notification: .announcement,
            argument: previousRemains ? Copy.previousConfirmationRestored : Copy.undone
        )
    }

    /// Undoing a repeated tap can legitimately leave an older green record in
    /// place. Say that visibly so the unchanged flap cannot read as a dead button.
    private func showUndoFeedback(for itemID: UUID) {
        let message = Copy.previousConfirmationRestored
        withAnimation(.snappy(duration: 0.2)) { undoFeedback[itemID] = message }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard undoFeedback[itemID] == message else { return }
            withAnimation(.snappy(duration: 0.2)) { undoFeedback[itemID] = nil }
        }
    }

    @discardableResult
    private func save(_ change: (inout Store) -> Void) -> Bool {
        do {
            try StoreIO.mutate(change)
            let updated = try StoreIO.load()
            withAnimation(.snappy(duration: 0.28)) { store = updated }
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.board)
            return true
        } catch {
            reportSaveError()
            return false
        }
    }

    private func reload() {
        do {
            store = try StoreIO.load()
        } catch {
            reportSaveError()
        }
    }

    private func reportSaveError() {
        showingSaveError = true
        UIAccessibility.post(notification: .announcement, argument: Copy.saveFailedBody)
    }
}

private struct ContextButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appFont(13, .semibold, relativeTo: .footnote)
            .foregroundStyle(Palette.text)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Palette.panel, in: .rect(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(.rect)
    }
}
