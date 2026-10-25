#!/usr/bin/env python3
"""Pull committable facts out of the cabinet's extracted firmware. Offline only; never touches the cabinet.

The dumps themselves (raw NAND, partition images, the rootfs with its vendor libraries) stay out of git:
they are the vendor's code and the stock games' data. What a builder elsewhere needs is facts about them,
and those are fine to commit:

  captures/abi/<lib>.txt      SONAME, NEEDED, and every exported dynamic symbol with its version, for each
                              shared library in the rootfs, so a build elsewhere can be checked against the
                              cabinet's exact libraries without the rootfs (games/love/check_abi.py).
  captures/abi/INDEX.txt      one line per library: name, SONAME, size, sha256.
  captures/kernel/version.txt the kernel's version banner.
  captures/kernel/config.txt  the kernel .config, if the image carries one (CONFIG_IKCONFIG).
  captures/kernel/drivers.txt which known drivers and subsystems are named in the image (Wi-Fi, USB, storage,
                              input, sound), found by string search: "present" means the name is in the image.
  captures/gl/strings.txt     the GL, GLES, and EGL extension and version strings inside libmali.
  captures/sdl/strings.txt    the video, audio, and render back ends compiled into the stock SDL2.
  captures/system/            the rootfs's own configuration, as text: init scripts, udev rules, inittab,
                              fstab, network and dropbear settings, the account list with each account's
                              password state (empty, locked, or set; never the hash), and the busybox
                              applets. These say how USB, the card, ADB, and a network would come up.
  captures/kernel/modules.txt what a loadable module must match: the vermagic string and whether
                              symbol versions (CONFIG_MODVERSIONS) are checked.
  captures/kernel/bootimg.txt the boot image's layout (header, kernel, device tree offsets and sizes), so a
                              rebuilt kernel or tree can be put back the same way.

  tools/device_facts.py --rootfs ROOTFS --kernel KERNEL_IMAGE [--out captures]

ROOTFS is the extracted rootfs directory (e.g. ~/partycade-dumps/2026-10-23_raw_plug3032slc/rootfs).
KERNEL_IMAGE is the kernel inside the boot partition (zImage or Image, gzip-wrapped or not); the tool
also accepts boot.img and searches it.
"""
import argparse
import gzip
import hashlib
import io
import os
import re
import subprocess
import sys
import zlib

WIFI = ["cfg80211", "mac80211", "nl80211", "rtl8xxxu", "rtl8192cu", "rtl8188eu", "r8188eu", "8188eu", "8192cu",
        "8812au", "8821cu", "rtw88", "rtl8187", "rt2800usb", "rt2x00", "mt7601u", "mt76x0u", "mt76x2u", "ath9k_htc",
        "carl9170", "brcmfmac", "zd1211rw", "ar5523", "rsi_usb", "wpa", "WEXT", "cfg80211_scan", "ieee80211"]
NET = ["usbnet", "cdc_ether", "rndis_host", "asix", "ax88179", "r8152", "smsc95xx", "cdc_ncm", "g_ether", "rndis",
       "usb_f_rndis", "usb_f_ecm", "usb_f_fs", "configfs", "dwc2", "ehci", "ohci", "usb-storage", "uas"]
STORAGE = ["dw_mmc", "dw_mmc-rockchip", "mmc_block", "vfat", "msdos", "exfat", "ntfs", "ext2", "ext3", "ext4",
           "squashfs", "fuse", "f2fs", "nls_cp437", "nls_iso8859-1", "nls_utf8"]
FLASH = ["rkflash", "rknand", "rk_nand", "sftl", "mtdblock", "mtd", "spinand", "sfc", "blkdev", "by-name"]
GADGET = ["usb_f_fs", "f_fs", "functionfs", "android_usb", "usb_f_adb", "adb", "usb_f_mass_storage", "usb_f_acm",
          "g_serial", "libcomposite", "udc-core", "dwc2_hsotg", "otg"]
OTHER = ["uinput", "evdev", "joydev", "hid-generic", "snd-usb-audio", "snd_usb_audio", "zram", "binfmt_misc",
         "IKCONFIG", "kallsyms", "devtmpfs", "inotify", "epoll", "cgroup", "namespaces"]


def sh(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.stdout


def is_elf(path):
    try:
        with open(path, "rb") as f:
            return f.read(4) == b"\x7fELF"
    except OSError:
        return False


def abi(rootfs, out):
    os.makedirs(out, exist_ok=True)
    index = []
    for top in ("lib", "usr/lib"):
        base = os.path.join(rootfs, top)
        for dirpath, _, files in os.walk(base):
            for f in sorted(files):
                p = os.path.join(dirpath, f)
                if os.path.islink(p) or ".so" not in f or not is_elf(p):
                    continue
                dyn = sh(["readelf", "-dW", p])
                soname = re.search(r"Library soname: \[(.*?)\]", dyn)
                needed = re.findall(r"Shared library: \[(.*?)\]", dyn)
                syms = []
                for line in sh(["readelf", "--dyn-syms", "-W", p]).splitlines():
                    parts = line.split()
                    # Num Value Size Type Bind Vis Ndx Name
                    if len(parts) >= 8 and parts[6] != "UND" and parts[4] in ("GLOBAL", "WEAK") and parts[3] in ("FUNC", "OBJECT", "IFUNC", "TLS", "NOTYPE"):
                        syms.append(f"{parts[3]} {parts[4]} {parts[2]} {parts[7]}")
                rel = os.path.relpath(p, rootfs)
                name = rel.replace("/", "_")
                with open(os.path.join(out, name + ".txt"), "w") as fo:
                    fo.write(f"path /{rel}\nsoname {soname.group(1) if soname else '-'}\n")
                    for n in needed:
                        fo.write(f"needed {n}\n")
                    for s_ in sorted(set(syms)):
                        fo.write(f"sym {s_}\n")
                data = open(p, "rb").read()
                index.append(f"/{rel} {soname.group(1) if soname else '-'} {len(data)} {hashlib.sha256(data).hexdigest()}")
    # Links matter too: the loader resolves SONAMEs through them.
    for top in ("lib", "usr/lib"):
        base = os.path.join(rootfs, top)
        for dirpath, _, files in os.walk(base):
            for f in sorted(files):
                p = os.path.join(dirpath, f)
                if os.path.islink(p) and ".so" in f:
                    index.append(f"/{os.path.relpath(p, rootfs)} -> {os.readlink(p)}")
    with open(os.path.join(out, "INDEX.txt"), "w") as fo:
        fo.write("\n".join(sorted(index)) + "\n")
    print(f"abi: {len([i for i in index if '->' not in i])} libraries -> {out}")


def kernel_blobs(path):
    """The image, plus every gzip stream inside it that decompresses (a zImage carries its kernel that way)."""
    raw = open(path, "rb").read()
    blobs = [raw]
    for m in re.finditer(b"\x1f\x8b\x08", raw):
        try:
            d = zlib.decompressobj(16 + zlib.MAX_WBITS).decompress(raw[m.start():m.start() + 64 * 1024 * 1024])
            if len(d) > 1024 * 1024:
                blobs.append(d)
        except zlib.error:
            pass
    return blobs


def kernel(path, out):
    os.makedirs(out, exist_ok=True)
    blobs = kernel_blobs(path)
    text = b"\n".join(blobs)
    ver = re.search(rb"Linux version [^\n\x00]{10,300}", text)
    with open(os.path.join(out, "version.txt"), "w") as f:
        f.write((ver.group(0).decode("ascii", "replace") if ver else "not found") + "\n")
    cfg = None
    for b in blobs:
        i = b.find(b"IKCFG_ST")
        if i >= 0:
            j = b.find(b"IKCFG_ED", i)
            try:
                cfg = gzip.decompress(b[i + 8:j]).decode("ascii", "replace")
            except OSError:
                pass
            break
    with open(os.path.join(out, "config.txt"), "w") as f:
        f.write(cfg if cfg else "# The image carries no config (no IKCFG_ST). drivers.txt is the string search instead.\n")
    strs = set(re.findall(rb"[\x20-\x7e]{4,}", text))
    # Loadable modules: the version string a module must carry (vermagic), and whether the kernel checks
    # symbol checksums (CONFIG_MODVERSIONS, seen as the module_layout symbol). These decide whether a Wi-Fi
    # driver can be added as a module built against Rockchip's 4.4 source, instead of a new kernel.
    vm = sorted({m.decode() for m in re.findall(rb"\d+\.\d+\.\d+[\w.+-]* SMP[\w ]*mod_unload[\w ]*", text)})
    with open(os.path.join(out, "modules.txt"), "w") as f:
        f.write("vermagic: " + (" | ".join(vm) if vm else "not found") + "\n")
        f.write("module_layout (CONFIG_MODVERSIONS): " + ("present" if b"module_layout" in text else "absent") + "\n")
        f.write("init_module / finit_module syscalls named: " +
                ("present" if (b"finit_module" in text or b"sys_init_module" in text) else "absent") + "\n")
    lines = []
    for group, names in (("wifi", WIFI), ("usb-net", NET), ("storage", STORAGE), ("flash", FLASH),
                        ("gadget", GADGET), ("other", OTHER)):
        for n in names:
            hit = any(n.encode() in s_ for s_ in strs)
            lines.append(f"{group:8} {n:20} {'present' if hit else 'absent'}")
    with open(os.path.join(out, "drivers.txt"), "w") as f:
        f.write("# A name found anywhere in the kernel image's strings. 'present' is a strong hint, not proof that\n"
                "# the driver is built in; config.txt, when there is one, is the authority.\n")
        f.write("\n".join(lines) + "\n")
    print(f"kernel: {ver.group(0)[:60].decode() if ver else 'no banner'}; config {'yes' if cfg else 'no'} -> {out}")


def bootimg(path, out):
    """Where things are inside the boot image: its header, each gzip stream, each device tree."""
    raw = open(path, "rb").read()
    lines = [f"file {os.path.basename(path)}: {len(raw)} bytes, sha256 {hashlib.sha256(raw).hexdigest()}",
             f"first 16 bytes: {raw[:16].hex()}  {raw[:8]!r}"]
    if raw[:8] == b"ANDROID!":
        import struct
        ks, ka, rs, ra, ss, sa, ta, ps = struct.unpack_from("<8I", raw, 8)
        lines.append(f"android boot header: kernel {ks} bytes at load 0x{ka:x}, ramdisk {rs} at 0x{ra:x}, "
                     f"second {ss} at 0x{sa:x}, tags 0x{ta:x}, page size {ps}")
        lines.append("cmdline: " + raw[64:64 + 512].split(b"\0")[0].decode("ascii", "replace"))
    for tag in (b"KRNL", b"RSCE", b"LOADER"):
        i = raw.find(tag)
        if 0 <= i < 1024 * 1024:
            lines.append(f"tag {tag.decode()} at 0x{i:x}")
    for m in re.finditer(b"\x1f\x8b\x08", raw):
        try:
            d = zlib.decompressobj(16 + zlib.MAX_WBITS)
            n = len(d.decompress(raw[m.start():m.start() + 64 * 1024 * 1024]))
            if n > 4096:
                lines.append(f"gzip stream at 0x{m.start():x}: {len(raw[m.start():]) - len(d.unused_data)} bytes -> {n}")
        except zlib.error:
            pass
    for m in re.finditer(b"\xd0\x0d\xfe\xed", raw):
        size = int.from_bytes(raw[m.start() + 4:m.start() + 8], "big")
        if 256 < size < 1024 * 1024:
            model = re.search(rb"rockchip,[a-z0-9,-]+", raw[m.start():m.start() + size])
            lines.append(f"device tree at 0x{m.start():x}: {size} bytes {model.group(0).decode() if model else ''}")
    os.makedirs(out, exist_ok=True)
    open(os.path.join(out, "bootimg.txt"), "w").write("\n".join(lines) + "\n")


SYSTEM_FILES = ["etc/inittab", "etc/fstab", "etc/profile", "etc/hostname", "etc/network/interfaces",
                "etc/init.d/.usb_config", "etc/securetty", "etc/shells", "etc/mdev.conf", "etc/passwd", "etc/group"]
SYSTEM_DIRS = ["etc/init.d", "etc/udev/rules.d", "lib/udev/rules.d", "etc/dropbear", "etc/network", "etc/default",
               "usr/share/udhcpc", "etc/wpa_supplicant", "etc/profile.d"]


def system(rootfs, out):
    """The rootfs's configuration text: small files only, and never a password hash."""
    os.makedirs(out, exist_ok=True)
    picked = set(SYSTEM_FILES)
    for d in SYSTEM_DIRS:
        full = os.path.join(rootfs, d)
        if os.path.isdir(full):
            for f in sorted(os.listdir(full)):
                picked.add(os.path.join(d, f))
    for extra in ("usr/bin/usbdevice", "lib/udev/mtd_probe"):
        picked.add(extra)
    index = []
    for rel in sorted(picked):
        src = os.path.join(rootfs, rel)
        if os.path.islink(src):
            index.append(f"{rel} -> {os.readlink(src)}")
            continue
        if not os.path.isfile(src):
            continue
        data = open(src, "rb").read()
        if b"\0" in data[:4096] or len(data) > 64 * 1024 or "dropbear" in rel and "key" in rel:
            index.append(f"{rel}: {len(data)} bytes, binary or a key, not copied")
            continue
        dst = os.path.join(out, rel.replace("/", "_"))
        open(dst, "wb").write(data)
        index.append(f"{rel}: {len(data)} bytes -> {os.path.basename(dst)}")
    shadow = os.path.join(rootfs, "etc", "shadow")
    if os.path.isfile(shadow):
        states = []
        for line in open(shadow, errors="replace"):
            parts = line.strip().split(":")
            if len(parts) > 1:
                pw = parts[1]
                state = "empty (no password)" if pw == "" else "locked" if pw.startswith(("!", "*")) else "set"
                states.append(f"{parts[0]}: {state}")
        open(os.path.join(out, "shadow-state.txt"), "w").write("\n".join(states) + "\n")
        index.append("etc/shadow: password state only -> shadow-state.txt")
    bb = os.path.join(rootfs, "bin", "busybox")
    if os.path.isfile(bb):
        links = sorted(os.path.relpath(os.path.join(dp, f), rootfs) for dp, _, fs in os.walk(rootfs) for f in fs
                       if os.path.islink(os.path.join(dp, f)) and os.readlink(os.path.join(dp, f)).endswith("busybox"))
        open(os.path.join(out, "busybox-applets.txt"), "w").write("\n".join(links) + "\n")
    open(os.path.join(out, "INDEX.txt"), "w").write("\n".join(index) + "\n")
    print(f"system: {len(index)} entries -> {out}")


def strings_of(path, pattern):
    data = open(path, "rb").read()
    return sorted({s_.decode() for s_ in re.findall(rb"[\x20-\x7e]{4,}", data) if re.search(pattern, s_)})


def gl_sdl(rootfs, out):
    gl = os.path.join(out, "gl")
    os.makedirs(gl, exist_ok=True)
    mali = [os.path.join(dp, f) for dp, _, fs in os.walk(os.path.join(rootfs, "usr/lib")) for f in fs
            if f.startswith("libmali") and not os.path.islink(os.path.join(dp, f))]
    lines = []
    for m in mali:
        lines.append(f"# {os.path.relpath(m, rootfs)}")
        lines += strings_of(m, rb"^(GL_|EGL_|OpenGL ES|EGL [0-9]|Mali|r[0-9]p[0-9])")
    open(os.path.join(gl, "strings.txt"), "w").write("\n".join(lines) + "\n")
    sdl = os.path.join(out, "sdl")
    os.makedirs(sdl, exist_ok=True)
    lib = [os.path.join(dp, f) for dp, _, fs in os.walk(os.path.join(rootfs, "usr/lib")) for f in fs
           if f.startswith("libSDL2-2.0.so") and not os.path.islink(os.path.join(dp, f))]
    lines = []
    for p in lib:
        lines.append(f"# {os.path.relpath(p, rootfs)}")
        lines += strings_of(p, rb"^(KMSDRM|kmsdrm|opengles2?|opengl|software|alsa|pulseaudio|dummy|disk|evdev|udev|offscreen|SDL_VIDEO_|SDL_AUDIO|SDL_RENDER|libGLESv2|libEGL|libgbm|libdrm|libasound|libudev)")
    open(os.path.join(sdl, "strings.txt"), "w").write("\n".join(lines) + "\n")
    print(f"gl: {len(mali)} mali libraries; sdl: {len(lib)} -> {gl}, {sdl}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--rootfs", required=True)
    ap.add_argument("--kernel", help="zImage, Image, or boot.img")
    ap.add_argument("--out", default=os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "captures"))
    a = ap.parse_args()
    if not os.path.isdir(os.path.join(a.rootfs, "usr", "lib")):
        sys.exit(f"{a.rootfs} does not look like the extracted rootfs (no usr/lib)")
    abi(a.rootfs, os.path.join(a.out, "abi"))
    gl_sdl(a.rootfs, a.out)
    system(a.rootfs, os.path.join(a.out, "system"))
    if a.kernel:
        kernel(a.kernel, os.path.join(a.out, "kernel"))
        bootimg(a.kernel, os.path.join(a.out, "kernel"))
    print("Done. These are facts and config text, not vendor programs: commit captures/abi, captures/kernel, "
          "captures/gl, captures/sdl, captures/system.")


if __name__ == "__main__":
    main()
