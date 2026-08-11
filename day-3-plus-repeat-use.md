# Day 3+ — Repeat use

**Goal:** let the list grow to fit the person, without ever turning into a chore list.

**Success metric:** two to four items, still in use after two weeks.

**Anti-goal:** eight items. An eight-item list is a chore list, and chore lists get abandoned by Thursday.

---

## The second item is signal-driven, never scheduled

Do not prompt on "day 3". Prompt when the user's behaviour says something is missing from the list.

### Trigger — any one of these

1. **Two app opens in one day.** They're looking for something the widget can't answer.
2. **A single item checked 5+ times in one day** via widget or app, without a new confirmation. That's rumination about something adjacent, not about that item.
3. **An item confirmed, then re-confirmed within 60 seconds.** Usually means they tapped the wrong thing and there's a near neighbour missing.

### Cooldowns

- At most one suggestion per 7 days.
- Never within 48 hours of install.
- After two declines, stop suggesting for 30 days.
- After three declines, stop forever. They know where the plus button is.

### Copy

> **You've opened this a few times today**
> Anything else worth keeping an eye on?
>
> [chips: the original list, minus what they already have]
>
> `Not right now`

Note the framing: it's about *them* having something on their mind, not about the app wanting more data. Never "Add more items to get the most out of Did I?".

---

## The cap

Six items, hard.

When they try to add a seventh:

> **That's six things**
> This app works because the list is short enough to trust at a glance. Want to swap something out instead?
>
> `Swap one out` · `Never mind`

If they insist via `Swap one out`, show the list with usage counts so the choice is informed: "Windows — last confirmed 12 days ago."

Don't make the cap a paywall. Making anxiety relief a subscription tier is a bad thing to do to people.

---

## The paranoia counter

Unlocked quietly on the first week's end, only if there's something amusing to show — i.e. at least one item was checked 10+ times.

Weekly card on the main screen, dismissible, never a notification:

> **This week**
> Top worry: the iron. 34 checks.
> Runner-up: the door, a modest 12.
> The stove was fine every single time. It's always fine.

Rotating closing lines:
- You checked 61 times. It was off 61 times. Just saying.
- Perfect record. Zero disasters. One slightly tired phone.
- Everything was fine, every time, all week.

**Hard rule:** the counter is only ever shown as a joke about a *good* record. If the week contains items that genuinely went unconfirmed, or the check count is climbing week over week, don't show the card. A stat that reads as "look how anxious you were" is not a feature.

### The escalating-checks guardrail

If checks-per-day for a single item trend upward across three consecutive weeks, suppress the counter permanently and show this once instead:

> You've been checking the iron a lot lately. This app is meant to end the checking, not become the thing you check. If it isn't helping, it's fine to delete it — the iron will still be off.

Then never mention it again. No resources, no diagnosis, no follow-up. One honest sentence and then get out of the way.

---

## Long-term behaviour

### Returning after a long absence

If the app hasn't been opened in 14+ days, do not re-onboard. Show the list as it is. If the widget was never installed, the widget prompt may reappear once — this is the only prompt allowed to resurface.

### Empty state

If they delete their last item, show Screen 1 from Day 0 again — same question, same chips, no shame, no "your list is empty" heading.

### Items that go stale

If an item hasn't been confirmed in 30 days, offer to archive it — once:

> **Windows hasn't come up in a month**
> Want to put it away? You can bring it back any time.
>
> `Archive it` · `Keep it`

Archive, never delete. Deleting someone's data on our initiative is not our call to make.

### Seasonal items

"Heating off", "windows closed", "watered the plants" come and go. Archived items surface in the add-item sheet under a quiet "Previously" section so re-adding is one tap.

---

## What the app never does, at any point

- Send a notification about anything except the one-time widget nudge and, if explicitly enabled per item, the leaving-home reminder.
- Streak-shame. Streaks exist and are celebrated; breaking one is never mentioned.
- Gate anything behind an account or subscription.
- Say "you forgot to turn off the stove". It cannot know that. It only ever knows whether there's a record.
- Use red. Amber is the strongest colour in the app. Red on a stove app at 9am is a small cruelty.
- Show a badge count on the app icon. A permanent number on the home screen is an anxiety generator, and this app has a specific obligation not to be one.
- Ask for a review while an item is in `unknown` state and the user is away from home.

---

## Review prompt, since we're here

`SKStoreReviewController` only, and only when: an item was just confirmed, the user is at home, they've used the app 15+ days, and no prompt has fired in 120 days. Ask people for a favour when things are good, never while they're wondering about the stove.

---

## Open questions for v2

- **Shared households.** Two people, one stove. Needs a shared state and a "Marta confirmed it" attribution. Genuinely useful, genuinely complicated, out of scope for v1.
- **NFC stickers.** The strongest possible answer to "can this record be trusted" — a tap that can only happen at the appliance. Ships as an accessory idea, not a v1 dependency.
- **Apple Watch complication.** Arguably a better home for this than the phone; the glance is even cheaper.
- **Multiple homes.** Currently a documented limitation.
