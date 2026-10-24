#!/usr/bin/env python3
"""Show or prepare the boot-image change that turns on the microSD slot, USB-A, and an ADB port.

Offline only. This never talks to the cabinet and never calls restore.

The kernel already has the USB-storage and SD drivers. The device tree leaves
both controllers disabled. Linux compares the status string with strcmp, so a
status value of "disabled" (9 bytes) can become "okay" followed by extra NULs
without moving any other byte in the tree. The boot image stays the same size.

  tools/enable_storage.py report BOOT.img
  tools/enable_storage.py report rk-kernel.dtb
  tools/enable_storage.py patch BOOT.img -o /tmp/boot-storage.img               # the SD slot only
  tools/enable_storage.py patch BOOT.img -o /tmp/boot.img --which sd,usb,adb   # all three

adb sets the Micro-USB OTG controller's dr_mode from "host" to "otg", so the stock adbd
gets a UDC: a root shell over the cable (untested on this board).

patch writes a new boot image. It does not write NAND. Flashing it is a separate
step, from a fresh rawdump, with a block list computed that session. See
GAMEDEV.md section 11. Do not reuse a block list from an older dump: SFTL moves
pages when the cabinet boots.
"""
import argparse
import os
import struct
import sys

FDT_MAGIC = 0xD00DFEED
FDT_BEGIN_NODE = 1
FDT_END_NODE = 2
FDT_PROP = 3
FDT_NOP = 4
FDT_END = 9

# USB-A is the host controller. The micro-USB OTG port stays as it is.
# The SD slot is the 4-bit controller. The 8-bit eMMC controller stays off;
# this board has no eMMC, and U-Boot's tree is the one that mentions it.
TARGETS = {
    "usb@101c0000": "usb",
    "dwmmc@10214000": "sd",
}
# The Micro-USB OTG port: dr_mode "host" -> "otg" turns on a UDC, so the stock adbd
# starts (FIRMWARE_ANALYSIS.md). "otg" fits in place of "host"; "peripheral" would not.
ADB_NODE = "usb@10180000"


def align(n):
    return (n + 3) & ~3


def find_dtb(blob):
    """Return (offset, dtb) for the first FDT, or raise."""
    sig = struct.pack(">I", FDT_MAGIC)
    start = 0
    while True:
        i = blob.find(sig, start)
        if i < 0:
            raise SystemExit("no device tree (d00dfeed) in this file")
        if i + 40 > len(blob):
            raise SystemExit("device tree header is cut off")
        totalsize = struct.unpack_from(">I", blob, i + 4)[0]
        if 40 < totalsize <= len(blob) - i and blob[i:i + 4] == sig:
            return i, bytearray(blob[i:i + totalsize])
        start = i + 4


def parse_header(dtb):
    magic, totalsize, off_struct, off_strings, off_rsv, version, last, boot, size_strings, size_struct = struct.unpack(
        ">10I", dtb[:40]
    )
    if magic != FDT_MAGIC:
        raise SystemExit("not a device tree")
    if totalsize != len(dtb):
        raise SystemExit(f"device tree size {len(dtb)} does not match header {totalsize}")
    strings = dtb[off_strings:off_strings + size_strings]
    return off_struct, off_struct + size_struct, strings


def cstring(buf, off):
    end = buf.find(b"\0", off)
    if end < 0:
        raise SystemExit("unterminated string in device tree")
    return buf[off:end].decode("ascii", "replace")


def walk(dtb):
    """Yield (path, prop_name, value_off, value_len) for every property."""
    off_struct, end, strings = parse_header(dtb)
    p = off_struct
    stack = []
    while p < end:
        token = struct.unpack_from(">I", dtb, p)[0]
        p += 4
        if token == FDT_BEGIN_NODE:
            name = cstring(dtb, p)
            p = align(p + len(name) + 1)
            stack.append(name)
        elif token == FDT_END_NODE:
            if stack:
                stack.pop()
        elif token == FDT_PROP:
            length, nameoff = struct.unpack_from(">II", dtb, p)
            p += 8
            yield "/".join(stack), cstring(strings, nameoff), p, length
            p = align(p + length)
        elif token == FDT_NOP:
            pass
        elif token == FDT_END:
            break
        else:
            raise SystemExit(f"bad device-tree token {token:#x} at {p-4:#x}")


def statuses(dtb):
    found = {}
    for path, prop, off, length in walk(dtb):
        node = path.split("/")[-1] if path else ""
        if prop == "status" and node in TARGETS:
            raw = bytes(dtb[off:off + length])
            found[node] = (TARGETS[node], raw.split(b"\0", 1)[0].decode(), off, length, path)
    return found


def dr_mode(dtb):
    for path, prop, off, length in walk(dtb):
        if prop == "dr_mode" and path.split("/")[-1] == ADB_NODE:
            return bytes(dtb[off:off + length]).split(b"\0", 1)[0].decode(), off, length, path
    return None


def report(dtb, label):
    found = statuses(dtb)
    print(f"{label}: {len(dtb)} bytes")
    for node, key in TARGETS.items():
        if node not in found:
            print(f"  {key:4} {node}: STATUS PROPERTY MISSING")
            continue
        _, text, off, length, path = found[node]
        print(f"  {key:4} {path}: status={text!r} ({length} bytes at {off:#x})")
    # Neighbours worth not touching.
    for path, prop, off, length in walk(dtb):
        node = path.split("/")[-1]
        if prop == "status" and node in ("usb@10180000", "dwmmc@10218000", "dwmmc@1021c000"):
            text = bytes(dtb[off:off + length]).split(b"\0", 1)[0].decode()
            print(f"  leave {path}: status={text!r}")
    m = dr_mode(dtb)
    print(f"  adb  {m[3]}: dr_mode={m[0]!r} ({m[2]} bytes at {m[1]:#x})" if m else f"  adb  {ADB_NODE}: DR_MODE MISSING")
    return found


def patch(dtb, which):
    found = statuses(dtb)
    changed = []
    if "adb" in which:
        m = dr_mode(dtb)
        if not m:
            raise SystemExit(f"no dr_mode on {ADB_NODE}")
        text, off, length, path = m
        if text == "otg":
            print(f"{path} is already otg")
        elif text != "host" or length != 5:
            raise SystemExit(f"{path} dr_mode is {text!r}, {length} bytes; refusing to guess")
        else:
            dtb[off:off + 5] = b"otg\0\0"
            changed.append(path + " dr_mode")
    for node, key in TARGETS.items():
        if key not in which:
            continue
        if node not in found:
            raise SystemExit(f"no status property on {node}")
        _, text, off, length, path = found[node]
        if text == "okay":
            print(f"{path} is already okay")
            continue
        if text != "disabled" or length < 9:
            raise SystemExit(f"{path} status is {text!r}, {length} bytes; refusing to guess")
        # strcmp stops at the first NUL. The extra bytes stay so nothing else moves.
        dtb[off:off + 9] = b"okay\0\0\0\0\0"
        changed.append(path)
    if not changed:
        raise SystemExit("nothing to change")
    # The patched tree must still walk.
    report(dtb, "patched")
    return changed


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("command", choices=("report", "patch"))
    ap.add_argument("image", help="boot.img or a bare rk-kernel.dtb")
    ap.add_argument("-o", "--out", help="patch: where to write the new boot image or dtb")
    ap.add_argument("--which", default="sd", help="patch: any of sd, usb, adb, comma-separated (default sd)")
    a = ap.parse_args()
    blob = open(a.image, "rb").read()
    try:
        off, dtb = find_dtb(blob)
        whole = True
    except SystemExit:
        if blob[:4] == struct.pack(">I", FDT_MAGIC):
            off, dtb, whole = 0, bytearray(blob), False
        else:
            raise
    which = {w.strip() for w in a.which.split(",") if w.strip()}
    unknown = which - set(TARGETS.values()) - {"adb"}
    if unknown:
        raise SystemExit(f"unknown --which {unknown}; use sd, usb, adb")
    if a.command == "report":
        report(dtb, a.image)
        if whole:
            print(f"device tree is {len(dtb)} bytes at offset {off} in {a.image}")
        return
    if not a.out:
        raise SystemExit("patch needs -o, and -o must not be the input")
    if os.path.realpath(a.out) == os.path.realpath(a.image):
        raise SystemExit("refusing to overwrite the input")
    before = bytes(dtb)
    patch(dtb, which)
    if len(dtb) != len(before):
        raise SystemExit("internal error: tree size changed")
    if whole:
        out = bytearray(blob)
        out[off:off + len(dtb)] = dtb
        if len(out) != len(blob):
            raise SystemExit("internal error: boot image size changed")
    else:
        out = dtb
    open(a.out, "wb").write(out)
    print(f"wrote {a.out} ({len(out)} bytes, same size as the input)")
    print("This file is not on the cabinet. Flashing it needs a fresh rawdump and written approval.")


if __name__ == "__main__":
    main()
