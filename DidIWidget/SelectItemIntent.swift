import AppIntents
import DidICore

/// Which item the single-item families show. `nil` falls back to the first item,
/// so an unconfigured widget is still useful.
struct SelectItemIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose item"
    static let description = IntentDescription("Pick which item this widget shows.")

    @Parameter(title: "Item") var item: ItemEntity?
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
