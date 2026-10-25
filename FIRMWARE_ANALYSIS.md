# Firmware Analysis

What the cabinet's flash contains, from the complete backup in `~/partycade-dumps/2026-10-23_raw_plug3032slc/` (see [RECOVERY.md](RECOVERY.md) § 2). Everything here was read from that backup. Nothing on the cabinet was changed.

## Flash layout

GPT on a 220672-sector logical disk (Rockchip SFTL on a Winbond W25N01GV SPI NAND). From [captures/partitions.json](captures/partitions.json):

| Partition | First LBA | Sectors | Size | Contents |
| :--- | :--- | :--- | :--- | :--- |
| (MBR + GPT) | 0 | 64 | 32 KiB | Protective MBR, GPT header at LBA 1 |
| `IDBlock` | `0x40` | `0x380` | 448 KiB | Rockchip boot block: DDR init + Boot1 miniloader, two copies |
| `uboot` | `0x400` | `0x400` | 512 KiB | Rockchip `LOADER` image with U-Boot 2017.09 |
| `boot` | `0x800` | `0x2400` | 4.5 MiB | Android boot image v0: zImage + Rockchip resource (DTB, logo) |
| `rootfs` | `0x2c00` | `0x20000` | 64 MiB | SquashFS 4.0, zlib, 58,961,801 bytes used. Mounted at `/` |
| `data` | `0x22c00` | `0xf000` | 30 MiB | ext2, label-less, 113 files. Mounted at `/data`; `/userdata` → `/data` |

GPT last usable LBA is `0x31bff`. Sectors past that up to 220671 are SFTL capacity outside any partition.

## SFTL physical layout (how the logical disk is stored on the NAND)

Reverse-engineered on 2026-10-23 and implemented in `tools/sftl_rebuild.py`. It was validated three ways: identical to `READ_LBA` data on all 65536 sectors that `READ_LBA` serves, `rootfs` unsquashes cleanly, and `data` passes `e2fsck -fn`.

* NAND: 1024 blocks × 64 pages × 2048 bytes, plus 64 bytes OOB per page. Rockchip's driver stores two 32-bit "spare" words per page, at OOB `+0x04` and `+0x14`. `READ_SECTOR` returns them as the first 8 of the 16 spare bytes of the page's first sector (the rest are `FF`).
* Blocks 0–7: the BootROM boot block (IDB), in several copies. The logical `IDBlock` partition is a separate SFTL-managed copy.
* A 4 KiB logical page (LPA = LBA / 8) is stored split across a **block pair**: its first 2 KiB is page *n* of even block 2k, and its second 2 KiB is page *n* of block 2k+1.
* Even half spare: u16 page type (`0xF095` = user data; `0xF086`, `0xF0A4`, `0xF0C2`, `0xF0D1`, `0xF0E0` = SFTL map/system pages; `0x0000` = special, see below), u16 pair index (= 2k / 2), and u32 **write sequence**, which increases by one per programmed page.
* Odd half spare: u32 LPA, plus a second u32 that is *not* an ordering (using it picks stale copies).
* The current copy of an LPA is the user-data copy with the highest even-half sequence. Old copies remain until garbage collection, and many pairs are fully stale (e.g. 90/91).
* "Special" pages: the odd half has LPA `0xFFFFFFFD`, and the even half has type `0x0000` and data starting `95 f0 00 00 78 56 34 12`. About 6 per pair, in pairs 18, 168, 388, 550, and 828–958. Their meaning is unknown (checkpoint or power-loss records?). They're copied verbatim by any raw restore.
* Block 1023: page 0 is all zero (data and spare words), the rest erased. Probably a bad-block mark.
* Partition → physical pairs: [RECOVERY.md](RECOVERY.md) § 3.

## Boot chain

```text
BootROM (RK3032)
  -> SPI NAND boot block: DDR init V1.09 (2017-11-20), then Boot1 miniloader (built 2020-12-23, SFTL 5.0.55)
  -> uboot partition: U-Boot 2017.09-g97b7efa-dirty (2023-05-11), board evb_rk3036, bootdelay=0
       rkimg_bootdev: SD card first if `rkimgtest mmc 1` passes, else ... rksfc dev 0 -> devtype spinand
       bootcmd: boot_android ${devtype} ${devnum}; bootrkp; run distro_bootcmd
  -> boot partition: Linux 4.4.194 (tyc@dell, Linaro GCC 6.3, 2023-05-11), DTB "Rockchip RK3032 Dongle"
       cmdline: console=ttyS2,115200 rw root=PARTUUID=614e0000-0000 rootfstype=squashfs rootwait
  -> rootfs (SquashFS) -> BusyBox init (/etc/inittab) -> /etc/init.d/rcS -> S01..S50 scripts
       S50ui: test_mode ? /usr/bin/PCBA_TEST : /usr/bin/game        (the menu)
  -> game menu -> system("/data/start.sh <index> <smoothing> <speed>")
       -> cd /data/Games && ./<emulator> [variant] [-fast]
```

With the switch **OFF**, the BootROM skips the flash and waits on USB. That is the Mask ROM mode used for every read.

## Kernel and device tree

Unpacked into `~/partycade-dumps/extracted/bootimg/`. The decoded tree is committed as [captures/device-tree.txt](captures/device-tree.txt).

* **Memory:** `0x60000000`, 128 MiB.
* **Storage:** `sfc@10208000` (Rockchip SPI flash controller) is `okay`. All three MMC controllers, `dwmmc@1021c000` (`emmc`), `dwmmc@10214000` (`sdmmc`, which has a `cd-gpios`), and `dwmmc@10218000` (`sdio`), are `disabled`. **The stock Linux can't see an SD card.** A kernel booted from SD would carry its own device tree, though.
* **USB:** `usb@10180000` (the OTG port, dwc2) is `okay` with `dr_mode = "host"`. The second controller `usb@101c0000` is disabled. See [ADB](#adb-is-configured-but-unreachable).
* **Network:** `ethernet@10200000` (RK3036 EMAC, RMII) is `disabled`. There's no Wi-Fi node.
* **Serial:** only `serial@20060000` (uart0) is `okay`. uart2, the kernel console `ttyS2`, is disabled.
* **Controls:** `uart-keys` node. Linux input codes: volume `0x73`/`0x72`, joystick `KEY_UP 0x67`, `KEY_DOWN 0x6c`, `KEY_LEFT 0x69`, `KEY_RIGHT 0x6a`, buttons `BTN_A 0x130` … `BTN_THUMBR 0x13e` (a, b, c, x, y, z, l, r, l2, r2, select, start, mode, bl, br). The control deck most likely sends key states over uart0, and the driver turns them into an evdev device. A custom game should read `/dev/input/event*` and expect those codes. The driver also exposes `/sys/devices/platform/uart-keys/test_mode`, which `S50ui` reads to pick the factory test program.
* **Display:** `lvds-simple-panel` through `vop@10118000`. HDMI is present in the SoC but its sound card is disabled.
* **Audio:** `simple-audio-card` named `rockchip,rk3032-codec` over I2S.
* **Logo:** `logo.bmp`, 40 × 264, 24-bit, in the resource image.

## U-Boot

The compiled-in default environment is in [captures/uboot-env.txt](captures/uboot-env.txt). Points that matter for the plan:

* `bootdelay=0`. The serial hotkeys from Rockchip's `hotkey.c` still apply: Ctrl+C stops autoboot, Ctrl+D enters rockusb download mode, and Ctrl+B enters the BootROM download.
* Strings include `download key pressed... `, `enter Rockusb!`, `Enter rockusb failed, fallback to bootrom...`, and `rktest rockusb`.
* U-Boot's own embedded device tree (`uboot.img` offset `0x6be90`, 2114 bytes, model `SDK-RK3036`) contains only `serial@20068000` (uart2, the U-Boot console, so the UART pads should show U-Boot at 115200), `sfc@10208000` (`rockchip,rksfc`, okay), and `dwmmc@1021c000` (no status property, so enabled). **It has no `sdmmc@10214000` node.**
* That makes the env's SD logic play out like this. `mmc dev 1 && rkimgtest mmc 1` probably fails, because no mmc 1 exists. The next branch, `elif mmc dev 0`, selects a card on `dwmmc@1021c000` as the boot device *without* `rkimgtest`. Only after that does it fall through to `rksfc dev 0` (the SPI NAND). Whether the board's microSD slot is wired to `dwmmc@1021c000` decides whether the factory U-Boot sees a card at all. **Expected: it is not.** The kernel's own tree, written for this board, puts the slot on `dwmmc@10214000`: alias `sdmmc`, `bus-width = 4`, `supports-sd`, card-detect GPIO1 pin 17, and `vmmc` on the always-on `vcc_io`. `dwmmc@1021c000` there is `non-removable`, `supports-emmc`, and 8-bit: the eMMC that this board does not have. U-Boot's tree is the generic `SDK-RK3036` one (audit, 2026-10-24; unverified on the board's traces).
* The `rkimgtest` / `sdfwupdate` caution in [RUNBOOK.md](RUNBOOK.md) Phase 4 still applies if the card shows up as mmc 1. The factory boot block's word at sector 65 + 104 is `0`. On an SD card, that value means "firmware update card". Nothing in the stock rootfs or data reads `sdfwupdate`.

## Rootfs

The file listing is committed as [captures/rootfs-listing.txt](captures/rootfs-listing.txt). Small stock scripts are in [captures/stock-scripts/](captures/stock-scripts/).

* SquashFS 4.0, zlib, block size 131072, 1998 inodes, created 2023-05-11. Buildroot `2018.02-rc3-g8043419-dirty`, hostname `host`.
* ABI: ARM EABI5 **hard-float**, glibc **2.29** (`/lib/ld-linux-armhf.so.3`). BusyBox init and shell.
* Libraries of interest: SDL2 **2.0.7** (`libSDL2-2.0.so.0.7.0`), SDL2_image, SDL2_mixer, MiniGUI 3.2 (`libminigui_ths`), libdrm + `libdrm_rockchip`, `libmali` (GLES 1/2, EGL, OpenCL), ALSA (`libasound`), libpng12, libjpeg, freetype.
* Init: `/etc/inittab` mounts things, runs `/etc/init.d/rcS`, and respawns a getty on `console`. The scripts are `S01logging`, `S10udev`, `S20urandom`, `S21mountall.sh`, `S40network`, `S50dropbear`, `S50ui`, and `S50usbdevice`. `/etc/fstab` mounts `/dev/block/by-name/data` on `/data` as ext2.
* `S50ui` starts `/usr/bin/spk-init.sh` (speaker) and then either `/usr/bin/PCBA_TEST` (factory test, if `uart-keys/test_mode` is 1) or `/usr/bin/game`.
* **The menu, `/usr/bin/game`:** a 73 KB MiniGUI program. It plays `logo.mp4`, then shows 12 entries with artwork from `/usr/local/share/minigui/res/images/` (`game_0.jpg` … `game_11.jpg`, plus `gameN_controls.jpg` and `gameN_settings.jpg`). It stores settings in `/userdata/Games/Speed.cfg`, `Smoothing.cfg`, and per-game `.cfg`, and has hard-coded `.sav` paths for its "reset high scores" option. To launch, it calls `system("/data/start.sh %d %d %d")` with the menu index, pixel smoothing, and speed, and it creates `/tmp/.minigui_freeze` while a game runs. **The count and names of entries are compiled into this binary.** Adding a 13th entry would mean patching or replacing it. Swapping what an existing entry runs only needs `start.sh`.

### ADB is configured but unreachable

`/etc/init.d/.usb_config` contains `usb_adb_en`, and `/usr/bin/adbd` exists. On boot, `S50usbdevice` sets up a configfs gadget (VID `0x2207`, product `rk3xxx`), starts `adbd`, and binds the first entry of `/sys/class/udc/`. No UDC exists, because the device tree forces the OTG controller to `dr_mode = "host"`. A kernel device tree with `dr_mode = "peripheral"` should therefore give a root ADB shell over the Micro-USB port, without any other change to the stock system. This is untested. The cheapest test is from an SD card ([RUNBOOK.md](RUNBOOK.md) Phase 4 step 5).

## Data partition

The listing with sizes and hashes is committed as [captures/data-partition-listing.txt](captures/data-partition-listing.txt). `start.sh` is in [captures/stock-scripts/data_start.sh](captures/stock-scripts/data_start.sh).

* ext2, 1 KiB blocks, 7680 inodes, 30720 blocks, 5702 used (about 24 MB free). `compiling_time.txt` says `2023-05-11:19-05-57`.
* `/data/start.sh` maps the menu index to an emulator:

| Index | Game (from the comments) | Command in `/data/Games` |
| :--- | :--- | :--- |
| 0 | Pac-Man | `PacMan` |
| 1 | Pac & Pal | `SuperPacMan p` |
| 2 | Super Pac-Man | `SuperPacMan` |
| 3 | Pac-Man Plus | `PacMan p` |
| 4 | Pac-Land | `PacLand` |
| 5 | Pac-Mania | `NS1` |
| 6 | Galaga | `Galaga` |
| 7 | Galaxian | `Galaxian` |
| 8 | Mappy | `Mappy` |
| 9 | Dig Dug | `DigDug` |
| 10 | Dig Dug II | `Mappy d` |
| 11 | (Rompers, per the menu's `Rompers.sav`) | `NS1 r` |

  The speed argument appends `-fast`. Smoothing is exported as `SDL_RENDER_SCALE_QUALITY`. The comments list more games the emulators can run (Ms. Pac-Man `PacMan m`, Rally-X `RallyX`, Xevious, Rolling Thunder `NS86`, Galaga '88 `NS1 g`, Dragon Spirit `NS1 d`, …), but those binaries or ROMs are not on this cabinet.
* `/data/Games/`: 8 emulator binaries (ARM hard-float, dynamically linked against SDL2, SDL2_image, ALSA, and pthread; 47–118 KB each), `*.rom` (41 files), `*.cfg` (15), `*.sav` (13, high scores), `*.wav` (4), and `0.png`…`15.png`.
* Also in the root: `parameter`, `spk_volume`, and `lost+found`.

**Custom games:** the least invasive hook is `start.sh`. Pointing one index at our own program in `/data/Games/` needs only a changed `start.sh` plus the new file. Ways to get those bytes onto the cabinet are listed in [RUNBOOK.md](RUNBOOK.md) Phase 3.

## What is safe to commit

Commit text and metadata only: this file, `captures/*` (partition table, GPT sectors, decoded device tree, U-Boot env, file listings with sizes and hashes, small stock shell scripts). Never commit the images, the kernel, the U-Boot binary, launcher or emulator binaries, or ROMs.

## The running system, from the field run (2026-10-24, analysed 2026-10-25)

From `captures/system/` (the rootfs's scripts and rules), `captures/sysprobe/before-*.txt` (the System probe on the live cabinet), and `captures/love/`. Verified on this cabinet unless marked.

* **Nothing restarts the stock menu.** `inittab` has no respawn line for it; `S50ui` runs `/usr/bin/game &` once at boot with `XDG_CONFIG_HOME=/userdata/` and `MG_CFG_PATH=/etc`. While a game runs, the stock menu waits in `system()` holding 53 MB anonymous and 8.6 MB file-backed of the 118,668 kB. The kernel's OOM killer chose it (score 506) when memory ran out, and the screen kept its last picture, "LOADING...", for good.
* **Boot hooks into `/data`: none.** No init script or udev rule runs anything from `/data` or `/userdata` at boot. The first code of ours that runs is `/data/start.sh`, when the stock menu opens a game.
* **Services:** `syslogd`, `klogd`, `udevd`, `dropbear -R` (host keys made in `/var/run/dropbear` at the first connection, so new ones every boot), and `adbd` (configfs gadget `rockchip`, function `ffs.adb`, mounted at `/dev/usb-ffs/adb`; it never gets a UDC while the OTG controller is in host mode). Root's password is set (hash not copied); `/root` is an empty directory on the read-only squashfs.
* **Mounts:** `/` squashfs read-only; `/userdata` (`/dev/rkflash0p5`) ext2 read-write, with `/data` the same files; `/tmp` and `/run` tmpfs; debugfs at `/sys/kernel/debug`; configfs.
* **The flash in Linux** is `rkflash` (`/dev/rkflash0p1..p5`, the GPT's five partitions). p1–p4 read back byte-identical to `sftl_rebuild.py`'s rebuild of the raw dump, and every partition reports `ro 0`.
* **USB:** `usb@10180000` (`dwc2`, host) is bus 1 and serves the USB-A jack with the switch ON: a TP-Link AC600 (`2357:011e`, "802.11ac WLAN Adapter", Realtek) enumerated as `usb 1-1`, high speed, and no driver bound it. `usb@101c0000` is `disabled`.
* **Kernel:** `4.4.194 #485 SMP`, built by `tyc@dell` with Linaro GCC 6.3.1 on May 11 2023. No `IKCONFIG`. `/proc/modules` exists (empty), so it can load modules; there is no `/lib/modules`. Its strings name USB-Ethernet drivers (`r8152`, `asix`, `ax88179`, `smsc95xx`, `cdc_ether`, `cdc_ncm`, `rndis_host`) and no Wi-Fi stack (expected from names; nothing was loaded or plugged in to prove a driver).
* **Graphics leak:** each time a process quits SDL and starts it again (`SDL_Quit` then `SDL_Init` with KMSDRM on `libmali`), 6,144 KiB of DRM GEM shared memory stays allocated until the process exits (two 1024×768×4 buffers; `Shmem` grew to 43 MB). A process that exits gives it all back.
* **Display:** KMSDRM, 1024×768 at 60 Hz, format XRGB8888 (`0x16362004`), renderer `opengles2` with 4096 textures. One joystick, `uart-keys`: 21 buttons, no axes or hats. Audio: ALSA at 44.1 kHz.
