# Agent instructions

This repo documents and probes a live Arcade1Up Pac-Man Partycade (RK3032, SPI NAND) connected to this PC over USB.

Read these, in this order, before doing anything:

1. [STATUS.md](STATUS.md): current facts, backups, and open questions.
2. [RUNBOOK.md](RUNBOOK.md): hard rules, the session loop, and the phase you're in.
3. [RECOVERY.md](RECOVERY.md): how to get the cabinet back if anything goes wrong. Read it before any step that could change the cabinet.
4. [tools/README.md](tools/README.md): what each tool does.
5. [CARTS.md](CARTS.md), when the task is a game. [SDCARD.md](SDCARD.md), when it involves the microSD card. Then [CONTROLS.md](CONTROLS.md) and [GAMEDEV.md](GAMEDEV.md). Dig Dug II opens The Yard (Keep, Lamp, Orb, Tea, Chest). STATUS.md "Pickup" is the live hardware state. The cart build in this tree is newer than the build on the cabinet.

## Non-negotiable

* Never write, erase, or reset the cabinet's flash, except through `tools/rk_restore.py restore` for a RECOVERY.md or RUNBOOK.md step that the user approved **in writing for the exact block list**. Don't run `rkdeveloptool`, `xrock`, `rkflashtool`, or `upgrade_tool` against the cabinet. Never send eFuse, force-erase, low-format, or LBA-write commands.
* Before any approved write: a fresh `rk.py rawdump`, saved under `~/partycade-dumps/`, and a `rk_restore.py diff` that says "none".
* Never USB-reset the device. One download attempt per Mask ROM enumeration. Stop at the first error and ask the user for a cold plug.
* Never commit flash dumps, firmware binaries, or ROMs. They go to `~/partycade-dumps/`.
* Anything physical (cold plug, cover, UART, SD card) is the user's job. Give them exact steps.
* Anything that could change the cabinet (writing flash, inserting an SD card built from the stock boot block) needs the user's explicit approval, after you explain the risk.

## Games

* A game is a cart in `games/carts/<id>/`. Start one with `./cart new`. Don't write a new C game. Don't change `games/engine/` to suit one cart: if the API lacks something, use the library or a layer, and write down what was missing.
* Look before you claim. `./cart shots ID ... --auto` writes PNGs; open them. `playtest.py` plays a game frame by frame on the cabinet's picture path.
* `./cart check` must say `all carts pass`, and `./stress.sh` must pass, before a game is called done. Add the new cart's checks to `games/test.py`.
* Keep every log line and save key a test or a save file depends on. Changing them silently breaks the tests or the saves on the cabinet.
* A change to the engine (`games/engine/`) needs a reason, a binding in `api.c`, a line in CARTS.md, a check in `test.py`, and `./stress.sh` passing. Run `python3 tools/bin2c.py` after editing `engine/lib/`.
* Shipping is `./cart pack`, then `./cart deploy`, which only stages. The write follows the rules above.

## Keeping the docs true

At the end of each session:

* Update STATUS.md: facts, plug table, backups, open questions.
* Append a dated section to BOOT_RESEARCH.md with device numbers, commands, results, and what you concluded.
* Update the `note` fields in `tools/rk.py` `STAGES` for any plug you tried.
* Record any new firmware findings in FIRMWARE_ANALYSIS.md, and recovery findings (e.g. test ladder results) in RECOVERY.md.
* Commit with git. The public remote is <https://github.com/jdistler/the-yard>. Do not push unless the user asks. Do not commit flash dumps, and do not force-push.

Say "verified" only for things observed on this cabinet. Anything from vendor docs or other boards is "expected" or "unverified".
