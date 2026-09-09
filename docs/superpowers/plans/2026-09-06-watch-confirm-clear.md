# Watch confirm/clear Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the Watch board confirm or clear an item by round-tripping the action through the phone, instead of being read-only.

**Architecture:** The watch never mutates state itself (no App Group access). A row tap/swipe sends a `WCSession` message to the phone; `WatchSync` (already the phone's `WCSessionDelegate`) decodes it, applies it via the existing `StoreIO.mutate` file-coordinated write, and replies with the freshly-written store. The watch applies exactly that returned data — never a locally-invented state. The existing one-way `StoreIO.write` → Darwin notification → `StoreChange` → `WatchSync.push()` broadcast is untouched and still fires as a side effect of the mutation.

**Tech Stack:** Swift, SwiftUI, WatchConnectivity, Swift Testing (`DidICore`'s existing `swift test` suite).

**Spec:** `docs/superpowers/specs/2026-09-06-watch-confirm-clear-design.md`

## Global Constraints

- The watch must never show a confirmed/cleared state that the phone didn't actually write — no optimistic local state (spec, "Out of scope").
- All real writes go through `StoreIO.mutate` on the phone process — no new write path (spec, "Constraints").
- Reuse `Copy.swift` (DidICore) for any new user-facing string — it's the single string catalog the app, widget, and watch all already share (`CLAUDE.md` "Conventions"; `WatchBoardView.swift` already calls `Copy.status`/`Copy.addAnItem`).

---

### Task 1: Pure action decode/apply logic in DidICore

**Files:**
- Create: `DidICore/Sources/DidICore/WatchAction.swift`
- Test: `DidICore/Tests/DidICoreTests/WatchActionTests.swift`

**Interfaces:**
- Produces: `public enum WatchAction: Equatable, Sendable { case confirm(id: UUID); case clear(id: UUID) }`, `public enum WatchActionDecoding { public static func decode(_ message: [String: Any]) -> WatchAction?; public static func apply(_ action: WatchAction, to store: inout Store, at date: Date) }`

- [ ] **Step 1: Write the failing tests**

Create `DidICore/Tests/DidICoreTests/WatchActionTests.swift`:

```swift
import Testing
import Foundation
@testable import DidICore

@Test func decodesAConfirmMessage() {
    let id = UUID()
    let action = WatchActionDecoding.decode(["action": "confirm", "id": id.uuidString])
    #expect(action == .confirm(id: id))
}

@Test func decodesAClearMessage() {
    let id = UUID()
    let action = WatchActionDecoding.decode(["action": "clear", "id": id.uuidString])
    #expect(action == .clear(id: id))
}

@Test func decodingRejectsAnUnknownAction() {
    let action = WatchActionDecoding.decode(["action": "delete", "id": UUID().uuidString])
    #expect(action == nil)
}

@Test func decodingRejectsAMissingID() {
    let action = WatchActionDecoding.decode(["action": "confirm"])
    #expect(action == nil)
}

@Test func decodingRejectsAMalformedID() {
    let action = WatchActionDecoding.decode(["action": "confirm", "id": "not-a-uuid"])
    #expect(action == nil)
}

@Test func applyingConfirmStampsTheItem() {
    var s = Store(items: [item()])
    let id = s.items[0].id
    WatchActionDecoding.apply(.confirm(id: id), to: &s, at: at("2026-08-11 08:42:00"))
    #expect(s.items[0].lastConfirmedAt == at("2026-08-11 08:42:00"))
}

@Test func applyingClearRemovesTheConfirmation() {
    var s = Store(items: [item()])
    let id = s.items[0].id
    s.confirm(id: id, at: at("2026-08-11 08:00:00"), calendar: utc)
    WatchActionDecoding.apply(.clear(id: id), to: &s, at: at("2026-08-11 09:00:00"))
    #expect(s.items[0].lastConfirmedAt == nil)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd DidICore && swift test --filter WatchActionTests`
Expected: FAIL — `WatchAction`/`WatchActionDecoding` do not exist yet.

- [ ] **Step 3: Write the implementation**

Create `DidICore/Sources/DidICore/WatchAction.swift`:

```swift
import Foundation

/// A watch-initiated action, decoded from a `WCSession` message dictionary.
/// The watch has no App Group access, so it never mutates `Store` itself —
/// it sends one of these to the phone, which applies it via `StoreIO.mutate`
/// and replies with the result. See `WatchSync.session(_:didReceiveMessage:replyHandler:)`.
public enum WatchAction: Equatable, Sendable {
    case confirm(id: UUID)
    case clear(id: UUID)
}

public enum WatchActionDecoding {
    /// `nil` for anything malformed — an unknown action, a missing or
    /// non-UUID id. The caller replies with failure rather than guessing.
    public static func decode(_ message: [String: Any]) -> WatchAction? {
        guard let action = message["action"] as? String,
              let idString = message["id"] as? String,
              let id = UUID(uuidString: idString)
        else { return nil }
        switch action {
        case "confirm": return .confirm(id: id)
        case "clear": return .clear(id: id)
        default: return nil
        }
    }

    public static func apply(_ action: WatchAction, to store: inout Store, at date: Date) {
        switch action {
        case .confirm(let id): store.confirm(id: id, at: date)
        case .clear(let id): store.clearCurrentStatus(id: id)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd DidICore && swift test --filter WatchActionTests`
Expected: PASS, all 7 tests.

- [ ] **Step 5: Run the full DidICore suite to check nothing else broke**

Run: `cd DidICore && swift test`
Expected: PASS, 185 tests (178 existing + 7 new).

- [ ] **Step 6: Commit**

```bash
git add DidICore/Sources/DidICore/WatchAction.swift DidICore/Tests/DidICoreTests/WatchActionTests.swift
git commit -m "Add pure watch-action decode/apply logic to DidICore"
```

---

### Task 2: "Unreachable" copy string

**Files:**
- Modify: `DidICore/Sources/DidICore/Copy.swift`

**Interfaces:**
- Produces: `public static let watchUnreachable: String`

- [ ] **Step 1: Add the string**

In `Copy.swift`, near the other short standalone strings (e.g. next to `clearStatus` at line 327), add:

```swift
public static let watchUnreachable = t("Couldn't reach iPhone — try again nearby.")
```

- [ ] **Step 2: Run the DidICore suite**

Run: `cd DidICore && swift test`
Expected: PASS — this is a new string, nothing references it yet, so nothing can break.

- [ ] **Step 3: Commit**

```bash
git add DidICore/Sources/DidICore/Copy.swift
git commit -m "Add watchUnreachable copy string"
```

---

### Task 3: Phone-side message handling in WatchSync

**Files:**
- Modify: `DidI/WatchSync.swift`

**Interfaces:**
- Consumes: `WatchActionDecoding.decode(_:) -> WatchAction?`, `WatchActionDecoding.apply(_:to:at:)`, `StoreIO.mutate<T>(_:) throws -> T`, `StoreIO.encoded(_:) throws -> Data`, `WidgetCenter.shared.reloadAllTimelines()`
- Produces: `WatchSync` now replies to watch messages with `["ok": Bool, "store": Data?]`

- [ ] **Step 1: Add the import**

At the top of `DidI/WatchSync.swift`, add:

```swift
import WidgetKit
```

(alongside the existing `Foundation`, `WatchConnectivity`, `DidICore` imports)

- [ ] **Step 2: Add the delegate method**

In `DidI/WatchSync.swift`, inside the `extension WatchSync: WCSessionDelegate` block (after `sessionDidDeactivate`), add:

```swift
    /// The watch has no App Group access, so every confirm/clear it makes
    /// arrives here to actually apply. Runs through the same `StoreIO.mutate`
    /// the app and widget already share — this is just one more caller of
    /// it, on the phone process, so no new race is introduced.
    ///
    /// Stays fully `nonisolated` rather than hopping to `@MainActor`:
    /// `StoreIO` and `WidgetCenter` need no actor, and under Swift 6 strict
    /// concurrency, capturing the task-isolated `replyHandler` into a
    /// `Task { @MainActor in }` closure is flagged as a data race — calling
    /// it directly, synchronously, in this method's own isolation avoids
    /// that entirely.
    nonisolated func session(
        _ session: WCSession, didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let action = WatchActionDecoding.decode(message) else {
            replyHandler(["ok": false])
            return
        }
        guard let store = try? StoreIO.mutate({ store -> Store in
            WatchActionDecoding.apply(action, to: &store, at: .now)
            return store
        }) else {
            replyHandler(["ok": false])
            return
        }
        WidgetCenter.shared.reloadAllTimelines()
        guard let data = try? StoreIO.encoded(store) else {
            replyHandler(["ok": false])
            return
        }
        replyHandler(["ok": true, "store": data])
    }
```

- [ ] **Step 3: Build the DidI app target**

Run: `cd /Users/dihnatovich/Documents/projects/possible-to-prod/one-tap-confirm && xcodebuild -project DidI.xcodeproj -scheme DidI -destination "id=7112ACAC-221B-4851-A916-CC9AFAE47662" build`
Expected: `** BUILD SUCCEEDED **`. If the destination UDID is stale, run `xcrun simctl list devices available | grep "iPhone 16 "` and use a current one.

- [ ] **Step 4: Commit**

```bash
git add DidI/WatchSync.swift
git commit -m "Handle watch confirm/clear messages on the phone"
```

---

### Task 4: Watch-side confirm/clear on WatchStore

**Files:**
- Modify: `DidIWatch/WatchStore.swift`

**Interfaces:**
- Consumes: `WCSession.default.sendMessage(_:replyHandler:errorHandler:)`, `Copy.watchUnreachable`
- Produces: `WatchStore.confirm(id: UUID)`, `WatchStore.clear(id: UUID)`, `WatchStore.lastError: String?` (read-only outside the class)

- [ ] **Step 1: Add the new state and methods**

In `DidIWatch/WatchStore.swift`, add `private(set) var lastError: String?` next to the existing `private(set) var store = Store()`, and add these methods after `start()` (before the `#if DEBUG` block):

```swift
    func confirm(id: UUID) {
        send(["action": "confirm", "id": id.uuidString])
    }

    func clear(id: UUID) {
        send(["action": "clear", "id": id.uuidString])
    }

    /// Every action round-trips through the phone — the watch has no App
    /// Group access and never guesses at the result. A failure (unreachable
    /// phone, or the phone's own write failing) surfaces as `lastError`
    /// rather than a state that silently doesn't change.
    private func send(_ message: [String: Any]) {
        guard WCSession.default.activationState == .activated else {
            lastError = Copy.watchUnreachable
            return
        }
        WCSession.default.sendMessage(message, replyHandler: { [weak self] reply in
            Task { @MainActor in
                guard let self else { return }
                if reply["ok"] as? Bool == true, let data = reply["store"] as? Data {
                    self.apply(data)
                    self.lastError = nil
                } else {
                    self.lastError = Copy.watchUnreachable
                }
            }
        }, errorHandler: { [weak self] _ in
            Task { @MainActor in self?.lastError = Copy.watchUnreachable }
        })
    }
```

- [ ] **Step 2: Build the Watch target**

Run: `cd /Users/dihnatovich/Documents/projects/possible-to-prod/one-tap-confirm && xcrun simctl list devices available | grep -i "watch"` to find a paired Watch simulator UDID, then:
`xcodebuild -project DidI.xcodeproj -scheme "DidI Watch App" -destination "id=<watch-simulator-udid>" build`
Expected: `** BUILD SUCCEEDED **`. If there is no separate Watch scheme name, run `xcodebuild -project DidI.xcodeproj -list` first to confirm the exact scheme name and use that.

- [ ] **Step 3: Commit**

```bash
git add DidIWatch/WatchStore.swift
git commit -m "Add confirm/clear message sending to WatchStore"
```

---

### Task 5: Watch board UI — tap to confirm, swipe to clear

**Files:**
- Modify: `DidIWatch/WatchBoardView.swift`

**Interfaces:**
- Consumes: `WatchStore.confirm(id:)`, `WatchStore.clear(id:)`, `WatchStore.lastError`, `Copy.clearStatus`

- [ ] **Step 1: Update the row and list to wire the new actions**

Replace the `row(_:now:)` function and the `List` in `body` in `DidIWatch/WatchBoardView.swift`:

```swift
struct WatchBoardView: View {
    var watchStore = WatchStore.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            List(watchStore.store.active) { item in
                row(item, now: context.date)
                    .swipeActions {
                        if item.lastConfirmedAt != nil {
                            Button(Copy.clearStatus) {
                                watchStore.clear(id: item.id)
                            }
                        }
                    }
            }
        }
        .navigationTitle("Did I?")
        .overlay {
            if watchStore.store.active.isEmpty {
                Text(Copy.addAnItem)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { WatchStore.shared.start() }
        .alert(
            watchStore.lastError ?? "", isPresented: Binding(
                get: { watchStore.lastError != nil },
                set: { if !$0 { watchStore.clearError() } }
            )
        ) {
            Button(Copy.ok) { watchStore.clearError() }
        }
    }

    private func row(_ item: Item, now: Date) -> some View {
        let state = watchStore.store.state(item, now: now)
        return HStack {
            Image(systemName: item.symbol)
                .foregroundStyle(Palette.color(for: state))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                Text(Copy.status(for: state, item: item))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(.rect)
        .onTapGesture { watchStore.confirm(id: item.id) }
    }
}
```

- [ ] **Step 2: Add the missing `clearError()` to WatchStore**

The alert binding above needs a way to dismiss the error. In `DidIWatch/WatchStore.swift`, add this method next to `confirm(id:)`/`clear(id:)`:

```swift
    func clearError() {
        lastError = nil
    }
```

- [ ] **Step 3: Confirm `Copy.ok` exists**

Run: `grep -n "static let ok " DidICore/Sources/DidICore/Copy.swift`
Expected: one match (`public static let ok = t("OK")` or similar). It is already used elsewhere in the app (`ConfirmationExpiryView.swift`'s `Button(Copy.ok)`), so no new string is needed here.

- [ ] **Step 4: Build the Watch target**

Run: `xcodebuild -project DidI.xcodeproj -scheme "DidI Watch App" -destination "id=<watch-simulator-udid>" build` (same destination as Task 4, Step 2)
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add DidIWatch/WatchBoardView.swift DidIWatch/WatchStore.swift
git commit -m "Wire tap-to-confirm and swipe-to-clear on the Watch board"
```

---

### Task 6: Full verification pass

**Files:** none (verification only)

- [ ] **Step 1: Run the full DidICore test suite**

Run: `cd DidICore && swift test`
Expected: PASS, 185 tests.

- [ ] **Step 2: Regenerate the Xcode project and build every target**

Run:
```bash
cd /Users/dihnatovich/Documents/projects/possible-to-prod/one-tap-confirm
xcodegen
xcodebuild -project DidI.xcodeproj -scheme DidI -destination "id=7112ACAC-221B-4851-A916-CC9AFAE47662" build
```
Expected: `** BUILD SUCCEEDED **` (this scheme embeds the widget and Watch app extensions, so a successful build here compiles all four targets together).

- [ ] **Step 3: Manual two-device soak (cannot be automated)**

Install the updated build on a physical iPhone paired with an Apple Watch (per `CLAUDE.md`'s existing device-testing pattern). Verify:
- Tapping an item on the Watch confirms it, and the phone's board (and widget) reflect it within the existing sync latency.
- Confirming on the phone updates the Watch board without touching the Watch.
- Swiping an already-confirmed item on the Watch and tapping "Clear current confirmation" clears it on both devices.
- Force-quitting the phone app, then tapping an item on the Watch, shows the "Couldn't reach iPhone — try again nearby." alert and the Watch row does not change state.

- [ ] **Step 4: Update CLAUDE.md's known standing gaps if the manual soak reveals anything new**

If Step 3 surfaces a real issue (e.g. reply latency worse than expected, an edge case in reachability), add one line to `CLAUDE.md`'s "Known standing gaps" section describing it, following the existing style of that section. If the soak is clean, skip this step — do not add a gaps entry for something that works.
