#!/usr/bin/env python3
"""Replace the kernel's compiled-in boot logo (a sideways white "LOADING...", shown from fbdev start to stage2)
in a cabinet boot image. Written and verified 2026-10-27 (boot image sha256 de23d410...b5c3 on the cabinet).

  kernel_logo.py IMG UPRIGHT.png OUT      UPRIGHT.png: 264x40, the picture as the player sees it

The kernel (4.4.194, zImage with a gzip piggy) carries a struct linux_logo (CLUT224, 40x264, 142 colours,
found by its width and height). The logo's palette and pixels are replaced in the inflated kernel; it is
compressed again with zopfli (pigz -11: zlib -9 is 1.3 KB too big) into the same span, zero-padded, with the
gzip trailer (CRC, inflated size) at the very end, where head.S reads the inflated size (input_data_end - 4)
and where the old trailer was. lib/decompress_inflate.c stops at the end of the deflate stream and checks no
CRC, so the padding is never read. Refuses unless: inflating the new piggy as the decompressor does gives the
patched kernel, nothing outside the piggy changed, the kernel changed only in the logo, and the boot image
changed only in its kernel section and ID. Needs pigz and Pillow.
"""
import hashlib
import os
import struct
import subprocess
import sys
import tempfile
import zlib

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bootimg  # noqa: E402

BASE = 0xc0008000          # the kernel's link address: offset 0 of the inflated Image


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    src, pic, out = sys.argv[1:]
    img = open(src, "rb").read()
    h = bootimg.parse(img)
    z = h["kernel"]
    start = z.find(b"\x1f\x8b\x08\x00")
    if start < 0 or z[start + 3] != 0:
        sys.exit("no plain gzip piggy in the zImage")
    o = zlib.decompressobj(-15)
    k = bytearray(o.decompress(z[start + 10:]))
    dend = len(z) - len(o.unused_data)
    pend = dend + 8
    if struct.unpack_from("<I", z, pend - 4)[0] != len(k):
        sys.exit("the inflated size is not where expected")
    # struct linux_logo { int type; uint width, height, clutsize; const uchar *clut, *data; }, type 3 = CLUT224
    at = k.find(struct.pack("<IIII", 3, 40, 264, 142))
    if at < 0 or k.find(struct.pack("<IIII", 3, 40, 264, 142), at + 1) >= 0:
        sys.exit("the 40x264 CLUT224 logo was not found exactly once")
    _, w, hh, cs, clut, data = struct.unpack_from("<IIIIII", k, at)
    co, do = clut - BASE, data - BASE
    ours = Image.open(pic).convert("RGB")
    if ours.size != (hh, w):
        sys.exit(f"the picture must be {hh}x{w} (upright)")
    q = ours.rotate(90, expand=True).quantize(cs, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = (q.getpalette()[:3 * cs] + [0] * (3 * cs))[:3 * cs]
    kn = bytearray(k)
    kn[co:co + 3 * cs] = bytes(pal)
    kn[do:do + w * hh] = bytes(p + 32 for p in q.getdata())
    changed = [i for i in range(len(k)) if k[i] != kn[i]]
    if not all(co <= i < co + 3 * cs or do <= i < do + w * hh for i in changed):
        sys.exit("internal: changed bytes outside the logo")
    with tempfile.TemporaryDirectory() as t:
        open(os.path.join(t, "k"), "wb").write(kn)
        subprocess.check_call(["pigz", "-11", "-n", "-f", os.path.join(t, "k")])
        g = open(os.path.join(t, "k.gz"), "rb").read()
    if g[:10] != z[start:start + 10]:
        sys.exit("the new gzip header differs from the old one")
    deflate = g[10:-8]
    room = dend - (start + 10)
    if len(deflate) > room:
        sys.exit(f"compressed logo kernel is {len(deflate) - room} bytes too big")
    piggy = z[start:start + 10] + deflate + bytes(room - len(deflate)) + struct.pack("<II", zlib.crc32(kn), len(kn))
    zn = z[:start] + piggy + z[pend:]
    o = zlib.decompressobj(-15)
    checks = {
        "same zImage length": len(zn) == len(z),
        "inflates (as decompress_inflate.c) to the patched kernel": o.decompress(zn[start + 10:pend]) == bytes(kn) and o.eof,
        "inflated size word at input_data_end - 4": struct.unpack_from("<I", zn, pend - 4)[0] == len(kn),
        "nothing outside the piggy changed": zn[:start] == z[:start] and zn[pend:] == z[pend:],
    }
    new = bytearray(img)
    ps = h["page"]
    new[ps:ps + len(zn)] = zn
    nh = bootimg.parse(bytes(new))
    new[576:608] = bootimg.image_id(nh["kernel"], nh["ramdisk"], nh["second"]) + bytes(12)
    nh = bootimg.parse(bytes(new))
    checks["ramdisk and resource (dtb, U-Boot logo) unchanged"] = nh["ramdisk"] == h["ramdisk"] and nh["second"] == h["second"]
    checks["header unchanged but the ID"] = all(new[i] == img[i] for i in range(ps) if not 576 <= i < 608)
    for c, ok in checks.items():
        print(("ok   " if ok else "FAIL ") + c)
    if not all(checks.values()):
        sys.exit("refused")
    open(out, "wb").write(bytes(new))
    print(f"{out}: {len(changed)} kernel bytes changed (the logo), {room - len(deflate)} bytes of padding; "
          f"sha256 {hashlib.sha256(bytes(new)).hexdigest()}")


if __name__ == "__main__":
    main()
