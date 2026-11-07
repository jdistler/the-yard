#!/usr/bin/env python3
"""Decode the arcade boards' high-score tables with games/shelf/scores.tsv.

    tools/arcade_scores.py DIR        DIR: a saves/arcade/mame2000 directory (with hi/ and nvram/)

Prints each board's table, best first. Home's shelf.lua decodes the same way (keep the two in step).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SPEC = os.path.join(os.path.dirname(HERE), "games", "shelf", "scores.tsv")


def spec():
    out = {}
    for line in open(SPEC):
        if line.startswith("#") or not line.strip():
            continue
        f = line.rstrip("\n").split("\t")
        out[f[0]] = dict(file=f[1], first=int(f[2]), stride=int(f[3]), count=int(f[4]), soff=int(f[5]),
                         slen=int(f[6]), enc=f[7], mul=int(f[8]), noff=int(f[9]), nlen=int(f[10]), chars=f[11])
    return out


def letter(b, chars):
    if chars == "ascii":
        return chr(b) if 0x41 <= b <= 0x5a or 0x61 <= b <= 0x7a or 0x30 <= b <= 0x39 or b in b"!?-'." else " "
    base = {"t0a": 0x0a, "t0b": 0x0b, "t11": 0x11}[chars]
    if base <= b < base + 26:
        return chr(ord("A") + b - base)
    if b <= 9:
        return str(b)
    return " "


def score(data, off, n, enc):
    v = 0
    rng = range(n) if not enc.endswith("le") else range(n - 1, -1, -1)
    for i in rng:
        b = data[off + i] if off + i < len(data) else 0
        if enc.startswith("bcd"):
            hi, lo = b >> 4, b & 15
            if hi > 9 or lo > 9:
                return None
            v = v * 100 + hi * 10 + lo
        else:
            v = v * 10 + (b if b <= 9 else 0)
    return v


def table(data, s):
    if s["file"] == "nv4":
        # Williams: four bits a byte. Pack the low nibbles from the first offset; offsets count packed bytes.
        raw = data[s["first"]:]
        data = bytes(((raw[i] & 15) << 4) | (raw[i + 1] & 15) for i in range(0, len(raw) - 1, 2))
        s = dict(s, first=0)
    rows = []
    for k in range(s["count"]):
        at = s["first"] + k * s["stride"]
        if at + s["stride"] > len(data) + (s["stride"] - max(s["soff"] + s["slen"], s["noff"] + s["nlen"])):
            break
        v = score(data, at + s["soff"], s["slen"], s["enc"])
        if v is None:
            continue
        name = "".join(letter(b, s["chars"]) for b in data[at + s["noff"]: at + s["noff"] + s["nlen"]]).strip() if s["nlen"] else ""
        rows.append((v * s["mul"], " ".join(name.split())))
    rows.sort(key=lambda r: -r[0])
    return rows


def main():
    d = sys.argv[1]
    for name, s in spec().items():
        p = os.path.join(d, "hi" if s["file"] == "hi" else "nvram", name + "." + ("hi" if s["file"] == "hi" else "nv"))
        if not os.path.exists(p):
            print(f"{name}: no file")
            continue
        rows = table(open(p, "rb").read(), s)
        print(f"{name}: " + ", ".join(f"{v} {n}".strip() for v, n in rows[:5]))


if __name__ == "__main__":
    main()
