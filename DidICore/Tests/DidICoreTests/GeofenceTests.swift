import Testing
import Foundation
@testable import DidICore

// MARK: - Concentric rings

@Test func ringsPlaceTheInnerRingAtTwoThirdsOfTheOuter() {
    let rings = Geofence.rings(
        radius: 150, radiusRange: 50...250, innerFactor: 0.66, outerID: "home", innerID: "home-inner"
    )
    #expect(rings.map(\.identifier) == ["home", "home-inner"])
    #expect(rings[0].radius == 150)
    #expect(rings[1].radius == 99)
}

@Test func theInnerRingNeverDropsBelowTheSliderFloor() {
    // 75 * 0.66 = 49.5, under the 50m floor — the inner ring must clamp to it.
    let rings = Geofence.rings(
        radius: 75, radiusRange: 50...250, innerFactor: 0.66, outerID: "home", innerID: "home-inner"
    )
    #expect(rings[1].radius == 50)
}

@Test func aRadiusAtTheFloorCollapsesToOneRing() {
    // Inner ring would be >= the outer one, so it is dropped rather than
    // registering a duplicate boundary.
    let rings = Geofence.rings(
        radius: 50, radiusRange: 50...250, innerFactor: 0.66, outerID: "home", innerID: "home-inner"
    )
    #expect(rings.map(\.identifier) == ["home"])
}

@Test func theOuterRingCarriesEntryAndExitTheInnerIsExitOnly() {
    let rings = Geofence.rings(
        radius: 150, radiusRange: 50...250, innerFactor: 0.66, outerID: "home", innerID: "home-inner"
    )
    #expect(rings[0].notifyOnEntry && rings[0].notifyOnExit)
    #expect(!rings[1].notifyOnEntry && rings[1].notifyOnExit)
}

@Test func radiusIsClampedToTheAllowedRange() {
    let tooSmall = Geofence.rings(
        radius: 1, radiusRange: 50...250, innerFactor: 0.66, outerID: "home", innerID: "home-inner"
    )
    #expect(tooSmall[0].radius == 50)

    let tooBig = Geofence.rings(
        radius: 999, radiusRange: 50...250, innerFactor: 0.66, outerID: "home", innerID: "home-inner"
    )
    #expect(tooBig[0].radius == 250)
}

// MARK: - Registration grace window

@Test func aCallbackJustAfterRegistrationIsWithinGrace() {
    let started = at("2026-08-11 08:00:00")
    let now = started.addingTimeInterval(9)
    #expect(Geofence.withinRegistrationGrace(startedAt: started, now: now, window: 10))
}

@Test func aCallbackAfterTheWindowIsNotWithinGrace() {
    let started = at("2026-08-11 08:00:00")
    let now = started.addingTimeInterval(11)
    #expect(!Geofence.withinRegistrationGrace(startedAt: started, now: now, window: 10))
}

@Test func noRegistrationYetIsNeverWithinGrace() {
    #expect(!Geofence.withinRegistrationGrace(startedAt: nil, now: .now, window: 10))
}

// MARK: - Leaving-home reminder dedup

@Test func aReminderNotYetQueuedIsMissing() {
    let due = [item()]
    let missing = LeavingHomeReminders.missing(due: due, alreadyQueued: [], identifierPrefix: "leaving-home-")
    #expect(missing.map(\.id) == due.map(\.id))
}

@Test func aReminderAlreadyPendingOrDeliveredIsNotMissing() {
    let due = [item()]
    let queued: Set<String> = ["leaving-home-" + due[0].id.uuidString]
    let missing = LeavingHomeReminders.missing(due: due, alreadyQueued: queued, identifierPrefix: "leaving-home-")
    #expect(missing.isEmpty)
}

@Test func onlyTheUnqueuedItemsAmongSeveralAreMissing() {
    let due = [item(), item(), item()]
    let queued: Set<String> = ["leaving-home-" + due[1].id.uuidString]
    let missing = LeavingHomeReminders.missing(due: due, alreadyQueued: queued, identifierPrefix: "leaving-home-")
    #expect(missing.map(\.id) == [due[0].id, due[2].id])
}
