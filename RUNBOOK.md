# Runbook

How to operate on this cabinet, step by step, and what to do next. Read [STATUS.md](STATUS.md) first for the current facts. This file is about procedure.

Every command below is run from the repo root, `~/Projects/arcade1up-partycade`.

## 1. Hard rules

These come from mistakes already made on this board. Do not relax them without asking the user.

1. **Never write, erase, or reset the cabinet's flash.** `tools/rk.py` has no code for it, and its command builder refuses every opcode except the read-only ones. Do not use `rkdeveloptool`, `xrock`, `rkflashtool`, or `upgrade_tool` against the cabinet. They all have write, erase, and reset commands that are one typo away (`wl`, `ef`, `ul`, `db`, `rd`, `w`, `e`, `P`, ...). They are in `reference/` to be *read*, not run.
2. **Never USB-reset the BootROM** (`libusb_reset_device`, `usbreset`, unbind/rebind, `dev.reset()`). It wedges the chip until a cold plug. This happened on devices 38–43.
3. **One download attempt per Mask ROM enumeration.** If a stage times out, that enumeration is spent. Don't retry, don't clear-halt. Record it and ask for a cold plug. `rk.py boot` enforces this through the log.
4. **A running plug can't be replaced.** Trying a different plug always needs a fresh Mask ROM: either a cold plug, or the warm reset some plugs do on their own.
5. **One hypothesis per boot.** Write down what the boot tests before running it.
6. **Dumps go to `~/partycade-dumps/`, never into git.** It is stock firmware and licensed games. `rk.py` refuses to write more than 1 MiB inside the repo. Commit only metadata: partition tables, file listings, hashes, small text configs, device tree text.
7. **Log everything.** `rk.py` appends to `logs/rk_log.jsonl` by itself. Write a human summary into [BOOT_RESEARCH.md](BOOT_RESEARCH.md) and update [STATUS.md](STATUS.md) at the end of every session.
8. **Ask the user for anything physical:** cold plugs, the cover, UART wiring, SD cards. Tell them exactly what to do and what state to leave the switch in.

## 2. One-time setup on a new machine

```bash
tools/fetch_references.sh      # shallow clones into reference/ (gitignored, ~15 MB)
make -C tools                  # builds tools/rksend (needs gcc + libusb-1.0 runtime; header is vendored)
python3 -c 'import usb'        # pyusb must be installed: pip install --user pyusb
tools/rk.py build              # builds build/*.wire and checks each against its known-good sha256
```

`rk.py build` must print `matches known-good` for every stage. A `HASH MISMATCH` means the reference blobs changed upstream. Stop and investigate, and don't send anything.

USB permissions: the device node is `root:plugdev` with a `+` ACL for the logged-in user, which has been enough on this OptiPlex. If you get `Access denied`, the user needs a udev rule for `2207:*` (ask them; don't `sudo` the tool).

## 3. Cold plug (the user does this)

Give the user these exact words:

> 1. Unplug the 12V barrel plug. 2. Unplug the Micro-USB cable. 3. Make sure the switch on the back is **OFF**. 4. Plug in the barrel plug. 5. Plug in the Micro-USB cable. The screen stays dark.

Then run `tools/rk.py state`. Expect `mode=maskrom` and `fresh BootROM, nothing sent yet`. Cable: the straight Micro-USB to USB-A cable on rear port `1-6` has been the reliable setup. Any data-capable cable and port works.

If nothing shows up, both plugs were not out at the same time, or the cable is charge-only. Have them redo it with a few seconds' pause while unplugged.

## 4. The session loop

```bash
tools/rk.py state                       # what is on the bus; no USB traffic
tools/rk.py boot --plug <name>          # DDR 396 + plug into RAM; only on a fresh Mask ROM
tools/rk.py info                        # chip, flash ID, size, capability, >32 MiB check
tools/rk.py probe                       # header sectors read twice; GPT/PARM/IDB detection
tools/rk.py parts                       # GPT (or PARM) -> captures/partitions.json
tools/rk.py dump --start 0 --count <N> -o ~/partycade-dumps/<dir>/full.img --verify
tools/rk.py log -n 20                   # what has been done
```

`boot` exit codes: 0 loader up; 2 DDR stage failed; 3 plug stage failed; 4 nothing re-enumerated; 5 the plug reset the chip back to a fresh Mask ROM. Exit code 5 means you can `boot` again right away with a different plug.

Every `dump` writes `<file>.sha256`, which records how many sectors were `0xCC` fill and which plug served the data. A dump with fill sectors is **incomplete**. Say so wherever it is mentioned.

## 5. Phase 1: read the whole flash (current phase)

Goal: a verified dump of all 220672 logical sectors with no `0xCC` fill.

### Step 1.1: `plug_3032slc` (next boot)

Test: does Rockchip's RK3032 SLC/SPI-NAND plug (SFTL 5.0.58) serve sectors at or above `0x10000`?

```bash
tools/rk.py state                 # must be fresh maskrom
tools/rk.py boot --plug plug_3032slc
tools/rk.py info                  # look at flash_id, flash_info.sectors, reads_at_or_above_0x10000
```

| Result | Next |
| :--- | :--- |
| Loader up, `reads_at_or_above_0x10000: data` | Step 1.2 |
| Loader up, size 0 or `0xCC fill` | Record. The chip now runs this plug, so go to Step 1.3 (needs a cold plug) |
| Exit 5 (reset to Mask ROM) | Record. `tools/rk.py boot --plug plug_3032` on the new device to get back to a working loader, then Step 1.3 |
| Exit 2/3/4 | Record. Ask for a cold plug. Re-check `rk.py build` hashes before anything else |

### Step 1.2: full verified dump

```bash
D=~/partycade-dumps/$(date +%F)_plug3032slc; mkdir -p $D
tools/rk.py dump --start 0 --count 220672 -o $D/full.img --verify
head -c $((0x10000*512)) $D/full.img | sha256sum
```

Three acceptance checks:

1. The `.sha256` file says `fill_sectors=0`. If not, look at where the fill is: a few scattered 64 KiB runs could be genuinely unwritten space, while one solid run from some LBA to the end is a plug limit.
2. The first-32 MiB hash must equal `342b0e8b6d0f9ced282e381efef8226fb3b2f7b2e6276eae8438581eee3e1fba`, the earlier `plug_3032` dump. If it differs, the two plugs disagree about the logical layout. Stop and investigate before trusting either.
3. Run a second full pass without `--verify` to a temp file, and the sha256 must match. Delete the temp file afterwards.

Then do Phase 2.

### Step 1.3: if no USB plug can read past 32 MiB

Do these in order. Each one is a separate decision, so ask the user before the physical ones.

1. **Larger-scope research, no hardware.** Use `strings` on each plug in `reference/rkbin/bin/rk30/` and compare it with the factory boot block (`~/partycade-dumps/extracted/IDBlock.img`). The factory boot block carries Boot1 (built Dec 23 2020, SFTL 5.0.55). It is a *miniloader*, not a usbplug, so it can't be downloaded as `0x472` as-is. Look at whether the `0xCC` boundary moves with any plug.
2. **The factory U-Boot's own download mode (rockusb).** U-Boot 2017.09 on this board contains `enter Rockusb!`. Rockusb speaks the same bulk protocol, and `rk.py` should work against it unchanged (its mode detection treats any device with string descriptors as a loader). It uses the factory's own SFTL, so it should read the whole flash. Ways in, all with the switch **ON** (a normal boot):
   * Hold a "download" key during power-up. Whether any cabinet button is wired as that key is unknown, so try it last.
   * Serial hotkey: with a 3.3 V USB-UART on the TX/RX/GND pads (VCC left unconnected, 115200 8N1), hold **Ctrl+D** in the terminal while powering on. Rockchip U-Boot's `hotkey.c` maps Ctrl+D to rockusb and Ctrl+C to the U-Boot shell (`bootdelay=0`, so send it repeatedly from before power-on). This **needs the cover removed**. Ask the user, and tell them what adapter they need.
   * In the U-Boot shell (Ctrl+C), `rockusb 0 spinand 0` (or `download`) also starts it. Shell commands like `md`, `mtd`, `sf`, and `rksfc` can read too, but don't run anything with `write`, `erase`, `env save`, or `saveenv`.
3. **SD card route for the dumper itself.** U-Boot boots a Rockchip-format microSD before the SPI NAND (Phase 4). A minimal Linux on SD could read `/dev/rkflash0` or the SFTL block device and copy it to the SD card. That's more work, but it never needs the cover off. The same `sdfwupdate` caution as in Phase 4 applies.

## 6. Phase 2: offline analysis (no hardware)

Everything happens in `~/partycade-dumps/<dir>/`. Record the results in [FIRMWARE_ANALYSIS.md](FIRMWARE_ANALYSIS.md).

```bash
cd ~/partycade-dumps/<dir>
python3 - <<'PY'
import json
parts = json.load(open("/home/joseph/Projects/arcade1up-partycade/captures/partitions.json"))["partitions"]
f = open("full.img", "rb")
for p in parts:
    f.seek(p["offset"] * 512); open(p["name"] + ".img", "wb").write(f.read(p["sectors"] * 512))
PY
file *.img; blkid rootfs.img data.img
unsquashfs -no-xattrs -d rootfs rootfs.img          # errors about device nodes are fine as non-root
```

Then answer these, in order. Each answer goes into FIRMWARE_ANALYSIS.md with paths, and no binaries go into the repo:

1. **What is `data`?** Use `file`, `blkid`, `binwalk` if installed (`pip install --user binwalk` or `apt`), and the first sectors in hex. Mount read-only with a loop device if it's ext2/4 or FAT (`sudo mount -o ro,loop`; ask the user for sudo). It is SquashFS if the magic is `hsqs`.
2. **Boot path to the menu:** `rootfs/etc/inittab`, `rootfs/etc/init.d/` (`rcS`, `S*`), and any `/etc/profile.d` or `/root` autostart. Follow it to the launcher binary.
3. **The launcher:** `file` and `readelf -d` (libraries: SDL? DirectFB? fbdev? DRM?), and `strings` for config paths, ROM paths, and game names.
4. **The game list:** `grep -rIl -i -e pac -e galaga -e 'dig dug' -e rom -e '\.zip' rootfs data_mount`. Look for an ini, json, xml, csv, or a table compiled into the launcher.
5. **The emulator:** a separate binary (MAME build? custom?) or built into the launcher. Note its ROM-set format.
6. **Platform ABI for our own code:** `file rootfs/bin/busybox` (ARM EABI5 hard or soft float?), `ls rootfs/lib` (glibc or uClibc or musl, and versions), `/dev/fb0` vs DRM use, audio (ALSA `rockchip,rk3032-codec`), input (evdev from `uart-keys`, codes in STATUS.md).

## 7. Phase 3: decide how custom games get onto the cabinet (decision with the user)

Present these to the user. Don't pick on their behalf.

| Path | What it is | Touches flash? | Needs |
| :--- | :--- | :--- | :--- |
| A. SD card boot | Factory U-Boot already runs `rkimgtest mmc 1` and boots the SD card first. Put our own GPT + boot + rootfs (a copy of stock plus our games, or a new system) on a microSD. | **Not if the card is built right.** A card whose boot block looks like an *update* card can trigger flashing (Phase 4 caution). | Confirm the slot is wired (the user says there is a slot, and it's empty). Phase 4. |
| B. Add to the stock launcher | If Phase 2 shows a config-driven game list, add entries and files in `data`/`rootfs`. | **Yes** (rootfs is read-only SquashFS, so it means repacking and writing) | A write tool that doesn't exist, a verified full backup, a tested restore path, and explicit user approval |
| C. Replace the board | LVDS controller + USB encoder + SBC ([DEVELOPMENT_ROADMAP.md](DEVELOPMENT_ROADMAP.md) §3) | No | Hardware purchase |

Path A is the recommended first path: it's reversible, and the factory bootloader supports it.

## 8. Phase 4: SD card boot (sketch, to be refined after Phase 2)

Read [FIRMWARE_ANALYSIS.md](FIRMWARE_ANALYSIS.md) § U-Boot first. The factory U-Boot's own device tree only has `dwmmc@1021c000`. A card is seen by U-Boot only if the slot is wired to that controller, in which case it is `mmc 0` and is chosen *before* the SPI NAND. The cheapest first test is to have U-Boot report what it sees, rather than to build a bootable card:

* With UART (cover off): Ctrl+C at power-on, then `mmc list`, `mmc dev 0`, and `mmc info` with a card in the slot. That's read-only.
* Without UART: a card that holds only a GPT with a `boot` partition containing a copy of the stock `boot.img` with a changed logo. If the logo changes, U-Boot booted the card. If the cabinet boots stock, U-Boot didn't see it. Pull the card to recover. The kernel on that card still mounts the stock rootfs from the SPI NAND by PARTUUID, which is fine for the test.

1. What `rkimgtest` accepts, from `reference/u-boot/cmd/rkimgtest.c`: it reads card sectors 64–65. It passes if the first 32-bit word is `0xFCDC8C3B`, the raw (still RC4'd) Rockchip boot-block magic, which the factory flash has. It also passes for the new-style tags `0x534e4b52` / `0x534e5252`.
2. > [!CAUTION]
   > When that check passes, U-Boot looks at the 32-bit word at **sector 65, byte offset 104**. If it is **zero**, U-Boot adds `sdfwupdate` to the kernel command line. That is Rockchip's *SD firmware-update* mode, which on many Rockchip systems rewrites the internal flash from the card. **The factory boot block has zero there** (checked 2026-10-23). So a byte-for-byte clone of the factory `IDBlock` onto a card is the dangerous case. Before any SD card goes into the cabinet:
   > * Make the word at sector 65 + 104 non-zero on the card. Rockchip's SD tool does this for "boot" cards versus "upgrade" cards. Find out what value it writes, rather than guessing.
   > * Grep the full rootfs and data for `sdfwupdate`, `fwupdate`, `update.img`, and `rkupdate`, to learn whether the stock system acts on that flag at all.
   > * Get the user's explicit OK, and explain the risk.
3. First card: copy the stock layout onto it, from the verified dump at the same LBAs (IDBlock with the tag fixed as above, uboot, boot, rootfs, data). This writes to the **SD card on the PC**, not to the cabinet. Change one visible thing (for example `logo.bmp` inside `boot`'s resource image) so it's obvious the card booted.
4. The user inserts the card with the switch **ON** and powers on. Success means the changed logo or behavior shows up. Pull the card and the stock system boots unchanged.
5. Then iterate on the SD rootfs: add our launcher or game, built for the ABI found in Phase 2.

## 9. Troubleshooting

| Symptom | Meaning | Action |
| :--- | :--- | :--- |
| `rk.py state` shows nothing | Switch ON, or a bad cold plug, or a charge-only cable | Cold plug with the switch OFF |
| `SPENT` in `state` | Something was already sent to this enumeration | Cold plug |
| A DDR chunk times out | The BootROM took bytes but the code didn't return | Spent. Check `rk.py build` hashes. One DDR change per cold plug (`ddr300`, `ddr456`) |
| `USB error … Pipe resynced` from a loader command | A bulk hiccup | Run `rk.py info` again. If it repeats, stop and record |
| `CSW mismatch` | The pipe is out of sync | Stop. Cold plug for a clean session |
| `info` flash size 0 | The plug doesn't drive this flash | Wrong plug; see the plug table in STATUS.md |
| Sectors differ between two reads | Not real data (buffer noise) | Wrong plug, or the storage isn't initialised |
| Data is all `0xCC` | `plug_3032` fill for LBA ≥ `0x10000` | Phase 1 |
