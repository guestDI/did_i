import Testing
import Foundation
@testable import DidICore

// day-0-install.md. The copy is a designed artefact — these assert it verbatim,
// so a well-meaning reword fails the build rather than shipping.

@Test func screenOneCopyIsVerbatim() {
    #expect(Copy.Screen1.title == "What did you last go back home to check?")
    #expect(Copy.Screen1.subtitle == "Pick one. You can add more later, but you probably won't.")
    #expect(Copy.Screen1.footer == "No account. Nothing is sent to a server.")
    #expect(Copy.Screen1.placeholder == "The garage door")
    #expect(Copy.Screen1.returnKey == "Add")
}

@Test func screenTwoCopyIsVerbatim() {
    #expect(Copy.Screen2.title == "Try it once")
    #expect(Copy.Screen2.subtitle == "This is the whole app. There's no step four.")
    #expect(Copy.Screen2.footer == "Hold to undo. Everything resets overnight.")
}

@Test func screenThreeCopyIsVerbatim() {
    #expect(Copy.Screen3.title == "Put it where you'll look")
    #expect(Copy.Screen3.subtitle == "The widget answers without opening anything.")
    #expect(Copy.Screen3.nudgeTitle == "Want a nudge tomorrow morning?")
    #expect(Copy.Screen3.nudgeBody ==
        "We'll remind you once, around the time you'd be leaving the house. Once. Then never again.")
    #expect(Copy.Screen3.yesOnce == "Yes, once")
    #expect(Copy.Screen3.noThanks == "No thanks")
}

@Test func noExclamationMarksAnywhereInSystemCopy() {
    let all = Copy.general + Copy.escalation + [
        Copy.onboardingConfirmation, Copy.Screen1.title, Copy.Screen1.subtitle,
        Copy.Screen1.footer, Copy.Screen2.title, Copy.Screen2.subtitle,
        Copy.Screen2.footer, Copy.Screen3.title, Copy.Screen3.subtitle,
        Copy.Screen3.nudgeTitle, Copy.Screen3.nudgeBody, Copy.unknownAtHome,
        Copy.unknownAway, Copy.neverWarning,
    ] + Copy.widgetNudges.flatMap { [$0.title, $0.body] }

    for line in all {
        #expect(!line.contains("!"), "exclamation mark in: \(line)")
    }
}

// MARK: - Chips

@Test func chipsAreInTheDocsOrder() {
    #expect(Chip.all.map(\.label) == [
        "The stove", "Front door", "Iron", "Windows", "Straightener", "Something else",
    ])
}

@Test func chipsCarryTheDocsResetDefaults() {
    let rules = Dictionary(uniqueKeysWithValues: Chip.all.map { ($0.label, $0.resetRule) })
    #expect(rules["The stove"] == .dailyAt(hour: 4))
    #expect(rules["Front door"] == .dailyAt(hour: 4))
    #expect(rules["Iron"] == .afterHours(12))
    #expect(rules["Windows"] == .dailyAt(hour: 4))
    #expect(rules["Straightener"] == .afterHours(12))
    #expect(rules["Something else"] == .dailyAt(hour: 4))
}

@Test func somethingElseIsLast() {
    #expect(Chip.somethingElse.label == "Something else")
    #expect(Chip.all.last == Chip.somethingElse)
}

@Test func customNamesAreCappedAtTwentyFourCharacters() {
    let long = String(repeating: "x", count: 40)
    let item = Chip.somethingElse.item(named: long, createdAt: .now)
    #expect(item.name.count == Item.maxNameLength)
}

@Test func aChipBecomesAnUnconfirmedItem() {
    let item = Chip.all[0].item(createdAt: at("2026-08-11 09:00:00"))
    #expect(item.name == "The stove")
    #expect(item.word == "Off")
    #expect(item.lastConfirmedAt == nil)
    #expect(resolve(item, now: at("2026-08-11 09:00:01"), calendar: utc) == .unknown)
}

// MARK: - Flags and resume

@Test func onboardingIsIncompleteUntilTheLastScreen() {
    var flags = OnboardingFlags()
    #expect(!flags.isComplete)
    flags.completedScreen = 2
    #expect(!flags.isComplete)
    flags.completedScreen = OnboardingFlags.lastScreen
    #expect(flags.isComplete)
}

@Test func addAssignsTheNextOrder() {
    var s = Store()
    s.add(Chip.all[0].item(createdAt: .now))
    s.add(Chip.all[1].item(createdAt: .now))
    #expect(s.active.map(\.order) == [0, 1])
}

@Test func aStoreWithNoFlagsKeyStillDecodes() {
    // Phases 0–3 wrote stores with no `flags`. A force-quit mid-upgrade must not
    // discard the board.
    let legacy = """
    { "items": [], "lastConfirmationLine": "Yep. Consider it handled." }
    """
    let decoded = try? StoreIO.decoder.decode(Store.self, from: Data(legacy.utf8))
    #expect(decoded?.flags == OnboardingFlags())
    #expect(decoded?.lastConfirmationLine == "Yep. Consider it handled.")
}

@Test func flagsSurviveARoundTrip() {
    var s = Store(items: [Chip.all[0].item(createdAt: .now)])
    s.flags.installedAt = at("2026-08-11 09:00:00")
    s.flags.completedScreen = 3
    s.flags.firstItemType = "stove"
    s.flags.practiceTapCompleted = true
    s.flags.widgetPromptOutcome = .later
    s.flags.notificationOptIn = true

    let data = try! StoreIO.encoder.encode(s)
    let back = try! StoreIO.decoder.decode(Store.self, from: data)
    #expect(back.flags == s.flags)
}

@Test func aFreshStoreHasNothingOnTheBoard() {
    // The Phase 0 seed is gone: a fresh install shows onboarding, not a stove.
    #expect(Store().active.isEmpty)
    #expect(!Store().flags.isComplete)
}

// MARK: - Chips against a board that already knows them

@Test func anArchivedItemHidesItsChip() {
    // Otherwise the chip makes a second "The stove" and strands the first one's
    // history, while "Previously" offers the real thing one row below.
    var s = Store()
    s.add(Chip.all[0].item(createdAt: at("2026-08-01 00:00:00")))
    s.archive(s.items[0].id, at: at("2026-09-01 00:00:00"))

    let labels = Chip.available(excluding: s.items).map(\.label)
    #expect(!labels.contains(Chip.all[0].label))
    // "Something else" is never taken.
    #expect(labels.contains(Chip.somethingElse.label))
}

// MARK: - Chip copy follows the language, user copy does not

@Test func aChipItemIsTaggedAndATypedOneIsNot() {
    let made = Date()
    #expect(Chip.all[0].item(createdAt: made).chipID == "stove")
    // A typed name is theirs, whichever chip opened the field.
    #expect(Chip.somethingElse.item(named: "Bathroom window", createdAt: made).chipID == nil)
    #expect(Chip.somethingElse.item(createdAt: made).chipID == nil)
}

@Test func chipCopyIsRewrittenOnLoadAndUserCopyIsLeftAlone() {
    var s = Store()
    s.add(Chip.all[0].item(createdAt: at("2026-08-01 00:00:00")))
    s.add(Chip.somethingElse.item(named: "Bathroom window", createdAt: at("2026-08-01 00:00:00")))

    // What a store written in another language looks like coming back.
    s.items[0].name = "Der Herd"
    s.items[0].word = "Aus"
    s.items[1].name = "Badezimmerfenster"

    s.localizeChipCopy()

    #expect(s.items[0].name == Chip.all[0].label)
    #expect(s.items[0].word == Chip.all[0].word)
    // Never touched: no chipID, so this text belongs to the user.
    #expect(s.items[1].name == "Badezimmerfenster")
}

@Test func clearingTheTagStopsTheRewriting() {
    var s = Store()
    s.add(Chip.all[0].item(createdAt: at("2026-08-01 00:00:00")))
    // What ItemSettingsView does the moment they edit the name.
    s.items[0].chipID = nil
    s.items[0].name = "Hob"

    s.localizeChipCopy()
    #expect(s.items[0].name == "Hob")
}
