import AppIntents
import WidgetKit
import DidICore

/// Read, mutate, write, reload, return. Nothing else — this runs
/// out-of-process on a tight budget and cannot assume the app has ever run.
struct ConfirmItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Confirm"
    static let isDiscoverable = false

    @Parameter(title: "Item") var itemID: String

    init() {}

    init(itemID: String) {
        self.itemID = itemID
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: itemID) else { return .result() }
        try StoreIO.mutate { store in
            store.confirm(id: id, at: .now)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.board)
        if #available(iOS 18.0, *) {
            ControlCenter.shared.reloadControls(ofKind: WidgetKind.control)
        }
        return .result()
    }
}
