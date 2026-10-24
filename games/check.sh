#!/usr/bin/env bash
# PC checks for the simulator: the probe still quits, Keep scores a catch and
# writes keep.sav, and the cabinet framebuffer rotation puts the top of the
# upright image on the left of the 1024x768 frame.
set -euo pipefail
cd "$(dirname "$0")"
make TARGET=pc
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "== probe self-test =="
( cd "$tmp" && PROBE_SELFTEST=1 CAB_SCREENSHOT="$tmp/probe.bmp" "$OLDPWD/out/pc/probe" )
test -s "$tmp/probe.bmp"

echo "== keep, upright =="
(
  cd "$tmp"
  KEEP_SELFTEST=1 CAB_SCREENSHOT="$tmp/keep-upright.bmp" CAB_SCALE=1 \
    "$OLDPWD/out/pc/keep"
  grep -q '^best ' keep.sav
  echo "keep.sav: $(cat keep.sav)"
)

echo "== lamp =="
( cd "$tmp" && LAMP_SELFTEST=1 "$OLDPWD/out/pc/lamp" && grep -q '^best ' lamp.sav && echo "lamp.sav: $(cat lamp.sav)" )

echo "== yard launches keep =="
( cd "$tmp" && YARD_ONCE=keep KEEP_SELFTEST=1 "$OLDPWD/out/pc/yard" )

echo "== keep, raw framebuffer rotation =="
( cd "$tmp" && KEEP_SELFTEST=1 CAB_RAW_FB=1 CAB_SCREENSHOT="$tmp/keep-fb.bmp" CAB_SCREENSHOT_FRAME=3 \
  "$OLDPWD/out/pc/keep" )
python3 - "$tmp/keep-fb.bmp" << 'PY'
import struct, sys
p = sys.argv[1]
d = open(p, "rb").read()
if d[:2] != b"BM":
    raise SystemExit("not a bmp")
off = struct.unpack_from("<I", d, 10)[0]
w, h = struct.unpack_from("<ii", d, 18)
bpp = struct.unpack_from("<H", d, 28)[0]
W, H = abs(w), abs(h)
if W != 1024 or H != 768:
    raise SystemExit(f"framebuffer shot is {w}x{h}, expected 1024x768")
if bpp not in (24, 32):
    raise SystemExit(f"bpp {bpp}")
stride = ((W * (bpp // 8) + 3) & ~3)
def pix(x, y):
    row = (H - 1 - y) if h > 0 else y
    i = off + row * stride + x * (bpp // 8)
    b, g, r = d[i], d[i+1], d[i+2]
    return r, g, b
reds, blues = [], []
for y in range(0, H, 4):
    for x in range(0, W, 4):
        r, g, b = pix(x, y)
        if r > 180 and g < 90 and b < 90:
            reds.append(x)
        elif b > 150 and r < 90 and g < 140:
            blues.append(x)
if len(reds) < 10 or len(blues) < 10:
    raise SystemExit(f"marker bars missing (red {len(reds)} blue {len(blues)})")
rm, bm = sum(reds)/len(reds), sum(blues)/len(blues)
print(f"red mean x {rm:.0f}  blue mean x {bm:.0f}  ({W}x{H})")
# Top of the upright image (red) has to land on the left of the framebuffer.
if not (rm < W * 0.35 and bm > W * 0.65):
    raise SystemExit("rotation is wrong: red (game top) should be on the left, blue (game bottom) on the right")
if rm > bm:
    raise SystemExit("rotation is mirrored")
print("rotation ok")
PY
echo "ok"
