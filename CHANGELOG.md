# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/). Versions follow SemVer (see `docs/05 Engineering/开发流程.md`).

## [Unreleased]

### Added
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
- Afternoon naps no longer count toward last night's sleep.
- Tapping the current mode after an automatic switch now records it as a manual change.
- A mode log that can't be read (for example before first unlock) is no longer moved aside or
  overwritten; saves wait until it can be read.
- Mode log data contract (`ModeChange`, `ModeLog`, `WidgetSnapshot`) stored as local JSON.
- DEV / STG / PROD build configurations with separate bundle ids.
- CI quality gates (PR title and branch, swift-format, lint, tests, coverage, warnings as errors) and
  TestFlight release workflow for STG and PROD.
