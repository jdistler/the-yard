#!/usr/bin/env python3
"""Rebuild the SFTL logical disk from a raw NAND image made by `rk.py rawdump`.

Offline only; never touches the hardware.

Raw image format: 65536 pages x 2112 bytes; each page is 4 x (512 data + 16 spare).
SFTL layout found on this cabinet (2026-10-23, Winbond W25N01GV, SFTL 5.0.55):
  * A logical page (LPA) is 4 KiB = 8 sectors.
  * It is stored as page n of an even block 2k (first 2 KiB) plus page n of block 2k+1 (second 2 KiB).
  * The spare of the odd-block half (first 16 bytes) holds u32 LPA at +0. Its u32 at +4 is NOT a write
    order (picking by it chose stale copies; ext2 in `data` then failed e2fsck).
  * The spare of the even-block half holds u16 page type at +0 (0xF095 = user data; 0xF086/0xF0A4/0xF0C2
    = SFTL system pages, which reuse small numbers in the LPA field), u16 block-pair index at +2, and
    u32 global write sequence at +4 (increments by one per programmed page).
  * For each LPA, the data copy with the highest even-half sequence is current.

Usage:
  tools/sftl_rebuild.py RAW OUT.img [--sectors 220672] [--check LOGICAL.img --check-sectors 0x10000]
  tools/sftl_rebuild.py RAW --where rootfs          # physical blocks holding a partition's current data
  tools/sftl_rebuild.py RAW --where 0x2c00:0x20000  # same, for a logical sector range START:COUNT
"""
import argparse
import collections
import hashlib
import json
import os
import struct

PAGE = 2112
PAGES_PER_BLOCK = 64
SECTORS_PER_LPA = 8


def page_data(raw, p):
    b = raw[p * PAGE:(p + 1) * PAGE]
    return b"".join(b[i * 528:i * 528 + 512] for i in range(4))


def spare0(raw, p):
    o = p * PAGE + 512
    return raw[o:o + 16]


DATA_TAG = 0xF095


def build_map(raw, max_lpa):
    pages = len(raw) // PAGE
    best = {}
    types = {}
    skipped = 0
    for blk in range(0, pages // PAGES_PER_BLOCK - 1, 2):
        for n in range(PAGES_PER_BLOCK):
            p0 = blk * PAGES_PER_BLOCK + n
            p1 = p0 + PAGES_PER_BLOCK
            s = spare0(raw, p1)
            if s[:8] == b"\xff" * 8:
                continue
            tag, pair, seq = struct.unpack("<HHI", spare0(raw, p0)[:8])
            types[tag] = types.get(tag, 0) + 1
            if tag != DATA_TAG or pair != blk // 2:
                continue
            lpa = struct.unpack("<I", s[:4])[0]
            if lpa >= max_lpa:
                skipped += 1
                continue
            if lpa not in best or seq > best[lpa][0]:
                best[lpa] = (seq, p0, p1)
    return best, skipped, types


def where(best, spec):
    if ":" in spec:
        start, count = (int(x, 0) for x in spec.split(":"))
    else:
        pj = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "captures", "partitions.json")
        parts = {p["name"]: p for p in json.load(open(pj))["partitions"]}
        start, count = parts[spec]["offset"], parts[spec]["sectors"]
    lo, hi = start // SECTORS_PER_LPA, (start + count + SECTORS_PER_LPA - 1) // SECTORS_PER_LPA
    blocks = collections.Counter()
    for lpa in range(lo, hi):
        if lpa in best:
            blocks[best[lpa][1] // PAGES_PER_BLOCK] += 1
    owned = {b for b in blocks if all(lo <= l < hi for l, v in best.items() if v[1] // PAGES_PER_BLOCK == b)}
    print(f"{spec}: LPAs {lo:#x}-{hi - 1:#x}, {sum(blocks.values())} mapped, in {len(blocks)} block pairs")
    print("pairs (even block: current pages; * = every current page in the pair belongs to this range):")
    print(" ".join(f"{b}{'*' if b in owned else ''}:{n}" for b, n in sorted(blocks.items())))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("raw")
    ap.add_argument("out", nargs="?")
    ap.add_argument("--sectors", type=lambda x: int(x, 0), default=220672)
    ap.add_argument("--check", help="known-good logical image to compare against")
    ap.add_argument("--check-sectors", type=lambda x: int(x, 0), default=0x10000)
    ap.add_argument("--fill", type=lambda x: int(x, 0), default=0x00, help="byte for unmapped LPAs")
    ap.add_argument("--where", help="partition name from captures/partitions.json, or START:COUNT in sectors")
    a = ap.parse_args()
    if not a.out and not a.where:
        ap.error("give OUT.img, --where, or both")

    raw = open(a.raw, "rb").read()
    max_lpa = a.sectors // SECTORS_PER_LPA
    best, skipped, types = build_map(raw, max_lpa)
    if a.where:
        where(best, a.where)
    if not a.out:
        return
    print("page types (even-half spare u16):", {hex(k): v for k, v in sorted(types.items())})
    out = bytearray(bytes([a.fill]) * (a.sectors * 512))
    for lpa, (seq, p0, p1) in best.items():
        o = lpa * 4096
        out[o:o + 2048] = page_data(raw, p0)
        out[o + 2048:o + 4096] = page_data(raw, p1)
    open(a.out, "wb").write(out)
    print(f"mapped LPAs: {len(best)} of {max_lpa} ({len(best) * 4096 / 2**20:.1f} MiB); "
          f"data pages with LPA out of range: {skipped}")
    print(f"{a.out}: sha256 {hashlib.sha256(out).hexdigest()}")

    if a.check:
        ref = open(a.check, "rb").read()[:a.check_sectors * 512]
        mine = bytes(out[:a.check_sectors * 512])
        bad = [s for s in range(a.check_sectors) if mine[s * 512:(s + 1) * 512] != ref[s * 512:(s + 1) * 512]]
        print(f"check vs {a.check} over {a.check_sectors:#x} sectors: {len(bad)} sectors differ")
        if bad:
            runs, start = [], bad[0]
            for x, y in zip(bad, bad[1:] + [None]):
                if y != x + 1:
                    runs.append((start, x)); start = y
            for s, e in runs[:20]:
                print(f"  differ LBA {s:#x}-{e:#x} ref={ref[s*512:s*512+8].hex()} mine={mine[s*512:s*512+8].hex()}")


if __name__ == "__main__":
    main()
