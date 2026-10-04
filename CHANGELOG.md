# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/). Versions follow SemVer (see `docs/05 Engineering/开发流程.md`).

## [Unreleased]

### Changed
- Cans have caps: Sunday boxing earns once a week; runs, the gym and other wins once a day.
- The companion is called HAKU everywhere you see it: the widget name, notifications, Settings and
  VoiceOver. Code names stay RUNNER.

### Added
- HAKU does it with you: heavy-bag combos at the boxing gym, curls at the fitness gym, a bobbing run with
  speed lines, the gym bag on its shoulder on gym days, and a running shoe warm-up on run day.
- Pictures for the coming shop and wardrobe: a can icon and a small picture of each item, drawn the same
  way as HAKU wears it.
- HAKU can wear wardrobe items: pink or gold gloves, a cyan or white runner headband, a striped mask,
  and a plant or small punching bag next to it at home. They show once the shop and wardrobe screens exist.
- Gym and run days (Issue #49): Tuesday to Thursday after work HAKU wears the gym bag until you
  train; Saturday from 17:00 it warms up for the run. At the gym it lifts, at the boxing gym it hits the
  bag. The couch invite now offers the gym or a walk. (HAKU's looks and the 健身房 place in Settings
  come with the UI thread's next PR.)
- HAKU earns cans from real workouts, saved for the shop that comes next: a boxing class, a 5 km run,
  or strength training (once a day). Strength training of 20 minutes or more now gets its own
  celebration too.
- Lock Screen HAKU knows how long couch scrolling has gone on, so after 30 minutes it eyes the gym bag
  there too, like on the home screen.
- Rewards groundwork (Issue #49), not shown in the app yet: a can ledger that counts each real-life
  win once, a shop of five items, three keepsakes granted at milestones (never lost), and a wardrobe
  with one item per slot.
- Couch scrolling now has steps: after 30 minutes HAKU keeps scrolling but keeps glancing at the gym
  bag by the door; when the day's invite shows, it gets up with the bag over its shoulder.
- HAKU talks on the Lock Screen: one short line in its own voice for the mode, the need, low energy or
  bedtime, a different one each day; everyday scenes have at least 7 lines, so none repeats within a week.
- Off-work notice: on work days, 15 minutes before work hours end, "快下班了" from HAKU in its chill
  outfit. Work hours (default 9:30 to 18:30) can now be changed in Settings; automatic switching and
  the notice follow them.
- HAKU has its own life at home: with nothing needed it naps in the sofa corner, plays a handheld,
  sneaks a snack, draws, shadow boxes or, on Sunday afternoons, wipes the room with a cloth. Tap it and
  it gets caught (hides the snack, closes the sketchbook, drops the gloves). New deadpan lines, and
  VoiceOver now says HAKU.
- Off-work animation: when the off-work notification is tapped, HAKU takes the headset off, pulls the
  mask down, stretches, opens a Monster and says "终于。". Once a day. Workout celebrations now carry
  the workout type, ready for per-type celebrations.
- Settings: the wake time is now editable next to the bedtime. RUNNER stays sleepy until then
  (it was fixed at 05:00).
- App icon: RUNNER's face split by a lightning crack, the side-hustle ¥ mask on one side and boxing
  on the other, with a glitch afterimage.
- "记一笔乐天 Pay" in Shortcuts: enter the amount (and whether it was eating out) right after paying,
  for example from an automation when Rakuten Pay closes. The app adds it the next time it opens and it
  comes off the savings card. A later card email for the same day and amount pairs with it instead of
  counting twice and sorts it by shop, unless it was marked as eating out.
- Savings card on the iPhone home screen: how far the bank balance is from the savings target, with
  a progress bar. Enter the balance on payday and the target in the new "钱" settings card. Both stay
  on the iPhone. Card spending will come off the balance once email reading is in.
- Budget groundwork (Issue #24), not shown in the app yet: reading Rakuten Card quick-notice and
  detail emails into expenses, pairing the two so each payment counts once, sorting shops into eating
  out / groceries / other by keywords, and the two numbers the money card will show (eating out left
  this month, gap to the savings target).
- Sunday boxing countdown on the Lock Screen and in the Dynamic Island: RUNNER's head in gloves and
  the minutes to 10:00. It starts when the app is opened (or the invite tapped) during Sunday warm-up
  and ends on arriving at the gym or the next time the app sees class has started.
- At most one invite a day: after an hour of couch scrolling (or 30 minutes into Sunday boxing
  warm-up) a notification from RUNNER says "起来走两步？我陪你。" or "拳套戴好了，出发去拳馆？". It is
  dropped if the need ends first and never lands at bedtime. Long-press it to see RUNNER get up.
  The Screen Time threshold schedules it even when the app isn't running.
- RUNNER celebrates a 5 km run or 30 minutes of boxing once, the next time the app is opened within
  3 hours of the workout ending. Never at bedtime.
- Couch scrolling look for RUNNER: slumped back with half-closed eyes, a lit phone in hand and a
  thumb flick every few seconds. When the app passes today's invite, RUNNER gets up, jumps and says
  it in the bubble.
- RUNNER acts out the need on the home screen and in widgets: lying on the couch after enough
  scrolling or an evening still at home, gloves on on Sunday morning. The Screen Time threshold now
  counts (debug builds). Sunday boxing ends at 12:00 and Screen Time couch after 3 hours, also on the
  Lock Screen without opening the app. Sunday gloves show up at 9:00 even if the app hasn't run that day.
- RUNNER celebrates a finished workout: two happy hops, a burst of sparkles and "干得漂亮！". Each
  workout plays once, never at bedtime. Not switched on in the app yet.
- RUNNER's "why" line on the home screen and the rectangular Lock Screen widget: bedtime, then a need
  (still at home for an hour in the evening, Sunday boxing from 9:00), then last night's sleep.
  Home is a third place in settings. Workouts and recent steps are read from Health on the iPhone
  only; only a summary is kept. Screen Time couch scrolling now only counts at home (or when home
  isn't set) and for 3 hours, and its line doesn't name the apps. On Sunday until 10:30 boxing
  warm-up comes before couch scrolling.
- Boxing warm-up look for RUNNER: gloves and red headband on over any outfit, bouncing, and a look
  at the door every few seconds, with its own tap lines. The same look works in widgets and as a
  small head for the Sunday countdown. Not switched on in the app yet.
- Screen Time watch: in settings, pick Bilibili and Xiaohongshu. When they add up to 30 minutes in a
  day, the app learns that the threshold was reached (never how long they were used). Debug builds
  only (the settings card too) until Apple approves Family Controls for TestFlight. RUNNER doesn't use it yet.
- RUNNER's face follows energy in three steps. Low (under 30): eye bags and slow moves. High
  (70 or more): bright eyes, twinkling sparkles by the head and quicker moves. Widgets show the same.
- Rules for what RUNNER acts out (Issue #23): couch scrolling (Screen Time threshold, or still at home
  in the evening) and Sunday boxing warm-up from 9:00, at most one invite a day after a need lasts,
  celebrating a 5 km run or 30 min of boxing once, replaying an automatic mode switch on open, and
  the line that says why RUNNER looks the way it does. Not shown in the app yet. `CompanionEvent`
  names the one-off celebration for CompanionKit.
- Places: set the gym and the office to your current location in settings. Arriving at the gym
  switches straight to boxing; leaving after 30+ minutes goes back. Arriving at the office switches
  to work. Works with the app closed when location access is "Always". Places stay on the iPhone.
- Bedtime reminder: one local notification a day at 23:30 (changeable in the new settings sheet).
  Long-press it to see RUNNER yawning. From then until 05:00 RUNNER is sleepy on the home screen
  and in widgets, and opening the app plays the good-night animation once. No second reminder.
- Automatic mode from the weekday schedule: Monday to Friday 9:30 to 18:30 is work, other times
  chill. It switches once per period and waits 2 hours after a manual change. Rules for arriving at
  the gym (straight to boxing) and the office (work), and leaving the gym after 30+ minutes (back to
  the earlier mode), are ready for the location PR.
- Today's energy from last night's sleep in the Health app: under 6 hours is low, 6 to 7.5 okay,
  7.5 or more full. Only the total is kept; raw sleep data stays in Health. A self-report still wins.
- iPhone widgets. Lock Screen (round, inline, rectangular) and Home Screen small: RUNNER with the
  current mode and today's energy, sleepy at bedtime. Home Screen buttons: switch mode (medium) and
  pick today's energy (small) without opening the app. The app applies widget taps when it opens.
- Home screen shows today's energy and its reason; RUNNER looks tired when energy is low.
- Bedtime look for RUNNER: at bedtime RUNNER takes the headset off, pulls the mask down, yawns,
  stretches and leans onto a pillow ("该睡了"), then stays sleepy with slow blinks, yawns and Z z z.
  A short loop for the notification and a sleepy still portrait (full or head only) for widgets.
- iPhone and Mac home screen: RUNNER companion per mode, four mode buttons, today's mode timeline.
- Mac menu bar panel with the current mode and mode buttons.
- RUNNER drawn as 36 named vector parts instead of PNGs: per-mode idle loops (work nod and LED
  breathing, chill Monster sip, boxing guard bounce, money chain shine), a reaction on tap, and a
  tired look below 30 energy. `CompanionPortrait` gives a still version for widgets.
- Energy data model: sleep and self-report events, a rule-based state engine that gives today's
  energy with its reason, the 23:30 to 05:00 bedtime window, and both in the widget snapshot.

### Fixed
- Settings > 钱: the amount fields now look like inputs, an outlined box with ¥ and the number
  together on the left, thousands separators, and a 完成 button to close the number pad.
- A mistap or a curious look at another mode no longer sticks: switching again within 2 minutes
  replaces it, and switching back undoes it, so the TODAY timeline and the 2-hour pause on automatic
  switching are as before.
- The app no longer crashes on launch on a real iPhone: the place monitor's name had a hyphen,
  which CoreLocation rejects.
- The Sunday boxing countdown says "已开始" at 10:00 instead of stopping at 0:00.
- The expanded notification no longer stacks a second RUNNER when the notification updates.
- Afternoon naps no longer count toward last night's sleep.
- Tapping the current mode after an automatic switch now records it as a manual change.
- A mode log that can't be read (for example before first unlock) is no longer moved aside or
  overwritten; saves wait until it can be read.
- Mode log data contract (`ModeChange`, `ModeLog`, `WidgetSnapshot`) stored as local JSON.
- DEV / STG / PROD build configurations with separate bundle ids.
- CI quality gates (PR title and branch, swift-format, lint, tests, coverage, warnings as errors) and
  TestFlight release workflow for STG and PROD.
