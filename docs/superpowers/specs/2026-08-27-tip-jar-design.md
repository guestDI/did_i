# Optional tip jar — design

## Purpose

Let a user who wants to support the app send a small one-time payment,
without turning the app into a monetized product. No ads, no subscription,
no feature gating — the tip buys nothing but a thank-you.

## Constraints

- App is "no backend, no account, no network calls" by design
  (`CLAUDE.md`). StoreKit purchases go through Apple directly, so this
  holds — no server of ours is involved.
- iOS 17+ minimum, so StoreKit 2's async/await API is fully available.
  No reason to touch the legacy `SKPaymentQueue` API.
- Widget and watch targets have no purchase surface; this is app-only.

## Product

One consumable in-app purchase:

- Product ID: `com.dihnatovich.didi.tip.small`
- Price: $2.99 (App Store tier, localized automatically per region by
  StoreKit)
- Type: Consumable, repeatable — buyable any number of times
- Configured in App Store Connect (external, requires dev account access)
  and mirrored in a local `.storekit` configuration file so it's testable
  in the simulator without hitting App Store Connect.

## Code shape

`DidI/TipJar.swift` — app target only, not `DidICore` (no shared/widget/watch
use).

```swift
@Observable
final class TipJar {
    private(set) var product: Product?

    func loadProduct() async
    func purchase() async throws -> Bool   // true = success, false = user cancelled
}
```

- `loadProduct()` fetches the one `Product` via
  `Product.products(for: ["com.dihnatovich.didi.tip.small"])`, storing it
  so the UI can show StoreKit's own localized price string rather than a
  hardcoded "$2.99".
- `purchase()` calls `product.purchase()`, verifies the resulting
  transaction via `VerificationResult`, and calls `transaction.finish()`
  on success. `finish()` is required, not optional — an unfinished
  transaction is redelivered by StoreKit on every future launch.
- A `Transaction.updates` listener is started once at app launch (from
  `DidIApp.init`, alongside `StoreChange.startListening()` and
  `WatchSync.shared.start()`) to catch and finish any transaction left
  unfinished by an interrupted purchase (app killed mid-flow, etc). This
  is the same StoreKit correctness requirement as `finish()` above, not
  additional scope.
- No entitlement tracking, no receipt storage, nothing written to the App
  Group `Store`. A tip changes nothing about app state or behavior.

## UI

New "Support" section in `SettingsView`, below existing sections:

- One row: "Buy me a coffee — {localized price}" (price pulled from
  `TipJar.product`, hidden/disabled if the product hasn't loaded yet).
- Tapping it calls `TipJar.purchase()`.
  - Success (`true`) → brief "Thanks!" alert.
  - Cancelled (`false`) → no-op, no alert.
  - Any thrown error → plain error alert ("Something went wrong, try again
    later" style copy, added to `Copy.swift` per existing convention).

## Testing

- No `DidICore` unit tests — this is a thin wrapper around StoreKit's own
  async calls with no business logic of its own to unit test.
- Manual/demo verification via the `.storekit` configuration file in the
  Xcode scheme: purchase success, user-cancel, and simulated failure
  paths, run in the simulator.

## Out of scope

- Multiple tip tiers/amounts.
- Persisting or displaying "you've tipped before" state.
- Restoring purchases (nothing to restore — it's consumable and grants no
  entitlement).
