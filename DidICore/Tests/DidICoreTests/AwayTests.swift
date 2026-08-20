import Testing
import Foundation
@testable import DidICore

private let home = HomeLocation(latitude: 52.37, longitude: 4.89)

private func awayStore() -> Store {
    Store(items: [item(rule: .onLeavingHome)], home: home)
}

// MARK: - isAway

@Test func withoutAHomeWeAreNeverAway() {
    var s = Store(items: [item()])
    s.lastLeftHomeAt = at("2026-08-11 08:42:00")
    // The away line claims "since you left". With no geofence that is not true.
    #expect(!s.isAway)
}

@Test func leavingMakesUsAway() {
    var s = awayStore()
    s.leftHome(at: at("2026-08-11 08:42:00"))
    #expect(s.isAway)
}

@Test func comingBackMakesUsHomeAgain() {
    var s = awayStore()
    s.leftHome(at: at("2026-08-11 08:42:00"))
    s.arrivedHome(at: at("2026-08-11 18:10:00"))
    #expect(!s.isAway)
}

@Test func leavingAgainAfterReturningIsAwayAgain() {
    var s = awayStore()
    s.leftHome(at: at("2026-08-11 08:42:00"))
    s.arrivedHome(at: at("2026-08-11 18:10:00"))
    s.leftHome(at: at("2026-08-12 08:40:00"))
    #expect(s.isAway)
}

// MARK: - The mute escape hatch

@Test func mutedItemsLeaveTheSummaryCount() {
    var s = Store(items: [item(), item()], home: home)
    s.items[0].mutedUntilHome = true
    #expect(s.counted.count == 1)
    #expect(s.active.count == 2)
}

@Test func arrivingHomeClearsEveryMute() {
    var s = Store(items: [item(), item()], home: home)
    s.items[0].mutedUntilHome = true
    s.items[1].mutedUntilHome = true
    s.arrivedHome(at: at("2026-08-11 18:10:00"))
    #expect(s.counted.count == 2)
}

@Test func aMutedItemIsNotRemindedAbout() {
    var s = Store(items: [item()], home: home)
    s.items[0].leavingHomeReminder = true
    #expect(s.needingLeavingHomeReminder(now: at("2026-08-11 09:00:00"), calendar: utc).count == 1)
    s.items[0].mutedUntilHome = true
    #expect(s.needingLeavingHomeReminder(now: at("2026-08-11 09:00:00"), calendar: utc).isEmpty)
}

@Test func onlyUnconfirmedItemsWithTheOptInAreReminded() {
    var s = Store(items: [item(), item(), item()], home: home)
    s.items[0].leavingHomeReminder = true                        // unknown, opted in
    s.items[1].leavingHomeReminder = false                       // unknown, not opted in
    s.items[2].leavingHomeReminder = true
    s.confirm(id: s.items[2].id, at: at("2026-08-11 08:50:00"), calendar: utc)

    let due = s.needingLeavingHomeReminder(now: at("2026-08-11 09:00:00"), calendar: utc)
    #expect(due.map(\.id) == [s.items[0].id])
}

// MARK: - The decay lesson trigger

@Test func theLessonNeedsAnItemTheyHaveSeenGreen() {
    var s = Store(items: [item()])
    // Never confirmed: they have not experienced the problem it explains.
    #expect(DecayLesson.agedOut(in: s, now: at("2026-08-12 09:00:00"), calendar: utc).isEmpty)

    s.confirm(id: s.items[0].id, at: at("2026-08-11 23:00:00"), calendar: utc)
    #expect(DecayLesson.agedOut(in: s, now: at("2026-08-12 09:00:00"), calendar: utc).count == 1)
}

@Test func theLessonDoesNotFireWhileEverythingIsStillGreen() {
    var s = Store(items: [item()])
    s.confirm(id: s.items[0].id, at: at("2026-08-12 08:00:00"), calendar: utc)
    #expect(DecayLesson.agedOut(in: s, now: at("2026-08-12 09:00:00"), calendar: utc).isEmpty)
}

@Test func theLessonFiresOnlyOnce() {
    var s = Store(items: [item()])
    s.confirm(id: s.items[0].id, at: at("2026-08-11 23:00:00"), calendar: utc)
    s.flags.decayLessonShown = true
    #expect(DecayLesson.agedOut(in: s, now: at("2026-08-12 09:00:00"), calendar: utc).isEmpty)
}

@Test func severalAgedOutItemsAreReportedTogetherNotStacked() {
    var s = Store(items: [item(), item()])
    for i in s.items.indices {
        s.confirm(id: s.items[i].id, at: at("2026-08-11 23:00:00"), calendar: utc)
    }
    let aged = DecayLesson.agedOut(in: s, now: at("2026-08-12 09:00:00"), calendar: utc)
    #expect(aged.count == 2)
    #expect(plainSpaces(Copy.Lesson.title(items: aged, hour: 4, locale: Locale(identifier: "en_US")))
        == "Your confirmations aged out at 4 AM")
}

/// The name leads instead of being folded into a possessive — no language has to
/// agree with a noun the user typed.
@Test func theLessonPutsASingleItemsNameInFront() {
    let stove = item()   // "The stove"
    #expect(plainSpaces(Copy.Lesson.title(items: [stove], hour: 4, locale: Locale(identifier: "en_US")))
        == "The stove: confirmation aged out at 4 AM")
}

@Test func theLessonDropsTheHourWhenItemsDisagree() {
    #expect(Copy.Lesson.title(items: [item()], hour: nil)
        == "The stove: confirmation aged out")
}

// MARK: - The one-shot widget nudge

private func optedIn() -> OnboardingFlags {
    OnboardingFlags(
        installedAt: at("2026-08-10 09:00:00"), notificationOptIn: true
    )
}

@Test func theNudgeNeedsAllFourConditions() {
    #expect(WidgetNudge.shouldSchedule(
        flags: optedIn(), widgetInstalled: false, notificationsGranted: true))

    #expect(!WidgetNudge.shouldSchedule(
        flags: optedIn(), widgetInstalled: true, notificationsGranted: true))
    #expect(!WidgetNudge.shouldSchedule(
        flags: optedIn(), widgetInstalled: false, notificationsGranted: false))

    var fired = optedIn(); fired.widgetNudgeFired = true
    #expect(!WidgetNudge.shouldSchedule(
        flags: fired, widgetInstalled: false, notificationsGranted: true))

    var neverOptedIn = optedIn(); neverOptedIn.notificationOptIn = false
    #expect(!WidgetNudge.shouldSchedule(
        flags: neverOptedIn, widgetInstalled: false, notificationsGranted: true))
}

@Test func theNudgeTargetsTheNextWeekdayMorningTwelveHoursOut() {
    // Monday 09:00 → earliest Monday 21:00 → Tuesday 08:00.
    let fire = WidgetNudge.fireDate(installedAt: at("2026-08-10 09:00:00"), calendar: utc)
    #expect(fire == at("2026-08-11 08:00:00"))
}

@Test func aLateInstallWaivesTheTwelveHourMinimum() {
    // Monday 21:00. The 08:00 twelve hours out is Wednesday; the doc wants the
    // next morning instead of waiting an extra full day.
    let fire = WidgetNudge.fireDate(installedAt: at("2026-08-10 21:00:00"), calendar: utc)
    #expect(fire == at("2026-08-11 08:00:00"))
}

@Test func aJustBeforeEightInstallStillWaitsTwelveHours() {
    // Monday 19:00 → earliest Tuesday 07:00 → Tuesday 08:00 is 13h out. Fine.
    let fire = WidgetNudge.fireDate(installedAt: at("2026-08-10 19:00:00"), calendar: utc)
    #expect(fire == at("2026-08-11 08:00:00"))
}

@Test func aMidMorningInstallSkipsTheSameDay() {
    // Tuesday 07:00 → earliest Tuesday 19:00 → Wednesday 08:00, not Tuesday's.
    let fire = WidgetNudge.fireDate(installedAt: at("2026-08-11 07:00:00"), calendar: utc)
    #expect(fire == at("2026-08-12 08:00:00"))
}

@Test func theNudgeSkipsTheWeekend() {
    // Friday 09:00 → earliest Friday 21:00 → Saturday 08:00 → pushed to Monday.
    let fire = WidgetNudge.fireDate(installedAt: at("2026-08-14 09:00:00"), calendar: utc)
    #expect(fire == at("2026-08-17 08:00:00"))
    #expect(utc.component(.weekday, from: fire!) == 2)   // Monday
}

@Test func aWeekendInstallWaitsForMonday() {
    let saturday = WidgetNudge.fireDate(installedAt: at("2026-08-15 10:00:00"), calendar: utc)
    #expect(saturday == at("2026-08-17 08:00:00"))
    let sunday = WidgetNudge.fireDate(installedAt: at("2026-08-16 21:00:00"), calendar: utc)
    #expect(sunday == at("2026-08-17 08:00:00"))
}

@Test func theNudgeNeverLandsOnAWeekend() {
    // Every hour of a full week — none may schedule onto a Saturday or Sunday.
    for hour in 0..<(24 * 7) {
        let installed = at("2026-08-10 00:00:00").addingTimeInterval(TimeInterval(hour) * 3600)
        guard let fire = WidgetNudge.fireDate(installedAt: installed, calendar: utc) else {
            Issue.record("no fire date for \(installed)")
            continue
        }
        #expect(!utc.isDateInWeekend(fire))
        #expect(utc.component(.hour, from: fire) == 8)
        #expect(fire > installed)
    }
}

// MARK: - Day 2 copy, verbatim

@Test func theLessonCopyIsVerbatim() {
    #expect(Copy.Lesson.body ==
        "Old checkmarks lie. A green tick from yesterday tells you nothing about today, so we expire them overnight and start fresh.")
    #expect(Copy.Lesson.footer == "Nothing went wrong. This is the app working.")
    #expect(Copy.Lesson.button == "Makes sense")
}

@Test func theLocationAskCopyIsVerbatim() {
    #expect(Copy.LocationAsk.title == "Want it to reset when you actually leave?")
    #expect(Copy.LocationAsk.body ==
        "Instead of a fixed time, we can clear your confirmations when you leave home — so a green tick always means \"since I left\". That needs your location, and it's never sent to a server.")
    #expect(Copy.LocationAsk.use == "Use my location")
    #expect(Copy.LocationAsk.keepTimer == "Keep the timer")
}

@Test func theHomeSetupCopyIsVerbatim() {
    #expect(Copy.HomeSetup.title == "Where's home?")
    #expect(Copy.HomeSetup.body ==
        "Tap \"Set as home\" while you're there. We'll remember the spot, not the address.")
    #expect(Copy.HomeSetup.set == "Set as home")
    #expect(Copy.HomeSetup.notHome == "I'm not home right now")
    #expect(Copy.HomeSetup.saved == "Home saved.")
    #expect(Copy.HomeSetup.confirmed ==
        "Home is set. Leaving home clears the board automatically.")
}

@Test func theDeclineCopyIsVerbatim() {
    #expect(Copy.LocationDeclined.message ==
        "No problem. We'll keep expiring things overnight instead.")
    #expect(Copy.resetRuleHint ==
        "On the board, open an item's More menu → \"Confirmation expiry\".")
}

@Test func theEscapeHatchCopyIsVerbatim() {
    #expect(Copy.cantCheckRightNow == "Can't check right now")
    #expect(Copy.askSomeoneAtHome == "Ask someone at home")
    #expect(Copy.mutedUntilHome == "Muted from the summary until you're home.")
    #expect(Copy.shareMessage(item: item()) == "Random question — is The stove off?")
}

@Test func theGeofenceRadiusIsOneFiftyMetres() {
    // Smaller drifts indoors; larger fires the nudge too late to be useful.
    #expect(HomeLocation(latitude: 0, longitude: 0).radius == 150)
}
