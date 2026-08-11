import Testing
import Foundation
@testable import DidICore

// architecture.md §8. Because `now` and `calendar` are injected, the whole decay
// mechanic is exercised in milliseconds rather than overnight.

func calendar(_ zone: String) -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: zone)!
    return c
}

let utc = calendar("UTC")

/// Absolute instant, written in whichever zone makes the case readable.
func at(_ stamp: String, _ zone: String = "UTC") -> Date {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.timeZone = TimeZone(identifier: zone)!
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return f.date(from: stamp)!
}

func item(
    confirmedAt: Date? = nil,
    rule: ResetRule = .dailyAt(hour: 4),
    word: String = "Off"
) -> Item {
    Item(
        name: "The stove", word: word, symbol: "flame", resetRule: rule,
        lastConfirmedAt: confirmedAt, createdAt: at("2026-08-01 00:00:00"), order: 0
    )
}

func isUnknown(_ state: ItemState) -> Bool { state == .unknown }

// MARK: - The two worked examples from §8

@Test func neverConfirmedIsUnknown() {
    #expect(resolve(item(), now: at("2026-08-11 09:00:00"), calendar: utc) == .unknown)
}

@Test func confirmedAt23IsUnknownJustAfterFourAndConfirmedJustBefore() {
    let stove = item(confirmedAt: at("2026-08-10 23:00:00"))
    #expect(!isUnknown(resolve(stove, now: at("2026-08-11 03:59:59"), calendar: utc)))
    #expect(isUnknown(resolve(stove, now: at("2026-08-11 04:00:01"), calendar: utc)))
}

@Test func confirmedAtFiveSurvivesUntilTheNextFourNotTheOneThatPassed() {
    let stove = item(confirmedAt: at("2026-08-10 05:00:00"))
    #expect(!isUnknown(resolve(stove, now: at("2026-08-10 23:59:00"), calendar: utc)))
    #expect(!isUnknown(resolve(stove, now: at("2026-08-11 03:59:59"), calendar: utc)))
    #expect(isUnknown(resolve(stove, now: at("2026-08-11 04:00:01"), calendar: utc)))
}

// MARK: - Freshness

@Test func freshnessFlipsAtSixtyPercentOfTheWindow() {
    // 10h window: ages at +6h.
    let stove = item(confirmedAt: at("2026-08-10 00:00:00"), rule: .afterHours(10))
    #expect(resolve(stove, now: at("2026-08-10 05:59:00"), calendar: utc)
        == .confirmed(age: 5 * 3600 + 59 * 60 as TimeInterval, freshness: .fresh))
    if case .confirmed(_, let freshness) =
        resolve(stove, now: at("2026-08-10 06:00:01"), calendar: utc) {
        #expect(freshness == .aging)
    } else {
        Issue.record("expected still-confirmed at 60% of the window")
    }
}

@Test func afterHoursExpiresOnTheHour() {
    let iron = item(confirmedAt: at("2026-08-10 08:00:00"), rule: .afterHours(12))
    #expect(!isUnknown(resolve(iron, now: at("2026-08-10 19:59:59"), calendar: utc)))
    #expect(isUnknown(resolve(iron, now: at("2026-08-10 20:00:01"), calendar: utc)))
}

@Test func neverRuleStaysConfirmed() {
    let thing = item(confirmedAt: at("2020-01-01 00:00:00"), rule: .never)
    #expect(!isUnknown(resolve(thing, now: at("2026-08-11 09:00:00"), calendar: utc)))
    #expect(boundaries(for: thing, after: at("2026-08-11 09:00:00"), calendar: utc).isEmpty)
}

// MARK: - onLeavingHome

@Test func leavingHomeClearsTheItem() {
    let stove = item(confirmedAt: at("2026-08-11 08:00:00"), rule: .onLeavingHome)
    let left = at("2026-08-11 08:42:00")
    #expect(isUnknown(resolve(stove, lastLeftHome: left, now: at("2026-08-11 09:00:00"), calendar: utc)))
}

@Test func leavingHomeBeforeConfirmingDoesNotClearIt() {
    let stove = item(confirmedAt: at("2026-08-11 09:00:00"), rule: .onLeavingHome)
    let left = at("2026-08-11 08:42:00")
    #expect(!isUnknown(resolve(stove, lastLeftHome: left, now: at("2026-08-11 09:05:00"), calendar: utc)))
}

@Test func leavingHomeNeverStaysGreenPastTwentyFourHours() {
    // No exit event at all — the ceiling has to expire it anyway.
    let stove = item(confirmedAt: at("2026-08-10 09:00:00"), rule: .onLeavingHome)
    #expect(!isUnknown(resolve(stove, lastLeftHome: nil, now: at("2026-08-11 08:59:00"), calendar: utc)))
    #expect(isUnknown(resolve(stove, lastLeftHome: nil, now: at("2026-08-11 09:00:01"), calendar: utc)))
}

// MARK: - DST

@Test func springForwardResolvesTheFourAmBoundaryExactlyOnce() {
    // US spring-forward 2026: 08 March, 02:00 → 03:00 in New York. 04:00 exists.
    let ny = calendar("America/New_York")
    let stove = item(confirmedAt: at("2026-03-07 23:00:00", "America/New_York"))

    #expect(!isUnknown(resolve(stove, now: at("2026-03-08 03:59:59", "America/New_York"), calendar: ny)))
    #expect(isUnknown(resolve(stove, now: at("2026-03-08 04:00:01", "America/New_York"), calendar: ny)))

    // Exactly one boundary pair, and the expiry is the 04:00 that really happened.
    let found = boundaries(for: stove, after: at("2026-03-07 23:00:00", "America/New_York"), calendar: ny)
    #expect(found.count == 2)
    #expect(found[1] == at("2026-03-08 04:00:00", "America/New_York"))
}

@Test func springForwardOverAMissingHourStillYieldsOneBoundary() {
    // A 02:00 reset on the night the 02:00 hour does not exist.
    // nextDate(matchingPolicy: .nextTime) lands on the next real instant, once.
    let ny = calendar("America/New_York")
    let stove = item(confirmedAt: at("2026-03-07 23:00:00", "America/New_York"),
                     rule: .dailyAt(hour: 2))
    let found = boundaries(for: stove, after: at("2026-03-07 23:00:00", "America/New_York"), calendar: ny)
    #expect(found.count == 2)
    #expect(!isUnknown(resolve(stove, now: at("2026-03-08 01:59:00", "America/New_York"), calendar: ny)))
    #expect(isUnknown(resolve(stove, now: at("2026-03-08 05:00:00", "America/New_York"), calendar: ny)))
}

@Test func fallBackResolvesTheFourAmBoundaryExactlyOnce() {
    // US fall-back 2026: 01 November, 02:00 → 01:00. The 01:00 hour repeats.
    let ny = calendar("America/New_York")
    let stove = item(confirmedAt: at("2026-10-31 23:00:00", "America/New_York"),
                     rule: .dailyAt(hour: 1))
    let found = boundaries(for: stove, after: at("2026-10-31 23:00:00", "America/New_York"), calendar: ny)
    #expect(found.count == 2)
    // The first 01:00 wins; the item does not survive into the repeated hour.
    #expect(isUnknown(resolve(stove, now: at("2026-11-01 01:30:00", "America/New_York").addingTimeInterval(3600), calendar: ny)))
}

// MARK: - Timezone travel

@Test func flyingWestExpiresTheItemLateByTheOffsetDifference() {
    // Confirmed 23:00 in London, then the user lands in New York. Boundaries
    // recompute against the current calendar: the 04:00 that applies is now
    // New York's, five hours later in absolute terms. Documented, not fixed.
    let confirmed = at("2026-08-10 23:00:00", "Europe/London")
    let stove = item(confirmedAt: confirmed)

    let londonExpiry = boundaries(for: stove, after: confirmed, calendar: calendar("Europe/London"))[1]
    let newYorkExpiry = boundaries(for: stove, after: confirmed, calendar: calendar("America/New_York"))[1]

    #expect(newYorkExpiry.timeIntervalSince(londonExpiry) == 5 * 3600)

    // At London's 04:00 the item is already unknown at home, still confirmed abroad.
    #expect(isUnknown(resolve(stove, now: londonExpiry.addingTimeInterval(1), calendar: calendar("Europe/London"))))
    #expect(!isUnknown(resolve(stove, now: londonExpiry.addingTimeInterval(1), calendar: calendar("America/New_York"))))
}

// MARK: - Boundaries

@Test func boundariesAreTheTwoTransitionsInOrder() {
    let stove = item(confirmedAt: at("2026-08-10 23:00:00"), rule: .afterHours(10))
    let found = boundaries(for: stove, after: at("2026-08-10 23:00:00"), calendar: utc)
    #expect(found == [at("2026-08-11 05:00:00"), at("2026-08-11 09:00:00")])
}

@Test func boundariesDropTransitionsAlreadyPassed() {
    let stove = item(confirmedAt: at("2026-08-10 23:00:00"), rule: .afterHours(10))
    let found = boundaries(for: stove, after: at("2026-08-11 06:00:00"), calendar: utc)
    #expect(found == [at("2026-08-11 09:00:00")])
}

@Test func unconfirmedItemHasNoBoundaries() {
    #expect(boundaries(for: item(), after: at("2026-08-11 09:00:00"), calendar: utc).isEmpty)
}

@Test func everyBoundaryIsAStateChange() {
    // The contract: crossing a boundary changes resolve's answer, and nothing
    // between two boundaries does.
    let stove = item(confirmedAt: at("2026-08-10 23:00:00"))
    let start = at("2026-08-10 23:00:00")
    for edge in boundaries(for: stove, after: start, calendar: utc) {
        let before = resolve(stove, now: edge.addingTimeInterval(-1), calendar: utc)
        let after = resolve(stove, now: edge.addingTimeInterval(1), calendar: utc)
        #expect(before != after)
    }
}
