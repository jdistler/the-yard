#!/usr/bin/env bash
# Play Keep, Lamp, Orb, Tea, and The Yard past the happy path. Headless. No cabinet.
set -euo pipefail
cd "$(dirname "$0")"
make -s TARGET=pc
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy SDL_HINT_RENDER_VSYNC=0

root=$(pwd)
out="$root/out/stress"
rm -rf "$out"
mkdir -p "$out"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

python3 - "$out" "$tmp" << 'PY'
import ctypes, sys
out, tmp = sys.argv[1], sys.argv[2]
libc = ctypes.CDLL("libc.so.6")
libc.srand.argtypes = [ctypes.c_uint]
libc.rand.restype = ctypes.c_int

def emit(title, holds, shots, quit_at):
    lines = [f"title={title}"]
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
    return lines

def keep_run(fast, catches, mode):
    libc.srand(1)
    step = 6 if fast else 3
    fall = 4 if fast else 2
    W, PW, H, PH = 240, 36, 320, 8
    px, py = (W - PW) // 2, H - 28
    ix = iy = alive = score = over = 0
    holds = []
    catch_at = miss_at = None

    def drop():
        nonlocal ix, iy
        ix = 8 + libc.rand() % (W - 16)
        iy = 28

    frame = 0
    while frame < 8000:
        b = set()
        if not alive and frame == 2:
            b.add("LOW")
        elif alive and not over and mode == "miss" and score >= catches:
            b.add("LEFT" if ix >= 120 else "RIGHT")
        elif alive and not over and score < catches:
            target = max(4, min(W - PW - 4, ix - PW // 2))
            if px + 2 < target:
                b.add("RIGHT")
            elif px - 2 > target:
                b.add("LEFT")
        holds.append(b)
        if alive:
            if "LEFT" in b:
                px -= step
            if "RIGHT" in b:
                px += step
            px = max(4, min(W - PW - 4, px))
        prev = holds[frame - 1] if frame else set()
        if not alive and "LOW" in b and "LOW" not in prev:
            px, py, score, over = (W - PW) // 2, H - 28, 0, 0
            drop()
            alive = 1
        if alive and not over:
            iy += fall
            if iy + 8 >= py and iy <= py + PH and ix + 8 >= px and ix <= px + PW:
                score += 1
                if catch_at is None:
                    catch_at = frame
                drop()
                if mode == "quit" and score >= catches:
                    for _ in range(6):
                        holds.append(set())
                    return holds, score, catch_at, None
            elif iy > H - 12:
                over = alive = 0
                miss_at = frame
                if score != catches:
                    raise SystemExit(f"keep sim {mode} fast={fast} scored {score}, wanted {catches}")
                return holds, score, catch_at, miss_at
        frame += 1
    raise SystemExit(f"keep sim {mode} fast={fast} did not finish, score {score}")

def write_keep(path, fast, catches, mode, shots):
    holds, score, catch_at, miss_at = keep_run(fast, catches, mode)
    quit_at = (miss_at if miss_at is not None else len(holds) - 1) + 2
    mapped = {}
    if "catch" in shots and catch_at is not None:
        mapped[catch_at] = shots["catch"]
    if "miss" in shots and miss_at is not None:
        mapped[miss_at] = shots["miss"]
    open(path, "w").write("\n".join(emit("Keep", holds, mapped, quit_at)) + "\n")
    print(f"keep {mode} fast={fast}: score {score} catch {catch_at} miss {miss_at} frames {len(holds)}")
    return score

# A round that never catches writes no file. First tile is x=79, paddle stays at 102.
holds = [set() for _ in range(150)]
holds[0].add("LOW")
open(f"{tmp}/zero.cab", "w").write("\n".join(emit("Keep", holds, {145: f"{out}/keep-zero.bmp"}, 148)) + "\n")

score_quit = write_keep(f"{tmp}/quit.cab", False, 3, "quit", {})
open(f"{tmp}/quit.expect", "w").write(str(score_quit))
open(f"{tmp}/keep-remember.cab", "w").write("title=Keep\n2 quit\n")
score_fast = write_keep(f"{tmp}/fast.cab", True, 4, "miss", {})
open(f"{tmp}/fast.expect", "w").write(str(score_fast))
score_long = write_keep(f"{tmp}/long.cab", False, 12, "miss", {"catch": f"{out}/keep-long-catch.bmp", "miss": f"{out}/keep-long-miss.bmp"})
write_keep(f"{tmp}/audio.cab", False, 1, "quit", {})
open(f"{tmp}/long.expect", "w").write(str(score_long))

# Title screen: stick must not slide the paddle. Wall: LEFT pins it at x=4.
# Opposed directions cancel. Out-of-order lines: frame 10's up beats frame 3's down.
open(f"{tmp}/title.cab", "w").write("""title=Keep
0 down RIGHT
40 shot %s/keep-title.bmp
42 quit
""" % out)
open(f"{tmp}/wall.cab", "w").write("""title=Keep
1 down LOW
2 up LOW
2 down LEFT
55 shot %s/keep-wall.bmp
57 quit
""" % out)
open(f"{tmp}/oppose.cab", "w").write("""title=Keep
1 down LOW
2 up LOW
2 down LEFT
2 down RIGHT
40 shot %s/keep-oppose.bmp
42 quit
""" % out)
open(f"{tmp}/order.cab", "w").write("""title=Keep
1 down LOW
2 up LOW
10 up LEFT
3 down LEFT
12 shot %s/keep-order.bmp
14 quit
""" % out)
open(f"{tmp}/combo.cab", "w").write("""title=Keep
0 down 1P
0 down 2P
90 shot %s/keep-quit-late.bmp
120 quit
""" % out)

stars = [(120, 160), (48, 70), (190, 64), (36, 150), (200, 168), (70, 240), (176, 250)]

def lamp_run(step, stop_at):
    px, py = 116, 156
    lit = [False] * 7
    score = 0
    holds = []
    done_at = None
    for frame in range(4000):
        b = set()
        if not all(lit) and (stop_at is None or score < stop_at):
            best_i, best_d = None, None
            for i in range(7):
                if lit[i]:
                    continue
                d = (px + 4 - stars[i][0]) ** 2 + (py + 4 - stars[i][1]) ** 2
                if best_d is None or d < best_d:
                    best_d, best_i = d, i
            tx, ty = stars[best_i]
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
            px -= step
        if "RIGHT" in b:
            px += step
        if "UP" in b:
            py -= step
        if "DOWN" in b:
            py += step
        px = max(8, min(224, px))
        py = max(70, min(292, py))
        for i in range(7):
            if lit[i]:
                continue
            dx, dy = px + 4 - stars[i][0], py + 4 - stars[i][1]
            if dx * dx + dy * dy < 18 * 18:
                lit[i] = True
                score += 1
        if stop_at is not None and score >= stop_at:
            for _ in range(4):
                holds.append(set())
                for i in range(7):
                    if lit[i]:
                        continue
                    dx, dy = px + 4 - stars[i][0], py + 4 - stars[i][1]
                    if dx * dx + dy * dy < 18 * 18:
                        lit[i] = True
                        score += 1
            return holds, score, None
        if all(lit):
            done_at = frame
            return holds, score, done_at
    raise SystemExit(f"lamp sim stuck step {step} score {score}")

holds, partial, _ = lamp_run(2, 2)
open(f"{tmp}/lamp-partial.cab", "w").write("\n".join(emit("Lamp", holds, {}, len(holds) + 1)) + "\n")
open(f"{tmp}/lamp-partial.expect", "w").write(str(partial))
print(f"lamp partial score {partial}")
if not 2 <= partial < 7:
    raise SystemExit(f"lamp partial unexpected {partial}")

holds, full, done_at = lamp_run(2, None)
# Two still frames, then Z, then a look at the fresh trip.
extra_at = len(holds)
for _ in range(2):
    holds.append(set())
low_at = len(holds)
holds.append({"LOW"})
for _ in range(4):
    holds.append(set())
reset_at = len(holds) - 1
open(f"{tmp}/lamp-full.cab", "w").write("\n".join(emit("Lamp", holds, {
    done_at: f"{out}/lamp-awake.bmp",
    reset_at: f"{out}/lamp-reset.bmp",
}, len(holds) + 1)) + "\n")
print(f"lamp full at {done_at}, reset shot {reset_at}")

holds, fast_score, _ = lamp_run(4, None)
open(f"{tmp}/lamp-fast.cab", "w").write("\n".join(emit("Lamp", holds, {}, len(holds) + 1)) + "\n")
print(f"lamp fast score {fast_score}")
if fast_score != 7:
    raise SystemExit("lamp fast sim did not light every star")

# Orb across a turn, and the same moment with the stick held.
spin = ["title=Orb"]
for frame in (2, 12, 50, 100, 160, 220):
    spin.append(f"{frame} shot {out}/orb-spin-{frame}.bmp")
spin.append("230 quit")
open(f"{tmp}/orb-spin.cab", "w").write("\n".join(spin) + "\n")
open(f"{tmp}/orb-still.cab", "w").write(f"title=Orb\n40 shot {out}/orb-still.bmp\n42 quit\n")
open(f"{tmp}/orb-yaw.cab", "w").write(f"title=Orb\n0 down RIGHT\n40 shot {out}/orb-yaw.bmp\n42 up RIGHT\n42 quit\n")

# The Yard: cancel up+down, walk every row including the wrap, open Orb, Keep, Lamp.
yard = ["title=The Yard"]
yard += [
    "2 down UP", "2 down DOWN", "3 up UP", "3 up DOWN",
    f"5 shot {out}/yard-row0.bmp",
    "7 down DOWN", "8 up DOWN",
    f"11 shot {out}/yard-row1.bmp",
    "13 down DOWN", "14 up DOWN",
    f"17 shot {out}/yard-row2.bmp",
    "19 down DOWN", "20 up DOWN",
    f"23 shot {out}/yard-row3.bmp",
    "25 down DOWN", "26 up DOWN",
    f"29 shot {out}/yard-wrap0.bmp",
    "31 down UP", "32 up UP",
    f"35 shot {out}/yard-wrap3.bmp",
    "37 down UP", "38 up UP",
    "40 down LOW", "41 up LOW",
    f"44 shot {out}/yard-after-orb.bmp",
    "46 down DOWN", "47 up DOWN",
    "48 down DOWN", "49 up DOWN",
    "52 down LOW", "53 up LOW",
    f"56 shot {out}/yard-after-keep.bmp",
    "58 down DOWN", "59 up DOWN",
    "62 down LOW", "63 up LOW",
    f"66 shot {out}/yard-after-lamp.bmp",
    "68 quit",
]
# One catch inside Keep, then back. Lamp lights all seven. Orb draws and leaves.
kholds, kscore, kcatch, _ = keep_run(False, 1, "quit")
yard += emit("Keep", kholds, {kcatch: f"{out}/yard-keep-catch.bmp"}, len(kholds) + 1)
lholds, _, ldone = lamp_run(2, None)
yard += emit("Lamp", lholds, {}, len(lholds) + 1)
yard += ["title=Orb", f"12 shot {out}/yard-orb.bmp", "14 quit"]
open(f"{tmp}/yard.cab", "w").write("\n".join(yard) + "\n")
open(f"{tmp}/yard-keep.expect", "w").write(str(kscore))
print(f"yard's keep score {kscore}, lamp done {ldone}")

open(f"{tmp}/miss.cab", "w").write(f"""title=The Yard
4 down LOW
5 up LOW
8 shot {out}/yard-missing.bmp
12 quit
""")
open(f"{tmp}/bad.cab", "w").write(f"""title=The Yard
2 shot {out}/yard-bad.bmp
4 quit
""")
open(f"{tmp}/empty.cab", "w").write(f"""title=The Yard
2 shot {out}/yard-empty.bmp
4 quit
""")
open(f"{tmp}/remember.cab", "w").write(f"""title=The Yard
2 shot {out}/yard-remembered.bmp
4 quit
""")
print("scripts ready")
PY

pix() {
    python3 - "$1" "$2" "$3" << 'PY'
import struct, sys
path, x, y = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
d = open(path, "rb").read()
off = struct.unpack_from("<I", d, 10)[0]
w, h = struct.unpack_from("<ii", d, 18)
W, H = abs(w), abs(h)
bpp = struct.unpack_from("<H", d, 28)[0]
stride = ((W * (bpp // 8) + 3) & ~3)
row = (H - 1 - y) if h > 0 else y
i = off + row * stride + x * (bpp // 8)
if bpp == 32:
    print(d[i + 2], d[i + 1], d[i])
else:
    print(d[i + 2], d[i + 1], d[i])
PY
}

yellow() {
    # shell helper via python exit code: yellow paddle pixel
    python3 - "$1" "$2" "$3" "$4" << 'PY'
import struct, sys
path, x, y, want = sys.argv[1:]
x, y, want = int(x), int(y), want == "yes"
d = open(path, "rb").read()
off = struct.unpack_from("<I", d, 10)[0]
w, h = struct.unpack_from("<ii", d, 18)
W, H = abs(w), abs(h)
if (W, H) != (240, 320):
    raise SystemExit(f"{path}: {W}x{H}")
bpp = struct.unpack_from("<H", d, 28)[0]
stride = ((W * (bpp // 8) + 3) & ~3)
row = (H - 1 - y) if h > 0 else y
i = off + row * stride + x * 3
r, g, b = d[i + 2], d[i + 1], d[i]
is_y = r > 200 and g > 180 and b < 100
if is_y != want:
    raise SystemExit(f"{path} ({x},{y}) {(r,g,b)} yellow={is_y} wanted {want}")
PY
}

gold_row() {
    python3 - "$1" "$2" << 'PY'
import struct, sys
path, row = sys.argv[1], int(sys.argv[2])
d = open(path, "rb").read()
off = struct.unpack_from("<I", d, 10)[0]
w, h = struct.unpack_from("<ii", d, 18)
W, H = abs(w), abs(h)
bpp = struct.unpack_from("<H", d, 28)[0]
stride = ((W * (bpp // 8) + 3) & ~3)
def pix(x, y):
    rr = (H - 1 - y) if h > 0 else y
    i = off + rr * stride + x * (bpp // 8)
    return d[i + 2], d[i + 1], d[i]
def gold(x, y):
    r, g, b = pix(x, y)
    return r > 220 and 160 < g < 230 and b < 120
y = 116 + row * 36
if not gold(20, y):
    raise SystemExit(f"{path}: lantern not on row {row} {pix(20, y)}")
for other in range(4):
    if other != row and gold(20, 116 + other * 36):
        raise SystemExit(f"{path}: lantern also on row {other}")
print(f"{path}: lantern on row {row}")
PY
}

run() {
    local name=$1 dir=$2 script=$3
    shift 3
    echo "== $name =="
    mkdir -p "$dir"
    ( cd "$dir" && CAB_SCRIPT="$script" CAB_SCRIPT_LOG=1 CAB_SCALE=1 CAB_MAX_FRAMES=8000 "$@" )
}

echo "== keep, a miss with nothing caught =="
run "keep zero" "$tmp/zero" "$tmp/zero.cab" "$root/out/pc/keep"
test ! -e "$tmp/zero/keep.sav"
python3 - "$out/keep-zero.bmp" << 'PY'
import struct, sys
d = open(sys.argv[1], "rb").read()
off = struct.unpack_from("<I", d, 10)[0]
w, h = struct.unpack_from("<ii", d, 18)
W, H = abs(w), abs(h)
bpp = struct.unpack_from("<H", d, 28)[0]
stride = ((W * (bpp // 8) + 3) & ~3)
green = 0
for y in range(0, H, 2):
    row = (H - 1 - y) if h > 0 else y
    for x in range(0, W, 2):
        i = off + row * stride + x * (bpp // 8)
        r, g, b = d[i + 2], d[i + 1], d[i]
        if g > 180 and r < 120 and b > 80:
            green += 1
if green:
    raise SystemExit(f"tile still falling after the miss ({green})")
print("missed with score 0, no save file")
PY

echo "== keep, quit before the miss =="
run "keep quit" "$tmp/quit" "$tmp/quit.cab" "$root/out/pc/keep"
exp=$(cat "$tmp/quit.expect")
grep -qx "best $exp" "$tmp/quit/keep.sav"
echo "saved best $exp without missing"
run "keep remember" "$tmp/quit" "$tmp/keep-remember.cab" "$root/out/pc/keep"
grep -qx "best $exp" "$tmp/quit/keep.sav"
echo "second launch kept best $exp"

echo "== keep, a higher record is not lowered =="
mkdir -p "$tmp/high"
printf 'best 9\n' > "$tmp/high/keep.sav"
# One catch and a miss. 1 does not replace 9.
run "keep high" "$tmp/high" "$tmp/quit.cab" "$root/out/pc/keep"
grep -qx 'best 9' "$tmp/high/keep.sav"
echo "best stayed 9"

echo "== keep, twelve catches then a miss =="
run "keep long" "$tmp/long" "$tmp/long.cab" "$root/out/pc/keep"
exp=$(cat "$tmp/long.expect")
grep -qx "best $exp" "$tmp/long/keep.sav"
echo "long game best $exp"

echo "== keep, fast =="
run "keep fast" "$tmp/fast" "$tmp/fast.cab" "$root/out/pc/keep" -fast
exp=$(cat "$tmp/fast.expect")
grep -qx "best $exp" "$tmp/fast/keep.sav"
echo "fast best $exp"

echo "== keep, the title stick does not move the paddle =="
run "keep title" "$tmp/title" "$tmp/title.cab" "$root/out/pc/keep"
yellow "$out/keep-title.bmp" 110 294 yes
yellow "$out/keep-title.bmp" 210 294 no
echo "paddle stayed centered"

echo "== keep, the wall =="
run "keep wall" "$tmp/wall" "$tmp/wall.cab" "$root/out/pc/keep"
yellow "$out/keep-wall.bmp" 8 294 yes
yellow "$out/keep-wall.bmp" 120 294 no
echo "paddle parked on the left wall"

echo "== keep, left and right together =="
run "keep oppose" "$tmp/oppose" "$tmp/oppose.cab" "$root/out/pc/keep"
yellow "$out/keep-oppose.bmp" 110 294 yes
yellow "$out/keep-oppose.bmp" 8 294 no
yellow "$out/keep-oppose.bmp" 210 294 no
echo "opposed stick cancelled"

echo "== keep, script lines out of frame order =="
run "keep order" "$tmp/order" "$tmp/order.cab" "$root/out/pc/keep"
yellow "$out/keep-order.bmp" 74 294 no
yellow "$out/keep-order.bmp" 90 294 yes
echo "later frame won"

echo "== keep, 1-player and 2-player quit =="
run "keep combo" "$tmp/combo" "$tmp/combo.cab" "$root/out/pc/keep"
test ! -e "$out/keep-quit-late.bmp"
echo "quit before the late shot"

echo "== lamp, leave in the middle =="
run "lamp partial" "$tmp/lpart" "$tmp/lamp-partial.cab" "$root/out/pc/lamp"
exp=$(cat "$tmp/lamp-partial.expect")
grep -qx "best $exp" "$tmp/lpart/lamp.sav"
echo "partial best $exp"

echo "== lamp, finish and start again =="
run "lamp full" "$tmp/lfull" "$tmp/lamp-full.cab" "$root/out/pc/lamp"
grep -qx 'best 7' "$tmp/lfull/lamp.sav"
python3 - "$out/lamp-awake.bmp" "$out/lamp-reset.bmp" << 'PY'
import struct, sys
def pix(path, x, y):
    d = open(path, "rb").read()
    off = struct.unpack_from("<I", d, 10)[0]
    w, h = struct.unpack_from("<ii", d, 18)
    H = abs(h)
    bpp = struct.unpack_from("<H", d, 28)[0]
    stride = ((abs(w) * (bpp // 8) + 3) & ~3)
    row = (H - 1 - y) if h > 0 else y
    i = off + row * stride + x * (bpp // 8)
    return d[i + 2], d[i + 1], d[i]
awake = pix(sys.argv[1], 200, 168)
reset = pix(sys.argv[2], 200, 168)
print(f"corner awake {awake} reset {reset}")
if not (awake[0] > 200 and awake[1] > 180):
    raise SystemExit("the corner star was not lit at the end of the trip")
if not (reset[0] < 120 and reset[2] > 80):
    raise SystemExit("Z did not start a fresh trip")
print("fresh trip, record still 7")
PY

echo "== lamp, fast =="
run "lamp fast" "$tmp/lfast" "$tmp/lamp-fast.cab" "$root/out/pc/lamp" -fast
grep -qx 'best 7' "$tmp/lfast/lamp.sav"
echo "fast lamp lit all seven"

scene_ok() {
    python3 - "$1" << 'PY'
import struct, sys
from collections import Counter
path = sys.argv[1]
d = open(path, "rb").read()
off = struct.unpack_from("<I", d, 10)[0]
w, h = struct.unpack_from("<ii", d, 18)
W, H = abs(w), abs(h)
if (W, H) != (384, 512):
    raise SystemExit(f"{path}: {W}x{H}")
bpp = struct.unpack_from("<H", d, 28)[0]
stride = ((W * (bpp // 8) + 3) & ~3)
colors = Counter()
body = 0
samples = 0
for y in range(24, H - 24, 2):
    row = (H - 1 - y) if h > 0 else y
    for x in range(0, W, 2):
        i = off + row * stride + x * (bpp // 8)
        r, g, b = d[i + 2], d[i + 1], d[i]
        samples += 1
        if abs(r - 8) > 12 or abs(g - 10) > 12 or abs(b - 26) > 12:
            body += 1
        colors[(r // 8, g // 8, b // 8)] += 1
dom = colors.most_common(1)[0][1] / samples
print(f"{path}: body {body} dominant {dom:.2f}")
if body < 2000:
    raise SystemExit(f"{path}: the room is missing")
if dom > 0.92:
    raise SystemExit(f"{path}: one triangle covered the picture")
PY
}

echo "== orb, a full turn =="
run "orb spin" "$tmp/ospin" "$tmp/orb-spin.cab" "$root/out/pc/orb"
for f in 2 12 50 100 160 220; do
    scene_ok "$out/orb-spin-$f.bmp"
done
echo "cube stayed on screen through the turn"

echo "== orb, the stick yaws =="
run "orb still" "$tmp/ostill" "$tmp/orb-still.cab" "$root/out/pc/orb"
run "orb yaw" "$tmp/oyaw" "$tmp/orb-yaw.cab" "$root/out/pc/orb"
python3 - "$out/orb-still.bmp" "$out/orb-yaw.bmp" << 'PY'
import struct, sys
def mean(path):
    d = open(path, "rb").read()
    off = struct.unpack_from("<I", d, 10)[0]
    w, h = struct.unpack_from("<ii", d, 18)
    W, H = abs(w), abs(h)
    bpp = struct.unpack_from("<H", d, 28)[0]
    stride = ((W * (bpp // 8) + 3) & ~3)
    acc = [0, 0, 0]
    n = 0
    for y in range(H // 2 - 40, H // 2 + 40, 2):
        row = (H - 1 - y) if h > 0 else y
        for x in range(W // 2 - 40, W // 2 + 40, 2):
            i = off + row * stride + x * (bpp // 8)
            acc[0] += d[i + 2]
            acc[1] += d[i + 1]
            acc[2] += d[i]
            n += 1
    return [c / n for c in acc]
a, b = mean(sys.argv[1]), mean(sys.argv[2])
delta = abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])
print(f"still {tuple(round(c) for c in a)} yaw {tuple(round(c) for c in b)} delta {delta:.0f}")
if delta < 12:
    raise SystemExit("holding right did not turn the room")
print("stick yaws the room")
PY

echo "== yard, every row, then Orb, Keep, and Lamp =="
mkdir -p "$tmp/card" "$tmp/yard"
printf 'pocket\n' > "$tmp/card/label"
( cd "$tmp/yard" && CAB_SCRIPT="$tmp/yard.cab" CAB_SCRIPT_LOG=1 CAB_SCALE=1 \
    CAB_MAX_FRAMES=8000 CAB_EXT="$tmp/card" "$root/out/pc/yard" >"$out/yard.log" 2>&1 )
grep -q "using offscreen" "$out/yard.log"
grep -qx "best $(cat "$tmp/yard-keep.expect")" "$tmp/yard/keep.sav"
grep -qx 'best 7' "$tmp/yard/lamp.sav"
grep -qx 'best 1' "$tmp/yard/yard.sav"
grep -qx 'yard' "$tmp/card/visited"
grep -q 'pocket' "$tmp/card/orb-card"
gold_row "$out/yard-row0.bmp" 0
gold_row "$out/yard-row1.bmp" 1
gold_row "$out/yard-row2.bmp" 2
gold_row "$out/yard-row3.bmp" 3
gold_row "$out/yard-wrap0.bmp" 0
gold_row "$out/yard-wrap3.bmp" 3
gold_row "$out/yard-after-orb.bmp" 2
gold_row "$out/yard-after-keep.bmp" 0
gold_row "$out/yard-after-lamp.bmp" 1
python3 - "$out/yard-row0.bmp" << 'PY'
import struct, sys
d = open(sys.argv[1], "rb").read()
off = struct.unpack_from("<I", d, 10)[0]
w, h = struct.unpack_from("<ii", d, 18)
H = abs(h)
bpp = struct.unpack_from("<H", d, 28)[0]
stride = ((abs(w) * (bpp // 8) + 3) & ~3)
y, x = 304, 224
row = (H - 1 - y) if h > 0 else y
i = off + row * stride + x * (bpp // 8)
r, g, b = d[i + 2], d[i + 1], d[i]
print(f"pocket {(r, g, b)}")
if not (r < 80 and g > 180 and b > 180):
    raise SystemExit("pocket mark missing")
PY
scene_ok "$out/yard-orb.bmp"
# The catch shot from the child should show the green tile.
python3 - "$out/yard-keep-catch.bmp" << 'PY'
import struct, sys
d = open(sys.argv[1], "rb").read()
off = struct.unpack_from("<I", d, 10)[0]
w, h = struct.unpack_from("<ii", d, 18)
W, H = abs(w), abs(h)
bpp = struct.unpack_from("<H", d, 28)[0]
stride = ((W * (bpp // 8) + 3) & ~3)
seen = False
for y in range(0, H, 2):
    row = (H - 1 - y) if h > 0 else y
    for x in range(0, W, 2):
        i = off + row * stride + x * (bpp // 8)
        r, g, b = d[i + 2], d[i + 1], d[i]
        if g > 180 and r < 120 and b > 80:
            seen = True
if not seen:
    raise SystemExit("keep launched from the yard did not catch")
print("keep caught from the yard")
PY
echo "yard played every row"

echo "== yard, the game is not there =="
mkdir -p "$tmp/alone" "$tmp/miss"
cp "$root/out/pc/yard" "$tmp/alone/yard"
( cd "$tmp/miss" && CAB_SCRIPT="$tmp/miss.cab" CAB_SCALE=1 CAB_MAX_FRAMES=40 \
    "$tmp/alone/yard" >"$out/yard-miss.log" 2>&1 )
grep -q "could not open keep" "$out/yard-miss.log"
test -s "$out/yard-missing.bmp"
echo "missing game returned to the menu"

echo "== yard, a broken save and no card =="
mkdir -p "$tmp/bad"
printf 'best 99\n' > "$tmp/bad/yard.sav"
( cd "$tmp/bad" && CAB_SCRIPT="$tmp/bad.cab" CAB_SCALE=1 CAB_MAX_FRAMES=20 \
    "$root/out/pc/yard" )
gold_row "$out/yard-bad.bmp" 0
python3 - "$out/yard-bad.bmp" << 'PY'
import struct, sys
d = open(sys.argv[1], "rb").read()
off = struct.unpack_from("<I", d, 10)[0]
w, h = struct.unpack_from("<ii", d, 18)
H = abs(h)
bpp = struct.unpack_from("<H", d, 28)[0]
stride = ((abs(w) * (bpp // 8) + 3) & ~3)
row = (H - 1 - 304) if h > 0 else 304
i = off + row * stride + 224 * (bpp // 8)
r, g, b = d[i + 2], d[i + 1], d[i]
if r < 80 and g > 180 and b > 180:
    raise SystemExit(f"pocket drawn with no card {(r, g, b)}")
print("broken save opened on the first row, no pocket")
PY

echo "== yard, card with no label =="
mkdir -p "$tmp/emptycard" "$tmp/empty"
( cd "$tmp/empty" && CAB_SCRIPT="$tmp/empty.cab" CAB_SCALE=1 CAB_MAX_FRAMES=20 \
    CAB_EXT="$tmp/emptycard" "$root/out/pc/yard" )
test ! -e "$tmp/emptycard/visited"
echo "empty card wrote nothing"

echo "== remembered row =="
# The full yard run left the lantern on Lamp.
( cd "$tmp/yard" && CAB_SCRIPT="$tmp/remember.cab" CAB_SCALE=1 CAB_MAX_FRAMES=20 \
    "$root/out/pc/yard" )
gold_row "$out/yard-remembered.bmp" 1
grep -qx 'best 1' "$tmp/yard/yard.sav"
echo "came back on Lamp"

echo "== yard, a held button opens the game once =="
mkdir -p "$tmp/once"
cp "$root/out/pc/yard" "$tmp/once/yard"
cat > "$tmp/once/keep" << EOF
#!/bin/sh
echo x >> "$tmp/once/launches"
exit 0
EOF
chmod +x "$tmp/once/keep"
cat > "$tmp/hold.cab" << EOF
title=The Yard
8 down LOW
20 up LOW
24 down DOWN
25 up DOWN
28 shot $out/yard-hold.bmp
30 quit
EOF
( cd "$tmp/once" && CAB_SCRIPT="$tmp/hold.cab" CAB_SCALE=1 CAB_MAX_FRAMES=80 \
    "$tmp/once/yard" >"$out/yard-hold.log" 2>&1 )
test "$(wc -l < "$tmp/once/launches")" = 1
gold_row "$out/yard-hold.bmp" 1
echo "one launch, and the next press still moves"

echo "== keep, a corrupt record loads as none =="
for bad in 'best 1000001' 'best -4' 'best 999999999999'; do
    dir="$tmp/corrupt"
    rm -rf "$dir"
    mkdir -p "$dir"
    printf '%s\n' "$bad" > "$dir/keep.sav"
    ( cd "$dir" && KEEP_SELFTEST=1 CAB_SCALE=1 "$root/out/pc/keep" )
    grep -qx 'best 1' "$dir/keep.sav"
    echo "rejected $bad"
done

echo "== keep, the save is durable and the catch is audible =="
if command -v strace >/dev/null; then
    mkdir -p "$tmp/trace"
    ( cd "$tmp/trace" && strace -f -o "$out/score.strace" -e trace=openat,fsync \
        env KEEP_SELFTEST=1 CAB_SCALE=1 "$root/out/pc/keep" )
    grep -q O_DIRECTORY "$out/score.strace"
    echo "directory fsync is in the save"
fi
mkdir -p "$tmp/audio"
( cd "$tmp/audio" && SDL_AUDIODRIVER=disk CAB_PACE=1 CAB_SCRIPT="$tmp/audio.cab" \
    CAB_SCRIPT_LOG=1 CAB_SCALE=1 CAB_MAX_FRAMES=4000 "$root/out/pc/keep" >"$out/audio.log" 2>&1 )
python3 - "$tmp/audio/sdlaudio.raw" << 'PY'
import struct, sys
b = open(sys.argv[1], "rb").read()
n = len(b) // 2
if n < 1000:
    raise SystemExit(f"audio file is {len(b)} bytes")
peak = 0
loud = 0
for i in range(0, n, 2):
    v = struct.unpack_from("<h", b, i * 2)[0]
    a = v if v >= 0 else -v
    if a > peak:
        peak = a
    if a > 1500:
        loud += 1
print(f"audio peak {peak} loud samples {loud}")
if peak < 2000 or loud < 200:
    raise SystemExit("the catch did not beep")
print("catch beep is in the recording")
PY

echo "== orb, dive the well =="
# A centered run is open until the pillar at travel 40. Holding right meets the
# first gate at travel 8 and writes orb.sav. The idle cube is a different test.
cat > "$tmp/well-safe.cab" << EOF
title=Orb
2 down LOW
24 shot $out/well-safe.bmp
50 quit
EOF
cat > "$tmp/well-hit.cab" << EOF
title=Orb
2 down LOW
2 down RIGHT
90 quit
EOF
mkdir -p "$tmp/well"
( cd "$tmp/well" && CAB_SCRIPT="$tmp/well-safe.cab" CAB_SCALE=1 CAB_MAX_FRAMES=80 \
    "$root/out/pc/orb" >"$out/well-safe.log" 2>&1 )
grep -q "orb well ready" "$out/well-safe.log"
if grep -q "dive crash" "$out/well-safe.log"; then
    echo "a centered dive hit a gate" >&2
    exit 1
fi
test ! -e "$tmp/well/orb.sav"
python3 - "$out/well-safe.bmp" << 'PY'
import struct, sys
d = open(sys.argv[1], "rb").read()
off = struct.unpack_from("<I", d, 10)[0]
w, h = struct.unpack_from("<ii", d, 18)
W, H = abs(w), abs(h)
if (W, H) != (384, 512):
    raise SystemExit(f"well shot is {W}x{H}")
bpp = struct.unpack_from("<H", d, 28)[0] // 8
stride = (W * bpp + 3) & ~3
buckets, holes, stone = set(), 0, 0
for y in range(60, H - 60, 2):
    row = off + ((H - 1 - y) if h > 0 else y) * stride
    for x in range(30, W - 30, 2):
        i = row + x * bpp
        b, g, r = d[i], d[i + 1], d[i + 2]
        buckets.add((r // 20, g // 20, b // 20))
        if r < 12 and g < 12 and b < 20:
            holes += 1
        if b > r + 10 and b > 60 and r > 25:
            stone += 1
print(f"well buckets {len(buckets)} holes {holes} stone {stone}")
if len(buckets) < 25 or holes > 400 or stone < 2000:
    raise SystemExit("the well is not on screen")
PY
mkdir -p "$tmp/wellhit"
( cd "$tmp/wellhit" && CAB_SCRIPT="$tmp/well-hit.cab" CAB_SCALE=1 CAB_MAX_FRAMES=120 \
    "$root/out/pc/orb" >"$out/well-hit.log" 2>&1 )
grep -q "dive crash" "$out/well-hit.log"
python3 - "$tmp/wellhit/orb.sav" << 'PY'
import sys
line = open(sys.argv[1]).read().strip()
n = int(line.split()[1])
print(f"well {line}")
if not line.startswith("best ") or n < 40:
    raise SystemExit("the gate did not save a score")
PY
echo "centered dive stays up, the right-hand gate saves"

echo "== tea, sky, door, party =="
# No-input arrival is frame 989. A lean is a dozen pixels. The heart fills
# on the same frame as the press. Empty hearts are cream; a filled one is rose.
cat > "$tmp/tea-visit.cab" << EOF
title=Tea
8 shot $out/tea-sky.bmp
16 down RIGHT
24 shot $out/tea-lean.bmp
25 up RIGHT
910 shot $out/tea-door.bmp
1000 shot $out/tea-party.bmp
1002 down RIGHT
1002 shot $out/tea-moth.bmp
1003 up RIGHT
1004 down LEFT
1005 up LEFT
1006 down LOW
1006 shot $out/tea-heart.bmp
1007 up LOW
1008 quit
EOF
mkdir -p "$tmp/tea-visit"
( cd "$tmp/tea-visit" && CAB_SCRIPT="$tmp/tea-visit.cab" CAB_SCRIPT_LOG=1 CAB_SCALE=1 \
    CAB_MAX_FRAMES=1200 "$root/out/pc/tea" >"$out/tea-visit.log" 2>&1 )
grep -q "tea say She flies to the castle." "$out/tea-visit.log"
grep -q "tea say She leans in the clouds." "$out/tea-visit.log"
grep -q "tea arrive 1" "$out/tea-visit.log"
grep -q "tea say They saved her a seat." "$out/tea-visit.log"
grep -q "tea party" "$out/tea-visit.log"
grep -q "tea heart Pip 1" "$out/tea-visit.log"
python3 - "$out" << 'PY'
import struct, sys
out = sys.argv[1]
def pix(path, x, y):
    d = open(path, "rb").read()
    off = struct.unpack_from("<I", d, 10)[0]
    w, h = struct.unpack_from("<ii", d, 18)
    W, H = abs(w), abs(h)
    if (W, H) != (384, 512):
        raise SystemExit(f"{path}: {W}x{H}")
    bpp = struct.unpack_from("<H", d, 28)[0] // 8
    stride = (W * bpp + 3) & ~3
    row = (H - 1 - y) if h > 0 else y
    i = off + row * stride + x * bpp
    return d[i + 2], d[i + 1], d[i]
def kind(rgb):
    r, g, b = rgb
    if r > 240 and g > 230 and b > 220:
        return "cream"
    if r > 220 and 150 < g < 210 and 180 < b < 240:
        return "castle"
    if 160 < r < 210 and g < 190 and b > 200:
        return "lilac"
    if r > 220 and 130 < g < 190 and b < 100:
        return "orange"
    if 110 < r < 170 and 110 < g < 170 and 120 < b < 190:
        return "grey"
    if r > 210 and g < 140 and 120 < b < 190:
        return "rose"
    if 170 < r < 230 and 100 < g < 170 and 50 < b < 130:
        return "tea"
    if r < 180 and g > 170 and b > 220:
        return "sky"
    return f"other{rgb}"
want = {
    "tea-sky.bmp": {(192, 340): "cream", (230, 340): "lilac", (184, 52): "castle"},
    "tea-lean.bmp": {(230, 340): "cream", (184, 52): "castle", (192, 340): "cream"},
    "tea-door.bmp": {(118, 316): "sky"},
    "tea-party.bmp": {(72, 270): "orange", (192, 270): "cream", (52, 194): "cream"},
    "tea-moth.bmp": {(192, 270): "grey", (72, 270): "cream"},
    "tea-heart.bmp": {(52, 194): "rose"},
}
for name, pts in want.items():
    for (x, y), k in pts.items():
        got = kind(pix(f"{out}/{name}", x, y))
        if got != k:
            raise SystemExit(f"{name} ({x},{y}) {got} wanted {k}")
    print(f"{name} ok")
PY

echo "== tea, nine cares, then the gifts at the door =="
cat > "$tmp/tea-cheer.cab" << EOF
title=Tea
1000 down LOW
1001 up LOW
1002 down LOW
1003 up LOW
1004 down LOW
1005 up LOW
1006 down RIGHT
1007 up RIGHT
1008 down LOW
1009 up LOW
1010 down LOW
1011 up LOW
1012 down LOW
1013 up LOW
1014 down RIGHT
1015 up RIGHT
1016 down LOW
1017 up LOW
1018 down LOW
1019 up LOW
1020 down LOW
1020 shot $out/tea-cheer.bmp
1021 up LOW
1024 quit
EOF
mkdir -p "$tmp/tea-cheer"
( cd "$tmp/tea-cheer" && CAB_SCRIPT="$tmp/tea-cheer.cab" CAB_SCRIPT_LOG=1 CAB_SCALE=1 \
    CAB_MAX_FRAMES=1200 "$root/out/pc/tea" >"$out/tea-cheer.log" 2>&1 )
test "$(grep -c 'tea heart' "$out/tea-cheer.log")" = 9
grep -q "tea cheer" "$out/tea-cheer.log"
grep -q "tea say The whole table glows." "$out/tea-cheer.log"
python3 - "$tmp/tea-cheer/tea.sav" << 'PY'
import sys
text = open(sys.argv[1]).read().splitlines()
want = ["visits 1", "pip teacup", "moth ribbon", "pearl flower", "nib none"]
if text != want:
    raise SystemExit(f"tea.sav {text}")
print("tea.sav", text)
PY
cat > "$tmp/tea-back.cab" << EOF
title=Tea
910 shot $out/tea-reunion.bmp
920 quit
EOF
cat > "$tmp/tea-arrive.cab" << EOF
title=Tea
920 quit
EOF
( cd "$tmp/tea-cheer" && CAB_SCRIPT="$tmp/tea-back.cab" CAB_SCRIPT_LOG=1 CAB_SCALE=1 \
    CAB_MAX_FRAMES=1000 "$root/out/pc/tea" >"$out/tea-back.log" 2>&1 )
grep -q "tea arrive 2" "$out/tea-back.log"
grep -q "tea say Pip kept a teacup." "$out/tea-back.log"
python3 - "$out/tea-reunion.bmp" << 'PY'
import struct, sys
d = open(sys.argv[1], "rb").read()
off = struct.unpack_from("<I", d, 10)[0]
w, h = struct.unpack_from("<ii", d, 18)
W, H = abs(w), abs(h)
bpp = struct.unpack_from("<H", d, 28)[0] // 8
stride = (W * bpp + 3) & ~3
row = (H - 1 - 316) if h > 0 else 316
i = off + row * stride + 118 * bpp
r, g, b = d[i + 2], d[i + 1], d[i]
print(f"reunion cup {(r, g, b)}")
if not (170 < r < 230 and 100 < g < 170 and 50 < b < 130):
    raise SystemExit("the teacup is not at the door")
PY

echo "== tea, a broken save is the first visit =="
for bad in 'not a save' 'visits -4' 'visits nope'; do
    dir="$tmp/tea-bad"
    rm -rf "$dir"
    mkdir -p "$dir"
    printf '%s\n' "$bad" > "$dir/tea.sav"
    ( cd "$dir" && CAB_SCRIPT="$tmp/tea-arrive.cab" CAB_SCRIPT_LOG=1 CAB_SCALE=1 \
        CAB_MAX_FRAMES=1000 "$root/out/pc/tea" >"$out/tea-bad.log" 2>&1 )
    grep -q "tea arrive 1" "$out/tea-bad.log"
    grep -q "tea say They saved her a seat." "$out/tea-bad.log"
    echo "rejected $bad"
done
mkdir -p "$tmp/tea-huge"
printf 'visits 1000001\npip flower\n' > "$tmp/tea-huge/tea.sav"
( cd "$tmp/tea-huge" && CAB_SCRIPT="$tmp/tea-arrive.cab" CAB_SCRIPT_LOG=1 CAB_SCALE=1 \
    CAB_MAX_FRAMES=1000 "$root/out/pc/tea" >"$out/tea-huge.log" 2>&1 )
grep -q "tea arrive 100000" "$out/tea-huge.log"
echo "a huge visit count stays at 100000"

echo "== tea, the other two buttons =="
cat > "$tmp/tea-buttons.cab" << EOF
title=Tea
1000 down TL
1000 shot $out/tea-tl.bmp
1001 up TL
1004 down RIGHT
1005 up RIGHT
1006 down TR
1007 up TR
1008 quit
EOF
mkdir -p "$tmp/tea-buttons"
( cd "$tmp/tea-buttons" && CAB_SCRIPT="$tmp/tea-buttons.cab" CAB_SCRIPT_LOG=1 CAB_SCALE=1 \
    CAB_MAX_FRAMES=1100 "$root/out/pc/tea" >"$out/tea-buttons.log" 2>&1 )
grep -q "tea heart Pip 1" "$out/tea-buttons.log"
grep -q "tea heart Moth 1" "$out/tea-buttons.log"
python3 - "$out/tea-tl.bmp" << 'PY'
import struct, sys
d = open(sys.argv[1], "rb").read()
off = struct.unpack_from("<I", d, 10)[0]
w, h = struct.unpack_from("<ii", d, 18)
H = abs(h)
bpp = struct.unpack_from("<H", d, 28)[0] // 8
stride = (abs(w) * bpp + 3) & ~3
row = (H - 1 - 194) if h > 0 else 194
i = off + row * stride + 52 * bpp
r, g, b = d[i + 2], d[i + 1], d[i]
if not (r > 210 and g < 140 and 120 < b < 190):
    raise SystemExit(f"TL did not fill the heart {(r, g, b)}")
print("TL filled a heart")
PY

echo "== tea, 1P+2P quits in the sky =="
cat > "$tmp/tea-quit.cab" << EOF
title=Tea
0 down 1P
0 down 2P
EOF
mkdir -p "$tmp/tea-quit"
( cd "$tmp/tea-quit" && CAB_SCRIPT="$tmp/tea-quit.cab" CAB_SCRIPT_LOG=1 CAB_SCALE=1 \
    CAB_MAX_FRAMES=200 "$root/out/pc/tea" >"$out/tea-quit.log" 2>&1 )
if grep -q "tea arrive" "$out/tea-quit.log"; then
    echo "quit reached the castle" >&2
    exit 1
fi
grep -q "tea say They will keep the gifts." "$out/tea-quit.log"
test ! -e "$tmp/tea-quit/tea.sav"
echo "quit before arrival"

echo "== tea, a button held from the start does not care =="
# Hurry still arrives (party by frame 580). The held button is not a new press.
cat > "$tmp/tea-held.cab" << EOF
title=Tea
0 down LOW
580 shot $out/tea-held-empty.bmp
582 up LOW
584 down LOW
584 shot $out/tea-held-heart.bmp
586 up LOW
588 quit
EOF
mkdir -p "$tmp/tea-held"
( cd "$tmp/tea-held" && CAB_SCRIPT="$tmp/tea-held.cab" CAB_SCRIPT_LOG=1 CAB_SCALE=1 \
    CAB_MAX_FRAMES=700 "$root/out/pc/tea" >"$out/tea-held.log" 2>&1 )
grep -q "tea party" "$out/tea-held.log"
test "$(grep -c 'tea heart' "$out/tea-held.log")" = 1
python3 - "$out/tea-held-empty.bmp" "$out/tea-held-heart.bmp" << 'PY'
import struct, sys
def pix(path, x, y):
    d = open(path, "rb").read()
    off = struct.unpack_from("<I", d, 10)[0]
    w, h = struct.unpack_from("<ii", d, 18)
    H = abs(h)
    bpp = struct.unpack_from("<H", d, 28)[0] // 8
    stride = (abs(w) * bpp + 3) & ~3
    row = (H - 1 - y) if h > 0 else y
    i = off + row * stride + x * bpp
    return d[i + 2], d[i + 1], d[i]
empty, filled = pix(sys.argv[1], 52, 194), pix(sys.argv[2], 52, 194)
cat = pix(sys.argv[1], 72, 270)
print(f"held empty {empty} filled {filled} cat {cat}")
if not (empty[0] > 240 and empty[1] > 230):
    raise SystemExit("the held button filled a heart before a new press")
if not (filled[0] > 210 and filled[1] < 140):
    raise SystemExit("the new press did not fill a heart")
if not (cat[0] > 220 and cat[2] < 100):
    raise SystemExit("hurry did not reach the party")
PY

echo "== tea, Nib on the third arrival =="
mkdir -p "$tmp/tea-nib"
printf 'visits 2\npip none\nmoth none\npearl none\nnib none\n' > "$tmp/tea-nib/tea.sav"
cat > "$tmp/tea-nib.cab" << EOF
title=Tea
910 shot $out/tea-nib-door.bmp
1000 shot $out/tea-nib.bmp
1002 quit
EOF
( cd "$tmp/tea-nib" && CAB_SCRIPT="$tmp/tea-nib.cab" CAB_SCRIPT_LOG=1 CAB_SCALE=1 \
    CAB_MAX_FRAMES=1100 "$root/out/pc/tea" >"$out/tea-nib.log" 2>&1 )
grep -q "tea arrive 3" "$out/tea-nib.log"
grep -q "tea say A kitten came to play." "$out/tea-nib.log"
python3 - "$out/tea-nib.bmp" << 'PY'
import struct, sys
d = open(sys.argv[1], "rb").read()
off = struct.unpack_from("<I", d, 10)[0]
w, h = struct.unpack_from("<ii", d, 18)
H = abs(h)
bpp = struct.unpack_from("<H", d, 28)[0] // 8
stride = (abs(w) * bpp + 3) & ~3
row = (H - 1 - 270) if h > 0 else 270
i = off + row * stride + 336 * bpp
r, g, b = d[i + 2], d[i + 1], d[i]
print(f"nib cushion {(r, g, b)}")
if not (160 < r < 210 and 140 < g < 190 and b > 200):
    raise SystemExit("Nib is not on her cushion")
PY
echo "tea played"

echo "== play.sh =="
./play.sh
echo "== check.sh =="
./check.sh
echo "stress ok  shots in $out"
