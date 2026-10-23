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
| Volume up / down | `0x73` / `0x72` (handled by the driver) |

How these reach SDL is **to be probed**. The stock games use joystick axes, so the driver probably also reports an X/Y axis. SDL 2.0.7 normally numbers the `BTN_*` codes in order (A = 0, B = 1, …), but which physical button is which `BTN_*` is unknown. So is whether the arrows also arrive as keyboard events. The first program we put on the cabinet answers all of this (§ 5, step 3).

**Rules for our games, so they behave like stock ones:**

* Accept input from **both** joystick events and keyboard events, through one mapping table in the code. That keeps the PC and the cabinet the same code.
* **Always have a way to quit back to the menu** (e.g. hold select + start for 2 s). The menu is stuck until the game exits.
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
| 1 | **Toolchain:** a Docker image (Debian 10 "buster": gcc-arm-linux-gnueabihf, glibc 2.28) plus SDL 2.0.7 headers. Link against the libraries in the extracted rootfs. Build a "hello" binary and check its required symbol versions with `readelf -V` against the rootfs | PC | No |
| 2 | **Game skeleton:** one C codebase that builds for the PC (normal SDL2, keyboard) and for the cabinet. Fixed logical resolution, letterboxed; input mapping table; quit combo; 44.1 kHz audio. Optionally run the ARM build under `qemu-arm` with the rootfs libraries (`SDL_VIDEODRIVER=dummy`) as a smoke test; that needs `sudo apt install qemu-user`, which the user runs | PC | No |
| 3 | **Prove the restore path:** [RECOVERY.md](RECOVERY.md) test ladder T1, T2, T3, one cold plug each | User + Approval | Yes (test blocks, restored) |
| 4 | **Probe program (option A):** a small SDL2 app reached from one tile through `start.sh`. It shows and logs to `/data/probe.log`: joystick count, names, axes, buttons, hats, keyboard events, screen size, renderer, and an audio tone. Quit with a combo. Flash it (a few `data` blocks) | PC builds; User + Approval to flash | Yes (`data`) |
| 5 | The user plays with the probe: presses every button and notes what the screen says. Then a `rawdump` (read-only) brings `/data/probe.log` back to the PC through `sftl_rebuild.py`. Write the real control map into this file | User, then PC | No |
| 6 | **First real game** behind the same tile, or a tiny "more games" menu there. Same flash path | PC + User + Approval | Yes (`data`) |
| 7 | **Our launcher (option B):** build it, measure the rootfs change offline (`S50ui` hook, rebuilt SquashFS, `sftl_patch.py --part rootfs`), check the stock menu fallback, then flash once | PC + User + Approval | Yes (`rootfs`, once) |
| 8 | From then on, each new game is a folder in `/data/games/<name>/` plus a line in the launcher's list: a `data`-only change. Optionally set up ADB first to skip the switch flips | Repeat | `data` only |

Each flash step follows RUNBOOK.md Phase 3, option B: a fresh `rawdump` → edit a copy → `sftl_patch.py` → rebuild check → `diff` says "none" → `restore` the listed blocks → `diff` against the patched image says "none" → switch ON and play.
