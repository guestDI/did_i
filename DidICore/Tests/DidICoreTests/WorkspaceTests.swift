import Testing
import Foundation
@testable import DidICore

@Test func legacyStoreGetsAStableHomeWorkspace() throws {
    let legacy = """
    {"items":[{
      "id":"11111111-1111-1111-1111-111111111111",
      "name":"The stove","word":"Off","symbol":"flame",
      "resetRule":{"dailyAt":{"hour":4}},
      "createdAt":"2026-08-10T22:00:00Z","order":0
    }]}
    """
    let decoded = try StoreIO.decoder.decode(Store.self, from: Data(legacy.utf8))
    #expect(decoded.workspaces.map(\.id) == [Workspace.legacyID])
    #expect(decoded.selectedWorkspaceID == Workspace.legacyID)
    #expect(decoded.items[0].workspaceID == Workspace.legacyID)
}

@Test func workspacesKeepIndependentBoardsAndCaps() {
    var store = Store()
    let workID = store.createWorkspace(named: "Work", at: .now)!
    for _ in 0..<Store.itemCap { store.add(item(), to: workID) }
    #expect(store.isFull)

    store.selectWorkspace(Workspace.legacyID)
    #expect(store.active.isEmpty)
    #expect(!store.isFull)
    store.add(item())
    #expect(store.active.count == 1)
    #expect(store.allActiveItems.count == Store.itemCap + 1)
}

@Test func theSameItemNameIsAllowedInDifferentWorkspaces() {
    var store = Store(items: [item()])
    let workID = store.createWorkspace(named: "Work", at: .now)!
    #expect(Item.isNameAvailable(store.items[0].name, among: store.items.filter { $0.workspaceID == workID }))
    store.add(item(), to: workID)
    #expect(store.activeItems(in: Workspace.legacyID).count == 1)
    #expect(store.activeItems(in: workID).count == 1)
}

@Test func movingAnItemPreservesItsEvidenceAndMovesItToTheBottom() {
    var store = Store(items: [item()])
    let id = store.items[0].id
    store.confirm(id: id, at: at("2026-08-11 09:00:00"), calendar: utc)
    let workID = store.createWorkspace(named: "Work", at: .now)!
    var existing = item()
    existing.name = "Printer"
    store.add(existing, to: workID)

    store.moveItem(id, to: workID)

    #expect(store.items.first { $0.id == id }?.lastConfirmedAt == at("2026-08-11 09:00:00"))
    #expect(store.activeItems(in: workID).last?.id == id)
}

@Test func archivingAWorkspacePreservesItsItemsAndRepairsSelection() {
    var store = Store(items: [item()])
    let workID = store.createWorkspace(named: "Work", at: .now)!
    store.add(item(), to: workID)
    store.archiveWorkspace(workID, at: at("2026-08-11 09:00:00"))

    #expect(store.selectedWorkspaceID == Workspace.legacyID)
    #expect(store.items.count == 2)
    #expect(store.allActiveItems.count == 1)

    store.restoreWorkspace(workID)
    #expect(store.selectedWorkspaceID == workID)
    #expect(store.active.count == 1)
}

@Test func workspaceNamesAreUniqueAndCapped() {
    var store = Store()
    #expect(store.createWorkspace(named: "Work", at: .now) != nil)
    #expect(store.createWorkspace(named: " work ", at: .now) == nil)
    for index in 2..<Store.workspaceCap {
        #expect(store.createWorkspace(named: "Place \(index)", at: .now) != nil)
    }
    #expect(store.createWorkspace(named: "One too many", at: .now) == nil)
}

@Test func archivedWorkspaceNamesRemainReserved() {
    var store = Store()
    let workID = store.createWorkspace(named: "Work", at: .now)!
    store.archiveWorkspace(workID, at: .now)

    #expect(store.createWorkspace(named: " work ", at: .now) == nil)
    store.restoreWorkspace(workID)
    #expect(store.activeWorkspaces.contains { $0.id == workID })
}

@Test func workspacesCanBeReordered() {
    var store = Store()
    let workID = store.createWorkspace(named: "Work", at: .now)!
    store.moveWorkspaceUp(workID)
    #expect(store.activeWorkspaces.map(\.id) == [workID, Workspace.legacyID])
}
