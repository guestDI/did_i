# Day 2 — Decay, and earning location

**Goal:** explain why confirmations expire, and get location permission at the one moment it makes obvious sense.

**Success metric:** location granted, geofence reset enabled. Acceptable outcome: declined, app keeps working on timers.

**Why this is the most important day:** location permission is one-shot in iOS. A "don't allow" is nearly unrecoverable — it takes a trip to Settings that nobody makes. Asking on Day 0, before the user understands why a stove app wants their address, kills the geofence reset and the leaving-home nudge permanently. So we wait until the user has personally experienced the problem it solves, thirty seconds ago, with their own item.

---

## The trigger

Fires on the **first app or widget open where an item has aged out since the user last looked.** Not on a schedule, not on "day 2" literally. If they don't open the app for a week, this fires on the day they do.

Conditions:
1. At least one item is in `unknown` state after a reset.
2. The user has confirmed that item at least once (so they've seen it green).
3. `decayLessonShown == false`.

---

## The lesson

Shown as a sheet over the main screen, not a full-screen takeover. The item list stays visible behind it so they can see what's being talked about.

**Title**
> Your stove confirmation aged out at 4am

**Body**
> Old checkmarks lie. A green tick from yesterday tells you nothing about today, so we expire them overnight and start fresh.

**Footer, muted**
> Nothing went wrong. This is the app working.

**Button:** `Makes sense`

That last line matters. Waking up to an "unknown" state reads as failure — as though the app is telling you that you left the stove on. It isn't, and it can't know that. Say so.

Item name is interpolated. If several items aged out, use "Your confirmations aged out at 4am" and skip the name.

---

## The location ask

Immediately after `Makes sense`, second sheet:

**Title**
> Want it to reset when you actually leave?

**Body**
> Instead of a fixed time, we can clear your confirmations when you leave home — so a green tick always means "since I left". That needs your location, and it never leaves your phone.

**Buttons:** `Use my location` / `Keep the timer`

Only `Use my location` presents the iOS dialog. Request **`whenInUse` first**, then escalate to `always` later if the leaving-home nudge is ever enabled — asking for `always` cold is the fastest way to get denied.

### iOS purpose string (Info.plist)

`NSLocationWhenInUseUsageDescription`:
> Used to clear your confirmations when you leave home, so an old checkmark never fools you. Your location is never sent to a server.

### If granted

**Home location setup.** Don't ask them to type an address or drag a map pin — both are heavy and error-prone.

> **Where's home?**
> Tap "Set as home" while you're there. We'll remember the spot, not the address.
>
> `Set as home` · `I'm not home right now`

If "I'm not home right now": store a pending flag and offer setup again on the first app open at least 24 hours later. Settings remains available immediately. The cooldown avoids an immediate nag without adding continuous location tracking or a map picker to a one-tap app.

Geofence radius: 75m default (150m at launch, then 100m, then 75m — each cut chasing iOS's own hysteresis buffer, which adds distance on top of whatever radius is set). Smaller and you get spurious triggers from GPS drift indoors; larger and the leaving-home nudge fires too late to be useful. 75m is close to the practical floor for background region monitoring — going lower trades a small latency gain for a real rise in false exits.

**Confirmation sequence:** persist the captured coordinate first, then begin monitoring. Show `Home saved.` after the first permission level is granted. After the app has background location access, show:
> Home is set. Leaving home clears the board automatically.

If iOS does not grant background access, explain that automatic leaving-home resets are not active and keep timer resets working. Never claim the automation is enabled before the required permission exists.

### If declined

Never ask again. Not on day 5, not on a settings banner, not with a "you're missing out" card.

**Copy on decline:**
> No problem. We'll keep expiring things overnight instead.

Then show where the setting actually lives, once:
> On the board, open an item's More menu → "Edit item" → "How long a tick lasts".

That's it. The app is slightly dumber and entirely functional.

---

## Introducing the reset rule editor

Now — and only now — the per-item reset setting becomes discoverable. It lives
inside the item editor (More → "Edit item"), which is where someone looking to
change an item goes first, and pushes to its own screen from there:

**How long a tick lasts**

> When a tick stops counting

- When I leave home (24 hours at most) *(only offered when Always Location is active)*
- 4 hours after I confirm
- 12 hours after I confirm
- At 4am each day *(default)*
- Never (only when I confirm again) *(the warning "A tick that never expires is a tick you can't trust." sits on the row itself, not in the footer — a caution that only appears after the tap is not a caution)*

Each option is a self-contained phrase rather than a fragment completing the
header. Sentence-completion broke on two of the five in English ("…until when I
leave home", "…until until I confirm again") and breaks harder on case agreement
in pl/ru.

The footer says: "Applies to future confirmations. The status currently on the
board will not change." A rule change must never revive or shorten the current
confirmation. The rule is captured when the user confirms; the newly configured
rule starts with the next tap.

If an item already uses leaving-home expiry and Always Location later becomes
unavailable, keep the selected choice visible but disabled, explain why, and
offer the iOS Settings recovery route. Do not present an unavailable automation
as a working choice.

"How long until this expires?" is an unanswerable question about a thing you've owned for nine seconds. It's an easy question about something that already happened to you this morning. That's the whole reason it lives on Day 2.

---

## Tone rules that start applying now

From Day 2 onward the user will regularly encounter items in `unknown` state while away from home. This is the state where the app stops being funny.

| State | Location | Voice |
|---|---|---|
| Confirmed, fresh | anywhere | Maximum silliness. Full joke pool. |
| Confirmed, aging | anywhere | Mild. "Off, 6 hours ago." No jokes. |
| Unknown | at home | Light. "No record yet. Easy fix." |
| Unknown | away from home | **Plain, calm, factual. Zero jokes.** |

Away-from-home unknown copy:
> No record since you left. That's not the same as leaving it on.

Plus an escape hatch, always available in that state:
- `Can't check right now` — mutes the item until they're home again, and stops it appearing in the widget's summary count.
- `Ask someone at home` — opens a share sheet pre-filled: "Random question — is the stove off?"

Snark aimed at someone who is genuinely anxious and 3km from home is the fastest way to make this app feel cruel. The joke is a reward for being fine, never a comment on being uncertain.

---

## Edge cases

**User never leaves home** (works remotely, unwell, holiday). The geofence never fires and items reset on the 4am fallback. This must be the behaviour anyway — geofence reset *supplements* the timer, it doesn't replace it. Never leave an item in a state where nothing can ever expire it.

**User confirms items but never opens the app again.** The decay lesson never fires. That's fine — they're using the widget, which is the intended end state. Don't chase them with a notification to deliver a lesson.

**Multiple homes / travel.** Out of scope for v1. Document it as a known limitation. If the geofence is 400km away, disable geofence resets and fall back to timers silently rather than clearing everything on arrival in a new city.

**Location granted, then revoked in Settings.** Fall back to timers. Show a one-line note in Settings, not a banner on the main screen.

**They set home at the office by mistake.** Provide "Reset home location" in Settings. Don't try to detect it.

**Everything aged out and the list is entirely amber.** Show the lesson once, referring to items collectively. Don't stack sheets per item.
