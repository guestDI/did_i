import SwiftUI
import DidICore

@main
struct DidIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-resetStoreForUITesting") {
            try? FileManager.default.removeItem(at: StoreIO.storeURL)
        }
        #endif
        StoreChange.startListening()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}
