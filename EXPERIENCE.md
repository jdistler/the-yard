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
