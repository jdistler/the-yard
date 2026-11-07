# The Shelf: console and arcade games from the microSD card

Home's **GAMES** section (after CLASSICS): a card per row (PARTY PICKS, then one per system). The lower button
opens the browser (`games/love/home/shelf.lua`): a row per system, box art, and a panel with the year, maker,
a one-line blurb and what each button does in that game. Choosing a game hands the screen to **play**
(`games/native/play`) through homeloop; holding 1-player + 2-player for a second comes back to the browser,
on that game. Research and history: `~/Projects/partycade-shelf` (its notes predate this and are partly wrong;
see "What the research notes got wrong" below).

## Pieces

| | Where | What |
| :--- | :--- | :--- |
| Player | `games/native/play/` (built by `games/Makefile` as `out/cab/play`, 190 KB) | A libretro frontend on the cabinet runtime (`engine/cab_gl.c`): KMSDRM, GLES 2, the deck through `cab_poll` (quit meter included), ALSA through SDL. `play <system> <rom>` |
| Systems | `games/native/play/play_sys.h` | Core per system, which RetroPad button each deck button is (read from each core's source), the legend, core options |
| Cores | `games/shelf/build_cores.sh` -> `~/partycade-build/cores` | fceumm, gambatte, gpsp, snes9x2005 (+2010), mednafen_pce_fast, mednafen_ngp, picodrive: armhf, Cortex-A7 NEON, glibc <= 2.29, C++ with static libstdc++, each passed by `games/check_binary.sh`. MAME 2000/2003 and Genesis Plus GX are the squashfs's own |
| Browser | `games/love/home/shelf.lua` | Rows, art (decoded on Home's worker thread, 40 kept), the get-ready picture, `/tmp/shelf.ret` to come back |
| Launch | `homeloop.sh` `shelf` request | `shelf <system> <file>`: system `[a-z0-9]`, file without `/` or a leading dot, must exist in `library/<system>/` |
| Index | `tools/shelf_index.py` + `games/shelf/curation.tsv` | `library/index.tsv` and `library/art/` (libretro-thumbnails, fitted to 180x240); titles, years, makers, blurbs, button names, tags (party, solo, hide) |
| Install | `games/cart push` (player, cores), `tools/shelf_sync.sh` (games, index, art) | Card only: `/data` has ~1.4 MB free |
| Tests | `tools/play_cab.sh SYSTEM ROM SECS [ACTIONS]` | One game on the glass, remote presses (`tools/cab.sh key`), real screenshots (`tools/cab.sh shot`), the player's timing log |

Card layout (`/mnt/sdcard/library/`): `bin/play`, `cores/`, `<system>/` games, `index.tsv`, `art/<system>/`,
`saves/<system>/` (battery saves `.srm`; MAME's `hi/`, `nvram/`, `cfg/` under `saves/arcade/mame2000/`),
`system/` (MAME's `hiscore.dat` under `system/mame2000/`), `recent.tsv`.

## Controls

The deck: 1P over 2P left of the stick; the stick; two buttons on top, the lower one beneath them shifted
left (GAMEDEV.md section 2). In every game: **1-player is Start, 2-player is Select**; on arcade boards 1P is
"play" (a coin, then Start, in one press) and 2P a coin. Holding both for a second leaves (the meter shows);
while both are held neither reaches the game. Lower / top-left / top-right per system:

| System | Lower | Top-left | Top-right |
| :--- | :--- | :--- | :--- |
| NES, Game Boy | A | B | |
| SNES | B | Y | A |
| GBA | A | B | R |
| Genesis | B | A | C |
| Master System, Game Gear, SG-1000 | 1 | 2 | |
| PC Engine | I | II | |
| Neo Geo Pocket | A | B | Option |
| Arcade | 1 | 2 | 3 |

The player's legend under the picture names each button by what it does in that game (`curation.tsv`) and
darkens the ones the game doesn't use.

## Measured on the cabinet (2026-11-07)

Emulation alone (`PLAY_BENCH`, niced, next to Home): Game Boy 456 fps, GBA (Aria of Sorrow) 223, Master System
211, PC Engine 210, SNES (Donkey Kong Country) 163, NES (Contra) 134; Genesis Plus GX 122, PicoDrive 281 (so
Genesis, Master System and Game Gear use PicoDrive). MAME 2000 runs 26 of the 28 arcade sets on the card at
112-466 fps (Final Fight, Simpsons, TMNT, X-Men, Vendetta and Strider included); `ghoulsu` and `sengoku` crash
(hidden). Player rss 5-26 MB; 60-72 MB left for the machine.

On the glass (`tools/play_cab.sh`): Super Mario World 58.6-59.4 fps, Sonic 2 59-60, Pokemon Crystal 59.8, Aria
of Sorrow 59.6, Contra (NES) 59-59.7, 1942 59.8-60, Final Fight 56 (on the old draw path; not re-measured).
The browser 60 fps. The full loop (Home -> GAMES -> browser -> 1942 -> 1P coins and starts -> hold 1P+2P ->
back on 1942 in the browser) verified with remote presses and screen grabs.

What it took: the Mali is fill-bound. Through cab_gl's upright target a frame was three full-screen passes and
SNES ran 35-40 fps; drawn straight onto the turned framebuffer, with a clear first (a tiled GPU otherwise reads
the old frame back into every tile), it is the game's pixels plus the bands. Sharp pixels at non-whole scales
are a whole-number nearest pre-scale, then one bilinear stretch (mediump fragment shaders cannot do "sharp
bilinear" in one pass).

## What the research notes got wrong (fact-checked 2026-11-07)

* **"Stock RetroArch 1.7.4 plays the cartridge systems."** Its udev input reads arrow keys only from devices
  tagged `ID_INPUT_KEYBOARD`; the deck is tagged a joystick and its stick sends `KEY_UP`..`KEY_RIGHT`, so the
  stick would be dead, and there is no uinput to fake a pad. It also cannot draw our marquee, legend or the
  cabinet's quit meter. Hence `play`.
* **1-player and 2-player "never gameplay".** Almost every console game needs Start at its title screen, and
  every arcade board a coin. They are Start/Select (coin+start on arcade); only the held pair is the quit.
* **The SD slot needs a boot write (phase 1).** Done 2026-11-01 (SDCARD.md); the card was already mounted.
* **MAME 2000 is for "late-1970s boards" only; CPS1 and the Konami beat-'em-ups are out.** They run at
  112-125 fps here.
* **Genesis Plus GX is the Genesis player.** It keeps up in benchmarks but its gameplay frames (13 ms) drop the
  picture to ~41 fps; PicoDrive (ARM assembly) is 2.3x faster.
* **`/userdata` has 5 MB free.** It has ~1.4 MB. Nothing of the Shelf lives there but homeloop's few lines.
* **Picture: integer scale, letterboxed.** A Game Boy at 4x is 640 wide on a 768-wide glass; the player fills
  the width at the right aspect with sharp pixels instead, and stands vertical arcade boards up to fill the tall
  screen.

## Testing pipeline (`tools/shelf_check.py`)

Every game, every time the library or the player changes:

1. **PC pass** (~3 min, 144 games): `games/out/pc/play` with x86 builds of every core (`~/partycade-build/pc-cores`)
   and a scripted deck (1P a few times, then right held and the lower button), 40 s of game time each. A game
   passes when it loads, its picture has detail and changes, and it makes sound. Pictures every 5 s; a
   contact sheet per system; `report.md`, `results.tsv` in `~/partycade-build/check/latest`.
2. **Cabinet pass** (`--cab`): each game's emulation speed and sound level on the cabinet's CPU and cores
   (`PLAY_BENCH`, which also coins and starts), one at a time, waiting for 50 MB free and capped at 100 MB.
   The cabinet's MAME 2000 (2020 build) is the reference for arcade sound: today's source, built for the PC,
   is silent on Bomb Jack, Joust and Defender, which have sound on the cabinet.
3. **By eye**: a flag a person checked and found fine goes in `games/shelf/reviewed.tsv` (name-entry screens,
   RPG menus and walls the script walks into look "stuck").
4. **On the glass**: `tools/play_cab.sh` for one game with remote presses and screen grabs.

First run (2026-11-07): 129 of 144 passed the PC pass; the 15 flags were 10 false (reviewed), 3 PC-core
silences, and two real: 1943 never started (the coin-then-Start press came too fast: fixed, 6 frames of coin,
a third of a second, Start) and Joust/Defender stopping on FACTORY SETTINGS RESTORED with blank memory
(fixed: `games/shelf/nvram/`, seeded onto the card by `tools/shelf_sync.sh`). Removed from the card:
`ghoulsu`, `sengoku` (they crash MAME 2000), kept in `~/partycade-card/unplayable/`.

## Arcade section and high scores

Home's **ARCADE** section (after CLASSICS): a card per board, its title screen and its leaderboard (the
record, its initials, 2nd and 3rd), the score on the info panel, the top five on the get-ready picture. The
lower button goes straight into the game. Back with a better record: the classics' confetti and
"NEW HIGH SCORE!", with the initials. The initials are entered in the game's own name entry, so they are
the board's own table, kept across power-off.

The tables: `games/shelf/scores.tsv` says where each board keeps its table and how (record length, BCD or a
digit a byte, the letter codes), `tools/arcade_scores.py` decodes them (the reference), `shelf.lua` the same
in Home. 18 boards so far; checked against the board's own screen: Contra, Donkey Kong, Pang, Joust (the
DAILY BUZZARDS table; its JOUST CHAMPIONS table is a different layout, not decoded yet), Simpsons, Defender.
Not decoded yet: Bomb Jack, Circus, Elevator Action, TMNT, Tron, Vendetta, X-Men, Dig Dug (also a Classic).
Mario Bros. is silent: this MAME plays its sounds from separate sample recordings (`mario.zip` of samples,
not on the card).

Per-game buttons: `curation.tsv`'s last column, e.g. Defender `B|A|R` (fire, thrust, reverse).

## Next

* High scores for the party picks (arcade `.hi` tables already persist; console scores by reading game RAM),
  initials, a scoreboard on the browser and in the get-ready picture; "pass the stick" turns.
* Pico-8 (the purchased `pico8_dyn`, gate passed on the PC) as a row of its own.
* Hearing the sound on the cabinet (nobody has listened yet; the queue and rate control are in the log).
* Final Fight and the other big CPS/Konami boards measured again on the new draw path.
