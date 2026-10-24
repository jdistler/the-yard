# The Yard

A side door on an Arcade1Up Pac-Man Partycade.

The stock menu has twelve games. One of them, Dig Dug II, opens a little menu of games of our own. A lantern walks the rows. Any of the three play buttons steps through the door. Hold 1-player and 2-player and you are back in the stock menu.

The cabinet is one RK3032 board with 128 MiB of RAM, a SPI NAND chip, and a control deck: a 4-way stick plus five buttons. The notes in this repo cover how that board boots, where the menu lives, and how a handful of blocks in its data partition were replaced so Dig Dug II launches The Yard. The same games run in a window on a PC.

Stock firmware and the twelve built-in games are not here. They stay in a dump directory outside the repo.

## Play on a PC

You need SDL2 (`libsdl2-dev` on Debian or Ubuntu) and Python 3.

```bash
cd games
make
./out/pc/yard
```

Arrows move. `Z` is the lower button. `X` and `C` are the two buttons beside it. Hold `1` and `2` to leave. Escape closes the window.

| Row | For | What it is |
| :--- | :--- | :--- |
| Keep | everyone | Catch the falling fruit in Pip's basket at sunset. The stick walks, `Z` dashes. Combos, three hearts, bees later. |
| Lamp | everyone | Carry a lantern through a dark meadow and wake the fallen stars into constellations, night after night. `Z` lifts the lamp. |
| Orb | 8 and up | Dive a glowing well in OpenGL ES 2. The stick steers, `Z` dives, and holding it boosts for double points. |
| Tea | 4 and up | A unicorn flies to a castle, catching treats that decorate the party, then looks after the cats: tea, cupcakes, hugs, and a song. A photo of each party stays on the wall. [Design](games/carts/tea/DESIGN.md). |
| Chest | 5 and up | Walk to a key, open the chest, and duel Zam, a gold psychic with two spoons who learns a new trick with every gem on the pile. The stick walks; the sword aims itself. [Design](games/carts/chest/DESIGN.md). |

Leave a title alone for ten seconds and Keep and Lamp play themselves, and Orb plays its own demo, until someone presses a button.

## Make a game

Every game except Orb is a **cart**: a folder of Lua that the `yard` runtime plays in a sandbox. A cart can't touch files or hang the cabinet. If it errors, the player sees a gentle "Oops" screen and goes back to the menu.

```bash
cd games
./cart new bubbles --from arcade     # blank, arcade, or story
./cart run bubbles                   # play it; saving a file restarts it
./cart check bubbles                 # the gate: lint, a played session, a mashed session, pictures, cost
```

[CARTS.md](CARTS.md) is the whole API and the work loop. `./stress.sh` runs every headless check (`test.py`). `python3 playtest.py start chest`, then `python3 playtest.py do "wait 60; tap LOW; look"`, plays a game a few frames at a time through the cabinet's own picture path and four-way stick ([GAMEDEV.md](GAMEDEV.md) § 13). Orb needs Mesa's EGL and GLES libraries to run on a PC.

Building for the cabinet needs the stock rootfs and the Docker image in `games/toolchain/` (`./build.sh cab`). `./cart deploy` stages a build onto a copy of a fresh raw dump and prints the plan. Writing the cabinet stays a deliberate step that the user approves in writing. See [STATUS.md](STATUS.md) and [RUNBOOK.md](RUNBOOK.md).

## Start here

| If you want… | Read |
| :--- | :--- |
| What is true right now | [STATUS.md](STATUS.md) |
| To make or change a game | [CARTS.md](CARTS.md), then [CONTROLS.md](CONTROLS.md) |
| The cabinet as a game machine: screen, deck, sound, storage, limits | [GAMEDEV.md](GAMEDEV.md) |
| How not to brick the cabinet | [RUNBOOK.md](RUNBOOK.md), [RECOVERY.md](RECOVERY.md) |
| The USB and image tools | [tools/README.md](tools/README.md) |
| The flash map, boot chain, and menu | [FIRMWARE_ANALYSIS.md](FIRMWARE_ANALYSIS.md) |
| The lab notebook, including the dead ends | [BOOT_RESEARCH.md](BOOT_RESEARCH.md) |
| Ports, the boot switch, Mask ROM, UART | [INTERFACING_AND_MODES.md](INTERFACING_AND_MODES.md) |
| The board and the cabinet | [HARDWARE_SPECS.md](HARDWARE_SPECS.md) |
| Rules for an agent working in this tree | [AGENTS.md](AGENTS.md) |

`captures/` holds the partition table, the decoded device tree, the U-Boot environment, and file listings. `logs/rk_log.jsonl` records every USB action the tools have taken. `reference/` and `build/` are gitignored and recreated by `tools/fetch_references.sh` and `tools/rk.py build`.

## This cabinet

Verified on the unit these notes were written from. The label details are in [HARDWARE_SPECS.md](HARDWARE_SPECS.md).

| | |
| :--- | :--- |
| Cabinet | Pac-Man Partycade, 12-in-1, model `PAC-D-308600`, Costco `1740652`, made June 2024 |
| Board | Arcade1Up `GBX70-V01` |
| SoC | Rockchip RK3032, Cortex-A7, 128 MiB |
| Storage | Winbond W25N01GV 1 Gbit SPI NAND, Rockchip SFTL, five GPT partitions |
| Software | U-Boot 2017.09, Linux 4.4.194, Buildroot, glibc 2.29 armhf, MiniGUI menu, SDL 2.0.7 |
| Display | 17" panel. The framebuffer is 1024×768 and is mounted rotated. Games draw upright and the runtime turns the picture |
| Deck | 4-way stick, 1-player and 2-player on the left, three buttons on the right, volume knob |
| Power | 12V barrel, center positive |
| Boot switch | OFF is USB Mask ROM. ON is the game. Read only at cold power-up |

The cabinet runs the 2026-10-23 build of The Yard: five C programs. This tree is newer. The games were redrawn on 2026-10-24, and later that day moved onto the cart runtime. Neither change has been written to the chip. See [STATUS.md](STATUS.md).

## License

Original code and notes in this repository are [MIT](LICENSE). Vendored code and fonts keep their own licenses:

* `tools/inc/libusb.h` is the upstream libusb header (LGPL-2.1).
* `games/engine/lua/` is Lua 5.4.7 (MIT).
* `games/engine/vendor/stb_image.h` and `stb_truetype.h` are public domain or MIT, at your choice.
* `games/engine/fonts/Fredoka-SemiBold.ttf` is under the SIL Open Font License 1.1 (`Fredoka-OFL.txt` beside it).
* `games/engine/font8x8_basic.h` is public domain.

Arcade1Up, the stock games, and the Rockchip boot blobs are not included and are not licensed here. Chest's boss, Zam, is drawn as a fan tribute to Alakazam, which belongs to Nintendo, Creatures, and Game Freak. That likeness is not covered by the MIT license.
