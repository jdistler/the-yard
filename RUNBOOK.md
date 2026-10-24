# Runbook

How to operate on this cabinet, step by step, and what to do next. Read [STATUS.md](STATUS.md) first for the current facts, and [RECOVERY.md](RECOVERY.md) before anything that could change the flash. This file is about procedure.

Every command below is run from the repo root, `~/Projects/arcade1up-partycade`.

## 1. Hard rules

These come from mistakes already made on this board. Do not relax them without asking the user.

1. **Never write, erase, or reset the cabinet's flash.** `tools/rk.py` has no code for it, and its command builder refuses every opcode except the read-only ones. The only write code in the project is `tools/rk_restore.py restore`. It is locked, and it may be run only for a [RECOVERY.md](RECOVERY.md) step that the user approved in writing for an exact block list. Do not use `rkdeveloptool`, `xrock`, `rkflashtool`, or `upgrade_tool` against the cabinet. They all have write, erase, and reset commands that are one typo away (`wl`, `ef`, `ul`, `db`, `rd`, `w`, `e`, `P`, ...). They are in `reference/` to be *read*, not run.
2. **Never USB-reset the BootROM** (`libusb_reset_device`, `usbreset`, unbind/rebind, `dev.reset()`). It wedges the chip until a cold plug. This happened on devices 38–43.
3. **One download attempt per Mask ROM enumeration.** If a stage times out, that enumeration is spent. Don't retry, don't clear-halt. Record it and ask for a cold plug. `rk.py boot` enforces this through the log.
4. **A running plug can't be replaced.** Trying a different plug always needs a fresh Mask ROM: either a cold plug, or the warm reset some plugs do on their own.
5. **One hypothesis per boot.** Write down what the boot tests before running it.
6. **Dumps go to `~/partycade-dumps/`, never into git.** It is stock firmware and licensed games. `rk.py` refuses to write more than 1 MiB inside the repo, and so do the offline tools. Commit only metadata: partition tables, file listings, hashes, small text configs, device tree text.
7. **Log everything.** `rk.py` and `rk_restore.py` append to `logs/rk_log.jsonl` by themselves. Write a human summary into [BOOT_RESEARCH.md](BOOT_RESEARCH.md) and update [STATUS.md](STATUS.md) at the end of every session.
8. **Ask the user for anything physical:** cold plugs, the cover, UART wiring, SD cards. Tell them exactly what to do and what state to leave the switch in.

## 2. One-time setup on a new machine

```bash
tools/fetch_references.sh      # shallow clones into reference/ (gitignored, ~15 MB)
make -C tools                  # builds tools/rksend (needs gcc + libusb-1.0 runtime; header is vendored)
python3 -c 'import usb'        # pyusb must be installed: pip install --user pyusb
tools/rk.py build              # builds build/*.wire and checks each against its known-good sha256
```

`rk.py build` must print `matches known-good` for every stage. A `HASH MISMATCH` means the reference blobs changed upstream. Stop and investigate, and don't send anything.

Offline analysis also uses `unsquashfs` (squashfs-tools), `debugfs` and `e2fsck` (e2fsprogs), `file`, `readelf`, and `strings`.

USB permissions: the device node is `root:plugdev` with a `+` ACL for the logged-in user, which has been enough on this OptiPlex. If you get `Access denied`, the user needs a udev rule for `2207:*` (ask them; don't `sudo` the tool).

## 3. Cold plug (the user does this)

Give the user these exact words:

> 1. Unplug the 12V barrel plug. 2. Unplug the Micro-USB cable. 3. Make sure the switch on the back is **OFF**. 4. Plug in the barrel plug. 5. Plug in the Micro-USB cable. The screen stays dark.

Then run `tools/rk.py state`. Expect `mode=maskrom` and `fresh BootROM, nothing sent yet`. Cable: the straight Micro-USB to USB-A cable on rear port `1-6` has been the reliable setup. Any data-capable cable and port works.

If nothing shows up, both plugs were not out at the same time, or the cable is charge-only. Have them redo it with a few seconds' pause while unplugged.

To return the cabinet to normal play: unplug both, switch **ON**, plug in power.

## 4. The session loop

```bash
tools/rk.py state                       # what is on the bus; no USB traffic
tools/rk.py boot --plug plug_3032slc    # DDR 396 + plug into RAM; only on a fresh Mask ROM
tools/rk.py info                        # chip, flash ID, size, capability
tools/rk.py rawdump -o ~/partycade-dumps/<dir>/nand_raw.bin --verify   # whole chip, physical, ~2 min
tools/rk_restore.py diff <raw image>    # read-only: which physical blocks differ from a backup (~35 s)
tools/rk.py log -n 20                   # what has been done
```

Older commands still work: `probe` and `parts` (header and GPT), and `read`/`dump` (logical `READ_LBA`, real only below LBA `0x10000`).

Offline, no hardware:

```bash
tools/sftl_rebuild.py nand_raw.bin logical.img --check <older READ_LBA dump>   # logical disk from raw
tools/sftl_rebuild.py nand_raw.bin --where rootfs                              # which blocks hold a partition
tools/rk_restore.py plan nand_raw.bin                                           # block classification
tools/rk_restore.py native nand_raw.bin nand_native_2112.bin                    # image for an external programmer
tools/sftl_patch.py nand_raw.bin logical.img modified.img patched_raw.bin --part data   # see Phase 3, option B
```

`boot` exit codes: 0 loader up; 2 DDR stage failed; 3 plug stage failed; 4 nothing re-enumerated; 5 the plug reset the chip back to a fresh Mask ROM. Exit code 5 means you can `boot` again right away with a different plug.

## 5. Phase 1: read the whole flash (DONE 2026-10-23)

Result: `~/partycade-dumps/2026-10-23_raw_plug3032slc/nand_raw.bin`. Details and hashes are in [RECOVERY.md](RECOVERY.md) § 2. To take a fresh one, do it before any planned flash change, and after the cabinet has been played (play writes high scores into `data`):

```bash
D=~/partycade-dumps/$(date +%F)_raw; mkdir -p $D
tools/rk.py rawdump -o $D/nand_raw.bin --verify          # reads each chunk twice
tools/rk.py rawdump -o /tmp/second.bin && cmp $D/nand_raw.bin /tmp/second.bin && rm /tmp/second.bin
tools/sftl_rebuild.py $D/nand_raw.bin $D/logical_rebuilt.img --check ~/partycade-dumps/2026-10-23_plug3032/full_lba0_220672.img
```

The check line compares the first 32 MiB. If the cabinet was played in between, a few sectors in `data` may legitimately differ there, but nothing in `IDBlock`/`uboot`/`boot` (LBA < `0x2c00`) may. Then carve the partitions and run `e2fsck -fn` on `data.img` and `unsquashfs -s` on `rootfs.img` (Phase 2).

Why physical reads: every plug's `READ_LBA` stops at 32 MiB, but `READ_SECTOR` (opcode `0x04`) reads raw NAND pages with no limit. The SFTL layout needed to turn pages back into the logical disk is documented in `tools/sftl_rebuild.py` and [FIRMWARE_ANALYSIS.md](FIRMWARE_ANALYSIS.md). The one trap: the newest copy of a logical page is chosen by the **even** half's spare sequence, not the odd half's.

## 6. Phase 2: offline analysis (DONE 2026-10-23)

Results are in [FIRMWARE_ANALYSIS.md](FIRMWARE_ANALYSIS.md) and [STATUS.md](STATUS.md). Repeat on a new dump like this:

```bash
cd ~/partycade-dumps/<dir>
# PARTYCADE_REPO is the clone. The default is this machine's checkout.
python3 - <<'PY'
import json, os
repo = os.environ.get("PARTYCADE_REPO", os.path.expanduser("~/Projects/arcade1up-partycade"))
parts = json.load(open(os.path.join(repo, "captures/partitions.json")))["partitions"]
f = open("logical_rebuilt.img", "rb")
for p in parts:
    f.seek(p["offset"] * 512); open(p["name"] + ".img", "wb").write(f.read(p["sectors"] * 512))
PY
cp data.img /tmp/d.img && e2fsck -fn /tmp/d.img; rm /tmp/d.img     # must report no errors
unsquashfs -q -no-xattrs -d rootfs rootfs.img                       # device-node errors are fine as non-root
mkdir data_fs && debugfs -R "rdump / data_fs" data.img              # ext2 without root or mounting
```

## 7. Phase 3: decide how custom games get onto the cabinet

Option B is what tile 10 uses. Dig Dug II opens The Yard (Keep, Lamp, Orb, Tea, Chest), written 2026-10-23. Options A, A2, and C were not done. The notes below are how that choice was framed.

Present these to the user. Don't pick on their behalf. All of them need a custom game built for the cabinet's ABI: ARM hard-float, glibc 2.29, SDL2 2.0.7 (plus SDL2_image and SDL2_mixer) and ALSA from the rootfs. Input arrives as evdev keys from `uart-keys` (codes in STATUS.md). The simplest first payload is a script or binary started in place of one of the 12 menu entries by `/data/start.sh`.

| Option | What it is | Touches the NAND? | Needs |
| :--- | :--- | :--- | :--- |
| A. SD card | Factory U-Boot boots a Rockchip-format microSD first. Put stock `boot` (optionally with a device tree that enables ADB, see A2) and a copy of `rootfs`/`data` plus our games on a card | **No**, if the card is built right (Phase 4 caution) | Proof that U-Boot sees the slot (Phase 4 step 1). The user inserts cards |
| A2. ADB shell via SD | Same card, but the device tree's OTG `dr_mode` set to `peripheral`. The stock rootfs already starts `adbd` | No | Same as A. Then a root shell over the Micro-USB cable, from which everything else is easy and reversible |
| B. In-place edit of `data` | Modify a copy of `data.img` offline (e.g. `start.sh` entry 11 → our program in `/data/Games/`), turn that into a patched raw image with `sftl_patch.py`, then `rk_restore.py restore` only the few blocks it lists. Proven offline: adding a file and editing `start.sh` changed 6 blocks, and the rebuild reproduced the modified image exactly | **Yes**, a few blocks, fully reversible from the backup | The RECOVERY.md test ladder T1–T3 done first, a fresh `rawdump` right before, and the user's approval for the exact blocks |
| C. Replace the board | LVDS controller + USB encoder + SBC ([DEVELOPMENT_ROADMAP.md](DEVELOPMENT_ROADMAP.md) §3) | No | Hardware purchase |

Recommendation to give: A2 first if the SD slot works, because a shell makes everything else easy and touches nothing. B is the fallback that needs no SD slot and no cover removal.

Option B, step by step (only after T1–T3 pass and the user approves):

```bash
D=~/partycade-dumps/<fresh rawdump dir>            # Phase 1 procedure, taken minutes before
cp $D/data.img /tmp/work_data.img
debugfs -w -f - /tmp/work_data.img <<'EOF'          # example; prepare start.sh and the game first
rm start.sh
write my_start.sh start.sh
write mygame Games/mygame
EOF
e2fsck -fn /tmp/work_data.img                       # must be clean
cp $D/logical_rebuilt.img /tmp/work_logical.img     # splice the modified data back in
python3 - <<'PY'
import json
p = {x["name"]: x for x in json.load(open("captures/partitions.json"))["partitions"]}["data"]
f = open("/tmp/work_logical.img", "r+b"); f.seek(p["offset"] * 512); f.write(open("/tmp/work_data.img", "rb").read())
PY
tools/sftl_patch.py $D/nand_raw.bin $D/logical_rebuilt.img /tmp/work_logical.img $D/patched_raw.bin --part data
tools/sftl_rebuild.py $D/patched_raw.bin /tmp/check.img && cmp /tmp/check.img /tmp/work_logical.img
tools/rk_restore.py diff $D/nand_raw.bin            # cabinet must still match the fresh dump: "none"
PARTYCADE_ALLOW_NAND_WRITE=yes tools/rk_restore.py restore $D/patched_raw.bin --blocks <list from sftl_patch> --approval "..."
tools/rk_restore.py diff $D/patched_raw.bin         # must say "none"
```

`start.sh` must stay executable. Stock is mode `0744`, owner `1006:1001`, and the cabinet runs everything as root. debugfs `write` copies the host file's mode and owner, so follow each `write` with `set_inode_field <path> mode 0100744` (or `0100755` for binaries). This was tested 2026-10-23, and `e2fsck` stays clean. To undo: `rk_restore.py restore $D/nand_raw.bin --blocks <same list>`.

## 8. Phase 4: SD card boot

Read [FIRMWARE_ANALYSIS.md](FIRMWARE_ANALYSIS.md) § U-Boot first. The factory U-Boot's own device tree only has `dwmmc@1021c000`. A card is seen by U-Boot only if the slot is wired to that controller, in which case it is `mmc 0` and is chosen *before* the SPI NAND. The cheapest first test is to have U-Boot report what it sees, rather than to build a bootable card:

* With UART (cover off): Ctrl+C at power-on, then `mmc list`, `mmc dev 0`, and `mmc info` with a card in the slot. That's read-only.
* Without UART: a card that holds only a GPT with a `boot` partition containing a copy of the stock `boot.img` with a changed logo. If the logo changes, U-Boot booted the card. If the cabinet boots stock, U-Boot didn't see it. Pull the card to recover. The kernel on that card still mounts the stock rootfs from the SPI NAND by PARTUUID, which is fine for the test.

1. What `rkimgtest` accepts, from `reference/u-boot/cmd/rkimgtest.c`: it reads card sectors 64–65. It passes if the first 32-bit word is `0xFCDC8C3B`, the raw (still RC4'd) Rockchip boot-block magic, which the factory flash has. It also passes for the new-style tags `0x534e4b52` / `0x534e5252`.
2. > [!CAUTION]
   > When that check passes, U-Boot looks at the 32-bit word at **sector 65, byte offset 104**. If it is **zero**, U-Boot adds `sdfwupdate` to the kernel command line. That is Rockchip's *SD firmware-update* mode. **The factory boot block has zero there** (checked 2026-10-23). The stock rootfs and data contain nothing that reads `sdfwupdate`, `fwupdate`, or `update.img` (grep, 2026-10-23), so the stock system should ignore the flag. Still, before any SD card goes into the cabinet:
   > * Make the word at sector 65 + 104 non-zero on the card. Rockchip's SD tool does this for "boot" cards versus "upgrade" cards. Find out what value it writes, rather than guessing.
   > * Take a fresh `rawdump` first, so RECOVERY.md applies.
   > * Get the user's explicit OK, and explain the risk.
3. First card: copy the stock layout onto it from `logical_rebuilt.img` at the same LBAs (IDBlock with the tag fixed as above, uboot, boot, rootfs, data). This writes to the **SD card on the PC**, not to the cabinet. Change one visible thing (for example `logo.bmp` inside `boot`'s resource image) so it's obvious the card booted.
4. The user inserts the card with the switch **ON** and powers on. Success means the changed logo or behavior shows up. Pull the card and the stock system boots unchanged.
5. For A2 (ADB): the device tree lives in `boot`'s second-stage resource image (`rk-kernel.dtb`; see FIRMWARE_ANALYSIS.md). Change `usb@10180000` `dr_mode` from `host` to `peripheral`, repack, and boot. Then, with the switch ON and the Micro-USB cable to the PC, `adb devices` should list `rk3xxx`. Whether the back switch routes the Micro-USB port to the SoC when ON is unknown; if `lsusb` shows nothing, try the other switch position only after asking the user.
6. Then iterate on the SD rootfs: add our launcher or game.

## 9. Troubleshooting

| Symptom | Meaning | Action |
| :--- | :--- | :--- |
| `rk.py state` shows nothing | Switch ON, or a bad cold plug, or a charge-only cable | Cold plug with the switch OFF |
| `SPENT` in `state` | Something was already sent to this enumeration | Cold plug |
| A DDR chunk times out | The BootROM took bytes but the code didn't return | Spent. Check `rk.py build` hashes. One DDR change per cold plug (`ddr300`, `ddr456`) |
| `USB error … Pipe resynced` from a loader command | A bulk hiccup | Run `rk.py info` again. If it repeats, stop and record |
| `CSW mismatch` | The pipe is out of sync | Stop. Cold plug for a clean session |
| `info` flash size 0 | The plug doesn't drive this flash | Wrong plug: use `plug_3032slc` |
| Sectors differ between two reads | Not real data (buffer noise) | Wrong plug, or the storage isn't initialised |
| `READ_LBA` data is all `0xCC` | Plug limit for LBA ≥ `0x10000` | Use `rawdump` + `sftl_rebuild.py` instead |
| `diff` reports `data` blocks after the cabinet was played | High scores and settings were saved | Expected. Take a fresh `rawdump` before any planned change |
| `diff` reports blocks outside `data` | Something changed the boot chain or rootfs | Stop. Record it. [RECOVERY.md](RECOVERY.md) |
| `e2fsck` on a rebuilt `data.img` reports errors | Rebuild chose stale copies | Check `sftl_rebuild.py` still selects by the **even**-half sequence |
