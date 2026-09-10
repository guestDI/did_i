import Foundation

/// A short, independent board of items. Workspaces are organizational only:
/// the saved Home location and its geofence remain global to the app.
public struct Workspace: Codable, Identifiable, Sendable, Equatable {
    public static let maxNameLength = 24
    public static let legacyID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    public let id: UUID
    public var name: String
    public var createdAt: Date
    public var archivedAt: Date?
    public var order: Int

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date,
        archivedAt: Date? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.name = String(name.prefix(Self.maxNameLength))
        self.createdAt = createdAt
        self.archivedAt = archivedAt
        self.order = order
    }

    public static func home(createdAt: Date = Date(timeIntervalSince1970: 0)) -> Workspace {
        Workspace(id: legacyID, name: Copy.Workspaces.home, createdAt: createdAt)
    }

    public static func isNameAvailable(
        _ candidate: String,
        among workspaces: [Workspace],
        excluding excludedID: UUID? = nil,
        locale: Locale = .current
    ) -> Bool {
        let normalized = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
        guard !normalized.isEmpty else { return false }
        return !workspaces.contains {
            $0.archivedAt == nil && $0.id != excludedID
                && $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale) == normalized
        }
    }
}

public extension Store {
    static let workspaceCap = 6

    var activeWorkspaces: [Workspace] {
        workspaces.filter { $0.archivedAt == nil }.sorted { $0.order < $1.order }
    }

    var archivedWorkspaces: [Workspace] {
        workspaces.filter { $0.archivedAt != nil }.sorted { $0.order < $1.order }
    }

    var selectedWorkspace: Workspace {
        activeWorkspaces.first { $0.id == selectedWorkspaceID }
            ?? activeWorkspaces.first
            ?? Workspace.home()
    }

    var allActiveItems: [Item] {
        let activeIDs = Set(activeWorkspaces.map(\.id))
        return items.filter { $0.archivedAt == nil && activeIDs.contains($0.workspaceID) }
    }

    func activeItems(in workspaceID: UUID) -> [Item] {
        items.filter { $0.workspaceID == workspaceID && $0.archivedAt == nil }
            .sorted { $0.order < $1.order }
    }

    func archivedItems(in workspaceID: UUID) -> [Item] {
        items.filter { $0.workspaceID == workspaceID && $0.archivedAt != nil }
            .sorted { $0.order < $1.order }
    }

    mutating func selectWorkspace(_ id: UUID) {
        guard activeWorkspaces.contains(where: { $0.id == id }) else { return }
        selectedWorkspaceID = id
    }

    @discardableResult
    mutating func createWorkspace(named rawName: String, at date: Date) -> UUID? {
        let name = String(rawName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Workspace.maxNameLength))
        guard activeWorkspaces.count < Self.workspaceCap,
              Workspace.isNameAvailable(name, among: workspaces) else { return nil }
        let workspace = Workspace(
            name: name,
            createdAt: date,
            order: (workspaces.map(\.order).max() ?? -1) + 1
        )
        workspaces.append(workspace)
        selectedWorkspaceID = workspace.id
        return workspace.id
    }

    mutating func renameWorkspace(_ id: UUID, to rawName: String) {
        let name = String(rawName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Workspace.maxNameLength))
        guard Workspace.isNameAvailable(name, among: workspaces, excluding: id),
              let i = workspaces.firstIndex(where: { $0.id == id }) else { return }
        workspaces[i].name = String(name.prefix(Workspace.maxNameLength))
    }

    mutating func archiveWorkspace(_ id: UUID, at date: Date) {
        guard activeWorkspaces.count > 1,
              let i = workspaces.firstIndex(where: { $0.id == id }) else { return }
        workspaces[i].archivedAt = date
        if selectedWorkspaceID == id, let replacement = activeWorkspaces.first {
            selectedWorkspaceID = replacement.id
        }
    }

    mutating func restoreWorkspace(_ id: UUID) {
        guard activeWorkspaces.count < Self.workspaceCap,
              let i = workspaces.firstIndex(where: { $0.id == id }),
              Workspace.isNameAvailable(workspaces[i].name, among: workspaces, excluding: id)
        else { return }
        workspaces[i].archivedAt = nil
        selectedWorkspaceID = id
    }

    mutating func moveItem(_ id: UUID, to workspaceID: UUID) {
        guard activeWorkspaces.contains(where: { $0.id == workspaceID }),
              activeItems(in: workspaceID).count < Self.itemCap,
              let i = items.firstIndex(where: { $0.id == id }),
              Item.isNameAvailable(
                items[i].name,
                among: items.filter { $0.workspaceID == workspaceID },
                excluding: id
              ) else { return }
        items[i].workspaceID = workspaceID
        items[i].order = (items.filter { $0.workspaceID == workspaceID }.map(\.order).max() ?? -1) + 1
    }
}
