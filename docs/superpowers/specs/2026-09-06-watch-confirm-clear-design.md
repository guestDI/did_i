# Watch confirm/clear — design

## Purpose

Let a user act on an item directly from the Watch board instead of only
glancing at it. Today `DidIWatch` is deliberately read-only (see
`WatchBoardView.swift`'s "no confirm, no undo, no settings" comment and
`day-3-plus-repeat-use.md`'s "the glance is even cheaper" note) — this
reverses that decision because a real user report showed the glance-only
model leaves a gap: seeing a stove is unconfirmed on your wrist and still
having to pull out the phone defeats a chunk of the Watch's value.

## Constraints

- The Watch has no App Group access (`WatchStore.swift`: "No file, no App
  Group") — it cannot mutate the shared store itself. Every action has to
  round-trip through the phone.
- `WCSession.sendMessage` requires the phone's session to be reachable
  (its app running, foreground or background). There is no queuing for
  when it isn't — this is a live action, not a background sync task, and
  the app's own rule is that displayed state must never lie about what
  actually happened.
- All real writes must still go through `StoreIO.mutate`'s existing
  `NSFileCoordinator`-based read-modify-write — this is what already
  keeps the app and widget extension race-safe on the same device, and
  the watch-triggered write is just one more caller of it, executed on
  the phone process like any other.

## Data flow

1. **Watch → phone.** A row tap sends
   `WCSession.default.sendMessage(["action": "confirm", "id": item.id.uuidString], replyHandler:, errorHandler:)`.
   A swipe-to-clear action sends `"action": "clear"` the same way.
2. **Phone applies it.** `WatchSync` (already the phone's
   `WCSessionDelegate`) gains
   `session(_:didReceiveMessage:replyHandler:)`. It decodes the action and
   id, then:
   - `"confirm"` → `try StoreIO.mutate { $0.confirm(id: id, at: .now) }`
   - `"clear"` → `try StoreIO.mutate { $0.clearCurrentStatus(id: id) }`
   - `WidgetCenter.shared.reloadAllTimelines()` afterward, matching every
     other mutation call site.
   - Replies with `["ok": true, "store": <encoded Store>]` on success, or
     `["ok": false]` if the mutate threw. No case fabricates success.
3. **Phone → watch (existing plumbing, untouched).**
   `StoreIO.write` already posts a Darwin notification that
   `StoreChange` bridges to `WatchSync.push()`, which re-broadcasts the
   full store to the watch via `updateApplicationContext`. This already
   fires for the mutation above with no new code — it is the same path a
   phone-side confirm already takes. The reply's embedded store is purely
   a latency shortcut so the watch doesn't wait for that second hop.
4. **Watch applies the result.** `WatchStore` gains `confirm(id:)` and
   `clear(id:)`, each wrapping the message send:
   - Success reply → decode the returned store, assign it to
     `WatchStore.store` directly (the same real data the phone just
     wrote, not a local guess).
   - Failure reply, or `errorHandler` (unreachable) → set an observable
     `lastError: String?` (e.g. "Couldn't reach iPhone — try again
     nearby."); the row's state does not change.

## UI (`WatchBoardView.swift`)

- `.onTapGesture` on a row → `watchStore.confirm(id: item.id)`. Always
  fires regardless of current state, matching the phone's `BoardRow`
  (a reconfirm is harmless — it just re-stamps "confirmed now").
- `.swipeActions` on a row, offering "Clear" (`Copy.clearStatus`), shown
  only when `item.lastConfirmedAt != nil` — the same condition the phone
  uses to decide whether `onClear` exists at all.
- `.alert` bound to `watchStore.lastError`, dismissing it on tap.

## Testing

- The action-dispatch logic — decode `["action", "id"]` into "call
  `confirm` or `clearCurrentStatus` on the store" — is pulled into a
  small pure function in `DidICore` (mirroring this session's
  `Geofence`/`LeavingHomeReminders` extractions) and unit-tested there:
  unknown action, missing id, and the two valid actions each routing to
  the right `Store` mutation.
- The actual `WCSession` round-trip (message send, reachability,
  reply/error handling) is not unit-testable — verified by a manual
  two-device (or Watch Simulator + iOS Simulator paired) soak: confirm
  and clear from the watch, confirm from the phone while watch is
  foregrounded, and a deliberately-unreachable case (phone app killed)
  to confirm the error path shows and no state silently flips.

## Out of scope

- Any change to the existing one-way phone-to-watch broadcast —
  `WatchSync.push()` is untouched.
- Complications or background Watch launch — this only covers the
  Watch app's own foreground board view.
- Optimistic local state on the watch ahead of the phone's reply — ruled
  out explicitly; the display must reflect what actually got written, not
  a guess.
