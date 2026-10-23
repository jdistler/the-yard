#!/usr/bin/env python3
"""Put a modified logical image back into a copy of a raw NAND image, in place. Offline only.

Every logical page (LPA) that differs between OLD.img and NEW.img is written over its current physical
copy (the pages sftl_rebuild.py would read), and spare bytes are left untouched. SFTL's map does not change,
so the cabinet's own SFTL reads the new bytes. Feed the result to `rk_restore.py restore --blocks <list>`.

  tools/sftl_patch.py RAW OLD.img NEW.img OUT_RAW [--part data]

OLD.img must be what `sftl_rebuild.py RAW` produces (it is checked). --part refuses any change outside that
partition (captures/partitions.json). Refuses LPAs with no current physical copy.
"""
import argparse
import hashlib
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sftl_rebuild as s  # noqa: E402

UNIT = 528


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("raw"); ap.add_argument("old"); ap.add_argument("new"); ap.add_argument("out")
    ap.add_argument("--part", help="only allow changes inside this partition")
    a = ap.parse_args()
    if os.path.realpath(a.out).startswith(os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + os.sep):
        raise SystemExit("Write raw images under ~/partycade-dumps/, not inside the repo.")
    raw = bytearray(open(a.raw, "rb").read())
    old, new = open(a.old, "rb").read(), open(a.new, "rb").read()
    if len(old) != len(new):
        raise SystemExit("OLD and NEW differ in size")
    best, _, _ = s.build_map(bytes(raw), len(old) // 512 // s.SECTORS_PER_LPA)
    lo, hi = 0, len(old) // 4096
    if a.part:
        pj = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "captures", "partitions.json")
        p = {x["name"]: x for x in json.load(open(pj))["partitions"]}[a.part]
        lo, hi = p["offset"] // 8, (p["offset"] + p["sectors"]) // 8
    changed = [l for l in range(len(old) // 4096) if old[l * 4096:(l + 1) * 4096] != new[l * 4096:(l + 1) * 4096]]
    if not changed:
        raise SystemExit("NEW is identical to OLD; nothing to do")
    outside = [l for l in changed if not lo <= l < hi]
    if outside:
        raise SystemExit(f"{len(outside)} changed LPAs outside --part {a.part}: {[hex(l) for l in outside[:8]]}")
    unmapped = [l for l in changed if l not in best]
    if unmapped:
        raise SystemExit(f"{len(unmapped)} changed LPAs have no physical copy: {[hex(l) for l in unmapped[:8]]}")
    for l in changed:
        if s.page_data(bytes(raw), best[l][1]) + s.page_data(bytes(raw), best[l][2]) != old[l * 4096:(l + 1) * 4096]:
            raise SystemExit(f"OLD.img is not the rebuild of RAW (LPA {l:#x} differs). Rebuild it first.")
    blocks = set()
    for l in changed:
        _, p0, p1 = best[l]
        for half, p in ((0, p0), (1, p1)):
            chunk = new[l * 4096 + half * 2048:l * 4096 + (half + 1) * 2048]
            for i in range(4):
                o = p * s.PAGE + i * UNIT
                raw[o:o + 512] = chunk[i * 512:(i + 1) * 512]
            blocks.add(p // s.PAGES_PER_BLOCK)
    open(a.out, "wb").write(raw)
    h = hashlib.sha256(raw).hexdigest()
    with open(a.out + ".sha256", "w") as f:
        f.write(f"{h}  {os.path.basename(a.out)}  patched from {os.path.basename(a.raw)} with {os.path.basename(a.new)}\n")
    print(f"{len(changed)} LPAs changed, in {len(blocks)} physical blocks: {','.join(map(str, sorted(blocks)))}")
    print(f"{a.out}: sha256 {h}")
    print("Check: sftl_rebuild.py OUT_RAW must reproduce NEW.img exactly before this goes anywhere near the cabinet.")


if __name__ == "__main__":
    main()
