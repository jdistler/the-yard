#!/usr/bin/env python3
"""Check that a LÖVE bundle will load on the cabinet, without the cabinet or its rootfs.

  games/love/check_abi.py games/out/love-arm

For every ELF file in the bundle:
  * it is 32-bit ARM, hard float;
  * no symbol version is newer than GLIBC_2.29 (the cabinet's glibc) or GLIBCXX_3.4.22 (its libstdc++);
  * every library it needs is in the bundle, or is on the cabinet. The cabinet's library names come from
    captures/rootfs-listing.txt (the file list of the stock rootfs), and, when tools/device_facts.py has
    been run, from captures/abi/INDEX.txt too.
Libraries SDL and OpenAL open at run time (libEGL, libGLESv2, libgbm, libdrm, libasound, libudev) are
checked against that same list.
"""
import os
import re
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RUNTIME_OPENED = ["libEGL.so.1", "libGLESv2.so.2", "libgbm.so.1", "libdrm.so.2", "libasound.so.2", "libudev.so.1"]


def cabinet_libs():
    names = set()
    listing = os.path.join(REPO, "captures", "rootfs-listing.txt")
    for line in open(listing, errors="replace"):
        m = re.search(r"/(lib[^/\s]+\.so[.\d]*)(\s|$)", line)
        if m:
            names.add(m.group(1))
    idx = os.path.join(REPO, "captures", "abi", "INDEX.txt")
    if os.path.exists(idx):
        for line in open(idx):
            names.add(os.path.basename(line.split()[0]))
    return names


def ver_tuple(v):
    return tuple(int(x) for x in v.split("."))


def main():
    bundle = sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, "games", "out", "love-arm")
    have = cabinet_libs()
    ours = set(os.listdir(os.path.join(bundle, "lib")))
    bad = 0
    for dirpath, _, files in os.walk(bundle):
        for f in sorted(files):
            p = os.path.join(dirpath, f)
            with open(p, "rb") as fh:
                if fh.read(4) != b"\x7fELF":
                    continue
            hdr = subprocess.run(["readelf", "-hA", p], capture_output=True, text=True).stdout
            dyn = subprocess.run(["readelf", "-dW", p], capture_output=True, text=True).stdout
            vers = subprocess.run(["readelf", "-VW", p], capture_output=True, text=True).stdout
            rel = os.path.relpath(p, bundle)
            problems = []
            if "ARM" not in hdr:
                problems.append("not ARM")
            # The loader goes by the ELF header's float-ABI flag; zig's linker writes no Tag_ABI_VFP_args.
            if "hard-float ABI" not in hdr and "Tag_ABI_VFP_args: VFP registers" not in hdr:
                problems.append("not hard float")
            g = sorted({v for v in re.findall(r"GLIBC_(\d+\.\d+(?:\.\d+)?)", vers)}, key=ver_tuple)
            if g and ver_tuple(g[-1]) > (2, 29):
                problems.append(f"needs GLIBC_{g[-1]}")
            x = sorted({v for v in re.findall(r"GLIBCXX_(\d+\.\d+(?:\.\d+)*)", vers)}, key=ver_tuple)
            if x and ver_tuple(x[-1]) > (3, 4, 22):
                problems.append(f"needs GLIBCXX_{x[-1]} (the cabinet has 3.4.22)")
            for need in re.findall(r"Shared library: \[(.*?)\]", dyn):
                if need not in ours and need not in have and not need.startswith(("ld-linux", "libc.so", "libm.so",
                                                                                   "libdl.so", "libpthread.so", "librt.so")):
                    problems.append(f"needs {need}, which is neither in the bundle nor on the cabinet")
            print(f"{'FAIL' if problems else 'ok  '} {rel:28} glibc {g[-1] if g else '-':6} {'; '.join(problems)}")
            bad += bool(problems)
    for lib in RUNTIME_OPENED:
        ok = lib in have or lib.split(".so")[0] + ".so" in have
        print(f"{'ok  ' if ok else 'FAIL'} opened at run time: {lib} {'is on the cabinet' if ok else 'NOT on the cabinet'}")
        bad += not ok
    print("the bundle will load" if not bad else f"{bad} problems")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
