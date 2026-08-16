# Did I? — orientation

iOS 17+, Swift, SwiftUI, WidgetKit. No backend, no account, no network calls.
One-tap confirmation app (stove/door/iron/etc): tap a widget, log "confirmed now."
Board decays from green → amber over time; nothing is ever red.

Read this file first. It's an index, not a summary — go to the linked doc for
the actual content instead of guessing from the one-liners below.

## Load-bearing decision

Display state is never stored, it's derived from `lastConfirmedAt` + `ResetRule` +
now. Nothing runs at 04:00; the widget shows amber because 04:00 arrived, not
because code executed. Everything else in the architecture follows from this.
Full reasoning: `architecture.md` §1.

## Where things live

- `DidICore/Sources/DidICore` — shared logic (state, store, copy/localization). Has its own test suite: `swift test` from `DidICore/`, NOT repo root.
- `DidI/` — app target
- `DidIWidget/` — widget extension target (own per-locale strings, separate from DidICore's)
- `Tests/Snapshots` — widget snapshot tests, pinned to iPhone 16 / iOS 18.6 / English
- `project.yml` — XcodeGen source of truth; no `.xcodeproj` is committed, run `xcodegen` to generate it
- `DidI.xcodeproj` — generated, gitignored-equivalent (don't hand-edit)

## Docs, in reading order for new work

1. `architecture.md` — system design, storage, App Group, timeline precomputation
2. `day-0-install.md`, `day-1-widget-nudge.md`, `day-2-decay-and-location.md`, `day-3-plus-repeat-use.md` — the product/UX spec, day-by-day onboarding and growth logic. These are the source of truth over the design project when they conflict (see decisions.md "Precedence").
3. `decisions.md` — running log of contradictions and calls made in passing. Long and chronological; grep it for a topic rather than reading start to end. Check it before assuming a behavior is undecided — it's probably already resolved here.

## Known standing gaps (as of last check)

- App Group `group.com.dihnatovich.didi` must be registered in the dev account + assigned to both targets; `DEVELOPMENT_TEAM` is unset in `project.yml`. Blocking prerequisite before any device testing.
- Overnight widget timeline behavior (04:00 transition) is unverified — can't be simulated, needs a real device soak.
- Lock screen widget has a plausible silent-failure mode: App Group file may be unreadable before first unlock (data protection), causing `StoreIO.mutate` to throw silently.
- Widget configuration sheet (item picker) reads from the extension's own bundle — untested in pl/ru.
- IBM Plex Mono not bundled; SF Mono stands in for flap cells (not visually final).
- Snapshot references need re-recording on any device/OS/locale change.

## Conventions

- Localization: `Copy.swift` is the single string catalog for the app/DidICore; the widget extension carries its own separate per-locale strings (AppIntents metadata extractor requirement). Never hardcode user-facing strings outside these.
- No red anywhere in the UI, ever — amber is the strongest color used.
