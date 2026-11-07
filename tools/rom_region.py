#!/usr/bin/env python3
"""Which country each console game on the card is from, read from its header: catches a Japanese, Korean,
German or fan-translated file standing in for the English game (2026-11-07: of six Pokemon files only Red
was English). Prints one line a game; tools/shelf_check.py adds it to the report.

    tools/rom_region.py [LIBRARY]
"""
import os
import sys

LIB = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/partycade-card/library")
GBA = {"E": "USA", "P": "Europe", "J": "Japan", "D": "Germany", "F": "France", "S": "Spain", "I": "Italy", "K": "Korea"}


def region(sysid, d):
    if sysid == "gb" and len(d) > 0x150:
        title = d[0x134:0x143].split(b"\0")[0].decode("ascii", "replace")
        code = d[0x13f:0x143].decode("ascii", "replace") if d[0x143] & 0x80 else ""
        if len(code) == 4 and code.isalnum() and code[3] in GBA:
            return GBA[code[3]], title
        if not title.isascii() or not title.replace(" ", "").replace("_", "").replace("-", "").isalnum():
            return "unusual header", title
        return ("Japan" if d[0x14a] == 0 else "overseas"), title
    if sysid == "gba" and len(d) > 0xb0:
        code = d[0xac:0xb0].decode("ascii", "replace")
        return GBA.get(code[3:], "?" + code), d[0xa0:0xac].decode("ascii", "replace").strip("\0")
    if sysid == "genesis" and len(d) > 0x200:
        reg = d[0x1f0:0x1f3].decode("ascii", "replace").strip()
        name = d[0x150:0x180].decode("ascii", "replace").strip()
        return ("Japan only" if reg in ("J",) else reg or "?"), name
    if sysid == "snes":
        best = None
        for base in (0x7fc0, 0xffc0, 0x81c0, 0x101c0):  # LoROM, HiROM (+copier header)
            if len(d) > base + 0x20:
                name = d[base:base + 21]
                if all(32 <= c < 127 for c in name):
                    best = (d[base + 0x19], name.decode().strip())
                    break
        if best:
            names = {0: "Japan", 1: "USA", 2: "Europe", 3: "Sweden", 6: "France", 8: "Spain", 9: "Germany", 13: "Korea"}
            return names.get(best[0], "region %d" % best[0]), best[1]
    return "-", ""


for line in open(os.path.join(LIB, "index.tsv")):
    if line.startswith("#"):
        continue
    f = line.split("\t")
    if f[0] in ("gb", "gba", "genesis", "snes"):
        d = open(os.path.join(LIB, f[0], f[1]), "rb").read()
        r, t = region(f[0], d)
        flag = "" if r in ("USA", "overseas", "-") or "U" in r else "   <-- check"
        print(f"{f[0]:8s} {f[1]:40s} {r:14s} {t}{flag}")
