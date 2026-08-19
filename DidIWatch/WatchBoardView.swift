import SwiftUI
import DidICore

/// A glance, not a second app to operate: no confirm, no undo, no settings.
/// `TimelineView` keeps it live between pushes the same way the board and the
/// widget do — state is derived from `lastConfirmedAt` + now, never stored,
/// so nothing here has to wait for the phone to say "this item aged out."
struct WatchBoardView: View {
    var watchStore = WatchStore.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            List(watchStore.store.active) { item in
                row(item, now: context.date)
            }
        }
        .navigationTitle("Did I?")
        .overlay {
            if watchStore.store.active.isEmpty {
                Text(Copy.addAnItem)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { WatchStore.shared.start() }
    }

    private func row(_ item: Item, now: Date) -> some View {
        let state = watchStore.store.state(item, now: now)
        return HStack {
            Image(systemName: item.symbol)
                .foregroundStyle(Palette.color(for: state))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                Text(Copy.status(for: state, item: item))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
