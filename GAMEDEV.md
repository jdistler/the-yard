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
| C. SD card or USB stick | One device-tree edit in the `boot` partition, then nothing else | The card or stick can be gigabytes. Linux already has the drivers | The controllers are **off** in the stock device tree, so a card or stick plugged in today is invisible. Turning them on is a boot-partition write, not done. It is not expected to make the card boot the machine. Details in § 9 |

All flash changes go through the same reversible path. Edit a copy offline, `tools/sftl_patch.py` lists the physical blocks that changed, and `tools/rk_restore.py restore` writes just those. The original backup undoes any of it ([RECOVERY.md](RECOVERY.md)).

**Recommendation:** **A** is what tile 10 does now (The Yard). **B** is the real 13th tile, later. **C** is extra room for pictures and music once a boot device-tree change is worth a flash of its own. Games that ship on the cabinet have to fit in the 24.40 MiB with nothing plugged in.

**Optional development accelerator:** the stock system already ships `adbd`, and it only lacks USB device mode. One small device-tree change in the `boot` partition (`enable_storage.py --which adb`: the OTG port's `dr_mode` from `host` to `otg`) should give a root shell over the Micro-USB cable with the switch ON. Then a new game build is `adb push`, with no switch flips. It's untested. It can ride in the same `boot` write as the SD slot (§ 11).

## 5. Step-by-step plan

Who does what: **PC** = the agent on this PC, no hardware. **User** = something physical. **Approval** = the user approves an exact flash change in writing.

| # | Step | Who | Flash change? |
| :--- | :--- | :--- | :--- |
| 0 | Back up `~/partycade-dumps/` off this PC | User | No |
| 1 | **Toolchain** (done): `games/toolchain/Dockerfile`, see section 6 | PC | No |
| 2 | **Game skeleton** (done): the platform layer, now `games/engine/cab.{h,c}`, plus the probe, now `games/native/probe/`; builds for PC and cabinet, smoke-tested under `qemu-arm-static` with the rootfs libraries | PC | No |
| 3 | **Prove the restore path** (done): block 91 erased, programmed, and read back with `plug_3032slc_erase`. Counts of 32 or more sectors hang the loader; the tool writes one page at a time | User + Approval | Yes (block 91, restored) |
| 4 | **Probe on tile 10 (Dig Dug II)** (flashed 2026-10-23): `/data/Games/probe`, and that tile's `start.sh` line runs it. Blocks 828, 829, 872, 873, 884, 885, 892, 893. Diff against the patched image was none | Done | Yes (`data`) |
| 5 | Probe played, log read back, and the user labeled each button from the screen. The map is in § 2 | Done | No |
| 6 | **The Yard** on tile 10 (flashed 2026-10-23): `yard` plus `keep` and `lamp`. Blocks 404, 405, 860, 861, 866, 867, 878, 879, 884, 885. The power-cut filesystem was repaired in that same write | Done | Yes (`data`) |
| 7 | **Our launcher (option B):** build it, measure the rootfs change offline (`S50ui` hook, rebuilt SquashFS, `sftl_patch.py --part rootfs`), check the stock menu fallback, then flash once | PC + User + Approval | Yes (`rootfs`, once) |
| 8 | From then on, each new game is a cart in `yard.pak`: `./cart deploy` rewrites the pack in place, a `data`-only change of a few blocks (CARTS.md § 10). Optionally set up ADB first to skip the switch flips | Repeat | `data` only |

Each flash step follows RUNBOOK.md Phase 3, option B: a fresh `rawdump` → edit a copy → `sftl_patch.py` → rebuild check → `diff` says "none" → `restore` the listed blocks → `diff` against the patched image says "none" → switch ON and play. `tools/data_patch.py` does the middle part (edit, patch, rebuild check) in one checked command.

## 6. Building and installing (`games/`)

The layout, the cart API, and the work loop for a new game are in [CARTS.md](CARTS.md). In short:

```
games/
  cart                   the CLI: new, list, run, check, shots, perf, pack, deploy
  carts/<id>/            one folder per game: info.lua (the label) and main.lua (the game). yard is the menu
  templates/             blank, arcade, story
  engine/                the runtime (runtime.c, api.c, lib/*.lua) on cab.c, cab_gl.c, gfx.c, sfx.c, plus Lua 5.4.7
  native/orb/orb.c       Orb, OpenGL ES 2, its own program. carts/orb/info.lua is its menu label
  native/probe/probe.c   the controls, screen, and audio probe
  toolchain/Dockerfile   Debian 10 armhf cross GCC 8.3 (glibc 2.28) + SDL 2.0.7 headers; image "partycade-armhf"
  Makefile               TARGET=pc or TARGET=cab: out/<target>/yard, orb, probe
  build.sh pc|cab|all    cab builds in Docker against the extracted rootfs, then runs check_binary.sh
  check_binary.sh        armhf, every NEEDED lib in the rootfs, GLIBC <= 2.29, GLIBCXX <= 3.4.22
  test.py                every headless check: quick, play, stress, system (§ 8)
  check.sh play.sh stress.sh   test.py quick, play, all
  playtest.py            play a game a few frames at a time through the cabinet path, and look (§ 13)
  feel.py                a reel of each game and a hand-response measure; pictures in out/feel/
```

* **Build.** `cd games && make` for the simulator, `./build.sh cab` for the cabinet. The outputs are `out/pc/` and `out/cab/` (gitignored). `ROOTFS=` overrides the rootfs path (default `~/partycade-dumps/2026-10-23_raw_plug3032slc/rootfs`). The PC build also links `out/pc/keep`, `lamp`, `tea`, and `chest` to `yard`, so the old names still start those carts.
* **Play on the PC** with `games/out/pc/yard`. The window shows the upright picture. Arrows move; Z X C are the three buttons right of the stick (lower, top left, top right); 1 and 2 are 1-player and 2-player. Hold 1 and 2 for a second, or press Escape, to quit. While 1 and 2 are held, a meter fills in the middle of the screen, so a grown-up can see the quit coming. `CAB_RAW_FB=1` shows the sideways framebuffer the panel scans.
* **Draw upright.** A cart's label picks 240×320 or 384×512. The runtime rotates the picture for the panel. Don't rotate it again.
* **Smoke-test the ARM build without the cabinet.** `qemu-arm-static` is in `~/.local/bin`. `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy YARD_PAK=out/yard.pak qemu-arm-static -L $ROOTFS out/cab/yard --check keep` should print `ok:`.
* **On the cabinet**, tile 10 runs `/data/Games/yard`. The 2026-10-23 build there is the old five C binaries (`yard` the menu, plus `keep`, `lamp`, `orb`, `tea`, `chest`). The cart build replaces them with three fixed-size files: `yard` (the runtime, padded to 2 MiB), `orb` (padded to 1 MiB), and `yard.pak` (every cart, padded to 4 MiB).
* **Stage a build** from a **fresh** `rawdump` taken in the session you will write in:

```
games/cart deploy --raw RAW --out ~/partycade-dumps/<date>_carts --first   # the first time
games/cart deploy --raw RAW --out ~/partycade-dumps/<date>_carts           # every later time
```

  It builds for the cabinet, packs the carts, pads the files, and runs `tools/data_patch.py` on a copy of RAW. `--first` uses `--rm` for the old C games and `--put` for the three new files. Later deploys use `--overwrite`, which writes each file into the disk blocks it already owns, so only flash pages that have been written before change: the case `sftl_patch.py` handles. Deploy then writes `PLAN.md` with the block list and the restore command. It does not flash. Diff RAW in that same session; it must say none. Then restore only with written approval for those blocks. A dump taken after cutting power fails `e2fsck`; pass the same `--repair` through `data_patch.py` by hand.

The command that installed the probe, kept here as the pattern for a one-off file:

```
python3 tools/data_patch.py RAW ~/partycade-dumps/<date>_probe_tile10 \
  --put games/out/cab/probe:Games/probe:755 \
  --replace 'start.sh:GAME_NAME="Mappy d":GAME_NAME=probe'
```

To read a log back: `rawdump`, `sftl_rebuild.py`, extract the `data` partition (offset `0x22c00`, `0xf000` sectors), then `debugfs -R 'dump /Games/probe.log probe.log' data.img`. The log is written about once a second and on a clean exit. Cutting power drops the tail.

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

The cabinet binaries were about 22 KB each (22 blocks) in the first build: `yard` 22432, `keep` 22504, `lamp` 22116. The cart runtime (renderer, synth, Lua, the library, and the round font) cross-compiles to about 420 KB of armhf code (measured 2026-10-24 with this PC's cross compiler, not the Docker toolchain). The five Lua carts pack into 120 KB. The fixed slots (2 + 1 + 4 MiB) take 7 MiB of the 24.40. The same size of game, with no big assets, fits about a thousand times in the free space. A game that brings 1 MiB of pictures uses about 1024 blocks, so the free space holds about two dozen of those before it is full. RAM is 128 MiB for the whole machine, Linux included. These programs are tiny next to that. The limit that matters is the 24.40 MiB free on `data`, and that rootfs is a read-only squashfs, so everything we add goes in `data`.

There is no network, no SDL_ttf, and no second player. Draw upright. 240×320 scales by 3.2 onto the 768×1024 panel. Sound is 44100 Hz, stereo, signed 16-bit. Quit by holding 1-player and 2-player, or the stock menu never returns.

Stock titles do not share a high-score format. Each emulator writes two private files in `/data/Games`, because `start.sh` does `cd /data/Games` before exec:

| File | What it is |
| :--- | :--- |
| `<Title>.cfg` | A few binary setting bytes (4 to 7). Not text. One per title (`PacMan.cfg`, `DigDug.cfg`, …). `PacManFast.cfg` is a copy `start.sh` makes from `PacMan.cfg` |
| `<Title>.sav` | That game's own high-score RAM, written back beside the binary. Sizes differ: Pac-Man and Galaxian are 3 bytes, Dig Dug II is 80, Pac-Mania and Rompers are 2128. Some are fixed-width score-table records. There is no common header |
| `Smoothing.cfg`, `Speed.cfg` | 12 bytes each, one per menu tile, read by `/usr/bin/game`. The menu passes them as `start.sh`'s smoothing and speed arguments. A game sees smoothing as `SDL_RENDER_SCALE_QUALITY` and speed as the argv `-fast` (`cab_fast`) |
| `/data/spk_volume` | ASCII digit plus a newline (the dump has `3\n`). The volume keys are handled by the kernel. Stock games read this and show `Games/<0-15>.png`. Do not write it |

The strings `.sav`, `.cfg`, and `/data/spk_volume` are in the Pac-Man binary. Our games must not use a stock title's name. A cart's save is `<name>.sav` in the current directory, lines of `key value` (`best 12`, `pip teacup`), written whole through a temp file, fsync, and rename (CARTS.md § 4, `save`). `keep.sav` and `lamp.sav` are one line, `best N`; `yard.sav` is the menu's last row in the same form. The runtime refuses `PacMan`, `DigDug`, `probe`, and the other stock names. A new save appears the first time a game saves, and it occupies one 1024-byte block.

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

The script's `title=` is the window title, which is the cart's `title`. The menu opens each cart as a child process (`yard <id>`), so a child only sees its own `title=` section, and the menu's frame count carries on when it comes back.

What the four passes check (78 checks, all passing on 2026-10-24 after the move to carts):

* **quick:** the probe self-test; Keep's and Lamp's self-tests catch, wake, and save; the menu's self-test; `yard keep` runs a cart by name; every cart boots and runs 120 frames; the 2D rotation (the top of the game lands on the left of the 1024×768 framebuffer) and the GL path drawing on the rotated framebuffer.
* **play:** every game played to its payoff and its save read back: Keep scores, Lamp completes a constellation, Tea reaches the cheer with the three gifts saved, Chest goes key, chest, sword and wins a gem, Orb crashes into the first gate (it closes the right side) and saves, and The Yard opens Lamp and comes back on Lamp's row. The pictures are in `games/out/play/`.
* **stress:** Chest's self-aiming sword, its first fight without tricks, Zam's teleport and shield after two gems and three bubbles after three; Tea's song after the cheer; a live `playtest.py` session; 1P+2P quits all six; Keep never lowers a record, loads an impossible record as none, starts its attract demo when idle and stops it on a press, never saves from the demo, repeats a round from the same seed, and runs `-fast`; Lamp runs `-fast` and has its demo; Tea's held button hurries the flight and pours nothing, TL and TR and LOW each fill a heart, the stick moves the ring, a gift is saved when given and the cat who kept it runs to the door next visit, a broken save is a first visit, Nib arrives on the third; Chest waits for a new press when a button is held from the launch, TL and TR shoot, a broken save opens with no gems, and the pile keeps every win; Orb copies the card label, plays an idle demo that never saves, and its pilot dives; The Yard wraps from the top row to Chest, shows the Oops screen and comes back when a cart errors, leaves a note when a native program is missing, and draws with the other games' saves present.
* **system:** the sandbox stops a loop that never ends, a memory hog, a misspelled name, and a forgotten `local`, collects layers made every frame, and reaches no `io`, `os`, `require`, `load`, `debug`, bytecode, or path outside the cart; `./cart pack` builds a full-size `yard.pak` that the runtime reads, and a flipped bit drops only that cart; `data_patch.py --overwrite` rewrites a file in its own blocks on ext2 with 1 KiB and 4 KiB blocks and leaves `e2fsck` clean; each template makes a cart that runs 15 seconds on its bot; the embedded font and library match their sources.

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

### The storage plan (audit, 2026-10-24)

The microSD slot is the storage, and USB-A stays free for a network adapter later.

* **Turn on only the slot.** That is one `boot` write: `enable_storage.py --which sd` (§ 11). Add `adb` to the same write for a shell over the Micro-USB cable if the user wants it.
* **One ext2 partition on the card.** The format, the layout, and the exact commands are in [SDCARD.md](SDCARD.md). ext2 is mounted with exec, so it can hold programs such as LÖVE (§ 12); FAT can't run anything. The stock udev rule mounts every card partition on the same `/mnt/sdcard`, so two partitions would hide each other (untested; FIELD_TASKS.md task 7 checks). The kernel has no ext4.
* **Speed.** The slot's limit is 37.5 MHz on four bits, about 18 MB/s at best. Loading a scene is fine; streaming video is not.
* **Keep the NAND copy.** Everything that must run with nothing plugged in stays there: the menu, the carts that ship today, saves. The card adds; it never replaces. The runtime already reads carts from `<card>/yard/carts` (CARTS.md § 11).
* **Not known until a card is in a powered cabinet:**
  * whether the slot is fitted and wired as the kernel's tree says;
  * whether card detect (GPIO1 pin 17) works, or the `broken-cd` polling is what finds the card;
  * which mount udev really makes.

  FIELD_TASKS.md has the steps.

### Wi-Fi on USB-A, later: what it needs

Turning on `usb@101c0000` is the easy part. A USB Wi-Fi adapter then needs three more things, and the stock system has none of them:

* **A driver in the kernel.** The kernel has no loadable modules, so the adapter's driver (an `rtl8xxxu`, `rt2800usb`, or `mt7601u` class driver, plus `cfg80211` and `mac80211`) must be built in. Nobody has listed what this kernel contains. `FIELD_TASKS.md` task 1 extracts its config if it carries one, and its driver strings either way. If the drivers are missing, Wi-Fi means building a new kernel from Rockchip's 4.4 tree for this board, a bigger `boot` change.
* **Firmware files.** Most adapters load a firmware blob. The rootfs has no `/lib/firmware`, so it would go on the card or in `data`, and the kernel must be told where to look.
* **Userland.** The rootfs has `udhcpc`, `ifup`, and `dropbear` (an SSH server, already with an init script), but no `wpa_supplicant` and no `iw`. Those can be cross-built and kept on the card's ext2 partition.

A route that needs no kernel work: the ADB edit above, plus a small Wi-Fi computer inside the cabinet (a Raspberry Pi Zero 2 W, for example) cabled to the Micro-USB port as the ADB host. It reaches the cabinet's shell over the network, and USB-A stays free. That is a hardware idea, not tested.

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

Linux checks `status` with `strcmp`. The stock value is the 9-byte string `disabled`. Overwriting those 9 bytes with `okay` and five extra NULs turns the node on and moves no other byte in the tree. The boot image stays the same size. The tool does that for `dwmmc@10214000` (the 4-bit SD slot, the default `--which sd`) and, when asked, `usb@101c0000` (USB-A, `--which usb`). `--which adb` also rewrites the Micro-USB OTG port's `dr_mode` from `host` to `otg` in place, for the ADB shell (§ 4). Otherwise it leaves three nodes alone:

| Node | Why it stays |
| :--- | :--- |
| `usb@10180000` | The Micro-USB OTG port. It is already `okay`, and it is the Mask ROM recovery jack. VBUS feeds into the board |
| `dwmmc@10218000` | SDIO. Not the card slot |
| `dwmmc@1021c000` | The 8-bit eMMC controller. This board has no eMMC. U-Boot's tree is the one that mentions it, and that tree has no SD controller, so a card still will not boot the machine |

```
python3 tools/enable_storage.py report ~/partycade-dumps/extracted/bootimg/rk-kernel.dtb
python3 tools/enable_storage.py patch ~/partycade-dumps/extracted/boot.img -o /tmp/boot-storage.img --which sd   # add ,adb for the shell; ,usb only when USB-A is wanted
python3 tools/enable_storage.py report /tmp/boot-storage.img
```

A check on 2026-10-23: the report starts with both targets `disabled` and the three leave-nodes as above. The patch writes 4718592 bytes, the same size as `boot.img`. The second report shows `usb` and `sd` as `okay`. Sixteen bytes differ (eight per node). The source `boot.img` is unchanged. `/tmp/boot-storage.img` is a scratch file. It is not a flash candidate, and a block list computed from an old dump is stale the moment the cabinet boots, because SFTL moves pages.

When the time comes to flash, the sequence is the same shape as every other restore, and the block list is printed that session:

```
# Cold plug. RAW is a rawdump from this session.
python3 tools/sftl_rebuild.py RAW logical.img
dd if=logical.img of=boot.img bs=512 skip=2048 count=9216
python3 tools/enable_storage.py patch boot.img -o boot-storage.img --which sd
python3 tools/enable_storage.py report boot-storage.img
cp logical.img logical-storage.img
dd if=boot-storage.img of=logical-storage.img bs=512 seek=2048 conv=notrunc
python3 tools/sftl_patch.py RAW logical.img logical-storage.img OUT --part boot
python3 tools/sftl_rebuild.py OUT check.img
cmp logical-storage.img check.img
```

`boot` is logical sector 2048, 9216 sectors (`captures/partitions.json`). `--part boot` refuses a change outside that partition. Then `rk_restore.py diff`, and `restore` only the blocks the patch printed, after written approval of that exact list. A bad device tree comes back by restoring those same boot blocks from the backup. Never write block 1023. Do not send eFuse, force-erase, low-format, `WRITE_LBA`, `CHANGE_STORAGE`, or `DEVICE_RESET`.

After a successful boot with the new tree, format the card on the PC. FAT is for pictures and saves: udev mounts an SD card at `/mnt/sdcard` with `fmask=133`, so those files are not executable. ext2 is for a binary, because that mount has `exec`. ext4 is not in this kernel, so an ext4 card will not mount. A USB stick is not auto-mounted; the cabinet build of `cab_ext_root` mounts `/dev/sda1` itself. The simulator side is already live: `CAB_EXT=/path/to/dir ./play.sh` is the card, and The Yard and Orb use it.

## 12. The engine and the games

Three steps on 2026-10-24, all on the PC only; the chip still has the 2026-10-23 22:00 build (STATUS.md).

**First, the redraw.** The first builds drew with `SDL_RenderFillRect` and the 8×8 font, and each game had one sine beep. Every game was rebuilt on a small software renderer (`gfx`) and synth (`sfx`):

* **gfx** draws into one 32-bit frame in RAM at the game's upright size, then uploads it to one streaming texture, the way the stock emulators draw (§ 1), and `cab_present` rotates it. It has anti-aliased shapes, dithered gradients, additive glow, and outlined toon figures (every part painted once grown in ink, then filled). It also has particles, shake, flash, easing, and a seeded RNG. Backgrounds that never move are painted once and copied.
* **sfx** is a 16-voice synth in the audio callback, with five waves, envelopes, slides, vibrato, pan, and a text step sequencer.
* **The built-in player** is each game's own bot, pressing through the deck's input path. It is the attract demo, the tests' player, and the reel.

**Then, the cart runtime.** The games moved from five C programs to Lua carts on one runtime, `yard`. The aim is that a new game, or a change to an old one, is a small, safe edit in a high-level language. That edit gets checked by tools that a less experienced agent can't skip, and it can't harm the cabinet. [CARTS.md](CARTS.md) is the reference. What changed underneath:

* **The runtime.** It is Lua 5.4.7, sandboxed: no io, os, require, load, debug, or bytecode, a 32 MB cap that counts pictures, a step watchdog, and strict globals. The API in `api.c` covers the renderer, toon figures, a light map, layers, PNG images and pixel art, round TrueType text (Fredoka, stb_truetype), the synth and sequencer, particles, saves, and the card. A Lua library (`engine/lib`) adds timers, tweens, tasks, the house palette, sound presets, faces, the caption band, and the arcade shell.
* **The menu is a cart too** (`carts/yard`). It lists whatever carts it finds, and runs each one as a child process. A cart that errors shows "Oops" and returns; a missing native program leaves a note.
* **The ports are faithful.** Each port is a line-for-line translation of the C rules. The same seed plays the same game: Chest's key, sword, and wins land on the same frames as the C build. Every log line and save format the tests read is unchanged. The visible change is the round font in place of the 8×8 one.
* **Cost.** Measured with callgrind on this PC over 1200 autoplayed frames, Lua adds 10 to 25 percent to a frame: Tea 7.1 M instructions a frame against 6.3 M in C, Chest 5.8 against 5.2, Lamp 4.8 against 3.9, Keep 1.2 against 1.0. Drawing is still the bulk, and it stays in C. This is a PC measurement; the cabinet's frame time is still unmeasured.
* **Shipping.** Three fixed-size files and an in-place update path (§ 6, CARTS.md § 10).

What each game is:

| Game | Band | The stick | `LOW` (and `TL`, `TR`) | What it remembers |
| :--- | :--- | :--- | :--- | :--- |
| The Yard | menu | Up and down (left and right too) pick a row; held, it repeats | Opens the row | `yard.sav`, the row. Each row shows its band (ALL, 4+, 5+, 8+) and what the game's save says |
| Keep | walk-up | Pip walks the basket along the orchard floor | Starts, then dashes the way Pip leans | `keep.sav`, the best score |
| Lamp | walk-up | Wren walks the meadow; walking into a star wakes it | Lifts the lamp: a wide flare that costs oil and scares moths | `lamp.sav`, the most nights woken |
| Orb | two-verb | Steers the orb | Dives; held (`LOW` or `TL`) while diving, boosts for double points | `orb.sav`, the best score |
| Tea | little | Any direction moves the ring to the next cat | The care in the picture over that cat | `tea.sav`, visits, gifts, photos |
| Chest | walk-up | Ned walks | A bolt the way he faces; with the sword, a laser | `chest.sav`, gems |

* **Keep.** A sunset orchard. Fruit shakes on the branch before it drops, and its shadow on the grass sharpens as it falls, so the landing spot is a picture. Apples are 1, pears 2, gold star fruit 5. Six catches in a row raise the multiplier, up to ×5. A miss splats and costs one of three hearts. After 10 points bees come down in a zigzag; catching one costs a heart. Speed and the number of fruit in the air rise with the score. `-fast` starts harder.
* **Lamp.** The meadow is dark except for the lantern's light, drawn with the runtime's light map. A sleeping star breathes a faint glow so it can be found. Waking one sends it up into the sky band, where it takes its place and a line joins it to the last one. A full set is a constellation (the Kite, the Teacup, the Cat, the Key, the Fish, the Crown, the Whale, the Teapot, the Dragon); then the next night has more stars. The lamp burns oil: fireflies refill it, moths from night 3 nibble it. Run dry and the light shrinks to an ember for two and a half seconds, then relights with the stars already woken still awake.
* **Orb.** The title is a lit orb over a grid, turning; the stick yaws it. The well is a tube of panels whose seams glow in a color that shifts with depth. The first four gates teach the four sides; after that they are random per run, with a pillar and a ring (only the middle open) from the tenth. Wisps are points, and catching several in a row is a chain. Speed rises with distance. It stays a C program (`native/orb`) because it draws with OpenGL ES 2.
* **Tea and Chest** are version 2 of their specs ([games/carts/tea/DESIGN.md](games/carts/tea/DESIGN.md), [games/carts/chest/DESIGN.md](games/carts/chest/DESIGN.md)), worked out by playing them with `playtest.py` (§ 13). Tea: treats to catch on the flight that then decorate the party, three different asks per cat (its wish, a cupcake, a hug), a song after the cheer, and a photo on the castle wall that stays between visits. Chest: the sword aims itself in the fight, Ned hops back from the chest, Zam (drawn after Alakazam) learns a teleport, a shield, and a three-bubble fan as the pile grows, and each win adds a different treasure to a mound.

**Third, the GPU runtime (2026-10-24, PC only).** The same carts also run on LÖVE 11.5, built from source with `zig cc` for the cabinet's glibc 2.29 (`games/love/build.sh`). It draws with OpenGL ES 2 on the Mali instead of the CPU, and its sound is OpenAL. With the same seed, each cart's bot writes the same log and the same save on both runtimes (`test.py love`). The bundle is 8.9 MB, so it belongs on the microSD card's ext2 partition once the slot is on; the first test puts it in `data` as one 4.1 MB `love.tar.gz` that the cabinet unpacks itself. Nothing about it is verified on the cabinet. [games/love/README.md](games/love/README.md) has the recipe and the open questions; [FIELD_TASKS.md](FIELD_TASKS.md) has the first run.

## 13. Playing a game yourself, as the cabinet runs it: `playtest.py`

`test.py` checks rules and `feel.py` films a reel. Neither lets an agent (or a person without a keyboard) play: press something, look at the result, decide the next move. `games/playtest.py` does that. It keeps one game running between commands, stopped on a frame, and runs it only when told.

```
python3 games/playtest.py start tea                   # a fresh session: its own saves, seed 1
python3 games/playtest.py do "wait 90; look; tap LEFT; film 60 every 10; tap LOW; look"
python3 games/playtest.py listen                      # the notes so far, and a spectrogram
python3 games/playtest.py stop
python3 games/playtest.py perf chest                  # instructions per frame, and a Cortex-A7 guess
```

What makes it the cabinet rather than a PC window:

| | How |
| :--- | :--- |
| Picture | The game draws through the cabinet path: the 1024×768 framebuffer, turned −90° (`CAB_RAW_FB=1`). Every picture is that framebuffer turned back upright and cropped, so the scale and the letterbox are the panel's |
| Deck | One joystick, player 0, the panel's names. The stick is strict four-way (`CAB_FOURWAY=1`): of two directions held, the newer wins, because nobody has measured whether this stick reports a diagonal. `--eight` lifts it |
| Time | Frames at 60 Hz, deterministic. Nothing moves between commands. `CAB_SEED` fixes the randomness |
| Sound | No device. The game's own synth is pulled 735 samples a frame into `audio-<Title>.wav` (`CAB_AUDIO_WAV`), so a sound lines up with the frame that started it. The real panel adds its ALSA buffer, about 23 ms |
| Saves | Real files in the session's `data/`, the stand-in for `/data/Games`. `--save "keep.sav=best 9"` seeds one |
| Quit | 1P+2P held for 60 frames, as on the cabinet. A session started on The Yard follows it into each game and back, because the games are child processes that inherit the control pipe |

Under it is a control mode in `cab.c` (`CAB_CONTROL=1`): each frame, before reading the deck, the game reads commands on stdin (`down X`, `up X`, `release`, `step N`, `shot PATH`, `every N DIR`, `sync`, `quit`) and answers `ready <frame> <title>| <held>` on stdout. `playtest.py` runs a small server per session that owns that pipe.

Each `do` prints the frames it kept as one sheet (the panel picture, the deck with the held buttons lit, and the loudness on that frame), the game's new log lines, the sound onsets with note names (`253:G5`), the frame and game, and the saves. `replay.cab` in the session folder is the same presses as a `CAB_SCRIPT`, so a session can become a test.

This is how Tea and Chest version 2 were found and checked (2026-10-24). Playing them showed things no check had: Tea's flight gave the hand nothing to do, Chest's laser followed the last step and missed, Ned started the fight on Zam's feet, a held button beat a level-three Zam in two seconds, the cats' mouths read as frowns, and a quick double tap on the Yard was one long press.

`perf` plays the cart with its built-in player inside the runtime under callgrind. It prints the instructions per frame left after SDL's PC-side copy, with a range for the cabinet's 1.008 GHz Cortex-A7 (0.5 to 0.8 instructions a cycle). `./cart perf` gives the whole-run number that `./cart check` holds against its budget. These are guesses, not measurements on the cabinet.
