# Did I? — orientation

iOS 17+, Swift, SwiftUI, WidgetKit. No backend, no account, no network calls.
One-tap confirmation app (stove/door/iron/etc): tap a widget, log "confirmed now."
Board decays from green → amber over time; nothing is ever red.

Read this file first. It's an index, not a summary — go to the linked doc for
the actual content instead of guessing from the one-liners below.

## Load-bearing decision

Display state is never stored, it's derived from `lastConfirmedAt` + the rule
captured with that confirmation + now. Nothing runs at 04:00; the widget shows amber because 04:00 arrived, not
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

- `DEVELOPMENT_TEAM` is set (`3VRYJ7457W`) in `project.yml`, but App Group `group.com.dihnatovich.didi` registration in the dev account itself (assigned to the DidI, DidIWidget, and DidIWatch targets) is still unverified. Blocking prerequisite before any device testing or archiving.
- Overnight widget timeline behavior (04:00 transition) confirmed working on a real device soak.
- Lock screen widget's App Group file may be unreadable before first unlock (data protection). `ConfirmItemIntent`/`SetConfirmedIntent` use `try StoreIO.mutate` (not `try?`), so a throw propagates to the AppIntent system rather than failing silently — but the on-device behavior before first unlock is still unverified.
- Widget configuration sheet (item picker) reads from the extension's own bundle; pl/ru string files exist (`DidIWidget/{pl,ru}.lproj`) but the picker UI itself is untested in those locales.
- IBM Plex Mono not bundled; SF Mono stands in for flap cells (not visually final).
- Snapshot references need re-recording on any device/OS/locale change.

## Conventions

- Localization: `Copy.swift` is the single string catalog for the app/DidICore; the widget extension carries its own separate per-locale strings (AppIntents metadata extractor requirement). Never hardcode user-facing strings outside these.
- No red anywhere in the UI, ever — amber is the strongest color used.
