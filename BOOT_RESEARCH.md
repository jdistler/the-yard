# Boot And Game-List Research

> This is the chronological lab notebook. Early sections contain theories that later turned out wrong (cables, 300 MHz, "RK3036", "eMMC"). For the current truth, read [STATUS.md](STATUS.md). For procedure, read [RUNBOOK.md](RUNBOOK.md).

Notes from the live cabinet. The goal is to learn how this Partycade boots, where the stock game list comes from, and what it would take to add a game we wrote. Early sessions only read the flash. From device 60 on, approved restores did write. The current chip is not the morning master. See STATUS.md "Pickup".

## Where to start

Mask ROM (back switch **OFF**, screen dark, USB ID `2207:301a`) is the right first state.

The stock game menu is not running in that state. The BootROM has skipped the onboard flash on purpose. The 12-game list, the launcher, and the Linux system that draws the menu all live in that flash, and they only start when the switch is **ON** at cold power-up:

```text
BootROM  ->  loader in flash  ->  Linux  ->  launcher reads the game list  ->  menu on the 17" panel
```

Switch **ON** is the wrong state for inspection from this PC. In that mode the Micro-USB port becomes a USB host, so the cabinet never appears as a device here, and the kernel messages go to the 3.3V UART pads inside the shield instead of USB.

So the work splits in two:

1. Stay in Mask ROM and read the flash, without booting the menu and without writing anything.
2. From that read, find the launcher and the file or table that names the games. Adding our own game means fitting whatever that launcher already knows how to start, or replacing the launcher. Which of those is realistic depends on what the flash actually contains. That is still unknown.

## What Mask ROM will and will not answer

Verified on this cabinet, 2026-10-23, while `2207:301a` was on the bus (port `1-6`, device 38, high-speed, `bcdDevice 1.00`):

| What we can see immediately | What we cannot see yet |
| :--- | :--- |
| USB identity `2207:301a`, "RK3036 in Mask ROM mode" | Chip details beyond the USB product ID (the bulk chip-info command) |
| One vendor interface, class `0xFF` / subclass `6` / protocol `5` | Flash type, size, or partition table |
| Bulk EP `0x81` IN and EP `0x02` OUT, 512-byte packets, bus-powered 400 mA | The game list, rootfs, or boot logs |
| No manufacturer, product, or serial strings | |

The bulk endpoints are advertised by the BootROM, but they do not carry the Rockchip command protocol yet. A standard read-only command block (test-unit-ready, read-chip-info `0x1B`, read-flash-id `0x01`, read-flash-info `0x1A`) was submitted on EP `0x02`. The host got USB protocol error `-71` (`EPROTO`) on the first packet, with zero bytes transferred. That is expected: before a USB plug is running, the BootROM only implements control-pipe downloads, so nothing answers bulk command blocks. It was never a cable result. `GET_STATUS` on the control pipe is stalled by this BootROM (pipe error), which is normal for a BootROM that only implements the requests it needs. Enumeration itself (device descriptor, configuration) succeeds.

The next step, which still does not write flash, is to send a DDR-init blob and a USB plug into RAM over the control pipe (vendor request `0x40` / `0x0C`, indexes `0x0471` then `0x0472`). Those Rockchip blobs are the public `rk3036_ddr_*` and `rk303x_usbplug_*` files. Once the plug is running, the same bulk commands can identify the storage and read it. Rockchip's own tools RC4-encrypt both stages with the published 16-byte mask-ROM key before the CRC-16/CCITT trailer. The encoding is documented in [tools/README.md](tools/README.md).

Every download before 11:20 on 2026-10-23 was plaintext, and most used the 300 MHz blob. Rockchip's RK3036 loader uses the 396 MHz blob. Flash was not modified by any of them.

## USB reset warning

The BootROM brings up its USB device block once, at cold power-up. A port reset from this PC does not run that startup again. After the link is wedged, only removing both the Micro-USB cable and the 12V barrel (USB VBUS back-powers the CPU) gets a new enumeration.

What happened on 2026-10-23, and what not to repeat:

* Bulk reads failed with `EPROTO` (`-71`). That left the pipe unhappy. The right response was to stop.
* Instead, `libusb` port resets were sent to "clear" it. 10:28:46 and 10:31:10 were still answered and the chip stayed device 38.
* A later reset, issued while a control transfer was already timing out, was not answered. From 10:32:30 the kernel logged `device descriptor read/64, error -110`, then `device not accepting address, error -71`, then a disconnect. The host kept retrying addresses 39–42 on its own and the BootROM never came back.
* 10:37:47 — after the cold-plug sequence, it enumerated cleanly again as device 43, still `2207:301a` on port `1-6`.

Rules for the next session: do not call a USB port reset, do not clear-halt in a loop, and do not leave a probe blocked inside `libusb`. If a transfer returns `EPROTO` or times out, stop. Cancelling the transfer is itself enough to wedge the control pipe. Flash was not written during any of this.

## Second session, device 43 (10:37 cold plug, same cable and blue SS port)

One vendor control OUT was sent on the fresh enumeration: the Rockchip DDR-init blob `rk3036_ddr_300MHz_v1.11.bin` (3804 bytes, "RK30" header) plus the CRC-16/CCITT trailer the BootROM expects, request `0x40` / `0x0C`, index `0x0471`. No RC4. No port reset. The transfer timed out at 4 seconds. `lsusb` still listed device 43, and the kernel logged nothing new, but a following `GET_DESCRIPTOR` on endpoint 0 also timed out. The BootROM had stayed inside the cancelled control transfer and will not answer again until both plugs are pulled.

That means a loader upload is not a safe thing to retry on this cable. Enumeration uses an 18-byte descriptor read and succeeds. The loader upload is one 3806-byte control write and does not complete. The same split showed up earlier as `EPROTO` on the first 31-byte bulk packet. Short setup packets work. The following data stage does not. The cable in use is USB-C to USB-A on a blue SuperSpeed port, with the cabinet jack being Micro-USB, so there is an adapter in the path. That is the thing to change before another upload is attempted.

## Hub test, device 47 (2026-10-23 10:55)

The front USB-C port brought up a bus-powered dock, not a single hub:

* Port `1-2` / `2-2`: VIA Labs `2109:2817` (USB 2.0) and `2109:0817` (USB 3.0).
* Behind that, a Realtek RTS5411 `0bda:5411` (USB 2.0) and `0bda:0411` (USB 3.0). The dock also enumerated a Genesys SD reader and a Realtek RTL8153 Ethernet adapter on the SuperSpeed side.
* The RK3036 enumerated on the USB 2.0 side at `1-2.2.4`, device 47, `2207:301a`, high-speed, at 10:55:25. Same cable and rigid Micro-USB-to-USB-C adapter as the direct rear-port attempts.

One DDR-init control write (`0x471`, 3806 bytes on the wire) timed out at 5 seconds. No port reset, no second try. A descriptor read after that also timed out, so the control pipe is stuck again until both plugs are pulled. Two hub transceivers between the PC and the cabinet did not change the failure. The pieces still shared with the failing direct connection are the USB-C-to-USB-A cable and the rigid Micro-USB-to-USB-C adapter.

## Direct cable, no SET_CONFIGURATION, device 49 (2026-10-23 11:05)

Same straight Micro-USB to USB-A cable, rear port `1-6`, fresh enumeration at 11:04:48 as device 49. Interface claimed, kernel configuration left as enumeration set it, no `SET_CONFIGURATION` from this process. One `0x471` write of the 300 MHz DDR blob timed out at 5.00 seconds. No USB disconnect was logged. The control pipe stopped answering after the host cancelled the transfer.

## Direct Micro-USB to USB-A cable, device 48 (2026-10-23 11:02)

The hub was unplugged at 10:59:43. A straight Micro-USB to USB-A cable then enumerated the RK3036 directly on rear port `1-6` as device 48 at 11:02:36. No rigid adapter, no USB-C cable, no hub. Same Mask ROM identity, high-speed.

The same single DDR-init control write timed out at 5.00 seconds. A descriptor read afterward timed out too, so the control pipe is stuck again. No port reset was sent.

Three different wires have now failed the same write and succeeded at enumeration:

| Path | Enumerates `2207:301a` | 3806-byte `0x471` write |
| :--- | :--- | :--- |
| Rigid adapter + USB-C-to-USB-A, rear USB-A | yes | timeout, pipe sticks |
| Same adapter and cable, through VIA + Realtek hubs | yes | timeout, pipe sticks |
| Straight Micro-USB to USB-A, rear port `1-6` | yes | timeout, pipe sticks |

The cable, the adapter, and the hub are not the cause. The BootROM answers the short setup packets used to enumerate, and it does not complete this control write on this Intel xHCI controller. The next attempt changes the transfer, not the wire: skip `SET_CONFIGURATION` (the kernel already did that), and send the image as a series of small control writes instead of one 3806-byte write. The first small write that times out ends the attempt.

## Device 49 (2026-10-23 11:04)

The cable/transfer theory in the section above was later shown wrong. The payload was plaintext (see the 11:20 review).

Device 49 came up at 11:04:48 on the same direct cable and rear port `1-6`. The DDR-init write was sent again with no `SET_CONFIGURATION` and no port reset. It timed out at 5.00 seconds. The kernel logged no disconnect, and the control pipe then stopped answering. Splitting that write into smaller pieces would not be the same transfer: the BootROM treats a control write shorter than 4096 bytes as the end of the image, and this image is already 3806 bytes, so it is already a single ending write.

## Step 0 result, device 50 (2026-10-23 11:12)

Same plaintext `rk3036_ddr_300MHz_v1.11.bin`, checksum `0xfb07`, 3806 bytes on the wire. One asynchronous vendor write, no `SET_CONFIGURATION`, no port reset.

| Field | Value |
| :--- | :--- |
| Host status | `LIBUSB_TRANSFER_TIMED_OUT` (2) |
| `length` | 3814 (8-byte setup + 3806 data) |
| `actual_length` | 3806 |

The chip accepted every data byte. The five seconds were the status stage, which never completed. The kernel logged no disconnect, and the device stayed at address 50. No second transfer was sent. This boot is spent.

The image was taken. What did not finish is the handshake after it, which the BootROM sends only after the downloaded code returns.

## Review, 2026-10-23 11:20

Before the next boot, the earlier work was checked against Rockchip's source. Findings (the plan file from that time, MASKROM_PLAN.md, was later replaced by RUNBOOK.md):

* Rockchip's packer (`rkdeveloptool` `writeFile`, `fix = false`) pads each USB stage to 2048 bytes and RC4-encrypts it. `DownloadBoot` sends those bytes as stored. Our plaintext downloads were not what this BootROM runs, which explains step 0: every byte accepted, then no return.
* `rkbin/RKBOOT/RK3036MINIALL.ini` uses `rk3036_ddr_396MHz_v1.11.bin` with a 1 ms sleep, then `rk303x_usbplug_v2.57.bin`.
* Our CRC and short-write framing match `RKU_DeviceRequest` and xrock.
* The padded, RC4'd 396 MHz payload built in Python is byte-identical to Rockchip's own `P_RC4` and `CRC_CCITT`, compiled unmodified: 4098 bytes on the wire, CRC `0x704e`, decrypting back to the `RK30` header.
* For the USB plug, Rockchip's `P_RC4` truncates its length to 16 bits and only encrypts the first 38,912 bytes. xrock encrypts all 103,388. xrock goes first.
* The cable, adapter, and hub changes did not affect any result. The bulk `EPROTO` at the start was expected behavior before a loader runs.

Device 51 (11:13:24) is untouched and is Boot A in the plan.

## Boot A, device 51 → 52 (2026-10-23 11:18): the loader runs

The same straight cable on rear port `1-6`. No `SET_CONFIGURATION` and no reset. Sent with `rksend` (asynchronous, 10 s per chunk).

| Stage | Wire | Chunks | Result |
| :--- | :--- | :--- | :--- |
| `0x471` `rk3036_ddr_396MHz_v1.11.bin`, padded + RC4 | 4098 B, CRC `0x704e` | 4096 + 2 | both completed, status stage returned |
| `0x472` `rk303x_usbplug_v2.57.bin`, xrock RC4 | 103390 B, CRC `0x219b` | 25 × 4096 + 990 | all completed |

About a second after the last chunk, the kernel logged a disconnect of device 51. Device 52 then enumerated on `1-6` as the same `2207:301a` and `bcdUSB 2.00`, but with strings `RockChip` / `USB-MSC` / `rockchip`. The interface is still `0xFF/6/5` with bulk `0x81`/`0x02`, and no kernel driver binds to it. That is Rockchip's USB plug. RC4 was the missing piece, and 396 MHz trains.

Read-only bulk commands to the plug:

| Command | Reply | Reading |
| :--- | :--- | :--- |
| test-unit-ready `0x00` | status 0 | |
| chip info `0x1B` | `41333033` + `0xFF`… | `A303` reversed = `RK303A`, the chip name in Rockchip's RK3036 loader config |
| flash ID `0x01` | `454d4d4320` | ASCII `EMMC ` |
| flash info `0x1A` | `00000000 0004 04 00 28 00 00` | size **0 sectors**, block 1024, page 4, chip-select mask 0 |
| capability `0xAA` | `07` | direct LBA, vendor storage, first-4M access |
| read storage `0x2B` | no data, CSW status 1 | not supported by this plug. The first attempt with a 4-byte buffer overflowed on the 13-byte CSW. One drain read plus test-unit-ready resynced the pipe. |
| read LBA `0x14` at 0, 1, 64, 0x2000 | status 0, data returned | every sector mostly `0xFF` with scattered cleared bits; the four 512-byte blocks at 0x2000 all differ, and the sectors at 0, 1, and 64 share one pattern. No MBR, GPT, IDB, or `PARM`. |

Reading: the standard plug runs in eMMC mode (its flash-ID string) and finds no eMMC (size 0, CS mask 0). The "sectors" are the unfilled DMA buffer, which explains why they look like `0xFF` RAM noise. This board most likely uses SLC NAND or SPI flash. Rockchip ships `rk303x_usbplug_slc_v2.65.bin` for that case. Its release notes add SPI NOR in 2.64 and wrong-ID filtering in 2.65, and `RK3036MINIALL_SLC.ini` pairs it with the same 396 MHz DDR blob. That plug is Boot D in the plan. It needs a cold plug, because the BootROM is no longer on the bus once a plug runs.

UART remains the other window, and only for a normal (**ON**) boot: 3.3V TX/RX/GND pads inside the shield, 115200 or 1.5 Mbaud, VCC left unconnected. That shows kernel messages. It does not, by itself, show the game-list file.

## Session 3, devices 53–56 (2026-10-23 11:23–11:40): the flash is read

All runs used `tools/rk.py`, and its log is in `logs/rk_log.jsonl`. Same cable and port (`1-6`). Every DDR stage was `ddr396`, and every stage completed in full (every chunk `actual == len`, status 0).

| Device | Plug | Outcome |
| :--- | :--- | :--- |
| 53 (cold plug 11:23:12) | `plug_slc` (`rk303x_usbplug_slc_v2.65`) | Plug accepted (23 chunks). The chip disconnected and re-enumerated 0.27 s later as **device 54, a fresh Mask ROM** (no strings). The plug started and then the chip reset. |
| 54 (warm reset) | `plug_slc264` (`rk303x_usbplug_slc_v2.64`) | Same as above. Device 55 is a fresh Mask ROM. The 2.65 flash-ID filter isn't the cause. |
| 55 (warm reset) | `plug_3032` (`rk3032_usbplug_v2.61`) | **Loader up as device 56** (`RockChip`/`USB-MSC`/`rockchip`). |

What device 56 reported:

* Chip info `32333033…` = `3032`. Flash ID `ef aa 21 53 7b`, and on a second read `ef aa 21 53 df`, so only the first three bytes are meaningful. `EF AA 21` is the Winbond W25N01GV, a 1 Gbit SPI NAND. Flash info: 220672 sectors (107.75 MiB), block 256 sectors, page 4 sectors, CS mask 1. Capability `0x27`.
* The probe shows every header LBA stable across two reads. LBA 0 is a protective MBR, LBA 1 is `EFI PART`, LBA 0x40 is the Rockchip boot block (`3b8cdcfc`, which decrypts to `55aaf00f`), LBA 0x400 is `LOADER  `, and LBA 0x800 is `ANDROID!`.
* GPT: `IDBlock`, `uboot`, `boot`, `rootfs`, `data` (see `captures/partitions.json`).
* Full dump of 220672 sectors with `--verify` took 22 s. A second pass without verify gave the identical sha256 `4841f3a6…`.

The 32 MiB wall: every sector from LBA `0x10000` up came back as `0xCC` with CSW status 0, including the whole `data` partition and the rootfs past its first 27.8 MB. The SquashFS table pointers read `0xcccccccc`. Tests on the same boot:

* A read *starting* at `0x10000` or above gives `0xCC`, with subcode 0 or 1 (`RWMETHOD_IMAGE`/`RWMETHOD_LBA`).
* A 128-sector read starting at `0xffc0` returned non-`0xCC` bytes for its last 64 sectors. A 0x2000-sector read starting at `0xF000` returned `0xCC` for all 4096 sectors past `0x10000`, and the two disagree. Conclusion: those non-`0xCC` bytes were stale buffer contents. Nothing above `0x10000` has been read for real.
* Reads below `0x10000` are consistent between overlapping large and small reads.

Offline (`~/partycade-dumps/extracted/`):

* The factory boot block is plaintext past its header. DDR `V1.09 20171120`, Boot1 built Dec 23 2020, `SFTL version: 5.0.55 20200925`, `sfc_nand` and `sfc nor` drivers.
* SFTL versions of the candidate plugs: `rk3032_usbplug_v2.61` 5.0.53 (the one that works but stops at 32 MiB); `rk3032_usbplug_slc_v2.63`, `rk303x_usbplug_slc_v2.64`, and `v2.65` all 5.0.58. `rk303x_usbplug_v2.57` has no SFTL, which explains why it only tried eMMC.
* `boot`: Android boot image v0, zImage, which decompresses to Linux 4.4.194, built 2023-05-11. No ramdisk. The second-stage blob is a Rockchip RSCE resource containing `rk-kernel.dtb` ("Rockchip RK3032 Dongle") and `logo.bmp`.
* Device tree highlights: 128 MiB RAM, OTG `dr_mode = "host"`, `uart-keys` input mapping, uart0 the only UART enabled, every MMC controller disabled, `sfc` okay. Decoded text is in `captures/device-tree.txt`.
* `uboot`: U-Boot 2017.09-g97b7efa-dirty (2023-05-11), `bootdelay=0`. The env checks an SD card first. It has rockusb and download-key support. Its embedded tree has only uart2, `sfc`, and `dwmmc@1021c000`.
* `rkimgtest` (Rockchip U-Boot source) sets `sdfwupdate` when the word at sector 65 + 104 is 0, and the factory boot block has 0 there.

Next is `plug_3032slc` on a cold plug, which is RUNBOOK Phase 1, Step 1.1. Device 56 was left running `plug_3032`.

Tool hardening the same session: a test dump of LBA `0xFFF0`+32 showed no fill warning, because the crossing read returned stale bytes. `read_lba` now splits at every `0x10000` boundary, and the same dump now reports 16 real sectors and 16 fill sectors. The full backup above was unaffected: its 128-sector reads ended exactly at `0x10000`.

## Session 4, devices 57–58 (2026-10-23 11:50–12:40): the whole chip, and a recovery plan

Cold plug, then `boot --plug plug_3032slc` on device 57, which came up as loader device 58. `info`: chip `3032`, flash `EF AA 21`, 220672 sectors, 256-sector blocks, 4-sector pages, capability `0x27`. `READ_LBA` at ≥ `0x10000` still returned `0xCC`. So the 32 MiB limit is the same in both RK3032 plugs.

**The way around it: `READ_SECTOR` (opcode `0x04`) reads physical NAND, and has no limit.** Each sector is 528 bytes (512 data + 16 spare), and the chip is 262144 sectors (1024 blocks × 64 pages × 4). I added the opcode to `rk.py`'s read-only list and added `rk.py rawdump`.

* `rawdump --verify`: every chunk read twice and matched. A second full pass without verify gave the identical sha256 `024af9ed…429e`. Each pass takes about 40 s.

**Rebuilding the logical disk** (`tools/sftl_rebuild.py`, offline):

* Attempt 1 used the odd-half spare `u32@0` as the LPA and accepted every page: 208 sectors differed from the `READ_LBA` dump in the first 32 MiB.
* Attempt 2 accepted only pages whose even-half spare has type `0xF095` and pair index = block/2: **0 sectors differed** in the first 32 MiB. But above 32 MiB, `e2fsck -fn data.img` found multiply-claimed blocks and bitmap differences, and `PacLand.sav` showed as a deleted inode.
* Root cause: the newest copy was chosen by the odd-half `u32@+4`, which isn't an ordering. LPA `0x482A` had copies in block pair 90/91 (odd `u32@+4` = `0x3082a`, data = PNG bytes, wrong) and pair 390/391 (`0xb42b`, data = the expected ext2 indirect-block list 2731, 2732, …). The even-half `u32@+4` ranks them correctly (`0x6434` < `0xacd0`), and within a block it counts up by one per page. So it's the write sequence.
* Attempt 3 selects by the even-half sequence: 0 sectors differ in the first 32 MiB, `e2fsck -fn data.img` is clean (113 files), and `unsquashfs` extracts the whole rootfs. Rebuilt image sha256 `94568231…d377`.

**What the firmware is** (details in FIRMWARE_ANALYSIS.md): Buildroot 2018.02-rc3, glibc 2.29, armhf. `S50ui` starts the MiniGUI menu `/usr/bin/game`, which has 12 entries compiled in and calls `/data/start.sh <index> <smoothing> <speed>`. `start.sh` maps the index to one of 8 SDL2 emulator binaries in `/data/Games`. `.usb_config` enables ADB and `adbd` ships, but OTG is forced to host by the device tree: a lead for a root shell. Nothing in rootfs or data reads `sdfwupdate`.

**Recovery work** (RECOVERY.md):

* The spare layout from `reference/kernel-rkflash/sfc_nand.c`: W25N01GV meta words are at OOB `+0x04` and `+0x14`, and the bad-block marker is OOB bytes 0–1. `READ_SECTOR` returns only the two meta words. `rk_restore.py native` builds a 2048+64 image for an external programmer.
* Write framing from `reference/rkdeveloptool`: `ERASE_NORMAL 0x06` addresses blocks; `WRITE_SECTOR 0x05` addresses physical sectors, ≤ 32 per command, 528 bytes each (the same layout as `READ_SECTOR`).
* `tools/rk_restore.py`: `plan`, `native`, and `diff` (read-only), plus a locked `restore`. **`diff` against device 58: all 1024 blocks identical to the backup.** That's a third, independent read of the whole chip. `restore` has never been run.
* Block classification corrected along the way. Pairs like 18/19 hold "special" pages (odd LPA `0xFFFFFFFD`, even type `0x0000`, magic `0x12345678`), so they're not free blocks. Pair 90/91 is fully stale (verified from the rebuild map), so it's the first write target in the test ladder. Block 1023 has page 0 all-zero, so never write it.
* `tools/sftl_patch.py`: writes a modified logical image back over the current physical copies. Offline test: adding `Games/hello.sh` and editing one line of `start.sh` changed 6 LPAs in 6 blocks (828, 829, 872, 873, 892, 893). Rebuilding from the patched raw reproduced the modified image exactly, and `e2fsck` was clean.

Device 58 was left running `plug_3032slc`. Nothing was written to the cabinet in this session.

## Session 5, devices 59–66 (2026-10-23 13:00–15:10): writes work, and the probe is on tile 10

Current truth is STATUS.md "Pickup" and GAMEDEV.md § 2. This section is the trail.

* Stock `plug_3032slc` erase and write both return success and do nothing above block 8. The clips are in the RAM loader (`0xbec6` erase, `0xbf3c` write), not in the cabinet flash. `plug_3032slc_erase` nops `0xbee2`, `0xbef4`, `0xbf62`, and `0xbfee`. The last nop keeps the caller's spare metadata. Wire sha256 `53574f36…df91`.
* A 32-sector `WRITE_SECTOR` never returns a status packet because progress is `bytes >> 9` and 32 × 528 counts as 33. The earlier busy-poll theory was wrong. Nothing was programmed. Counts below 32 are safe. `rk_restore.py` refuses ≥ 32, writes one page, and compares 2048 data bytes plus the first 8 spare bytes.
* Device 64 restored all 64 pages of block 91. Then, with approval, it installed the probe on blocks 828, 829, 872, 873, 884, 885, 892, 893. Diff against the patched image: none. Dumps: `~/partycade-dumps/2026-10-23_probe_tile10/`.
* The user played Dig Dug II (now the probe). Screen was rotated 90° clockwise. Framebuffer is 1024×768 @ 60, KMSDRM, opengles2, ALSA. Device 66 read the chip back (`2026-10-23_probe_played`, sha256 `5d8f173c…a2ad`). The deck is the stick, 1-player, 2-player, three buttons on the right, and volume. The user then read the probe screen: 1-player is button 6, 2-player is button 7, and the three buttons to the right are 1 (top-left), 3 (top-right), and 0 (lower). That is the same set of five codes as the log. Select, start, and the other advertised codes are not on this deck. The power switch ended the session, so `probe.log` has no exit line.

Device 66 was left running `plug_3032slc_erase`, switch OFF. Do not restore the whole chip from the morning master.

## 2026-10-24: games overhaul, no hardware

No cabinet was attached and no USB command was sent. This session ran in a cloud container with no `~/partycade-dumps/` and no rootfs, so nothing here was built for, staged on, or written to the chip.

* Built the PC simulator with SDL 2.0.7 headers taken from the `release-2.0.7` tag (the tarball URL in the Dockerfile returned 404 and libsdl.org was not reachable). Orb ran on Mesa (llvmpipe) through `SDL_VIDEODRIVER=offscreen`.
* Added `games/common/gfx.{h,c}` (software 2D renderer) and `games/common/sfx.{h,c}` (synth and sequencer), plus to `cab.c` a quit-hold fraction for an on-screen meter and `cab_bot` for each game's built-in player.
* Rebuilt The Yard, Keep, Lamp, Orb, Tea, and Chest on them. Save names and formats did not change. Tea and Chest keep their specs' rules and lines.
* Replaced the frame-exact `play.sh` and `stress.sh` with `games/test.py` (49 checks, all pass) and rewrote `feel.py`.
* Every source compiles for armhf with `arm-linux-gnueabihf-gcc` and the cabinet's flags (`-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard -DCAB_CABINET`), object files only. The two warnings are `-Wcast-align` in old `cab.c` code. Not linked against the cabinet's libraries and not run under `qemu-arm`, because the rootfs was not here.
* Frame cost by callgrind on this PC, game work per frame excluding SDL's copy: Keep about 1 M instructions, Yard about 2.3, Lamp about 3.5, Chest about 3.4, Tea about 4. Expected to fit 16.7 ms on the 1.008 GHz Cortex-A7; not measured there.
* Audio by SDL's disk driver: every game produces sound with no silent stretch; Tea peaks at 2354 and Chest at the 3000 cap (`sfx_limit`), both quieter than the other games.

Conclusion: the new games are ready for a cabinet build and play test. The next flash needs a fresh dump, `build.sh cab`, `stage_game.py --bundle keep,lamp,orb,tea,chest`, and written approval for the printed blocks.

## 2026-10-24 (later): a way to play the games, and Tea and Chest version 2, no hardware

No cabinet, no USB command, nothing staged or written.

* `cab.c` gained a control mode (`CAB_CONTROL=1`: commands on stdin, one `ready` line per step on stdout), frame-locked audio capture to WAV (`CAB_AUDIO_WAV`, 735 samples a frame, no audio device opened), and a strict four-way stick (`CAB_FOURWAY=1`). None of them is on unless its variable is set; a cabinet launch from `start.sh` sets none.
* `games/playtest.py` drives that: sessions, macro presses, sheets of the panel picture with the deck drawn under each frame, sound onsets with note names, a callgrind frame-cost estimate.
* Playing Tea and Chest that way found the problems listed in each spec's "What changed in version 2." Both games were reworked and their specs rewritten. Zam is now drawn after Alakazam at the user's request; the README and the Chest spec say that likeness is not covered by the MIT license.
* `test.py`: 57 checks, all pass. Frame cost by `playtest.py perf`: Tea 5.1 M instructions of its own work a frame, Chest 3.9 M. Estimated 5 to 10 ms on the Cortex-A7; not measured there.


## 2026-10-24 (evening): the cart runtime and the deploy audit, no hardware

No cabinet, no USB command, nothing staged or written. Cloud container again: no `~/partycade-dumps/`, no rootfs. No plug was tried, so `rk.py` `STAGES` notes are unchanged.

* **Runtime.** `games/engine/runtime.c` and `api.c` embed Lua 5.4.7 (from the `v5.4.7` tag on GitHub; lua.org returned 403) in the existing renderer and synth.
  * The sandbox has no io, os, package, debug, load, dofile, or `string.dump`.
  * One allocator caps Lua plus pictures at 32 MB.
  * A count hook stops a callback after 150 M VM steps (400 M in `init`).
  * After `init()`, reading an unset global or making a new one is an error.
  * Additions to the engine: TrueType text with stb_truetype and Fredoka SemiBold (OFL; a static instance cut with fontTools), PNG with stb_image, a light map (`gfx_light.inc`, Lamp's darkness pass made general), and an iris wipe.
  * The menu launches each cart as `yard <id>` in a child process, so test scripts keep per-title sections and a cart crash can't take the menu with it.
* **Ports.** The menu, Keep, Lamp, Tea, and Chest are Lua carts in `games/carts/`. The C sources are deleted (git history keeps them).
  * With the same seed and the built-in player, Chest's log has the key at frame 24, the sword at 136, the win at 234, and the second key at 860 in both the C and the Lua build.
  * Callgrind over 1200 frames (x86 instructions per frame, whole process): Tea 7.1 M (C 6.3 M), Chest 5.8 (5.2), Lamp 4.8 (3.9), Keep 1.2 (1.0).
* **Tools.**
  * `games/cart` (new, list, run, check, shots, perf, pack, deploy) and three templates.
  * `test.py` has a new `system` pass. 78 checks, all pass.
  * `playtest.py` reads its title list from the runtime and profiles through it.
* **ARM.** The runtime cross-compiles with this container's `arm-linux-gnueabihf-gcc` to 419532 bytes, linked with unresolved SDL symbols only to measure size. That compiler is newer than the cabinet's glibc (GLIBC_2.38 symbols), so it is not a candidate binary. The Docker toolchain image did not build: `apt-get` to archive.debian.org failed in this sandbox. Not run under qemu.
* **Deploy audit.**
  * `data_patch.py` → `sftl_patch.py` → round trip → `diff` → approved `restore` is sound. Its one weak point is a new file on pages SFTL never wrote: `sftl_patch.py` refuses those, but only late.
  * `data_patch.py` gained `--overwrite SRC:DEST`, which writes a same-size file into the blocks it already owns.
  * The first version used debugfs `blocks`. On a test image that wrote file data over the indirect blocks, and e2fsck aborted. It now maps each logical block with `bmap`. The block map is unchanged, the content matches, and e2fsck is clean on ext2 with 1 KiB and 4 KiB blocks (in `test.py system`).
  * The cabinet layout becomes three fixed-size files: `yard` 2 MiB, `orb` 1 MiB, and `yard.pak` 4 MiB (crc32 per file; the carts use 120 KB). `games/cart deploy` stages either the first install (`--rm` the old C binaries, `--put` the three) or an in-place update (`--overwrite`), and writes `PLAN.md`.
  * `stage_game.py` is gone.

Conclusion: the cart build is ready for a cabinet build (`build.sh cab` with the rootfs), a qemu smoke test, and a `cart deploy --first` from a fresh dump. Approval is needed for whatever blocks that prints. Open: the frame time on the A7, and whether the first install lands entirely on pages SFTL has written.


## 2026-10-24 (night): the SD audit, a LÖVE build for the cabinet, and field tasks, no hardware

No cabinet, no USB command, nothing staged or written. Cloud container: no `~/partycade-dumps/`, no rootfs. No plug was tried, so `rk.py` `STAGES` notes are unchanged. No device numbers.

* **SD and USB audit (from `captures/device-tree.txt`, `captures/uboot-env.txt`, and the rootfs listing).**
  * The kernel's tree has the card slot at `dwmmc@10214000` (alias `sdmmc`, 4-bit, card detect on GPIO1 pin 17, `vmmc` on the always-on `vcc_io`), `disabled`.
  * U-Boot's embedded tree has only `dwmmc@1021c000`. Expected: `rkimgtest mmc 1` never sees the slot, so a card does not boot the machine, and the RUNBOOK's SD-boot options A and A2 are expected not to work. RUNBOOK § 7 and § 8 (now "Phase 4: the SD slot as storage, and an ADB shell"), GAMEDEV § 9 and § 11, FIRMWARE_ANALYSIS, and STATUS were corrected.
  * Storage plan: FAT at `/mnt/sdcard` is `noexec`; ext2 is exec; no ext4.
  * Wi-Fi on USB-A needs a built-in driver with cfg80211/mac80211, firmware (`/lib/firmware` is absent), and `wpa_supplicant` or `iw` (absent). `udhcpc`, `dropbear`, and `adbd` are present.
  * `tools/enable_storage.py` gained `--which adb`: `dr_mode` `host` → `otg` on `usb@10180000`, in place (tested on a synthetic tree: 20 bytes, same size). The default is now `sd` alone.
* **`tools/device_facts.py`** (new) turns a rootfs and a `boot.img` into committable text: library ABIs, the kernel config (IKCFG) and a driver list, the GL and SDL strings. Tested on a fake rootfs only.
* **LÖVE 11.5 for the cabinet** (`games/love/build.sh arm`).
  * `zig cc` 0.13.0 targeting `arm-linux-gnueabihf.2.28 -mcpu=cortex_a7`, with SDL 2.30.9 (KMSDRM, GLES2, ALSA loaded at run time), LuaJIT v2.1, OpenAL Soft 1.23.1, ogg, vorbis, theora 1.1.1, modplug, freetype 2.13.2, zlib 1.3.1. Headers for DRM, GBM, EGL, GLES, ALSA, and udev are vendored in `games/love/include/`.
  * Problems found and fixed: libtool linked `liblove` with `-nostdlib` and no libc++ (sed on libtool); LuaJIT on ARM left `__floatdidf` and three others undefined (`rtshim.c`) and wanted libgcc's unwinder (`LUAJIT_NO_UNWIND`); the x86 `luajit` binary needed `-lunwind`; zig `objcopy` in place empties files (strip to a new file); a game folder failed to mount under qemu (`std::length_error`), so games ship as `.love`.
  * `check_abi.py`: every ELF is ARM hard-float, glibc ≤ 2.29, GLIBCXX ≤ 3.4.22, and every needed library is in the bundle or in `captures/rootfs-listing.txt`. Result: the bundle will load. Expected, not verified.
  * `smoke.sh` under `qemu-arm -L /usr/arm-linux-gnueabihf` (Ubuntu's libraries, not the cabinet's): LÖVE 11.5.0, LuaJIT arm, C++ exceptions come back as Lua errors, images, PNG, sound data, freetype, zlib: `smoke ok`. 3M `math.sin` in 2000 ms under qemu.
  * Bundle 8.9 MB; as `love.tar.gz` with the probe and `yard.love`, 4.1 MB.
* **The GPU runtime** (`games/love/yard/`): the cart API on `love.graphics` at 768×1024, the synth rendered into cached buffers, the deck with SDL 2.0.7's button numbers (overridable by `/data/Games/yard-deck.txt`), the same sandbox and pack reader. With the same seed and bot, Chest, Keep, Lamp, and Tea write identical log lines (105, 8, 21, 60 over 1200 frames) and identical saves on both runtimes. Carts now use `idiv`, `atan2`, and `unpack` so they parse as Lua 5.1; `cart check` lints for it and parses with LuaJIT.
* **The probe** (`games/love/probe/`) ran headless on x86 with Mesa llvmpipe; its cabinet numbers are FIELD_TASKS.md task 5.
* **A test bug.** `cart check yard` timed out at 5 minutes in its random-mash pass, also on the previous commit: a cart the menu launched was a separate process with no frame limit. The checker now sets `CAB_MAX_FRAMES` as well. No engine change.
* `test.py`: 90 checks, all pass (12 new in `love`). `cart check`: all carts pass.

Conclusion: everything that can be done without the cabinet is done. The next facts come from [FIELD_TASKS.md](FIELD_TASKS.md): the device facts, a cabinet build with `check_binary.sh`, a qemu run against the real rootfs, one staged deploy that needs written approval of its blocks, a play test, and the probe's report.

### Addendum, same night: what the field tasks must settle about SD, USB-A, Wi-Fi, and ADB

Still no hardware. The first FIELD_TASKS.md left the SD/USB question to a one-line task 7, so it would not have settled them. Added:

* From `captures/device-tree.txt`: USB-A's power switch is probably `usb_en`, a fixed regulator on a GPIO (declared 3.3 V; the GPIO likely enables a 5 V switch) with `regulator-always-on`, so VBUS is expected to be present once `usb@101c0000` is enabled. The SD node has `broken-cd`: the card is found by polling (every `card-detect-delay` 200 ms), not by an interrupt on the detect pin. Expected, unverified.
* `tools/device_facts.py` also writes `captures/kernel/bootimg.txt` (boot image header, gzip streams, device tree offsets) and `captures/system/` (init scripts, udev rules, network and dropbear settings, busybox applets, password state without hashes), and searches for flash and USB-gadget driver names. Tested on a fake rootfs and boot image.
* `games/sysprobe/sysprobe.sh` and a "System probe" menu row (`cart deploy --with-sysprobe`): a read-only script that records the live device tree's status for the slot and ports, `/proc/partitions`, `/proc/mtd`, block devices and the sha256 of each small partition as Linux reads it, USB and MMC devices, regulators, UDC, network and firmware, which tools exist, processes, `dmesg`, and `/proc/config.gz` if present. Then it watches for 90 s and logs what appears while someone plugs things in. Dry-run under dash on this container.
* The Yard's menu scrolls past five rows (eight with the three test rows). With five games nothing moves. New checks in `test.py system`; 93 checks pass.
* FIELD_TASKS.md now has a table of the questions and the task that answers each, the System probe in tasks 4–6 as a "before" picture, and task 7 as concrete steps: the `boot` write with `sd,usb,adb`, a boot check, a card prepared with FAT32 and ext2 partitions, "after" probes with a card, a stick, and a Wi-Fi adapter, and ADB read-only checks including card read and write speed.

### Addendum: the cart runtime keeps a log on the cabinet

The C cart runtime only wrote to stderr, which the stock launcher discards, so a play test of it would have left nothing to read back, not even frame times. Engine change (`runtime.c`, `cab.c`; no cart API, so no `api.c` binding): on the cabinet build it appends to `/data/Games/yard.log` (`YARD_LOG` elsewhere), moves a log over 256 KB to `yard.log.1`, flushes each line, turns `YARD_STATS` on, and at each start logs free memory, the cart, the video driver and display mode, the renderer, each joystick's name and button/axis/hat counts, and the audio driver. Tested on the PC under `YARD_LOG`; two new checks in `test.py system` (95 pass). FIELD_TASKS.md task 6 reads `yard.log` back, and a table there lists every file the tests leave behind.

### Addendum: the card's format (SDCARD.md)

No hardware. SDCARD.md sets the card format from what is known: the first 16 MiB zeroed (so U-Boot's `rkimgtest` never finds a Rockchip signature at sector 64), MBR with one partition at 1 MiB, ext2 labelled `YARD` (the stock udev rule mounts ext2 with exec and FAT with `fmask=133`; no ext4 in the kernel), SDHC 4–32 GB, and carts in `yard/carts/<id>/` (from `scan_carts`). One partition because the udev rule mounts every card partition on `/mnt/sdcard`, so two would hide each other (untested). Two new PC checks: a card cart is listed, and a card cart cannot take a shipped cart's id (97 pass). FIELD_TASKS.md 7f makes the real card and looks for a card cart in the menu.

## 2026-10-24 (evening, on the cabinet PC): FIELD_TASKS.md Tasks 1–6 and microSD formatting

Hardware attached on port `1-6`. Devices 75/76 (`plug_3032slc_erase` for Task 4 dump + 52-block write) and 80/81 (`plug_3032slc_erase` for Task 6 post-play dump).

* **Task 1 (`aad955e`):** Ran `tools/device_facts.py` on `~/partycade-dumps/2026-10-23_raw_plug3032slc/rootfs` and `boot.img` into `captures/`. Confirmed `CONFIG_MMC_DW=y`, `CONFIG_USB_DWC2=y`, `CONFIG_USB_STORAGE=y`, `CONFIG_EXT2_FS=y`, `CONFIG_VFAT_FS=y`, `CONFIG_EXFAT_FS=y`, `CONFIG_NTFS_FS=y`, USB Ethernet drivers (`r8152`, `asix`, `ax88179_178a`, `cdc_ether`, `rndis_host`), and no `CONFIG_WLAN`, `CONFIG_CFG80211`, or `CONFIG_EXT4_FS`.
* **Task 2 (`2439035`):** Installed `ziglang==0.13.0` (`~/.local/bin/zig`) and ran `games/love/build.sh arm`. Found that `smoke.sh` against the real cabinet `rootfs` failed at `[love "boot.lua"]:48: Failed to initialize filesystem: no error` (`__xstat(0, ...)` returning `EINVAL` because Zig's bundled glibc headers lack ARM's `_STAT_VER = 3`). Fixed by adding `-D_FILE_OFFSET_BITS=64` (`__xstat64` ignores `ver`) in `games/love/build.sh`. `check_abi.py`, `smoke.sh` (against the real dump rootfs), and `test.py love` (12/12) all passed.
* **Task 3 (`b0703dc`):** Built `partycade-armhf` Docker image and ran `games/build.sh cab`, `./cart pack`, `qemu-arm-static` smoke test (`ok: 300 frames`), `./cart check` (`all carts pass`), and `./stress.sh` (`97 passed, 0 failed`). Fixed a timestamp race in `games/build.sh` where `make TARGET=cab` inside Docker tried to run `python3 tools/bin2c.py`.
* **Task 4 (`10df7c2`, devices 75 → 76):**
  * Booted `plug_3032slc_erase` on Mask ROM device 75 (loader device 76).
  * `tools/rk.py rawdump -o ~/partycade-dumps/2026-10-24_love/nand_raw.bin --verify` (sha256 `48a4fc08767bf686018dc41050f24b0184da0b9cb5150137919339f35b23d524`); `diff` reported `none`.
  * Added `--repair` pass-through to `games/cart deploy` (`e2fsck -fy` cleaned `Unattached inode 126` from the prior power-cut play session). Staged `--first --with-love-probe --with-sysprobe --repair` into `~/partycade-dumps/2026-10-24_love/stage/nand_raw_patched.bin` (sha256 `c4a413d46358ed89f097f48e0a90ff7114a46998c4703d0315f7107dbe014e40`), touching 52 blocks (`18,19,90,91,334..361,364..373,850,851,856,857,866,867,878,879,884,885`).
  * Restored all 52 blocks with user approval and confirmed full-chip `diff` = `none`.
* **microSD card prepared (`SDCARD.md`):** Formatted `/dev/sdd` (29.7 GB USB reader) using `partycade-armhf` Docker container: zeroed first 16 MiB, MBR partition 1 at sector 2048, `mke2fs -t ext2 -b 4096 -I 128 -O ^ext_attr,^dir_index -L YARD`, verified `Filesystem features` (`ext_attr resize_inode dir_index filetype sparse_super large_file`), populated `/label` (`yard`) and `/yard/carts/cardkeep`, and verified with `e2fsck -fn`.
* **Tasks 5 & 6 (devices 80 → 81):**
  * User playtested The Yard (`Keep`, `Lamp`, `Orb`, `Tea`, `Chest`), `LOVE probe`, `GPU yard`, and `System probe` (twice: once with TP-Link AC600 USB dongle, once with both microSD card and TP-Link AC600).
  * Cold-plugged to Mask ROM device 80, booted `plug_3032slc_erase` (loader device 81), dumped `~/partycade-dumps/2026-10-24_love_played/nand_raw.bin` (sha256 `7a54af20e13f5305631bfc949dff0674248641f76daa484bb536056710f93adf`), rebuilt `logical.img` (`400befe3…`), and extracted `captures/love/` and `captures/sysprobe/`.
  * **Conclusions from the extracted logs:**
    1. **Cortex-A7 frame times (`captures/love/yard.log`):** Keep `2.15–2.74 ms`, The Yard `7.49–8.01 ms`, Lamp `8.14–9.34 ms`, Chest `9.88–16.49 ms`, Tea `14.06–18.42 ms` (`peak 1459 ms` during initial stamp baking).
    2. **6.0 MiB/launch DRM `shmem` leak & OOM kill of `/usr/bin/game`:** `/usr/bin/game` holds `53.2 MB` anon-rss + `8.6 MB` file-rss (`37.4 MB` of `118.7 MB` free when `yard` starts). Each time the `yard` menu calls `cab_shutdown()` + `gfx_init()` in the same process, `libMali.so`/`libgbm.so` leaks two `1024×768×4` DRM GEM dumb buffers (`6,144 KiB` of `shmem`). After several launches `shmem` reached `43.2 MB`, causing `SDL_OpenAudio: Couldn't create audio thread` in Tea and triggering the Linux OOM killer (`captures/sysprobe/before-1.txt`), which killed `/usr/bin/game` (PID 439) and left exiting stuck on `"LOADING..."`.
    3. **LÖVE `kmsdrm not available` + 1970 clock re-unpack:** `captures/love/love-probe.log` shows `Error: Could not initialize SDL video subsystem (kmsdrm not available)` because SDL 2.30's CMake `CheckKMSDRM` check (`pkg_search_module` for `libdrm` and `gbm`) failed without `.pc` files and left `SDL_VIDEO_DRIVER_KMSDRM` undefined in `SDL_config.h`. Also, `[ love.tar.gz -nt /data/love/.stamp ]` was always true (2026 archive mtime > 1970 cabinet clock), re-unpacking `love.tar.gz` (~10 s) on every click.
    4. **Orb left/right viewport clipping:** `cab_gl_present()` in `games/engine/cab_gl.c` set `dw = cab_w * s` (`768`) and `dh = cab_h * s` (`1024`) without swapping axes for the 90°-rotated `1024×768` framebuffer (`dst.y = -128..896`).
    5. **USB-A (`usb@10180000`) is already live in host mode on the stock cabinet:** `captures/sysprobe/before-1.txt` and `before-2.txt` show the user's TP-Link AC600 (`idVendor=2357, idProduct=011e`, Realtek 802.11ac) enumerating immediately on `usb1` (`10180000.usb`, `dwc2`) when plugged into USB-A.
    6. **Partition checksums (`rkflash0p1..4`):** Exact byte-for-byte match between Linux `/dev/rkflash0p1..4` and `sftl_rebuild.py`, with `ro = 0` on all partitions.

