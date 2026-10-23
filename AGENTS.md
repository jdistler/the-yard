# Agent instructions

This repo documents and probes a live Arcade1Up Pac-Man Partycade (RK3032, SPI NAND) connected to this PC over USB.

Read these, in this order, before doing anything:

1. [STATUS.md](STATUS.md): current facts and the current blocker.
2. [RUNBOOK.md](RUNBOOK.md): hard rules, the session loop, and the phase you're in.
3. [tools/README.md](tools/README.md): how `tools/rk.py` works.

## Non-negotiable

* Never write, erase, or reset the cabinet's flash. Use only `tools/rk.py` against the hardware. Don't run `rkdeveloptool`, `xrock`, `rkflashtool`, or `upgrade_tool` against it.
* Never USB-reset the device. One download attempt per Mask ROM enumeration. Stop at the first error and ask the user for a cold plug.
* Never commit flash dumps, firmware binaries, or ROMs. They go to `~/partycade-dumps/`.
* Anything physical (cold plug, cover, UART, SD card) is the user's job. Give them exact steps.
* Anything that could change the cabinet (writing flash, inserting an SD card built from the stock boot block) needs the user's explicit approval, after you explain the risk.

## Keeping the docs true

At the end of each session:

* Update STATUS.md: facts, plug table, backups, open questions.
* Append a dated section to BOOT_RESEARCH.md with device numbers, commands, results, and what you concluded.
* Update the `note` fields in `tools/rk.py` `STAGES` for any plug you tried.
* Record any new firmware findings in FIRMWARE_ANALYSIS.md.
* Commit with git. The repo is local only; there is no remote.

Say "verified" only for things observed on this cabinet. Anything from vendor docs or other boards is "expected" or "unverified".
