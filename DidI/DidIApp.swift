import SwiftUI

@main
struct DidIApp: App {
    init() {
        StoreChange.startListening()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}
