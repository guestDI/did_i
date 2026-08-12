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

**Typeface.** The design specifies IBM Plex Mono. It is not a system font on iOS and
is not bundled yet — SF Mono via `.system(design: .monospaced)` stands in. Bundling
Plex is a Phase 2 item; both are tabular, so no layout will move.

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
