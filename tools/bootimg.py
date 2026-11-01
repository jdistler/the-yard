#!/usr/bin/env python3
"""The cabinet's boot partition: an Android boot image (header v0, 2 KiB pages) with the kernel (zImage) and a
Rockchip resource image ("second": the device tree and U-Boot's logo.bmp), and no ramdisk.

  bootimg.py info IMG                         the header and its sections
  bootimg.py ramdisk IMG CPIO OUT [--size N]  IMG with CPIO as its ramdisk; everything else byte for byte,
                                              the header's ID (SHA-1) recomputed; padded to N (the partition)
  bootimg.py check ORIG NEW                   NEW is ORIG plus a ramdisk and nothing else
  bootimg.py logo IMG BMP OUT                 IMG with U-Boot's logo.bmp pixels replaced by BMP's (same header:
                                              the resource image's layout does not move); the ID recomputed
  bootimg.py logocheck ORIG NEW               NEW differs from ORIG only in logo.bmp's pixels and the ID
  bootimg.py verify IMG                       the checks U-Boot makes before starting the kernel (header ID,
                                              each resource file's hash): run it on every image before writing

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


# A resource entry (Rockchip resource_tool v2, the layout this U-Boot reads): "ENTR", name[220], hash[32],
# hash_size (u32), offset in 512-byte blocks (u32), size in bytes (u32). U-Boot checks rk-kernel.dtb against its
# hash ("HASH: OK(s)"; a stale one is "Get a bad hash of DTB !" and no boot: the 2026-10-27 SD-slot image).
ENTRY_NAME, ENTRY_HASH, ENTRY_HASH_SIZE, ENTRY_OFFSET = 4, 224, 256, 260


def resource_table(res):
    """[(entry byte offset in res, name, file offset, size, hash_size, stored hash)]."""
    if res[:4] != b"RSCE":
        raise SystemExit("the second section is not a resource image")
    tbl, esz, n = res[9], res[10], struct.unpack_from("<I", res, 12)[0]   # RSCE, versions, sizes, count
    out = []
    for i in range(n):
        at = (tbl + i * esz) * 512
        e = res[at:at + 512]
        if e[:4] != b"ENTR":
            raise SystemExit(f"resource entry {i}: not ENTR")
        name = e[ENTRY_NAME:ENTRY_HASH].split(b"\0")[0].decode()
        hs = struct.unpack_from("<I", e, ENTRY_HASH_SIZE)[0]
        off, size = struct.unpack_from("<II", e, ENTRY_OFFSET)
        out.append((at, name, off * 512, size, hs, e[ENTRY_HASH:ENTRY_HASH + hs]))
    return out


def resource_entries(res):
    """The Rockchip resource image (RSCE): {name: (offset, size)} in bytes."""
    return {name: (off, size) for _, name, off, size, _, _ in resource_table(res)}


def file_hash(data, size):
    if size == 20:
        return hashlib.sha1(data).digest()
    if size == 32:
        return hashlib.sha256(data).digest()
    raise SystemExit(f"resource hash of {size} bytes: unknown kind")


def second_offset(h):
    ps = h["page"]
    return ps + (h["ksz"] + ps - 1) // ps * ps + (h["rsz"] + ps - 1) // ps * ps


def seal(img):
    """IMG (bytes) with every resource entry's hash and the header ID made to match the contents: the last step
    of any change to the boot image (a DTB or logo edit)."""
    out = bytearray(img)
    h = parse(img)
    soff = second_offset(h)
    for at, name, off, size, hs, _ in resource_table(h["second"]):
        if hs:
            out[soff + at + ENTRY_HASH:soff + at + ENTRY_HASH + hs] = file_hash(h["second"][off:off + size], hs)
    nh = parse(bytes(out))
    out[576:608] = image_id(nh["kernel"], nh["ramdisk"], nh["second"]) + b"\0" * 12
    return bytes(out)


def verify(img):
    """The checks U-Boot makes before it starts the kernel, as {description: ok}."""
    h = parse(img)
    checks = {"header ID matches kernel, ramdisk and second": h["id"][:20] == image_id(h["kernel"], h["ramdisk"], h["second"])}
    for _, name, off, size, hs, stored in resource_table(h["second"]):
        data = h["second"][off:off + size]
        if hs:
            checks[f"{name}: hash matches ({hs * 8} bits)"] = stored == file_hash(data, hs)
        if name.endswith(".dtb"):
            checks[f"{name}: device tree header and size"] = (data[:4] == b"\xd0\x0d\xfe\xed"
                                                              and struct.unpack(">I", data[4:8])[0] <= size)
    return checks


def logo_pixels(bmp):
    """(header, pixel bytes) of an uncompressed 24-bit BMP."""
    if bmp[:2] != b"BM":
        raise SystemExit("not a BMP")
    data_off, w, h, planes, bpp, comp = struct.unpack_from("<I", bmp, 10)[0], *struct.unpack_from("<iiHHI", bmp, 18)
    if bpp != 24 or comp != 0:
        raise SystemExit(f"logo: {bpp} bpp, compression {comp}: only 24-bit uncompressed")
    row = (w * 3 + 3) // 4 * 4
    return bmp[:data_off], data_off, row * abs(h)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("info"); p.add_argument("img")
    p = sub.add_parser("ramdisk"); p.add_argument("img"); p.add_argument("cpio"); p.add_argument("out")
    p.add_argument("--size", type=int, default=PART)
    p = sub.add_parser("check"); p.add_argument("orig"); p.add_argument("new")
    p = sub.add_parser("logo"); p.add_argument("img"); p.add_argument("bmp"); p.add_argument("out")
    p = sub.add_parser("logocheck"); p.add_argument("orig"); p.add_argument("new")
    p = sub.add_parser("verify"); p.add_argument("img")
    a = ap.parse_args()
    if a.cmd == "verify":
        checks = verify(open(a.img, "rb").read())
        for k, v in checks.items():
            print(("ok   " if v else "FAIL ") + k)
        sys.exit(0 if all(checks.values()) else 1)
    if a.cmd in ("logo", "logocheck"):
        d = open(a.img if a.cmd == "logo" else a.orig, "rb").read()
        h = parse(d)
        ps = h["page"]
        soff = ps + (h["ksz"] + ps - 1) // ps * ps + (h["rsz"] + ps - 1) // ps * ps
        loff, lsize = resource_entries(h["second"])["logo.bmp"]
        old = h["second"][loff:loff + lsize]
        ohdr, odata, olen = logo_pixels(old)
        if a.cmd == "logo":
            new = open(a.bmp, "rb").read()
            nhdr, ndata, nlen = logo_pixels(new)
            if nhdr != ohdr or nlen != olen:
                raise SystemExit("the new logo's header differs from the stock one (size, depth, layout): refused")
            out = bytearray(d)
            start = soff + loff + odata
            out[start:start + olen] = new[ndata:ndata + nlen]
            out = seal(bytes(out))
            open(a.out, "wb").write(out)
            print(f"{a.out}: logo.bmp pixels replaced ({olen} bytes at {start}), hashes and id recomputed")
            return
        nd = open(a.new, "rb").read()
        n = parse(nd)
        lo, hi = soff + loff + odata, soff + loff + odata + olen
        diff = [i for i in range(len(d)) if d[i] != nd[i]] if len(d) == len(nd) else None
        checks = {
            "same length": diff is not None,
            "only the logo's pixels and the id differ": diff is not None and all(lo <= i < hi or 576 <= i < 608 for i in diff),
            "kernel and ramdisk identical": h["kernel"] == n["kernel"] and h["ramdisk"] == n["ramdisk"],
            "the device tree identical": resource_entries(n["second"])["rk-kernel.dtb"] == resource_entries(h["second"])["rk-kernel.dtb"]
                                          and n["second"][:loff] == h["second"][:loff],
            "id matches the new sections": n["id"][:20] == image_id(n["kernel"], n["ramdisk"], n["second"]),
        }
        for k, v in checks.items():
            print(("ok   " if v else "FAIL ") + k)
        print(f"{len(diff or [])} bytes differ")
        sys.exit(0 if all(checks.values()) else 1)
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
