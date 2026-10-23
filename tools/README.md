# tools/

| File | What it is |
| :--- | :--- |
| `rk.py` | The one tool to use. Read-only USB access to the cabinet: state, boot, info, probe, parts, read, dump, log. |
| `rksend.c` | C sender for the Mask ROM download stages, called by `rk.py boot`. It uses asynchronous libusb control transfers so every 4096-byte chunk reports `actual_length` and status, and it stops at the first short or failed chunk. |
| `Makefile` | `make -C tools` builds `rksend`. The header is in `inc/libusb.h` (libusb 1.0.27), so no `-dev` package is needed. |
| `fetch_references.sh` | Shallow, sparse clones of rkbin, Rockchip U-Boot, rkdeveloptool, xrock, and rkflashtool into `reference/` (gitignored). Prints each commit. |

## `rk.py` subcommands

| Command | Talks to | What it does |
| :--- | :--- | :--- |
| `state` | sysfs only | Lists Rockchip devices and their mode (`maskrom` has no USB strings; `loader` has strings), and whether this Mask ROM enumeration has already been sent anything. |
| `build` | nothing | Encodes each stage in `STAGES` from `reference/rkbin/bin/rk30/` into `build/<name>.wire` and compares it with the stored sha256. |
| `boot --plug NAME [--ddr ddr396]` | Mask ROM | Refuses unless the device is a fresh Mask ROM. Sends the DDR stage (`0x471`), then the plug (`0x472`) via `rksend`, then waits 15 s for a loader. Exit codes: 0 loader up, 2 DDR failed, 3 plug failed, 4 nothing came back, 5 the chip reset to a fresh Mask ROM. |
| `info [--storage]` | loader | Test-unit-ready, chip info, flash ID, flash info (size), capability, and a check of whether LBA `0x10000` returns real data or `0xCC` fill. `--storage` adds READ_STORAGE, which these plugs reject. |
| `probe` | loader | Reads LBA 0, 1, 64, 0x400, 0x800, 0xC00, 0x1000, and 0x2000 twice each. Reports stability and finds MBR/GPT/PARM/IDB. |
| `parts` | loader | Parses the GPT (or a Rockchip `PARM`). Writes `captures/partitions.json` and `captures/gpt_lba1-33.bin`. |
| `read LBA COUNT -o FILE [--verify]` | loader | Small reads. Refuses more than 1 MiB inside the repo. |
| `dump (--part NAME | --start S --count N -o FILE) [--verify]` | loader | Bulk read in 1 MiB steps. Resumable (re-run the same command). `--verify` reads every MiB twice. Writes `FILE.sha256` with the fill-sector count and which plug served it. |
| `log [-n N]` | nothing | Last N entries of `logs/rk_log.jsonl`. |

## Safety design

* `Loader.command()` refuses any opcode outside `READ_ONLY_OPCODES` (`0x00`, `0x01`, `0x14`, `0x1A`, `0x1B`, `0x2B`, `0xAA`). Write (`0x15`), erase (`0x06`, `0x0B`, `0x16`, `0x25`), reset (`0xFF`), set-reset-flag (`0x1E`), storage change (`0x2A`), and SDRAM write/execute (`0x18`, `0x19`) are not reachable.
* `boot` uses the log, keyed by the PC's `boot_id` and the USB device number, to refuse a second download on the same Mask ROM enumeration.
* `read_lba` splits reads so no single command crosses a `0x10000`-sector boundary. With `plug_3032`, a crossing read returns stale buffer bytes past the boundary instead of `0xCC`, which would slip past the fill check.
* No USB reset anywhere. After a bulk error on a loader, `rk.py` does one drain read plus test-unit-ready to resync, then stops.

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
