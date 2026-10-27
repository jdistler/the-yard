#!/usr/bin/env python3
"""mkinitramfs.py INIT OUT: a newc cpio with /init (INIT), /dev, /dev/console, /newroot. Uncompressed (it is
~4 KB; the boot partition has 14 KB free). Fixed times and owners, so the same INIT gives the same bytes."""
import sys

def entry(name, mode, data=b"", rdev=(0, 0), ino=[1]):
    ino[0] += 1
    hdr = "070701" + "".join("%08X" % v for v in (
        ino[0], mode, 0, 0, 1, 0, len(data), 0, 0, rdev[0], rdev[1], len(name) + 1, 0))
    out = hdr.encode() + name.encode() + b"\0"
    out += b"\0" * (-len(out) % 4)
    out += data + b"\0" * (-len(data) % 4)
    return out

init = open(sys.argv[1], "rb").read()
blob = (entry("dev", 0o40755) + entry("dev/console", 0o20600, rdev=(5, 1)) + entry("newroot", 0o40755) +
        entry("init", 0o100755, init) + entry("TRAILER!!!", 0))
blob += b"\0" * (-len(blob) % 512)
open(sys.argv[2], "wb").write(blob)
print(f"{sys.argv[2]}: {len(blob)} bytes")
