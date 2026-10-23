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

| What arrived | evdev code | SDL joystick button | Also a key event |
| :--- | :--- | :--- | :--- |
| A | `0x130` | 0 | no |
| B | `0x131` | 1 | no |
| X | `0x133` | 3 | no |
| L | `0x136` | 6 | no |
| R | `0x137` | 7 | no |
| Up / Left / Right / Down | `0x67` / `0x69` / `0x6a` / `0x6c` | 15 / 16 / 17 / 18 | yes (`Up` `Down` `Left` `Right`) |
| Volume down / up | `0x72` / `0x73` | 19 / 20 | yes |

Directions are joystick buttons plus keyboard events, not axes. Holding a control makes evdev repeat (`value 2`); the SDL joystick and the keyboard path do not.

The physical deck, from the user after that session, is the whole control set:

* Left of the joystick: **1-player** on top, **2-player** below it.
* The 4-way joystick.
* Right of the joystick: three buttons, two on the top row and one below them, shifted left.
* Volume + and volume −.
* The power switch. It is not a key. It was the last thing tested, which is why `probe.log` stops at 25.3 s in the middle of an L press and has no exit line.

Those five play buttons are the five codes in the table (A, B, X, L, R). Which label is which code is not known yet. The driver still advertises C, Y, Z, L2, R2, select, start, mode, bl, and br (joystick buttons 2, 4, 5, 8–14). None of them are on this deck, and none of them appear in the log.

The probe's picture was rotated **90° clockwise** on the cabinet. The framebuffer itself is landscape: KMSDRM, opengles2, flags `0xe`, output and display **1024×768 @ 60**. A game draws upright by rotating the presented frame 90° counter-clockwise. Audio came up as ALSA.

**Rules for our games, so they behave like stock ones:**

* Accept input from **both** joystick events and keyboard events, through one mapping table in the code. That keeps the PC and the cabinet the same code.
* **Always have a way to quit back to the menu.** This deck has no select or start button, so a select+start combo never fires. Use two real buttons held together (the 1-player and 2-player buttons, once their codes are known). The menu is stuck until the game exits. Cutting power does not return to the menu, and it drops the last second of the log.
* Don't touch the volume. Optionally show the `/data/spk_volume` overlay like stock games do.

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
| C. SD card | Nothing on the flash | No flash writes | Two unknowns: whether U-Boot sees the slot, and the stock Linux has SD support switched off in its device tree. The card must stay inserted. More research before it's usable |

All flash changes go through the same reversible path. Edit a copy offline, `tools/sftl_patch.py` lists the physical blocks that changed, and `tools/rk_restore.py restore` writes just those. The original backup undoes any of it ([RECOVERY.md](RECOVERY.md)).

**Recommendation:** start with **A** as the first on-cabinet test (data only, a handful of blocks), then move to **B** once our launcher is good. Keep SD (C) as research only.

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
| 5 | Probe played and the log read back (`2026-10-23_probe_played`). The deck is the stick, 1-player, 2-player, three buttons on the right, and volume. Codes are in § 2. Which of A/B/X/L/R is which physical button is still open | Done | No |
| 6 | **First real game** behind the same tile, or a tiny "more games" menu there. Same flash path | PC + User + Approval | Yes (`data`) |
| 7 | **Our launcher (option B):** build it, measure the rootfs change offline (`S50ui` hook, rebuilt SquashFS, `sftl_patch.py --part rootfs`), check the stock menu fallback, then flash once | PC + User + Approval | Yes (`rootfs`, once) |
| 8 | From then on, each new game is a folder in `/data/games/<name>/` plus a line in the launcher's list: a `data`-only change. Optionally set up ADB first to skip the switch flips | Repeat | `data` only |

Each flash step follows RUNBOOK.md Phase 3, option B: a fresh `rawdump` → edit a copy → `sftl_patch.py` → rebuild check → `diff` says "none" → `restore` the listed blocks → `diff` against the patched image says "none" → switch ON and play. `tools/data_patch.py` does the middle part (edit, patch, rebuild check) in one checked command.

## 6. Building and installing (`games/`)

```
games/
  toolchain/Dockerfile   Debian 10 armhf cross GCC 8.3 (glibc 2.28) + SDL 2.0.7 headers; image "partycade-armhf"
  common/cab.{h,c}       platform layer: window, logical resolution, input map, quit combo, audio, text, log, screenshot
  common/font8x8_basic.h public-domain 8x8 font
  probe/probe.c          the controls/screen/audio probe
  Makefile               TARGET=pc or TARGET=cab; GAMES := probe ...
  build.sh pc|cab|all    cab builds in Docker against the extracted rootfs, then runs check_binary.sh
  check_binary.sh        armhf, every NEEDED lib in the rootfs, GLIBC <= 2.29, GLIBCXX <= 3.4.22
```

* Build: `cd games && ./build.sh all` → `out/pc/<game>` and `out/cab/<game>` (gitignored). The first run builds the Docker image. `ROOTFS=` overrides the rootfs path (default `~/partycade-dumps/2026-10-23_raw_plug3032slc/rootfs`).
* Play on the PC: `out/pc/probe`. Keys: arrows; Z X C = A B C; A S D = X Y Z; Q W = L R; 1 2 = L2 R2; Backspace = SELECT; Return = START; Tab = MODE. Escape quits.
* Smoke-test the ARM build without the cabinet (`qemu-arm-static` is in `~/.local/bin`):
  `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy PROBE_SELFTEST=1 CAB_SCREENSHOT=/tmp/s.bmp qemu-arm-static -L $ROOTFS out/cab/probe` must exit 0 within a few seconds (the self-test presses A, then holds SELECT+START).
* The probe install already happened (2026-10-23). Tile 10's `start.sh` line is `GAME_NAME=probe`, and `/data/Games/probe` is the cabinet binary. Running the command below again will fail, because `GAME_NAME="Mappy d"` is no longer in `start.sh`. Undo of that install is a restore of blocks 828, 829, 872, 873, 884, 885, 892, 893 from `~/partycade-dumps/2026-10-23_probe_tile10/nand_raw.bin`.
* The next game uses the same tool on a **fresh** `rawdump` from the session you will write in. Put the new binary at `Games/<name>` and point case `10)` at it (the current text to replace is `GAME_NAME=probe`). The command that did the probe, kept here as the pattern:

```
python3 tools/data_patch.py RAW ~/partycade-dumps/<date>_probe_tile10 \
  --put games/out/cab/probe:Games/probe:755 \
  --replace 'start.sh:GAME_NAME="Mappy d":GAME_NAME=probe'
```

  It prints the blocks and the `rk_restore.py restore` command. To read a log back: `rawdump`, `sftl_rebuild.py`, extract the `data` partition (offset `0x22c00`, `0xf000` sectors), then `debugfs -R 'dump /Games/probe.log probe.log' data.img`. The log is written about once a second and on a clean exit. Cutting power drops the tail.
