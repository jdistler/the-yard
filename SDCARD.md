# The microSD card: format and layout

Written 2026-10-24. **Nothing here has been tried on the cabinet yet.** The slot is still switched off in the device tree (FIELD_TASKS.md task 7 turns it on). The rules below come from the stock rootfs, the device trees, the U-Boot source, and the runtime's code; each is marked with how sure it is. Task 7 checks them, and this file gets updated with what it finds.

## Verified on the cabinet (2026-11-01)

The slot is on: boot partition `def61406…7c53` (`games/boot/out/boot-yard-sd2.img`: `/dwmmc@10214000` okay, sealed with
`tools/bootimg.py`, so U-Boot's DTB hash check passes). A 32 GB SanDisk SDHC card (ext2, one partition) is found when
pushed in with the power on, runs at high speed (37.125 MHz), and is mounted read-write at **`/mnt/sdcard`** with
`noatime` by the stock udev rule. dd with fsync: **14 MB/s write, 16 MB/s read**. Hot insertion works. Before writing
the boot image, the same tree was booted from RAM through U-Boot's console (`fdt set`, `bootz`), so nothing was
written until it had run. The slot's DAT0/DAT1 are also U-Boot's console (RECOVERY.md path E): with a card in, the
console is the card's, and the sniffer board takes its place for recovery.

## What Home keeps on it (2026-11-02)

* `partycade/logs/home.log` (and `.1`): Home's log, when a card is mounted at power-on (homeloop; up to 4 MB, Home
  trims it itself). Without a card it is `/data/home/home.log` (128 KB). `/tmp/home.logpath` says which.
* `partycade/swap`: 128 MB of swap (made once: `dd if=/dev/zero of=... bs=1M count=128`, `mkswap`). **Off by
  default** (2026-11-02): with it on, running out of memory froze the whole cabinet (the card swapping) where
  without it the kernel kills Home and homeloop starts it again. homeloop turns it on once a boot only if
  `partycade/swap.on` exists (swappiness 10).
* `partycade/art/<show>/<name>.pkm`: the shows' painted pictures (tools/show_art.py; cart push copies them).
* Nothing Home needs to start lives on the card: take it out and Home logs to /data again at the next start.

## The short version

* A microSDHC card, 4 to 32 GB.
* The first 16 MiB wiped to zeros.
* An MBR (DOS) partition table with **one** partition, starting at 1 MiB, filling the card.
* That partition formatted **ext2**, label `YARD`.
* Games go in `yard/carts/<id>/` on it.

```
/                      the card's root (mounted at /mnt/sdcard on the cabinet)
  yard/
    carts/<id>/        extra carts: info.lua, main.lua, pictures, as in games/carts/
  label                the card's one-word name (card.read("label"); The Yard shows "card in")
  visited, orb-card    small files the games write (card.write)
  love/                later: the LÖVE bundle, unpacked (games/love/README.md)
```

## Why each rule

| Rule | Why | How sure |
| :--- | :--- | :--- |
| **Wipe the first 16 MiB** | Stock U-Boot runs `rkimgtest` on a card. A card whose sector 64 starts with a Rockchip loader signature (`0xFCDC8C3B`, `0x534e4b52`, `0x534e5252`) passes it, and if the word at sector 65 + 104 is zero, U-Boot starts the kernel in Rockchip's SD firmware-update mode (`sdfwupdate`). A card that once held a Rockchip, Pi, or other board image can carry exactly that. Zeros there rule it out. **Never write a Rockchip image, loader, or anything made from the cabinet's boot block onto the card** without the user's explicit OK (AGENTS.md). | The test is in the U-Boot source (RUNBOOK.md Phase 4). The device trees say U-Boot can't see this slot at all, so it is expected never to look, but wiping costs nothing |
| **MBR, partition 1 at 1 MiB** | Every kernel reads an MBR table. Whether this 4.4 kernel reads GPT on a card is not known. 1 MiB alignment suits the card's erase blocks and keeps the wiped area clear | MBR support: expected. GPT: unknown |
| **One partition** | The stock rule `/lib/udev/rules.d/61-sd-cards-auto-mount.rules` mounts a card partition (`mmcblk*`, parent type `SD`) on `/mnt/sdcard`. With two partitions, both go to the same folder and the second hides the first. Task 7's test card has two partitions on purpose, to see what really happens | The rule's summary is from the rootfs (GAMEDEV.md § 9); its exact text arrives with task 1 (`captures/system/`). Two partitions: untested |
| **ext2** | The rule mounts ext2 with `exec`, so programs (LÖVE, later `wpa_supplicant`) can run from the card. FAT is mounted with `fmask=133`, which takes away every file's run permission: fine for pictures and saves, but nothing on it can run. The kernel has no ext4 driver, so an ext4 or ext3 card won't mount as such | Mount options: from the rootfs rule. Kernel filesystems: from the kernel's strings (STATUS.md) |
| **Label `YARD`** | Nothing depends on it yet; it marks the card as ours, and a later launcher can check for it | — |
| **SDHC, 4–32 GB** | The slot runs 4-bit at up to 37.5 MHz, about 18 MB/s at best, with no 1.8 V supply, so UHS speeds don't apply: any Class 10 or A1 card is as fast as the slot. SDXC (64 GB and up) should work once reformatted to ext2, but is untested | Expected, from the device tree |
| **`yard/carts/<id>/`** | The cart runtime looks for carts in `YARD_CARTS`, then `yard.pak` beside it, then a card's `yard/carts` (`games/engine/runtime.c`, `scan_carts`). The card root is `/mnt/sdcard` when that is a mount; otherwise the cabinet build mounts `/dev/mmcblk0p1` (then `/dev/mmcblk0`, then a USB `/dev/sda1`) on `/tmp/stick` itself, trying vfat, ext2, then exfat | Read from the code. `test.py system` checks on the PC, with `CAB_EXT=<folder>` standing in for the card, that a card cart is listed and that a card cart with a shipped cart's id is skipped (the shipped one wins, so give card carts new ids). Not on the cabinet |
| **`label`, `visited`, `orb-card` at the root** | `card.read` and `card.write` (CARTS.md § 4) use one-word names at the card's root, at most 4096 bytes, written with a temp file, fsync, and rename | Code; PC only |

## Making a card (on the Linux PC)

**Find the card first, and check it twice.** A wrong device name erases the PC's own disk.

```bash
lsblk -o NAME,SIZE,MODEL,TRAN,MOUNTPOINTS      # once without the card
lsblk -o NAME,SIZE,MODEL,TRAN,MOUNTPOINTS      # once with it: the new disk is the card, e.g. sdX or mmcblkN
CARD=/dev/sdX                                  # the whole card, not a partition; its SIZE must match the card
sudo umount ${CARD}* 2>/dev/null
sudo dd if=/dev/zero of=$CARD bs=1M count=16 conv=fsync
sudo parted -s $CARD mklabel msdos mkpart primary ext2 1MiB 100%
sudo mkfs.ext2 -L YARD ${CARD}1                # on an mmcblk card the partition is ${CARD}p1
sudo dumpe2fs -h ${CARD}1 | grep -i features   # expect only: ext_attr resize_inode dir_index filetype sparse_super large_file
sudo mount ${CARD}1 /mnt
sudo mkdir -p /mnt/yard/carts
echo yard | sudo tee /mnt/label
sudo umount /mnt
```

If `dumpe2fs` lists anything beyond those features (a newer `mke2fs` might add one), write it down and remake the card with `-O ^name` for each extra one. A feature the 4.4 kernel doesn't know makes it refuse the mount, or mount it read-only.

To put a cart on the card: `sudo cp -r games/carts/<id> /mnt/yard/carts/` with the card mounted. A cart on the card is checked like any other (`./cart check <id>` first).

## Looking after it

* **Switch off from the stock menu, not mid-game.** ext2 has no journal. A power cut while a game writes can leave the card needing a check. On the PC: `sudo e2fsck -f ${CARD}1`. The games write with fsync and rename, so a save is either the old one or the new one.
* **The card adds; it never replaces.** Everything that must work with no card (the menu, the shipped carts, the saves) stays in the NAND. A cart on the card disappears from the menu when the card is out.
* **Hot-plugging is untested.** Until task 7 shows the cabinet notices a card going in and out (the slot polls, `broken-cd`), put the card in before switching on.

## What task 7 has to confirm

1. The slot is fitted and wired as the kernel's tree says, and a card shows up at all.
2. Which mount the udev rule makes: where, with which options, and what happens with two partitions.
3. ext2 mounts read-write with `exec`; FAT mounts with `fmask=133`.
4. Read and write speed.
5. A card cart appears in The Yard's menu.

Each answer replaces an "expected" in this file with what was seen.
