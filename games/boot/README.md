# Boot customization over the air: tinyinit + stage2

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
partition, and the real `stage2.sh`. The stock rcS runs (udev, network, dropbear, ui) in every case.

## Files

| File | |
| :--- | :--- |
| `tinyinit.c`, `build.sh` | the init (`out/tinyinit`, and `out/tinyinit-qemu` for the test) |
| `mkinitramfs.py` | the 4 KB cpio |
| `../../tools/bootimg.py` | `info`, `ramdisk` (build `boot-yard.img`), `check` |
| `stage2.sh` | v1: a boot log, Wi-Fi and SSH right after power-on, the health mark |
| `qemu_test.py` | the test |
