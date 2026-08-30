import Testing
import Foundation
@testable import DidICore

// Store mutation is pure — `StoreIO`'s disk half needs an App Group container
// and is exercised on device, not here.

private func store(_ rule: ResetRule = .dailyAt(hour: 4)) -> Store {
    Store(items: [item(rule: rule)])
}

@Test func confirmStampsTheItemAndPicksALine() {
    var s = store()
    let id = s.items[0].id
    s.confirm(id: id, at: at("2026-08-11 09:00:00"), calendar: utc)

    #expect(s.items[0].lastConfirmedAt == at("2026-08-11 09:00:00"))
    #expect(s.items[0].lastConfirmationRule == .dailyAt(hour: 4))
    #expect(s.items[0].confirmationRules == [.dailyAt(hour: 4)])
    #expect(Copy.general.contains(s.items[0].confirmationLine ?? ""))
    #expect(s.lastConfirmationLine == s.items[0].confirmationLine)
}

@Test func confirmingAnUnknownIdChangesNothing() {
    var s = store()
    s.confirm(id: UUID(), at: at("2026-08-11 09:00:00"), calendar: utc)
    #expect(s.items[0].lastConfirmedAt == nil)
    #expect(s.lastConfirmationLine == nil)
}

@Test func theStoredLineIsStableAcrossReadsOfTheSameConfirmation() {
    // The widget renders one confirmation at many timeline entries; the joke
    // must not reshuffle underneath it.
    var s = store()
    s.confirm(id: s.items[0].id, at: at("2026-08-11 09:00:00"), calendar: utc)
    let item = s.items[0]
    let first = Copy.status(for: .confirmed(age: 60, freshness: .fresh), item: item)
    let second = Copy.status(for: .confirmed(age: 600, freshness: .fresh), item: item)
    #expect(first == second)
}

@Test func thirdConfirmationInOneDayEscalates() {
    var s = store()
    let id = s.items[0].id
    s.confirm(id: id, at: at("2026-08-11 08:00:00"), calendar: utc)
    #expect(Copy.general.contains(s.items[0].confirmationLine ?? ""))
    s.confirm(id: id, at: at("2026-08-11 12:00:00"), calendar: utc)
    #expect(Copy.general.contains(s.items[0].confirmationLine ?? ""))
    s.confirm(id: id, at: at("2026-08-11 18:00:00"), calendar: utc)
    #expect(Copy.escalation.contains(s.items[0].confirmationLine ?? ""))
    #expect(s.items[0].confirmations?.count == 3)
}

@Test func theCountResetsWithTheDay() {
    var s = store()
    let id = s.items[0].id
    for hour in ["08", "12", "18"] {
        s.confirm(id: id, at: at("2026-08-11 \(hour):00:00"), calendar: utc)
    }
    s.confirm(id: id, at: at("2026-08-12 08:00:00"), calendar: utc)

    // History is kept for 30 days; it is the *day's* count that resets, which is
    // what de-escalates the line.
    #expect(s.items[0].confirmations?.count == 4)
    #expect(Copy.general.contains(s.items[0].confirmationLine ?? ""))
}

@Test func escalationCountsOneItemNotTheBoard() {
    var s = Store(items: [item(rule: .dailyAt(hour: 4)), item(rule: .dailyAt(hour: 4))])
    for i in 0..<3 {
        s.confirm(id: s.items[i % 2].id, at: at("2026-08-11 0\(8 + i):00:00"), calendar: utc)
    }
    // Two taps on one, one on the other — nobody has reached three.
    #expect(s.items.allSatisfy { Copy.general.contains($0.confirmationLine ?? "") })
}

@Test func storeStateAppliesTheGeofenceEntry() {
    var s = store(.onComingHome)
    s.confirm(id: s.items[0].id, at: at("2026-08-11 08:00:00"), calendar: utc)
    s.lastEnteredHomeAt = at("2026-08-11 08:42:00")
    #expect(s.state(s.items[0], now: at("2026-08-11 09:00:00"), calendar: utc) == .unknown)
}

@Test func changingExpiryCannotResurrectAnExpiredConfirmation() {
    var s = store(.afterHours(4))
    let id = s.items[0].id
    s.confirm(id: id, at: at("2026-08-11 08:00:00"), calendar: utc)
    #expect(s.state(s.items[0], now: at("2026-08-11 13:00:00"), calendar: utc) == .unknown)

    var updated = s.items[0]
    updated.resetRule = .never
    s.update(updated)

    #expect(s.items[0].resetRule == .never)
    #expect(s.items[0].lastConfirmationRule == .afterHours(4))
    #expect(s.state(s.items[0], now: at("2026-08-11 13:00:00"), calendar: utc) == .unknown)
}

@Test func changedExpiryStartsWithTheNextConfirmation() {
    var s = store(.afterHours(4))
    let id = s.items[0].id
    s.confirm(id: id, at: at("2026-08-11 08:00:00"), calendar: utc)

    var updated = s.items[0]
    updated.resetRule = .afterHours(12)
    s.update(updated)
    #expect(s.state(s.items[0], now: at("2026-08-11 13:00:00"), calendar: utc) == .unknown)

    s.confirm(id: id, at: at("2026-08-11 14:00:00"), calendar: utc)
    #expect(s.items[0].lastConfirmationRule == .afterHours(12))
    #expect(s.state(s.items[0], now: at("2026-08-12 01:00:00"), calendar: utc) != .unknown)
}

@Test func editingALegacyItemSnapshotsItsOldRule() {
    var legacy = item(confirmedAt: at("2026-08-11 08:00:00"), rule: .afterHours(4))
    legacy.confirmations = [at("2026-08-11 08:00:00")]
    var s = Store(items: [legacy])

    var updated = legacy
    updated.resetRule = .never
    s.update(updated)

    #expect(s.items[0].lastConfirmationRule == .afterHours(4))
    #expect(s.items[0].confirmationRules == [.afterHours(4)])
}

@Test func allBoundariesMergesEveryItemInOrder() {
    var s = Store(items: [item(rule: .afterHours(10)), item(rule: .afterHours(4))])
    let now = at("2026-08-11 00:00:00")
    s.confirm(id: s.items[0].id, at: now, calendar: utc)
    s.confirm(id: s.items[1].id, at: now, calendar: utc)

    let found = s.allBoundaries(after: now, calendar: utc)
    #expect(found == found.sorted())
    #expect(found.count == 4)
}

// MARK: - Encoding

@Test func aStoreWrittenBeforeTheNewFieldsExistedStillDecodes() {
    // Phase 0 wrote items without confirmationLine or confirmations.
    let legacy = """
    {
      "items": [{
        "id": "\(UUID().uuidString)",
        "name": "The stove",
        "word": "Off",
        "symbol": "flame",
        "resetRule": { "dailyAt": { "hour": 4 } },
        "createdAt": "2026-08-10T22:00:00Z",
        "order": 0
      }]
    }
    """
    let decoded = try? StoreIO.decoder.decode(Store.self, from: Data(legacy.utf8))
    #expect(decoded?.items.count == 1)
    #expect(decoded?.items[0].confirmationLine == nil)
    #expect(decoded?.items[0].confirmations == nil)
}

@Test func storeRoundTripsThroughJSON() {
    var s = store()
    s.confirm(id: s.items[0].id, at: at("2026-08-11 09:00:00"), calendar: utc)
    s.lastLeftHomeAt = at("2026-08-11 08:42:00")

    let data = try! StoreIO.encoder.encode(s)
    let back = try! StoreIO.decoder.decode(Store.self, from: data)

    #expect(back.items == s.items)
    #expect(back.lastLeftHomeAt == s.lastLeftHomeAt)
    #expect(back.lastConfirmationLine == s.lastConfirmationLine)
}

// MARK: - Undo (the Day 0 practice card's promise)

@Test func undoRevertsTheMostRecentConfirmation() {
    var s = store()
    let id = s.items[0].id
    s.confirm(id: id, at: at("2026-08-11 09:00:00"), calendar: utc)
    s.undo(id: id)

    #expect(s.items[0].lastConfirmedAt == nil)
    #expect(s.items[0].confirmationLine == nil)
    #expect(s.state(s.items[0], now: at("2026-08-11 09:01:00"), calendar: utc) == .unknown)
}

@Test func undoFallsBackToThePreviousConfirmation() {
    var s = store()
    let id = s.items[0].id
    s.confirm(id: id, at: at("2026-08-11 08:00:00"), calendar: utc)
    s.confirm(id: id, at: at("2026-08-11 12:00:00"), calendar: utc)
    s.undo(id: id)

    #expect(s.items[0].lastConfirmedAt == at("2026-08-11 08:00:00"))
    #expect(s.items[0].confirmations?.count == 1)
}

@Test func undoRestoresThePreviousConfirmationsExpiryRule() {
    var s = store(.afterHours(4))
    let id = s.items[0].id
    s.confirm(id: id, at: at("2026-08-11 08:00:00"), calendar: utc)

    var updated = s.items[0]
    updated.resetRule = .afterHours(12)
    s.update(updated)
    s.confirm(id: id, at: at("2026-08-11 10:00:00"), calendar: utc)
    s.undo(id: id)

    #expect(s.items[0].lastConfirmedAt == at("2026-08-11 08:00:00"))
    #expect(s.items[0].lastConfirmationRule == .afterHours(4))
    #expect(s.state(s.items[0], now: at("2026-08-11 13:00:00"), calendar: utc) == .unknown)
}

@Test func undoDeEscalatesTheNextLine() {
    var s = store()
    let id = s.items[0].id
    for hour in ["08", "12", "18"] {
        s.confirm(id: id, at: at("2026-08-11 \(hour):00:00"), calendar: utc)
    }
    #expect(Copy.escalation.contains(s.items[0].confirmationLine ?? ""))

    s.undo(id: id)
    s.confirm(id: id, at: at("2026-08-11 19:00:00"), calendar: utc)
    #expect(Copy.escalation.contains(s.items[0].confirmationLine ?? ""))

    s.undo(id: id)
    s.undo(id: id)
    s.confirm(id: id, at: at("2026-08-11 20:00:00"), calendar: utc)
    #expect(Copy.general.contains(s.items[0].confirmationLine ?? ""))
}

@Test func undoingAnUnconfirmedItemIsHarmless() {
    var s = store()
    s.undo(id: s.items[0].id)
    #expect(s.items[0].lastConfirmedAt == nil)
}

// MARK: - Archiving

@Test func archivedItemsLeaveTheBoardButNotTheStore() {
    var s = Store(items: [item(), item()])
    s.items[1].archivedAt = at("2026-08-11 09:00:00")
    #expect(s.active.count == 1)
    #expect(s.items.count == 2)
}

@Test func activeIsOrderedByOrder() {
    var first = item(); first.order = 2
    var second = item(); second.order = 0
    let s = Store(items: [first, second])
    #expect(s.active.map(\.order) == [0, 2])
}
