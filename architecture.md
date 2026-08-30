# Architecture — Did I?

iOS 17+, Swift, SwiftUI, WidgetKit. No backend, no account, no network calls.

---

## 1. The load-bearing decision

**Display state is never stored. It is derived.**

An item's state is a pure function:

```
state(item, now) -> .unknown | .confirmed(freshness)
```

computed from `lastConfirmedAt`, the rule captured when that confirmation was
made, and the current time. The item's configured `ResetRule` is the rule for its
next confirmation; changing settings never reinterprets evidence already on the
board. Nothing writes "this item is now amber". Nothing needs to run at 04:00.

This matters because iOS will not reliably execute your code at 04:00. If state were stored, every expiry would need a background task, and background tasks are best-effort — the app would routinely show a stale green tick, which is the one failure this product cannot have (see the trust argument in the UX docs: a green tick that lies is worse than no app).

With derived state, the widget shows amber at 04:00 because 04:00 arrived, not because anything executed.

**Corollary:** widget timelines are precomputed at confirmation time. The moment someone taps, every future boundary for that item is known, so you emit a timeline entry at each one and hand the schedule to WidgetKit. No refresh budget is consumed, because you never ask for a refresh.

Everything else in this document follows from that decision.

---

## 2. Processes and storage

Three execution contexts, one shared container:

| Context | Runs | Lifetime |
|---|---|---|
| `DidI` (app) | Settings, history, item management, geofence registration | Foreground, plus brief background wake on region exit |
| `DidIWidget` (extension) | Timeline provider, `AppIntent` execution | System-controlled, seconds at a time |
| System | Region monitoring, notification delivery | — |

They share nothing but the App Group container. Assume no shared memory, no shared singletons, no "the app is running" assumptions anywhere in the widget code path.

### App Group

`group.com.<you>.didi`

```swift
let root = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.<you>.didi"
)!
let storeURL = root.appending(path: "items.json")
```

### Why a JSON file and not SwiftData / Core Data

Six records, each a few hundred bytes, read in full on every access. A single `Codable` struct array written atomically is faster to build, trivially testable, easy to inspect during development, and has no store-migration story to maintain. SwiftData's App Group support works but buys nothing at this size and costs setup complexity in the extension.

Revisit only if shared households (v2) arrive, which introduces sync and therefore a real persistence layer.

### Write safety

Both the app and the widget extension can write. The realistic collision is: the app is open in the foreground while the user taps the widget button.

- Writes go through `NSFileCoordinator` with `.forReplacing`, and `Data.write(to:options: .atomic)`.
- After any write, post a Darwin notification (`CFNotificationCenterPostNotification` on `CFNotificationCenterGetDarwinNotifyCenter()`) so the other process can reload if it's alive.
- Conflict policy: last write wins. Two writes racing means two taps within milliseconds; either outcome is correct.

### Backup

Store lives in the group container root. It is included in iCloud device backup by default, which is the behaviour we want — reinstall on a new phone restores the list. There is no cloud sync and no account; a restore from backup is the only continuity mechanism, and that is a deliberate limitation.

---

## 3. Data model

```swift
struct Item: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String              // max 24 chars, widget-safe
    var symbol: String            // SF Symbol name
    var resetRule: ResetRule
    var lastConfirmedAt: Date?    // nil = never confirmed
    var lastConfirmationRule: ResetRule? // rule captured by the latest tap
    var createdAt: Date
    var archivedAt: Date?         // archive, never delete
    var order: Int
}

enum ResetRule: Codable, Sendable, Equatable {
    case dailyAt(hour: Int)       // default: 4
    case afterHours(Int)          // 4 or 12
    case onComingHome             // requires geofence
    case never                    // discouraged in UI
}

struct Store: Codable, Sendable {
    var items: [Item]
    var home: HomeLocation?
    var lastLeftHomeAt: Date?
    var lastEnteredHomeAt: Date?
    var flags: OnboardingFlags
    var checkCounts: [UUID: [Date]]   // for the paranoia counter, trimmed to 30 days
}
```

`confirmations` also carries aligned rule snapshots for Undo. Older store files
decode with no snapshots; the old configured rule is captured before the first
edit. This preserves the derived-state architecture while enforcing the trust
invariant: changing an expiry setting cannot turn an expired timestamp green.

`checkCounts` records widget/app *views* of an item, not confirmations — it feeds the weekly card and, more importantly, the escalating-checks guardrail in the Day 3+ doc. Trim aggressively; it is the only structure that grows.

---

## 4. State derivation

The whole of the app's logic worth unit-testing lives here, and it is pure.

```swift
enum ItemState: Equatable {
    case unknown
    case confirmed(age: TimeInterval, freshness: Freshness)
}

enum Freshness { case fresh, aging }   // aging = past 60% of the window

func resolve(_ item: Item, lastEnteredHome: Date?, now: Date) -> ItemState
```

Rules:

- No `lastConfirmedAt` → `.unknown`.
- `.dailyAt(h)` → unknown if the most recent occurrence of hour `h` is after `lastConfirmedAt`.
- `.afterHours(n)` → unknown if `now > lastConfirmedAt + n hours`.
- `.onComingHome` → unknown if `lastEnteredHomeAt > lastConfirmedAt`. **Always ORed with a 24h ceiling** so an item can never become permanently green if the user does not leave and return.
- `.never` → always confirmed. Exists because someone will want it; discouraged in copy.

`now` is injected everywhere. There is no call to `Date()` inside the resolver. This makes decay behaviour testable in milliseconds instead of overnight, which matters because overnight is the slowest possible feedback loop and this is the app's core mechanic.

### Boundary calculation

```swift
func boundaries(for item: Item, after: Date) -> [Date]
```

Returns the future instants at which `resolve` would change its answer — typically two: the fresh→aging transition and the aging→unknown transition. Used directly by the timeline provider. For `.onComingHome`, only the 24h ceiling is predictable; the geofence entry is handled by an explicit reload.

---

## 5. Widget

### Timeline generation

```swift
struct Provider: AppIntentTimelineProvider {
    func timeline(for config: Config, in context: Context) async -> Timeline<Entry> {
        let store = try? StoreIO.read()
        let now = Date()
        let dates = [now] + store.allBoundaries(after: now).prefix(20).sorted()
        let entries = dates.map { Entry(date: $0, store: store, renderedAt: $0) }
        return Timeline(entries: entries, policy: .after(dates.last ?? now.addingHours(24)))
    }
}
```

Each entry renders the state *as of its own date*, using the same `resolve` function the app uses. Same input, same code, same answer in both places — this is the point of deriving rather than storing.

Cap entries at 20 and 24 hours out. Beyond that the reload policy picks up the rest.

### Families

| Family | Content |
|---|---|
| `systemSmall` | One item, chosen via widget configuration. Icon, name, state, relative time. |
| `systemMedium` | Up to four items in a 2×2 grid. |
| `accessoryCircular` | One item: symbol + hours-since. |
| `accessoryRectangular` | Summary: "3 of 4 handled". |

Lock screen families matter more than they look — the Day 2 UX doc requires that "did I?" be answerable without unlocking the phone.

### The tap

```swift
struct ConfirmItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Confirm"
    @Parameter(title: "Item") var itemID: String

    func perform() async throws -> some IntentResult {
        try StoreIO.mutate { store in
            store.confirm(id: UUID(uuidString: itemID)!, at: .now)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "DidIWidget")
        return .result()
    }
}
```

Used as `Button(intent: ConfirmItemIntent(itemID: item.id.uuidString))`. iOS 17+.

Constraints to respect:
- `perform()` runs out-of-process on a tight budget. Read, mutate, write, reload, return. No network, no analytics, no animation work.
- It cannot assume the app is running or has ever run in this session.
- **It cannot fire a custom haptic.** The widget button gets the system's own press feedback. If the "satisfying thunk" turns out to be load-bearing for the product feel, that is a finding to make in week one, not week six — see §9.

Long-press to undo is not available inside a widget button; undo lives in the app, and the widget's confirmation is reversible only by opening the app. Acceptable, and worth confirming against the Day 0 copy which currently promises "hold to undo" on the practice screen (that promise is about the in-app card, so it stands).

---

## 6. Location and background

### Authorization — correction to the Day 2 flow

Background region monitoring requires **`.authorizedAlways`**. `.authorizedWhenInUse` will not deliver entry or exit events while the app is backgrounded or terminated, which is exactly when they matter.

So the escalation described in the Day 2 doc is not optional politeness — it is required for the feature to function:

1. Request `.authorizedWhenInUse` at the "Use my location" tap. Used immediately to capture the home coordinate.
2. Once home is set, request `.authorizedAlways` with a one-line explanation of what it buys ("so we can clear the board when you're back, even with the app closed").
3. If the user grants only when-in-use, the geofence reset silently degrades to
   the 24h ceiling and the leaving-home nudge is unavailable. Do not offer
   "When I come home" as a new expiry choice until Always access is active. If
   an existing item still carries that choice, show it disabled with the recovery
   route to iOS Settings. Do not badger. Do not show a warning banner.

`NSLocationAlwaysAndWhenInUseUsageDescription` must be present alongside the when-in-use string.

### Region monitoring

One `CLCircularRegion`, 75m radius, `notifyOnExit = true`, `notifyOnEntry = true`. Allowance is 20 regions; we use one.

Entry events record `lastEnteredHomeAt`, which expires `.onComingHome`
confirmations and clears the "can't check right now" mute state described in
the Day 2 tone rules. Exit events record `lastLeftHomeAt` and schedule only the
separate, opt-in leaving-home reminders; departure does not clear a confirmation.

### Background wake

A region exit relaunches a terminated app with `UIApplication.LaunchOptionsKey.location`. The `CLLocationManager` and its delegate must be constructed **synchronously during launch**, before any `await`, or the event is dropped. In SwiftUI this means an `@UIApplicationDelegateAdaptor`, not a `.task` modifier.

Work permitted in an exit wake (a few seconds, no guarantees):

1. Set `store.lastLeftHomeAt = .now`.
2. `WidgetCenter.shared.reloadAllTimelines()`.
3. If any item is unconfirmed and its per-item nudge is enabled, schedule a `UNTimeIntervalNotificationTrigger` a few seconds out.

Nothing else. No cleanup, no trimming, no counters.

An entry wake performs the corresponding minimal path: set
`store.lastEnteredHomeAt = .now`, clear home-bound mutes, and reload widget
timelines. It schedules no notification.

### Notifications

`UNUserNotificationCenter` only. Two categories exist in the entire app:

- The one-shot widget nudge (Day 1 doc) — calendar trigger, fires once, ever.
- The leaving-home reminder — opt-in per item, scheduled from the region-exit wake.

No badge count, ever. A permanent number on the home screen is an anxiety generator and this app has a specific obligation not to be one.

---

## 7. Module layout

```
DidICore/          Swift package, no UIKit, no WidgetKit
  Item.swift
  ResetRule.swift
  StateResolver.swift        <- pure, fully tested
  Boundaries.swift           <- pure, fully tested
  StoreIO.swift              <- coordinated read/write
  Copy.swift                 <- confirmation lines, notification variants
DidI/              app target
DidIWidget/        widget extension target
DidICoreTests/
```

`DidICore` is a package rather than a framework so the widget extension links it without embedding overhead, and so the resolver can be tested on macOS in a fast loop.

`Copy.swift` holding all user-facing strings is not premature abstraction here — the copy pool is a designed artefact (see the Day 0 doc) with rules about rotation and escalation, and it needs to be identical in both processes.

---

## 8. Testing

Because the resolver is pure and `now` is injected, the entire decay mechanic is testable without waiting:

- An item confirmed at 23:00 with `.dailyAt(4)` is unknown at 04:00:01 and confirmed at 03:59:59.
- An item confirmed at 05:00 with `.dailyAt(4)` survives until the *next* 04:00, not the one that already passed.
- `.onComingHome` never stays green past 24h even with no entry event.
- DST transitions: a `.dailyAt(4)` boundary on the spring-forward night must still resolve exactly once. Use `Calendar.nextDate(after:matching:)`, never arithmetic on 86400.
- Timezone change mid-window (user flies): boundaries recompute against the current calendar; an item may expire early or late by hours. Acceptable; document it.

Snapshot-test the widget views at each state and each family, in both colour schemes. The widget is the product; a layout break there is a total failure, and it is the surface you will look at least often during development.

---

## 9. What to validate before building any of this

The architecture above is low-risk. The product risk sits somewhere else entirely, and it is worth an afternoon before writing the rest:

**Vertical slice:** one hardcoded item, one `systemSmall` widget with a working `ConfirmItemIntent`, `.dailyAt(4)` reset, real App Group store. Tap it. Leave it overnight. Check it turns amber on its own.

Three things you learn that no amount of planning tells you:

1. How the widget tap actually feels without a custom haptic.
2. Whether the timeline entry at the boundary renders when you expect, or lags.
3. Whether the round trip from tap to visible green is fast enough that the button feels like a switch rather than a form submission.

If any of those disappoint, the fix is a design change, not a code change — and you want to know before the copy deck is written.

---

## 10. Decisions log

| Decision | Rejected alternative | Why |
|---|---|---|
| Derived state | Stored state flags | Requires reliable background execution, which iOS does not offer |
| Precomputed timelines | On-demand refresh | Refresh budget is finite and the boundaries are already known |
| JSON in App Group | SwiftData / Core Data | Six records; migration and extension setup cost buys nothing |
| No account, no sync | CloudKit | Removes an entire subsystem; backup covers device replacement |
| Region monitoring | `BGAppRefreshTask` at 04:00 | Best-effort scheduling is unacceptable for the core mechanic |
| Archive | Delete | Deleting a user's data on our own initiative is not our call |
| iOS 17 minimum | iOS 16 with tap-to-open | Interactive widgets are the product; without them there is no one-touch app |

---

## 11. Known limitations, documented not fixed

- **One home.** A second residence or long travel breaks geofence resets; falls back to timers.
- **No shared household.** Two people and one stove needs shared state and attribution. v2.
- **No custom haptic in-widget.** System feedback only.
- **No cross-device sync.** iPad and iPhone hold independent lists.
- **Timezone travel** can shift a `.dailyAt` boundary by hours.

---

## 12. v2 candidates, in rough order of value

1. **NFC stickers.** The strongest available answer to "can this record be trusted" — a tap that can only physically happen at the appliance. Reads natively via Core NFC, or via a Shortcuts automation with no app open at all.
2. **Apple Watch complication.** Arguably a better home for the glance than the phone.
3. **Shared household.** High value, high complexity; the first feature that forces a real backend.
4. **Live Activity** on leaving home, showing unconfirmed items in the Dynamic Island for the first 30 minutes — the window in which turning back is still cheap.
