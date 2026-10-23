# Firmware Analysis

What the cabinet's flash contains, from the backups in `~/partycade-dumps/`. Only the first 32 MiB had been read when this was written (see [STATUS.md](STATUS.md)). Sections that need the rest are marked **TODO**.

## Flash layout

GPT on a 220672-sector logical disk (Rockchip SFTL on a Winbond W25N01GV SPI NAND). From [captures/partitions.json](captures/partitions.json):

| Partition | First LBA | Sectors | Size | Contents | Read? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| (MBR + GPT) | 0 | 64 | 32 KiB | Protective MBR, GPT header at LBA 1 | yes |
| `IDBlock` | `0x40` | `0x380` | 448 KiB | Rockchip boot block: DDR init + Boot1 miniloader, two copies | yes |
| `uboot` | `0x400` | `0x400` | 512 KiB | Rockchip `LOADER` image with U-Boot 2017.09 | yes |
| `boot` | `0x800` | `0x2400` | 4.5 MiB | Android boot image v0: zImage + Rockchip resource (DTB, logo) | yes |
| `rootfs` | `0x2c00` | `0x20000` | 64 MiB | SquashFS 4.0, zlib, 58,961,801 bytes used | first 27.8 MB only |
| `data` | `0x22c00` | `0xf000` | 30 MiB | unknown | **no** |

GPT last usable LBA is `0x31bff`. Sectors past that up to 220671 are SFTL capacity outside any partition.

## Boot chain

```text
BootROM (RK3032)
  -> SPI NAND boot block at LBA 64: DDR init V1.09 (2017-11-20), then Boot1 miniloader (built 2020-12-23, SFTL 5.0.55)
  -> uboot partition: U-Boot 2017.09-g97b7efa-dirty (2023-05-11), board evb_rk3036, bootdelay=0
       rkimg_bootdev: SD card first if `rkimgtest mmc 1` passes, else ... rksfc dev 0 -> devtype spinand
       bootcmd: boot_android ${devtype} ${devnum}; bootrkp; run distro_bootcmd
  -> boot partition: Linux 4.4.194 (tyc@dell, Linaro GCC 6.3, 2023-05-11), DTB "Rockchip RK3032 Dongle"
       cmdline: console=ttyS2,115200 rw root=PARTUUID=614e0000-0000 rootfstype=squashfs rootwait
  -> rootfs partition (SquashFS) -> init -> launcher (TODO: needs full rootfs)
```

With the switch **OFF**, the BootROM skips the flash and waits on USB. That is the Mask ROM mode used for every read.

## Kernel and device tree

Unpacked into `~/partycade-dumps/extracted/bootimg/`. The decoded tree is committed as [captures/device-tree.txt](captures/device-tree.txt).

* **Memory:** `0x60000000`, 128 MiB.
* **Storage:** `sfc@10208000` (Rockchip SPI flash controller) is `okay`. All three MMC controllers, `dwmmc@1021c000` (`emmc`), `dwmmc@10214000` (`sdmmc`, which has a `cd-gpios`), and `dwmmc@10218000` (`sdio`), are `disabled`. **The stock Linux can't see an SD card.** A kernel booted from SD would carry its own device tree, though.
* **USB:** `usb@10180000` (the OTG port) has `dr_mode = "host"`. The second controller is disabled.
* **Serial:** only `serial@20060000` (uart0) is `okay`. uart2, the kernel console `ttyS2`, is disabled.
* **Controls:** `uart-keys` node. Linux input codes: volume `0x73`/`0x72`, joystick `KEY_UP 0x67`, `KEY_DOWN 0x6c`, `KEY_LEFT 0x69`, `KEY_RIGHT 0x6a`, buttons `BTN_A 0x130` … `BTN_THUMBR 0x13e` (a, b, c, x, y, z, l, r, l2, r2, select, start, mode, bl, br). Most likely the control deck sends key states over uart0 and the driver turns them into an evdev device. A custom game should read `/dev/input/event*` and expect those codes.
* **Display:** `lvds-simple-panel` through `vop@10118000`. HDMI is present in the SoC but its sound card is disabled.
* **Audio:** `simple-audio-card` named `rockchip,rk3032-codec` over I2S.
* **Logo:** `logo.bmp`, 40 × 264, 24-bit, in the resource image.

## U-Boot

The compiled-in default environment is in [captures/uboot-env.txt](captures/uboot-env.txt). Points that matter for the plan:

* `bootdelay=0`. The serial hotkeys from Rockchip's `hotkey.c` still apply: Ctrl+C stops autoboot, Ctrl+D enters rockusb download mode, and Ctrl+B enters the BootROM download.
* Strings include `download key pressed... `, `enter Rockusb!`, `Enter rockusb failed, fallback to bootrom...`, and `rktest rockusb`.
* U-Boot's own embedded device tree (`uboot.img` offset `0x6be90`, 2114 bytes, model `SDK-RK3036`) contains only `serial@20068000` (uart2, the U-Boot console, so the UART pads should show U-Boot at 115200), `sfc@10208000` (`rockchip,rksfc`, okay), and `dwmmc@1021c000` (no status property, so enabled). **It has no `sdmmc@10214000` node.**
* That makes the env's SD logic play out like this. `mmc dev 1 && rkimgtest mmc 1` probably fails, because no mmc 1 exists. The next branch, `elif mmc dev 0`, selects a card on `dwmmc@1021c000` as the boot device *without* `rkimgtest`. Only after that does it fall through to `rksfc dev 0` (the SPI NAND). Whether the board's microSD slot is wired to `dwmmc@1021c000` is **unknown**, and that one fact decides whether an SD card is seen by the factory U-Boot at all.
* The `rkimgtest` / `sdfwupdate` caution in [RUNBOOK.md](RUNBOOK.md) Phase 4 still applies if the card shows up as mmc 1. The factory boot block's word at sector 65 + 104 is `0`. On an SD card, that value means "firmware update card".

## Rootfs (partial)

* Superblock: SquashFS 4.0, zlib, block size 131072, 1998 inodes, created 2023-05-11 11:06:33, `bytes_used` 58,961,801. It ends at LBA `0x2c00 + 115161 = 0x1edd9`.
* The directory and inode tables are at the end of the image, past the 32 MiB boundary, so `unsquashfs` can't list it yet.
* **TODO** (needs the full rootfs): init, launcher, emulator, game list, libc and float ABI. Questions are listed in [RUNBOOK.md](RUNBOOK.md) Phase 2.

## Data partition

* **TODO.** Not read: the whole partition is above LBA `0x10000`. With 64 MiB of rootfs taken by the system, this 30 MiB partition is the likeliest home for the 12 games and their list.

## What is safe to commit

Commit text and metadata only: this file, `captures/*` (partition table, GPT sectors, decoded device tree, U-Boot env), file listings with sizes and hashes, and small configuration excerpts. Never commit the images, the kernel, the U-Boot binary, launcher or emulator binaries, or ROMs.
