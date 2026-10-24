# tools/

| File | Touches the cabinet? | What it is |
| :--- | :--- | :--- |
| `rk.py` | Reads only | The main tool. Read-only USB access to the cabinet: state, boot, info, probe, parts, read, dump, rawdump, log. |
| `rk_restore.py` | `diff` reads; `restore` **writes** (locked) | Recovery: `plan`, `native`, `diff`, `restore`. See [RECOVERY.md](../RECOVERY.md). The only erase and program code in the project. |
| `sftl_rebuild.py` | No (offline) | Raw NAND image → logical disk image, and `--where` (which physical blocks hold a partition). |
| `sftl_patch.py` | No (offline) | Modified logical image → patched copy of the raw image, plus the list of blocks that changed. Feeds `rk_restore.py restore`. |
| `data_patch.py` | No (offline) | RAW + `--put SRC:DEST[:MODE]` / `--overwrite SRC:DEST` / `--replace DEST:OLD:NEW` / `--rm DEST` on the `data` partition → patched raw image, block list, restore command. Runs e2fsck before and after, reads every edit back, and requires an exact rebuild round trip. `--overwrite` writes a same-size file into the data blocks it already owns (found with debugfs `bmap`, never `blocks`, which lists indirect blocks too): nothing is allocated, so only pages SFTL has written before change. `--repair` fixes a power-cut filesystem in the copy before editing. `games/cart deploy` drives it. |
| `rksend.c` | Mask ROM download | C sender for the Mask ROM download stages, called by `rk.py boot`. It uses asynchronous libusb control transfers so every 4096-byte chunk reports `actual_length` and status, and it stops at the first short or failed chunk. |
| `Makefile` | | `make -C tools` builds `rksend`. The header is in `inc/libusb.h` (libusb 1.0.27), so no `-dev` package is needed. |
| `fetch_references.sh` | | Shallow, sparse clones of rkbin, Rockchip U-Boot, rkdeveloptool, xrock, and rkflashtool, plus the Rockchip kernel's `drivers/rkflash` files, into `reference/` (gitignored). |

## `rk.py` subcommands

| Command | Talks to | What it does |
| :--- | :--- | :--- |
| `state` | sysfs only | Lists Rockchip devices and their mode (`maskrom` has no USB strings; `loader` has strings), and whether this Mask ROM enumeration has already been sent anything. |
| `build` | nothing | Encodes each stage in `STAGES` from `reference/rkbin/bin/rk30/` into `build/<name>.wire` and compares it with the stored sha256. |
| `boot --plug NAME [--ddr ddr396]` | Mask ROM | Refuses unless the device is a fresh Mask ROM. Sends the DDR stage (`0x471`), then the plug (`0x472`) via `rksend`, then waits 15 s for a loader. Exit codes: 0 loader up, 2 DDR failed, 3 plug failed, 4 nothing came back, 5 the chip reset to a fresh Mask ROM. Use `--plug plug_3032slc`. |
| `info [--storage]` | loader | Test-unit-ready, chip info, flash ID, flash info (size, block and page size), capability, and whether LBA `0x10000` returns real data or `0xCC` fill. |
| `probe` | loader | Reads LBA 0, 1, 64, 0x400, 0x800, 0xC00, 0x1000, and 0x2000 twice each. Reports stability and finds MBR/GPT/PARM/IDB. |
| `parts` | loader | Parses the GPT (or a Rockchip `PARM`). Writes `captures/partitions.json` and `captures/gpt_lba1-33.bin`. |
| `read LBA COUNT -o FILE [--verify]` | loader | Small logical reads. Real data only below LBA `0x10000`. |
| `dump (--part NAME \| --start S --count N -o FILE) [--verify]` | loader | Logical bulk read in 1 MiB steps. Resumable. Writes `FILE.sha256` with the `0xCC` fill count. Real only below LBA `0x10000`. |
| `rawdump [--start 0 --count 262144] -o FILE [--verify]` | loader | **Physical** read of the whole NAND via `READ_SECTOR`: 528 bytes per sector (512 data + 16 spare), page-major. Resumable. About 40 s per pass. Writes `FILE.sha256`. This is how backups are taken. |
| `log [-n N]` | nothing | Last N entries of `logs/rk_log.jsonl`. |

## `rk_restore.py` subcommands

| Command | Talks to | What it does |
| :--- | :--- | :--- |
| `plan IMAGE` | nothing | Checks IMAGE against its `.sha256` and classifies every block (boot-block, sftl-data, sftl-special, sftl-sys, erased). |
| `native IMAGE OUT` | nothing | Writes the 2048 + 64 OOB per page format for an external SPI NAND programmer. |
| `diff IMAGE [--blocks 0-1023]` | loader, reads | Reads blocks from the cabinet and lists those that differ from IMAGE. The full chip takes about 35 s. |
| `restore IMAGE --blocks LIST --approval TEXT [--pages N] [--include-boot-blocks]` | loader, **writes** | Refuses unless `PARTYCADE_ALLOW_NAND_WRITE=yes` is set, `--approval` quotes the user, you type `WRITE`, and this USB device was booted with the current `plug_3032slc_erase` wire. It checks geometry, then for each block erases, verifies FF, programs **one 4-sector page per USB command**, and verifies data plus the 8 metadata bytes before the next page. `--pages 1` stops after page 0. It refuses a count of 32 or more (the loader's `bytes>>9` progress then never matches, so it sends no status). It never writes block 1023, and blocks 0–7 need `--include-boot-blocks`. |

## Safety design

* `rk.py`'s `Loader.command()` refuses any opcode outside `READ_ONLY_OPCODES` (`0x00`, `0x01`, `0x04`, `0x14`, `0x1A`, `0x1B`, `0x2B`, `0xAA`). `0x04` is `READ_SECTOR`, a raw page read.
* `rk_restore.py`'s `Writer.write_command()` accepts only `WRITE_SECTOR 0x05` and `ERASE_NORMAL 0x06`. LBA writes, force erase, system-disk erase, reset, storage change, and eFuse are not reachable from any tool. See RECOVERY.md § 7 for why.
* `boot` uses the log, keyed by the PC's `boot_id` and the USB device number, to refuse a second download on the same Mask ROM enumeration.
* `read_lba` splits reads so no single command crosses a `0x10000`-sector boundary. With `plug_3032`, a crossing read returns stale buffer bytes past the boundary instead of `0xCC`.
* No USB reset anywhere. After a bulk error, `rk.py` sends nothing else. The old resync (a drain read plus a test-unit-ready CBW) wedged the pipe further on 2026-10-23 and must not be used after a timeout. Cold plug.
* Every tool refuses to write large files inside the repo. Images go to `~/partycade-dumps/`.

## Adding a plug or DDR blob to try

1. Check that the file exists in `reference/rkbin/bin/rk30/`.
2. Add an entry to `STAGES` in `rk.py` with `sha=None` and a `note` saying what it tests.
3. `tools/rk.py build`, then copy the printed full sha256 (`sha256sum build/<name>.wire`) into the entry, so the exact bytes you test are the ones that get recorded.
4. After the boot, update the `note` with the result, and update the plug table in STATUS.md.

## Encoding (verified against Rockchip's own code)

* RC4 with the Rockchip key `7c4e0304550509072d2c7b38170d1711`, then CRC-16/CCITT (poly `0x1021`, init `0xffff`), appended big-endian.
* DDR stages are zero-padded to a 2048-byte multiple before RC4, as Rockchip's packer does.
* Plugs are RC4'd over their exact length, as xrock does. Rockchip's packer truncates RC4 to the first 38,912 bytes of images over 64 KiB. This BootROM accepts the xrock form, and that's the only form tested.
* The wire is sent in 4096-byte control writes. A write shorter than 4096 ends the image. A wire whose length is ≡ 4095 (mod 4096) gets one padding byte. A length that's an exact multiple of 4096 is refused, because its terminator rule is untested.
