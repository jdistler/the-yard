#!/usr/bin/env python3
"""Bricked-cabinet recovery from a raw NAND backup (see RECOVERY.md).

  plan    IMAGE          offline: check the backup, list what a full restore would erase and program
  native  IMAGE OUT      offline: convert to the chip's own page format (2048 data + 64 OOB) for an
                         external SPI NAND programmer
  diff    IMAGE          read-only, live: compare the cabinet's NAND with the backup, block by block
  restore IMAGE ...      WRITES THE CABINET. Locked; see RECOVERY.md before even reading this code path.

IMAGE is a `rk.py rawdump` file: 262144 physical sectors x 528 bytes (512 data + 16 spare), page-major.
rk.py stays read-only; the only erase/program code in the project is in this file.
"""
import argparse
import hashlib
import os
import struct
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rk  # noqa: E402

UNIT = rk.RAW_UNIT                     # 528
BLOCK_SECTORS = 256                    # 64 pages x 4 sectors
BLOCKS = rk.RAW_SECTORS // BLOCK_SECTORS
BLOCK_BYTES = BLOCK_SECTORS * UNIT
ERASED = b"\xff" * BLOCK_BYTES
SKIP_BLOCKS = {1023}                   # page 0 all 0x00 (data+spare), rest erased: likely a bad-block mark

WRITE_SECTOR, ERASE_NORMAL = 0x05, 0x06
WRITE_CHUNK = 4                        # one NAND page, and below the loader's count bug
CSW_TIMEOUT_MS = 120000                # a real page program returns in milliseconds; this only
                                           # covers a slow busy poll. The 32-sector hang was not that.
APPROVAL_ENV = "PARTYCADE_ALLOW_NAND_WRITE"


def load_image(path):
    raw = open(path, "rb").read()
    if len(raw) != rk.RAW_SECTORS * UNIT:
        raise SystemExit(f"{path}: {len(raw)} bytes, expected {rk.RAW_SECTORS * UNIT} (a full rawdump)")
    h = hashlib.sha256(raw).hexdigest()
    side = path + ".sha256"
    if not os.path.exists(side):
        raise SystemExit(f"{side} missing: refusing an image whose provenance is not recorded")
    want = open(side).read().split()[0]
    if want != h:
        raise SystemExit(f"{path}: sha256 {h} does not match {side} ({want}). The backup is damaged.")
    return raw, h


def block(raw, b):
    return raw[b * BLOCK_BYTES:(b + 1) * BLOCK_BYTES]


def parse_blocks(spec):
    out = []
    for part in spec.split(","):
        lo, _, hi = part.partition("-")
        out += range(int(lo, 0), int(hi or lo, 0) + 1)
    bad = [b for b in out if not 0 <= b < BLOCKS]
    if bad:
        raise SystemExit(f"block numbers out of range: {bad}")
    return out


def page_meaningful(page):
    """Bytes that are flash content: the 2048 data bytes plus the 8-byte Rockchip spare.

    The other 8 bytes of sector 0's spare, and all 16 spare bytes of the other three
    sectors, come back as the same bit pattern on every page of every block, including
    blocks that were never written. The backup stored 0xFF there. That pattern is not
    flash content and must not be compared or treated as a failed erase.
    """
    out = bytearray()
    for i in range(4):
        base = i * UNIT
        out += page[base:base + 512]
        if i == 0:
            out += page[base + 512:base + 520]
    return bytes(out)


def block_meaningful(buf):
    return b"".join(page_meaningful(buf[p * 4 * UNIT:(p + 1) * 4 * UNIT]) for p in range(64))


def first_spare(blk_bytes):
    for n in range(64):
        page = blk_bytes[n * 4 * UNIT:(n + 1) * 4 * UNIT]
        if page != b"\xff" * len(page):
            return page[512:520]
    return None


def describe(raw, b, blk_bytes=None):
    """Label a block by its pair's first programmed page (the even block carries the page type)."""
    blk_bytes = block(raw, b) if blk_bytes is None else blk_bytes
    if blk_bytes == ERASED:
        return "erased"
    if blk_bytes.count(0) == len(blk_bytes):
        return "all-zero"
    if b < 8:
        return "boot-block"
    even = first_spare(block(raw, b & ~1)) or b"\xff" * 8
    odd = first_spare(block(raw, b | 1)) or b"\xff" * 8
    tag = struct.unpack("<H", even[:2])[0]
    if struct.unpack("<I", odd[:4])[0] == 0xFFFFFFFD:
        return "sftl-special"
    return {0xF095: "sftl-data", 0xF086: "sftl-sys", 0xF0A4: "sftl-sys", 0xF0C2: "sftl-sys",
            0xF0D1: "sftl-sys", 0xF0E0: "sftl-sys"}.get(tag, "other")


def cmd_plan(a):
    raw, h = load_image(a.image)
    kinds = {}
    for b in range(BLOCKS):
        kinds.setdefault(describe(raw, b), []).append(b)
    print(f"{a.image}: sha256 {h} (matches its .sha256)")
    for k, bl in sorted(kinds.items(), key=lambda kv: -len(kv[1])):
        print(f"  {len(bl):4d} blocks {k:13s} e.g. {bl[:8]}")
    prog = [b for b in range(BLOCKS) if b not in SKIP_BLOCKS and block(raw, b) != ERASED]
    print(f"Full restore: erase {BLOCKS - len(SKIP_BLOCKS)} blocks, program {len(prog)} of them, skip {sorted(SKIP_BLOCKS)}.")
    print("Prefer `diff` first and restore only the blocks that differ.")


def cmd_native(a):
    """2112-byte native pages: data, then OOB with BBM 0xFFFF, Rockchip spare words at +0x04 and +0x14."""
    raw, _ = load_image(a.image)
    if os.path.realpath(a.out).startswith(rk.ROOT + os.sep):
        raise SystemExit("Write native images under ~/partycade-dumps/, not inside the repo.")
    with open(a.out, "wb") as f:
        for p in range(rk.RAW_SECTORS // 4):
            pg = raw[p * 4 * UNIT:(p + 1) * 4 * UNIT]
            data = b"".join(pg[i * UNIT:i * UNIT + 512] for i in range(4))
            spare = pg[512:528]
            oob = bytearray(b"\xff" * 64)
            oob[0x04:0x08] = spare[0:4]
            oob[0x14:0x18] = spare[4:8]
            f.write(data + bytes(oob))
    print(f"{a.out}: {os.path.getsize(a.out)} bytes; sha256 {hashlib.sha256(open(a.out, 'rb').read()).hexdigest()}")
    print("Program with on-die ECC ENABLED (the chip fills OOB ECC bytes). Skip block 1023. See RECOVERY.md.")


def cmd_diff(a):
    raw, h = load_image(a.image)
    blocks = parse_blocks(a.blocks)
    L = rk.Loader()
    differ = []
    t0 = time.time()
    try:
        for i, b in enumerate(blocks):
            live = L.read_raw(b * BLOCK_SECTORS, BLOCK_SECTORS)
            want = block(raw, b)
            if block_meaningful(live) != block_meaningful(want):
                differ.append(b)
                pages = sorted({p for p in range(64)
                                if page_meaningful(live[p * 4 * UNIT:(p + 1) * 4 * UNIT])
                                != page_meaningful(want[p * 4 * UNIT:(p + 1) * 4 * UNIT])})
                print(f"\nblock {b}: differs ({describe(raw, b)} in backup, {describe(raw, b, live)} live), "
                      f"pages {pages[:12]}{'...' if len(pages) > 12 else ''}")
            print(f"\r{i + 1}/{len(blocks)} blocks, {len(differ)} differ, {time.time() - t0:.0f}s", end="", flush=True)
    finally:
        L.close()
    print()
    rk.log("restore_diff", devnum=L.devnum, image_sha256=h, blocks=a.blocks, differ=differ)
    print(f"Differing blocks: {differ if differ else 'none: the cabinet matches the backup'}")


class Writer(rk.Loader):
    """The only code that can erase or program the cabinet's NAND."""

    def write_command(self, op, lba, count, payload=b""):
        if op not in (WRITE_SECTOR, ERASE_NORMAL):
            raise SystemExit(f"opcode {op:#x} not allowed")
        if op == WRITE_SECTOR and not 1 <= count < 32:
            raise SystemExit(
                f"WRITE_SECTOR count {count} refused. At 32 sectors the loader's progress "
                "(payload bytes >> 9) becomes 33, so it never sends status and swallows the next command."
            )
        tag = int.from_bytes(os.urandom(4), "little")
        cdb = struct.pack(">BBIBH7x", op, 0, lba, 0, count)
        cbw = struct.pack("<IIIBBB", 0x43425355, tag, len(payload), 0x00, 0, 10) + cdb
        try:
            self.dev.write(rk.EP_OUT, cbw, timeout=3000)
            if payload:
                self.dev.write(rk.EP_OUT, payload, timeout=10000)
            csw = bytes(self.dev.read(rk.EP_IN, 13, timeout=CSW_TIMEOUT_MS))
        except self.usb.core.USBError as e:
            raise SystemExit(
                f"USB error on opcode {op:#x} lba {lba:#x} count {count}: {e}. "
                "No retry and no resync. Cold plug before any further command."
            )
        sig, ctag, _, status = struct.unpack("<IIIB", csw)
        if sig != 0x53425355 or ctag != tag:
            raise SystemExit(f"CSW mismatch on opcode {op:#x}; STOP and record everything.")
        return status

    def erase_block(self, b):
        return self.write_command(ERASE_NORMAL, b, 1)

    def program_block(self, b, data, pages=None):
        limit = BLOCK_SECTORS if pages is None else pages * WRITE_CHUNK
        for s in range(0, limit, WRITE_CHUNK):
            chunk = data[s * UNIT:(s + WRITE_CHUNK) * UNIT]
            if chunk == b"\xff" * len(chunk):
                continue
            st = self.write_command(WRITE_SECTOR, b * BLOCK_SECTORS + s, WRITE_CHUNK, chunk)
            if st:
                return st
            live = self.read_raw(b * BLOCK_SECTORS + s, WRITE_CHUNK)
            if page_meaningful(live) != page_meaningful(chunk):
                raise SystemExit(
                    f"block {b} sector {s}: page read-back mismatch. STOP. No further page was sent."
                )
            print(f"  block {b} page {s // WRITE_CHUNK}: verified")
        return 0


def cmd_restore(a):
    if os.environ.get(APPROVAL_ENV) != "yes":
        raise SystemExit(f"Locked. Writing needs {APPROVAL_ENV}=yes, --approval, and a block list. Read RECOVERY.md.")
    if not a.approval or len(a.approval) < 20:
        raise SystemExit("--approval must quote the user's written go-ahead (who, when, which blocks).")
    if a.pages is not None and not 1 <= a.pages <= 64:
        raise SystemExit("--pages must be from 1 to 64")
    raw, h = load_image(a.image)
    blocks = parse_blocks(a.blocks)
    if SKIP_BLOCKS & set(blocks):
        raise SystemExit(f"blocks {sorted(SKIP_BLOCKS & set(blocks))} are never written")
    if any(b < 8 for b in blocks) and not a.include_boot_blocks:
        raise SystemExit("Blocks 0-7 hold the boot block (IDB); add --include-boot-blocks only if RECOVERY.md says so.")
    W = Writer()
    info = rk.decode_flash_info(W.command(rk.OP["READ_FLASH_INFO"], 11)[0])
    if info["block_sectors"] != BLOCK_SECTORS or info["page_sectors"] != 4:
        W.close()
        raise SystemExit(f"Loader reports geometry {info}; this tool assumes 256-sector blocks of 4-sector pages.")
    plug = [e for e in rk.log_entries() if e["action"] == "loader_up" and e.get("devnum") == W.devnum]
    want_sha = rk.STAGES["plug_3032slc_erase"]["sha"]
    if not plug or plug[-1].get("plug") != "plug_3032slc_erase" or plug[-1].get("sha") != want_sha:
        W.close()
        raise SystemExit(
            "Refusing to write. This USB device was not booted with the current plug_3032slc_erase wire. "
            "Cold plug, then `rk.py boot --ddr ddr396 --plug plug_3032slc_erase`."
        )
    page_note = f", first {a.pages} page(s) only" if a.pages else ""
    print(f"About to ERASE and PROGRAM {len(blocks)} block(s) {a.blocks}{page_note} from {a.image} (sha256 {h}).")
    if input("Type WRITE to continue: ") != "WRITE":
        W.close()
        raise SystemExit("Not confirmed; nothing written.")
    rk.log("restore_start", devnum=W.devnum, image_sha256=h, blocks=a.blocks, approval=a.approval)
    try:
        for b in blocks:
            want = block(raw, b)
            st = W.erase_block(b)
            if st:
                raise SystemExit(f"block {b}: erase status {st} (bad block?). STOP.")
            blank = W.read_raw(b * BLOCK_SECTORS, BLOCK_SECTORS)
            if block_meaningful(blank) != b"\xff" * len(block_meaningful(blank)):
                raise SystemExit(f"block {b}: data or spare metadata not 0xFF after erase. STOP.")
            if want != ERASED:
                st = W.program_block(b, want, a.pages)
                if st:
                    raise SystemExit(f"block {b}: program status {st}. STOP.")
            got = W.read_raw(b * BLOCK_SECTORS, BLOCK_SECTORS)
            if a.pages:
                for p in range(a.pages):
                    sl = slice(p * 4 * UNIT, (p + 1) * 4 * UNIT)
                    if page_meaningful(got[sl]) != page_meaningful(want[sl]):
                        raise SystemExit(
                            f"block {b} page {p}: read-back differs from backup. STOP; erase before any retry."
                        )
                rk.log("restore_pages", devnum=W.devnum, block=b, pages=a.pages, ok=True)
                print(f"block {b}: first {a.pages} page(s) verified. The rest of the block is still erased.")
                continue
            if block_meaningful(got) != block_meaningful(want):
                raise SystemExit(f"block {b}: read-back differs from backup. STOP; do not power off, record it.")
            rk.log("restore_block", devnum=W.devnum, block=b, ok=True)
            print(f"block {b}: restored and verified")
    finally:
        W.close()
    print("Done. Do not issue LBA writes with this plug; cold plug and run `rk_restore.py diff` again.")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("plan"); s.add_argument("image"); s.set_defaults(f=cmd_plan)
    s = sub.add_parser("native"); s.add_argument("image"); s.add_argument("out"); s.set_defaults(f=cmd_native)
    s = sub.add_parser("diff"); s.add_argument("image")
    s.add_argument("--blocks", default=f"0-{BLOCKS - 1}", help="e.g. 0-7,16,970-1023 (default all)")
    s.set_defaults(f=cmd_diff)
    s = sub.add_parser("restore"); s.add_argument("image")
    s.add_argument("--blocks", required=True); s.add_argument("--approval")
    s.add_argument("--pages", type=int, help="program only the first N pages of each block, then stop")
    s.add_argument("--include-boot-blocks", action="store_true")
    s.set_defaults(f=cmd_restore)
    a = p.parse_args()
    a.f(a)


if __name__ == "__main__":
    main()
