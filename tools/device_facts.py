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
    lines = []
    for group, names in (("wifi", WIFI), ("usb-net", NET), ("storage", STORAGE), ("other", OTHER)):
        for n in names:
            hit = any(n.encode() in s_ for s_ in strs)
            lines.append(f"{group:8} {n:20} {'present' if hit else 'absent'}")
    with open(os.path.join(out, "drivers.txt"), "w") as f:
        f.write("# A name found anywhere in the kernel image's strings. 'present' is a strong hint, not proof that\n"
                "# the driver is built in; config.txt, when there is one, is the authority.\n")
        f.write("\n".join(lines) + "\n")
    print(f"kernel: {ver.group(0)[:60].decode() if ver else 'no banner'}; config {'yes' if cfg else 'no'} -> {out}")


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
    if a.kernel:
        kernel(a.kernel, os.path.join(a.out, "kernel"))
    print("Done. These are facts, not vendor code: commit captures/abi, captures/kernel, captures/gl, captures/sdl.")


if __name__ == "__main__":
    main()
