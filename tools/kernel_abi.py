#!/usr/bin/env python3
"""How close is a kernel we built to the cabinet's? For building modules that the cabinet's kernel can load.

The cabinet's kernel (boot.img) has no embedded config and its source is a vendor fork of Rockchip's
develop-4.4. A module only works if every struct it shares with the kernel has the same layout, so we
rebuild the kernel from Rockchip's tree with the vendor's compiler (Linaro GCC 6.3-2017.05) and tune the
config until the code matches:

  symvers  BOOT.IMG OUT       every exported symbol of the cabinet kernel, as a Module.symvers for modpost
                              (all of them: .bss variables such as kmalloc_caches included)
  exports  BOOT.IMG VMLINUX   exported names only in one or the other: which features are on (IPv6, LSM, ...)
  code     BOOT.IMG VMLINUX   every exported function in both, word by word (branch targets and literal
                              addresses ignored); for those that differ, the memory offsets each one uses.
                              Same compiler and same layout give identical code, so a struct that differs
                              shows up as a cluster of functions with shifted offsets.

The verdict for games/net/wifi (2026-10-26): 7009 of 7152 functions identical; the rest are drivers the
Wi-Fi modules never touch (EHCI internals, 8250 serial, HID, Mali kbase, thermal). See BOOT_RESEARCH.md.
Needs pyelftools for 'exports' and 'code', and capstone for the offset report (pip install pyelftools capstone).
"""
import argparse, re, struct, sys, zlib
from collections import Counter

BASE = 0xc0008000          # the kernel's text starts here (load 0x10008000, PAGE_OFFSET 0xc0000000)


def cabinet_image(boot):
    raw = open(boot, "rb").read()
    return zlib.decompress(raw[raw.find(b"\x1f\x8b\x08"):], 16 + zlib.MAX_WBITS)


def cabinet_exports(img):
    """name -> address, from __ksymtab/__ksymtab_gpl: (value, name pointer) pairs whose name pointer lands
    on a NUL-separated C identifier. The table sits just before __ksymtab_strings."""
    ident = re.compile(rb"[A-Za-z_][A-Za-z0-9_]*\Z")
    # Find __ksymtab_strings around a name every kernel exports, then walk out while entries are identifiers.
    pos = img.find(b"\x00register_netdev\x00")
    lo = pos
    while True:
        p = img.rfind(b"\x00", 0, lo)
        if p < 0 or not (img[p + 1:lo] == b"" or ident.match(img[p + 1:lo])):
            break
        lo = p
    hi = pos + 1
    while True:
        n = img.find(b"\x00", hi)
        if n < 0 or not (img[hi:n] == b"" or ident.match(img[hi:n])):
            break
        hi = n + 1
    # The first string has no NUL before it (the tables end right there), so allow a little before lo.
    s_lo, s_hi = BASE + lo - 128, BASE + hi
    syms = {}
    # The tables end where the strings begin; scan back far enough for both (each entry is 8 bytes).
    start = max(0, lo - 0x20000)
    for off in range(start - start % 4, lo - 7, 4):
        val, name = struct.unpack_from("<II", img, off)
        if s_lo <= name < s_hi and 0xbf000000 <= val < 0xd0000000:
            e = img.find(b"\x00", name - BASE)
            if ident.match(img[name - BASE:e]):
                syms.setdefault(img[name - BASE:e].decode("latin1"), val)
    return syms


def elf(path):
    from elftools.elf.elffile import ELFFile
    e = ELFFile(open(path, "rb"))
    secs = [(s["sh_addr"], s.data()) for s in e.iter_sections() if s["sh_type"] == "SHT_PROGBITS" and s["sh_flags"] & 2]
    syms, exports = {}, set()
    for s in e.get_section_by_name(".symtab").iter_symbols():
        if s["st_info"]["type"] == "STT_FUNC" and s["st_size"] > 0:
            syms[s.name] = (s["st_value"], s["st_size"])
        if s.name.startswith("__ksymtab_") and s.name != "__ksymtab_strings" and not s.name.startswith("__ksymtab_gpl"):
            exports.add(s.name[len("__ksymtab_"):])

    def read(a, n):
        for b, d in secs:
            if b <= a < b + len(d):
                return d[a - b:a - b + n]
    return syms, exports, read


def same(a, b):
    if a == b:
        return True
    if (a >> 25) & 7 == 5 and (b >> 25) & 7 == 5 and a >> 24 == b >> 24:
        return True                       # b/bl with the same condition: targets differ by layout only
    return 0xbf000000 <= a < 0xc2000000 and 0xbf000000 <= b < 0xc2000000   # a literal-pool address


def offsets(code, addr):
    import capstone
    md = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_ARM)
    pat = re.compile(r"\[(r\d+|sb|sl|ip|lr), #(-?0x[0-9a-f]+|-?\d+)\]")
    return {int(m.group(2), 0) for i in md.disasm(code, addr) for m in pat.finditer(i.op_str)}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("symvers"); p.add_argument("boot"); p.add_argument("out")
    for n in ("exports", "code"):
        p = sub.add_parser(n); p.add_argument("boot"); p.add_argument("vmlinux")
    a = ap.parse_args()
    img = cabinet_image(a.boot)
    cab = cabinet_exports(img)
    if a.cmd == "symvers":
        with open(a.out, "w") as f:
            for n in sorted(cab):
                f.write(f"0x00000000\t{n}\tvmlinux\tEXPORT_SYMBOL\n")
        print(f"{len(cab)} exported symbols -> {a.out}")
        return
    syms, exports, read = elf(a.vmlinux)
    if a.cmd == "exports":
        ours = exports | {n for n in syms if n in cab and n not in exports}
        only_c, only_o = sorted(set(cab) - ours), sorted(ours - set(cab))
        print(f"cabinet {len(cab)}, ours {len(ours)}, both {len(set(cab) & ours)}")
        print(f"only in the cabinet ({len(only_c)}):", " ".join(only_c))
        print(f"only in ours ({len(only_o)}):", " ".join(only_o))
        return
    differ = []
    total = 0
    for n, ca in cab.items():
        if n not in syms:
            continue
        oa, size = syms[n]
        ob, cb = read(oa, size), img[ca - BASE:ca - BASE + size]
        if ob is None or len(cb) < size:
            continue
        total += 1
        k = size // 4
        ow, cw = struct.unpack(f"<{k}I", ob[:k * 4]), struct.unpack(f"<{k}I", cb[:k * 4])
        bad = sum(1 for x, y in zip(ow, cw) if not same(x, y))
        if bad:
            differ.append((n, bad, k, offsets(ob, oa), offsets(cb, ca)))
    print(f"{total} exported functions in both, {total - len(differ)} identical, {len(differ)} differ")
    for n, bad, k, o, c in sorted(differ, key=lambda x: -len(x[3] ^ x[4])):
        if o != c:
            print(f"  {n}: {bad}/{k} words; offsets only ours {sorted(hex(v) for v in o - c)[:6]}"
                  f" only cabinet {sorted(hex(v) for v in c - o)[:6]}")
    same_offs = [d[0] for d in differ if d[3] == d[4]]
    print(f"  ({len(same_offs)} more differ in code but use the same offsets)")


if __name__ == "__main__":
    sys.exit(main())
