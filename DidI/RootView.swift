import SwiftUI
import DidICore

/// Onboarding until it is finished, then the board — and back to Screen 1 if the
/// board ever empties. day-3: an empty list shows the Day 0 question again, same
/// chips, no shame, no "your list is empty" heading.
struct RootView: View {
    @State private var store = StoreIO.read()

    private var needsOnboarding: Bool {
        !store.flags.isComplete || store.active.isEmpty
    }

    var body: some View {
        Group {
            if needsOnboarding {
                OnboardingView(store: store) { store = StoreIO.read() }
                    .id(store.flags.completedScreen)
            } else {
                BoardView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: StoreChange.name)) { _ in
            store = StoreIO.read()
        }
    }
}
