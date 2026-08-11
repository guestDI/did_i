# Day 1 — The widget nudge

**Goal:** get the widget onto the home screen, using exactly one notification.

**Success metric:** widget installed. Failure is acceptable; nagging is not.

**Constraint:** the app has no location permission today. Everything on Day 1 runs on time-based resets only.

---

## The nudge

### Fires only if all of these are true

1. No widget of ours is currently installed (checked via `WidgetCenter.shared.getCurrentConfigurations`).
2. Notification permission was granted — meaning the user tapped "Later" on the widget screen, then "Yes, once", then allowed the OS dialog.
3. It has been at least 12 hours since install.
4. It has not fired before. Ever.

If any condition fails, the nudge never fires and is permanently cancelled. No retries, no second chances, no "we noticed you still haven't…".

### Timing

Default 08:00 local, weekdays. Skip weekends — nobody is rushing out the door on a Saturday, and the nudge only makes sense at the moment its value is obvious.

If the install happened after 20:00, the nudge targets the *next* weekday morning rather than the one 12 hours later.

Better version if you have the data: schedule against the user's typical first-unlock time. iOS won't hand you that directly, but you can approximate it from when the app was installed and any early-morning app opens. Don't over-engineer this for v1 — 08:00 is fine.

### Copy (pick one at random at schedule time)

> **Your widget is still homeless**
> Two taps and it lives on your home screen. Long-press → Edit → Add widget.

> **The app works better when you can see it**
> Long-press your home screen, hit Edit, add the widget. Ten seconds.

> **Quick one before you head out**
> Add the widget so you never have to open this app again. Long-press → Edit → Add widget.

Tapping the notification deep-links to the widget instruction video, not the main screen.

### After it fires

Mark `widgetNudgeFired = true` permanently. Whatever happens next — installed, ignored, notification swiped away — the app never mentions the widget again unprompted.

If they never install it, that's a legitimate way to use the app. Some people will open it directly. Let them.

---

## What the app does the rest of Day 1

Nothing new. This is deliberate.

- The item they created sits green, aging quietly.
- Confirmation lines rotate normally if they tap again.
- No tips, no tooltips, no "did you know" cards.
- No second-item prompt (that's Day 3+, and it's signal-driven, not scheduled).

The first 24 hours should feel like the app is already old and settled. Anything that feels like it's still introducing itself competes with the one thing we actually want them to do today.

---

## The first reset happens tonight

At 04:00 the item flips back to unknown. **The user is not notified about this.** It's the first thing they'll see on Day 2, and that's where we explain it — in context, with their own item, rather than as a warning about something that hasn't happened yet.

Do not send a "your stove confirmation expired" notification. It's alarming, it's useless at 4am, and it wastes the goodwill of the one notification they agreed to.

---

## Edge cases

**They install the widget before the nudge is due.** Cancel the pending notification. Say nothing. No congratulations screen — installing a widget is not an achievement, it's a preference.

**They install the widget, then remove it later.** Do not re-arm the nudge. They've made an informed choice.

**They tapped "Show me" on Day 0 but never installed.** Same as any other non-install: the nudge fires as scheduled.

**Notification permission granted, then revoked in Settings.** iOS drops the notification silently. Mark the nudge as fired anyway on next app open. Never surface "notifications are off" as a warning banner — it's their phone.

**Multiple items already exist** (rare, if they tapped "Something else" and then added more). The nudge copy is unchanged; don't enumerate items in a notification.

**Day 1 falls on a public holiday.** Not worth detecting. Ship the weekday rule and move on.

---

## Instrumentation worth having

Local-only counters, never transmitted (there's no backend and that's a selling point):

- `installTimestamp`
- `firstItemType`
- `practiceTapCompleted` (bool)
- `widgetPromptOutcome` — `installed` / `later` / `dismissed`
- `notificationOptIn` (bool)
- `widgetNudgeFired` (bool)
- `widgetInstalledAt` (nullable)

These exist to let *you* reason about the flow if you ever look at your own device, and to gate the Day 2 and Day 3 logic. They are not analytics. If you later add analytics, say so plainly in the footer copy on Screen 1, because "nothing leaves your phone" has to stay true.
