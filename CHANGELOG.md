# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/). Versions follow SemVer (see `docs/05 Engineering/开发流程.md`).

## [Unreleased]

### Changed
- The Daily Widget "下一件" line keeps a task for its first 10 minutes, then moves on. Tasks past that never show.
- Gym days follow the days you actually go: a weekday with a gym visit or strength workout in 2 of the
  last 4 weeks. Until a weekday qualifies, gym days stay Tuesday to Thursday. There is no setting for it.
- Widgets redraw every 15 minutes for the next 6 hours, so HAKU's idle bits on the Lock Screen change too.
- The currency is called 能量罐 everywhere you read it: the shop, unboxing, places and VoiceOver. HAKU
  still drinks Monster. The home screen shows "你认真活过的每一天，都不该白白消失。" before any mode is set.
- The clock no longer switches the mode. Work starts when you arrive at the office and ends when you
  leave it (or by hand); before, the app switched to 上班 at 9:30 even if you were still at home. The
  off-work notice now goes out only on days you're in 上班 mode or at the office.
- HAKU's sleeping pillow is light blue, so it no longer blends into the white hair.
- HAKU stops couch scrolling when you do: it gets up 20 minutes after Screen Time last saw you on the
  picked apps (it reports every 10 more minutes of use), as soon as you walk, or when you change mode by
  hand. Before, it lay on the couch for 3 hours after the daily 30 minutes.
- Cans have caps: Sunday boxing earns once a week; runs, the gym and other wins once a day.
- The companion is called HAKU everywhere you see it: the widget name, notifications, Settings and
  VoiceOver. Code names stay RUNNER.

### Added
- HAKU reacts to planned Daily Widget tasks: 15 minutes before, it taps its watch and holds up the task's prop
  (headphones, shopping bag, gym bag or a sticky note); at the start it slaps a sticky note on the screen; when a
  task is done it gives a peace sign, or for the day's focus flares its mask and pumps its fist.
- With Daily Widget linked, the home screen shows "下一件 18:00 <title>" for today's next timed task, and
  the Lock Screen shows "下一件 18:00" without the title. Tapping the line opens Daily on that day. A
  couch-scrolling invite within an hour of a task says "等下还有事，先起来收拾？" instead. HAKU's task
  animations follow in the companion package.
- Settings has a "联动 Daily Widget" switch, off by default. Turned on, you pick Daily's iCloud Drive
  folder once and Life Hub reads its tasks (never writes). A task planned ahead in Daily and done earns
  1 能量罐, at most 3 a day. Turning it off forgets the folder; cans stay.
- HAKU packs up at the office from 15 minutes before the end of work hours: closes the laptop, wipes
  the desk, takes the bag, then looks at its watch for up to 30 minutes after. Only on work days in
  上班 mode at the office. When leaving the office ends work, HAKU says "……收工。" for 30 minutes.
- Near the end of a work day at the office, HAKU packs up: it closes the laptop, wipes the desk, takes
  the headset off, shoulders the bag and watches the clock.
- When HAKU is stiff in work hours, it sends "起来。我先起了。" once. This shares the one work-time
  notice a day with the scrolling-at-work notice. Ignored 3 days in a row, it pauses for a week.
- HAKU gets stiff when your Apple Watch logs two idle stand hours in a row in 上班 or 副业: it twists
  and thumps its back, and stretches when you open the app. When you stand after that, it rolls its
  shoulders once. No Watch or no recent data: nothing. Health access now also asks for stand hours.
- When you sit too long at work, HAKU twists and thumps its back (also its Lock Screen look), stretches
  when you open the app, and rolls its shoulders after you stand up.
- Change moments (Issue #91): the app notes by itself when you got up after an invite, reached the gym
  after 走, or earned a keepsake within a day of being one win away. On Sunday HAKU says one line about
  the week's moments on the home screen and widgets; a week with none gets no line. Getting up after an
  invite now also earns its can and the 起身庆祝 keepsake.
- Tap HAKU while it snacks or draws: after it hides the snack or sketchbook, it looks away and whistles a little note.
- At home HAKU now and then scratches its head and a tuft of hair sticks up, then slowly settles.
- When HAKU's 元气 is high (good sleep, sunlight) a little music note now and then floats up as it hums.
- When HAKU's 元气 is low (short sleep, no sun) it now and then rubs an eye with its fist.
- Tap HAKU three times within 30 seconds and it says "……干嘛。" and turns its back on you for a moment.
- At work HAKU now and then sneaks a look at its phone and puts it straight away.
- On boxing day HAKU now and then shakes out its wrists and lifts a glove to fix its headband.
- Open the app between midnight and 5:00 and HAKU squints at you and says "还不睡。" once a night. No notification.
- A napping HAKU now and then mumbles in its sleep: a small "…" floats up instead of the Z z z.
- While vibe coding HAKU now and then stops typing, stretches with its hands up and goes back to the keys.
- At work HAKU now and then nods twice to the music, stops for a beat and pushes its headset back into place.
- Open the app after half a day away and HAKU looks up at you slowly, as if to say "oh, you're here". No line.
- HAKU's hidden 体能 and 元气 now show on the home screen, widgets and the Lock Screen: weeks of training make
  it stand straighter and bounce more, good sleep and daylight make it brighter. They never show as numbers.
- HAKU's hidden 体能 and 元气 show in how it moves, never as a number: fit means upright, bouncier and
  shadow boxing instead of napping; low 元气 means slower, half a beat late, and a little washed out.
- Tapping a napping HAKU makes it roll over in its sleep. Tap again soon after and it half wakes
  and grumbles.
- Traces that stay: after 5 boxing cans HAKU's gloves look worn, after 2 runs of 5 km the running shoes
  stay by the door, and after 10 hours of vibe coding in all a second monitor sits by the laptop. They
  show at home, on widgets and on the Lock Screen, and never go away.
- Debug builds keep a local dogfood log of automatic decisions (each geofence arrival or departure and
  whether it switched the mode, and the 编程 Focus), so wrong switches can be found after a few weeks of use.
  It stays on the iPhone and isn't shown in the app.
- HAKU has two hidden params, worked out by rules: 体能 from the last four weeks of boxing, gym and 5 km
  runs, and 元气 from the last three nights' sleep plus daylight. They rise fast and fall slowly and never go
  below tired. HAKU's moves will use them once the looks exist. No numbers or bars anywhere, and no cans.
- At home, every fourth sip HAKU finds the can empty, shakes it by its ear and stares at it.
- Lasting traces in HAKU's world: taped, scuffed gloves after 5 boxing sessions, a second monitor by
  the laptop after 10 hours of vibe coding, running shoes at home after 2 runs. The app decides when
  they are earned.
- HAKU's eyes drift off to one side now and then and come back, so it looks like it has its own
  thoughts.
- HAKU on the widgets and Lock Screen changes a little every 15 minutes: a glance, a sip, gloves up.
  At home it shows what it is doing in the app, such as napping (just zzz) or playing the handheld.
- HAKU backs off: if you ignore the same invite (couch, gym day or scrolling at work) three times in a row,
  it stops that invite for a week and says "行，我不念了。" that day. Nothing is made up afterwards. An
  invite is only counted as ignored when the app can tell; when it can't, it isn't counted.
- When you open the app, HAKU is looking elsewhere and turns to you half a beat late. A napping HAKU
  doesn't.
- When HAKU has waited at the door long enough on a work-day morning, it gives up once: headphones off,
  back on the sofa, "……今天在家？". It plays when the 90-minute wait ends with you still at home, the
  next time you open the app during work hours.
- HAKU picks the new home looks by itself (Issue #83, PRD sections 16 and 18). On work days at home in
  下班 mode: brushing teeth until work starts ("又要上班了。"), then waiting at the door tapping its watch
  ("……公司还在等你。") for up to 90 minutes, with no notification and not on days you changed the mode by
  hand. After 8+ hours in 上班 mode, the first 30 minutes home are collapsed on the sofa arm
  ("你也活着回来了啊。"). From 21:00 a quiet evening at home is the blanket. Today's traces: a bandage
  after 30+ minutes of boxing or a boxing workout, the monitor on after 30+ minutes of vibe coding,
  sunlight after a full night's sleep. Traces fade at 05:00 and earn no cans. Widgets and the Lock Screen show them too.
- The wardrobe has a 人生收藏 section: each keepsake you earned, with the day and how, such as
  "2026-11-02 · 累计 10 次周日拳击".
- HAKU's world keeps traces of the day (Issue #83): a bandage after boxing, the monitor still glowing at home
  after vibe coding, sunlight through the window after good sleep. New states: collapsed on the sofa arm
  after a long work day, wrapped in a blanket on lazy evenings, brushing teeth on weekday mornings, and
  tapping its watch at the door when it's past 9:30 and you're still home.
- Work days get three HAKU states. 摸鱼: 30+ minutes on the picked apps inside work hours (counted apart
  from the evening couch) and HAKU peeks over the laptop; one notice goes out, as the day's one push.
  犯困: at the office in work mode, from 3 hours after arriving or 14:00, for 2 hours, with a yawn and a
  Monster. 加班: still at the office after 19:00, slumped on the desk. Both show a Lock Screen line and
  send nothing.
- Gym days (Tue to Thu): if you're home at 19:30 and haven't trained, HAKU waits at the door with the bag,
  and at 20:00 the day's one invite asks "包背好了，走？". Its 走 button, or the new "出发去健身" control
  (Lock Screen, Control Center or Action button), sends HAKU walking with the bag for up to an hour, until
  you reach the gym. Not going changes nothing. This invite replaces the couch one on gym days.
- HAKU looks for the new mode states (Issues #73, #74, #75): vibe coding with `</>` on the mask
- 副业 has three states: vibe coding, 拍摄 and 运营. In 副业 mode, tap HAKU to switch; vibe coding is the
  default and stacks a can every 30 minutes, up to 3. An iOS Focus filter "副业 · vibe coding" (add it to
  a Focus such as 编程 and turn it on) switches to vibe coding, but not within 2 hours of a manual change.
  State taps earn no cans. The mode code reads SIDE instead of MONEY.
- HAKU looks for the new mode states (Issues #73, #74, #75): vibe coding in a hoodie with `</>` on the mask
  and cans piling up, silent flow that hands over a can, sleepy late coding, shooting with the ¥¥ mask,
  peeking over the laptop at work, a drowsy yawn with a Monster, slumped on the desk at overtime, waiting
  at the door with the gym bag, a towel and a hand weight, and walking to the gym. Switching state plays a
  short squash and sparkle.
- Settings > 地点 is a list: 家, 公司, 健身房 and 拳馆, plus your own places from the + button. Each added
  place has a name, a radius and what HAKU does when you arrive (switch to 上班, 下班 or 副业, count as the
  gym or the boxing gym, or only note it). Up to 20 places, the iOS limit. Places stay on this iPhone.
- HAKU now acts out what you're doing on the home screen and the Lock Screen: boxing at the boxing gym,
  lifting at the fitness gym, the gym bag after work on gym days and the shoe warm-up on run day.
  Settings shows the fitness gym again; staying there 30 minutes or more counts as a gym workout.
- New items open with an unboxing: after buying in the shop, or the next time you open the app after a
  keepsake is earned. HAKU pops out of the box wearing it; "现在戴上" puts it on, "先放衣柜" keeps it
  for later. Items owned before this update don't unbox.
- HAKU unboxes new items: a gift box shakes, pops open, and HAKU jumps out wearing the item and says a
  line ("……给你的。才不是特意挑的。" for keepsakes). The 起身庆祝 keepsake adds a peace sign to every
  celebration.
- HAKU does it with you: heavy-bag combos at the boxing gym, curls at the fitness gym, a bobbing run with
  speed lines, the gym bag on its shoulder on gym days, and a running shoe warm-up on run day.
- Shop and wardrobe. The home screen gets two entry points and is otherwise unchanged: the can count
  next to Settings opens the shop (buy items with cans, see what you own and how far each keepsake is),
  and "衣柜" on HAKU's card opens the wardrobe (tap an owned item to wear it, preview each mode). What
  HAKU wears shows on the home screen and the Lock Screen.
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
- Leaving the office switches to 下班 Chill only from 17:30. Stepping out earlier, such as for lunch,
  keeps 上班.
- Staying 30 minutes at the boxing gym counts as boxing, like the fitness gym: 5 cans once a week and
  a step toward the worn and gold gloves. Before, boxing counted only with a watch workout.
- When location access isn't "Always", home shows how to fix it. Without it the app only learns you left
  the office or got home when you open it. The Debug log notes why a place event was held back.
- Opening the app now plays what you missed in the last 3 hours: a mode switch made while the app was
  closed (HAKU starts in the old outfit and changes), and the off-work animation if you didn't tap the
  notice and aren't back in 上班. Before, these only played with the app on screen, so HAKU looked idle.
- Walking past a place no longer leaves HAKU in that mode: leaving within 3 minutes of arriving puts
  the earlier mode back. A GPS blip that leaves and returns within 3 minutes keeps the stay going, so
  gym time and office time aren't cut short.
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
