import Testing
import Foundation
@testable import DidICore

private let now = at("2026-09-10 12:00:00")
private let day: TimeInterval = 86_400

/// Installed long enough ago that the 48-hour rule never accidentally gates a test.
private func settled(_ items: [Item] = [item()]) -> Store {
    var s = Store(items: items)
    s.flags.installedAt = now.addingTimeInterval(-40 * day)
    return s
}

private func spread(_ count: Int, from start: Date, over span: TimeInterval) -> [Date] {
    (0..<count).map { start.addingTimeInterval(Double($0) / Double(max(count, 1)) * span) }
}

// MARK: - The cap

@Test func sixItemsIsTheCap() {
    #expect(Store.itemCap == 6)
    var s = settled((0..<5).map { _ in item() })
    #expect(!s.isFull)
    s.items.append(item())
    #expect(s.isFull)
}

@Test func archivedItemsDoNotCountTowardsTheCap() {
    var s = settled((0..<6).map { _ in item() })
    #expect(s.isFull)
    s.archive(s.items[0].id, at: now)
    #expect(!s.isFull)
    // Archived, never deleted.
    #expect(s.items.count == 6)
    #expect(s.archived.count == 1)
}

@Test func archivedItemsComeBack() {
    var s = settled()
    s.archive(s.items[0].id, at: now)
    s.unarchive(s.items[0].id)
    #expect(s.active.count == 1)
    #expect(s.archived.isEmpty)
}

@Test func theCapListShowsUsageSoTheChoiceIsInformed() {
    var stale = item()
    stale.name = "Windows"
    stale.lastConfirmedAt = now.addingTimeInterval(-12 * day)
    #expect(Copy.Cap.usage(item: stale, now: now) == "Windows — last confirmed 12 days ago")
}

// MARK: - Second-item triggers

@Test func twoAppOpensInADayTriggers() {
    var s = settled()
    s.recordBoardView(at: now.addingTimeInterval(-3600))
    #expect(SecondItem.shouldSuggest(in: s, now: now, calendar: utc) == nil)
    s.recordBoardView(at: now)
    #expect(SecondItem.shouldSuggest(in: s, now: now, calendar: utc) == .twoAppOpensInADay)
}

@Test func fiveChecksOfOneItemWithNoConfirmationTriggers() {
    var s = settled()
    let id = s.items[0].id
    for offset in 1...5 { s.recordCheck(id, at: now.addingTimeInterval(-Double(offset) * 60)) }
    #expect(SecondItem.shouldSuggest(in: s, now: now, calendar: utc) == .oneItemCheckedFiveTimes)
}

@Test func checkingSomethingYouThenConfirmedIsNotRumination() {
    var s = settled()
    let id = s.items[0].id
    for offset in 1...5 { s.recordCheck(id, at: now.addingTimeInterval(-Double(offset) * 60)) }
    s.confirm(id: id, at: now, calendar: utc)
    #expect(SecondItem.shouldSuggest(in: s, now: now, calendar: utc) == nil)
}

@Test func reconfirmingWithinAMinuteTriggers() {
    var s = settled()
    let id = s.items[0].id
    s.confirm(id: id, at: now.addingTimeInterval(-40), calendar: utc)
    s.confirm(id: id, at: now, calendar: utc)
    #expect(SecondItem.shouldSuggest(in: s, now: now, calendar: utc) == .reconfirmedWithinAMinute)
}

@Test func reconfirmingAnHourLaterDoesNot() {
    var s = settled()
    let id = s.items[0].id
    s.confirm(id: id, at: now.addingTimeInterval(-3600), calendar: utc)
    s.confirm(id: id, at: now, calendar: utc)
    #expect(SecondItem.shouldSuggest(in: s, now: now, calendar: utc) == nil)
}

// MARK: - Second-item cooldowns

@Test func neverSuggestWithinFortyEightHoursOfInstall() {
    var s = settled()
    s.flags.installedAt = now.addingTimeInterval(-47 * 3600)
    s.recordBoardView(at: now.addingTimeInterval(-60))
    s.recordBoardView(at: now)
    #expect(SecondItem.shouldSuggest(in: s, now: now, calendar: utc) == nil)

    s.flags.installedAt = now.addingTimeInterval(-49 * 3600)
    #expect(SecondItem.shouldSuggest(in: s, now: now, calendar: utc) != nil)
}

@Test func atMostOneSuggestionPerSevenDays() {
    var s = settled()
    s.recordBoardView(at: now.addingTimeInterval(-60))
    s.recordBoardView(at: now)

    s.usage.lastSuggestedAt = now.addingTimeInterval(-6 * day)
    #expect(SecondItem.shouldSuggest(in: s, now: now, calendar: utc) == nil)

    s.usage.lastSuggestedAt = now.addingTimeInterval(-8 * day)
    #expect(SecondItem.shouldSuggest(in: s, now: now, calendar: utc) != nil)
}

@Test func twoDeclinesStopSuggestionsForThirtyDays() {
    var s = settled()
    s.recordBoardView(at: now.addingTimeInterval(-60))
    s.recordBoardView(at: now)
    s.usage.declineCount = 2

    s.usage.lastDeclinedAt = now.addingTimeInterval(-29 * day)
    #expect(SecondItem.shouldSuggest(in: s, now: now, calendar: utc) == nil)

    s.usage.lastDeclinedAt = now.addingTimeInterval(-31 * day)
    #expect(SecondItem.shouldSuggest(in: s, now: now, calendar: utc) != nil)
}

@Test func threeDeclinesStopSuggestionsForever() {
    var s = settled()
    s.recordBoardView(at: now.addingTimeInterval(-60))
    s.recordBoardView(at: now)
    s.usage.declineCount = 3
    s.usage.lastDeclinedAt = now.addingTimeInterval(-400 * day)
    // They know where the plus button is.
    #expect(SecondItem.shouldSuggest(in: s, now: now, calendar: utc) == nil)
}

@Test func aFullBoardIsNeverAskedToGrow() {
    var s = settled((0..<6).map { _ in item() })
    s.recordBoardView(at: now.addingTimeInterval(-60))
    s.recordBoardView(at: now)
    #expect(SecondItem.shouldSuggest(in: s, now: now, calendar: utc) == nil)
}

// MARK: - The escalating-checks guardrail

/// Checks rising across three consecutive weeks.
private func escalatingStore() -> Store {
    var s = settled()
    let id = s.items[0].id
    let counts = [(21.0, 4), (14.0, 10), (7.0, 20)]   // weeks ago → checks
    for (weeksAgoDays, count) in counts {
        let start = now.addingTimeInterval(-weeksAgoDays * day)
        s.usage.checks[id.uuidString, default: []] += spread(count, from: start, over: 6 * day)
    }
    return s
}

@Test func risingChecksAcrossThreeWeeksTripTheGuardrail() {
    let s = escalatingStore()
    #expect(EscalatingChecks.escalating(in: s, now: now)?.id == s.items[0].id)
}

@Test func aFlatWeekBreaksTheTrend() {
    var s = settled()
    let id = s.items[0].id
    for (weeksAgoDays, count) in [(21.0, 10), (14.0, 10), (7.0, 20)] {
        let start = now.addingTimeInterval(-weeksAgoDays * day)
        s.usage.checks[id.uuidString, default: []] += spread(count, from: start, over: 6 * day)
    }
    #expect(EscalatingChecks.escalating(in: s, now: now) == nil)
}

@Test func fallingChecksDoNotTripIt() {
    var s = settled()
    let id = s.items[0].id
    for (weeksAgoDays, count) in [(21.0, 20), (14.0, 12), (7.0, 4)] {
        let start = now.addingTimeInterval(-weeksAgoDays * day)
        s.usage.checks[id.uuidString, default: []] += spread(count, from: start, over: 6 * day)
    }
    #expect(EscalatingChecks.escalating(in: s, now: now) == nil)
}

@Test func aRisingButTinyTrendDoesNotTripTheGuardrail() {
    // 1 → 2 → 3 checks across three weeks is "trending upward" by the letter of
    // the doc, but telling this person the app has become the thing they check
    // would be absurd and slightly insulting.
    var s = settled()
    let id = s.items[0].id
    for (weeksAgoDays, count) in [(21.0, 1), (14.0, 2), (7.0, 3)] {
        let start = now.addingTimeInterval(-weeksAgoDays * day)
        s.usage.checks[id.uuidString, default: []] += spread(count, from: start, over: 6 * day)
    }
    #expect(EscalatingChecks.escalating(in: s, now: now) == nil)
}

@Test func theGuardrailNeedsTheLatestWeekToBeHeavy() {
    var s = settled()
    let id = s.items[0].id
    // Rising, and the newest week clears the floor.
    for (weeksAgoDays, count) in [(21.0, 3), (14.0, 6), (7.0, 10)] {
        let start = now.addingTimeInterval(-weeksAgoDays * day)
        s.usage.checks[id.uuidString, default: []] += spread(count, from: start, over: 6 * day)
    }
    #expect(EscalatingChecks.escalating(in: s, now: now)?.id == id)
}

@Test func theGuardrailSpeaksOnlyOnce() {
    var s = escalatingStore()
    s.usage.guardrailShown = true
    // Then never mention it again. No resources, no diagnosis, no follow-up.
    #expect(EscalatingChecks.escalating(in: s, now: now) == nil)
}

@Test func theGuardrailMessageIsVerbatimAndNamesTheItem() {
    var iron = item(); iron.name = "Iron"
    #expect(Copy.escalatingChecks(item: iron) ==
        "Iron. You've been checking this a lot lately. This app is meant to end the checking, not become the thing you check. If it isn't helping, it's fine to delete it — it'll still be off.")

    // The closing clause used to say "off" for every item, including doors.
    var door = item(word: "Locked"); door.name = "Front door"
    #expect(Copy.escalatingChecks(item: door).hasSuffix("it'll still be locked."))
}

// MARK: - The paranoia counter

/// A good week: everything confirmed, checks not climbing, one item checked a lot.
private func goodWeek() -> Store {
    var s = settled([item(), item()])
    let weekStart = now.addingTimeInterval(-7 * day)
    let previousStart = now.addingTimeInterval(-14 * day)

    for i in s.items.indices {
        let id = s.items[i].id
        s.items[i].confirmations = spread(5, from: weekStart, over: 6 * day)
        // Last week busier than this week, so the trend is flat or down.
        s.usage.checks[id.uuidString] =
            spread(20, from: previousStart, over: 6 * day)
            + spread(i == 0 ? 14 : 6, from: weekStart, over: 6 * day)
    }
    return s
}

@Test func aGoodWeekWithSomethingAmusingShowsTheCard() {
    let card = ParanoiaCounter.card(for: goodWeek(), now: now, calendar: utc)
    #expect(card != nil)
    #expect(card?.topChecks == 14)
    #expect(card?.runnerUpChecks == 6)
    #expect(Copy.Paranoia.closing.contains(card?.closingLine ?? ""))
}

@Test func noCardBeforeTheFirstWeekIsOut() {
    var s = goodWeek()
    s.flags.installedAt = now.addingTimeInterval(-6 * day)
    #expect(ParanoiaCounter.card(for: s, now: now, calendar: utc) == nil)
}

@Test func noCardWithoutSomethingAmusingToShow() {
    var s = goodWeek()
    // Nothing reached ten checks.
    for id in s.usage.checks.keys {
        s.usage.checks[id] = spread(4, from: now.addingTimeInterval(-7 * day), over: 6 * day)
    }
    #expect(ParanoiaCounter.card(for: s, now: now, calendar: utc) == nil)
}

@Test func noCardIfAnythingGenuinelyWentUnconfirmed() {
    var s = goodWeek()
    s.items[1].confirmations = []
    // A stat that reads as "look how anxious you were" is not a feature.
    #expect(ParanoiaCounter.card(for: s, now: now, calendar: utc) == nil)
}

@Test func noCardWhileChecksAreClimbingWeekOverWeek() {
    var s = goodWeek()
    let id = s.items[0].id
    s.usage.checks[id.uuidString] =
        spread(5, from: now.addingTimeInterval(-14 * day), over: 6 * day)
        + spread(30, from: now.addingTimeInterval(-7 * day), over: 6 * day)
    #expect(ParanoiaCounter.card(for: s, now: now, calendar: utc) == nil)
}

@Test func theGuardrailSuppressesTheCardPermanently() {
    var s = goodWeek()
    s.usage.paranoiaSuppressed = true
    #expect(ParanoiaCounter.card(for: s, now: now, calendar: utc) == nil)
}

@Test func aDismissedCardStaysAwayForAWeek() {
    var s = goodWeek()
    s.usage.weeklyCardDismissedAt = now.addingTimeInterval(-3 * day)
    #expect(ParanoiaCounter.card(for: s, now: now, calendar: utc) == nil)
    s.usage.weeklyCardDismissedAt = now.addingTimeInterval(-8 * day)
    #expect(ParanoiaCounter.card(for: s, now: now, calendar: utc) != nil)
}

@Test func theCardCopyReadsAsTheDocWroteIt() {
    var iron = item(); iron.name = "Iron"
    var door = item(); door.name = "Front door"
    var stove = item(); stove.name = "The stove"
    #expect(Copy.Paranoia.topWorry(item: iron, checks: 34) == "Top worry: Iron. 34 checks.")
    #expect(Copy.Paranoia.runnerUp(item: door, checks: 12)
        == "Runner-up: Front door, a modest 12.")
    #expect(Copy.Paranoia.reassurance(item: stove)
        == "The stove: fine every single time. It always is.")
}

// MARK: - Retention

@Test func checksAreTrimmedToThirtyDays() {
    var s = settled()
    let id = s.items[0].id
    s.usage.checks[id.uuidString] = [now.addingTimeInterval(-40 * day)]
    s.recordCheck(id, at: now)
    #expect(s.usage.checks[id.uuidString]?.count == 1)
}

@Test func confirmationsAreTrimmedToThirtyDays() {
    var s = settled()
    let id = s.items[0].id
    s.items[0].confirmations = [now.addingTimeInterval(-40 * day)]
    s.confirm(id: id, at: now, calendar: utc)
    #expect(s.items[0].confirmations?.count == 1)
}

@Test func aStoreWithNoUsageKeyStillDecodes() {
    let legacy = #"{ "items": [], "flags": { "completedScreen": 3 } }"#
    let decoded = try? StoreIO.decoder.decode(Store.self, from: Data(legacy.utf8))
    #expect(decoded?.usage == Usage())
    #expect(decoded?.flags.completedScreen == 3)
}

// MARK: - Items that go stale

@Test func anItemUnconfirmedForAMonthIsOfferedForArchiving() {
    var s = settled()
    s.items[0].lastConfirmedAt = now.addingTimeInterval(-31 * day)
    #expect(StaleItem.needingArchiveOffer(in: s, now: now)?.id == s.items[0].id)
}

@Test func anItemConfirmedThisMonthIsLeftAlone() {
    var s = settled()
    s.items[0].lastConfirmedAt = now.addingTimeInterval(-29 * day)
    #expect(StaleItem.needingArchiveOffer(in: s, now: now) == nil)
}

@Test func aNeverConfirmedItemCountsFromWhenItWasCreated() {
    var s = settled()
    s.items[0].lastConfirmedAt = nil
    s.items[0].createdAt = now.addingTimeInterval(-31 * day)
    #expect(StaleItem.needingArchiveOffer(in: s, now: now)?.id == s.items[0].id)

    s.items[0].createdAt = now.addingTimeInterval(-3 * day)
    #expect(StaleItem.needingArchiveOffer(in: s, now: now) == nil)
}

@Test func theArchiveOfferIsMadeOnceWhateverTheAnswer() {
    var s = settled()
    s.items[0].lastConfirmedAt = now.addingTimeInterval(-31 * day)
    s.items[0].archiveOfferedAt = now
    #expect(StaleItem.needingArchiveOffer(in: s, now: now) == nil)
}

@Test func theStaleCopyNamesTheItem() {
    var windows = item(); windows.name = "Windows"
    #expect(Copy.StaleItem.title(item: windows) == "Windows hasn't come up in a month")
    #expect(Copy.StaleItem.body == "Want to put it away? You can bring it back any time.")
}

// MARK: - The review prompt

@Test func reviewIsAskedOnlyAfterFifteenDays() {
    var s = settled()
    s.flags.installedAt = now.addingTimeInterval(-14 * day)
    #expect(!ReviewPrompt.shouldAsk(in: s, now: now))
    s.flags.installedAt = now.addingTimeInterval(-16 * day)
    #expect(ReviewPrompt.shouldAsk(in: s, now: now))
}

@Test func reviewIsNeverAskedWhileAwayFromHome() {
    var s = settled()
    s.home = HomeLocation(latitude: 52.37, longitude: 4.89)
    s.leftHome(at: now.addingTimeInterval(-3600))
    // Never while they're wondering about the stove.
    #expect(!ReviewPrompt.shouldAsk(in: s, now: now))
    s.arrivedHome(at: now)
    #expect(ReviewPrompt.shouldAsk(in: s, now: now))
}

@Test func reviewIsAskedAtMostEveryHundredAndTwentyDays() {
    var s = settled()
    s.usage.lastReviewPromptAt = now.addingTimeInterval(-119 * day)
    #expect(!ReviewPrompt.shouldAsk(in: s, now: now))
    s.usage.lastReviewPromptAt = now.addingTimeInterval(-121 * day)
    #expect(ReviewPrompt.shouldAsk(in: s, now: now))
}

// MARK: - What actually counts as a check

@Test func confirmingAnItemCountsAsCheckingIt() {
    var s = settled()
    let id = s.items[0].id
    s.confirm(id: id, at: now, calendar: utc)
    // The only signal a widget-only user ever produces.
    #expect(s.checks(id, since: now.addingTimeInterval(-day), until: now.addingTimeInterval(1)) == 1)
}

@Test func openingTheBoardOnlyChecksWhatWasStillInQuestion() {
    var s = settled([item(), item()])
    let answered = s.items[0].id, open = s.items[1].id
    s.confirm(id: answered, at: now.addingTimeInterval(-3600), calendar: utc)

    s.recordBoardView(at: now, calendar: utc)

    let window = (since: now.addingTimeInterval(-60), until: now.addingTimeInterval(1))
    // One for its own confirmation an hour ago, and nothing for this look.
    #expect(s.checks(answered, since: window.since, until: window.until) == 0)
    #expect(s.checks(open, since: window.since, until: window.until) == 1)
}

@Test func aBoardOfGreenItemsRecordsALookAtNothing() {
    var s = settled([item(), item()])
    for i in s.items.indices {
        s.confirm(id: s.items[i].id, at: now.addingTimeInterval(-3600), calendar: utc)
    }
    let before = s.usage.checks.mapValues(\.count)
    s.recordBoardView(at: now, calendar: utc)
    // The app open is still recorded; it just is not evidence about any one item.
    #expect(s.usage.checks.mapValues(\.count) == before)
    #expect(s.usage.appOpens.count == 1)
}

// MARK: - Board order

/// Board order is also the medium widget's tap-target order, so it has to move.
private func ordered() -> Store {
    var s = settled([])
    for _ in 0..<3 { s.add(item()) }
    return s
}

@Test func movingUpSwapsWithTheItemAbove() {
    var s = ordered()
    let names = s.active.map(\.id)
    s.moveUp(names[2])
    #expect(s.active.map(\.id) == [names[0], names[2], names[1]])
}

@Test func theTopItemCannotMoveUp() {
    var s = ordered()
    let before = s.active.map(\.id)
    s.moveUp(before[0])
    #expect(s.active.map(\.id) == before)
}

@Test func movingUpSkipsPastArchivedItems() {
    var s = ordered()
    let all = s.active.map(\.id)
    s.archive(all[1], at: now)
    // The middle item is off the board, so the last one lands at the top.
    s.moveUp(all[2])
    #expect(s.active.map(\.id) == [all[2], all[0]])
}
