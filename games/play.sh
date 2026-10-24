#!/usr/bin/env bash
# Drive Keep, Lamp, and The Yard the way the deck does: a script of the same
# buttons, then read the saves and the pictures. Headless. No cabinet, no flash.
set -euo pipefail
cd "$(dirname "$0")"
make -s TARGET=pc
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy SDL_HINT_RENDER_VSYNC=0

root=$(pwd)
out="$root/out/play"
rm -rf "$out"
mkdir -p "$out"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

python3 - "$out" "$tmp/session.cab" << 'PY'
import sys
out, path = sys.argv[1], sys.argv[2]
lines = []

def emit(title, holds, shots, quit_at):
    lines.append(f"title={title}")
    prev = set()
    for frame, held in enumerate(holds):
        for name in sorted(held - prev):
            lines.append(f"{frame} down {name}")
        for name in sorted(prev - held):
            lines.append(f"{frame} up {name}")
        prev = set(held)
        if frame in shots:
            lines.append(f"{frame} shot {shots[frame]}")
    for name in sorted(prev):
        lines.append(f"{quit_at} up {name}")
    lines.append(f"{quit_at} quit")

# Keep. glibc rand() with the default seed, same calls drop() makes: 79, then 110.
# Paddle starts at x=102. Eight frames of LEFT park it under the first tile.
# After the catch, a short LEFT dodges the second tile so the score stays 1.
rands = [79, 110, 17, 27, 121, 39]
ri = 0
W, PW, H, PH = 240, 36, 320, 8
px, py = (W - PW) // 2, H - 28
ix = iy = alive = score = over = 0
catch_at = miss_at = None

def drop():
    global ix, iy, ri
    ix, iy = rands[ri], 28
    ri += 1

holds = []
for frame in range(500):
    b = set()
    if frame == 5:
        b.add("LOW")
    if 6 <= frame <= 13 or (score >= 1 and px > 66):
        b.add("LEFT")
    holds.append(b)
    if "LEFT" in b:
        px -= 3
    if "RIGHT" in b:
        px += 3
    px = max(4, min(W - PW - 4, px))
    pressed = "LOW" in b and (frame == 0 or "LOW" not in holds[frame - 1])
    if not alive and pressed:
        px, py, score, over = (W - PW) // 2, H - 28, 0, 0
        drop()
        alive = 1
    if alive and not over:
        iy += 2
        if iy + 8 >= py and iy <= py + PH and ix + 8 >= px and ix <= px + PW:
            score += 1
            if catch_at is None:
                catch_at = frame
            drop()
        elif iy > H - 12:
            over, alive = 1, 0
            miss_at = frame
            break
else:
    raise SystemExit("keep: the tile never missed")
if score != 1 or catch_at is None:
    raise SystemExit(f"keep sim score {score} catch {catch_at} miss {miss_at}")
print(f"keep sim: catch frame {catch_at}, miss frame {miss_at}, score {score}")
emit("Keep", holds, {
    2: f"{out}/keep-title.bmp",
    catch_at: f"{out}/keep-catch.bmp",
    miss_at: f"{out}/keep-miss.bmp",
}, miss_at + 2)

# Lamp. Step 2, same clamps as lamp.c. The light starts on the center star.
stars = [(120, 160), (48, 70), (190, 64), (36, 150), (200, 168), (70, 240), (176, 250)]
px, py = 116, 156
lit = [False] * 7
holds = []
done_at = None

def near(i):
    dx, dy = px + 4 - stars[i][0], py + 4 - stars[i][1]
    return dx * dx + dy * dy < 18 * 18

def light():
    for i in range(7):
        if not lit[i] and near(i):
            lit[i] = True

for frame in range(2000):
    light()
    if all(lit):
        done_at = frame
        holds.append(set())
        break
    best_i, best_d = None, None
    for i in range(7):
        if lit[i]:
            continue
        d = (px + 4 - stars[i][0]) ** 2 + (py + 4 - stars[i][1]) ** 2
        if best_d is None or d < best_d:
            best_d, best_i = d, i
    tx, ty = stars[best_i]
    b = set()
    if tx > px + 5:
        b.add("RIGHT")
    elif tx < px + 3:
        b.add("LEFT")
    if ty > py + 5:
        b.add("DOWN")
    elif ty < py + 3:
        b.add("UP")
    holds.append(b)
    if "LEFT" in b:
        px -= 2
    if "RIGHT" in b:
        px += 2
    if "UP" in b:
        py -= 2
    if "DOWN" in b:
        py += 2
    px = max(8, min(224, px))
    py = max(70, min(292, py))
else:
    raise SystemExit(f"lamp sim stuck, lit {sum(lit)}")
print(f"lamp sim: all 7 lit at frame {done_at}")
emit("Lamp", holds, {2: f"{out}/lamp-start.bmp", done_at: f"{out}/lamp-awake.bmp"}, done_at + 8)

lines.append("title=The Yard")
lines += [
    f"2 shot {out}/yard-row0.bmp",
    "6 down DOWN",
    "7 up DOWN",
    f"10 shot {out}/yard-row1.bmp",
    "14 down LOW",
    "15 up LOW",
    f"18 shot {out}/yard-back.bmp",
    "20 quit",
]
open(path, "w").write("\n".join(lines) + "\n")
PY

# observe scripts sit next to the shots, outside the save directory
cat > "$out/observe-keep.cab" << EOF
title=Keep
3 shot $out/keep-remembered.bmp
5 quit
EOF
cat > "$out/observe-yard.cab" << EOF
title=The Yard
3 shot $out/yard-remembered.bmp
5 quit
EOF

card=$tmp/card
mkdir -p "$card"
printf 'pocket\n' > "$card/label"
export CAB_EXT=$card

run() {
    local name=$1 script=$2
    echo "== $name =="
    ( cd "$tmp" && CAB_SCRIPT="$script" CAB_SCRIPT_LOG=1 CAB_MAX_FRAMES=5000 CAB_SCALE=1 \
        "$root/out/pc/$name" )
}

run keep "$tmp/session.cab"
echo "keep.sav: $(cat "$tmp/keep.sav")"
grep -qx 'best 1' "$tmp/keep.sav"
run keep "$out/observe-keep.cab"
echo "keep.sav still: $(cat "$tmp/keep.sav")"
grep -qx 'best 1' "$tmp/keep.sav"

run yard "$tmp/session.cab"
echo "lamp.sav: $(cat "$tmp/lamp.sav")"
echo "yard.sav: $(cat "$tmp/yard.sav")"
echo "card visited: $(cat "$card/visited")"
grep -qx 'best 7' "$tmp/lamp.sav"
grep -qx 'best 1' "$tmp/yard.sav"
grep -qx 'yard' "$card/visited"
run yard "$out/observe-yard.cab"
grep -qx 'best 1' "$tmp/yard.sav"

cat > "$out/orb.cab" << EOF
title=Orb
12 shot $out/orb.bmp
14 quit
EOF
cat > "$out/orb-raw.cab" << EOF
title=Orb
6 shot $out/orb-raw.bmp
8 quit
EOF
echo "== orb =="
( cd "$tmp" && SDL_VIDEODRIVER=offscreen CAB_SCRIPT="$out/orb.cab" CAB_SCRIPT_LOG=1 \
    CAB_MAX_FRAMES=40 CAB_SCALE=1 "$root/out/pc/orb" )
grep -q 'pocket' "$card/orb-card"
echo "== orb framebuffer =="
( cd "$tmp" && SDL_VIDEODRIVER=offscreen CAB_RAW_FB=1 CAB_SCRIPT="$out/orb-raw.cab" \
    CAB_MAX_FRAMES=20 CAB_SCALE=1 "$root/out/pc/orb" )

python3 - "$out" << 'PY'
import struct, sys, zlib
out = sys.argv[1]

def load(name):
    d = open(f"{out}/{name}.bmp", "rb").read()
    if d[:2] != b"BM":
        raise SystemExit(f"{name}: not a bmp")
    off = struct.unpack_from("<I", d, 10)[0]
    w, h = struct.unpack_from("<ii", d, 18)
    bpp = struct.unpack_from("<H", d, 28)[0]
    W, H = abs(w), abs(h)
    if (W, H) != (240, 320):
        raise SystemExit(f"{name}: {W}x{H}, expected 240x320")
    stride = ((W * (bpp // 8) + 3) & ~3)
    def pix(x, y):
        row = (H - 1 - y) if h > 0 else y
        i = off + row * stride + x * (bpp // 8)
        b, g, r = d[i], d[i + 1], d[i + 2]
        return r, g, b
    return W, H, pix, d, off, bpp, h

def png(name):
    W, H, pix, *_ = load(name)
    raw = bytearray()
    for y in range(H):
        raw.append(0)
        for x in range(W):
            raw += bytes(pix(x, y))
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    ihdr = struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)
    blob = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    open(f"{out}/{name}.png", "wb").write(blob)

def gold(pix, x, y):
    r, g, b = pix(x, y)
    return r > 220 and 160 < g < 230 and b < 120

# Lantern is the 6x6 block at x=18, y = 114 + row*36.
for name, row in (("yard-row0", 0), ("yard-row1", 1), ("yard-back", 1), ("yard-remembered", 1)):
    _, _, pix, *_ = load(name)
    y = 116 + row * 36
    other = 116 + (1 - row) * 36
    if not gold(pix, 20, y):
        raise SystemExit(f"{name}: lantern not on row {row}")
    if gold(pix, 20, other):
        raise SystemExit(f"{name}: lantern also on the other row")
    png(name)
    print(f"{name}: lantern on row {row}")

_, _, pix, *_ = load("keep-catch")
# Green tile, or the yellow paddle, must be on screen. The title bar is red.
seen_green = seen_paddle = False
for y in range(0, 320, 2):
    for x in range(0, 240, 2):
        r, g, b = pix(x, y)
        if g > 180 and r < 120 and b > 80:
            seen_green = True
        if r > 200 and g > 180 and b < 120:
            seen_paddle = True
if not (seen_green and seen_paddle):
    raise SystemExit(f"keep-catch missing tile or paddle (green {seen_green} paddle {seen_paddle})")
png("keep-catch")
png("keep-remembered")
png("lamp-awake")
png("keep-title")
png("keep-miss")
png("lamp-start")
_, _, pix, *_ = load("yard-row0")
r, g, b = pix(224, 304)
if not (r < 80 and g > 180 and b > 180):
    raise SystemExit(f"yard pocket mark missing at (224,304): {(r, g, b)}")
print("pocket mark on the yard")
print("pictures ok")
PY

python3 - "$out" << 'PY'
import struct, sys
out = sys.argv[1]

def load(name, expect):
    d = open(f"{out}/{name}.bmp", "rb").read()
    off = struct.unpack_from("<I", d, 10)[0]
    w, h = struct.unpack_from("<ii", d, 18)
    bpp = struct.unpack_from("<H", d, 28)[0]
    W, H = abs(w), abs(h)
    if (W, H) != expect:
        raise SystemExit(f"{name}: {W}x{H}, expected {expect[0]}x{expect[1]}")
    stride = ((W * (bpp // 8) + 3) & ~3)
    def pix(x, y):
        row = (H - 1 - y) if h > 0 else y
        i = off + row * stride + x * (bpp // 8)
        return d[i + 2], d[i + 1], d[i]
    return W, H, pix

W, H, pix = load("orb", (384, 512))
r, g, b = pix(W // 2, H // 2)
print(f"orb center {(r, g, b)}")
# Frame 12 shows the gold face and the purple side. Lambert keeps them
# dimmer than the vertex colors, so the test matches the lit pixels.
gold = purple = 0
for y in range(30, H - 30, 2):
    for x in range(0, W, 2):
        r, g, b = pix(x, y)
        if r > 120 and g > 80 and b < 80 and r > b + 40:
            gold += 1
        if b > 70 and b > r + 20 and b > g and r < 100:
            purple += 1
print(f"orb gold {gold} purple {purple}")
if gold < 200 or purple < 80:
    raise SystemExit("orb cube is not on screen")
# The top bar is the rotation marker and should be red in the upright view.
r, g, b = pix(W // 2, 4)
if not (r > 160 and g < 100 and b < 100):
    raise SystemExit(f"orb top bar not red: {(r, g, b)}")
print("orb room is on screen")

W, H, pix = load("orb-raw", (1024, 768))
reds, blues = [], []
for y in range(0, H, 4):
    for x in range(0, W, 4):
        r, g, b = pix(x, y)
        if r > 180 and g < 90 and b < 90:
            reds.append(x)
        elif b > 150 and r < 90 and g < 140:
            blues.append(x)
if len(reds) < 10 or len(blues) < 10:
    raise SystemExit(f"orb rotation bars missing (red {len(reds)} blue {len(blues)})")
rm, bm = sum(reds) / len(reds), sum(blues) / len(blues)
print(f"orb raw red mean x {rm:.0f}  blue mean x {bm:.0f}")
if not (rm < W * 0.35 and bm > W * 0.65):
    raise SystemExit("orb rotation is wrong")
print("orb rotation ok")
PY
echo "play ok  shots in $out"
