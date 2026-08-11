import SwiftUI
import WidgetKit
import DidICore

struct BoardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = StoreIO.read()
    @State private var editing: Item?

    var body: some View {
        // TimelineView supplies `now`. Nothing stores display state.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 0) {
                header(now: context.date)
                Spacer(minLength: 0)
                columnHeadings
                ForEach(store.active) { item in
                    row(item: item, now: context.date)
                }
                footer
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
            ItemSettingsView(item: item, hasHome: store.home != nil) { updated in
                save { store in
                    guard let i = store.items.firstIndex(where: { $0.id == updated.id })
                    else { return }
                    store.items[i] = updated
                }
            }
        }
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
            Text(now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                .font(board(10, .medium))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
    }

    private var columnHeadings: some View {
        HStack {
            Text("Item")
            Spacer()
            Text("Status")
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
            onConfirm: { confirm(item) },
            onUndo: item.lastConfirmedAt == nil ? nil : { undo(item) },
            onEditName: { editing = item }
        )
    }

    // MARK: - Actions

    private func confirm(_ item: Item) {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        save { $0.confirm(id: item.id, at: .now) }
        if let line = store.items.first(where: { $0.id == item.id })?.confirmationLine {
            UIAccessibility.post(notification: .announcement, argument: line)
        }
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
