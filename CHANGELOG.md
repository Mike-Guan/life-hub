# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/). Versions follow SemVer (see `docs/05 Engineering/开发流程.md`).

## [Unreleased]

### Added
- The home draws the second preset character in her own figure: the same room, spots and poses as HAKU,
  with her own head, hair and tops. She sits with her hands on her lap, swings a forehand with her racket on
  her tennis day, guards and punches in two gloves with the boxing card, and dozes over her tablet in bed.
- The identity card picker offers fitness, study and art next to boxing and tennis. With the fitness card the
  fitness gym is the card's place: arriving switches to the card at once and leaving gives back the earlier mode.
- The identity card picker offers dance, music and ski, each with its own home tagline and identity-day
  invite for both characters. The home card taglines now show in Japanese and English too.
- The app follows the phone's language (Chinese, Japanese or English; other languages get English), and
  Settings has a language picker to choose one by hand. The watch follows the watch's language. The
  onboarding hints under each card, such as the place it switches at, are translated too.
- Notifications, the setup's 以后再说 button, the memory page's dates and counts, the place names and note in
  Settings > 地点, and a few error lines now follow the app's language.
- About 230 more Japanese and 170 more English strings, and HAKU's line at the home shop no longer tells you how to spend cans.
- Declined permissions no longer put a red bar on the home screen. Location not set to Always and Motion &
  Fitness turned off each show a grey line in Settings > 地点, with a button to open the iPhone's Settings.
- Settings has a 隐私政策 row that opens the privacy policy, shown once the page has its address.
- The home page shows its labels, sheets and HAKU's lines in Japanese or English when the app runs in that language.
- The welcome-back recap and the wardrobe's VoiceOver label now follow the app's language.
- The home page's date reads 周一，10/26 in Chinese and 10/26（月） in Japanese.
- In the second preset character's home, the card below the room shows her name, her head and her own lines.
- In the home HAKU now follows the home's behavior rules: at bedtime he goes to bed, by mode he sits at
  the desk or on the sofa or trains in the sports corner, and in about half of the 15-minute slots he walks
  over to look at a home item (a plant, the cactus, the speaker) for 30 s. He never goes to the sports
  gear on his own.
- At night in the home HAKU gets into bed and dozes over his phone, tucked in: its screen lights his face,
  and every 10 s he nods off, then jerks back awake. The third time he falls asleep under the blanket. By day
  he sleeps under the blanket at once.
- Share cards: a keepsake or a new top or full set can be shared as a 9:16 or 1:1 picture of the character
  wearing it, with its name and her line. Rows in 人生收藏 open the keepsake's page, which shows how she looked the
  day it arrived; its 「分享」 and a quiet 「分享」 link on the unboxing open the choice. Cards carry no date,
  place or health number, and sharing gives nothing.
- Every tap target on the home page is at least 44 pt, also on iPhone SE: HAKU, the standing bag, the bench, the
  floating labels and the header buttons. A tap just beside a small target still lands on it.
- Second polish batch for the second preset character: the tablet slides back to her lap after the tap, her
  lap things slide away and back while she blows on her drink, the flat racket flips upright after juggling,
  the watch's raised racket swings, twirls and juggles, a tap during a move gets a blink, and at bedtime a tap
  rolls her over instead of rubbing an eye.
- CompanionKit draws the shop's room items for the app: `HomeItemIcon` (small icon, drawn as in the home) and
  `HomeItemPreview` (the real room around the item where it stands, circled, HAKU next to it). The home's shop
  button now opens the app's shop through `onShop` and reads 商店; the prototype's own shop panel is gone.
- The second preset character naps over her tablet when dozing off on the couch: a slow breath and the odd
  nod, and a still frame on widgets and the watch face. Tapping her doesn't wake her.
- In the home prototype HAKU uses the bench: tapping it, dropping him on it, or a fitness card day with the
  bench bought sends him to lie on it and press the bar off the rack, up and down.
- Art for the second preset character's boxing look: a white towel with a pink stripe on her right shoulder.
- The home prototype's room keeps its code-drawn ink look, refined: thinner lines, more small detail (drawer
  handles, keyboard keys, book spines, a throw on the sofa, rug fringe, wood grain), soft shadows under the
  furniture and a light edge on top faces. At night the lamps, the vending machine and the moon glow, and the room
  floats on the page with a hard shadow. A sports corner holds the standing bag, a bench (25 cans, any card) and a
  snowboard (20 cans, ski card). Gloves and a racket on its wall only show in a preview from the room's settings
  for now. The window moved left.
- In the home prototype HAKU walks the shortest way around the furniture instead of back through the middle of
  the rug, steps on and off seats from the side, and lands on open floor when dropped on something he can't use.
- The home page has a saved room per character: a furniture catalog and a layout that keeps what a newer
  build wrote. The wardrobe's room item moves into the room once. Nothing on screen uses it yet (Issue #489).
- HAKU makes small moves in each card look's base outfit now and then. In sport it stretches an arm across
  the chest, then the other, or drinks from a water bottle. Out, it looks at its wrist or tugs its backpack
  strap and shrugs. In craft, it spins its pencil and drops it, or wipes paint off its hand on the apron.
  Whatever it holds for the card goes down out of the frame first. These moves replace the boxing idle in
  card looks.
- A prototype of HAKU's home, from a house button on the home screen and under Settings (家（原型）), in DEV and STG builds only. It is a small iso room in
  SpriteKit: HAKU walks to the desk, sofa, bed or bag when the mode changes, says a line when tapped, can be
  carried, and the room has a day/night switch, a wardrobe, a shelf, recolouring and a mock shop. All data is fake.
- The second preset character's swimming, yoga, ball and outdoor cards, which still wear her tennis look, now
  get their base outfit's idle moves too: a stretch on her toes and a towel for the sport cards, the collar and
  a look at her phone for outdoor. The racket goes down out of the frame first.
- The second preset character can wear her Sunday beanie in 下班, between her cat ears, with its pom swaying a
  little. A set hat or the bath towel takes it off; it stays on when she turns away and on the watch.
- The second preset character wears her first 7 Sunday items: three hair pieces (on her ponytail, else as a
  side clip), a bear blanket and a cloud cushion on her lap, a succulent on the floor and a nightlight on the wall
  whose glow breathes slowly. The watch leaves out what is on her lap or the floor.
- HAKU dresses for the dance, music and ski cards, each with its own idle now and then: it bobs to a small
  speaker as notes float up and stops when caught, plays air chords by a ukulele while counting silently, or
  pulls its ski goggles down and back and breathes out a white puff. The watch leaves out the speaker and the
  fist, and raises the ukulele into view. The cards stay out of the picker for now.
- HubCore decides where the character is in the home page and what she does: a one-time moment first, then
  bedtime, then the mode's spot. On the identity card's day she uses the card's gear if it stands in the room,
  and some quarter hours she walks over to a home item for 30 seconds. She never uses sports gear on her own.
- The second preset character has her own seven weekly items, in her own rotation. They go on sale once
- Two new wear slots for weekly items: a badge on the clothes, worn in every mode, and a hat, worn only in
  下班. HAKU's star badge and both characters' beanies use them and go on sale once their art is in.
- The second preset character has her own eight weekly items, in her own rotation.
- From HAKU's third week, the shop puts one weekly item on sale with a 「本周」 tag, in a fixed rotation that
  starts over, so no item is gone for good. Once bought it stays in its place that week, marked owned. His six drawn
  Sunday items take turns now.
- `HomeSnapshot`: what the home page shows, built from the app's own data (mode, cards, cans, items, face,
  room) instead of the prototype's fake data (Issue #489). The page switches to it in its own change.
- HAKU can wear six Sunday items: an orange or a mint headband, a dotted or a lightning-bolt mask, and a small
  cactus or a mini speaker in the room. The speaker's light ring glows every 3 seconds. The shop lists them once
  their catalog entries are marked drawn. The watch leaves room items out, since they stand on the floor.
- In DEV and STG builds the shop has two tabs, 衣服 and 房间, with this week's item first on its tab. A room item's
  preview shows it standing in the real home page, says where, and sports gear adds that having it earns no cans.
  The bench (any card) and the snowboard (ski card) join the room tab. The home's shop button opens the shop on
  房间. Keepsakes left the shop there, since they live in the home page. Release builds keep one shelf and the
  keepsakes as before.
- HAKU can dress for four more identity cards: tennis (visor, racket and ball), fitness (gym bag and a small
  dumbbell), study (green jacket and an open book) and art (green jacket, apron, sketchbook and pencil).
  The watch leaves the gym bag off the floor.
  Boxing and the other cards keep the boxing kit.
- The second preset character's eight Sunday items and a plain back view of every top, for when she turns
  away, in her clothes layer file. Nothing in the app shows them yet.
- A keepsake or outfit now remembers how its character looked the day it arrived: her mode, what she wore
  and her identity card. Nothing shows it yet; the keepsake page and share cards will. Wins filled in from
  an earlier day keep no look, because the wardrobe has no history.
- The home page's snapshot is built from the app's own stores (mode, cards, cans, wardrobe, energy, room) and
  lists the keepsakes the character earned, with the day each was earned. Room items she owns but hasn't placed
  go into her room's layout when it is built.
- Japanese for the first batch of lock-screen lines (both characters) and English for 842 strings
  are in the String Catalogs, behind the Debug-only 「日文和英文」 switch. `scripts/import-strings.py` adds a
  writers' delivery to the right catalogs.
- The app ships the Japanese font Zen Maru Gothic (Bold and Black, SIL Open Font License in `Apps/iOS/Fonts`)
  and registers it in the app, the widgets and the notification. Nothing uses it yet; Japanese text switches
  to it in a separate change. If the font fails to load, the app says so in its error list.
- The second preset character dresses for the dance, music and ski cards, each with its own idle move: she sways
  by a small speaker as notes float up, taps along a score she holds, or pats snow off her shoulder in ski goggles
  and sneezes. The cards stay out of the picker until HAKU's looks are in too.
- Shop clothes art for the second preset character: eight pop tops and sets, two identity-card tops and six
  base outfits, each with matching sleeves, in their own layer file. Nothing in the app shows them yet.
- The second preset character can wear her eight shop clothes: two tops each for work, off work and side
  hustle, plus the picnic and rain sets with their hats. Her sleeves match when she rubs her eye or points
  at the door. From behind she keeps the hat and shows her own plain top for now. The shop starts offering
  them in a later change.
- Walking 6,000 steps in a day earns 1 can, from Health (iPhone and Apple Watch together, steps typed in by
  hand left out) or the iPhone's own count. Days you didn't open the app count too, up to a week back. Steps
  are never shown and never leave the iPhone.
- HAKU has three new idle moves: at work he leans back and spins his chair round once, off work he pats a
  pillow and leans back on it, and in boxing he bumps his gloves together twice and looks up.
- Debug builds have a 「日文和英文」 switch in settings. It is off by default, so every build shows Chinese
  whatever the phone's language until all Japanese and English text is in. TestFlight builds don't show it.
- The second preset character has two small idle moves in each base outfit: in sportswear she reaches up onto her
  toes or wipes her forehead with a towel, in the smock she tucks her hair behind her ear or makes a viewfinder
  with her hands, and in the lilac top she straightens her collar or smiles at her phone.
- HAKU's eight pop clothes are in the shop: two tops for each of work, off work and 副业, plus the varsity
  and raincoat sets. Each is worn only in its mode, in place of the jacket. The hoodie strings and the
  raincoat's duck swing a little with his breath.

### Changed
- The home's reward shelf shows the worn, taped boxing gloves once the character has boxed 5 times, and the
  reward list names them. The shelf no longer draws gloves nobody earned.
- In the home the floor lamp's cord runs to a socket on the wall beside it, not out across the floor.
- In the home the floating labels (奖励, 家具, 商店, 休息) step above the character, or below him at the top
  of the room, while he would be under them, so they never cover him.
- The home shows only the room items that stand in the room: the sports floor holds one piece, so buying the
  bench puts the bag away and it no longer stands in front of the character on the bench. Showing every item
  keeps to that too.
- The second preset character, napping over her tablet on the couch, rolls over in her sleep when tapped,
  without a word, as she does at bedtime. Neither roll-over shows the heart bubble.
- The home page shows only real data: the mode, today's timeline, the cans, what HAKU owns and wears, the earned
  keepsakes with their order, and the room colours all come from the app's stores (`HakuHomeView(snapshot:…)`).
  Mode buttons switch the real mode; colour changes are saved. The fake shop, wardrobe, keepsakes and timeline
  are gone, and day/night and "fill the room" are DEBUG only. The room has named zones and slots for later
  rearranging; the right wall hook moved left so the wardrobe no longer hides it.
- A room item from the shop no longer stands in HAKU's 下班 backdrop. Bought room items live in HAKU's home.
- VoiceOver reads the unboxing as "开箱：" and the item's name instead of the character's mode.
- The shop's 衣服 / 房间 tabs switch at once: the black fill no longer slides across to the tapped tab.
- The second preset character has the home page too: her home button, the shop's 衣服 / 房间 tabs, and her
  keepsakes on the home page's shelf instead of in the shop.
- The home page is in every build, not only DEV and STG: HAKU's home button on the home screen opens it, and his
  shop always has the 衣服 and 房间 tabs with keepsakes in the home page. The second preset character keeps one
  shelf and her keepsakes in the shop until her room version is ready.
- On a Japanese or English iPhone, the Photos permission prompt for saving a share card is in that language.
- The home page's room has zones (家 区域规划 v0): a bought room item goes into its zone, and when the zone is
  full the earliest item goes into the cupboard; a keepsake is never pushed out by a purchase. Items earlier
  builds kept in storage move into their zones once. The unboxing of a room item says 「原来的 X 收进柜子了。」
  when it made room. `RoomLayout.put` and `putAway` are ready for 整理.
- Opening the app, HAKU says one line at most: a celebration first, then an invite, good night, the late-night
  line, a planned task, bath time and the stretch. A mode change no longer clears it. A tap during a one-off
  animation only makes HAKU blink. At bedtime a tap gets a sleepy mumble instead of switching the side-hustle
  state, and a shake makes HAKU roll over half asleep.
- The Lock Screen and Dynamic Island countdown draws the character in the identity card's look picked on the
  iPhone, such as HAKU in tennis kit, instead of always the boxing look.
- The watch face says 还没有模式 when the iPhone has sent but no mode is set, instead of asking to open the
  iPhone.
- On the watch app and the watch face, both characters wear the look of the identity card picked on the iPhone,
  instead of the default boxing or tennis look. On cards without a look of their own, the second preset character
  also does that card's base idles on the watch.
- Swiping back to the character's page on the watch no longer replays its opening reaction, invite hop and line.
- On another identity card's day, HAKU warms up without the boxing headband and gloves.
- A new item no longer makes HAKU pop out of the gift box in boxing gloves. It wears the look of the mode it is in
  and of the user's own identity card, unless the item only shows in another mode.
- Without a mode, home and the phone widgets say 还没有模式 instead of NO MODE. A widget asks to open the app only
  before it ever got a snapshot; after that it says 到常去的地方会自己换.
- Tapping an item's price in the shop shows the character wearing it first. Cans are spent only on the confirm
  button, not on the first tap.
- With languages on, item names in the shop, wardrobe and unboxing follow the phone's language where a
  translation exists.
- Settings shows the Daily Widget link only in DEV builds. Test builds don't offer it.
- The shop no longer falls back to the character's old identity card when the saved cards can't be read.
- Couch scrolling in the hours before bedtime (from 2.5 hours before it, and after midnight) no longer has HAKU
  peek at the gym bag or send the couch invite. HAKU dozes off in the blanket instead, drawn like the blanket
  until its own pose is approved.
- When the iPhone hasn't sent anything for three hours, the watch shows the character's plain mode look
  instead of staying on an old scene, such as still setting off.
- Release builds don't sell room items yet. They show only in the home page, which release builds don't open so far.
- With languages on (Debug and STG), 16 more error and reminder lines show in English: Health, Screen Time,
  places, Daily, saving records and the bedtime notification.
- Test builds can try a character together with her default mode cards (Settings, under the characters). The
  user's own cards are put aside and come back when the switch is turned off or the user switches back to
  their own character; places and learned days stay.
- Six lines now say only what the characters felt or sensed: the keepsake gift, the late-night line, the second
  preset character's boxing card line and keepsake line, the racket cheer and her focus-done line.
- The wardrobe's room shelf and the unboxing of a room item say room things go in the home page. The shelf only lists
  them, and the unboxing has one button, since room items are not worn.
- On the watch, HAKU holds his boxing gloves up beside his chin and his energy can beside his face, so the
  screen edge no longer cuts them off. The iPhone is unchanged.
- Settings can rename the three common mode cards (上班, 下班, 副业), with the same card screen and length limit
  as the first setup. Before, only the first setup could name them.
- The boxing countdown on the Lock Screen and in the Dynamic Island keeps the system font when the app is in
  Japanese, like notifications. Home Screen widgets keep the rounded Japanese font.
- When the second preset character turns away in one of her shop clothes, her back shows that top's plain
  colour instead of her own top, and her "…" bubble moves up off a set hat.
- Without Screen Time, an evening of sitting still at home shows HAKU under the blanket instead of holding a
  phone it can't know about.
- A mode switched from the 切换模式 widget now reaches the watch, the off-work notice and the gym countdown at
  once. Before, they waited until the app was next opened.
- After the off-work animation, HAKU no longer stays slumped in 上班 for the rest of the evening: leaving the
  office or the next day puts the headset back on.
- The shop catalogue has a prop colour and a gold prop (earned on the card's 10th win) for the other
  first-batch identity cards of each character. They go on sale once the character art draws them; a gold prop
  earned before its art is done is granted on the card's next win after that.
- A 模式卡 control for Control Center, the Lock Screen and the Action button: pick 副业 or the identity card
  when adding it, tap to switch to it, tap again to go back to the mode before. It shows the card's own name.
- The shop catalogue has clothes for identity cards. Cards without an outfit of their own share one of three
  base outfits (sport, outing, craft), each with two tops to buy that every card on that base can wear; HAKU's
  boxing card and the second character's boxing and tennis cards have a top of their own. They go on sale once
  the character art draws them.
- A wardrobe saved by a newer build keeps the outfits this build can't read, and an unreadable wardrobe is
  copied aside before the next save replaces it.
- With languages on, the work-day buttons in first-time setup show the phone language's weekday letters and
  start the week where the phone's calendar does. In Chinese they still run Monday to Sunday. They also fit
  narrow phones.
- The second preset character's 6 tops and 2 full sets are on sale. She wears the one of the mode she is in,
  on the home screen, the shop, the wardrobe, unboxing, widgets and the watch.
- When HAKU switches between idle scenes, only the sparkles show. The peace sign, the dumbbell reps and the
  identity card's props no longer pop in and out on every switch.
- HAKU gets up from the sofa only on a real signal: vibe coding, or getting up and walking after couch
  scrolling. Its own bath time no longer counts.
- In the good-night notification HAKU takes the headset off once instead of every 2.4 s, with no Z z z
  over the hair while sitting up. After the off-work
  animation HAKU stays relaxed until the mode changes, and "终于。" fades as the animation ends.
- With languages on, the small line under the character that says why it looks that way (gym day, couch, sitting
  too long, keeping watch at work) follows the phone's language where a translation exists.
- Today's energy has its own line under the character, saying where it comes from. When it is a guess from
  sleep, a 不对？ button opens the correction card; a long press on the character only zooms in again.
- Buying in the shop rolls the can count down and moves the bought item off the shelf smoothly. When the
  purchase can't be saved, the error stays on screen and the unboxing plays after the shop closes.
- Full energy is easier to tell apart from okay: HAKU's deadpan eyes open a notch with a glint, and KURO's eyes
  grow a size, her cheeks go pink, her ears stand up a little and sparkles show by her head.
- The shop banner and the wardrobe preview show HAKU standing, so the clothes stay in view. Before, at home they
  could catch HAKU asleep on the sofa or bent over the handheld.
- With languages on, the default card names (上班, 下班, 副业 and the character's own card) show in the phone's
  language in the wardrobe, settings and everywhere else they appear. Names you gave a card stay as you wrote them.
- The permission prompts for location, Health and Motion say "places you set" instead of naming the boxing
  gym, say the app never records your route, and say only the computed state goes to your own Apple Watch.
  They now also come in Japanese and English, following the phone's language. The 「日文和英文」 switch
  can't reach these system prompts.
- The off-work card's default name is now 「下班」, so the watch no longer cuts it to 「下班 Chi」. Names you
  already changed stay as they are.
- 27 character lines no longer tell you what to do, mention money, or claim things the app can't sense.
  For example 「起来。我先起了。」 is now 「我先起来了。……你呢？」 and the bedtime notification says
  「到你定的睡觉时间了」. The memory page and settings say 「规律」 instead of 「习惯」, and the Screen Time card no longer
  names two apps and says only this iPhone knows how long you scrolled.
- On the iPhone home screen HAKU stands 24 pt lower, so a one-line speech bubble no longer covers the tips of
  its hair, the headset band, the stars beside the headset, the gift box on its head or the sunlit window, also on
  the smallest iPhone and in Japanese. The watch is unchanged.
- In the wardrobe, changing an outfit, the previewed mode or the shelf fades over 0.25 s instead of cutting.
- The small buttons in Settings (看看, 选 App, 导出) and the place editor (取消, 设为当前位置) now have the full
  44 pt tap area. The shop banner grows with longer text instead of cutting it off.
- Opening a keepsake or going through the first-run setup no longer uses up HAKU's late-night "还不睡。" or its
  slow look up after half a day away. Both now wait for the home screen.
- The second preset character's identity-card idle moves now show on the home screen and in notifications.
  Before, those screens didn't pass her card, so only her base moves played.
- Taps, hops, speech bubbles and buttons no longer spring back and forth. Each move eases back once and stops.
  The cheer hop is lower, so the hair stays inside the card.
- The wardrobe data groups items by where they are worn: clothes, accessories, the identity card's props and
  room. Props show only in the identity card's mode, and items of another card are hidden but kept, so switching
  back puts them on again. The wardrobe screen moves to these groups in a separate change.
- In the wardrobe, item names can take two lines, and a long shelf name (Accessories) shrinks to fit its tab
  instead of breaking inside the word.
- The wardrobe screen picks a mode first, then shows four tabs: clothes, accessories, props (only in the identity
  card's mode) and room. Celebrations are the last group of accessories. Keepsakes not yet earned no longer show.
- The shop says when everything on the shelf is owned, and with no cans yet it shows how to earn them right
  under the banner. The identity card's line uses the user's own name for it (「… 那天 +5（每周一次）」) and is
  left out without a card. Clothes in the shop carry a tag naming the mode they are worn in.
- The wardrobe shows a dashed placeholder on an empty shelf and an empty 人生收藏 instead of hiding it.
- The shop catalogue has tops and full sets for both characters, each worn in one mode (work, off work, side
  hustle); a full set replaces that mode's top. They go on sale once the character art draws them.
- The second preset character can dress for four identity cards: boxing (gloves and a big bag hung top left),
  fitness (a yoga block), study (a notebook and highlighter) and art (a smock and a drawing pen), each with its
  own tap move and idle moves. The app shows them once it passes the picked card; other cards keep her tennis look.
- In first-time setup, the Chill activities say how the app senses them as 定位 (location) instead of 地点, which
  also named the places list. With languages on, those labels, the place names and the place editor title follow
  the phone's language.
- The welcome back scene no longer ends with a cut: HAKU settles back over the last second and the sofa,
  blanket, phone and crate drop a little and fade out. A tap that skips it does the same over 0.3 s.
- Tennis is her main card: she bounces the ball on a flat racket and spins the racket while idle, and a tap
  makes her swing. Boxing keeps only the gloves tapping together.
- Shop prices are lower so the first full set is about 3 to 4 weeks away: the plant 8, the cyan headband 10,
  the striped mask 12, the sandbag 15, the pink gloves 20; the second character's flower 8, scrunchie 10,
  blanket 12, lamp 15, tennis bag 20. Items already bought stay owned.
- The wardrobe opens on 下班 when the current mode has no button in the user's cards, and keepsake dates follow
  the phone's language.
- Leaving the office ends 上班 at any time, a lunch break too; coming back switches to 上班 again. Before, a
  leave earlier than an hour before the end of work hours kept 上班 until you got home.
- Settings has a 上班日 row and a 身份卡 group. Each opens the same screen as the first-run setup, so work days
  and the identity card can be set, changed or cleared later.
- On the watch the second preset character holds her racket, books, cup and tablet higher, so the bottom of the
  screen no longer cuts them off. The pen, stylus and badge are left off on the watch. The iPhone is unchanged.
- The watch no longer assumes a 23:30 bedtime when the iPhone sent none: with no bedtime set, HAKU on the
  watch and its widgets never turn sleepy.
- When the mode switches on its own, at a place, the character fades into the new outfit like a manual switch
  instead of cutting over.
- The confirmation sheets (删除全部数据, 先用默认, forgetting memories) look up their text in the String Catalog,
  so translations show.
- The Screen Time watch (pick apps in settings) now works in TestFlight (STG) builds too, not only in
  Debug. The App Store build still leaves it out.
- The on-time sleep can needs a bedtime you set. With no bedtime it is never given; with the bedtime reminder
  turned off it is still given.
- VoiceOver in the shop and wardrobe says what a buy button gets, how far a keepsake has come, and what the
  preview is wearing in the user's own mode name.
- The second preset character's keepsake unbox line is now 「……给你。收好。」, so it no longer echoes the
  first character's line.
- The home page room has walkable cells and a shortest walk from where the character stands, around furniture
  and never cutting a corner (Issue #489). The scene switches to it in its own change.
- Japanese for the second and third copy batches: home bubbles, VoiceOver lines, identity cards, first-run setup,
  shop, wardrobe, unboxing, settings, memory, place editor, item names and reasons.
- After you answer the energy check, HAKU and KURO blink once and nod while saying 「哦。」 / 「嗯。」.
- On the iPhone the second preset character stands a little lower, so her speech bubble no longer covers her
  ponytail (unbox page and home card). The watch is unchanged.
- The shop follows the identity card: the boxing gloves, sandbag and gold gloves show only with the boxing
  card, the second character's tennis bag and gold racket only with the tennis card. Items already owned stay.
  The second character's flower is now called 地上小粉花.
- The confirmation before switching characters is one whole sentence per direction and looks up the String
  Catalog, so it can be translated.
- The watch shows your own card names in the clock row, on the second page and in the watch widgets, cut to
  4 Chinese characters or 8 letters. Until you rename a card, nothing changes.
- A tired HAKU now shows it in every mode: off work he keeps smiling with half-open eyes and bags, at work and
  on the side job his eyes close further and the bags sit by the eye corners above the mask. The stars of a
  full night stay brighter and clear the headset.
- The watch has no dark band behind the clock any more; every screen keeps its own background.
- The memory page names the identity day and its first time after the card the user picked, not always 拳击日.
- With Japanese on, headings and bold text use the rounded Japanese font Zen Maru Gothic. Chinese and English
  keep the system font.
- On the watch, the second preset character says a line when tapped, from the same lines as on the iPhone.
  At bedtime, tapping five times in a row no longer turns either character away.
- The companion keeps lookout for phone use at work only while the mode is 上班. On a day off or a leave at home
  on a work day it plays the current mode instead.
- Cans follow the identity card: a 30-minute session of the picked card (its watch workout or its place) earns
  the weekly 5 cans, and its gold keepsake counts that card only. Any other watch workout of 30 minutes (not a
  walk) earns 3 cans, shared with the gym's daily 3. The shop names the card instead of "周日拳击".
- After 删除全部数据 the first-run setup opens again and the bedtime reminder switch is off, as on a fresh install.
- In boxing, HAKU now and then slips left, slips right and ducks. Tapping him in boxing makes him duck, throw a
  left hook that stops at his chest and say 「……反射。」 instead of punching at the screen.
- Daylight and going to bed on time now earn their can: 15 minutes in daylight (Apple Watch) earns 1 a day,
  and falling asleep within 30 minutes of the bedtime set in Settings earns 1 a night. Life Hub asks once
  for time in daylight in Health. Only the win is kept, never the daylight or sleep times.
- With the fitness card picked, a visit to the fitness gym earns the card's weekly cans, the same as a
  strength workout, so one session no longer pays twice.
- 删掉所有记忆 is greyed out and can't be tapped when there is nothing to forget.
- On the smallest watch, a long mode name in the clock row shrinks to fit instead of running into the clock.
- The home greeting stays on one line: the date, environment badge, can count and settings button moved to
  the row above it. The red error dot is gone; the error line under the greeting already says what is wrong.
- With no mode yet, the watch tells you to pick one on the iPhone, in smaller type, instead of the iPhone's line.
- The room bag from the shop is bigger, standing in the bottom left corner. A mode's own backdrop now holds no
  items: no heavy bag at the boxing gym, no gym bag on the floor for the fitness card, no speaker for the dance
  card and no ukulele for the music card. The dance idle keeps its shrug without the notes.
- With VoiceOver, the confirmation sheets keep focus inside and the escape gesture cancels.
- HAKU's room no longer stacks two things in one spot: the glowing monitor is smaller and stands clear of
  HAKU's ear, and steps aside for the pillow and the headphones; the room item and the running shoes step
  aside while the door, a bag or the blanket fills their corner; the bandage sits clear of the mouth and hides under the raised mask.
- The watch also plays the one-offs (a workout cheer, a Daily task done, getting up from the sofa, the
  opening of coming back), the Daily task cue and the invite, and KURO's need and overtime sign, like the phone.
- Groundwork for the watch commute: Life Hub can tell walking to work, riding the train and walking home
  between home and the office. Nothing shows it yet.
- The bedtime reminder can be turned on only after a bedtime is picked. It no longer saves the prefilled time.
- The Apple Watch plays what the iPhone home card plays: walking after leaving a place, boxing at the gym,
  lifting, running, morning, overtime, just home, the bath and the vibe-coding cans.
- While HAKU has paused an invite you kept ignoring, it only slumps on the couch with you and no longer peeks
  at the gym bag.
- Watch face widgets: on tinted faces the character is drawn as line art in the face colour instead of a flat
  shape.
- Workouts from the Health app are sorted into about ten groups (walking, cycling, swimming, racket, ball,
  yoga, dance, outdoor and more). Cans are unchanged: only boxing, 5 km runs and the gym earn.
- Deleting an added place or clearing a preset one asks first, in a Toy sheet with 留着 on the left. The place
  editor names the identity card's place after the user's card, as Settings does.
- Settings: the character choice and the times use outlined Toy controls, so they no longer show as pale grey.
- Each character has her own cans, items, keepsake progress, room traces and hidden stats. Cans go to the
  character picked when they are earned; switching asks first. Everything earned before stays HAKU's. Life
  records, sleep and the weekly changes are shared.
- KURO has her own shop, wardrobe and unboxing: her 5 items and 3 keepsakes, at the same can prices. Each
  character keeps what she wears; the home card, widgets and watch show it.
- The unboxing buttons fit the item: 现在摆上 / 先收起来 for room items, 现在用上 / 先放衣柜 for celebrations.
- HAKU's blanket is now cream with a white folded hem, two small orange-and-white cats and faint paw prints,
  everywhere it shows.
- After a night under 6 hours, HAKU sends no "出去走走" invite while you scroll on the couch that day.
- The TODAY mode log on the home screen starts a new day at 05:00, not midnight. Changes after midnight
  stay in the evening's log until 05:00.
- A failed 设为当前位置 says why in plain words, with 去设置打开 when access is off and 再点一次 otherwise,
  instead of the system error text.
- Arriving at the gym in Work or 副业 switches to Chill, unless you picked the mode in the last 2 hours.
  HAKU lifts only in Chill; switch to another mode at the gym and HAKU follows it. You still earn the
  gym can after 30 minutes there, whatever the mode. Leaving the gym keeps the mode.
- A Daily Widget task that just started shows as "现在 18:00" for 10 minutes, then the line moves on to
  "下一件". Tasks past that never show.
- Gym days follow the days you actually go: a weekday with a gym visit or strength workout in 2 of the
  last 4 weeks. Until a weekday qualifies, gym days stay Tuesday to Thursday. There is no setting for it.
- With notifications denied, Settings says so under each reminder that is on, with 去设置打开. The line goes
  away on return once they are allowed.
- Widgets redraw every 15 minutes for the next 6 hours, so HAKU's idle bits on the Lock Screen change too.
- The currency is called 能量罐 everywhere you read it: the shop, unboxing, places and VoiceOver. HAKU
  still drinks Monster. The home screen shows "你认真活过的每一天，都不该白白消失。" before any mode is set.
- The clock no longer switches the mode. Work starts when you arrive at the office and ends when you
  leave it (or by hand); before, the app switched to 上班 at 9:30 even if you were still at home. The
  off-work notice now goes out only on days you're in 上班 mode or at the office.
- The identity day follows the user's card: its warm-up line and invite use the card's own invite, and a user
  without a card has no identity day. A character's own card keeps its lines.
- HAKU's sleeping pillow is light blue, so it no longer blends into the white hair.
- HAKU stops couch scrolling when you do: it gets up 20 minutes after Screen Time last saw you on the
  picked apps (it reports every 10 more minutes of use), as soon as you walk, or when you change mode by
  hand. Before, it lay on the couch for 3 hours after the daily 30 minutes.
- Cans have caps: Sunday boxing earns once a week; runs, the gym and other wins once a day.
- An unset bedtime's times in Settings are grey without the extra fade, so they stay readable.
- The companion is called HAKU everywhere you see it: the widget name, notifications, Settings and
  VoiceOver. Code names stay RUNNER.
- Tapping HAKU on the phone plays the same body move as on the watch (pushes up a headset cup, clinks the can,
  punches, flashes the mask, glares, rolls over). Five taps in 30 seconds turn him away for a few seconds with
  "……够了。" on both.
- HAKU wears only the blue earring everywhere. The white earbud in chill, at night under the blanket and on
  walks is gone.
- Red button text uses a darker red that is readable on white and paper (`Toy.alertText`).
- HAKU and KURO cheer after every kind of workout of 20 minutes or more (tennis, swimming, yoga and the
  rest), not only boxing, runs and the gym. Cans are unchanged.
- The home card and the watch know the commute: walking from home to the office or back, riding the train or
  bus, and the moment of arriving. Life Hub asks for Motion & Fitness once; motion stays on the iPhone.
- After a workout the watch cheers for it as soon as the Health app saves it, without opening the iPhone app.
  The iPhone home still cheers the next time it opens.
- HAKU's warm-up taps and VoiceOver follow the user's identity card; only the boxing card keeps the gloves.
- At the boxing gym HAKU's heavy bag is bigger and hangs top left behind his hair, swinging from its
  chain when he hits it.
- When HAKU puts the pillow behind his shoulder to lean on it, it now lands exactly where it rests, so it no
  longer jumps from his chest to behind his shoulder.
- On small watches (40 and 41 mm) the second page fits its mode, energy and the character's line, and the
  page dots no longer sit on the card's outline. VoiceOver reads each row as one item.
- Both characters now dress for the picked identity card on the home screen, in widgets, in the notification
  and in onboarding, not only in the shop and wardrobe. On the home screen the second preset character also
  points at the door for an invite, walks after leaving a place and goes to the bath, like HAKU.
- The character on the watch face shows the same scene as the watch app and the iPhone Lock Screen (the gym
  bag, setting off, the bath) and changes its pose every 15 minutes, instead of only the plain mode look.

### Added
- Commute scenes: on the way to work HAKU walks briskly with a tote bag and yawns; on the way home he drags his
  feet with sleepy eyes. On a train or bus he stands and sways instead of stepping.
- Tapping KURO plays a move for her look: the tablet over her face, a sip from her cup, a ball bounced on her
  racket or a push of her glasses. When tired she rubs her eyes, 5 taps turn her back, and sometimes a heart pops up.
- KURO's own shop items (five to buy at HAKU's prices, three keepsakes at HAKU's milestones) and her own
  wardrobe, kept apart from HAKU's. Both share one can balance. Not shown yet; her shop opens with its pictures.
- The second preset character's shop items are drawn on her: a window flower, a scrunchie, a cat blanket, a cat-ear
  lamp, a tennis bag and three keepsakes, each in its own look, with icons and her own unboxing (she pops out of the
  box acting calm, with stars in a thought bubble). Data and screens follow in engineering's part of #192.
- 回来的时候 (animation): HAKU looks up from the phone after a short absence. After a long one it dozes on
  the sofa (or at the desk in Work), sits up, turns the phone face down, says "……又不是在等你。", pushes over a
  crate, and the cards flip one by one before the cans open together. With nothing recorded it scoots over and
  pats the seat: "……坐。". A tap skips it.
- 回来的时候 on home: opening the app after 3 or more days away plays HAKU's welcome back with what was
  recorded meanwhile, once per return, before any keepsake unboxing. Good nights while away are read back
  from Health for the sleep card. HAKU only for now. Opened at bedtime, it waits for the next open after.
- 回来的时候 (data side): after 3 or more days without opening the app, a replay of what was recorded while
  away, with up to 3 cards, or up to 5 cards and the cans earned meanwhile after 8 days or more (at most once in
  30 days). With nothing recorded, the quiet version. The return itself gives no cans. The animation comes with
  the UI part.
- During the evening extension, KURO waits at her desk with a sign showing the picked end time.
- KURO waits out a late work day at her desk, chin on hand, with the late end on a small sign above her head.
- On home, the line KURO says when tapped follows the current need, activity and moment of the day.
- 晚间延长 in Settings, off by default. On work days, still at the office in work mode after work hours, the
  character waits at the desk until the picked time. If KURO leaves after work hours on such a day, she says
  "……终于。" instead of her usual off-work line. The off-work notice stays at the end of work hours.
- KURO says her own line on the day an invite you ignored 3 times pauses for a week.
- KURO has her own lines in her own quiet voice for every mode, need, moment and idle bit, plus after a workout
  and on unboxing. Tapping her shows one in a speech bubble.
- KURO's own Lock Screen and widget lines for every scene HAKU has, plus her off-work line.
- KURO's tennis day: the boxing day rules with her own lines. Her day is learned from her sessions at the
  tennis court (a weekday in 2 of the last 4 weeks), Saturday until one qualifies. Her invites carry her name.
- A second character, KURO, picked in Settings (HAKU stays the default). Home, the widgets and the watch draw
  her in the outfit for the current mode with her energy face and bedtime look. For KURO the boxing slot
  reads 网球日, the side slot reads 备课 and the boxing gym reads 网球场.
- A second character, KURO 黒, can be drawn in CompanionKit in 4 outfits (work, chill, tennis, desk), with her
  face following energy, a sleepy face at bedtime and a gentle idle loop. It is not shown in the app yet.
- HAKU on Apple Watch: a watch face widget (circular, corner and rectangular) and a watch app that shows
  HAKU as the iPhone last saw it. The iPhone sends the state; the watch changes nothing.
- Poking HAKU on the Apple Watch plays a reaction for its state, with a light tap on the wrist: a headset cup
  pushed up ("在上班。") at work, the can held out to clink ("叮。") in Chill, a punch at boxing, the mask
  flashing </> in 副业, a roll-over when asleep or out of energy, and a glare ("……干嘛。") while HAKU is busy.
  Five pokes in a row turn HAKU's back for a few seconds ("……够了。"). Pokes change nothing.
- After long couch scrolling, as the bath or vibe coding starts, HAKU drops the phone, gets up from the sofa,
  stretches, pulls its mask up with the </> lit and says "……活过来了？". It plays at most once a day, when
  you switch within 20 minutes of the last couch scrolling at home and open the app within 30 minutes.
- Groundwork for sharing HAKU later: a separate public card that can hold only the look, mode, face and an
  optional activity, with share tiers per relationship. Nothing uses it yet and nothing you see changes.
- HAKU can call you to the bath: a towel on its head, shampoo and a rubber duck, "……去洗澡。我先占浴室了。",
  then it walks off. A tap makes it dry its hair, flicking water off.
- The bath shows on the home screen and widgets from 45 minutes before bedtime for 30 minutes, only at home
  in Chill. The Lock Screen line says "去洗澡". After a tap it does not come back that evening. No push, no cans.
- HAKU walks for up to 30 minutes after you leave home, the office or a gym, until you arrive somewhere:
  leaning in, a hop each step, speed lines and dust behind, with earbuds from home, the bag from the
  office, a towel from the gym or a bandage from boxing. It shows on the home screen and the widgets.
  The mode stays as it was.
- Daily Widget tasks whose title names one of 15 scenes (coffee, a meeting, groceries, the gym and more)
  carry that scene, so HAKU can act it out around the start. Titles are matched on the phone only.
- HAKU acts out a Daily Widget task by its title in the 15 minutes before it starts: sipping coffee, eating or
  drinks, typing on a laptop for a meeting, a phone call, a grocery tote, shopping bags, cooking, lifting,
  running, a stroll in the sun, a camera, a wave for friends, hair clippers and a sore cheek for the doctor.
  Titles that match none keep the category prop.
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
- Tap HAKU while it snacks or draws: after it hides the snack or sketchbook, it looks away and whistles a little
  note.
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
- Shaking the phone or the watch makes HAKU dizzy: swirl eyes, stars around the head and a wobble, with a line
  per mode. On a boxing day he gets pumped instead, asleep he glares and sleeps on, and three shakes in a minute
  turn him away. KURO plays her tap reaction for now.
- Press and hold HAKU for a close-up of his face; drag sideways while holding and his eyes follow. On the watch
  the Digital Crown moves his eyes too, and on the Always On screen he dozes with his eyes shut.
- After a workout HAKU celebrates in the group's own way: towel and panting for walks, a helmet for rides,
  goggles for swims, kicks, a racket, a spinning ball, a big stretch, dancing and mountains. Each has its own
  line.
- The watch app has two pages: HAKU or KURO full screen in the mode's color from the chest up, with a mode and
  how-long chip, then swipe up for today's mode time, energy and line.
- KURO reacts when the watch's crown is turned, when she's pressed and held, and after a workout: her look's
  tap move, with a heart and a line after a workout.

### Fixed
- With the app closed, arriving at or leaving a place now switches the mode, in every mode. Each launch
  (including the background one a geofence causes) replays the last state of every place fence, and the
  place handling moved into HubCore (`PlaceEvent`) with tests. A place whose stored coordinates come back a
  hair off is no longer re-added at each launch, which dropped the fence's state.
- A place event caught up at a later launch is judged and logged at the time it happened, so the 2-hour hold
  after a manual change and the work-hour rules apply as they would have then.
- The shop's room item preview keeps a still of the room under the live one, so it shows where SpriteKit can't
  draw, such as the CI simulator.
- With languages on (Debug and STG), VoiceOver reads the second preset character's overtime lines from her
  string table, so they can show in Japanese and English.
- After a workout cheer or the off-work move, HAKU can again stretch after a long sit, get up from the sofa,
  wonder if you're staying home and cheer a finished task. Before, these waited until the app was restarted.
- On a gym day you already trained, went to the gym or set off for it, scrolling on the phone no longer brings
  back the evening gym invite. The same goes for the Sunday boxing invite once you have boxed.
- The wardrobe preview and its head icons dress the character for the picked identity card, so the art
  card shows the apron and sketchbook instead of the boxing kit.
- Unboxing a top or full set shows HAKU in the mode it is worn in, not always off work.
- The wardrobe keeps what a newer build put on (new slots or modes) instead of losing the whole wardrobe,
  and writes it back when saving.
- Watch: the app opens without the system killing it (a hand-made pager replaces the vertical page view),
  HAKU is a little smaller, waking is smoother, and a shake still counts right after the screen dims. (#231)
- Watch: the app has its own icon. (#230)
- A mode carried over from yesterday shows when it really started in the TODAY log. (#232)
- The iPhone launch screen shows HAKU. (#233)
- HAKU no longer grows a peace-sign hand inside boxing gloves. (#239)
- With KURO picked, the small widget, the money bar and the unboxing sheet use her colours. On a tinted or
  monochrome Lock Screen the widget head is drawn as line art. (#238)
- The iPhone app stays light when the system is dark; the boxing countdown text stays dark on its coral card;
  the watch mode chip shrinks instead of running under the clock. (#240)
- The settings gear and small Settings buttons are at least 44 pt. Error messages show dark text with a red
  warning icon. (#241)
- With KURO picked, her shop and wardrobe tiles use her own colours. (#243)
- With KURO picked, a tinted Lock Screen or watch face draws her head as line art instead of one solid shape. (#248)
- With KURO picked, chill is called "下班" and the four modes show her own icons. (#250)
- KURO now plays a move and says her own line for the off-work notice and the one-offs (staying in, a stretch,
  coming back, a Daily task done, a cheer). (#242)
- KURO's body moves for every need, activity and moment, not only her line; tapping her while she rests her chin
  at the desk makes her look up. (#247)
- Leaving the office in the evening ends work even if that leave was missed: from 17:30, being away from the
  office or arriving home switches to Chill at the next place event or app open, also within 2 hours of a
  manual change, unless you changed the mode after leaving. The debug log now says why a place event kept the mode.
- Switching mode and back within 2 minutes now updates the widgets and the Apple Watch too. Before, they
  kept showing the mode you had undone.
- A night of sleep imported again with new numbers now updates HAKU's face in the widgets and on the watch.
- The watch keeps the newest state from the iPhone when two arrive out of order.
- KURO's keepsakes granted by the previous two builds stay hers, and a keepsake is never granted twice.
- With KURO, the mode buttons, TODAY log, control and watch use her card colors, and her tennis and desk
  modes read TENNIS and DESK instead of BOXING and SIDE. Her desk time shows her tagline, not HAKU's
  side-hustle state.
- The second preset character's colored card fills the whole home card, with no white strips above and below.
- Picking KURO in Settings now updates the widgets, the watch, the invite and the bedtime notification
  right away, and ends a running boxing countdown. With KURO, the small widget, the mode buttons and the
  activity line say 网球日 / 备课 / 网球场 with a tennis icon, and Settings and the bedtime notification
  use her name instead of HAKU. The line under her home card is her own for each mode.
- The welcome back after days away no longer gets stuck when you pull down Control Center, which had
  held back celebrations and keepsake unboxing. Leaving the big return halfway still counts toward its
  once-in-30-days limit, and a return kept from bedtime is dropped when KURO is picked.
- Before any mode is picked, the home title says "NO MODE", not "NO MODE MODE".
- The second preset character's card now fills with her own color per mode (mint, sky, pink, lavender, as in
  the approved preview), dims at bedtime and squashes as the mode changes, on the home screen and the watch.
  Before, it stayed white.
- With the second preset character chosen, a tap on her on the watch is a poke: a happy hop and a light tap on
  the wrist. Expanded notifications draw her instead of HAKU, and the widget line no longer mentions HAKU's
  bath, walks or activities she doesn't show.
- The second preset character can take a tap action like HAKU's, so the app can switch the 副业 state from her.
- A mode change during the welcome back no longer clears its line.
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
- With the rain or picnic set's hat on, the second preset character's full-energy stars sit above the brim
  instead of on it.
- The second preset character's boxing and dance cards no longer stand a sandbag or speaker in the room;
  a mode's default look has no room items. The dance notes still rise.
- Tapping the second preset character at bedtime gets a sleepy mumble instead of a daytime line, and no
  longer switches the side-hustle card.
- The second preset character has the art for her new pose, dozing off hugging her tablet. It stays hidden
  until it is wired to dozing.
- When the second preset character is tapped in the middle of an idle move, what she put down slides back over
  0.2 s and notes or snow fade, instead of jumping back in one frame. A cup already at her lips stays there.
- The second preset character's taps end more smoothly: her eyes shut for a moment instead of jumping back,
  she turns away and back like a card flipping, her lap blanket slides away and back around a sip, and a tap
  still playing stops when the mode changes; the off-work move waits for the switch.
- The second preset character's boxing look now wears the white towel on her right shoulder. It hides when
  she turns away.
