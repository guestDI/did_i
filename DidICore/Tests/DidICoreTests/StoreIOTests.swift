import Testing
import Foundation
@testable import DidICore

// The coordination around `decode` needs an App Group container and is exercised
// on device. What is checked here is the distinction the whole write path rests
// on: a file that is absent is a new install, and a file that is present but
// unreadable is *not*. Getting that wrong let `mutate` overwrite every item with
// an empty store, which is why it is pinned down.

private func tempURL() -> URL {
    FileManager.default.temporaryDirectory
        .appending(path: "didi-test-\(UUID().uuidString).json")
}

@Test func anAbsentFileIsAFreshInstall() throws {
    let store = try StoreIO.decode(from: tempURL())
    #expect(store.items.isEmpty)
    #expect(store.home == nil)
}

@Test func anUndecodableFileThrowsRatherThanReadingAsEmpty() throws {
    let url = tempURL()
    try Data("{ this is not the store }".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    #expect(throws: (any Error).self) { try StoreIO.decode(from: url) }
    // The display path is still allowed to flatten it; only writes must not.
    #expect((try? StoreIO.decode(from: url)) == nil)
}

@Test func aWrittenStoreComesBackWithItsItems() throws {
    let url = tempURL()
    defer { try? FileManager.default.removeItem(at: url) }
    var original = Store(items: [item()])
    original.confirm(id: original.items[0].id, at: at("2026-08-11 09:00:00"), calendar: utc)
    try StoreIO.encoder.encode(original).write(to: url)

    let back = try StoreIO.decode(from: url)
    #expect(back.items == original.items)
}

// MARK: - Retention

@Test func pruningDropsHistoryOlderThanThirtyDaysAnywhereItHides() {
    let now = at("2026-08-11 09:00:00")
    let old = now.addingTimeInterval(-40 * 86_400)
    let recent = now.addingTimeInterval(-2 * 86_400)

    var s = Store(items: [item()])
    let id = s.items[0].id
    s.items[0].confirmations = [old, recent]
    s.usage.checks[id.uuidString] = [old, recent]
    s.usage.checks["a-dead-archived-item"] = [old]
    s.usage.appOpens = [old, recent]

    s.pruneHistory(now: now)

    #expect(s.items[0].confirmations == [recent])
    #expect(s.usage.checks[id.uuidString] == [recent])
    // An archived item whose every check has aged out leaves no key behind.
    #expect(s.usage.checks["a-dead-archived-item"] == nil)
    #expect(s.usage.appOpens == [recent])
}

@Test func pruningNeverRemovesTheItemItself() {
    let now = at("2026-08-11 09:00:00")
    var s = Store(items: [item()])
    s.items[0].confirmations = [now.addingTimeInterval(-40 * 86_400)]
    s.archive(s.items[0].id, at: now)

    s.pruneHistory(now: now)

    #expect(s.items.count == 1)
    #expect(s.items[0].archivedAt == now)
    #expect(s.items[0].confirmations == [])
}

// MARK: - Timeline boundaries

@Test func boundariesAreUniqueAndSkipArchivedItems() {
    let confirmedAt = at("2026-08-11 09:00:00")
    // Three items sharing one reset hour used to yield three identical timestamps
    // each, crowding a timeline capped at 20.
    var s = Store(items: [item(), item(), item()])
    for i in s.items.indices { s.items[i].lastConfirmedAt = confirmedAt }

    let shared = s.allBoundaries(after: confirmedAt, calendar: utc)
    #expect(shared == Array(Set(shared)).sorted())
    #expect(shared.count == 2)   // ages-at and expiry, once between them

    s.archive(s.items[0].id, at: confirmedAt)
    #expect(s.allBoundaries(after: confirmedAt, calendar: utc) == shared)

    for id in s.active.map(\.id) { s.archive(id, at: confirmedAt) }
    #expect(s.allBoundaries(after: confirmedAt, calendar: utc).isEmpty)
}
