# Decisions

Running log of things the docs left open, decided in passing rather than escalated.
Contradictions between docs are escalated, not logged here.

## Precedence

**The written docs beat the design project.** Where `Did I.dc.html` and the day docs
disagree on behaviour, structure, or copy, the docs win. The design is the visual
source of truth — palette, split-flap board, typography, layout — and nothing more.

`design-brief.md` is not in the repo and is out of scope. Do not chase it.

### Resolved contradictions

| Conflict | Ruling |
|---|---|
| Reset hour: architecture `.dailyAt(4)` vs design's 3:30am | 04:00. Architecture. |
| Onboarding: Day 0's 3 screens vs design `1f`'s 3 screens | Day 0 doc, verbatim. See below. |
| Unknown state: design's neutral grey dash vs docs' amber | Amber `#D9A03F`. Architecture §1, day-3. |

The unknown-state override is worth spelling out because the design argues the other
case in its own assumptions line ("amber appears only in the confirmation toast and
onboarding CTA — never on a state"). Overruled: architecture §1 says the widget shows
amber at 04:00, and day-3 calls amber the strongest colour in the app. `Palette.unknown`
now aliases `Palette.amber`. The `—` dash glyph is kept — the docs never asked for a
different shape, and it still reads as absence rather than alarm. Still no red anywhere.

**Onboarding (Phase 4) follows `day-0-install.md`, not design `1f`.** That means:
single-select chips on screen 1 with the doc's exact title and subtitle, the practice
tap on screen 2 that writes a real entry, and the widget screen with the "Later" →
"Yes, once" branch. The design's multi-select "Pick your worries. Four to six." is
dropped — the Day 0 doc names multi-select as a trap that produces a chore list on
day zero. The design's cold-open manifesto screen ("You did turn it off.") is dropped
too; Day 0 §"Screen 0" is explicit that no such screen exists. The design's *styling*
of those screens still applies to the Day 0 content.

## Phase 0

**Bundle identifiers.** `com.dihnatovich.didi`, widget `com.dihnatovich.didi.widget`,
App Group `group.com.dihnatovich.didi`. The docs write `group.com.<you>.didi`.
Change in `project.yml` and `StoreIO.appGroupID` if you want a different prefix.

**Widget configuration.** Phase 0 uses `StaticConfiguration` + `TimelineProvider`,
not `AppIntentTimelineProvider`. There is exactly one item and nothing to configure;
item selection arrives with Phase 2's families.

**`resolve` signature.** Architecture §4 lists `resolve(_:home:lastLeftHome:now:)`.
`home` is unused by the resolver — the geofence produces `lastLeftHomeAt`, and the
resolver only compares timestamps. Dropped the parameter. Added `calendar:` instead,
defaulting to `.current`, so the DST and timezone tests in §8 can pin a calendar.

**Aging threshold.** §4 says "past 60% of the window". Implemented as a fraction of
`[lastConfirmedAt, expiry]`, so a `.dailyAt(4)` confirmation at 20:00 ages at ~00:48
and a `.afterHours(12)` one ages at 7h12m. The design's settings screen shows
"start fading after 4 HOURS" as a fixed duration; treated as display copy for the
default case, not a second mechanism.

**`Item.word`.** Added to the model. The design renders a per-item status word on the
split-flap cells (`OFF`, `LOCKED`, `DOWN`, `UNPLUGGED`) and the settings screen makes it
editable. Not in architecture §3, but the board does not work without it.

**`Store` fields.** Phase 0 carries `items` only. `home`, `lastLeftHomeAt`, `flags`
and `checkCounts` arrive in the phases that use them; they decode into an existing
file as absent-with-default, so no migration.

**Seed item.** `StoreIO.read()` returns a hardcoded STOVE / `.dailyAt(4)` store when no
file exists, so the widget works before the app has ever run. Deleted in Phase 4 when
onboarding creates the first item.

**Typeface.** The design specifies IBM Plex Mono. The regular, medium, semibold,
and bold faces from IBM Plex v6.4.2 are bundled once in DidICore under the SIL
Open Font License, then registered per process for the app, widget, and Watch app.
SF Mono remains only as a defensive fallback if a packaged font resource cannot
be loaded. Snapshot references must be re-recorded because Plex has different
glyph metrics from the temporary system face.

**Confirmation line selection.** Phase 0 picks deterministically from a four-line pool
keyed on `lastConfirmedAt`, so the line is identical across every timeline entry for one
confirmation and differs between confirmations. The real pool with the
no-repeat-twice-in-a-row and 3+-per-day escalation rules is Phase 1 work
(needs stored rotation state, which the widget cannot write on read).

**Darwin notification listener.** `StoreIO.write` posts it as specified. Nothing
listens yet — the app reloads the store on `scenePhase == .active`, which covers
everything except a widget tap while the app sits in the foreground. Listener lands
in Phase 3 with the item list.

**Store read never throws.** An unreadable or absent file returns the seed. The widget
has no way to surface an error, and a hard failure there is worse than a fresh board.
`StoreIO.storeURL` does still `fatalError` when the App Group is missing — that is a
provisioning mistake, and failing silently would let the app and the extension write to
two different files without anyone noticing.

**Warnings.** `SWIFT_TREAT_WARNINGS_AS_ERRORS` is on for both targets.

## Phase 1

**Copy is stored in the docs' case.** `Copy.swift` never pre-shouts. The design renders
the board in caps, so *views* apply `.textCase(.uppercase)` — to item names, the footer
and column headings only. Status lines and jokes stay sentence case: the design's board
voice is a visual treatment, but the words belong to the docs, and
`LOGGED. THE STOVE IS OFF. THE WORLD IS SAFE. ISH.` is not the joke that was written.

**The chosen line is persisted, not re-rolled.** `Item.confirmationLine` holds the
string picked at confirmation time. The widget renders one confirmation across many
timeline entries, and re-picking on each render would reshuffle the joke under the
user. Storing the resolved string rather than a pool index means editing a pool never
mis-indexes an old file. This is stored *copy*, not stored state — nothing in it says
an item is green.

**No-repeat is a guarantee, not a retry.** `Copy.confirmationLine(escalating:avoiding:)`
removes the previous line from the candidate set instead of resampling until it differs.
`Store.lastConfirmationLine` is global rather than per-item, because "never twice in a
row" is about what the person just read and they read one line at a time.

**Escalation needs a per-item day count**, which architecture §3 does not have —
`checkCounts` is explicitly *views*, not confirmations, and it belongs to the paranoia
counter. Added `Item.todaysConfirmations`, trimmed to the current day on every write.
Optional so Phase 0 files still decode. Escalation fires on the third confirmation of
one item in one day, counting the current one.

**`isHome` defaults to `false` in `Copy.status`.** Until Phase 5 there is no location,
and the day-2 tone table splits unknown into at-home (light) and away (plain). Guessing
"away" is silent when wrong; guessing "at home" aims light copy at someone who may be
3km away. Never guess towards the joke.

**Leaving-home reminder copy is invented.** The docs specify the trigger, the opt-in and
the tone but never wrote the string. Kept to the away register and reusing the doc's own
`unknownAway` line as the body. Replace freely.

**Onboarding, decay-lesson, location-ask and settings strings are not in `Copy.swift`
yet.** They arrive with the phase that renders them. Phase 1 carries what Phases 0–3
show plus the notification variants architecture §7 names.

**Small-widget status line is now two lines.** The doc pool runs to 59 characters where
the design's line was 19. Clipping a joke mid-sentence is worse than a second line —
`lineLimit(2)` with a 0.8 scaling floor. Confirm on device; this is a layout guess.

**`Store` still omits `home`, `flags` and `checkCounts` (Phase 1).** Added `lastLeftHomeAt` (the
resolver needs it and the tests exercise it) and `lastConfirmationLine`. The rest lands
with location, onboarding and the paranoia counter respectively.

## Phase 2

**Faces live in `DidICore`, buttons live in the extension.** `SmallFace`, `MediumFace`,
`CircularFace` and `RectangularFace` are pure SwiftUI so the snapshot target can render
them. `Button(intent:)` needs AppIntents and WidgetKit, which the package deliberately
does not link, so the extension injects a `ConfirmAction` through the environment and
tests get `.inert`. Both paths render identical pixels — the wrapper adds no chrome.

**One widget kind, four families.** `AppIntentConfiguration` with an optional
`ItemEntity` parameter. `systemSmall` and `accessoryCircular` use the selection;
`systemMedium` and `accessoryRectangular` ignore it. One kind keeps
`reloadTimelines(ofKind:)` a single call, which is what the intent already does.
Unconfigured widgets fall back to the first item rather than rendering empty.

**`systemMedium` is a 2×2 grid, per architecture §5** — not the design's row-with-dotted-
leader list from `1d`. Docs beat design on structure. Worth revisiting: the leader-line
list is a better fit for the departure-board metaphor and handles long names more
gracefully. Overrule and it is a contained change to `MediumFace`.

**`accessoryCircular` shows SF Symbol + hours-since, per architecture §5**, not the
design `1e`'s tick-plus-name. Same precedence call. State is carried by glyph and
opacity, never colour, because iOS flattens these to monochrome.

**`accessoryRectangular` is the summary line only**, per architecture §5 — the design
showed three item rows. `Copy.summary` says "handled", never "done": the app knows there
is a record, not that anything was switched off.

**The widget is dark in both colour schemes.** Every value in `Palette` is a fixed hex,
so light and dark already render identically; the paired snapshots now assert it. A
stray `.primary` or `.secondary` would flip under light mode and fail the light half.
The design's light direction (`1b`) is a main-screen treatment, not a widget one.

**Snapshot harness is hand-rolled** — no third-party dependency is allowed, so
`ImageRenderer` → RGBA8 → per-channel compare, in `Tests/Snapshots/Snapshotting.swift`.
Tolerances are 12/255 per channel and 2% of channels differing, absorbing the
antialiasing drift that arrives with OS point releases. `RECORD_SNAPSHOTS=1` rewrites
references; a missing reference is always written *and* failed, so a new case cannot
pass on its first run. Failures dump a `.failed.png` next to the reference.

**Snapshots composite the background themselves.** The faces do not paint one — the
widget supplies it via `containerBackground`. Rendering them bare put near-white text
on white and the first recorded set proved nothing. `homeScreen()` grounds the system
families on `Palette.ink`; `lockScreen()` approximates the accessory families as white
on black, which is how iOS flattens them.

**Snapshot target is iOS, not the package.** `DidICoreSnapshotTests` is a
`bundle.unit-test` in `project.yml` running on the simulator, because macOS text
rendering is not representative of the device. The package's own tests stay pure logic
and keep the fast `swift test` loop architecture §7 asks for. References were recorded
on iPhone 16 / iOS 18.6 — re-record if you standardise on another simulator.

**Snapshot sizes are the design's** (Phase 2), not the device's: 158×158, 338×158, 72×72, 172×72.
Real widget frames vary by device, and the faces are frame-agnostic; the tests pin a
frame so the fixtures stay comparable.

## Phase 3

**Two tap targets per row.** day-2 says the reset editor opens by "tapping an item's
name (not the big confirm area)", so the name is its own button and everything else in
the row confirms. A long press anywhere on the row undoes. The name is a small target;
if it turns out to be fiddly on device, the alternative is a swipe action, not a bigger
name.

**Undo pops one confirmation.** `Store.undo` removes the most recent entry from
`todaysConfirmations` and reverts `lastConfirmedAt` to the one before it, or to nil.
The stored joke is cleared rather than restored — the line that went with the undone tap
is gone, and picking a fresh one would read as a reward for undoing. A side effect worth
knowing: undoing back below three confirmations also de-escalates the next line, which
is tested and is the behaviour you want.

**Undo has no confirmation dialog and no time limit.** It is available whenever the item
has a record, and it is reversible by tapping again. A destructive-action alert for
something this cheap would be heavier than the mistake.

**Undo is silent on the widget.** Architecture §5 rules out long-press inside a widget
button, so the widget's confirmation is reversible only by opening the app. Unchanged.

**No press-state highlight on rows.** The design's `style-active` background is dropped:
the flap turns over and the haptic fires on touch-up, which is the feedback. Add it back
if the row feels dead on device.

**Flap transition.** A character change pushes the old glyph up and the new one in from
below, 0.28s snappy — the split-flap read without 3D rotation maths. Reduced motion gets
the cross-fade the Day 0 doc specifies for the practice card. This is a guess about feel,
not a spec.

**Darwin listener now exists.** `StoreChange.startListening()` in the app's `init`
bridges the notification `StoreIO.write` posts into `NotificationCenter`, so the board
refreshes when the widget writes while the app is foregrounded. This closes the gap left
open in Phase 0.

**Item editor holds name, status word and "Forget this after".** Name is capped at 24
characters per Day 0; the status word is capped at 10, because past that the flap cells
stop being readable — neither cap shows an error, the field just stops accepting.
The `never` warning appears as a section footer only when `never` is selected.

**The global Settings screen is not built.** day-2 references "Settings → any item" and
the design's `2a` shows a full screen with TONE and reminder sections, but every other
row on it belongs to location (Phase 5) or repeat-use (Phase 6). The per-item editor is
reachable by the route day-2 specifies. Build the container when it has more than one
thing in it.

**`Store.active`** filters archived items and sorts by `order`; the board and all four
widget families now go through it. Nothing archives anything yet — that arrives with the
stale-item prompt in Phase 6.

**`HomeLocation` and `Store.home` exist but are never written.** Added now because the
editor has to hide "when I leave home" until a home exists, and a placeholder boolean
would just be something for Phase 5 to hunt down.

## Phase 4

**SF Symbol names are mapped, and the mapping is tested.** The Day 0 table names icons
conceptually — `iron`, `window`, `check` — and none of those exist in SF Symbols. An
unresolved symbol renders as nothing, silently, so `SymbolTests` asserts every chip's
symbol against the real catalogue via `UIImage(systemName:)`. Current mapping:
stove/straightener `flame`, door `lock`, iron `powerplug`,
windows `window.vertical.closed`, something-else `checkmark`.

**Status words per chip are invented.** The design's board spells out a word per item
and the Day 0 chip table does not supply one. Off / Locked / Unplugged / Shut / Off /
Done. Editable per item in the settings sheet.

**Screen 2 shows the onboarding-specific line, not a random one.** The doc's behaviour
note says "a random confirmation line appears below it", but the pool section names one
onboarding-specific line and describes the general pool as "used everywhere *after*".
Read as the latter — the joke is written for this moment. The card itself shows
"logged just now" and the line sits below it, as specified.

**No video on Screen 3.** The doc calls for a 4–6s looping capture of the install flow
and there is no asset in the repo. `Show me` opens the same five beats as large captions
(`Copy.Screen3.walkthrough`) instead. This is the one place Phase 4 is not the doc — a
written list is exactly what the doc says nobody follows. Drop the capture in and
replace the sheet's body.

**Screen 3 shows a live medium widget preview** of the user's own board. Not in the doc;
taken from design `1f`. It gives the screen something to look at where the video was
meant to be, and it is their real item rather than a mock.

**The practice card is the board's row, not a copy of it.** `BoardRow` moved into
DidICore and both screens use it, so "exactly as it will look on the main screen" is
enforced by construction. Onboarding passes only `onConfirm`, so the name-tap and
hold-to-undo affordances are absent there.

**The Phase 0 seed item is gone.** `StoreIO.read()` returns an empty store when no file
exists, and `RootView` shows onboarding. A store on your device from Phases 0–3 has no
`flags` key; `Store.init(from:)` is now hand-written so it decodes with defaults rather
than throwing the board away.

**Empty board reopens Screen 1, but does not re-onboard.** day-3 says a deleted last
item shows the Day 0 question again, and separately that returning users are never
re-onboarded. So an empty board always starts at Screen 1, and if onboarding was already
completed, picking a chip adds the item and returns straight to the board — no practice
tap, no widget screen. `firstItemType` keeps its original value.

**Notification permission is requested but nothing is scheduled.** Screen 3's
"Yes, once" branch asks the OS and records `notificationOptIn`. The nudge itself, and
its four firing conditions, are Phase 5. A prior OS-level denial skips the sheet
entirely, per the Day 0 edge case.

**Chips are a two-column adaptive grid.** The doc says "chips" and gives an order;
spacing and wrapping were not specified.

**Verbatim copy is enforced by test.** `OnboardingTests` asserts the Day 0 strings
character for character, plus the voice rule that no system copy contains an
exclamation mark. A well-meaning reword fails the build.

## Found by running it (post-Phase 4)

Four defects the test suite could not have caught, found by launching the app on a
simulator and looking at the screenshots.

**The practice card showed away-from-home copy.** `Copy.status` defaulted `isHome:
false`, so an unknown item read "No record since you left. That's not the same as
leaving it on." on the calm setup screen — truncated mid-word at that.
The Phase 1 reasoning was "never guess towards the joke", which was right about jokes
and wrong here: the light line is light, not funny. And the away line presupposes a
geofence — with no home set, "since you left" is not merely risky, it is *untrue*.
Parameter is now `isAway`, defaulting false; Phase 5 passes true after a region exit.

**The away line was clipped.** `lineLimit(1)` on the row's status. That line is 62
characters and is the single most carefully-written sentence in the product; it must
never be cut. Now two lines with `fixedSize`.

**Rows went ragged.** Making the status two lines gave rows unequal heights, which
stops a departure board reading as one board. `minHeight: 76`.

**Long status words crushed the item name.** "UNPLUGGED" is nine flap cells; at 18pt
they ran into the name column. `FlapWord` now takes an optional `maxWidth` and scales
cells uniformly to fit.

**The snapshot harness's record switch never worked.** `RECORD_SNAPSHOTS=1` read
`ProcessInfo.environment`, but `xcodebuild` does not forward shell environment to the
simulator test runner — it silently did nothing, and the original recording only
succeeded because the directory was missing. Removed rather than fixed: **to re-record,
delete the reference PNG and re-run.** Deleting one also used to break the build,
because XcodeGen globbed `__Snapshots__` in as build inputs; the directory is now
excluded from the target's sources.

## Phase 5

**The board is top-anchored now.** Design `1a` parks the rows at the bottom behind a
`flex:1` spacer, and day-2 requires that the decay lesson be "a sheet over the main
screen, not a full-screen takeover — the item list stays visible behind it so they can
see what's being talked about". The sheet lands exactly where the design parks the rows,
so the list was completely hidden. Docs beat design, and this also closes the dead-space
question flagged after Phase 3.

**`isAway` is derived from two timestamps**, `lastLeftHomeAt` and `lastEnteredHomeAt`,
not stored as a flag — same rule as display state. With no home set, `isAway` is false:
the away line claims "since you left", and that has to be true when shown.

**The `always` escalation is its own step**, immediately after home is captured, with
architecture §6's one-line reason. Refusal is silent — the geofence degrades to the 24h
ceiling, the leaving-home reminder is simply never offered, and no banner appears
anywhere. day-2 wanted this deferred until the nudge was enabled; architecture §6
overrides, because exit events do not arrive at all without it.

**The late-install nudge rule.** "If the install happened after 20:00, the nudge targets
the *next* weekday morning rather than the one 12 hours later" is read as: an install at
or after 20:00 waives the 12-hour minimum and takes the next morning, instead of skipping
to the morning after. A 21:00 Monday install fires Tuesday 08:00, eleven hours later.
The alternative reading — wait until Wednesday — makes the nudge arrive two days after
install, which is not what "rather than" is contrasting. Tested across every hour of a
full week; the fire date is never a weekend and always 08:00.

**The escape hatch lives in a context menu.** day-2 wants "Can't check right now" and
"Ask someone at home" always available on an unknown item while away. Two visible buttons
per row would wreck the board, so they are a long-press context menu on the row, shown
only in that state. Discoverability is the trade; revisit if it goes unused.

**Superseded after simulator user testing:** the row context menu consumed the same
long press promised for undo, so a confirmed item could not actually be undone. Secondary
away and ordering commands now live in a subtle 44-point ellipsis menu beside the item
name. The whole row remains the confirm/undo target; the same menu opens item settings.
An attempted invisible 44-point name target still failed Apple's hit-area audit and made
the row's two tap meanings too easy to confuse, so the name is display text only.

**Muted items are excluded from `counted`**, which is what `accessoryRectangular`
summarises. `active` still includes them, so they stay on the board — the mute silences
the count, not the item.

**A Settings screen exists now**, minimally. Phase 5 forces it: day-2 wants "Reset home
location" and a one-line note when location is revoked, and both need somewhere to live.
It holds home state and the "Forget this after" pointer, nothing else. Tone and reminder
sections from design `2a` wait for Phase 6.

**Notification permission for the per-item reminder is asked at the toggle**, not
earlier — the first moment it buys the user something concrete. The toggle only appears
once a home exists.

**`reconcileWidgetNudge` runs on every foreground** and resolves the nudge to exactly one
of scheduled, retired, or already handled. Permission revoked in Settings marks it fired,
per the day-1 edge case: iOS drops it silently, so the bookkeeping should be honest.
Installing the widget also marks it fired, which is what stops it re-arming if the widget
is later removed.

**Foreground notifications are presented as banners.** The leaving-home reminder arrives
seconds after the exit, when the phone may still be in the user's hand; suppressing it
there would make the feature look broken.

## Phase 6

**The guardrail has a magnitude floor the doc does not specify.** day-3 says only
"if checks-per-day for a single item trend upward across three consecutive weeks".
Taken literally, 1 → 2 → 3 checks over three weeks trips it — permanently suppressing
the weekly card and telling a light user that the app "has become the thing you check".
That is the most harmful sentence in the product, so it now also requires the most
recent week to reach 10 checks, reusing the counter's own threshold for "a lot".
Tested both ways. **This is a judgement call on an underspecified rule — overrule it
by changing `EscalatingChecks.floor`.**

**Per-item check counts come only from app opens.** A "check" is a *view*, per
architecture §3. iOS gives no callback when someone looks at a widget, so widget views
are unobservable — the widget's timeline is precomputed and the system renders it
without running our code. Opening the board therefore counts as one check for every
item on it. Consequences: the second-item trigger "one item checked 5+ times" is in
practice "the board opened 5+ times", and the weekly card's "top worry" ranking is
driven by how long an item has been on the board rather than by attention. The
plumbing, the trends and the guardrail are all real; the input signal is coarser than
the doc assumes. A real per-item signal would need something like a tap that opens an
item — worth adding before shipping the counter.

**`checkCounts` is `[String: [Date]]`, keyed by `uuidString`.** Architecture §3 writes
`[UUID: [Date]]`, which `JSONEncoder` emits as a flat alternating array — unreadable in
a store that §2 wants inspectable during development.

**`todaysConfirmations` became `confirmations`, trimmed to 30 days.** The weekly card
needs to know what was confirmed across a week, not just today; the escalation pool
still filters to the current day. Stores written before this lose their confirmation
history once, which resets escalation and delays the first weekly card. No migration
written — it is a counter, not content.

**`OnboardingFlags` and `Usage` now decode leniently**, like `Store`. Found by test:
the Phase 4 "old store still decodes" test only passed because `flags` was absent
entirely. With a partial `flags` object present, synthesised `Decodable` threw and the
whole store — every item — was silently replaced by an empty one. Any field added to
either struct would have shipped that bug.

**A "flat week breaks the trend."** `escalating` requires strictly increasing rates.
Trending upward should not fire on a plateau.

**Archived items do not count toward the cap**, so "Swap one out" frees a slot without
deleting anything. Archive, never delete.

**The add-item sheet is the second-item prompt.** Same view, different heading, so the
suggestion is a normal add rather than a special modal. Declining it increments
`declineCount` — the cooldowns depend on that being the *only* way to decline.

**Chips are matched to existing items by name.** Renaming an item resurfaces its chip.
Better than silently hiding a chip whose item no longer resembles it.

**Not built, though day-3 describes them:** the 30-day stale-item archive prompt and
the `SKStoreReviewController` prompt. Neither was in the phase brief. The archive
machinery they need (`archive`, `unarchive`, `archived`, the "Previously" section) is
in place, so both are small additions.

## Tail: stale items and the review prompt

**The 30-day archive offer counts from creation for never-confirmed items.** day-3
says "hasn't come up in a month"; an item created six weeks ago and never confirmed has
not come up either, and is the likeliest thing on the board to be dead weight. Offered
once, whatever the answer — `Item.archiveOfferedAt` is stamped on both buttons.

**One prompt per app open, in priority order:** decay lesson → pending home setup →
escalating-checks guardrail → weekly card → second-item suggestion → stale-item offer.
Each returns early. Stacking any two of these would undo the restraint every one of
them is written with.

**Review uses SwiftUI's `requestReview` environment action**, not
`SKStoreReviewController.requestReview(in:)`, which is deprecated on iOS 18 and would
fail the warnings-as-errors build.

**Review's "at home" test passes when there is no geofence.** `isAway` is false without
a home, so a user who declined location can still be asked. The trigger is a
confirmation that just happened, which is itself the "things are good" signal day-3 is
reaching for. Only a *known* away state suppresses it.

## Tail: the medium widget and the check signal

**The medium face shows all six items, not four.** It was `prefix(4)` against a
six-item cap, so a full board silently hid two rows — on a board whose entire job is
answering "did I?", a hidden row is the worst thing it can do. Two columns still
(architecture §5); the row count goes to three once there are more than four items.
Six rows fit the medium height with no clipping in either scheme.

**Cells stay in board order, never sorted by state.** Ranking unknown items first
reads better on paper, but widget timelines refresh on their own schedule, and a cell
that moves between the decision to tap and the tap itself confirms the wrong item.
Stable position beats useful order in a one-tap product.

**Confirming an item now records a check of it.** `checks` was written only by
`recordBoardView`, so a widget-only user — the intended primary user — produced no
check history at all, and the paranoia counter read their week as empty. A tap is the
only look iOS ever lets us observe.

**Opening the board only counts as a check of items that were still unknown.**
Previously it fanned out to every active item, which made per-item checks a copy of
the app-open count: every item tied, and the counter's "top worry" ranking was
meaningless. If the stove already reads green, opening the board was not checking the
stove. When everything is green the open is recorded in `appOpens` and attributed to
nothing.

This narrows but does not close the gap noted in Phase 6: a look at the widget that
does not end in a tap is still invisible, because iOS gives no callback for a widget
being rendered or viewed. What `checks` now measures is *observed* attention —
confirmations plus board-opens while in doubt — which is a real per-item signal rather
than a proxy for app launches.

## PO pass: closing the flow dead ends

**Items can be put away from item settings.** Archiving previously required either
hitting the six-item cap (to reach the swap flow) or waiting 30 days for the stale
offer. A three-item board was permanent. One destructive row in `ItemSettingsView`,
worded "Put it away" with the restore promise as its footer — archive, never delete,
same as every other path.

**"Previously" also appears on onboarding Screen 1.** An empty board falls back to
Screen 1, and the restore list lived only in `AddItemSheet`, which an empty board can
never reach. Archiving your last item therefore stranded every item you had ever
archived. `PreviouslyList` is now shared by both, and Screen 1 puts it in a
`ScrollView` because unlike the fixed chip grid it can outgrow the screen.

**A chip is hidden when an item of that name is archived, not just when it is
active.** Fixing the above surfaced it: "The stove" showed as both a chip and a
Previously row, and the chip would have created a second copy while stranding the
first one's history. `Chip.available(excluding:)` now takes all items, and both
callers use it.

**Settings links to the widget walkthrough.** "Later" on Screen 3 plus a declined
notification permanently closed the only two routes to those instructions, and the
widget is the product. One quiet row; no banner, no re-prompting.

**A failed home fix says so.** `captureHome` returns `nil` indoors or in airplane
mode, and `guard let coordinate else { return }` made the primary button do nothing
at all inside a sheet that cannot be swipe-dismissed. It now shows one amber line and
stays put. Deliberately not `decline()` — a failed fix is not a refusal, and burning
`locationDeclined` would mean never asking again.

**Board order is editable, one step at a time.** "Move up" in the row context menu
swaps `order` with the item above. Board order is also the medium widget's
tap-target order (see the stable-position decision above), so a position assigned
once at add time is not something to be stuck with. A `List` with `.onMove` would
give free reordering but would take the departure-board layout with it.

The simulator user test above supersedes only the trigger: "Move up" now lives in the
row's ellipsis menu so long-press remains reserved for undo.

**`Copy.LocationDeclined.settingsHint` is now `Copy.resetRuleHint`.** It is the
pointer to the reset-rule editor, shown unconditionally in Settings; someone who
granted location needs it just as much as someone who declined.

## Localization, stage 1: English only, but honestly English

No second language is added here. This is the work that has to happen *before*
one can be, plus the English-only bugs that were hiding inside it.

**`.stringsdict`, not a String Catalog.** SwiftPM's command-line build copies an
`.xcstrings` into the resource bundle verbatim and never compiles it, so plurals
resolved to "1 minutes" under `swift test` while working under `xcodebuild`. A
test suite that cannot see the localization is not a safety net. `.stringsdict`
is processed by both build systems; Xcode can migrate it to a catalog with one
menu command whenever a translator wants that format.

**One `t()` helper rather than `String(localized:bundle:)` at ~70 sites.** The
widget extension links DidICore, so every lookup has to name `Bundle.module`
explicitly or it searches the running executable and finds nothing. One helper
means that cannot be forgotten at one call site.

**`withArticle` is deleted, and every sentence that used it was rewritten.** It
lowercased a user-typed noun and prefixed "the". German needs der/die/das for a
word we never see; Polish and Russian decline it differently per sentence. The
paranoia card, the guardrail and the decay lesson now put the name in a label
position — "Top worry: Iron.", "The stove: fine every single time." — where no
language has to agree with it. `bareName`, which faked a possessive by deleting
a leading "The ", went the same way.

**The guardrail's closing clause was wrong for every item that is not a stove.**
It said "will still be off" regardless, so a door read "the front door will still
be off". Found while rewriting the sentence for the above; it takes `item.word`
now.

**The hour is formatted, not assembled.** `clockHour` glued a translated "am"
onto a number, which assumes every locale has a meridiem and puts it last. It
uses `Date.FormatStyle` now: "4 AM" in en_US, "13" in en_GB, "04 Uhr" in de_DE.
This does change English copy — the design's "4am" becomes "4 AM" — and that is
the honest cost of not hardcoding a clock convention. `locale` is injected for
the same reason `now` and `calendar` are, or the tests assert whatever region
the build machine happens to be in.

**Tests normalize U+202F.** `Date.FormatStyle` separates hour from meridiem with
a narrow no-break space. Correct typography, invisible in a source literal, so
`plainSpaces()` swaps it rather than having every expectation carry a character
nobody can see.

**`Item.chipID` — chip copy follows the language, typed copy never does.** Adding
an item copies the chip's label and word into the store as literals, so without
this a language switch left the board in the old language forever and every chip
reappeared as available (`Chip.available(excluding:)` matches on name). Items
built from a chip carry its id; `Store.localizeChipCopy()` reapplies the current
label and word on every read, in both processes, so the app and widget can never
disagree. Editing either field in item settings clears the id, and from then on
the text is the user's and is never rewritten. A typed name is never tagged.

**What stage 1 deliberately does not solve.** `item.word` is spelled out in flap
cells sized for short English words — "LOCKED" is six characters, German
"ABGESCHLOSSEN" is thirteen, and `FlapWord` will scale it down to unreadable
rather than clip. That is a design problem, not a plumbing one, and it should be
solved against a real second language rather than in the abstract.

## Localization, stage 2: Polish and Russian

**`CFBundleLocalizations` on the app target is what actually turns a language on.**
Shipping `pl.lproj` and `ru.lproj` inside the DidICore resource bundle did nothing
on its own. iOS picks the process language from the *main* bundle's supported
localizations, and the app target has no `.lproj` folders because every string
lives in the package. With Polish set as the device language the app still ran
entirely in English — including `Date.formatted`, which was the tell. The app
target now declares `en, pl, ru` in its Info.plist. **Add a locale there whenever
one is translated, or the translation is dead weight in the binary.**

**Plural rules come from the process locale, not the catalog.** A macOS harness
running under `en_PL` applied English plural rules to the Polish forms and picked
"5 minuty" instead of "5 minut". That is a property of the test environment, not
the data. Verified on a genuinely Polish device: 1 minuta / 22 minuty / 5 minut,
and on Russian: 1 час / 3 часа / 5 часов. All four categories resolve correctly in
both languages. The lesson is that plural forms cannot be trusted from a unit test
run in another region — they need a device set to the target language.

**`Done` is one key serving two places.** It is both a chip status word and a
toolbar button, and a `.strings` file cannot hold a key twice. Both translations
were checked identical before deduping; if a future language needs them different,
the two uses have to be split into separate keys first.

**The widget extension carries its own four-string file per locale.** Not
duplication for its own sake — the AppIntents metadata extractor refuses any
bundle but the extension's own. Everything else in the product resolves from
DidICore.

**The chip relocalization works as designed.** A store written with English chip
names came back on a Polish device as KUCHENKA / DRZWI WEJŚCIOWE / ŻELAZKO / OKNA
without any migration step, which is `Store.localizeChipCopy` doing its job on
read. Diacritics and Cyrillic both render in the flap cells.

**The flap-cell width problem did not materialise, because the translator dodged
it.** Polish and Russian status words came back as abbreviations — WYŁ., ZAMK.,
ODŁ., ВЫКЛ., ОТКЛ. — rather than full adjectives, so nothing was scaled down to
unreadable. That was the translator honouring the six-character brief, not the
layout being safe. A language that cannot abbreviate naturally will still break
this, and the constraint has to stay in every future brief.

## Widget pass: the tap that lied

**The small face is no longer one big button.** It used to wrap the whole face in
`ConfirmItemIntent`, which meant tapping the widget to *look* at it wrote a
confirmation. That is a false green — the precise failure the product exists to
prevent, and the thing the location permission string promises to avoid ("an old
checkmark never fools you"). It also left a small-widget-only user with no route
into the app at all, since every pixel was the button.

The header row (name + age) is now outside the button and falls through to the
default open action; the flaps and status line are the button. The rule is one
users already know from other widgets: the control acts, the label is the door.
`RootView` already lands on the board when onboarding is complete, so no deep
link was needed — opening from the widget arrives exactly where undo lives.

This also repays the Day 0 promise. Screen 2 teaches "hold to undo", then Screen
3 moves the user onto the widget, where hold means "edit home screen". A mis-tap
used to cost: notice, find the app icon, open, locate the card, hold. It now
costs tap-header, hold-card. A widget undo button was considered and rejected
again — a second button on a one-tap surface argues with the premise.

**`invalidatableContent()` on everything a tap changes.** Re-confirming an item
that already read NOW produced no visible change whatsoever, which reproduces
"did that register?" — the exact loop the app claims to end — inside the app's
own widget. The modifier makes the age, flaps and status blur the instant the tap
lands and resolve when the new entry arrives. This is why the medium face's age
and status word are wrapped as one unit rather than separately: they are one
statement and should settle together.

**Snapshot tests pass unchanged, which is the point.** The small-face refactor is
pixel-identical; only the tap regions moved. It also means the snapshots cannot
prove the carve-out works — that needs a home screen.

**Two hard-coded accessibility hints are gone.** `Faces.swift` had
`"Double tap to log"` inline twice while a translated `Copy.confirmHint` already
existed, so Polish and Russian VoiceOver users got English. They were also the
only strings living outside `Copy.swift`. `CircularFace` had no hint at all.

**Translation delta: one new key.** `"Double tap to open Did I?"` (`Copy.openHint`)
is English-only and falls back cleanly. It needs to go to the translator with the
next batch.

**Known and accepted:** archiving the configured item silently retargets the
widget to the first active one. The name is on screen so it is visible, but a
user trained on "top-left widget = stove" will glance at green belonging to the
door. A dead widget is worse.

## Device feedback: the settings dead end and the lock screen

**Settings had no way to set home.** With `home == nil` the section rendered
`Copy.HomeSettings.notSet` as plain `Text` and nothing else — "Not set", not
tappable, no route forward. The only path to home setup was the day-2 sheet,
which fires once, so anyone who tapped "I'm not home right now" or opened
Settings before day 2 was permanently stuck. It is now a button presenting
`DayTwoFlow`, reused rather than reimplemented so the capture, the no-fix line
and the `always` escalation all still happen. It enters at `.locationAsk` when
authorization has not been granted and `.homeSetup` when it has.

**Known remaining edge:** if location was denied in iOS Settings, the flow runs
to `.declined` and explains the timer fallback rather than offering a jump to
iOS Settings. Honest, but still not a way forward. Left alone for now.

**The lock screen face was the wrong design, and the report proved it.** The
device feedback was "Ready 1 from 2 or Ready 1 ... I was thinking it will show
icon for device and I can click to confirm, but widget opens app". Those two
strings only come from `Copy.summary`, which only `RectangularFace` renders, so
the widgets in question were lock screen accessories.

architecture §5 specified `accessoryRectangular` as a bare summary and it was
built exactly that way. On a real lock screen it fails the question the app is
named after: "1 of 4 handled" does not tell you whether *the stove* is off, and
with no button the one-tap promise is invisible on the surface most likely to be
glanced at. It now shows the configured item — symbol, name, age, status word —
is tappable like every other per-item face, and keeps the count as a third line,
so nothing the doc asked for was lost. **This overrides architecture §5** and is
the one place the docs have been contradicted rather than followed; reverting is
a single view.

**`systemSmall` was missing the icon the same table specifies** ("Icon, name,
state, relative time"). Added to the header. It costs a few characters on the
longest name in the chip pool — "THE SPACE H…" now truncates where it did not
before — which is accepted: the glyph does the identifying, and scaling 9pt
tracked uppercase any further makes it unreadable.

**The empty board moved into `EmptyFace` in DidICore.** It had been written
inline in the widget target, where the snapshot suite cannot reach it, so the
one state a new user is guaranteed to see had no coverage. Now shared by every
single-item family and snapshotted.

**`Copy.ok`.** `DayTwoFlow`'s declined step had a hard-coded `"OK"`, the last
user-facing string outside `Copy.swift`. It became reachable from Settings with
this change, so it was fixed rather than noted. Value equals key, so pl and ru
resolve correctly through fallback with no translator round-trip.

## The small widget always showed the same item

Reported from a device: the small widget shows the front door and nothing else,
with a two-item board. Not a rendering bug — the unknown-state snapshot proves
the flaps do fall back to amber dashes — and not a metadata failure either;
`Metadata.appintents` in the built appex contains `SelectItemIntent`,
`ConfirmItemIntent` and `ItemEntity`, so configuration is registered correctly.

The cause is `BoardEntry.selected` falling back to `store.active.first` for an
unconfigured widget, which is correct code meeting a broken assumption. Nothing
in the product ever says the widget can be configured. "Long-press → Edit Widget
→ Item" is not a thing people go looking for, so every small widget stays on
item one forever and a second item is unreachable.

**Fixed with `AppIntentTimelineProvider.recommendations()`**, which is what the
platform provides for exactly this. The gallery now lists one ready-made entry
per item, so the choice happens at placement — where it belongs — instead of in
a menu nobody opens. Capped at six to match the board cap; an empty board returns
nothing and the gallery falls back to the placeholder.

This only helps at placement time, so `Copy.Screen3.whichItem` was added to the
walkthrough sheet for changing one already on screen. It is deliberately *not* a
sixth numbered step — the numbering encodes a placement sequence and this is a
footnote about a widget that already exists.

**Translation delta: `Copy.Screen3.whichItem` and `Copy.openHint`** are both
English-only pending the next translator batch.

## Security and performance pass

**The store could be wiped by a single decode failure.** `read()` could not tell
"no file yet" from "file exists and will not decode" — both returned an empty
`Store()`. `mutate` was built on it, so one unparseable file meant read empty,
apply a no-op, write empty, and every item was gone. In an app whose first rule
is that items are archived and never deleted, this was the only path that deleted
everything, and it did it silently.

`read()` still flattens failure for display, which is right — a widget cannot
surface an error and an empty face beats a crash. But it is now a thin wrapper
over `load()`, which seeds a genuinely absent file and throws for a corrupt one,
and every write goes through the throwing path. The realistic trigger was never
first-unlock (writes fail there too, so it failed safe) but schema-shaped: a
downgrade to a build that does not know a newer `resetRule` case, or someone
later adding a non-optional field.

**`mutate` is now a single coordinated write.** It used to take one coordination
to read and a second to write, and the gap lost updates: tap the stove and then
the door on the medium widget, and the second read could precede the first write,
dropping a confirmation the button had already acknowledged. The old comment
claimed either outcome was correct, which holds only for two taps on the *same*
item. The same gap could drop an archive under a widget tap.

**The file protection class is stated rather than inherited.** It was whatever
the container defaulted to; it is now written explicitly as
`completeFileProtectionUntilFirstUserAuthentication`. That is deliberately not
the strongest option: `complete` would stop the lock screen widget reading while
locked, which is the only reason that widget exists.

**"Nothing leaves your phone" was not true and is now accurate.** App Group
containers are included in iCloud backups, so the store — home coordinate
included — does leave the device in the user's own backup. Excluding it from
backup would make the old sentence true at the cost of wiping the board on every
device migration, which is a worse trade than stating the promise precisely. The
footer and both location usage strings now say the store is never sent to a
server, which is meaningful and exactly correct. **This overrides
day-0-install.md's verbatim copy** — a doc cannot authorise a false privacy claim.

**`UIBackgroundModes: location` removed.** That key is for continuous background
location. `LocationMonitor` never calls `startUpdatingLocation` and never sets
`allowsBackgroundLocationUpdates`; region monitoring delivers exits and relaunches
a terminated app without it. Declaring it invited App Review questions and put the
app in the battery list under background location for nothing. **Verify geofencing
still works on device before shipping** — this is the one change here that fails
silently if the reasoning is wrong.

**History is swept, not just trimmed where touched.** `confirm` and `recordCheck`
only ever trimmed the one item they were given, so an archived item froze with up
to 30 days of history and its `usage.checks` key was never visited again. Items
are never deleted, so those arrays were the only part of the file that grew
without limit — and the file is re-parsed on every widget refresh and every tap.
`pruneHistory` applies the existing 30-day retention to everything and rides on
`recordBoardView`, the one frequent path never on the widget's budget. Trimming
history is retention, not deletion: the item and its archive are untouched, which
a test pins down.

**Timeline boundaries are deduplicated and skip archived items.** A just-archived
item kept its `lastConfirmedAt` and so kept producing boundaries for a day after
leaving the board, and six items sharing a 04:00 reset produced six identical
timestamps against a cap of 20.

**`.prettyPrinted` is DEBUG-only** rather than shipping inflated JSON.

**Deliberately not changed: synchronous store reads on the main thread.**
`RootView` reads at init and `LocationMonitor.start()` reads during launch, both
through file coordination, which can in principle block on the other process. The
file is small and the window is microseconds, and the launch read *must* be
synchronous — a region exit relaunches a terminated app and the manager has to
exist before the first `await`. Making the rest async buys a loading state and a
flash of empty board in exchange for a hazard nobody has measured.

**Translation delta.** `Screen1.footer` changed, so the pl and ru entries for the
old sentence are now dead and the new one falls back to English. Pending keys are
now that footer, `Copy.openHint` and `Copy.Screen3.whichItem`. The two location
usage strings in `project.yml` have never been localised at all — there is no
`InfoPlist.strings` — which is a separate gap worth closing in the same batch.

## Release-readiness product pass

**Location denial now has a recovery route.** Once iOS location permission is
denied, calling `requestWhenInUseAuthorization` again cannot show the system
dialog. Settings therefore shows an explicit, localised `Open iOS Settings`
button instead of sending the user through a sheet whose primary action could
only fail. Authorization is refreshed both when that sheet closes and whenever
the app becomes active again; the same recovery action is shown if permission is
revoked after home was already set.

**"I'm not home right now" has a 24-hour cooldown.** The pending flag previously
caused the home setup sheet to return on the very next launch, including seconds
later. The original overnight stationary-location idea was never implemented and
would add tracking solely to decide when to ask for more tracking. A timestamped
24-hour deferral is deterministic, testable, and leaves Settings available for
anyone ready sooner. Existing stores with the old boolean-only pending flag still
prompt once, preserving migration behavior.

**The Polish and Russian privacy/localisation delta is closed.** The corrected
server-based privacy promise, small-widget instruction, app-opening VoiceOver
hint, and location-denial recovery action now have translations. Both system
location permission dialogs also have per-locale `InfoPlist.strings`, so the most
sensitive copy no longer falls back to English.

## UX hardening pass

**Every user-initiated store write is transactional in the UI.** Confirming,
undoing, adding, editing, archiving, restoring, setting home and completing a
setup step now advance, dismiss, animate and fire success haptics only after the
write succeeds. A failed initial read shows a retry state instead of pretending
the user has an empty board. Background best-effort bookkeeping remains quiet.

**Confirmation copy records evidence, not physical truth.** A tap proves that the
user made a confirmation at a time; it cannot prove a stove is currently off, a
door is locked, or that nothing bad happened. The general, escalation, weekly and
guardrail lines now describe timestamps and observed app activity only. Weekly
totals are interpolated from the real count. Legacy localisation keys remain in
the string files so an old persisted confirmation line can still be translated.

**The existing feature set stays intact, with recovery paths made visible.** Undo
remains on long-press and is also in the row's More menu. Away-state mute and
share actions remain and are now visible below the affected row. Archiving,
restoring, suggestions, decay education, location setup and the weekly card are
unchanged in scope. Destructive semantic roles were removed because they rendered
red, which violates the product's standing colour rule; confirmation remains.

**Small screens and accessibility sizes scroll instead of clipping.** Onboarding,
setup sheets and the board use semantic type and scrollable containers, with
44-point secondary controls. At accessibility sizes the board swaps the decorative
flap word for readable semantic text. Custom names are trimmed, case-insensitive
duplicates across active and archived items are rejected, and a blank custom
status word cannot be saved.

**The six-item medium widget is a 3 × 2 grid.** All six items remain visible, but
the previous 2 × 3 layout made each tappable row too short. Two rows preserve a
minimum 44-point hit target without changing the cap or removing configuration.

**The widget onboarding action says what exists.** There is still no video asset,
so `View steps` opens the existing captioned walkthrough. Calling it `Show me`
implied a video the app did not contain. This is a copy correction, not a removed
flow; a real localised video can replace the sheet later.

## Confirmation-expiry trust pass

**Expiry settings apply to future confirmations only.** The former implementation
resolved the latest timestamp against the item's live `resetRule`. Changing an
expired item to `never` could therefore turn it green without another tap. Each
confirmation now captures its rule, with aligned snapshots retained for Undo.
Legacy items capture their old rule before the first settings edit. Display state
remains derived; the inputs are now the timestamp, its captured rule and now.

**"Forget this after" is now "Confirmation expiry".** "This" could mean the item,
its history or its current record, while the app only controls how long a
confirmation counts as current. The focused editor says new confirmations stay
current until, names the anchor for rolling durations, exposes the 24-hour
geofence ceiling, and states that the board's current status will not change.
General name/status editing is a separate More-menu action.

**Leaving-home expiry is offered only when it can run in the background.** A home
coordinate plus When-In-Use permission cannot fulfil the promise. New selection
requires Always Location. An existing unavailable selection remains visible but
disabled, with an explanation and direct recovery route to iOS Settings.

**"Confirmation expiry" is now "How long a tick lasts", and the options no longer
complete the header.** The rename off "Forget this after" fixed the ambiguous
"this" but landed on systems vocabulary, in a More menu whose other rows are plain
verb phrases ("Edit item", "Put it away", "Can't check right now"). "Tick" is
already this app's word for the thing that expires. The header was a sentence stem
— "New confirmations stay current until" — that two of five options could not
complete: "…until *when* I leave home" and a literal doubled "…until *until* I
confirm again". Options are now self-contained under "When a tick stops counting",
which also removes the case-agreement trap the stem set for pl/ru.

**`.never` says "Never" and carries its warning on the row.** The old label,
"Until I confirm again", described true behaviour but read as the safe default —
every rule ends when you confirm again — while `neverWarning` appeared in the
footer only *after* selection, contradicting the label it was meant to qualify. A
caution that arrives after the tap is not a caution.

**Still open: "Edit item" is a decoy for this setting.** It is the obvious "change
this thing" affordance and holds name, status word and the leaving-home *reminder*,
while the leaving-home *expiry* lives in a sibling sheet. Two geofence settings,
two screens, one guaranteed backtrack. Merging the expiry editor into
`ItemSettingsView` as a push is the fix; deferred because it is structural, not copy.

**The expiry editor moved inside "Edit item".** It used to be a sibling row in the
More menu, which made "Edit item" a decoy: the obvious "change this item"
affordance held name, status word and the leaving-home *reminder*, while the
leaving-home *expiry* sat in a separate sheet — two geofence settings on two
screens, and a guaranteed backtrack for anyone who guessed the pencil icon first.
`ConfirmationExpiryView` is now pushed from `ItemSettingsView` on a
`@Binding var rule`, with no Done of its own; the parent's Done saves the whole
item at once, so an item is never half-edited. The focused-editor rationale still
holds — five options with a warning on one do not belong inline — it is just a
push instead of a sheet.

Routing the rule through `ItemSettingsView.save` is safe: `Store.update` captures
the rule snapshot regardless of which field changed, so "applies to future
confirmations only" is unaffected. The one-time pointer copy now names both hops:
More → "Edit item" → "How long a tick lasts".

**The dimmed leaving-home row explains itself to VoiceOver.** The footer naming
the missing permission comes after every other option in reading order, so the row
carries `Copy.leavingExpiryUnavailable` as an `accessibilityHint` too, and the
Open-Settings section — previously a bare unexplained button — now has the same
line as its footer.

**A revoked notification permission no longer leaves a reminder toggle lying.**
`leavingHomeReminder` asked for permission once, at the moment it was switched on,
and nothing re-checked it. Switch notifications off in iOS Settings afterwards and
`center.add` fails silently while the toggle still reads on — the app's one active
safety net, dead, with the UI insisting it works. Worst for exactly the user who
stopped opening the board because they trusted it. The toggle is *not* cleared:
that would hide the failure and throw away the intent. Instead the state is
re-derived on every appearance and on foreground, the item editor explains it with
a route to iOS Settings, and Settings grows a Reminders section that appears only
when reminders are on and cannot fire. Same shape as the unavailable leaving-home
expiry, and as the revoked-location note: keep the choice, say why it cannot run,
offer the way back. `reconcileWidgetNudge` had this treatment already; the reminder
never got it.

**"Can't check right now" and "Ask someone at home" no longer require a geofence.**
Both were gated on `isAway`, which needs a home plus Always Location plus a real
region exit. day-2 accepts "declined, app keeps working on timers" as a normal
outcome, so that gate withheld the app's entire answer to being out and unable to
check from the people most likely to need it. The gate is now
`isAway || cannotTellIfAway`; when the geofence *can* answer and says they are
home, the actions stay hidden. `isAway` still gates the status line, which claims
"since you left" and has to be true — these buttons claim nothing.

Muting needed an end condition that does not depend on region entry, so `confirm`
now lifts the mute, and the muted line reads "until you confirm it" rather than
"until you're home" when nothing can detect a homecoming.

**A visit spent in Settings or the item editor is no longer counted as checking
the stove.** `recordBoardView` recorded a check against every unresolved item on
every open, including opens made to rename an item, set home or fix a rule. Those
counts feed the weekly card, which reads them back to the user as a fact about
their own behaviour — an app whose first obligation is not to generate anxiety
cannot inflate that number. Split in two: `recordBoardView` (prune + app open,
every time) and `recordChecks` (per item, deferred to scene background and skipped
when the user navigated on purpose). At launch there is no way to tell the two
kinds of visit apart, so the call waits until the visit is over. App-initiated
interruptions — the day-2 lesson, the guardrail, the weekly card, the second-item
suggestion, the stale offer — deliberately do not set the flag: the app
interrupted them, they still came to look.

**Leaving-home reminders: background task assertion, single store access,
notification-before-widget ordering, and a foreground backstop.** Reported as
"sometimes not triggered, sometimes triggered too late" — the "too late" half is
geofence detection latency (see the 150m→100m radius change above); the
"sometimes not triggered" half was architectural, four independent causes in one
~10-second background wake:

- `UNUserNotificationCenter.add` is XPC with no synchronous counterpart, called
  with no `await` and nothing else holding the process open — a bare race against
  iOS suspending the app, won most of the time and lost some of the time. Fixed
  with a `beginBackgroundTask` assertion around the whole wake, held until
  `scheduleLeavingHomeReminders` actually `await`s each `add` call to completion.
- `didExitRegion` wrote the exit via `StoreIO.mutate`, then immediately opened a
  second coordination with `StoreIO.read()` to find due items. `read()` flattens
  any failure to an empty store and the caller cannot tell "nothing was due" from
  "the read failed" — a second silent failure mode in the tightest budget in the
  app. `StoreIO.mutate` is now generic (`mutate<T>(_:) -> T`), so the due-item
  list is computed inside the same access that records the exit.
- A failed `mutate` used to `return` immediately, dropping the notification along
  with everything else — the notification is the least recoverable part of a
  failed write (a stale `isAway` corrects itself on the next successful access; a
  reminder that never fired does not), so failure now falls back to computing
  `due` from a plain read instead of giving up.
- `WidgetCenter.shared.reloadAllTimelines()` ran before the reminder was
  scheduled. Reordered: the widget can be a few minutes stale for free, the
  reminder cannot.
- Exit is the *only* trigger; a wake that is skipped entirely (app not launched
  for the region event, killed before the background task begins) had no
  recovery path at all. `Notifications.reconcileLeavingHomeReminders()` now runs
  on every foreground next to `reconcileWidgetNudge`, checked against
  `pendingNotificationRequests` (the actual source of truth for "was this ever
  scheduled") rather than a store flag.

`didEnterRegion` is unchanged: no notification is scheduled there, so it does not
share the same failure shape.

**The board row's long-press-to-undo missed the first attempt.** `.onTapGesture`
and `.onLongPressGesture` were attached as two independent modifiers on the same
row. Their underlying UIKit recognizers have no failure relationship to each
other, so the first long press after the row appeared could lose the
recognition race and register as nothing at all — reported as "cancel doesn't
work the first time," and as a side effect "still has checkmark, color didn't
change," because with `onUndo` never actually called there was nothing for the
row to update. Composed into one `Gesture` instead —
`LongPressGesture(minimumDuration: 0.5).onEnded { undo() }.exclusively(before:
TapGesture().onEnded { confirm() })` — which gives the two an explicit
precedence, so there is nothing left to race.

No change was made to `Palette` (fresh/aging/unknown). The reported "color is
almost the same" was most likely the same symptom as the checkmark not
clearing — nothing had actually changed, since undo never fired. Revisit if it
still reads as low-contrast after retrying with the gesture fix.

**Geofence radius cut again, 100m → 75m.** Same lever as the earlier 150m → 100m
change, pulled a second notch: real-world background region monitoring accuracy
and iOS's own hysteresis buffer both add distance on top of whatever radius is
configured, so each cut chases a moving target with shrinking returns. 75m is
close to the practical floor Apple documents for `CLCircularRegion` monitoring —
a further cut trades a small latency win for a real rise in false exits from GPS
drift indoors (apartments, multi-story homes, weak signal). `LocationMonitor`'s
clamp now reads `min(home.radius, 75)` so stores still holding 100 or 150 from
before this change pick up the new ceiling without a migration.

**Geofence radius is now user-adjustable, not a single global default.** A flat
and a house with a garden both read as "home" at wildly different scales — no
fixed number (150m, then 100m, then 75m) can be right for everyone, and shrinking
the global default for latency risked firing "left home" while someone with a
larger property was still in their own yard. Settings gains a "Home area size"
slider (50–250m, 25m steps, shown once a home exists), saved on drag release —
not per tick, since each write is a coordinated file access — and applied
immediately via `LocationMonitor.monitor` rather than waiting for the next
foreground. `HomeLocation.defaultRadius` (75) and `.radiusRange` (50...250) are
the single source for both the initial capture value and the slider's bounds.

The old `min(home.radius, 75)` clamp in `LocationMonitor.monitor` is gone: it
existed to auto-migrate stores from the app's own shrinking defaults, but with a
real user control in place it would silently overwrite a deliberate choice on
every relaunch, making the slider a lie. Replaced with a clamp to
`HomeLocation.radiusRange` only — a floor/ceiling against corrupt or pre-slider
data, never against what the user actually picked. Anyone who already has 100m
or 150m stored keeps it until they open the new control themselves; there is no
migration nudge, matching how this app treats every other quiet default.

The displayed value uses `Measurement<UnitLength>.formatted()` rather than a
hand-built "75m" string — free locale-correct unit conversion (feet in a US
region) with no formatting code to keep in sync with the metres the geofence
itself is built in.

**`SmallFace`'s confirm area gets the same panel-card background `MediumFace`
already uses.** Reported as "action buttons on a widget are not clear."
Investigated by importing the Claude Design canvas project
(`Did I.dc.html` + `ios-frame.jsx` + `support.js`) and comparing every frame
against the shipped `Faces.swift`.

Most apparent design/code divergences turned out to be prior, deliberate
Precedence calls already logged here: `systemMedium`'s grid over the design's
row list, `accessoryCircular`'s glyph over the design's tick+name,
`accessoryRectangular`'s summary line over the design's three rows, and the
board footer's copy update for configurable reset rules. None of those needed
touching — they are docs beating design on structure, exactly as the
Precedence section prescribes; design is authoritative for palette/typography/
layout only. `support.js` is the generated dc-runtime bundle, not design
content — nothing to compare there.

The one real gap: `MediumFace` already solved "a tappable cell that's just
text on the background reads as inert" with a `Palette.panel` card (see its
own comment), but `SmallFace` — the family most people actually use, being the
one placeable directly on the home screen — never got the same treatment. A
`Button(intent:)` inside a widget carries no visible chrome of its own beyond
the system's momentary press highlight, so with nothing to distinguish it from
static text, the flap block read as decoration rather than the one-tap
control. Wrapped the confirm block in the same `Palette.panel` rounded card,
matching the established convention rather than inventing a new one.

`accessoryCircular`/`accessoryRectangular` (lock screen) were left alone: iOS
renders those tinted/monochrome, stripping any background color, which the
existing code comments already account for. `ConfirmControl` (Control Center)
needed nothing — a native `ControlWidgetToggle` is unambiguous on its own.

All eight `small-*` snapshot references re-recorded against the pinned iPhone
16 / iOS 18.6 simulator; `medium-*`, `circular`, `rectangular`, and `empty`
passed unchanged, confirming nothing else moved.

## `.onLeavingHome` → `.onComingHome`: reset trigger moved to arrival

**This overrides day-2-decay-and-location.md**, which specifies "clear your
confirmations when you leave home" verbatim (its LocationAsk pitch, the
resetRule menu label, and the "since I left" guarantee it promises) as a
deliberate design, not an oversight.

Found on a physical device: an item confirmed at home, with no departure at
all, flipped back to unconfirmed shortly after. Root cause was `CLRegion`
exit events firing on cell/Wi-Fi positioning drift rather than a real
crossing — `LocationMonitor.start()` re-registering the geofence on every
foreground made this worse (fixed separately, see git history), but the
underlying inaccuracy is a documented limit of `CLCircularRegion` monitoring,
not something more code can reliably eliminate. Exit-triggered reset put that
inaccuracy on the critical path for something the product explicitly
promises never to do without the user's action: silently un-confirm an item
they just closed.

Re-specified against actual use, direct from the person using the app: the
reset should fire when *returning* home, because being home again is what
makes the door/stove answerable to change again (it can be reopened, used,
etc.) — not on departure, which is exactly when a confirmation needs to
*survive* untouched. The separate "remind me if I leave with this
unconfirmed" notification (`Item.leavingHomeReminder`, `Notifications.swift`)
already covers the case the old exit-triggered reset was trying to backstop,
and needs no change: it is a departure-time check against whatever `state()`
already says, independent of which rule produced that state.

`ResetRule.onLeavingHome` → `.onComingHome`. `resolve()`'s `lastLeftHome:`
parameter → `lastEnteredHome:`, compared against `Store.lastEnteredHomeAt`
instead of `lastLeftHomeAt`. `Away.needingLeavingHomeReminder` no longer
needs to bypass `state(_:now:calendar:)` — the race it was dodging (the exit
handler resetting the very item being checked, in the same store access)
doesn't exist once exit stops touching this rule at all, so it now calls
`state()` directly. `LocationAsk` pitch copy, the resetRule menu label, and
`Copy.leavingExpiryUnavailable` (→ `comingHomeExpiryUnavailable`) rewritten
to match, with pl/ru translations added alongside (old leaving-home-worded
keys left in the `.strings` files rather than deleted — dead weight, but
harmless, and consistent with how this project treats every other superseded
key).

## E2E UX pass: truthful exits, progressive away help, scoped animation

Running the complete first-use and repeat-confirmation paths on iOS 18.6 found
three places where correct individual features combined into misleading or
annoying behavior.

**`Skip for now` is now a real exit.** The widget screen used to label its
secondary action `Later`, then immediately open a second sheet asking another
question. The reminder contract now lives inline as `Remind me once` plus the
weekday-morning detail; only that action asks notification permission.
`Skip for now` records the decline and ends onboarding in one tap. A prior OS
denial hides the unavailable reminder choice.

**Unknown rows disclose away help progressively when location is unknown.** A
declined or limited permission previously expanded every unknown item with two
large crisis actions while still claiming `Easy fix.` as though home were known.
The status is now the location-neutral `No current record.` and a single
`I'm away` button reveals the existing mute/share actions. A positively detected
away state still shows them immediately.

**Only flap glyphs animate during confirmation.** Animating the entire store or
practice state made SwiftUI cross-fade two complete board rows on top of each
other, duplicating the name and timestamp at the product's first-success moment.
Whole-row animation is removed; `FlapCell` retains its own scoped transition.

The practice footer no longer promises an overnight reset for the Iron and
Straightener presets, which use 12-hour rules. `Old confirmations expire
automatically` is true for every default. Coming-home copy was also completed
through the success state, Settings, and all localized iOS permission strings;
the separate leaving-home reminder keeps its departure wording.
