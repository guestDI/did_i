# Day 0 — Install

**Goal:** get one item created, one real confirmation logged, and the widget question asked — in under 30 seconds.

**Success metric:** user reaches the main screen with one green item. Secondary: widget installed.

**Not a goal:** explaining the app, collecting permissions, showing off features.

---

## Voice reminder

Humour scales with confidence. Onboarding is the safest place in the entire product to be funny, because nobody is anxious during setup. Be silly here. Be plain later, when they're 3km from home and the stove says "unknown".

No exclamation marks on system copy. Sentence case everywhere. Contractions always.

---

## Screen 0 — does not exist

No splash. No logo animation. No "Welcome to Did I?". Cold open directly on Screen 1.

Every second before the first question is a second spent deciding whether to care.

---

## Screen 1 — the question

**Title**
> What did you last go back home to check?

**Subtitle**
> Pick one. You can add more later, but you probably won't.

**Chips** (in this order)
- The stove
- Front door
- Iron
- Windows
- Straightener
- Something else

**Footer, 11px, muted**
> No account. Nothing leaves your phone.

### Behaviour

- Tapping a chip advances immediately. There is no Continue button.
- "Something else" opens a single text field.
  - Placeholder: `The garage door` (a real example, not a repeat of the label)
  - Max 24 characters. Longer names break the widget.
  - Return key label: "Add"
- Only one item can be picked. Multi-select is a trap that produces a five-item chore list on day zero.

### Why chips, not a text field

A blank "what do you want to track?" field is a blank-page problem plus mobile typing. The chip list is a one-tap answer *and* it teaches the concept — you learn what the app is for by reading the options.

### Icon + reset default assigned silently per chip

| Chip | Icon | Default reset |
|---|---|---|
| The stove | flame | Daily at 04:00 |
| Front door | lock | Daily at 04:00 |
| Iron | iron | 12 hours after confirming |
| Windows | window | Daily at 04:00 |
| Straightener | flame | 12 hours after confirming |
| Something else | check | Daily at 04:00 |

The user is never asked about this. See Day 2 for when the reset rule surfaces.

---

## Screen 2 — the practice tap

**Title**
> Try it once

**Subtitle**
> This is the whole app. There's no step four.

Then: the live item card, in its unknown state, exactly as it will look on the main screen.

**Footer, 11px, muted**
> Hold to undo. Everything resets overnight.

### Behaviour

- The tap fires the real haptic (`UIImpactFeedbackGenerator`, heavy) and writes a real entry to the store. This is not a simulation.
- Card animates to confirmed green, shows "logged just now", and a random confirmation line appears below it.
- Auto-advance after 2.5s, or on tap of anywhere.

### Why this screen exists

Three jobs at once:
1. Teaches the interaction by doing it, not describing it.
2. Delivers the joke while the user is calm enough to enjoy it.
3. Produces a real logged entry, so the app is never empty. A fresh install where everything reads "unknown" looks broken — and "unknown" is exactly the state that makes people delete things.

### Confirmation lines (rotating, random, never repeat twice in a row)

Onboarding-specific:
> Nice. Now go about your day, you magnificent adult.

General pool, used everywhere after:
- Logged. Your confirmation is on the record.
- Done. Future you has a timestamp now.
- Noted. One less thing to remember.
- Confirmed. Look at you, adulting.
- Got it. The board has your back.
- Recorded for posterity and peace of mind.
- Yep. Consider the check logged.
- Marked. Past you left a receipt.
- Filed under "confirmed".
- Done. That's one less thing rattling around in there.
- Locked in. Go be somewhere else now.
- Confirmed. Genuinely, well done.

Escalation lines, used only when the same item is confirmed 3+ times in one day:
- Third confirmation today. Latest one logged.
- Confirmed again. The newest timestamp is on the board.
- Updated. This confirmation replaces the last.

Keep every line under 60 characters so it fits one line on the smallest supported device.

---

## Screen 3 — the widget

**Title**
> Put it where you'll look

**Subtitle**
> The widget answers without opening anything.

**Body:** a live medium-widget preview of the user's board, followed by the five installation steps in a readable sheet. A video can replace the sheet later when a real, localised asset exists.

**Fallback text under the video, 12px:**
> Long-press your home screen → Edit → Add widget → search "Did I?"

**Buttons**
- Primary: `View steps` — opens the installation steps in a scrollable sheet
- Secondary: `Later`

### Why this is the real conversion event

iOS gives no API to place a widget on someone's behalf. It's a five-step manual task at the end of an onboarding, which is exactly where people bail. Treat "Later" as a legitimate outcome, not a failure.

### The "Later" branch — and the only permission ask today

When "Later" is tapped, show one sheet:

**Title**
> Want a nudge tomorrow morning?

**Body**
> We'll remind you once, around the time you'd be leaving the house. Once. Then never again.

**Buttons:** `Yes, once` / `No thanks`

Only on "Yes, once" do we present the iOS notification permission dialog. If they say "No thanks", we never ask for notification permission again during onboarding.

This is the only kind of permission ask that gets a yes: specific, attached to a thing they just chose, with a stated limit.

### If they install the widget on this screen

Detect via widget timeline callback. If a widget appears before the Day 1 nudge is due, cancel the nudge silently. Don't congratulate them.

---

## End state

Main screen. One item. Green. Confirmed seconds ago.

No "you're all set" celebration. No tour. No checklist. No settings prompt. The app goes quiet.

---

## What we deliberately do not do on Day 0

- Ask for location. (Earned on Day 2 — see that doc.)
- Ask for notifications, unless "Later" was tapped on the widget screen.
- Create an account. There is no account, ever.
- Offer a second item.
- Explain decay, reset rules, or the geofence.
- Show the paranoia counter.

---

## Edge cases

**Force-quit mid-onboarding.** Resume at the last completed screen. Never restart. Making someone redo a setup is how you lose them twice.

**"Something else" left empty.** Return key stays disabled; no error message, no red border. Just nothing happens.

**Notification permission previously denied at OS level** (reinstall). Skip the "Yes, once" sheet entirely — don't offer something we can't deliver.

**Reinstall with existing local data.** There is no cloud, so a reinstall is a fresh install. Treat it as one, no restore prompt.

**VoiceOver.** Screen 2's practice tap must be reachable as a single button with label "Confirm stove is off" and hint "Double tap to log". The confirmation line is announced via `UIAccessibility.post(.announcement:)`.

**Reduced motion.** The widget video still plays — it's instructional, not decorative — but the card flip on Screen 2 becomes a cross-fade.
