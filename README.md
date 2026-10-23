# Arcade1Up Pac-Man Partycade (2024 Revision): Hardware, Firmware & Interface Notes

Documentation and read-only tooling for the **Arcade1Up Pac-Man Partycade (12-in-1)**, Costco item 1740652, model `PAC-D-308600`, made June 2024. The goal is to understand how it boots and where its game list lives, and then to run our own games on it.

## Start here

* **[STATUS.md](STATUS.md)**: what is verified right now, the current blocker, and the next step. Read this first.
* **[RUNBOOK.md](RUNBOOK.md)**: hard rules, how to operate the cabinet over USB, and the phased plan with decision tables.
* **[AGENTS.md](AGENTS.md)**: short rules for AI agents working in this repo.
* **[tools/README.md](tools/README.md)**: `tools/rk.py`, the read-only USB tool, and how the download encoding works.

## Reference

* **[FIRMWARE_ANALYSIS.md](FIRMWARE_ANALYSIS.md)**: flash layout, boot chain, kernel, device tree, U-Boot, and what is still unread.
* **[BOOT_RESEARCH.md](BOOT_RESEARCH.md)**: chronological lab notebook of every session, including the dead ends.
* **[INTERFACING_AND_MODES.md](INTERFACING_AND_MODES.md)**: ports, the boot switch, entering Mask ROM, and UART.
* **[HARDWARE_SPECS.md](HARDWARE_SPECS.md)**: cabinet, display, control deck, and mainboard parts.
* **[DEVELOPMENT_ROADMAP.md](DEVELOPMENT_ROADMAP.md)**: building software for this platform, and the board-swap alternative.
* `captures/`: small machine-readable artifacts from the cabinet (partition table, GPT sectors, decoded device tree, U-Boot env).
* `logs/rk_log.jsonl`: every action `tools/rk.py` has taken against the hardware.
* `reference/` (gitignored): upstream sources, recreated by `tools/fetch_references.sh`.
* Flash dumps live outside the repo in `~/partycade-dumps/` and are never committed.

## Quick reference

"Verified" means observed on this cabinet.

| Parameter | Value | Status |
| :--- | :--- | :--- |
| Cabinet model | `PAC-D-308600` / art. `1740652`, serial `BSBLF-0624-032314` | label |
| Mainboard | Arcade1Up `GBX70-V01` | label |
| SoC | **Rockchip RK3032** (RK3036 family, Cortex-A7) | verified (loader chip info, device tree) |
| RAM | 128 MiB | verified (device tree) |
| Storage | Winbond W25N01GV 1 Gbit **SPI NAND** (ID `EF AA 21`), GPT with 5 partitions | verified (USB loader) |
| Software | U-Boot 2017.09 → Linux 4.4.194 → SquashFS rootfs (all built May 2023) | verified (flash dump) |
| Display | BOE `DV170YGZ-N10`, 17" 1280×1024 LVDS | label; LVDS panel in device tree |
| Controls | Control deck `GB-CON-5 V02`; key events reach Linux through a `uart-keys` driver | verified (device tree) |
| Power | 12V DC barrel, center positive | label |
| Micro-USB | Rockchip OTG. Linux runs it as **host** (`dr_mode = "host"`), so the PC sees nothing in normal mode. | verified |
| Boot switch ("NC") | **OFF** = USB Mask ROM (`2207:301a`, dark screen). **ON** = normal game boot. Read only at cold power-up. | verified |
