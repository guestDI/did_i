import AppIntents
import DidICore

/// Which item the single-item families show. `nil` falls back to the first item,
/// so an unconfigured widget is still useful.
struct SelectItemIntent: WidgetConfigurationIntent {
    // These four cannot come from DidICore: the AppIntents metadata extractor
    // rejects any bundle but the extension's own ("AppIntents requires
    // 'LocalizedStringResource' to use the main bundle"). They are translated in
    // DidIWidget/en.lproj/Localizable.strings instead — the one place in the
    // product with a second string file, and the reason it exists.
    static let title: LocalizedStringResource = "Choose item"
    static let description = IntentDescription("Pick which item this widget shows.")

    @Parameter(title: "Item") var item: ItemEntity?
}

/// Control Center's counterpart to `SelectItemIntent`. Same picker, same
/// entity — `ControlConfigurationIntent` is a distinct protocol from
/// `WidgetConfigurationIntent` (and, unlike it, requires `perform()`), so it
/// cannot just reuse the widget's intent type.
@available(iOS 18.0, *)
struct SelectControlItemIntent: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Choose item"
    static let description = IntentDescription("Pick which item this widget shows.")

    @Parameter(title: "Item") var item: ItemEntity?

    init() {}
    init(item: ItemEntity?) {
        self.item = item
    }

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct ItemEntity: AppEntity {
    let id: String
    let name: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Item"
    static let defaultQuery = ItemQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct ItemQuery: EntityQuery {
    private func live() -> [ItemEntity] {
        StoreIO.read().items
            .filter { $0.archivedAt == nil }
            .sorted { $0.order < $1.order }
            .map { ItemEntity(id: $0.id.uuidString, name: $0.name) }
    }

    func entities(for identifiers: [String]) async throws -> [ItemEntity] {
        live().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ItemEntity] {
        live()
    }

    func defaultResult() async -> ItemEntity? {
        live().first
    }
}
