import SwiftUI
import DidICore

@main
struct DidIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-resetStoreForUITesting") {
            try? FileManager.default.removeItem(at: StoreIO.storeURL)
        }
        if arguments.contains("-appStoreScreenshotBoard") {
            try? StoreIO.write(Self.appStoreScreenshotStore(now: .now))
        }
        #endif
        StoreChange.startListening()
        WatchSync.shared.start()
    }

    #if DEBUG
    /// Stable, truthful data for App Store screenshots. It is compiled out of
    /// release builds and only selected by the screenshot UI test launch flag.
    private static func appStoreScreenshotStore(now: Date) -> Store {
        let items = Array(Chip.all.prefix(3)).enumerated().map { order, chip in
            var item = chip.item(createdAt: now.addingTimeInterval(-14 * 86_400))
            item.order = order
            return item
        }
        var store = Store(
            items: items,
            flags: OnboardingFlags(
                installedAt: now.addingTimeInterval(-14 * 86_400),
                completedScreen: OnboardingFlags.lastScreen,
                firstItemType: Chip.all[0].label,
                practiceTapCompleted: true,
                widgetPromptOutcome: .installed,
                widgetInstalledAt: now.addingTimeInterval(-14 * 86_400),
                decayLessonShown: true,
                locationDeclined: true,
                settingsHintShown: true
            )
        )
        store.confirm(id: items[0].id, at: now.addingTimeInterval(-5 * 60))
        store.confirm(id: items[1].id, at: now.addingTimeInterval(-2 * 3600))
        for index in 0..<2 {
            store.items[index].confirmationLine = nil
        }
        return store
    }
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}
