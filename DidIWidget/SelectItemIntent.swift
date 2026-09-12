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
    static let title: LocalizedStringResource = "Configure Did I?"
    static let description = IntentDescription("Small widgets show an item. Medium widgets show a workspace.")

    @Parameter(title: "Item (small widgets)") var item: ItemEntity?
    @Parameter(title: "Workspace (medium widget)") var workspace: WorkspaceEntity?
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
    let workspaceName: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Item"
    static let defaultQuery = ItemQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(workspaceName)")
    }
}

struct ItemQuery: EntityQuery {
    private func live(includeArchived: Bool = false) -> [ItemEntity] {
        let store = StoreIO.read()
        let items = includeArchived ? store.items : store.allActiveItems
        return items.map { item in
            ItemEntity(
                id: item.id.uuidString,
                name: item.name,
                workspaceName: store.workspaces.first { $0.id == item.workspaceID }?.name ?? ""
            )
        }
    }

    func entities(for identifiers: [String]) async throws -> [ItemEntity] {
        live(includeArchived: true).filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ItemEntity] {
        live()
    }

    func defaultResult() async -> ItemEntity? {
        let store = StoreIO.read()
        return live().first { entity in
            store.activeItems(in: store.selectedWorkspaceID).contains { $0.id.uuidString == entity.id }
        } ?? live().first
    }
}

struct WorkspaceEntity: AppEntity {
    let id: String
    let name: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Workspace"
    static let defaultQuery = WorkspaceQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct WorkspaceQuery: EntityQuery {
    private func live(includeArchived: Bool = false) -> [WorkspaceEntity] {
        let store = StoreIO.read()
        let workspaces = includeArchived ? store.workspaces : store.activeWorkspaces
        return workspaces.map {
            WorkspaceEntity(id: $0.id.uuidString, name: $0.name)
        }
    }

    func entities(for identifiers: [String]) async throws -> [WorkspaceEntity] {
        live(includeArchived: true).filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [WorkspaceEntity] { live() }
    func defaultResult() async -> WorkspaceEntity? {
        let selectedID = StoreIO.read().selectedWorkspaceID.uuidString
        return live().first { $0.id == selectedID } ?? live().first
    }
}
