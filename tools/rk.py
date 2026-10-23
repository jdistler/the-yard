#!/usr/bin/env python3
"""Read-only USB tool for the Partycade's RK3032 (GBX70-V01).

Every subcommand either reads host state or reads from the cabinet. There is no
write, erase, reset, or storage-change code path in this file, and the bulk
command builder refuses any opcode outside READ_ONLY_OPCODES. Recovery writes
live only in rk_restore.py (see RECOVERY.md).

Run `tools/rk.py -h` for the subcommands. See tools/README.md and RUNBOOK.md.
"""
import argparse
import datetime
import hashlib
import json
import os
import random
import struct
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RKBIN = os.path.join(ROOT, "reference", "rkbin", "bin", "rk30")
BUILD = os.path.join(ROOT, "build")
LOG = os.path.join(ROOT, "logs", "rk_log.jsonl")
CAPTURES = os.path.join(ROOT, "captures")
RKSEND = os.path.join(ROOT, "tools", "rksend")
DEFAULT_DUMPS = os.path.expanduser("~/partycade-dumps")

VID, PID = 0x2207, 0x301A
EP_OUT, EP_IN = 0x02, 0x81
SECTOR = 512
CHUNK_SECTORS = 128  # rkdeveloptool DEFAULT_RW_LBA

RC4_KEY = bytes([124, 78, 3, 4, 85, 5, 9, 7, 45, 44, 123, 56, 23, 13, 23, 17])

# Each stage: source blob in rkbin, how it is encoded, and the sha256 of a
# known-good wire file (None = never built before; build prints the hash).
STAGES = {
    "ddr396": dict(src="rk3036_ddr_396MHz_v1.11.bin", kind="ddr",
                   sha="240db75401335e23ac1ea66cc01d682bb909dc584c5664349213005e638d3c26",
                   note="PROVEN: returned on device 51, 2026-10-23"),
    "ddr300": dict(src="rk3036_ddr_300MHz_v1.11.bin", kind="ddr", sha=None, note="fallback, untested with RC4"),
    "ddr456": dict(src="rk3036_ddr_456MHz_v1.11.bin", kind="ddr", sha=None, note="fallback, untested with RC4"),
    # Results on this cabinet, 2026-10-23. See BOOT_RESEARCH.md for the evidence.
    "plug_std": dict(src="rk303x_usbplug_v2.57.bin", kind="plug",
                     sha="a04a53ef850f40b7f026216f5a40db043e3d706280c10bc2912fc0b28f858dd7",
                     note="runs; sees no storage (flash size 0). Not useful here"),
    "plug_slc": dict(src="rk303x_usbplug_slc_v2.65.bin", kind="plug",
                     sha="184b2105ee8dcfc339e4e3eb1dc1045bb585c5e3b3ac99b75d12d436a74847a5",
                     note="runs, then resets the chip back to Mask ROM (53->54)"),
    "plug_slc264": dict(src="rk303x_usbplug_slc_v2.64.bin", kind="plug",
                        sha="bd38bbaaa843b9949dfb9660fc942a17ac55086c0a2a40dc30ee951d8432575f",
                        note="runs, then resets the chip back to Mask ROM (54->55)"),
    "plug_3032": dict(src="rk3032_usbplug_v2.61.bin", kind="plug",
                      sha="d62ff8bfed2b57089e025399e6b1d9d6609c52445755918c455babb7ce408e6e",
                      note="WORKS: sees the SPI NAND; reads starting at LBA >= 0x10000 return 0xCC fill"),
    "plug_3032slc": dict(src="rk3032_usbplug_slc_v2.63.bin", kind="plug",
                         sha="bfe4a7db5a27e8ac471bce5b6bff6f39b885f96fa1086ade610052a89896cfbc",
                         note="USE THIS: READ_LBA also stops at 0x10000, but READ_SECTOR reads the whole "
                              "chip (devices 57->58)"),
    # Same blob, two Thumb edits so opcode 0x06 erases the block it is given. Stock returns
    # success and erases nothing above block 8 (cmp r4,#8 / bhi, then rsb r6,r4,#8). The inner
    # call is SPI NAND block-erase 0xD8 of page block*64, so one request is one block.
    "plug_3032slc_erase": dict(src="rk3032_usbplug_slc_v2.63.bin", kind="plug",
                               sha="bd6cd1df7022bb9004d3e77a92507168ed7e89112aab915d2d6145032e91b195",
                               patch=((0xbee2, bytes.fromhex("02d8"), bytes.fromhex("00bf")),
                                      (0xbef4, bytes.fromhex("01d9"), bytes.fromhex("01e0"))),
                               note="patched erase: nop the block>8 return, branch over the count clip"),
}

FILL = b"\xcc" * SECTOR  # what plug_3032 returns for sectors it does not serve

OP = dict(TEST_UNIT_READY=0x00, READ_FLASH_ID=0x01, READ_SECTOR=0x04, READ_LBA=0x14, READ_FLASH_INFO=0x1A,
          READ_CHIP_INFO=0x1B, READ_STORAGE=0x2B, READ_CAPABILITY=0xAA)
RAW_UNIT = 528            # READ_SECTOR returns 512 data + 16 spare per physical sector
RAW_SECTORS = 262144      # W25N01GV: 1024 blocks x 64 pages x 4 sectors
PAGE_SECTORS = 4
READ_ONLY_OPCODES = frozenset(OP.values())

NAND_MAKERS = {0xEC: "Samsung", 0x98: "Toshiba/Kioxia", 0xAD: "SK Hynix", 0x2C: "Micron",
               0xC2: "Macronix", 0xEF: "Winbond", 0xC8: "GigaDevice", 0x01: "Spansion/Cypress",
               0x9B: "ATO", 0xA1: "XTX", 0x0B: "XTX", 0xE5: "Dosilicon", 0x89: "Intel", 0x92: "ESMT",
               0xC9: "Foresee", 0x5E: "Zbit", 0x20: "XMC/Micron NOR", 0x1C: "EON", 0x68: "Boya"}


# ---------- encoding ----------

def rc4(data):
    s = list(range(256))
    j = 0
    for i in range(256):
        j = (j + s[i] + RC4_KEY[i % 16]) & 0xFF
        s[i], s[j] = s[j], s[i]
    out = bytearray(len(data))
    i = j = 0
    for n, b in enumerate(data):
        i = (i + 1) & 0xFF
        j = (j + s[i]) & 0xFF
        s[i], s[j] = s[j], s[i]
        out[n] = b ^ s[(s[i] + s[j]) & 0xFF]
    return bytes(out)


def crc16_ccitt(data):
    c = 0xFFFF
    for b in data:
        c ^= b << 8
        for _ in range(8):
            c = ((c << 1) ^ 0x1021) & 0xFFFF if c & 0x8000 else (c << 1) & 0xFFFF
    return c


def rkcrc32(data):
    c = 0
    for b in data:
        c ^= b << 24
        for _ in range(8):
            c = ((c << 1) ^ 0x04C10DB7) & 0xFFFFFFFF if c & 0x80000000 else (c << 1) & 0xFFFFFFFF
    return c


def encode_stage(name):
    st = STAGES[name]
    plain = bytearray(open(os.path.join(RKBIN, st["src"]), "rb").read())
    for off, old, new in st.get("patch", ()):
        if plain[off:off + len(old)] != old:
            raise SystemExit(f"{name}: patch at {off:#x} expected {old.hex()}, found {plain[off:off+len(old)].hex()}")
        plain[off:off + len(new)] = new
    plain = bytes(plain)
    if st["kind"] == "ddr":
        # Rockchip packer: zero-pad to a 2048 multiple, RC4 (image < 64 KiB, so the
        # packer's 16-bit length truncation does not matter).
        plain += b"\0" * (-len(plain) % 2048)
    # Plugs: RC4 over the exact length (xrock style). Proven with plug_std.
    body = rc4(plain)
    c = crc16_ccitt(body)
    wire = body + bytes([c >> 8, c & 0xFF])
    if len(wire) % 4096 == 0:
        raise SystemExit(f"{name}: wire length is a 4096 multiple; needs a terminator rule nobody has tested")
    if len(wire) % 4096 == 4095:
        wire += b"\0"
    return wire, c


def wire_path(name):
    return os.path.join(BUILD, f"{name}.wire")


# ---------- host-side state ----------

def boot_id():
    return open("/proc/sys/kernel/random/boot_id").read().strip()


def sysfs_devices():
    base = "/sys/bus/usb/devices"
    out = []
    for name in sorted(os.listdir(base)):
        p = os.path.join(base, name)
        try:
            if open(os.path.join(p, "idVendor")).read().strip() != "2207":
                continue
        except OSError:
            continue

        def rd(f):
            try:
                return open(os.path.join(p, f)).read().strip()
            except OSError:
                return None
        mfg = rd("manufacturer")
        # The BootROM has no string descriptors; every loader seen so far does
        # (plugs: RockChip/USB-MSC/rockchip; U-Boot rockusb is expected to as well).
        mode = "maskrom" if mfg is None else "loader"
        out.append(dict(port=name, devnum=int(rd("devnum")), busnum=int(rd("busnum")), product_id=rd("idProduct"),
                        mode=mode, manufacturer=mfg, product=rd("product"), serial=rd("serial"),
                        speed=rd("speed")))
    return out


def the_device():
    devs = sysfs_devices()
    if not devs:
        raise SystemExit("No Rockchip device on the bus. Do the cold plug (RUNBOOK.md, 'Cold plug').")
    if len(devs) > 1:
        raise SystemExit(f"More than one Rockchip device: {devs}")
    return devs[0]


def log(action, **fields):
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    rec = dict(ts=datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
               boot_id=boot_id(), action=action, **fields)
    with open(LOG, "a") as f:
        f.write(json.dumps(rec) + "\n")
    return rec


def log_entries():
    if not os.path.exists(LOG):
        return []
    return [json.loads(l) for l in open(LOG) if l.strip()]


def devnum_already_used(devnum):
    bid = boot_id()
    return [e for e in log_entries() if e.get("boot_id") == bid and e.get("devnum") == devnum
            and e["action"].startswith("send_")]


# ---------- loader (bulk) session ----------

class Loader:
    def __init__(self):
        import usb.core
        import usb.util
        self.usb = usb
        d = the_device()
        if d["mode"] != "loader":
            raise SystemExit(f"Device {d['devnum']} is in {d['mode']} mode, not loader. Run `rk.py boot` first.")
        self.devnum = d["devnum"]
        self.dev = usb.core.find(idVendor=VID, idProduct=int(d["product_id"], 16))
        if self.dev is None or self.dev.address != self.devnum:
            raise SystemExit("pyusb and sysfs disagree about the device; stop and look at `rk.py state`.")
        usb.util.claim_interface(self.dev, 0)

    def close(self):
        self.usb.util.release_interface(self.dev, 0)

    def command(self, op, n_in=0, lba=0, count=0, cdblen=6, timeout=5000):
        if op not in READ_ONLY_OPCODES:
            raise SystemExit(f"opcode {op:#x} is not on the read-only list; refusing")
        tag = random.getrandbits(32)
        cdb = struct.pack(">BBIBH7x", op, 0, lba, 0, count)
        cbw = struct.pack("<IIIBBB", 0x43425355, tag, n_in, 0x80 if n_in else 0x00, 0, cdblen) + cdb
        try:
            self.dev.write(EP_OUT, cbw, timeout=3000)
            data = b""
            if n_in:
                data = bytes(self.dev.read(EP_IN, max(n_in, 512), timeout=timeout))
                if len(data) == 13 and data[:4] == b"USBS" and n_in != 13:
                    sig, ctag, res, status = struct.unpack("<IIIB", data)
                    return b"", status
            csw = bytes(self.dev.read(EP_IN, 13, timeout=3000))
        except self.usb.core.USBError as e:
            self.resync()
            raise SystemExit(f"USB error on opcode {op:#x}: {e}. Pipe resynced; stop and record it.")
        sig, ctag, res, status = struct.unpack("<IIIB", csw)
        if sig != 0x53425355 or ctag != tag:
            raise SystemExit(f"CSW mismatch on opcode {op:#x}; stop, this boot is suspect.")
        return data, status

    def resync(self):
        try:
            self.dev.read(EP_IN, 512, timeout=500)
        except self.usb.core.USBError:
            pass
        tag = random.getrandbits(32)
        cbw = struct.pack("<IIIBBB", 0x43425355, tag, 0, 0, 0, 6) + bytes(16)
        self.dev.write(EP_OUT, cbw, timeout=2000)
        self.dev.read(EP_IN, 13, timeout=2000)

    def read_raw(self, sector, count):
        """Physical NAND read (bypasses SFTL). Returns count*528 bytes."""
        out = bytearray()
        while count:
            n = min(count, 128)
            data, status = self.command(OP["READ_SECTOR"], n * RAW_UNIT, lba=sector, count=n, cdblen=10,
                                        timeout=10000)
            if status != 0 or len(data) != n * RAW_UNIT:
                raise SystemExit(f"READ_SECTOR {sector:#x}+{n}: status {status}, got {len(data)} bytes")
            out += data
            sector += n
            count -= n
        return bytes(out)

    def read_lba(self, lba, count):
        # plug_3032 returns stale buffer bytes (not 0xCC) for the part of a single
        # read that runs past a 0x10000-sector boundary, so never let one cross it.
        out = bytearray()
        while count:
            n = min(count, CHUNK_SECTORS, 0x10000 - (lba & 0xFFFF))
            data, status = self.command(OP["READ_LBA"], n * SECTOR, lba=lba, count=n, cdblen=10, timeout=10000)
            if status != 0 or len(data) != n * SECTOR:
                raise SystemExit(f"READ_LBA {lba:#x}+{n}: status {status}, got {len(data)} bytes")
            out += data
            lba += n
            count -= n
        return bytes(out)


def decode_flash_info(d):
    size, block, page, ecc, access, manuf, cs = struct.unpack("<IHBBBBB", d[:11])
    return dict(sectors=size, mib=size * SECTOR / 2 ** 20, block_sectors=block, page_sectors=page,
                ecc_bits=ecc, access_time=access, manuf_code=manuf, cs_mask=cs)


def decode_flash_id(d):
    if all(32 <= b < 127 for b in d):
        return dict(ascii=d.decode().strip(), hex=d.hex())
    return dict(hex=d.hex(), maker=NAND_MAKERS.get(d[0], "unknown"))


def decode_capability(d):
    names = ["direct_lba", "vendor_storage", "first_4m_access", "read_lba", "read_com_log",
             "read_idb_config", "read_secure_mode", "new_idb"]
    return dict(hex=d.hex(), flags=[n for i, n in enumerate(names) if d and d[0] & (1 << i)])


# ---------- subcommands ----------

def cmd_state(a):
    devs = sysfs_devices()
    if not devs:
        print("No Rockchip device on the bus.")
        print("  Switch ON + running game: expected (OTG is a host). Otherwise do the cold plug.")
        return
    for d in devs:
        used = devnum_already_used(d["devnum"])
        print(f"device {d['devnum']} on port {d['port']}: mode={d['mode']} speed={d['speed']}Mbps "
              f"strings={d['manufacturer']}/{d['product']}/{d['serial']}")
        if d["mode"] == "maskrom":
            print("  fresh BootROM, nothing sent yet" if not used else
                  f"  SPENT: {len(used)} send(s) already logged on this enumeration. Cold plug before `boot`.")
        elif d["mode"] == "loader":
            plug = [e for e in log_entries() if e["action"] == "send_472" and e.get("ok")]
            name = plug[-1]["stage"] if plug else "unknown"
            print(f"  USB plug running (last plug sent: {name}). Read-only commands are available.")


def cmd_build(a):
    os.makedirs(BUILD, exist_ok=True)
    bad = 0
    for name, st in STAGES.items():
        src = os.path.join(RKBIN, st["src"])
        if not os.path.exists(src):
            print(f"{name}: missing {src}. Run tools/fetch_references.sh"); bad += 1; continue
        wire, c = encode_stage(name)
        h = hashlib.sha256(wire).hexdigest()
        open(wire_path(name), "wb").write(wire)
        if st["sha"] is None:
            verdict = "no reference hash (unproven stage)"
        elif h == st["sha"]:
            verdict = "matches known-good"
        else:
            verdict = "HASH MISMATCH, do not send"; bad += 1
        print(f"{name:9s} {len(wire):7d} B crc16 {c:04x} sha256 {h[:16]}…  {verdict}  [{st['note']}]")
    sys.exit(1 if bad else 0)


def send_stage(dev, index, name):
    path = wire_path(name)
    if not os.path.exists(path):
        raise SystemExit(f"{path} missing; run `rk.py build`")
    wire = open(path, "rb").read()
    want = STAGES[name]["sha"]
    if want and hashlib.sha256(wire).hexdigest() != want:
        raise SystemExit(f"{name}: wire hash differs from known-good; refusing")
    if not os.access(RKSEND, os.X_OK):
        raise SystemExit("tools/rksend not built; run `make -C tools`")
    r = subprocess.run([RKSEND, str(dev["devnum"]), f"{index:x}", path, "10000"],
                       capture_output=True, text=True, timeout=600)
    print(r.stdout, end="")
    ok = r.returncode == 0
    log(f"send_{index:x}", devnum=dev["devnum"], stage=name, ok=ok, rc=r.returncode,
        out=r.stdout.strip().splitlines()[-3:])
    return ok


def cmd_boot(a):
    d = the_device()
    if d["mode"] != "maskrom":
        raise SystemExit(f"Device {d['devnum']} is in {d['mode']} mode. `boot` needs a fresh Mask ROM; cold plug.")
    if devnum_already_used(d["devnum"]):
        raise SystemExit(f"Device {d['devnum']} already received a download on this enumeration. Cold plug.")
    print(f"Mask ROM device {d['devnum']} is fresh. DDR={a.ddr} plug={a.plug}")
    if not send_stage(d, 0x471, a.ddr):
        print("\nDDR stage failed. This enumeration is spent: do not send anything else, do not reset.")
        print("Record the chunk output in BOOT_RESEARCH.md, then ask for a cold plug. See RUNBOOK.md 'Decision table'.")
        sys.exit(2)
    time.sleep(0.01)
    if not send_stage(d, 0x472, a.plug):
        print("\nPlug stage failed. Enumeration spent. Record it and ask for a cold plug.")
        sys.exit(3)
    print("Plug sent; waiting up to 15 s for the loader to enumerate…")
    deadline = time.time() + 15
    while time.time() < deadline:
        time.sleep(0.5)
        devs = sysfs_devices()
        if devs and devs[0]["mode"] == "loader" and devs[0]["devnum"] != d["devnum"]:
            n = devs[0]
            print(f"Loader up: device {n['devnum']} ({n['manufacturer']}/{n['product']}/{n['serial']})")
            log("loader_up", devnum=n["devnum"], from_devnum=d["devnum"], plug=a.plug)
            return
    devs = sysfs_devices()
    if devs and devs[0]["mode"] == "maskrom" and devs[0]["devnum"] != d["devnum"]:
        n = devs[0]
        log("plug_reset_to_maskrom", devnum=n["devnum"], from_devnum=d["devnum"], plug=a.plug)
        print(f"The plug ran, then the chip reset back into Mask ROM as device {n['devnum']}.")
        print("That device is a fresh BootROM (warm reset, switch OFF). No cold plug needed for the next boot.")
        sys.exit(5)
    log("loader_missing", devnum=d["devnum"], plug=a.plug)
    print("No loader appeared. Record it; cold plug before anything else.")
    sys.exit(4)


def cmd_info(a):
    L = Loader()
    res = {}
    try:
        _, st = L.command(OP["TEST_UNIT_READY"])
        res["test_unit_ready"] = st
        d, _ = L.command(OP["READ_CHIP_INFO"], 16)
        res["chip_info"] = dict(hex=d.hex(), name=d[:4][::-1].decode(errors="replace"))
        d, _ = L.command(OP["READ_FLASH_ID"], 5)
        res["flash_id"] = decode_flash_id(d)
        d, _ = L.command(OP["READ_FLASH_INFO"], 11)
        res["flash_info"] = decode_flash_info(d)
        d, _ = L.command(OP["READ_CAPABILITY"], 8)
        res["capability"] = decode_capability(d)
        if a.storage:
            d, st = L.command(OP["READ_STORAGE"], 4)
            res["storage"] = dict(hex=d.hex(), status=st)
        if res["flash_info"]["sectors"] > 0x10000:
            hi = L.read_lba(0x10000, 1)
            res["reads_at_or_above_0x10000"] = "0xCC fill (limited plug)" if hi == FILL else "data"
    finally:
        L.close()
    plug = [e for e in log_entries() if e["action"] == "send_472" and e.get("ok")]
    log("info", devnum=L.devnum, plug=plug[-1]["stage"] if plug else None, result=res)
    print(json.dumps(res, indent=1))
    fi = res["flash_info"]
    if fi["sectors"] == 0:
        print("\nVERDICT: flash size 0. This plug does not see the storage; sector reads will be noise.")
    elif res.get("reads_at_or_above_0x10000", "").startswith("0xCC"):
        print(f"\nVERDICT: storage found ({fi['mib']:.1f} MiB) but this plug only serves LBA < 0x10000 (32 MiB).")
    else:
        print(f"\nVERDICT: storage found, {fi['mib']:.1f} MiB, reads above 32 MiB return data. Next: `rk.py probe`.")


def classify(sec):
    tags = []
    if sec[:4] == b"PARM":
        tags.append("PARM")
    if sec[510:512] == b"\x55\xaa":
        tags.append("MBR-signature")
    if sec[:8] == b"EFI PART":
        tags.append("GPT-header")
    if rc4(sec[:4]) == b"\x55\xaa\xf0\x0f":
        tags.append("Rockchip-IDB")
    if sec == b"\xff" * len(sec):
        tags.append("all-FF")
    if sec == b"\0" * len(sec):
        tags.append("all-00")
    return tags


PROBE_LBAS = [0, 1, 64, 0x400, 0x800, 0xC00, 0x1000, 0x2000]


def cmd_probe(a):
    L = Loader()
    os.makedirs(CAPTURES, exist_ok=True)
    rows = []
    try:
        for lba in PROBE_LBAS:
            first = L.read_lba(lba, 4)
            second = L.read_lba(lba, 4)
            stable = first == second
            tags = classify(first[:SECTOR])
            rows.append(dict(lba=lba, stable=stable, tags=tags, head=first[:16].hex()))
            print(f"LBA {lba:#07x}: {'stable' if stable else 'CHANGES BETWEEN READS'}  {tags or ''}  {first[:16].hex()}")
    finally:
        L.close()
    log("probe", devnum=L.devnum, rows=rows)
    if not any(r["stable"] for r in rows):
        print("\nVERDICT: nothing reads back the same twice. This is buffer noise, not storage.")
    elif any("PARM" in r["tags"] for r in rows):
        print("\nVERDICT: Rockchip PARM found. Next: `rk.py parts`.")
    elif any("GPT-header" in r["tags"] for r in rows):
        print("\nVERDICT: GPT found. Next: `rk.py parts` (GPT parsing is a TODO; save LBA 0-33 with `read`).")
    else:
        print("\nVERDICT: stable data but no known header. Save LBA 0-0x2100 with `read` and inspect offline.")


def parse_mtdparts(text):
    i = text.find("mtdparts=")
    if i < 0:
        return []
    spec = text[i + 9:].split()[0]
    spec = spec.split(":", 1)[1] if ":" in spec else spec
    parts = []
    for item in spec.split(","):
        size_s, rest = item.split("@", 1) if "@" in item else (item, "")
        off_s, name = rest.split("(", 1)
        name = name.rstrip(")").split(")")[0]
        size = None if size_s.strip() == "-" else int(size_s, 16)
        parts.append(dict(name=name, offset=int(off_s, 16), sectors=size))
    return parts


def parse_gpt(hdr, entries):
    if hdr[:8] != b"EFI PART":
        return None
    n, esz = struct.unpack("<II", hdr[80:88])
    parts = []
    for i in range(n):
        e = entries[i * esz:(i + 1) * esz]
        if len(e) < 128 or e[:16] == bytes(16):
            continue
        first, last = struct.unpack("<QQ", e[32:48])
        name = e[56:128].decode("utf-16-le").rstrip("\0")
        parts.append(dict(name=name, offset=first, sectors=last - first + 1, type_guid=e[:16].hex()))
    return parts


def cmd_parts(a):
    L = Loader()
    try:
        hdr = L.read_lba(1, 1)
        if hdr[:8] == b"EFI PART":
            ent_lba = struct.unpack("<Q", hdr[72:80])[0]
            n, esz = struct.unpack("<II", hdr[80:88])
            entries = L.read_lba(ent_lba, (n * esz + SECTOR - 1) // SECTOR)
            if L.read_lba(ent_lba, (n * esz + SECTOR - 1) // SECTOR) != entries:
                raise SystemExit("GPT entries differ between reads; stop.")
            parts = parse_gpt(hdr, entries)
            last_usable = struct.unpack("<Q", hdr[48:56])[0]
            L.close()
            os.makedirs(CAPTURES, exist_ok=True)
            open(os.path.join(CAPTURES, "gpt_lba1-33.bin"), "wb").write(hdr + entries)
            json.dump(dict(table="gpt", last_usable_lba=last_usable, partitions=parts),
                      open(os.path.join(CAPTURES, "partitions.json"), "w"), indent=1)
            log("parts", devnum=L.devnum, table="gpt", partitions=parts)
            print(f"GPT, {len(parts)} partitions, last usable LBA {last_usable:#x}\n")
            print(f"{'name':16s} {'offset':>10s} {'sectors':>10s} {'MiB':>8s}")
            for p in parts:
                print(f"{p['name']:16s} {p['offset']:#10x} {p['sectors']:#10x} {p['sectors'] * SECTOR / 2**20:8.2f}")
            print("\nSaved captures/partitions.json and captures/gpt_lba1-33.bin (safe to commit).")
            return
    except BaseException:
        L.close()
        raise
    found = None
    L = Loader()
    try:
        for lba in PROBE_LBAS:
            blk = L.read_lba(lba, 32)
            if blk[:4] != b"PARM":
                continue
            n = struct.unpack("<I", blk[4:8])[0]
            if not 0 < n < len(blk) - 12:
                print(f"LBA {lba:#x}: PARM with bad length {n}"); continue
            text = blk[8:8 + n]
            crc_ok = struct.unpack("<I", blk[8 + n:12 + n])[0] == rkcrc32(text)
            print(f"LBA {lba:#x}: PARM length {n}, crc {'ok' if crc_ok else 'BAD'}")
            if crc_ok and found is None:
                found = (lba, text.decode(errors="replace"))
    finally:
        L.close()
    if not found:
        raise SystemExit("No PARM block with a good CRC at the probe offsets. Use `probe` and `read`.")
    lba, text = found
    parts = parse_mtdparts(text)
    os.makedirs(CAPTURES, exist_ok=True)
    open(os.path.join(CAPTURES, "parameter.txt"), "w").write(text)
    json.dump(dict(parm_lba=lba, partitions=parts), open(os.path.join(CAPTURES, "partitions.json"), "w"), indent=1)
    log("parts", devnum=L.devnum, parm_lba=lba, partitions=parts)
    print(text)
    print(f"\n{'name':16s} {'offset':>10s} {'sectors':>10s} {'MiB':>8s}")
    for p in parts:
        s = p["sectors"]
        print(f"{p['name']:16s} {p['offset']:#10x} {('-' if s is None else hex(s)):>10s} "
              f"{('rest' if s is None else f'{s * SECTOR / 2**20:.1f}'):>8s}")
    print("\nSaved captures/parameter.txt and captures/partitions.json (safe to commit).")


def out_path_ok(path, nbytes):
    real = os.path.realpath(path)
    if real.startswith(ROOT + os.sep) and nbytes > 1024 * 1024:
        raise SystemExit(f"Refusing to write {nbytes} bytes inside the repo. Use {DEFAULT_DUMPS}/ "
                         "(stock firmware and game data must not be committed).")


def cmd_read(a):
    lba, count = int(a.lba, 0), int(a.count, 0)
    out_path_ok(a.out, count * SECTOR)
    L = Loader()
    try:
        data = L.read_lba(lba, count)
        if a.verify and L.read_lba(lba, count) != data:
            raise SystemExit("Second read differs: not real storage data. Nothing saved.")
    finally:
        L.close()
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    open(a.out, "wb").write(data)
    h = hashlib.sha256(data).hexdigest()
    log("read", devnum=L.devnum, lba=lba, count=count, out=a.out, sha256=h, verified=a.verify)
    print(f"{a.out}: {len(data)} bytes, sha256 {h}, tags of first sector {classify(data[:SECTOR])}")


def cmd_dump(a):
    if a.part:
        pj = os.path.join(CAPTURES, "partitions.json")
        parts = {p["name"]: p for p in json.load(open(pj))["partitions"]}
        if a.part not in parts:
            raise SystemExit(f"No partition {a.part!r}; have {list(parts)}")
        p = parts[a.part]
        start = p["offset"]
        count = p["sectors"] if p["sectors"] is not None else (int(a.count, 0) if a.count else None)
        if count is None:
            raise SystemExit("Partition has size '-' (rest of flash): pass --count from `info` flash size minus offset.")
        out = a.out or os.path.join(DEFAULT_DUMPS, f"{a.part}.img")
    else:
        if a.start is None or a.count is None or a.out is None:
            raise SystemExit("Give --part NAME, or all of --start --count --out")
        start, count, out = int(a.start, 0), int(a.count, 0), a.out
    out_path_ok(out, count * SECTOR)
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    done = os.path.getsize(out) // SECTOR if os.path.exists(out) else 0
    if done > count:
        raise SystemExit(f"{out} is larger than the requested range; move it aside first.")
    if done:
        print(f"Resuming {out} at sector {done} of {count}")
    L = Loader()
    t0 = time.time()
    try:
        with open(out, "r+b" if done else "wb") as f:
            f.truncate(done * SECTOR)
            f.seek(done * SECTOR)
            step = 2048  # 1 MiB per progress tick
            while done < count:
                n = min(step, count - done)
                data = L.read_lba(start + done, n)
                if a.verify and L.read_lba(start + done, n) != data:
                    raise SystemExit(f"Verify mismatch at sector {start + done:#x}; stopping (file kept up to here).")
                f.write(data)
                f.flush()
                done += n
                rate = done * SECTOR / max(time.time() - t0, 1e-6) / 2 ** 20
                print(f"\r{done}/{count} sectors ({done * 100 // count}%) {rate:.2f} MiB/s", end="", flush=True)
    finally:
        L.close()
    print()
    blob = open(out, "rb").read()
    h = hashlib.sha256(blob).hexdigest()
    fill = sum(1 for i in range(0, len(blob), SECTOR) if blob[i:i + SECTOR] == FILL)
    plug = [e for e in log_entries() if e["action"] == "send_472" and e.get("ok")]
    with open(out + ".sha256", "w") as f:
        f.write(f"{h}  {os.path.basename(out)}  lba={start:#x} count={count:#x} "
                f"fill_sectors={fill} plug={plug[-1]['stage'] if plug else '?'}\n")
    log("dump", devnum=L.devnum, start=start, count=count, out=out, sha256=h, verified=a.verify, fill_sectors=fill)
    print(f"{out}: sha256 {h}")
    if fill:
        print(f"WARNING: {fill} of {count} sectors are 0xCC fill, not flash data. This dump is INCOMPLETE.")


def cmd_rawdump(a):
    """Whole-chip physical image via READ_SECTOR: RAW_SECTORS x 528 bytes, page-interleaved data+spare."""
    start, count = int(a.start, 0), int(a.count, 0)
    if start % PAGE_SECTORS or count % PAGE_SECTORS:
        raise SystemExit("start and count must be multiples of 4 (one NAND page)")
    out = a.out
    out_path_ok(out, count * RAW_UNIT)
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    done = os.path.getsize(out) // (RAW_UNIT * PAGE_SECTORS) * PAGE_SECTORS if os.path.exists(out) else 0
    if done > count:
        raise SystemExit(f"{out} is larger than the requested range; move it aside first.")
    if done:
        print(f"Resuming {out} at sector {done} of {count}")
    L = Loader()
    t0 = time.time()
    try:
        with open(out, "r+b" if done else "wb") as f:
            f.truncate(done * RAW_UNIT)
            f.seek(done * RAW_UNIT)
            step = 1024
            while done < count:
                n = min(step, count - done)
                data = L.read_raw(start + done, n)
                if a.verify and L.read_raw(start + done, n) != data:
                    raise SystemExit(f"Verify mismatch at raw sector {start + done:#x}; stopping (file kept up to here).")
                f.write(data)
                f.flush()
                done += n
                rate = done * RAW_UNIT / max(time.time() - t0, 1e-6) / 2 ** 20
                print(f"\r{done}/{count} raw sectors ({done * 100 // count}%) {rate:.2f} MiB/s", end="", flush=True)
    finally:
        L.close()
    print()
    h = hashlib.sha256(open(out, "rb").read()).hexdigest()
    with open(out + ".sha256", "w") as f:
        f.write(f"{h}  {os.path.basename(out)}  raw_sector={start:#x} count={count:#x} unit=528\n")
    log("rawdump", devnum=L.devnum, start=start, count=count, out=out, sha256=h, verified=a.verify)
    print(f"{out}: sha256 {h}")


def cmd_log(a):
    for e in log_entries()[-a.n:]:
        extra = {k: v for k, v in e.items() if k not in ("ts", "boot_id", "action")}
        print(e["ts"], e["action"], json.dumps(extra)[:200])


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("state", help="what is on the bus (no USB traffic)").set_defaults(f=cmd_state)
    sub.add_parser("build", help="build and hash-check every download stage").set_defaults(f=cmd_build)
    b = sub.add_parser("boot", help="download DDR + USB plug into RAM on a fresh Mask ROM")
    b.add_argument("--ddr", default="ddr396", choices=[k for k, v in STAGES.items() if v["kind"] == "ddr"])
    b.add_argument("--plug", required=True, choices=[k for k, v in STAGES.items() if v["kind"] == "plug"])
    b.set_defaults(f=cmd_boot)
    i = sub.add_parser("info", help="loader: chip, flash ID, flash size, capability")
    i.add_argument("--storage", action="store_true", help="also READ_STORAGE (the 2.57 plug rejects it)")
    i.set_defaults(f=cmd_info)
    sub.add_parser("probe", help="loader: read header LBAs twice, look for PARM/GPT/IDB").set_defaults(f=cmd_probe)
    sub.add_parser("parts", help="loader: find PARM, save partition table to captures/").set_defaults(f=cmd_parts)
    r = sub.add_parser("read", help="loader: read a small LBA range to a file")
    r.add_argument("lba"); r.add_argument("count"); r.add_argument("-o", "--out", required=True)
    r.add_argument("--verify", action="store_true", help="read twice and require a match")
    r.set_defaults(f=cmd_read)
    d = sub.add_parser("dump", help=f"loader: resumable bulk read to {DEFAULT_DUMPS}")
    d.add_argument("--part"); d.add_argument("--start"); d.add_argument("--count"); d.add_argument("-o", "--out")
    d.add_argument("--verify", action="store_true")
    d.set_defaults(f=cmd_dump)
    rw = sub.add_parser("rawdump", help="loader: physical NAND image via READ_SECTOR (512+16 per sector)")
    rw.add_argument("--start", default="0"); rw.add_argument("--count", default=str(RAW_SECTORS))
    rw.add_argument("-o", "--out", required=True); rw.add_argument("--verify", action="store_true")
    rw.set_defaults(f=cmd_rawdump)
    lg = sub.add_parser("log", help="show the last N log entries")
    lg.add_argument("-n", type=int, default=20)
    lg.set_defaults(f=cmd_log)
    a = p.parse_args()
    a.f(a)


if __name__ == "__main__":
    main()
