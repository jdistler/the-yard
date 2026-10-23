# Recovery plan: getting a bricked cabinet back to factory state

Read this **before** anything ever writes to the cabinet, so the way back is known in advance. Every path below restores the exact bytes that were on the chip on 2026-10-23.

Status, 2026-10-23: the backup is complete and verified three ways. The USB restore path has been designed and is coded, but it has **never been run**. The write commands still have to be tested. That is the test ladder in section 6, and every rung needs the user's explicit go-ahead.

## 1. Why this cabinet is hard to brick permanently

* The RK3032's first-stage loader, the **BootROM**, is mask ROM inside the SoC. Nothing on the flash can change it.
* The back switch **OFF** plus a cold plug puts the chip in USB Mask ROM even when the flash holds a perfectly good firmware. This has been observed on every cold plug so far. So the switch overrides the flash, and a damaged flash can't take USB Mask ROM away. Rockchip BootROMs also fall back to USB by themselves when they find no valid boot block.
* From Mask ROM, `rk.py boot --plug plug_3032slc` loads a loader that reads every physical page of the NAND (`READ_SECTOR`). The same loader accepts the matching write commands (`WRITE_SECTOR`, `ERASE`), so the same path can put pages back.
* **The only truly irreversible things are eFuse writes** (`WRITE_NEW_EFUSE 0x23` and the like) and physical damage. No tool in this repo can send an eFuse command, and none ever should.

So "bricked" here means one of these: the flash contents are wrong, Mask ROM can't be reached (a hardware fault), or the NAND chip itself died. Sections 4 and 5 cover each case.

## 2. What is backed up

Everything is in `~/partycade-dumps/2026-10-23_raw_plug3032slc/`, outside git. `SHA256SUMS` in that folder covers every file.

| File | What it is | sha256 (first 16) | Used for |
| :--- | :--- | :--- | :--- |
| `nand_raw.bin` | **The master backup.** All 262144 physical sectors × 528 bytes (512 data + 16 spare, page-major) via `READ_SECTOR` | `024af9edbf48df38` | USB raw restore (path A) |
| `nand_raw.bin.sha256` | Provenance line written by `rk.py rawdump` | | `rk_restore.py` refuses an image without it |
| `nand_native_2112.bin` | The same pages in the chip's own layout: 2048 data + 64 OOB. Bad-block marker `FFFF`, Rockchip spare words at OOB `+0x04` / `+0x14` | `db15402d75ad5d9a` | External programmer (path D) |
| `logical_rebuilt.img` | The 107.75 MiB logical disk that Linux sees, rebuilt offline from the raw image by `tools/sftl_rebuild.py` | `94568231f7f9a2b4` | Analysis, SD card, logical restore (path B) |
| `IDBlock.img`, `uboot.img`, `boot.img`, `rootfs.img`, `data.img` | Partitions carved from the logical image at the GPT offsets | see `SHA256SUMS` | Analysis, SD card |
| `rootfs/`, `data_fs/` | Extracted file trees | | Reading only |

How we know the backup is right:

1. Two full `rawdump` passes produced the same sha256. `--verify` also read every chunk twice.
2. A live `rk_restore.py diff` (2026-10-23, device 58) read all 1024 blocks again and found **0 differing blocks**.
3. The rebuilt logical image matches the independent `READ_LBA` dump (`2026-10-23_plug3032/full_lba0_220672.img`) on all 65536 sectors that `READ_LBA` could reach. `rootfs.img` unsquashes cleanly, and `data.img` passes `e2fsck -fn` with no errors.

**User action, once:** copy the whole `~/partycade-dumps/` folder (about 500 MB) to a second place, such as a USB stick or cloud storage. If this PC's disk dies, the backup goes with it.

## 3. Physical layout of the chip (from the backup)

W25N01GV: 1024 blocks × 64 pages × 2048 bytes, plus 64 OOB bytes per page. `rk.py` sector numbers are physical: `sector = block*256 + page*4 + i`.

| Blocks | Contents |
| :--- | :--- |
| 0–7 | Boot block (IDB: DDR init + miniloader), read by the BootROM. Several copies, in even/odd pairs |
| 8–15 | Erased |
| 16–969 | SFTL user data in even/odd pairs: a 4 KiB logical page is stored as page *n* of block 2k plus page *n* of block 2k+1. Many pairs are fully stale (every logical page has a newer copy elsewhere) and wait for garbage collection; e.g. 90/91, 92/93, 166/167 |
| 18/19, 168/169, 388/389, 550/551, 828–958 (even/odd) | "sftl-special": about 6 pages per pair. The odd half has LPA `0xFFFFFFFD`; the even half has tag `0x0000` and a `0x12345678` magic. Probably SFTL checkpoint or power-loss records. Treat as live metadata |
| 970–1022 | SFTL system blocks: map and bad-block tables (tags `0xF086`, `0xF0A4`, `0xF0C2`, `0xF0D1`, `0xF0E0`) mixed with data |
| 1023 | Page 0 is programmed as all `0x00` (data and spare words); pages 1–63 are erased. Probably a bad-block marker or a block reserved by the driver. **Never write it.** |

`tools/rk_restore.py plan IMAGE` prints the current classification.

Where each partition's current data physically lives (`tools/sftl_rebuild.py nand_raw.bin --where <name>`; even block of each pair listed, the odd block is +1):

| Partition | Block pairs |
| :--- | :--- |
| `IDBlock` (logical copy; the BootROM reads physical blocks 0–7) | 16, 164 (shared with other data) |
| `uboot` | 160, 162 |
| `boot` | 124–158 |
| `rootfs` | 20–88, 94–122, 412–… (256 pairs) |
| `data` | 174–… (122 pairs) |

This is useful after a bad experiment. If `diff` reports only blocks from one partition, you know what got hit.

## 4. Brick scenarios and what to do

Always start the same way: cold plug with the switch **OFF**, then `rk.py state` should show `maskrom`. If it doesn't, go to scenario 5.

| # | Symptom with the switch ON | Likely cause | Fix |
| :--- | :--- | :--- | :--- |
| 1 | Menu works, but a game won't start or behaves wrongly | `data` partition changed (e.g. `/data/start.sh`, a `.cfg`, a binary) | Path A, restricted to the blocks `diff` reports |
| 2 | Logo then black, or a boot loop | Kernel (`boot`) or `rootfs` damaged | Path A |
| 3 | Completely dark, no logo | `IDBlock` or `uboot` damaged, or SFTL metadata corrupt | Path A, including boot blocks (`--include-boot-blocks`) |
| 4 | Anything, after an interrupted restore | Partial write | Mask ROM still works (section 1). Run path A again: `diff`, then restore what differs |
| 5 | Switch OFF + cold plug shows **nothing** on USB | The cable or port first. Then the switch, the USB path, or the SoC | Try another cable and port, and `dmesg`. Then path D (external programmer). The flash contents can't cause this |
| 6 | Path A erase or program fails with a status error, or read-back never matches | The NAND chip is wearing out or dead | Path D with a new chip (section 5, caveat about bad blocks) |

## 5. Restore paths

### Path A: USB raw block restore (BLOCKED with `plug_3032slc`: erase is a no-op above block 8)

> [!WARNING]
> Tested 2026-10-23 12:39 (approved T1–T3). T1 (block 8, already erased) "passed" but proved nothing. In T2, `ERASE_NORMAL` on block 91 returned status 0, yet the block read back unchanged, and a full `diff` showed the chip untouched. The tool stopped before programming. The cabinet is unchanged.
>
> Cause, from disassembling `rk3032_usbplug_slc_v2.63.bin` (load address `0x63000000`): opcode `0x06` (switch at `0xe774` → `0xe358`) and `0x0B` (→ `0xe2ea`) both call `0x12d4a(block, count, force)`, which calls the storage driver's erase hook. The erase function at `0xbec6` returns 0 **without erasing** when the start block is above 8, and clips the range to blocks 0–7 (skipping bad blocks, string "ce: %x is bad block skip"). So this plug can only erase the boot-block area. `ERASE_FORCE` most likely reaches the same code and stays on the never-send list.
>
> Path A therefore can't restore `data`/`rootfs` blocks with this plug. Recovery of data blocks currently relies on path B (U-Boot rockusb) or path D (programmer). Reads (`rawdump`, `diff`) are unaffected.

This puts back the exact physical pages, including SFTL's own metadata. The factory SFTL (5.0.55) then finds exactly the state it left. That's why it's the primary path: it doesn't depend on how the plug's SFTL version (5.0.53/5.0.58) would lay data out, and it isn't limited to 32 MiB the way `READ_LBA`/`WRITE_LBA` are.

Wire format, from `reference/rkdeveloptool/RKComm.cpp`:

* `ERASE_NORMAL 0x06`: CBW with no data. `dwAddress` = **block index** (rkdeveloptool computes `offset / usBlockSize`), `usLength` = block count. CSW status 1 means a bad block.
* `WRITE_SECTOR 0x05`: `dwAddress` = physical sector, `usLength` ≤ 32. The data phase carries `count × 528` bytes in exactly the layout `READ_SECTOR` returns and `nand_raw.bin` stores.

Procedure (needs the user's written approval for the exact block list):

```bash
tools/rk.py state                                   # fresh maskrom after a cold plug, switch OFF
tools/rk.py boot --plug plug_3032slc                # the plug the backup was taken with
tools/rk.py info                                    # must show EF AA 21, block_sectors 256, page_sectors 4
I=~/partycade-dumps/2026-10-23_raw_plug3032slc/nand_raw.bin
tools/rk_restore.py diff $I                         # read-only; lists the differing blocks (~35 s)
# show the list to the user, get approval in writing, then:
PARTYCADE_ALLOW_NAND_WRITE=yes tools/rk_restore.py restore $I --blocks <list from diff> \
    --approval "<user's words, date>"               # asks you to type WRITE; erase, verify FF, program, verify
tools/rk_restore.py diff $I                         # must say "none"
```

Then the user does a cold plug with the switch **ON**. Success is the normal logo and menu.

Rules for path A:

* Restore only the blocks `diff` lists, not the whole chip. Fewer erase cycles, and a smaller blast radius if something is wrong.
* `restore` stops at the first failure. Don't loop or retry blindly. Record the output in BOOT_RESEARCH.md and think first.
* Never write through `WRITE_LBA` with the plug. The plug's SFTL would rewrite map pages in its own format and version.
* Blocks 0–7 need `--include-boot-blocks`. Restore them last, so that if something goes wrong earlier, the old boot block still boots whatever is intact.

### Path B: logical restore through U-Boot rockusb (offline analysis 2026-10-23; never entered)

U-Boot 2017.09 in the `uboot` partition writes the SPI NAND through the same SFTL the kernel uses (`FtlWrite`, `sfc_nand_erase_block` are in the image). Its `download` command runs `rockusb 0 $devtype $devnum`, and this board's boot device is `spinand` (FIRMWARE_ANALYSIS.md). A rockusb write is a logical-sector write, so SFTL updates its own map. The legacy raw opcode is rejected (`CMD Not support, pls use new version Tool`); the write that works is the mass-storage one. Nothing here has been run on the cabinet.

There is no download key to press. The image does contain `download key pressed... ` and an ADC key driver (`adc-keys`, `rockchip,saradc`), but neither U-Boot's own device tree nor the kernel tree has an `adc-keys` or `saradc` node. The control deck is `uart-keys`, which U-Boot never reads. Holding a cabinet button at power-on does not enter download mode.

Ways in, both untested:

* **UART, the realistic one.** U-Boot's console is uart2 at 115200 (pads inside the shield, 3.3 V; INTERFACING_AND_MODES.md). `bootdelay=0`, so Ctrl+D has to be arriving as U-Boot starts; it runs `rockusb`. Ctrl+C is a shell. The shell has `ext4load` and `fatwrite` and no `ext4write`, so putting a file on `data` is a rockusb write from the PC, not a shell redirect. The kernel then disables uart2, so this console does not become a Linux login.
* **`reboot loader` from a root shell.** The kernel image contains the reboot-mode driver, and its tree maps `loader` to `0x5242c301` (GRF + `0x1d8`), which is U-Boot's `BOOT_LOADER` and prints `enter Rockusb!`. There is no root shell until some other path exists, so this is how a later game build would re-enter rockusb, not how we get in the first time.

Some Rockchip U-Boot rockusb builds return `0xCC` for reads past 32 MB (`RKUSB_READ_LIMIT_ADDR`). This image was not proven to have that cap. Writes in the matching source are not capped. Confirm with a read of a known sector above 32 MB before trusting a dump from this mode. A write should be one partition, checked with `rk_restore.py diff` afterwards (switch OFF, Mask ROM, read-only).

### Path C: SD card (theory, for diagnosis)

The factory U-Boot boots a Rockchip-format microSD first (RUNBOOK.md Phase 4). If U-Boot works but the rest of the flash doesn't, a card made from `logical_rebuilt.img` brings the cabinet up from the card. That gives a working Linux to diagnose from. It doesn't restore the NAND by itself. Whether the RK3032 BootROM can boot an SD card directly (with the NAND boot block dead) is unknown.

### Path D: external SPI NAND programmer (for Mask ROM failure or a dead chip)

* Chip: Winbond **W25N01GV**, 3.3 V SPI NAND. Check the package on the board: WSON-8 (8×6 mm) is the usual one, SOIC-16 is possible. A clip rarely works on WSON, so plan on hot-air removal and a WSON-8 socket adapter.
* Programmer: a CH341A with [SNANDer](https://github.com/McMCCRU/SNANDer) supports W25N01GV. Use 3.3 V only, and check the CH341A's data lines are 3.3 V (many cheap ones are 5 V and need a fix).
* Image: `nand_native_2112.bin`. Write it with on-die ECC **enabled**, so the chip computes its own ECC bytes in the OOB. Skip block 1023.
* **First**, read the chip with the programmer and compare it with `nand_native_2112.bin` (data plus OOB `+0x04..0x07` and `+0x14..0x17`). That proves the conversion and the programmer before any write.
* New chip caveat: a replacement chip has its *own* factory bad blocks. If any block the image uses is bad on the new chip, a 1:1 raw copy doesn't work. SFTL would have to rebuild around it, and that path (write the IDB raw, let the factory firmware format SFTL, then write partitions logically) is unexplored. Read the new chip's bad-block markers first.

## 6. Test ladder for path A (do in order; each rung needs explicit approval)

The aim is to prove the write path **before** it's needed, on blocks where failure costs nothing. Before each rung: cold plug, `boot --plug plug_3032slc`, and a full `diff` that says "none". After each rung: a full `diff` (must say "none"), then a cold plug with the switch ON, and the user confirms the menu works. Record each rung in BOOT_RESEARCH.md.

| Rung | Command (after the env var and `--approval`) | What it proves | Worst case |
| :--- | :--- | :--- | :--- |
| T0 (done) | `rk_restore.py plan`, `native`, `diff` | The backup is complete, current, and self-consistent | None (read-only) |
| T1 | `restore $I --blocks 8` | `ERASE_NORMAL` addresses **blocks** on this plug. Block 8 is erased in the backup and on the chip, so only an erase and an FF check happen | If the plug treated the address as a sector or page number, it would erase inside block 0 (a boot block copy). The full `diff` afterwards shows exactly what changed, and `restore --blocks 0 --include-boot-blocks` puts it back |
| T2 | `restore $I --blocks 91` | `WRITE_SECTOR` programs data and spare correctly over a full 64-page block. Pair 90/91 is **fully stale**: every logical page in it has a newer copy elsewhere (the rebuild map proves it), so SFTL never reads it as current data | Block 91 is left wrong. SFTL erases stale blocks before reuse, and `restore --blocks 91` can try again |
| T3 | `restore $I --blocks 21` | A live data block round-trips. Pair 20/21 holds only `rootfs` pages (`sftl_rebuild.py --where rootfs` marks it `*`), and rootfs is read-only at runtime | If it fails, part of the rootfs is wrong until restored: logo then black. Mask ROM is still there |

**Result 2026-10-23:** T1 ran (no change), T2 stopped at "not 0xFF after erase" (the erase was a no-op, see path A warning), T3 not run. Full `diff` after each: none.

After T3 passes, path A is proven, and the cabinet can be put back to 2026-10-23 state at any time. Only then should anything that changes the flash on purpose be considered (RUNBOOK.md Phase 3, path B).

## 7. Commands that must never be sent

`rk_restore.py` only knows `0x05` and `0x06`. Nobody should add these:

| Opcode | Name | Why |
| :--- | :--- | :--- |
| `0x23` (and other eFuse/OTP) | `WRITE_NEW_EFUSE` | Irreversible. Could disable USB Mask ROM or change the boot order forever |
| `0x0B` | `ERASE_FORCE` | Ignores bad-block marks and can erase factory bad-block information |
| `0x16`, `0xFD` subcodes | `ERASE_SYSTEMDISK`, low format | Wipes SFTL wholesale |
| `0x15`, `0x25` | `WRITE_LBA`, `ERASE_LBA` | Go through the plug's SFTL (see path A rules) |
| `0x2A` | `CHANGE_STORAGE` | Not needed; unknown side effects |
| `0xFF` | `DEVICE_RESET` | Not needed; a cold plug does the same thing safely |
