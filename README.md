# The Yard

A side door on an Arcade1Up Pac-Man Partycade.

The stock menu has twelve games. One of them, Dig Dug II, opens a little menu of five original ones. A lantern walks the rows. The lower button steps through the door. Hold 1-player and 2-player and you are back in the stock menu.

The same five games run in a window on a PC. The cabinet is one RK3032 board with 128 MiB of RAM, a SPI NAND chip, and a control deck that is a 4-way stick plus five buttons. The notes in this repo are how that board boots, where the menu lives, and how a handful of blocks in its data partition were replaced so Dig Dug II launches The Yard.

Stock firmware and the twelve built-in games are not here. They stay in a dump directory outside the repo.

## Play on a PC

You need SDL2. On Debian or Ubuntu that is `libsdl2-dev`.

```bash
cd games
make
./out/pc/yard
```

Arrows move. `Z` is the lower button. `X` and `C` are the two buttons beside it. Hold `1` and `2` to leave. Escape closes the window.

| Row | What it is |
| :--- | :--- |
| Keep | Catch the tile. The stick moves the paddle. `Z` starts. |
| Lamp | Carry a lantern around a dark yard and wake seven stars. |
| Orb | Turn a room with the stick. `Z` dives the well. |
| Tea | A unicorn flies to a castle and looks after the cats. Any direction leans. Any right-hand button does the care. [Design](games/tea/DESIGN.md). |
| Chest | Walk to a key, open the chest, and duel Zam. The stick walks. `Z`, `X`, and `C` shoot. [Design](games/chest/DESIGN.md). |

`./stress.sh` plays the edges. `python3 feel.py` plays a reel of each game and writes pictures under `games/out/feel/` (it needs Pillow). Both are headless.

Building for the cabinet needs the stock rootfs and the Docker image in `games/toolchain/`. `./build.sh cab` does that. Putting a build on the cabinet writes NAND, and that stays a deliberate step. See [STATUS.md](STATUS.md).

## Start here

| If you want… | Read |
| :--- | :--- |
| What is true right now | [STATUS.md](STATUS.md) |
| How to run the games, and the control deck | [GAMEDEV.md](GAMEDEV.md), [CONTROLS.md](CONTROLS.md) |
| How not to brick the cabinet | [RUNBOOK.md](RUNBOOK.md), [RECOVERY.md](RECOVERY.md) |
| The USB tools | [tools/README.md](tools/README.md) |
| The flash map, boot chain, and menu | [FIRMWARE_ANALYSIS.md](FIRMWARE_ANALYSIS.md) |
| The lab notebook, including the dead ends | [BOOT_RESEARCH.md](BOOT_RESEARCH.md) |
| Ports, the boot switch, Mask ROM, UART | [INTERFACING_AND_MODES.md](INTERFACING_AND_MODES.md) |
| The board and the cabinet | [HARDWARE_SPECS.md](HARDWARE_SPECS.md) |
| Rules for an agent working in this tree | [AGENTS.md](AGENTS.md) |

`captures/` holds the partition table, the decoded device tree, the U-Boot environment, and file listings. `logs/rk_log.jsonl` is every USB action the tools have taken. `reference/` and `build/` are gitignored and recreated by `tools/fetch_references.sh` and `tools/rk.py build`.

## This cabinet

Verified on the unit these notes were written from. The label details are in [HARDWARE_SPECS.md](HARDWARE_SPECS.md).

| | |
| :--- | :--- |
| Cabinet | Pac-Man Partycade, 12-in-1, model `PAC-D-308600`, Costco `1740652`, made June 2024 |
| Board | Arcade1Up `GBX70-V01` |
| SoC | Rockchip RK3032, Cortex-A7, 128 MiB |
| Storage | Winbond W25N01GV 1 Gbit SPI NAND, Rockchip SFTL, five GPT partitions |
| Software | U-Boot 2017.09, Linux 4.4.194, Buildroot, glibc 2.29 armhf, MiniGUI menu, SDL 2.0.7 |
| Display | 17" panel. Games draw upright. The framebuffer is 1024×768, and the panel mount shows that upright |
| Deck | 4-way stick, 1-player and 2-player on the left, three buttons on the right, volume knob |
| Power | 12V barrel, center positive |
| Boot switch | OFF is USB Mask ROM. ON is the game. Read only at cold power-up |

On the cabinet, Dig Dug II opens The Yard. That write landed on 2026-10-23. The picture pass after it (a fuller court, a lantern, a wider path) is in this tree and has been played on the PC. It has not been written back to the chip.

## License

Original code and notes in this repository are [MIT](LICENSE). `tools/inc/libusb.h` is the upstream libusb header and stays LGPL-2.1. `games/common/font8x8_basic.h` is public domain. Arcade1Up, the stock games, and the Rockchip boot blobs are not included and are not licensed here.
