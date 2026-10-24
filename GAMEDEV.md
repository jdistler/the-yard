# Making our own games for the cabinet

Goal: original games of our own, playable on the stock board as entries 13, 14, … next to the 12 built-in ones. Nothing copyrighted is involved. Everything here comes from the 2026-10-23 backup (see [FIRMWARE_ANALYSIS.md](FIRMWARE_ANALYSIS.md)), unless it is marked as something to probe.

## 1. How the stock games work (the template we copy)

Every stock game is a small, ordinary **SDL2 program** in `/data/Games/`. The menu (`/usr/bin/game`) runs `/data/start.sh <index> <smoothing> <speed>`. `start.sh` does `cd /data/Games && ./PacMan …`, waits for it to exit, and then the menu comes back. Disassembling `PacMan` showed:

| Area | What the stock game does |
| :--- | :--- |
| Start-up | `SDL_Init(VIDEO \| AUDIO \| JOYSTICK \| …)`. `SDL_CreateWindow(…, 1024, 768, SDL_WINDOW_FULLSCREEN_DESKTOP)`. `SDL_CreateRenderer(-1, ACCELERATED \| PRESENTVSYNC)`. Then it asks `SDL_GetRendererOutputSize` for the real screen size and letterboxes into it |
| Drawing | Draws its frame into a streaming texture (`SDL_LockTexture`), then `SDL_RenderCopyEx` scales it to the screen. The menu's "pixel smoothing" setting arrives as `SDL_RENDER_SCALE_QUALITY` |
| Video backend | The cabinet's SDL2 is **2.0.7**, built with **KMSDRM** video, the **opengles2** renderer (Mali GPU), a software renderer, and **ALSA** audio |
| Sound | `SDL_OpenAudio`, 44100 Hz, signed 16-bit |
| Input | `SDL_JoystickOpen(0)` and `(1)`. It handles `SDL_JOYAXISMOTION` (axes 0/1, threshold ±8192), `SDL_JOYBUTTONDOWN/UP` (button numbers 0–20 through a table), and `SDL_KEYDOWN/UP`. Escape quits |
| Volume | The volume buttons are handled by the kernel driver. The game only reads `/data/spk_volume` and shows `Games/<0-15>.png` as an overlay |
| Files | Settings and high scores live next to the binary in `/data/Games/` (`.cfg`, `.sav`) |

## 2. The controls

The control deck talks to the SoC over a serial line. A kernel driver, `uart-keys`, turns it into one Linux input device. Its key codes, from the device tree:

| Physical | Linux code |
| :--- | :--- |
| Joystick up / down / left / right | `KEY_UP 0x67`, `KEY_DOWN 0x6c`, `KEY_LEFT 0x69`, `KEY_RIGHT 0x6a` |
| Buttons a, b, c, x, y, z, l, r, l2, r2 | `BTN_A 0x130` … `BTN_TR2 0x139` |
| select, start, mode, bl, br | `0x13a` … `0x13e` |
| Volume up / down | `0x73` / `0x72` (they also reach the game; see below) |

Measured on the cabinet 2026-10-23 (probe log from `~/partycade-dumps/2026-10-23_probe_played/probe.log`). One joystick, name `uart-keys`, guid `19000000010000000100000000010000`: **0 axes, 21 buttons, 0 hats**. There is no second joystick. SDL 2.0.7 numbers the buttons like this: `BTN_*` `0x130`–`0x13e` are buttons 0–14 (`button = code - 0x130`), then the `KEY_*` codes in ascending order are buttons 15–20.

| On the panel | evdev code | SDL joystick button | Name in `cab` | Also a key event |
| :--- | :--- | :--- | :--- | :--- |
| 1-player (left of the stick, top) | `0x136` | 6 | `CAB_1P` | no |
| 2-player (left of the stick, bottom) | `0x137` | 7 | `CAB_2P` | no |
| Right of the stick, top-left | `0x131` | 1 | `CAB_TL` | no |
| Right of the stick, top-right | `0x133` | 3 | `CAB_TR` | no |
| Right of the stick, lower, shifted left | `0x130` | 0 | `CAB_LOW` | no |
| Up / Left / Right / Down | `0x67` / `0x69` / `0x6a` / `0x6c` | 15 / 16 / 17 / 18 | UP LEFT RIGHT DOWN | yes |
| Volume down / up | `0x72` / `0x73` | 19 / 20 | — | yes |

Directions are joystick buttons plus keyboard events, not axes. Holding a control makes evdev repeat (`value 2`); the SDL joystick and the keyboard path do not.

The physical deck, from the user after that session, is the whole control set:

* Left of the joystick: **1-player** on top, **2-player** below it.
* The 4-way joystick.
* Right of the joystick: three buttons, two on the top row and one below them, shifted left.
* Volume + and volume −.
* The power switch. It is not a key. It was the last thing tested, which is why `probe.log` stops at 25.3 s in the middle of an L press and has no exit line.

The user read those five numbers off the probe (2026-10-23) and they are the only five play-button codes in `probe.log`. The probe binary on the cabinet printed the Linux names A, B, X, L, and R for those same five numbers. Newer builds print LOW, TL, TR, 1P, and 2P. The driver still advertises C, Y, Z, L2, R2, select, start, mode, bl, and br (joystick buttons 2, 4, 5, 8–14). None of them are on this deck, and none of them appear in the log.

The probe's picture was rotated **90° clockwise** on the cabinet. The framebuffer itself is landscape: KMSDRM, opengles2, flags `0xe`, output and display **1024×768 @ 60**. `cab_present` draws the game upright into that framebuffer with a −90° copy, which the panel's clockwise mount shows upright. The PC window shows the upright view. `CAB_RAW_FB=1` shows the 1024×768 framebuffer instead, and `games/check.sh` checks that the top of the game lands on the left edge of that frame. Audio came up as ALSA.

**Rules for our games, so they behave like stock ones:**

* Accept input from **both** joystick events and keyboard events, through one mapping table in the code. That keeps the PC and the cabinet the same code.
* **Always have a way to quit back to the menu.** `cab_poll` returns 0 when 1-player and 2-player are held for 1 second (joystick buttons 6 and 7), or when select and start are held (the PC self-test; those two are not on this deck), or on Escape / window close. The menu is stuck until the game exits. Cutting power does not return to the menu, and it drops the last second of the log. The probe already on the cabinet is an older binary: it still quits only on select+start or 60 seconds idle.
* Don't touch the volume. Optionally show the `/data/spk_volume` overlay like stock games do.

Which verb sits on which button, and how the player's age changes difficulty without moving those verbs, is [CONTROLS.md](CONTROLS.md). New games follow that file.

## 3. What a game binary must be

* ARM 32-bit, **hard-float** (`armhf`, ARMv7 Cortex-A7, NEON available). Dynamically linked against the cabinet's own libraries.
* Built against **glibc ≤ 2.28 headers** (the cabinet has 2.29), so the binary never asks for a newer symbol version.
* Only SDL2 API that exists in **2.0.7**. SDL2_image and SDL2_mixer are present (SDL2_ttf is **not**; use a bitmap font or bundle one). The GameController API exists, but the cabinet has no mapping for this device, so use the joystick API.
* C is easiest. For C++, link `-static-libstdc++ -static-libgcc`, because the cabinet's `libstdc++` is from GCC 6.
* Small. `data` has about 24 MB free in total.
* Assets next to the binary. Run from its own directory (`start.sh` does `cd`).

## 4. Getting games onto the cabinet: the options

The menu loads exactly 12 tiles (`for i in 0..11`), with artwork in the read-only rootfs. **A 13th tile can't be added by configuration.** Extra games therefore need a menu of our own. There are two places to hook it in:

| Option | What changes on the flash | Pros | Cons |
| :--- | :--- | :--- | :--- |
| **A. "More games" behind an existing tile** | `data` only: `start.sh` plus our files. A few blocks. | Smallest change. The stock menu and system are untouched | The tile still shows the stock game's art and name. That stock game moves into our menu, or opens only when a button is *not* held, which is hidden and not obvious |
| **B. Our own main menu** | `rootfs` once: `S50ui` becomes "run `/data/launcher` if present, else the stock menu". After that, `data` only | Real entries 13, 14, … with our own art. The 12 stock games are still launched exactly as before (`/data/start.sh N …`, stock artwork reused). Falls back to the stock menu if our launcher is missing or crashes | One larger write (a rebuilt SquashFS, size to be measured offline). The menu UI is ours to build |
| C. SD card or USB stick | One device-tree edit in the `boot` partition, then nothing else | The card or stick can be gigabytes. Linux already has the drivers | The controllers are **off** in the stock device tree, so a card or stick plugged in today is invisible. Turning them on is a boot-partition write, not done. It does not make the card boot the machine. Details in § 9 |

All flash changes go through the same reversible path. Edit a copy offline, `tools/sftl_patch.py` lists the physical blocks that changed, and `tools/rk_restore.py restore` writes just those. The original backup undoes any of it ([RECOVERY.md](RECOVERY.md)).

**Recommendation:** **A** is what tile 10 does now (The Yard). **B** is the real 13th tile, later. **C** is extra room for pictures and music once a boot device-tree change is worth a flash of its own. Games that ship on the cabinet have to fit in the 24.40 MiB with nothing plugged in.

**Optional development accelerator:** the stock system already ships `adbd`, and it only lacks USB device mode. One small device-tree change in the `boot` partition should give a root shell over the Micro-USB cable with the switch ON. Then a new game build is `adb push`, with no switch flips. It's untested and needs one more flash change, so it's worth it only once we iterate a lot.

## 5. Step-by-step plan

Who does what: **PC** = the agent on this PC, no hardware. **User** = something physical. **Approval** = the user approves an exact flash change in writing.

| # | Step | Who | Flash change? |
| :--- | :--- | :--- | :--- |
| 0 | Back up `~/partycade-dumps/` off this PC | User | No |
| 1 | **Toolchain** (done): `games/toolchain/Dockerfile`, see section 6 | PC | No |
| 2 | **Game skeleton** (done): `games/common/cab.{h,c}` plus `games/probe/`; builds for PC and cabinet, smoke-tested under `qemu-arm-static` with the rootfs libraries | PC | No |
| 3 | **Prove the restore path** (done): block 91 erased, programmed, and read back with `plug_3032slc_erase`. Counts of 32 or more sectors hang the loader; the tool writes one page at a time | User + Approval | Yes (block 91, restored) |
| 4 | **Probe on tile 10 (Dig Dug II)** (flashed 2026-10-23): `/data/Games/probe`, and that tile's `start.sh` line runs it. Blocks 828, 829, 872, 873, 884, 885, 892, 893. Diff against the patched image was none | Done | Yes (`data`) |
| 5 | Probe played, log read back, and the user labeled each button from the screen. The map is in § 2 | Done | No |
| 6 | **The Yard** on tile 10 (flashed 2026-10-23): `yard` plus `keep` and `lamp`. Blocks 404, 405, 860, 861, 866, 867, 878, 879, 884, 885. The power-cut filesystem was repaired in that same write | Done | Yes (`data`) |
| 7 | **Our launcher (option B):** build it, measure the rootfs change offline (`S50ui` hook, rebuilt SquashFS, `sftl_patch.py --part rootfs`), check the stock menu fallback, then flash once | PC + User + Approval | Yes (`rootfs`, once) |
| 8 | From then on, each new game is a folder in `/data/games/<name>/` plus a line in the launcher's list: a `data`-only change. Optionally set up ADB first to skip the switch flips | Repeat | `data` only |

Each flash step follows RUNBOOK.md Phase 3, option B: a fresh `rawdump` → edit a copy → `sftl_patch.py` → rebuild check → `diff` says "none" → `restore` the listed blocks → `diff` against the patched image says "none" → switch ON and play. `tools/data_patch.py` does the middle part (edit, patch, rebuild check) in one checked command.

## 6. Building and installing (`games/`)

```
games/
  toolchain/Dockerfile   Debian 10 armhf cross GCC 8.3 (glibc 2.28) + SDL 2.0.7 headers; image "partycade-armhf"
  common/cab.{h,c}       platform layer: upright view, cabinet rotation, input map, quit, score, audio, text, log, button scripts, card files, the autopilot input
  common/cab_gl.c        OpenGL ES 2: upright framebuffer, then the same rotation as cab_present
  common/gfx.{h,c}       software 2D renderer: anti-aliased shapes, gradients, glow, outlined toon figures, text, sprites, particles, background caches (§ 12)
  common/sfx.{h,c}       synth: 16 voices, five waves, envelopes, slides, drums, and a looping step sequencer (§ 12)
  common/font8x8_basic.h public-domain 8x8 font, set proportionally by gfx
  probe/probe.c          the controls/screen/audio probe
  keep/keep.c            Keep: catch the fruit in Pip's basket. Dash, combos, three hearts, bees later. keep.sav
  lamp/lamp.c            Lamp: a lantern in a dark meadow, fallen stars that climb back into constellations, night after night. lamp.sav
  orb/orb.c              Orb: OpenGL ES 2. A lit orb on the title, then a neon well with gates, wisps, and a boost. orb.sav. Reads a card file named label
  tea/tea.c              Tea: a unicorn, a castle, and the cats. tea.sav is visits and gifts. Spec: tea/DESIGN.md
  chest/chest.c          Chest: a person, a key, a chest, and Zam. chest.sav is gems. Spec: chest/DESIGN.md
  yard/yard.c            The Yard: the menu behind Dig Dug II. Launches keep, lamp, orb, tea, or chest. Shows each game's band and what it remembers. yard.sav is the highlighted row
  test.py                every headless check: quick (self-tests, rotation), play (a session of each game), stress (the edges)
  check.sh               python3 test.py quick
  play.sh                python3 test.py play; pictures in out/play/
  stress.sh              python3 test.py all; pictures in out/stress/
  feel.py                a reel of each game and a hand-response measure; pictures in out/feel/
  stage_game.py          build (if needed) and patch a raw dump. Does not flash
  Makefile               TARGET=pc or TARGET=cab; GAMES := probe keep lamp yard orb tea chest
  build.sh pc|cab|all    cab builds in Docker against the extracted rootfs, then runs check_binary.sh
  check_binary.sh        armhf, every NEEDED lib in the rootfs, GLIBC <= 2.29, GLIBCXX <= 3.4.22
```

* Build: `cd games && ./build.sh pc` for the simulator, `./build.sh cab` for the cabinet. Outputs are `out/pc/<game>` and `out/cab/<game>` (gitignored). `ROOTFS=` overrides the rootfs path (default `~/partycade-dumps/2026-10-23_raw_plug3032slc/rootfs`).
* Play on the PC: `games/out/pc/yard`. The window is the upright picture. Keys: arrows move; Z X C are the three buttons right of the stick (lower, top-left, top-right); 1 and 2 are 1-player and 2-player. Hold 1 and 2 for a second, or press Escape, to quit. A meter in the middle of the screen fills while 1 and 2 are held, so a grown-up can see the quit coming. `CAB_RAW_FB=1` shows the sideways framebuffer the panel scans. `./check.sh` is the short self-test. `./play.sh` plays a session of every game with no keyboard and checks the saves and pictures. `./stress.sh` plays the edges and then both of those (§ 8).
* Draw in upright pixels. `gfx_init` (or `cab_init`) takes the upright size: 240×320 for The Yard, Keep, and Lamp, 384×512 for Tea, Chest, and Orb. The cabinet build rotates it in `cab_present`. Do not rotate again inside the game.
* Smoke-test the ARM build without the cabinet (`qemu-arm-static` is in `~/.local/bin`):
  `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy PROBE_SELFTEST=1 CAB_SCREENSHOT=/tmp/s.bmp qemu-arm-static -L $ROOTFS out/cab/probe` must exit 0 within a few seconds (the self-test presses the lower button, then holds select+start).
* Tile 10 on the cabinet is The Yard (`GAME_NAME=yard`) with Keep, Lamp, Orb, Tea, and Chest, flashed 2026-10-23 22:00. Blocks 372, 373, 404, 405, 860, 861, 878, 879, 884, 885. Undo of that write is a restore of those blocks from `~/partycade-dumps/2026-10-23_yard5/nand_raw.bin`. The old probe binary is still sitting in `/data/Games/probe` and is not what the tile launches.
* To stage the next game, from a **fresh** `rawdump` taken in the session you will write in:

```
games/stage_game.py --raw RAW --out ~/partycade-dumps/<date>_yard --game yard --bundle keep,lamp,orb,tea,chest
```

  That builds the cabinet binaries if needed and replaces tile 10's `GAME_NAME=yard` with `GAME_NAME=` the `--game` name. `--from` overrides that when the dump's `start.sh` still says something else (the probe-era dumps say `GAME_NAME=probe`). It prints the blocks and the restore command. It does not flash. Diff RAW in that same session; it must say none. Then restore only with written approval for those blocks. A dump taken after cutting power fails `e2fsck`; staging from it needs `--repair`. A clean quit does not.

The command that installed the probe, kept here as the pattern:

```
python3 tools/data_patch.py RAW ~/partycade-dumps/<date>_probe_tile10 \
  --put games/out/cab/probe:Games/probe:755 \
  --replace 'start.sh:GAME_NAME="Mappy d":GAME_NAME=probe'
```

  It prints the blocks and the `rk_restore.py restore` command. To read a log back: `rawdump`, `sftl_rebuild.py`, extract the `data` partition (offset `0x22c00`, `0xf000` sectors), then `debugfs -R 'dump /Games/probe.log probe.log' data.img`. The log is written about once a second and on a clean exit. Cutting power drops the tail.

## 7. What fits, and how a game remembers

Measured from the fresh dump `~/partycade-dumps/2026-10-23_yard/nand_raw.bin` (sha256 `8b55b119…9e6a`). The `data` partition is ext2:

| | |
| :--- | :--- |
| Size | 30720 blocks × 1024 bytes = 30 MiB exactly |
| In use | 5737 blocks (5.60 MiB), 115 files |
| Free | 24983 blocks (25,582,592 bytes, 24.40 MiB) and 7565 inodes |
| Reserved for root | 1536 blocks (1.5 MiB). The menu is started by init, so our games run as root and may use the reserved blocks too |
| One small file | at least 1 block and 1 inode, even when the text is 8 bytes. A high-score file costs 1024 bytes, not 8 |
| Name length | 255 bytes |

The cabinet binaries were about 22 KB each (22 blocks) before the 2026-10-24 overhaul: `yard` 22432, `keep` 22504, `lamp` 22116. Each game now links the 2D renderer and the synth as well; the armhf objects say about 50 to 60 KB of code per game, still with no picture or sound files. The three of them plus three score files are under 70 KB. The same size of game, with no big assets, fits about a thousand times in the free space. A game that brings 1 MiB of pictures uses about 1024 blocks, so the free space holds about two dozen of those before it is full. RAM is 128 MiB for the whole machine, Linux included. These programs are tiny next to that. The limit that matters is the 24.40 MiB free on `data`, and that rootfs is a read-only squashfs, so everything we add goes in `data`.

There is no network, no SDL_ttf, and no second player. Draw upright. 240×320 scales by 3.2 onto the 768×1024 panel. Sound is 44100 Hz, stereo, signed 16-bit. Quit by holding 1-player and 2-player, or the stock menu never returns.

Stock titles do not share a high-score format. Each emulator writes two private files in `/data/Games`, because `start.sh` does `cd /data/Games` before exec:

| File | What it is |
| :--- | :--- |
| `<Title>.cfg` | A few binary setting bytes (4 to 7). Not text. One per title (`PacMan.cfg`, `DigDug.cfg`, …). `PacManFast.cfg` is a copy `start.sh` makes from `PacMan.cfg` |
| `<Title>.sav` | That game's own high-score RAM, written back beside the binary. Sizes differ: Pac-Man and Galaxian are 3 bytes, Dig Dug II is 80, Pac-Mania and Rompers are 2128. Some are fixed-width score-table records. There is no common header |
| `Smoothing.cfg`, `Speed.cfg` | 12 bytes each, one per menu tile, read by `/usr/bin/game`. The menu passes them as `start.sh`'s smoothing and speed arguments. A game sees smoothing as `SDL_RENDER_SCALE_QUALITY` and speed as the argv `-fast` (`cab_fast`) |
| `/data/spk_volume` | ASCII digit plus a newline (the dump has `3\n`). The volume keys are handled by the kernel. Stock games read this and show `Games/<0-15>.png`. Do not write it |

The strings `.sav`, `.cfg`, and `/data/spk_volume` are in the Pac-Man binary. Our games must not use a stock title's name. `cab_score_load("keep")` / `cab_score_save("keep", n)` use a text file `keep.sav` containing one line, `best N`, fsync'd, in the current directory. `lamp.sav` is the same for Lamp. `yard.sav` stores the last highlighted row of the menu, in that same one-line form. The function refuses `PacMan`, `DigDug`, `probe`, and the other stock names. A new score file appears the first time a game saves, and it occupies one 1024-byte block.

A longer save is the same idea: one file per game, a temp file, `fflush`, `fsync`, `rename`, then an `fsync` of the directory. ext2 has no journal, so the directory sync is what makes the new name survive a power cut. A record below 0 or above 1000000 loads as a missing file: a value that does not fit in a signed int comes back negative, and either one would freeze the record. There is no shared save slot and no battery-backed RAM. The ext2 free space above is the whole budget for saves, binaries, and pictures together. A save can be as large as that free space; a one-line score is the right size for a high score. The cabinet clock is not set, so file timestamps stay at the epoch. Cutting power can drop the last second and dirty the filesystem, which is why the rename is fsync'd first and why a dump after a power cut needs `--repair`.

`probe.log` on the chip from the first play test is damaged: the power cut left two of its blocks claimed twice, and its timestamp is the epoch because the cabinet clock is not set. `e2fsck` without a repair refuses that filesystem. Staging from this dump uses `--repair`, which fixes the copy and includes those blocks in the write. The stock high-score files are separate and are not rewritten by that repair unless `e2fsck` itself has to.

## 8. Driving the simulator from this PC

`games/test.py` plays every game with no keyboard and no cabinet, in a fresh temporary directory that stands in for `/data/Games`. `check.sh`, `play.sh`, and `stress.sh` call it with `quick`, `play`, and `all`. The 2D games run under the dummy SDL driver; Orb runs under `SDL_VIDEODRIVER=offscreen`, because a GL context needs that and `dummy` cannot make one. Orb on this PC needs Mesa's EGL and GLES libraries (`libegl1`, `libgles2`).

Two drivers press the buttons:

* `CAB_SCRIPT`, a file of the deck's buttons on player 0, for exact presses (a quit chord, a held button across a launch, TL and TR on a cat).
* `CAB_AUTOPLAY=1`, each game's own built-in player, for a long session. It is the same player the attract demo uses after ten idle seconds on a title. It presses through `cab_bot`, the same input path as the deck, so it exercises the real rules. Saves are written as usual under `CAB_AUTOPLAY` (the attract demo never writes a save). `CAB_SEED=N` makes a run repeat exactly; under a script or autoplay the seed is 1 unless set.

The script format, also in `cab.h`:

```
title=Keep
5 down LOW
6 up LOW
6 down LEFT
14 up LEFT
132 shot /tmp/keep-catch.bmp
275 quit
```

`title=` selects the window title (`Keep`, `Lamp`, `Orb`, `Tea`, `Chest`, `The Yard`). `*` matches every game. A file with no `title=` line applies to whatever is running. Frame numbers are `cab_poll` calls, starting at 0. `down` latches until `up`. `shot` saves the BMP of the frame just drawn. `quit` ends on that frame, before it is drawn, so take the shot on the frame before. `CAB_MAX_FRAMES` is the safety stop. `CAB_SHOTDIR` dumps every `CAB_SHOT_EVERY` frame (default 30). `CAB_SCRIPT_LOG=1` prints how many commands that process kept. `CAB_TESTCARD=1` paints a red band across the top and a blue band across the bottom of a 2D game's frame, which the rotation check looks for.

The Yard's script keeps counting across the game it launches, because `cab_init` loads the file once per process and does not reset the frame counter. The child game is a new process and only sees its own `title=` section. That is how one file can move the lantern, open Lamp, quit Lamp, and land back on the menu.

What the three passes check (49 checks, all passing on 2026-10-24):

* **quick:** the probe self-test; Keep's and Lamp's self-tests catch, wake, and save; the Yard's self-test and `YARD_ONCE=keep`; the 2D rotation (the top of the game lands on the left of the 1024×768 framebuffer) and the GL path drawing on the rotated framebuffer.
* **play:** every game played to its payoff and its save read back: Keep scores, Lamp completes a constellation, Tea reaches the cheer with the three gifts saved, Chest goes key, chest, sword and wins a gem, Orb crashes into the first gate (it closes the right side) and saves, and The Yard opens Lamp and comes back on Lamp's row. The pictures are in `games/out/play/`.
* **stress:** 1P+2P quits all six; Keep never lowers a record, loads an impossible record as none, starts its attract demo when idle and stops it on a press, never saves from the demo, repeats a round from the same seed, and runs `-fast`; Lamp runs `-fast` and has its demo; Tea's held button hurries the flight and pours nothing, TL and TR and LOW each fill a heart, the stick moves the ring, a gift is saved when given and the cat who kept it runs to the door next visit, a broken save is a first visit, Nib arrives on the third; Chest waits for a new press when a button is held from the launch, TL and TR shoot, a broken save opens with no gems, and the pile keeps every win; Orb copies the card label, plays an idle demo that never saves, and its pilot dives; The Yard wraps from the top row to Chest, leaves a note when a game binary is missing, and draws with the other games' saves present.

`python3 games/feel.py` plays a reel of each game with the built-in player and writes `games/out/feel/<game>/strip.png`, two stills, and `report.txt`, plus `sheet.png` with every game side by side. It also presses each game's verb on a known frame and compares the change in the picture on that frame with the change between two quiet frames. On 2026-10-24 every game answered on the press frame (for example Chest 216 pixels against 1, Keep 464 against 137). `games/test.py` is the correctness check; `feel.py` is for looking.

## 9. A thumb drive or a microSD card

Both jacks are on the metal shield. **Plugging either in today does nothing the games can use.** The kernel was built with the drivers. The device tree leaves the controllers off. There are no loadable modules; the drivers are inside the kernel image.

| | USB-A (center jack) | Micro-USB | MicroSD |
| :--- | :--- | :--- | :--- |
| Silicon | `usb@101c0000`, the host controller | `usb@10180000`, the OTG controller | `dwmmc@10214000`, 4-bit SD |
| Stock device tree | `status = "disabled"`, `dr_mode = "host"` | `okay`, `dr_mode = "host"` | `disabled`. Pins, 4-bit bus, card-detect GPIO, and 3.3 V supply are already filled in. Max clock 37.5 MHz |
| What a plug does now | The `usb-en` GPIO regulator is always-on, so the jack may already have 5 V. The controller is off, so a stick gets power and never enumerates | This is the recovery port. VBUS is diode-fed *into* the board from a PC, so the jack does not power a stick. Leave it for Mask ROM | Nothing. Linux never sees a card |

U-Boot's own tree has the 8-bit eMMC controller (`dwmmc@1021c000`, non-removable) and **not** the 4-bit SD controller. The slot on this board is the SD one. Stock U-Boot will not boot from a card in it. The env's `rkimgtest mmc 1` does not change that.

Linux already contains `usb-storage`, the DesignWare MMC host, VFAT, ext2, exFAT, and NTFS. It does **not** contain ext4. `mount` and `blkid` are in the rootfs. `mkfs.vfat` is not, so format the card on the PC. `/mnt/sdcard` exists.

`/lib/udev/rules.d/61-sd-cards-auto-mount.rules` mounts a partition whose kernel name is `mmcblk*` and whose parent type is `SD` onto `/mnt/sdcard`. VFAT is mounted with `fmask=133`, so files on a FAT card are not executable. ext2 is mounted with `exec`, so a binary can be run from an ext2 card. There is **no** rule that mounts a USB disk (`/dev/sda1`). A game runs as root and can mount one itself once the controller is on: `mkdir -p /tmp/stick && mount -t vfat -o rw,noatime /dev/sda1 /tmp/stick`.

Turning a port on is one property in the kernel device tree inside the `boot` partition: `status = "okay"` on `usb@101c0000`, or on `dwmmc@10214000`, or both. That is a NAND write of boot blocks. It has not been done. The offline tool and the flash sequence are in § 11. It still would not make the card a boot disk. After it, the card or stick is the way past the 24.40 MiB on `data`. RAM stays 128 MiB, so a game loads a scene from the card. It does not treat the card as memory.

Games already have the call. `cab_ext_root()` returns `CAB_EXT` when that directory exists (the simulator; it does not have to be a mount), otherwise `/mnt/sdcard` if that path is a mount, otherwise `/tmp/stick` if that path is a mount. On a cabinet build only, the first call tries `mount` of `/dev/mmcblk0p1`, `/dev/mmcblk0`, then `/dev/sda1` onto `/tmp/stick`, as vfat, then ext2, then exfat. A PC build never mounts. `cab_ext_read` and `cab_ext_write` take one file name, the same character rules as a score file, and writes are temp, fsync, rename. The Yard reads `label` and writes `visited`. Orb copies `label` to `orb-card`. A game that must run with nothing plugged in still fits in the 24.40 MiB on `data`. The card is extra.

## 10. How far this hardware can be pushed

Measured from the device tree, the kernel image, and the libraries in the rootfs. The scanout was measured on the cabinet (1024×768 @ 60). Free RAM while Linux is up has not been measured.

| | What it is | What to design for |
| :--- | :--- | :--- |
| CPU | Two Cortex-A7 cores, one operating point, **1.008 GHz**. NEON and VFPv4 | Game logic, particles, a softsynth. Not a software renderer for the whole panel |
| GPU | Mali-400 **MP1** (one pixel processor, `Mali_PP0` only) at **400 MHz** (`0x17d78400`). `libGLESv2.so.2` and `libEGL.so.1` are `libmali.so`. The blob is `libmali-utgard-400-r7p0-wayland.so`, compiler `r7p0-00rel0`, and it advertises **OpenGL ES 2.0** and **GLSL ES 1.00** | A small 3D scene is in range. One full 1024×768 layer at 60 Hz is about 47 million pixels a second, and one 400 MHz pixel processor can light and texture a room, a character, and a few dozen objects at that rate. Design for GLES 2.0: one color target, `mediump` in the fragment shader, short shaders. The PC's Mesa context reports ES 3.2 limits (16384² textures, thousands of uniform vectors). Those are the Intel GPU on this PC. The cabinet's queried limits are still unmeasured, because Orb has not been run there. Skinned crowds, deferred lighting, and long shaders are past this chip |
| RAM | **128 MiB** DDR at `0x60000000`, shared by Linux, the GPU, and the game | A 1024×768 frame is 3 MiB. Keep decoded pictures to a handful of megabytes. The free-RAM number is still unknown, so stay well under the 128 |
| Picture | CRTC is **1024×768 @ 60**. The panel label is 1280×1024, and that mode is not what Linux scans | Draw upright. The portrait area is 768×1024. Scales that land on whole pixels: **192×256** (×4), **384×512** (×2), **768×1024** (×1). 240×320 fills the panel at ×3.2 and is the size the samples use; it is not a whole-pixel scale, so fine art wants 384×512 or the full 768×1024 |
| Pictures on disk | SDL2_image opens `libpng16.so.16` and `libjpeg.so.62`, both present. GIF and BMP are built in. No SDL2_ttf | PNG or JPEG for art. freetype is on the system if a game calls it itself. The 8×8 font in `cab_text` is the one the samples use |
| Sound | 44100 Hz, stereo, signed 16-bit, ALSA. SDL2_mixer is built **without** Ogg, MP3, FLAC, or MOD | WAV, or a synth in the audio callback (Keep and Lamp already beep that way). One minute of stereo WAV is about 10 MiB, which is a large slice of `data` and a small slice of a future card |
| Video | The VPU node is `disabled`. `ffmpeg` is installed | No hardware video. Don't plan cutscenes as video files. Sprite animation is the path |
| Storage on the NAND | 24.40 MiB free on `data`. Rootfs is read-only squashfs | The game that runs with nothing plugged in has to fit there, saves included. A 22 KB game fits about a thousand times. A game with 1 MiB of pictures fits about two dozen times |

Smooth on this machine means one update per vsync, drawing at 384×512 or 768×1024, nearest-neighbor when the scale is an integer, and not decoding a pile of pictures in the middle of a frame. The 2D samples are the floor. Orb's idle room is the 3D floor: 44 triangles, one Lambert shader, a checker floor and a cube, drawn upright at 384×512 and rotated in `cab_gl_present` the same way `cab_present` rotates the SDL renderer. The lower button is the next step, and it is built for this portrait panel. The CPU rebuilds a short octagonal tube every frame and slides it toward the camera, so the well is endless without a long scene. One 128×128 repeating texture, generated in the game, does the stone. Fog is eye depth. The fragment shader is `mediump`, one texture fetch, a multiply, and a mix: no loop, no discard, one color target. A gate pinches one side of the tube; the fifth gate is a pillar. The ship moves and the shaft stays centered, so a hard steer still fills the frame. A vertex that would pass the near plane is held on a cap, because a clipped corner becomes a triangle over the whole picture. A crash writes `orb.sav`. That is the budget: a textured shaft, a handful of gates, a ship. A skinned crowd or a video cutscene is not. The VPU node is disabled. A 1280×1024 mode is not what Linux scans today; it would be a later device-tree change, and only a play test can show whether the panel accepts it. The cabinet has not run this GL path.

## 11. Turning on USB-A and the microSD slot

There is a path. It is offline until a fresh dump and a written approval. `tools/enable_storage.py` never talks to the cabinet.

Linux checks `status` with `strcmp`. The stock value is the 9-byte string `disabled`. Overwriting those 9 bytes with `okay` and five extra NULs turns the node on and moves no other byte in the tree. The boot image stays the same size. The tool does that for `usb@101c0000` (USB-A) and `dwmmc@10214000` (the 4-bit SD slot). It leaves three nodes alone:

| Node | Why it stays |
| :--- | :--- |
| `usb@10180000` | The Micro-USB OTG port. It is already `okay`, and it is the Mask ROM recovery jack. VBUS feeds into the board |
| `dwmmc@10218000` | SDIO. Not the card slot |
| `dwmmc@1021c000` | The 8-bit eMMC controller. This board has no eMMC. U-Boot's tree is the one that mentions it, and that tree has no SD controller, so a card still will not boot the machine |

```
python3 tools/enable_storage.py report ~/partycade-dumps/extracted/bootimg/rk-kernel.dtb
python3 tools/enable_storage.py patch ~/partycade-dumps/extracted/boot.img -o /tmp/boot-storage.img
python3 tools/enable_storage.py report /tmp/boot-storage.img
```

A check on 2026-10-23: the report starts with both targets `disabled` and the three leave-nodes as above. The patch writes 4718592 bytes, the same size as `boot.img`. The second report shows `usb` and `sd` as `okay`. Sixteen bytes differ (eight per node). The source `boot.img` is unchanged. `/tmp/boot-storage.img` is a scratch file. It is not a flash candidate, and a block list computed from an old dump is stale the moment the cabinet boots, because SFTL moves pages.

When the time comes to flash, the sequence is the same shape as every other restore, and the block list is printed that session:

```
# Cold plug. RAW is a rawdump from this session.
python3 tools/sftl_rebuild.py RAW logical.img
dd if=logical.img of=boot.img bs=512 skip=2048 count=9216
python3 tools/enable_storage.py patch boot.img -o boot-storage.img
python3 tools/enable_storage.py report boot-storage.img
cp logical.img logical-storage.img
dd if=boot-storage.img of=logical-storage.img bs=512 seek=2048 conv=notrunc
python3 tools/sftl_patch.py RAW logical.img logical-storage.img OUT --part boot
python3 tools/sftl_rebuild.py OUT check.img
cmp logical-storage.img check.img
```

`boot` is logical sector 2048, 9216 sectors (`captures/partitions.json`). `--part boot` refuses a change outside that partition. Then `rk_restore.py diff`, and `restore` only the blocks the patch printed, after written approval of that exact list. A bad device tree comes back by restoring those same boot blocks from the backup. Never write block 1023. Do not send eFuse, force-erase, low-format, `WRITE_LBA`, `CHANGE_STORAGE`, or `DEVICE_RESET`.

After a successful boot with the new tree, format the card on the PC. FAT is for pictures and saves: udev mounts an SD card at `/mnt/sdcard` with `fmask=133`, so those files are not executable. ext2 is for a binary, because that mount has `exec`. ext4 is not in this kernel, so an ext4 card will not mount. A USB stick is not auto-mounted; the cabinet build of `cab_ext_root` mounts `/dev/sda1` itself. The simulator side is already live: `CAB_EXT=/path/to/dir ./play.sh` is the card, and The Yard and Orb use it.

## 12. The engine and the games, after the 2026-10-24 overhaul

The first builds drew with `SDL_RenderFillRect` and the 8×8 font, and each game had one sine beep. Every game was rebuilt on two small libraries in `games/common/`. Nothing here is on the cabinet yet: the chip still has the 2026-10-23 22:00 build (STATUS.md).

**gfx** draws into one 32-bit frame in RAM at the game's upright size, then `gfx_present` uploads it to one streaming texture, the way the stock emulators draw (§ 1), and `cab_present` rotates it. It needs nothing newer than SDL 2.0.7, no SDL_ttf, and no picture files.

* Shapes: rectangles, rounded rectangles, circles, ellipses, rings, triangles, polygons, thick lines, stars, and hearts, all with anti-aliased edges. Dithered vertical gradients. Additive glow.
* Toon figures: a figure's parts are drawn twice (`toon_pass` 0 then 1), first in ink grown by a few pixels, then filled, so one outline wraps the whole body. Tea's unicorn and cats, Chest's Ned and Zam, and the key and chest are drawn this way.
* Text: the public-domain 8×8 font, set proportionally, with an outline or a shadow.
* Particles (sparks, stars, hearts, rings, floating labels), screen shake, a full-screen flash, easing curves, and a seeded RNG.
* Speed: backgrounds that never move are painted once into a surface and copied each frame (`gfx_blit`); figures that animate on a short cycle are cached per step (`gfx_blit_key`; Tea's unicorn and the far castle). Measured with callgrind on this PC, a frame costs about 1 to 5 million instructions of the game's own work (Keep about 1, Tea about 4), plus SDL's copy. That is the estimate for the 1.008 GHz Cortex-A7, not a measurement on it.
* The quit meter: while 1P+2P is held, every game shows a bar filling toward "leaving...". `cab_quit_progress` gives the fraction.

**sfx** is a 16-voice synth in the audio callback: sine, triangle, square, saw, and noise, an attack and release, a pitch slide, vibrato, and pan. A step sequencer plays looping songs written as text, one string per track (`"C5 . E5 G5 - ."`, with `K`, `S`, `H`, `C` for kick, snare, hat, clap). Each game sets its own mix with `sfx_master`; Tea and Chest stay quiet, as their specs ask.

**The built-in player.** Keep, Lamp, Orb, Tea, and Chest each carry a small player that presses buttons through `cab_bot`. On Keep, Lamp, and Orb it is the attract demo: after ten idle seconds on the title the game plays itself with "demo" on screen, and any real press hands it back. The demo never writes a save. `CAB_AUTOPLAY=1` runs the same player from the first frame for the tests and the reel.

What each game is now:

| Game | Band | The stick | `LOW` (and `TL`, `TR`) | What it remembers |
| :--- | :--- | :--- | :--- | :--- |
| The Yard | menu | Up and down (left and right too) pick a row; held, it repeats | Opens the row | `yard.sav`, the row. Each row shows its band (ALL, 4+, 5+, 8+) and the other games' saves |
| Keep | walk-up | Pip walks the basket along the orchard floor | Starts, then dashes the way Pip leans | `keep.sav`, the best score |
| Lamp | walk-up | Wren walks the meadow; walking into a star wakes it | Lifts the lamp: a wide flare that costs oil and scares moths | `lamp.sav`, the most nights woken |
| Orb | two-verb | Steers the orb | Dives; held (`LOW` or `TL`) while diving, boosts for double points | `orb.sav`, the best score |
| Tea | little | Any direction moves the ring to the next cat | The care in the picture over that cat | `tea.sav`, visits and gifts |
| Chest | walk-up | Ned walks | A bolt the way he faces; with the sword, a laser | `chest.sav`, gems |

* **Keep.** A sunset orchard. Fruit shakes on the branch before it drops, and its shadow on the grass sharpens as it falls, so the landing spot is a picture. Apples are 1, pears 2, gold star fruit 5. Six catches in a row raise the multiplier, up to ×5. A miss splats and costs one of three hearts. After 10 points bees come down in a zigzag; catching one costs a heart. Speed and the number of fruit in the air rise with the score. `-fast` starts harder.
* **Lamp.** The meadow is dark except for the lantern's light. A sleeping star breathes a faint glow so it can be found. Waking one sends it up into the sky band, where it takes its place and a line joins it to the last one. A full set is a constellation (the Kite, the Teacup, the Cat, the Key, the Fish, the Crown, the Whale, the Teapot, the Dragon); then the next night has more stars. The lamp burns oil: fireflies refill it, moths from night 3 nibble it. Run dry and the light shrinks to an ember for two and a half seconds, then relights with the stars already woken still awake.
* **Orb.** The title is a lit orb over a grid, turning; the stick yaws it. The well is a tube of panels whose seams glow in a color that shifts with depth. The first four gates teach the four sides; after that they are random per run, with a pillar and a ring (only the middle open) from the tenth. Wisps are points, and catching several in a row is a chain. Speed rises with distance. The HUD is drawn with gfx at 192×256 and laid over the 3D frame as one texture.
* **Tea and Chest** follow their specs (`games/tea/DESIGN.md`, `games/chest/DESIGN.md`), lines included. Their rules and timings were kept; the pictures, the motion, and the sound are new.
