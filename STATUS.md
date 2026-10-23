# Status: what is known, as of 2026-10-23 11:40

This is the single source of truth for the current state. If another doc disagrees with this one, this one wins. Update it at the end of every session.

## Headline

* The cabinet can be put into USB Mask ROM on demand. A RAM-only USB loader can then be downloaded into it, and its flash read over USB, without writing anything.
* The board is an **RK3032** (not RK3036), with **128 MiB RAM** and a **Winbond W25N01GV 128 MiB SPI NAND**. There is no eMMC.
* The flash has a GPT with 5 partitions. The first 32 MiB of the flash are backed up and verified. That covers the boot block, U-Boot, the kernel, and the first 27.8 MB of the rootfs.
* **Blocker:** the only USB plug that sees the flash (`plug_3032`) returns `0xCC` fill for any read that starts at sector `0x10000` (32 MiB) or above. So the rest of the rootfs and the whole `data` partition, where the game list most likely lives, have not been read yet.
* **Next step:** one cold plug, then `tools/rk.py boot --plug plug_3032slc`. See [RUNBOOK.md](RUNBOOK.md), Phase 1.
* Nothing has ever been written to the cabinet's flash.

## Hardware state right now

At the end of the 2026-10-23 session, device 56 (`plug_3032` loader) was still on the bus at port `1-6`. Any new plug needs a cold plug first. A running plug can't be replaced.

## Verified facts

| Fact | Value | Evidence |
| :--- | :--- | :--- |
| Mask ROM entry | Switch **OFF** + cold plug (both plugs out first) | Repeated all session; [INTERFACING_AND_MODES.md](INTERFACING_AND_MODES.md) |
| Mask ROM USB | `2207:301a`, high-speed, no strings, `bcdDevice 1.00`, iface `FF/06/05`, bulk `0x81`/`0x02` | lsusb on devices 38–55 |
| Download protocol | Vendor control `0x40`/`0x0C`, index `0x471` then `0x472`, RC4 (Rockchip key) + CRC-16/CCITT, 4096-byte chunks | Devices 51, 53, 54, 55 |
| DDR init | `rk3036_ddr_396MHz_v1.11.bin` works. The same blob is used by Rockchip for RK3032. | Returned on 4 boots |
| SoC | RK3032 | `plug_3032` chip info `3032`; device tree `rockchip,rk3032-dongle`; RK3036 plugs misbehave |
| RAM | 128 MiB at `0x60000000` | Device tree `memory` node |
| Flash | SPI NAND, ID `EF AA 21` = Winbond W25N01GV (1 Gbit). The 4th/5th ID bytes vary between reads and are junk. | `plug_3032` READ_FLASH_ID |
| Logical size | 220672 sectors (107.75 MiB) served by Rockchip's SFTL translation layer | `plug_3032` READ_FLASH_INFO |
| Partition table | GPT: `IDBlock` 0x40+0x380, `uboot` 0x400+0x400, `boot` 0x800+0x2400, `rootfs` 0x2c00+0x20000 (64 MiB), `data` 0x22c00+0xf000 (30 MiB) | [captures/partitions.json](captures/partitions.json) |
| Factory boot block | DDR init `V1.09 20171120`, Boot1 built Dec 23 2020, `SFTL version: 5.0.55 20200925`, SFC NAND/NOR drivers | Plaintext strings in `IDBlock` |
| U-Boot | `U-Boot 2017.09-g97b7efa-dirty (May 11 2023)`, `board=evb_rk3036`, `bootdelay=0`; checks the **SD card first** (`rkimgtest mmc 1`) | [captures/uboot-env.txt](captures/uboot-env.txt) |
| U-Boot download mode | Has rockusb ("download key pressed… enter Rockusb!") and serial hotkeys | `uboot` strings |
| Kernel | Linux 4.4.194, built May 11 2023 by `tyc@dell`, Android boot image v0, no ramdisk | `boot` partition |
| Kernel cmdline | `console=ttyS2,115200 rw root=PARTUUID=614e0000-0000 rootfstype=squashfs rootwait` | Device tree `chosen` |
| Rootfs | SquashFS 4.0, zlib, 58,961,801 bytes, 1998 inodes, built May 11 2023 | Superblock |
| USB OTG in Linux | `dr_mode = "host"` | Device tree. Explains why the PC sees nothing with the switch ON |
| Controls | `uart-keys` driver: joystick → `KEY_UP/DOWN/LEFT/RIGHT`, buttons → `BTN_A`… (`0x130`–`0x13e`), volume keys. Only `uart0` is enabled. | Device tree `uart-keys` |
| Serial console | Kernel console points at `ttyS2`, but `serial@20068000` (uart2) has `status = "disabled"` | Device tree. UART pads may show only loader/U-Boot output |
| Display | `lvds-simple-panel` through the VOP | Device tree |

## Plug results on this board

| Plug (`rk.py` name) | File | Result |
| :--- | :--- | :--- |
| `plug_std` | `rk303x_usbplug_v2.57.bin` | Runs. Flash ID `EMMC`, size 0, reads are RAM noise. Not useful. |
| `plug_slc` | `rk303x_usbplug_slc_v2.65.bin` | Runs, then the chip resets to Mask ROM about 0.3 s later. |
| `plug_slc264` | `rk303x_usbplug_slc_v2.64.bin` | Same as `plug_slc`. |
| `plug_3032` | `rk3032_usbplug_v2.61.bin` | **Works** for LBA < `0x10000`. Reads that *start* at ≥ `0x10000` return `0xCC` with status 0. |
| `plug_3032slc` | `rk3032_usbplug_slc_v2.63.bin` | **Not tried yet.** RK3032 variant with SFTL 5.0.58 (factory is 5.0.55; `plug_3032` is 5.0.53). |

A plug that resets the chip leaves a fresh Mask ROM on the bus (new device number). The next boot can go straight onto it without a cold plug.

## Backups

All outside the repo in `~/partycade-dumps/`. Its `README.txt` says what is complete.

* `2026-10-23_plug3032/full_lba0_220672.img`, sha256 `4841f3a6…34f9`. Two full passes matched. **Only the first `0x10000` sectors are real.** Their sha256 is `342b0e8b6d0f9ced282e381efef8226fb3b2f7b2e6276eae8438581eee3e1fba`. Any later full dump must reproduce that hash over its first 32 MiB.
* `extracted/`: `IDBlock.img`, `uboot.img`, `boot.img`, the unpacked kernel, the device tree, and the boot logo.

## Open questions, in priority order

1. Can any plug read LBA ≥ `0x10000`? `plug_3032slc` first. Fallbacks are in [RUNBOOK.md](RUNBOOK.md).
2. What is in `data` (30 MiB)? It is probably the games, the ROMs, and the game list. Not read yet.
3. What launches the menu (init scripts and launcher binary in the rootfs)? This needs the full rootfs.
4. Can the stock U-Boot see the microSD slot? U-Boot's own device tree only has `dwmmc@1021c000`, and stock Linux disables every MMC controller. See [FIRMWARE_ANALYSIS.md](FIRMWARE_ANALYSIS.md) § U-Boot. If it can, SD boot is a no-flash-write path for custom software.
