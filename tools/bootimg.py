#!/usr/bin/env python3
"""The cabinet's boot partition: an Android boot image (header v0, 2 KiB pages) with the kernel (zImage) and a
Rockchip resource image ("second": the device tree and U-Boot's logo.bmp), and no ramdisk.

  bootimg.py info IMG                         the header and its sections
  bootimg.py ramdisk IMG CPIO OUT [--size N]  IMG with CPIO as its ramdisk; everything else byte for byte,
                                              the header's ID (SHA-1) recomputed; padded to N (the partition)
  bootimg.py check ORIG NEW                   NEW is ORIG plus a ramdisk and nothing else

U-Boot (2017.09, Rockchip) loads the ramdisk at ramdisk_addr_r, which env_fixup sets to ramdisk_addr1_r
(0x64000000) on boards with 128 MB or less (games/boot/README.md). Offline only.
"""
import argparse, hashlib, struct, sys

PART = 9216 * 512   # the boot partition, 4.5 MiB


def parse(d):
    if d[:8] != b"ANDROID!":
        raise SystemExit("not an Android boot image")
    f = struct.unpack_from("<10I", d, 8)
    h = dict(zip(("ksz", "kaddr", "rsz", "raddr", "ssz", "saddr", "tags", "page", "ver", "osver"), f))
    ps = h["page"]
    up = lambda n: (n + ps - 1) // ps * ps  # noqa: E731
    koff = ps
    roff = koff + up(h["ksz"])
    soff = roff + up(h["rsz"])
    h.update(kernel=d[koff:koff + h["ksz"]], ramdisk=d[roff:roff + h["rsz"]], second=d[soff:soff + h["ssz"]],
             end=soff + up(h["ssz"]), id=d[576:608], cmdline=d[64:576].split(b"\0")[0])
    return h


def image_id(k, r, s):
    x = hashlib.sha1()
    for part in (k, r, s):
        x.update(part)
        x.update(struct.pack("<I", len(part)))
    return x.digest()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("info"); p.add_argument("img")
    p = sub.add_parser("ramdisk"); p.add_argument("img"); p.add_argument("cpio"); p.add_argument("out")
    p.add_argument("--size", type=int, default=PART)
    p = sub.add_parser("check"); p.add_argument("orig"); p.add_argument("new")
    a = ap.parse_args()
    if a.cmd == "info":
        d = open(a.img, "rb").read()
        h = parse(d)
        print(f"page {h['page']} ver {h['ver']} kernel {h['ksz']} ramdisk {h['rsz']} second {h['ssz']} "
              f"cmdline {h['cmdline']!r}; image ends at {h['end']} of {len(d)}")
        ok = h["id"][:20] == image_id(h["kernel"], h["ramdisk"], h["second"])
        print(f"id {h['id'][:20].hex()} ({'matches' if ok else 'does NOT match'} the sections)")
        return
    if a.cmd == "ramdisk":
        d = open(a.img, "rb").read()
        h = parse(d)
        if h["rsz"]:
            raise SystemExit("the image already has a ramdisk")
        rd = open(a.cpio, "rb").read()
        ps = h["page"]
        pad = lambda b: b + b"\0" * (-len(b) % ps)  # noqa: E731
        hdr = bytearray(d[:ps])
        struct.pack_into("<I", hdr, 16, len(rd))                 # ramdisk_size
        hdr[576:608] = image_id(h["kernel"], rd, h["second"]) + b"\0" * 12
        out = bytes(hdr) + pad(h["kernel"]) + pad(rd) + pad(h["second"])
        if len(out) > a.size:
            raise SystemExit(f"{len(out)} bytes: does not fit the {a.size}-byte partition")
        out += b"\0" * (a.size - len(out))
        open(a.out, "wb").write(out)
        print(f"{a.out}: ramdisk {len(rd)} bytes, image {len(out)} bytes ({a.size - len(out.rstrip(bytes(1)))} spare)")
        return
    o, n = parse(open(a.orig, "rb").read()), parse(open(a.new, "rb").read())
    od, nd = open(a.orig, "rb").read(), open(a.new, "rb").read()
    hdr_diff = [i for i in range(2048) if od[i] != nd[i] and not (16 <= i < 20 or 576 <= i < 608)]
    checks = {
        "kernel identical": o["kernel"] == n["kernel"],
        "second (dtb, logo) identical": o["second"] == n["second"],
        "header identical but ramdisk size and id": not hdr_diff,
        "id matches the new sections": n["id"][:20] == image_id(n["kernel"], n["ramdisk"], n["second"]),
        "fits the partition": len(nd) <= PART,
    }
    for k, v in checks.items():
        print(("ok   " if v else "FAIL ") + k)
    sys.exit(0 if all(checks.values()) else 1)


if __name__ == "__main__":
    main()
