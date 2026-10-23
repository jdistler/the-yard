#!/usr/bin/env python3
"""Build a patched raw NAND image with files added/changed in the `data` partition. Offline only.

  tools/data_patch.py RAW OUTDIR [--put SRC:DEST[:MODE]] [--replace DEST:OLD:NEW] [--rm DEST] ...

RAW must be a fresh `rk.py rawdump` of the cabinet (taken in the same Mask ROM session you will restore in).
DEST paths are relative to /data, e.g. Games/probe or start.sh. MODE is octal (default 755); --put files get
uid/gid 0. --replace edits a text file in place; OLD must occur exactly once; mode/uid/gid are kept.

Steps, each checked: rebuild RAW -> old.img, copy the data partition, e2fsck it, apply the edits with debugfs,
read every edit back, e2fsck again, sftl_patch.py --part data, rebuild the patched raw and require it to equal
new.img byte for byte. Prints the block list and the rk_restore.py command. Nothing here touches the cabinet.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys

TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(TOOLS)
DEBUGFS = shutil.which("debugfs") or "/sbin/debugfs"
E2FSCK = shutil.which("e2fsck") or "/sbin/e2fsck"


def run(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if r.returncode:
        raise SystemExit(f"FAILED: {' '.join(cmd)}\n{r.stdout}{r.stderr}")
    return r.stdout + r.stderr


def debugfs(img, req, write=False):
    out = run([DEBUGFS] + (["-w"] if write else []) + ["-R", req, img])
    lines = [l for l in out.splitlines() if not l.startswith("debugfs ")]
    return "\n".join(lines)


def fsck(img, label):
    r = subprocess.run([E2FSCK, "-fn", img], capture_output=True, text=True)
    if r.returncode:
        raise SystemExit(f"e2fsck on {label} reports problems (exit {r.returncode}):\n{r.stdout}{r.stderr}")
    print(f"  e2fsck {label}: clean")


def stat(img, path):
    out = debugfs(img, f'stat "/{path}"')
    m = re.search(r"Mode:\s+(\d+)", out)
    u = re.search(r"User:\s+(\d+)\s+Group:\s+(\d+)", out)
    t = re.search(r"Type:\s+(\w+)", out)
    if not (m and u and t):
        return None
    return {"type": t.group(1), "mode": int(m.group(1), 8), "uid": int(u.group(1)), "gid": int(u.group(2))}


def cat(img, path, tmp):
    run([DEBUGFS, "-R", f'dump "/{path}" {tmp}', img])
    return open(tmp, "rb").read()


def put(img, data_path, dest, mode, uid, gid):
    if stat(img, dest):
        debugfs(img, f'rm "/{dest}"', write=True)
    debugfs(img, f'write {data_path} "/{dest}"', write=True)
    for field, val in (("mode", f"0{0o100000 | mode:o}"), ("uid", uid), ("gid", gid)):
        debugfs(img, f'set_inode_field "/{dest}" {field} {val}', write=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("raw")
    ap.add_argument("outdir")
    ap.add_argument("--put", action="append", default=[], metavar="SRC:DEST[:MODE]")
    ap.add_argument("--replace", action="append", default=[], metavar="DEST:OLD:NEW")
    ap.add_argument("--rm", action="append", default=[], metavar="DEST")
    a = ap.parse_args()
    if not (a.put or a.replace or a.rm):
        raise SystemExit("Nothing to do: give --put, --replace or --rm.")
    out = os.path.abspath(a.outdir)
    if out.startswith(REPO + os.sep):
        raise SystemExit("OUTDIR must be under ~/partycade-dumps/, not inside the repo.")
    os.makedirs(out, exist_ok=True)
    J = lambda n: os.path.join(out, n)  # noqa: E731

    part = {p["name"]: p for p in json.load(open(os.path.join(REPO, "captures", "partitions.json")))["partitions"]}["data"]
    off, size = part["offset"] * 512, part["sectors"] * 512

    print("1. Rebuilding the logical image from RAW")
    run([sys.executable, os.path.join(TOOLS, "sftl_rebuild.py"), a.raw, J("old.img")])
    old = open(J("old.img"), "rb").read()
    open(J("data_old.img"), "wb").write(old[off:off + size])
    fsck(J("data_old.img"), "data (before)")
    shutil.copy(J("data_old.img"), J("data_new.img"))
    img = J("data_new.img")

    print("2. Applying edits")
    expect = []
    for spec in a.rm:
        dest = spec.strip("/")
        if not stat(img, dest):
            raise SystemExit(f"--rm {dest}: no such file")
        debugfs(img, f'rm "/{dest}"', write=True)
        expect.append((dest, None, None))
        print(f"  rm {dest}")
    for spec in a.put:
        f = spec.split(":")
        if len(f) not in (2, 3):
            raise SystemExit(f"--put {spec}: want SRC:DEST[:MODE]")
        src, dest, mode = f[0], f[1].strip("/"), int(f[2], 8) if len(f) == 3 else 0o755
        put(img, os.path.abspath(src), dest, mode, 0, 0)
        expect.append((dest, open(src, "rb").read(), (mode, 0, 0)))
        print(f"  put {src} -> /data/{dest} mode {mode:o}")
    for spec in a.replace:
        dest, old_s, new_s = spec.split(":", 2) if spec.count(":") >= 2 else (None, None, None)
        if dest is None:
            raise SystemExit(f"--replace {spec}: want DEST:OLD:NEW")
        dest = dest.strip("/")
        st = stat(img, dest)
        if not st or st["type"] != "regular":
            raise SystemExit(f"--replace {dest}: not a regular file")
        text = cat(img, dest, J("tmp_cat"))
        n = text.count(old_s.encode())
        if n != 1:
            raise SystemExit(f"--replace {dest}: {old_s!r} occurs {n} times, need exactly 1")
        new_text = text.replace(old_s.encode(), new_s.encode())
        open(J("tmp_new"), "wb").write(new_text)
        put(img, J("tmp_new"), dest, st["mode"] & 0o7777, st["uid"], st["gid"])
        expect.append((dest, new_text, (st["mode"] & 0o7777, st["uid"], st["gid"])))
        print(f"  replace in {dest}: {old_s!r} -> {new_s!r} (mode {st['mode'] & 0o7777:o}, owner {st['uid']}:{st['gid']})")

    print("3. Reading edits back")
    for dest, data, meta in expect:
        st = stat(img, dest)
        if data is None:
            if st:
                raise SystemExit(f"  {dest} still exists")
            continue
        if not st or cat(img, dest, J("tmp_cat")) != data:
            raise SystemExit(f"  {dest}: content mismatch after write")
        if (st["mode"] & 0o7777, st["uid"], st["gid"]) != meta or st["type"] != "regular":
            raise SystemExit(f"  {dest}: metadata {st} != {meta}")
        print(f"  {dest}: ok")
    for t in ("tmp_cat", "tmp_new"):
        if os.path.exists(J(t)):
            os.remove(J(t))
    fsck(img, "data (after)")

    print("4. Patching the raw image")
    new = bytearray(old)
    new[off:off + size] = open(img, "rb").read()
    open(J("new.img"), "wb").write(new)
    pout = run([sys.executable, os.path.join(TOOLS, "sftl_patch.py"), a.raw, J("old.img"), J("new.img"),
                J("nand_raw_patched.bin"), "--part", "data"])
    print("  " + pout.strip().replace("\n", "\n  "))
    blocks = re.search(r"blocks: ([\d,]+)", pout).group(1)

    print("5. Round trip: rebuilding the patched raw image")
    run([sys.executable, os.path.join(TOOLS, "sftl_rebuild.py"), J("nand_raw_patched.bin"), J("check.img")])
    if hashlib.sha256(open(J("check.img"), "rb").read()).digest() != hashlib.sha256(new).digest():
        raise SystemExit("  MISMATCH: the patched raw image does not rebuild to new.img. Do not restore it.")
    os.remove(J("check.img"))
    print("  identical to new.img")
    with open(J("BLOCKS.txt"), "w") as f:
        f.write(blocks + "\n")

    print(f"\nBlocks to write: {blocks}")
    print("Before restoring: run `rk_restore.py diff` against RAW in the SAME session; it must report 0 differing blocks.")
    print("Restore (only with the user's written approval for exactly these blocks):")
    print(f"  PARTYCADE_ALLOW_NAND_WRITE=yes python3 tools/rk_restore.py restore {J('nand_raw_patched.bin')} "
          f"--blocks {blocks} --approval '<user approval text>'")


if __name__ == "__main__":
    main()
