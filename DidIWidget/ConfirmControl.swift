import AppIntents
import SwiftUI
import WidgetKit
import DidICore

/// What Control Center needs to draw the toggle: which item, how to label
/// it, and whether it currently reads as confirmed — a plain button has no
/// persisted appearance, so reflecting real state back to the user (and
/// having it survive reopening Control Center) requires a toggle.
struct ControlItemState: Sendable {
    let id: String
    let name: String
    let symbol: String
    let confirmed: Bool
}

/// A Control Center / Lock Screen control: on confirms the configured item
/// on the spot, off clears it back to unknown. Off clears the current visible
/// claim while retaining confirmation history; it is not `Store.undo`, which
/// would reveal the previous confirmation and make the toggle visibly snap back
/// on. A binary control needs an idempotent off. `promptsForUserConfiguration()` sends a first-time
/// add straight to the item picker, same as an unconfigured small widget
/// falling back to the first item.
@available(iOS 18.0, *)
struct ConfirmControl: ControlWidget {
    static let kind = WidgetKind.control

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: Provider()
        ) { state in
            ControlWidgetToggle(
                state.name,
                isOn: state.confirmed,
                action: SetConfirmedIntent(itemID: state.id),
                valueLabel: { isOn in
                    if isOn {
                        Label("Confirmed", systemImage: state.symbol)
                    } else {
                        Label("Not confirmed", systemImage: state.symbol)
                    }
                }
            )
        }
        .displayName("Did I?")
        .description("Confirm an item without opening the app. Add it again for each item you track.")
        .promptsForUserConfiguration()
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: SelectControlItemIntent) -> ControlItemState {
            state(for: configuration.item)
        }

        func currentValue(configuration: SelectControlItemIntent) async throws -> ControlItemState {
            state(for: configuration.item)
        }

        private func state(for entity: ItemEntity?) -> ControlItemState {
            let store = StoreIO.read()
            let resolved = entity
                .flatMap { picked in store.items.first { $0.id.uuidString == picked.id } }
                ?? store.active.first
            guard let resolved else {
                return ControlItemState(id: "", name: "Did I?", symbol: "checkmark.circle", confirmed: false)
            }
            let confirmed = store.state(resolved, now: .now) != .unknown
            return ControlItemState(
                id: resolved.id.uuidString, name: resolved.name, symbol: resolved.symbol, confirmed: confirmed
            )
        }
    }
}

/// Read, mutate, write, reload, return — same shape and budget as
/// `ConfirmItemIntent`, just with a direction: on confirms, off hard-clears.
@available(iOS 18.0, *)
struct SetConfirmedIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Confirm"

    @Parameter(title: "Confirmed") var value: Bool
    @Parameter(title: "Item") var itemID: String

    init() {}
    init(itemID: String) {
        self.itemID = itemID
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: itemID) else { return .result() }
        try StoreIO.mutate { store in
            if value {
                store.confirm(id: id, at: .now)
            } else {
                store.clearCurrentStatus(id: id)
            }
        }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.board)
        ControlCenter.shared.reloadControls(ofKind: WidgetKind.control)
        return .result()
    }
}
