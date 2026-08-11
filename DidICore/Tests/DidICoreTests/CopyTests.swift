import Testing
import Foundation
@testable import DidICore

// day-0-install.md: the pool is a designed artefact with rules, not a bag of
// strings to pick from at random.

@Test func everyConfirmationLineFitsOneLineOnTheSmallestDevice() {
    let all = Copy.general + Copy.escalation + [Copy.onboardingConfirmation]
    for line in all {
        #expect(line.count < 60, "over 60 chars: \(line)")
    }
}

@Test func poolsAreTheOnesTheDocSpecifies() {
    #expect(Copy.general.count == 12)
    #expect(Copy.escalation.count == 3)
    #expect(Set(Copy.general).count == 12)   // no accidental duplicates
}

@Test func confirmationLineNeverRepeatsTwiceInARow() {
    var previous: String?
    for _ in 0..<500 {
        let line = Copy.confirmationLine(escalating: false, avoiding: previous)
        #expect(line != previous)
        #expect(Copy.general.contains(line))
        previous = line
    }
}

@Test func confirmationLineRotatesAcrossTheWholePool() {
    var seen = Set<String>()
    var previous: String?
    for _ in 0..<500 {
        let line = Copy.confirmationLine(escalating: false, avoiding: previous)
        seen.insert(line)
        previous = line
    }
    #expect(seen == Set(Copy.general))
}

@Test func escalatingDrawsFromTheEscalationPoolOnly() {
    for _ in 0..<100 {
        #expect(Copy.escalation.contains(Copy.confirmationLine(escalating: true, avoiding: nil)))
    }
}

// MARK: - Tone rules (day-2)

@Test func jokesReachFreshItemsOnly() {
    var stove = item(confirmedAt: at("2026-08-11 09:00:00"))
    stove.confirmationLine = "Yep. Consider it handled."

    let fresh = Copy.status(
        for: .confirmed(age: 60, freshness: .fresh), item: stove)
    #expect(fresh == "Yep. Consider it handled.")

    let aging = Copy.status(
        for: .confirmed(age: 6 * 3600, freshness: .aging), item: stove)
    #expect(aging == "Off, 6 hours ago.")
    #expect(!Copy.general.contains(aging))
}

@Test func unknownAwayIsPlainAndUnknownAtHomeIsLight() {
    let stove = item()
    #expect(Copy.status(for: .unknown, item: stove, isAway: false) == "No record yet. Easy fix.")
    #expect(Copy.status(for: .unknown, item: stove, isAway: true)
        == "No record since you left. That's not the same as leaving it on.")
}

@Test func theAwayLineNeedsToKnowTheyLeft() {
    // "No record *since you left*" presupposes a geofence. With no home set it is
    // not just risky, it is untrue — so the default is the light line.
    #expect(Copy.status(for: .unknown, item: item()) == Copy.unknownAtHome)
}

@Test func noUnknownStateGetsAJoke() {
    // Humour is a reward for being fine, never a comment on being uncertain.
    for isAway in [true, false] {
        let line = Copy.status(for: .unknown, item: item(), isAway: isAway)
        #expect(!Copy.general.contains(line))
        #expect(!Copy.escalation.contains(line))
    }
}

@Test func elapsedReadsNaturally() {
    #expect(Copy.confirmedAgo(word: "Off", age: 30) == "Off, a moment ago.")
    #expect(Copy.confirmedAgo(word: "Off", age: 60) == "Off, 1 minute ago.")
    #expect(Copy.confirmedAgo(word: "LOCKED", age: 20 * 60) == "Locked, 20 minutes ago.")
    #expect(Copy.confirmedAgo(word: "Off", age: 3600) == "Off, 1 hour ago.")
    #expect(Copy.confirmedAgo(word: "Off", age: 6 * 3600 + 120) == "Off, 6 hours ago.")
}

@Test func shortAgeIsTheBoardsClippedUnits() {
    #expect(Copy.shortAge(30) == "NOW")
    #expect(Copy.shortAge(14 * 60) == "14M")
    #expect(Copy.shortAge(6 * 3600) == "6H")
}

@Test func onlyTwoNotificationCategoriesHaveCopy() {
    #expect(Copy.widgetNudges.count == 3)
    #expect(Copy.widgetNudges.contains { $0.title == "Your widget is still homeless" })
    let reminder = Copy.leavingHomeReminder(item: item())
    #expect(reminder.title == "No record for the stove")
    #expect(reminder.body == Copy.unknownAway)
}

// MARK: - The "Forget this after" editor (day-2)

@Test func forgetAfterOffersTheDocsOptionsInOrder() {
    #expect(ResetRule.choices(hasHome: true).map(Copy.forgetAfter) == [
        "When I leave home", "4 hours", "12 hours", "Every night at 4am", "Never",
    ])
}

@Test func leavingHomeIsHiddenWithoutAHome() {
    let choices = ResetRule.choices(hasHome: false)
    #expect(!choices.contains(.onLeavingHome))
    #expect(choices.map(Copy.forgetAfter) == [
        "4 hours", "12 hours", "Every night at 4am", "Never",
    ])
}

@Test func theDefaultRuleIsNightlyAtFour() {
    #expect(ResetRule.default == .dailyAt(hour: 4))
    #expect(ResetRule.choices(hasHome: false).contains(.default))
}

@Test func neverCarriesItsWarning() {
    #expect(Copy.neverWarning == "A tick that never expires is a tick you can't trust.")
}

@Test func clockHoursReadAsClockTimes() {
    #expect(Copy.forgetAfter(.dailyAt(hour: 4)) == "Every night at 4am")
    #expect(Copy.forgetAfter(.dailyAt(hour: 0)) == "Every night at 12am")
    #expect(Copy.forgetAfter(.dailyAt(hour: 13)) == "Every night at 1pm")
}
