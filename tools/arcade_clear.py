#!/usr/bin/env python3
"""Clear the arcade boards' high-score tables: every score set to a small placeholder (100 a place: 500,
400, ... 100 on a five-row board; zeros made some boards scramble their table or restore the factory one), the names left as they are (a board
that finds its table blank or malformed may restore its factory one). Encodings from games/shelf/scores.tsv.

    tools/arcade_clear.py DIR [SET ...]     DIR: a saves/arcade/mame2000 directory; default every board in the spec

Home and tools/arcade_scores.py show a zero row as empty. Writes DIR/hi/<set>.hi.bak / nvram/<set>.nv.bak first.
"""
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import arcade_scores as A  # noqa: E402


def encode(v, n, enc):
    """v as n bytes in the board's encoding (bcd: two digits a byte, high first; bcdle: low byte first; dig: one
    digit a byte)."""
    if enc.startswith("bcd"):
        digits = ("%0" + str(n * 2) + "d") % v
        b = [int(digits[i:i + 2], 16) for i in range(0, n * 2, 2)]
    else:
        digits = ("%0" + str(n) + "d") % v
        b = [int(c) for c in digits]
    return bytes(reversed(b)) if enc.endswith("le") else bytes(b)


def slate(k, s):
    """The placeholder score for row k: 100 a place, the last row 100 (a board keeps a sorted table)."""
    return (s["count"] - k) * 100 // s["mul"]


def clear(data, s):
    d = bytearray(data)
    if s["file"] == "nv4":
        # four bits a byte: the score's packed bytes are nibble pairs from the first offset
        for k in range(s["count"]):
            at = k * s["stride"] + s["soff"]
            b = encode(slate(k, s), s["slen"], s["enc"])
            for i, byte in enumerate(b):
                j = s["first"] + (at + i) * 2
                if j + 1 < len(d):
                    d[j] = (d[j] & 0xF0) | (byte >> 4)
                    d[j + 1] = (d[j + 1] & 0xF0) | (byte & 15)
        return bytes(d)
    for k in range(s["count"]):
        at = s["first"] + k * s["stride"] + s["soff"]
        b = encode(slate(k, s), s["slen"], s["enc"])
        d[at:at + len(b)] = b
    return bytes(d)


def main():
    d = sys.argv[1]
    want = set(sys.argv[2:])
    for name, s in A.spec().items():
        if want and name not in want:
            continue
        sub = "hi" if s["file"] == "hi" else "nvram"
        p = os.path.join(d, sub, name + (".hi" if s["file"] == "hi" else ".nv"))
        if not os.path.exists(p):
            continue
        if not os.path.exists(p + ".bak"):
            shutil.copy(p, p + ".bak")
        data = open(p, "rb").read()   # (read first: open(p, "wb") empties the file)
        open(p, "wb").write(clear(data, s))
        print(f"{name}: cleared ({', '.join(str(v) for v, _ in A.table(open(p, 'rb').read(), s)[:3]) or 'empty'})")


if __name__ == "__main__":
    main()
