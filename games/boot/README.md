# Boot customization over the air: tinyinit + stage2

**First written 2026-10-26 20:52 (verified):** boot partition sha256 `94172b67…3704` (now `de23d410…b5c3`, below), written over Wi-Fi by
`tools/ota_boot.sh`; first boot: initramfs unpacked at 0.34 s, `yardinit: start` 0.77 s, stage2 at 2.4 s, Wi-Fi and
SSH 42 s after the reboot with no one at the cabinet, the health mark at 66 s (`boot/tries` back to 0).

**Since 2026-10-27, Partycade Home is the front end at power-on (verified over several reboots).** stage2 v2 puts
Home's power-on picture (`/userdata/home/boot.fb.gz`, rendered on the PC by `cart push`) into `/dev/fb0` at
~2.7 s and binds `S50ui` (this folder) over the stock `/etc/init.d/S50ui` from a copy in `/dev`; the stock rcS
then runs it at ~5.2 s: the saved volume and the factory test mode as stock, then `homeloop` (syntax-checked),
with a 30 s watchdog that starts the stock menu if neither Home nor the menu is up. Home's first frame ~9 s.
`boot/home-off` keeps stage2 and boots the stock menu; 1P + 2P at power-on gives the whole stock boot.
`tools/cab.sh bootfilm` films the next power-on (stage2 records into RAM; the stock boot sends a SIGUSR2 that
`cabctl record` ignores). **No "LOADING..." at power-on any more (2026-10-27, written with the user's approval, verified):** the boot partition
holds `out/boot-yard-klogo.img`, sha256 `de23d410…b5c3`: `boot-yard.img` with U-Boot's `logo.bmp` (40x264,
pixels only, `tools/bootimg.py logo`) and the kernel's compiled-in boot logo (`tools/kernel_logo.py`: a 142-colour
`linux_logo` in the inflated kernel, recompressed with zopfli into the same span) both replaced by `logo.png`
(a small neon PARTYCADE). Steps on the way: `boot-yard-logo.img` (`df00e303…a04b`, U-Boot's logo only). The boot
film's first frame (stage2, 2.7 s) shows the pink logo. Back to any earlier image: `tools/ota_boot.sh write
IMG <sha now>`; to stock: `tools/ota_boot.sh restore`.

**Since 2026-11-02 the boot partition is `out/boot-starlight.img`, sha256 `a8d3e0e8…7791`:** `boot-yard-sd2.img` with both
logos replaced by `logo-starlight.png` (BOOT_RESEARCH.md, 2026-11-02).

**Goal:** change what the cabinet does at power-on (intro, menu, idle screen, Wi-Fi at boot) from files in
`/data`, over Wi-Fi, with no Micro-USB. Written 2026-10-26.

## How

* Linux sees the flash as `/dev/rkflash0p1..5`, all writable (`ro=0`), through the kernel's own flash layer.
  The **boot partition (p3) is not in use once the kernel runs**, so it can be rewritten over SSH safely.
  The system image (p4, squashfs) is in use, so it is never written from the running system.
* The boot partition is an Android boot image with no ramdisk, and only 14 KB free. The kernel supports an
  initramfs, and U-Boot (Rockchip 2017.09) loads a ramdisk at `ramdisk_addr1_r` = 0x64000000 on boards with
  128 MB or less (`env_fixup`, `rk_board_req_mem_layout1`; the cabinet's U-Boot carries those strings).
* So `boot-yard.img` is the stock boot image plus a **4 KB initramfs**: `tinyinit` (3 KB, C, no libc).
  `tools/bootimg.py check` proves the kernel and the resource section (device tree, `logo.bmp`) are byte
  for byte the stock ones; only the ramdisk size and the header ID (SHA-1) change.
* `tinyinit` mounts the system image, mounts the data partition, and runs **`/userdata/boot/stage2.sh`** as a
  child (30 s limit), then starts the stock `/sbin/init` whatever happened. stage2 is an ordinary shell
  script on `/data`: everything after this one write is changed over Wi-Fi.

## Safety, in layers

1. **No stage2.sh, `boot/disabled`, or 1-player + 2-player held at power-on:** the stock boot, as before.
2. **A stage2 that fails or hangs** cannot stop the boot (child process, time limit).
3. **The try counter:** `boot/tries` counts boots that ran stage2; at 3, stage2 is skipped. stage2 resets it
   once the system has been up 60 s.
4. **A broken `/data`:** the stock boot.
5. **U-Boot cannot boot the boot partition:** its fallback (`boot_targets=mmc1 ...`) scans the SD card, which
   carries `extlinux/extlinux.conf` booting the stock kernel and device tree (`rescue/`) with the stock command
   line. Unverified: U-Boot only looks there after a failure.
6. **Anything else (a hang in the kernel or before Wi-Fi):** Mask ROM over Micro-USB: `rk_restore.py restore`
   of the boot partition's blocks from a fresh dump of today's state (RECOVERY.md). The stock boot image is
   `~/partycade-dumps/2026-10-23_raw_plug3032slc/boot.img` (sha256 `a0ce5967…3fba90`), also on the SD card.

## Tested

`qemu_test.py` boots the cabinet's own system image and data partition in QEMU (vexpress-a15, a 4.4 kernel
from Rockchip's tree with virtio) through `tinyinit-qemu` (the same code, virtio disk names): no stage2,
stage2, a failing stage2, a hanging stage2, the counter, `disabled`, the safe-mode keys, an unmountable data
partition, the real `stage2.sh`, Home bound (S50ui runs), `home-off`, and the safe-mode keys with Home installed
(14 scenarios). The stock rcS runs (udev, network, dropbear, ui) in every case.

## Files

| File | |
| :--- | :--- |
| `tinyinit.c`, `build.sh` | the init (`out/tinyinit`, and `out/tinyinit-qemu` for the test) |
| `mkinitramfs.py` | the 4 KB cpio |
| `../../tools/bootimg.py` | `info`, `ramdisk` (build `boot-yard.img`), `check` |
| `stage2.sh` | v2: a boot log, Home at power-on (picture, S50ui), Wi-Fi and SSH right after power-on, the health mark, `boot/film` |
| `S50ui` | bound over the stock one while Home is on: volume, test mode, homeloop, watchdog |
| `qemu_test.py` | the test |
