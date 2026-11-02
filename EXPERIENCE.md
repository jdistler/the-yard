# The Partycade experience: plan (2026-10-27)

The user's brief: minimise every wait, make it smooth, beautiful, delightful, with whimsy where it fits;
replace the stock "LOADING..." screens and the stock idle demo; end to end, from power-on to power-off.
Everything is checked on the real screen (`tools/cab.sh shot`, `tools/cabview/flow.py`).

## What the cabinet does today (measured 2026-10-27)

| Moment | Today | Cost |
| :--- | :--- | :--- |
| Power-on | U-Boot's "LOADING..." (magenta), kernel, stock rcS | ~3 s |
| Stock menu | 15 s intro video, copyright page, then the menu | ~22 s more |
| Between programs | `/dev/fb0`: the kernel console's white "LOADING..." | every launch and return |
| Home start (warm) | LÖVE 0.6 s + art 0.3 s + labels 0.2 s + **sounds 1.8 s** | ~3 s |
| Home start (cold) | + 1.1 s reading LÖVE's 9 MB of libraries from flash | ~4 s |
| Idle | Stock menu: Pac-Man attract demo; Home: card cycling after 45 s | — |
| Leaving a classic | Hold 1P 5 s, no feedback (the stock emulator owns the screen) | 5 s |

Found while measuring: `/dev/fb0` is shown whenever no program holds the display, and writing it takes 20 ms;
LÖVE can render an upright picture, turn it for the framebuffer, read it back and write it in ~150 ms. Volume
is the kernel's (`uart-keys` calls `/usr/bin/volctrl.sh`, which saves `/data/spk_volume`), so it works without
the stock menu. The classics' `.sav` files are their boards' high-score memory (Galaxian `60 33 00` = 3360).

## The experience, moment by moment

1. **Power-on.** U-Boot's logo (unchanged for now: it lives in the boot partition's resource image; see 8),
   then at ~2.5 s stage2 paints our boot picture into `/dev/fb0`: the Partycade marquee on the night sky, "warming
   up the neon". Home starts from `S50ui` (bound over the stock one by stage2) at ~4–5 s, with no intro video.
2. **Home's intro (power-on only).** The marquee flickers on letter by letter with a neon buzz, the grid scrolls
   in, the carousel slides up. Any button skips it. Coming back from a game there is no intro.
3. **Home.** Three sections (Classics, The Yard, More). Clean logos (cut from the settings pages, on
   transparent), each card with its own colour glow; info panel with year, blurb, Speed/Smoothing, and how to
   leave the game. Volume keys show a neon volume meter. A shooting star now and then; the marquee buzzes.
4. **Launch.** The card zooms, a coin-drop chime; Home renders a "get ready" picture for that game (its logo,
   "hold 1-PLAYER 5 s to come back" for classics, "hold 1P + 2P" for ours) into `/dev/fb0` and quits. The
   picture stays up while the emulator loads, so there is never a white "LOADING...".
5. **Back from a game.** homeloop writes the "welcome back" picture (Home's background with the marquee, made
   by Home once per boot in `/tmp`) the moment the game exits; Home starts warm (target under 1 s: synthesised
   sounds made with FFI, the music after the first frame) and fades in on the same card.
6. **Idle.** After 45 s, attract: the carousel tours the games with their blurbs. After 3 minutes, the night
   scene: the grid dims, the marquee sleeps ("zzz" in neon), Pac-Man chases ghosts along the horizon and the
   ghosts turn blue after a power pellet. The first press wakes it and is not used as a choice.
7. **The original menu** stays a card under More (with the freeze-file fix and the intro skipped).

## Status (2026-10-27, end of the session)

Done and verified on the cabinet: 1–5 and 7 below (with `flow.py front`, `cab.sh film`, `cab.sh bootfilm`).
6 tried (a read-ahead in stage2): no gain, left in. 8: U-Boot's and the kernel's logos replaced and written (approved);
high scores not started. The night scene and attract were checked with short timers.

Added after the plan (the user: "delight me and never frustrate me"): exit-hold ticks for the classics, high
scores and their celebration, LAST PLAYED, a way back from the original menu, deep sleep, party mode.

**The night show (2026-10-27, games/love/home/night.lua):** idle 3 minutes, then a three-hour night that
loops: dusk (10 min), ~28 scenes of 3-5 minutes in a new order each night with quiet sky between (the chase,
an alien swarm with dive-bombers, constellations drawing arcade shapes, fireflies spelling words, an aurora, a
meteor shower, a neon city with a blimp, a UFO taking a ghost, a digger tunnelling under the grid, the sign's
dreams), a 15-minute rest stretch (dark, a few fireflies, music silent), and dawn. A moon crosses the sky. All
ten at 60 fps on the cabinet. HOME_NIGHT_SPEED fast-forwards it, HOME_NIGHT_SCENE shows one scene.

**Music and the idle shows (2026-11-01, games/love/home):** every moment has its own original chiptune now,
streamed by a little synth in its own thread (`synth.lua`, `songs.lua`, `musicthread.lua`, `music.lua`): Neon
Home (the menu), Insert Coin (attract), Channel Surfing (the TV guide), and in the night show Sundown (dusk),
Night Air (the quiet sky between scenes), one per scene (Midnight Chase, The Swarm, Starfield, Firefly Waltz,
Aurora, Falling Stars, Neon Nights, Close Encounter, Underground, Lullaby), silence for the rest stretch, and
First Light (dawn). Crossfades between them; the sound effects stay as they were. `songcheck.lua` checks every
song on the PC (`games/out/love-x86/luajit games/love/home/songcheck.lua [WAVDIR]`). On the cabinet the thread
uses ~11% of a core at its busiest.

The second idle show, **the Freedom Show** (`freedom.lua`, 9.5 minutes, satirical and very patriotic): the
flag raised at dawn (a cloth mesh with its stripes and stars painted once), the bald eagle lands on the pole, a
Pac-Man parade in Uncle Sam's hat, jets in red/white/blue smoke; RED ALERT (klaxon, searchlights, a ghost field
reporter, the invaders descend); the Battle of the Backyard (they burn holes in the flag that ripple with the
cloth, they taunt, a star-spangled cannon, the eagle dives through a column, the jets strafe a row, Pac-Man eats
the FREEDOM PELLET and the scared invaders fall onto the lawn, the mothership); MISSION ACCOMPLISHED (duct tape
on every hole, fireworks, confetti, celebratory hot dogs, U! S! A!, EAGLE CAM's single tear, fireworks that
write U S A); a sunset with "America the Beautiful"; "FREEDOM WILL RETURN". Its music: a fanfare into a
Sousa-style march (quoting Yankee Doodle, with a trio on "America the Beautiful" that modulates up a semitone at
the end), Red Alert, Invader Assault, Mission Accomplished, the anthem. 60 fps on the cabinet in every act.

Which show plays is the **IDLE SHOW** card under MORE (top buttons change it, LOWER watches it now): AUTO (the
Freedom Show by day, 8 AM to 10 PM, then half an hour of the night sky in turn; the night sky alone at night),
FREEDOM SHOW, or NIGHT SKY. Kept in Home's state file. Tests: `HOME_SHOW=freedom:SECONDS` or `night` starts
Home in a show; `HOME_DT=0.0166667` makes every frame 1/60 s (PC renders: the whole show in a minute).

**The SHOWS section (2026-11-01, later):** a tab of its own (CLASSICS · THE YARD · TV · SHOWS · MORE) with a
card for each idle show: NIGHT SKY, FREEDOM SHOW, TEXAS, LONGHORNS, MISSION CONTROL, SUMMER, HALLOWEEN,
THANKSGIVING, CHRISTMAS, NEW YEAR'S EVE, and the SCHEDULE.
LOWER on a show opens a screen of tiles, one per segment with its picture (`tools/show_thumbs.py` renders them
with Home itself on the PC; `games/love/home/thumbs/`), to watch any part now; the show plays on from there and
any button goes back to the tiles. The SCHEDULE's AUTO follows the calendar (`shows.lua` `pick`): Christmas
(Dec 1-26), Thanksgiving week, the Freedom Show for July 1-7 and the Memorial Day and Labor Day weekends, Texas
for Texas Independence Day and bluebonnet season (Mar 15 - Apr 30), the Longhorns from two hours before kickoff
to the end of a game, ordinary days taking turns (Texas, Freedom, and the Longhorns in football season), the night
sky at night (10 PM - 8 AM) and for half an hour between shows. Added overnight 2026-11-01: Halloween (Oct 15-31,
and Halloween night from 5 PM), New Year's Eve (Dec 27 - Jan 1, and live from 6 PM on the 31st to 1 AM, the
countdown ending at midnight), Mission Control (July 16-24, and in the ordinary-day rotation), Summer (every other
turn June - August). The LONGHORNS card shows the next game, the live score, or the final; the SCHEDULE card says
what AUTO plays next.

* `texas.lua` (10 min): a day across Texas, Galveston to Big Bend, with Round Rock's rock and donuts; ten tunes.
* `longhorns.lua` (9 min): game day on the Forty Acres, the band (Big Bertha; TEXAS spelled from above), Smokey
  and the flag run, Hook 'em, a drive to a touchdown, the Red River Rivalry at the State Fair (the Golden Hat stays
  in Austin), the Tower lit orange. Game days from `utgame.lua`: ESPN's public team endpoint fetched by tvnet's
  `get` (countdown, live score, final; a TOUCHDOWN TEXAS celebration when Texas scores). Our own drawings and
  tunes (Texas Fight and The Eyes of Texas are not quoted).
* `thanksgiving.lua` (8 min): the parade, the Great Turkey Chase, autumn, the table, football on TV, pie.
* `christmas.lua` (9 min): the house in lights, the sleigh, a Texas Christmas, the tree, cookies, Silent Night;
  public-domain carols.
* `halloween.lua`: the haunted house, jack-o'-lanterns, the graveyard, trick or treat, a storm, BOO!
* `newyear.lua`: the party, resolutions, the ball drop, midnight, Auld Lang Syne. On the night (or with
  `HOME_NY_NOW`), live to the second.
* `space.lua` (Mission Control): Houston, the Saturn V, a launch and staging, the station over Texas, the Moon,
  splashdown; quotes Strauss's Zarathustra sunrise and The Blue Danube (public domain).
* `summer.lua` (8 min): Lake Travis, Barton Springs, snow cones, tubing the river, a summer storm and its rainbow,
  fireflies on the porch, sunset off the dock.
* `tools/show_lint.py [SHOW...]`: plays every show start to finish on the PC (fixed 1/60 s frames), fails on any
  Lua error, and writes contact sheets.
* `showlib.lua`: what they share (pictures made at a show's start and released at its end, particles, fireworks,
  smoke, a cloth flag, captions on plates).

The menu now paints neon titles only for the cards near the chosen one (GPU memory in the menu 32 -> 20 MB).

**Memory (2026-11-01):** Home has ~35 MB on this cabinet and the Mali driver keeps ~20 MB of it for itself
(`/sys/kernel/debug/mali/gpu_memory`: 32 MB in the menu, of which LÖVE's own textures were 12 MB). The Freedom
Show on top of the menu's pictures ran the OOM killer, so an idle show now frees the menu's logos and neon labels
(painted again on waking, the cards in view first) and the show's own pictures exist only while it plays. Home's
log line every 5 s has the Lua heap and LÖVE's texture memory.

## Work, in order (each one checked on the cabinet, committed)

1. Logos from the settings pages (done: `tools/home_art.py`); cards redrawn for transparent logos.
2. Home starts fast: FFI synth, music after the first frame, startup marks in `home.log`.
3. `/dev/fb0` pictures: launch, welcome back, boot (Home renders and saves them; homeloop and stage2 show them).
4. Home polish and whimsy: card glow per game, volume meter, shooting stars, marquee buzz, night scene, how to
   leave each game.
5. Home at power-on: stage2 binds our `S50ui` (spk-init as stock, PCBA test mode as stock, then homeloop);
   safety unchanged (1P+2P at power-on, `boot/disabled`, the try counter, homeloop's fallback to the stock menu
   after two failures).
6. Keep LÖVE warm: measure the cost of locking its touched pages in memory (`cabctl pin`) against the cold
   1.1 s; only if it fits.
7. Flows: `flow.py boot` (reboot, then Home on screen), `flow.py home` from power-on.
8. Later: U-Boot's logo (a boot-image rewrite, as before with `tools/ota_boot.sh`), high scores on the cards
   (each board's `.sav` decoded and checked against its own attract screen).
