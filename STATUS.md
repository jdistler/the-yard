# Status: what is known, as of 2026-10-23 15:40

This is the single source of truth for the current state. If another doc disagrees with this one, this one wins. Update it at the end of every session.

## Pickup

Read this before the history below. Game development on the PC can start. The cabinet already runs our probe in place of Dig Dug II.

* **Next work** is a game in `games/` on the platform layer `games/common/cab`, built with `games/build.sh` and played on the PC. Flashing it needs a fresh `rawdump` in that session and the user's written approval for the exact block list. Plan and rules: [GAMEDEV.md](GAMEDEV.md). The one open input fact is which of joystick buttons 0, 1, 3, 6, and 7 (codes A, B, X, L, R) is 1-player, 2-player, and each of the three buttons to the right of the stick.
* **Cabinet right now:** switch OFF, Micro-USB plugged, port `1-6`, device 66, loader `plug_3032slc_erase` (wire sha256 `53574f36b7637f55701f6a0e9aae7aec991fc3c2d326e9e9899956cd4ee8df91`). This enumeration has already been used. A timeout means a cold plug, not a retry. Do not write unless the user approves the blocks.
* **On the chip, past the morning master:** block 91 matches the morning backup again. Tile 10 (`start.sh` case `10`) runs `/data/Games/probe` instead of Dig Dug II (`Mappy d`). Those pages are blocks 828, 829, 872, 873, 884, 885, 892, 893. Undo is a restore of those blocks from `~/partycade-dumps/2026-10-23_probe_tile10/nand_raw.bin` (sha256 `acfebb7a75a3edf97ea3a09a0bb650544ab17b28ad45569ad73cca70ec1e143d`). The image that was written is `nand_raw_patched.bin` in that directory (sha256 `e92541b756690bb6a37d216379e3f107830c72043e9c6d53e3e9702d321912f9`), and a diff against it was none.
* **Newest full read** is `~/partycade-dumps/2026-10-23_probe_played/nand_raw.bin` (sha256 `5d8f173cf63b1e8a7427d6c6761b54ddeebe3462cc3ad35c14438c10592aa2ad`, device 66). It contains `/data/Games/probe.log`. Do not restore the whole chip from the morning master `2026-10-23_raw_plug3032slc/nand_raw.bin` (sha256 `024af9edbf48df38c10039ca09dc2371b97b9e17410daa17020f9e08a30c429e`). That would remove the probe and later `data` writes. Blocks 972 and 973 are SFTL sys pages from normal boots. Leave them.
* **Writes** use `plug_3032slc_erase`, one 4-sector page per command, count under 32. The 32-sector hang is `bytes >> 9` counting 528-byte sectors as 33, not a NAND busy poll. Compare 2048 data bytes plus the first 8 spare bytes of sector 0. The write function returns 0 even when the page did not program, so only a read-back counts. Never write block 1023. Reads of a stock chip can use `plug_3032slc`. Copy `~/partycade-dumps/` off this PC. That is still the user's job.

## Headline

* **The whole flash is backed up and verified.** `rk.py rawdump` read all 1024 physical NAND blocks (data plus spare). Two passes matched, and a live `rk_restore.py diff` found the cabinet still identical. `tools/sftl_rebuild.py` turns that raw image into the logical disk offline. Every partition is extracted; rootfs and data both pass their filesystem checks.
* **The game list is understood.** The menu program `/usr/bin/game` (rootfs, MiniGUI) has 12 entries compiled in. For a pick it runs `/data/start.sh <index> <smoothing> <speed>`, and that shell script maps the index to an emulator binary in `/data/Games/`. Details are in [FIRMWARE_ANALYSIS.md](FIRMWARE_ANALYSIS.md).
* **A recovery plan exists:** [RECOVERY.md](RECOVERY.md). `plug_3032slc_erase` erases and programs past block 8, one 4-sector page at a time. Block 91 was restored and matches the backup.
* **Block 91 was erased at 13:02, then fully restored at 14:30.** It is the stale half of pair 90/91. A full diff against the morning backup lists only the SFTL-sys pages in blocks 972 and 973. Those were left alone.
* **Read-back on device 62 (2026-10-23, patched loader, cold plug).** Comparing data plus the 8-byte Rockchip spare, the only blocks that differ from the backup are 91, 972, and 973. Block 91's data and spare metadata are 0xFF on every page, so the program command did not commit a page. The other spare bytes (sector 0 bytes 8–15, and all 16 spare bytes of the other three sectors) read back as one fixed pattern on every page of every block, including blocks that were never written. The backup has 0xFF there. That pattern is not stored flash content. `diff` and the restore verify ignore it.
* **Block 91 is restored.** Device 64, same loader as the page-0 test. All 64 pages were erased, programmed, and read back against the backup. A following diff does not list block 91.
* **Both failures are now explained from the stock plug, and the busy-poll story was wrong.** The write hook ops+0x14 is `0xbf3c`. At `0xbf62` it returns success for any sector ≥ 2048 and programs nothing. It also stores `0xff` over spare word 0 at `0xbfee`, so removing only the clip would program the wrong metadata. The 32-sector hang is `0xeef4`: progress is `bytes >> 9`, and 32 × 528 bytes counts as 33 sectors, so the status packet is never sent. Counts below 32 are exact. `plug_3032slc_erase` nops `0xbf62` and `0xbfee` as well as the erase clip. Wire sha256 `53574f36b7637f55701f6a0e9aae7aec991fc3c2d326e9e9899956cd4ee8df91`. Device 64 and, later, device 66 both ran that wire. `rk_restore.py` refuses a `WRITE_SECTOR` count of 32 or more.
* **The controls probe is on tile 10, and it has been played.** Install dump `~/partycade-dumps/2026-10-23_probe_tile10/nand_raw.bin` (sha256 `acfebb7a…143d`). After the play test, `~/partycade-dumps/2026-10-23_probe_played/nand_raw.bin` (sha256 `5d8f173c…a2ad`, device 66) has `/data/Games/probe.log`. The map is in [GAMEDEV.md](GAMEDEV.md) § 2. The log ends at 25.3 s with no exit line. The picture was 90° clockwise on a 1024×768 framebuffer.

## Hardware state right now

Device 66 is `plug_3032slc_erase` on port `1-6`, switch OFF. The probe log has been read. Playing wrote new `data` pages, so this chip no longer matches the pre-play image. Leave the loader attached until the next cold plug. Undo of the probe itself is still a restore of blocks 828, 829, 872, 873, 884, 885, 892, 893 from `2026-10-23_probe_tile10/nand_raw.bin`.

> [!NOTE]
> Playing the cabinet normally writes to `data` (high scores, settings). After that, the raw backup no longer matches the chip exactly: `rk_restore.py diff` will report some `data` blocks, and restoring them would roll back high scores. That is expected. Take a fresh `rawdump` before any planned flash change.

## Verified facts

| Fact | Value | Evidence |
| :--- | :--- | :--- |
| Mask ROM entry | Switch **OFF** + cold plug (both plugs out first) | Every session; [INTERFACING_AND_MODES.md](INTERFACING_AND_MODES.md) |
| Mask ROM USB | `2207:301a`, high-speed, no strings, `bcdDevice 1.00`, iface `FF/06/05`, bulk `0x81`/`0x02` | lsusb on devices 38–58 |
| Download protocol | Vendor control `0x40`/`0x0C`, index `0x471` then `0x472`, RC4 (Rockchip key) + CRC-16/CCITT, 4096-byte chunks | Devices 51, 53–58 |
| DDR init | `rk3036_ddr_396MHz_v1.11.bin` works (Rockchip uses it for RK3032 too) | Every boot since device 51 |
| SoC | RK3032 | Plug chip info `3032`; device tree `rockchip,rk3032-dongle` |
| RAM | 128 MiB at `0x60000000` | Device tree |
| Flash | SPI NAND Winbond W25N01GV, ID `EF AA 21`: 1024 blocks × 64 pages × (2048 + 64 OOB) | READ_FLASH_ID, FLASH_INFO (256-sector blocks, 4-sector pages) |
| Logical disk | 220672 sectors (107.75 MiB) served by Rockchip SFTL 5.0.55 | READ_FLASH_INFO; rebuilt offline |
| SFTL physical layout | A 4 KiB logical page = page *n* of even block 2k + page *n* of block 2k+1. Odd half's spare: u32 LPA. Even half's spare: u16 type (`0xF095` = data), u16 pair index, u32 **write sequence** (newest copy wins) | `sftl_rebuild.py` output equals `READ_LBA` data on all 65536 comparable sectors; e2fsck clean |
| Partition table | GPT: `IDBlock` 0x40+0x380, `uboot` 0x400+0x400, `boot` 0x800+0x2400, `rootfs` 0x2c00+0x20000 (64 MiB), `data` 0x22c00+0xf000 (30 MiB) | [captures/partitions.json](captures/partitions.json) |
| Factory boot block | DDR init `V1.09 20171120`, Boot1 built Dec 23 2020, SFTL 5.0.55 | Strings in `IDBlock` |
| U-Boot | `U-Boot 2017.09-g97b7efa-dirty (May 11 2023)`, `board=evb_rk3036`, `bootdelay=0`; checks the **SD card first** (`rkimgtest mmc 1`) | [captures/uboot-env.txt](captures/uboot-env.txt) |
| Kernel | Linux 4.4.194, May 11 2023, cmdline `console=ttyS2,115200 rw root=PARTUUID=614e0000-0000 rootfstype=squashfs rootwait` | `boot` partition, device tree |
| Rootfs | SquashFS 4.0, 1998 inodes, Buildroot 2018.02-rc3, glibc 2.29, ARM EABI5 **hard-float** (`/lib/ld-linux-armhf.so.3`), BusyBox init | [captures/rootfs-listing.txt](captures/rootfs-listing.txt) |
| Graphics/audio libs | SDL2 2.0.7, SDL2_image, SDL2_mixer, MiniGUI 3.2 (`libminigui_ths`), libdrm + Rockchip DRM, Mali (`libmali`, GLES1/2, EGL), ALSA | `rootfs/usr/lib` |
| Boot to menu | `inittab` → `rcS` → `S50ui`. If `/sys/devices/platform/uart-keys/test_mode` is 1 it runs `PCBA_TEST` (factory test); otherwise it runs `/usr/bin/game` | [captures/stock-scripts/](captures/stock-scripts/) |
| Menu | `/usr/bin/game`: 12 entries compiled in, artwork `/usr/local/share/minigui/res/images/game_N.jpg`, `gameN_controls.jpg`, `gameN_settings.jpg`, settings in `/userdata/Games/*.cfg` | `strings` |
| Launch | `system("/data/start.sh %d %d %d")` = index, pixel smoothing (`SDL_RENDER_SCALE_QUALITY`), speed (`1` → `-fast`); `start.sh` runs `cd /data/Games && ./<binary> [variant] [-fast]` | [captures/stock-scripts/data_start.sh](captures/stock-scripts/data_start.sh) |
| `data` partition | ext2, 30 MiB, 113 files, 5.7 MB used, ~24 MB free. Mounted at `/data`, and `/userdata` is a symlink to it. Holds `start.sh`, `Games/` (8 emulator binaries, ROMs, `.cfg`, `.sav`, `.wav`, thumbnails), `parameter`, `spk_volume` | [captures/data-partition-listing.txt](captures/data-partition-listing.txt) |
| Emulators | One SDL2 binary per hardware family: `PacMan`, `SuperPacMan`, `PacLand`, `NS1`, `Galaga`, `Galaxian`, `Mappy`, `DigDug`. Variants are selected by an argument (`p`, `d`, `r`) | `start.sh`, `readelf` |
| Network/SSH | `S40network` and `S50dropbear` exist, but the RK3036 EMAC node is `status = "disabled"` and there is no Wi-Fi node | init.d, device tree |
| USB OTG in Linux | `usb@10180000` (OTG, dwc2) is `okay` with `dr_mode = "host"`; the second controller `usb@101c0000` is disabled | Device tree |
| **ADB is configured** | `/etc/init.d/.usb_config` contains `usb_adb_en`, `/usr/bin/adbd` exists, and `S50usbdevice` starts adbd and binds the first UDC. No UDC exists because OTG is forced to host. **A device tree with `dr_mode = "peripheral"` (or `"otg"`) should give a root ADB shell over the Micro-USB port.** Untested lead | rootfs, device tree |
| Controls | Deck is a 4-way stick, 1-player (left, top), 2-player (left, bottom), three buttons to the right, volume +/−, and a power switch that is not a key. SDL sees one `uart-keys` joystick, 0 axes, buttons A/B/X/L/R plus the directions and volume. Label-to-code pairing is still open. See [GAMEDEV.md](GAMEDEV.md) § 2 | Probe log plus the user, 2026-10-23 |
| Screen mode | KMSDRM, opengles2, 1024×768 @ 60. The probe's landscape picture was rotated 90° clockwise on the panel. The panel label is BOE `DV170YGZ-N10`, 1280×1024 | Probe log; user; cabinet label |
| Serial console | Kernel console is `ttyS2`, but uart2 is `status = "disabled"` | Device tree |
| `sdfwupdate` | Nothing in rootfs or data mentions `sdfwupdate`, `fwupdate`, or `update.img`. The SD-update risk lives only in U-Boot's `rkimgtest` | grep, 2026-10-23 |

## Plug results on this board

| Plug (`rk.py` name) | File | Result |
| :--- | :--- | :--- |
| `plug_std` | `rk303x_usbplug_v2.57.bin` | Runs. Flash ID `EMMC`, size 0. Not useful. |
| `plug_slc` | `rk303x_usbplug_slc_v2.65.bin` | Runs, then the chip resets to Mask ROM. |
| `plug_slc264` | `rk303x_usbplug_slc_v2.64.bin` | Same as `plug_slc`. |
| `plug_3032` | `rk3032_usbplug_v2.61.bin` | Works. `READ_LBA` serves only LBA < `0x10000`; starting at ≥ `0x10000` returns `0xCC`. |
| `plug_3032slc` | `rk3032_usbplug_slc_v2.63.bin` | Works. Same `READ_LBA` 32 MiB limit, but **`READ_SECTOR` (raw physical) reads the whole chip**. Used for the master backup. **Use this one for reads.** It cannot erase or program past block 8. |
| `plug_3032slc_erase` | same file, four patches in RAM | The write loader. Nops the erase clip, the write clip, and the spare-word store. Wire sha256 `53574f36…df91`. **Use this one for restore.** |

## Backups

All outside the repo in `~/partycade-dumps/`. Its `README.txt` says what each file is. The full table with hashes is in [RECOVERY.md](RECOVERY.md) § 2.

* **Master:** `2026-10-23_raw_plug3032slc/nand_raw.bin`, sha256 `024af9ed…429e`. Plus `logical_rebuilt.img` (`94568231…d377`), the five partition images, `nand_native_2112.bin` for an external programmer, `rootfs/`, `data_fs/`, and `SHA256SUMS`.
* Older: `2026-10-23_plug3032/full_lba0_220672.img`, where only the first 32 MiB are real. It's kept as the independent cross-check for `sftl_rebuild.py`.
* **Probe install:** `2026-10-23_probe_tile10/nand_raw.bin` (sha256 `acfebb7a…143d`) is the chip just before the probe. `nand_raw_patched.bin` (sha256 `e92541b7…12f9`) is what was written. `BLOCKS.txt` lists 828, 829, 872, 873, 884, 885, 892, 893.
* **After the play test:** `2026-10-23_probe_played/nand_raw.bin` (sha256 `5d8f173c…a2ad`) plus `probe.log`. This is the newest picture of the chip.
* **User action pending:** copy `~/partycade-dumps/` somewhere off this PC.

## Open questions, in priority order

1. **Custom games (the user's goal: original games as entries 13+, on the stock board).** The probe is installed. The deck is a 4-way stick, 1-player and 2-player buttons to its left, three buttons to its right, and volume. Those five buttons are joystick codes A, B, X, L, and R; which label is which code is still open. The other advertised codes are not on this deck. The framebuffer is 1024×768 and the probe's picture was rotated 90° clockwise. See [GAMEDEV.md](GAMEDEV.md) § 2.
2. Block 91 round-trips, and the probe's eight `data` blocks were programmed and read back. Path A works. See [RECOVERY.md](RECOVERY.md).
3. **ADB lead:** does the stock system give a root ADB shell if OTG is switched to peripheral in the device tree? The cheapest test is an SD card whose `boot` carries the stock kernel plus that one DTB change, with the rootfs still from NAND. That needs question 4 answered. Also unknown: whether the back switch moves the Micro-USB port between the SoC's OTG and something else.
4. Can the stock U-Boot see the microSD slot? Its device tree has only `dwmmc@1021c000`, and stock Linux disables every MMC controller. That decides the SD card path.
5. What are the SFTL "special" pages (odd-half LPA `0xFFFFFFFD`, even-half magic `0x12345678`, about 6 per pair)? They don't affect restore, which copies them verbatim, but they matter for any future synthesis of SFTL state.
6. What is `PCBA_TEST`, and what sets `uart-keys/test_mode`? It's a factory test mode, possibly reachable with a button combination at power-on.
