# Status: what is known, as of 2026-10-23 12:50

This is the single source of truth for the current state. If another doc disagrees with this one, this one wins. Update it at the end of every session.

## Headline

* **The whole flash is backed up and verified.** `rk.py rawdump` read all 1024 physical NAND blocks (data plus spare). Two passes matched, and a live `rk_restore.py diff` found the cabinet still identical. `tools/sftl_rebuild.py` turns that raw image into the logical disk offline. Every partition is extracted; rootfs and data both pass their filesystem checks.
* **The game list is understood.** The menu program `/usr/bin/game` (rootfs, MiniGUI) has 12 entries compiled in. For a pick it runs `/data/start.sh <index> <smoothing> <speed>`, and that shell script maps the index to an emulator binary in `/data/Games/`. Details are in [FIRMWARE_ANALYSIS.md](FIRMWARE_ANALYSIS.md).
* **A recovery plan exists:** [RECOVERY.md](RECOVERY.md). **USB raw restore (path A) does not work with `plug_3032slc`:** its erase command reports success but erases nothing above block 8 (test ladder 2026-10-23, confirmed by disassembly; RECOVERY.md path A). The flash content is unchanged (full `diff`: none).
* No byte of the cabinet's flash has changed. Erase/program commands were sent for blocks 8 and 91 only; both were no-ops.
* **Custom games:** toolchain and probe are built (`games/`, GAMEDEV.md section 6). A UART adapter is not required. The SD slot and a USB stick are not consulted by stock U-Boot or Linux (kernel MMC nodes are `disabled`; U-Boot has no `sdmmc` node; udev mounts only `mmcblk` and nothing runs from a USB disk). The next test, still needing approval, is a patched `plug_3032slc` whose erase is not limited to blocks 0–8, tried on stale block 91 only (RECOVERY.md path A).

## Hardware state right now

At the end of the 2026-10-23 session, device 58 (`plug_3032slc` loader) was still on the bus at port `1-6`. Any new plug needs a cold plug first. To play the cabinet normally: unplug both, switch **ON**, power on.

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
| Controls | `uart-keys` driver: joystick → `KEY_UP/DOWN/LEFT/RIGHT`, buttons → `BTN_*` (`0x130`–`0x13e`), volume keys | Device tree |
| Serial console | Kernel console is `ttyS2`, but uart2 is `status = "disabled"` | Device tree |
| `sdfwupdate` | Nothing in rootfs or data mentions `sdfwupdate`, `fwupdate`, or `update.img`. The SD-update risk lives only in U-Boot's `rkimgtest` | grep, 2026-10-23 |

## Plug results on this board

| Plug (`rk.py` name) | File | Result |
| :--- | :--- | :--- |
| `plug_std` | `rk303x_usbplug_v2.57.bin` | Runs. Flash ID `EMMC`, size 0. Not useful. |
| `plug_slc` | `rk303x_usbplug_slc_v2.65.bin` | Runs, then the chip resets to Mask ROM. |
| `plug_slc264` | `rk303x_usbplug_slc_v2.64.bin` | Same as `plug_slc`. |
| `plug_3032` | `rk3032_usbplug_v2.61.bin` | Works. `READ_LBA` serves only LBA < `0x10000`; starting at ≥ `0x10000` returns `0xCC`. |
| `plug_3032slc` | `rk3032_usbplug_slc_v2.63.bin` | Works. Same `READ_LBA` 32 MiB limit, but **`READ_SECTOR` (raw physical) reads the whole chip**. Used for the master backup. **Use this one.** |

## Backups

All outside the repo in `~/partycade-dumps/`. Its `README.txt` says what each file is. The full table with hashes is in [RECOVERY.md](RECOVERY.md) § 2.

* **Master:** `2026-10-23_raw_plug3032slc/nand_raw.bin`, sha256 `024af9ed…429e`. Plus `logical_rebuilt.img` (`94568231…d377`), the five partition images, `nand_native_2112.bin` for an external programmer, `rootfs/`, `data_fs/`, and `SHA256SUMS`.
* Older: `2026-10-23_plug3032/full_lba0_220672.img`, where only the first 32 MiB are real. It's kept as the independent cross-check for `sftl_rebuild.py`.
* **User action pending:** copy `~/partycade-dumps/` somewhere off this PC.

## Open questions, in priority order

1. **Custom games (the user's goal: original games as entries 13+, on the stock board).** The plan is in [GAMEDEV.md](GAMEDEV.md): toolchain → recovery test ladder → probe program behind one tile → own launcher. How the control deck's buttons map to SDL joystick numbers is still to be probed on the cabinet.
2. Does the restore write path work on this plug? It's the [RECOVERY.md](RECOVERY.md) test ladder, T1 → T3, each rung approved by the user.
3. **ADB lead:** does the stock system give a root ADB shell if OTG is switched to peripheral in the device tree? The cheapest test is an SD card whose `boot` carries the stock kernel plus that one DTB change, with the rootfs still from NAND. That needs question 4 answered. Also unknown: whether the back switch moves the Micro-USB port between the SoC's OTG and something else.
4. Can the stock U-Boot see the microSD slot? Its device tree has only `dwmmc@1021c000`, and stock Linux disables every MMC controller. That decides the SD card path.
5. What are the SFTL "special" pages (odd-half LPA `0xFFFFFFFD`, even-half magic `0x12345678`, about 6 per pair)? They don't affect restore, which copies them verbatim, but they matter for any future synthesis of SFTL state.
6. What is `PCBA_TEST`, and what sets `uart-keys/test_mode`? It's a factory test mode, possibly reachable with a button combination at power-on.
