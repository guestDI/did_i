import SwiftUI
import DidICore

/// Onboarding until it is finished, then the board — and back to Screen 1 if the
/// board ever empties. day-3: an empty list shows the Day 0 question again, same
/// chips, no shame, no "your list is empty" heading.
struct RootView: View {
    @State private var store: Store
    @State private var loadFailed: Bool

    init() {
        do {
            _store = State(initialValue: try StoreIO.load())
            _loadFailed = State(initialValue: false)
        } catch {
            _store = State(initialValue: Store())
            _loadFailed = State(initialValue: true)
        }
    }

    private var needsOnboarding: Bool {
        !store.flags.isComplete || store.active.isEmpty
    }

    var body: some View {
        Group {
            if loadFailed {
                VStack(spacing: 16) {
                    Text(Copy.loadFailedTitle)
                        .font(boardScaled(.headline, .semibold))
                        .foregroundStyle(Palette.text)
                    Text(Copy.loadFailedBody)
                        .font(.subheadline)
                        .foregroundStyle(Palette.sub)
                        .multilineTextAlignment(.center)
                    Button(Copy.tryAgain) { reload() }
                        .buttonStyle(PrimaryButton())
                }
                .padding(30)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.ink)
            } else if needsOnboarding {
                OnboardingView(store: store) { reload() }
                    .id(store.flags.completedScreen)
            } else {
                BoardView(initialStore: store)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: StoreChange.name)) { _ in
            reload()
        }
    }

    private func reload() {
        do {
            store = try StoreIO.load()
            loadFailed = false
        } catch {
            loadFailed = true
            UIAccessibility.post(notification: .announcement, argument: Copy.loadFailedBody)
        }
    }
}
