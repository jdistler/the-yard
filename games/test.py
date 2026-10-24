#!/usr/bin/env python3
"""Headless checks for the games. No cabinet, no flash.

    python3 test.py quick    the self-tests and the panel rotation (check.sh)
    python3 test.py play     one session of every game, saves and pictures (play.sh)
    python3 test.py stress   the edges: quit, held buttons, broken saves, records, demos (stress.sh)
    python3 test.py system   the sandbox, the cart pack, the deploy tools, the templates
    python3 test.py love     the GPU runtime (LÖVE) plays each cart as the C runtime does (needs
                             games/love/build.sh x86; `all` skips it when that build is missing)
    python3 test.py all

Every run happens in a fresh temporary directory, which stands in for /data/Games.
The games play themselves where a test needs a long session (CAB_AUTOPLAY, the same
built-in player the attract mode uses), and a CAB_SCRIPT presses the deck's buttons
where a test needs exact presses. Pictures land in out/play/ and out/stress/.
"""
import os
import shutil
import struct
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
BIN = os.path.join(HERE, "out", "pc")
GL_GAMES = {"orb"}
failures = []
passes = 0


def say(msg):
    print(msg, flush=True)


def check(cond, what):
    global passes
    if cond:
        passes += 1
        say(f"  ok   {what}")
    else:
        failures.append(what)
        say(f"  FAIL {what}")


def run(game, cwd, script=None, env=None, args=(), frames=None, timeout=180, binary=None):
    """Run one game in cwd. Returns (exit code, stderr text)."""
    e = dict(os.environ)
    e.update({"SDL_VIDEODRIVER": "offscreen" if game in GL_GAMES else "dummy", "SDL_AUDIODRIVER": "dummy",
              "CAB_SCALE": "1"})
    if script is not None:
        path = os.path.join(cwd, f"{game}.cab")
        with open(path, "w") as f:
            f.write(script)
        e["CAB_SCRIPT"] = path
    if frames:
        e["CAB_MAX_FRAMES"] = str(frames)
    if env:
        e.update(env)
    try:
        p = subprocess.run([binary or os.path.join(BIN, game), *args], cwd=cwd, env=e, capture_output=True, text=True,
                           timeout=timeout)
        return p.returncode, p.stderr
    except subprocess.TimeoutExpired as ex:
        return -999, (ex.stderr or b"").decode() if isinstance(ex.stderr, bytes) else str(ex.stderr)


def script(title, *lines):
    return "\n".join([f"title={title}", *lines]) + "\n"


def read(cwd, name):
    try:
        with open(os.path.join(cwd, name)) as f:
            return f.read()
    except OSError:
        return None


def best(cwd, name, word="best"):
    text = read(cwd, name)
    if not text:
        return None
    for line in text.splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[0] == word:
            try:
                return int(parts[1])
            except ValueError:
                return None
    return None


def bmp(path):
    """(width, height, pixel(x, y) -> (r, g, b)) for a 24 or 32 bit BMP."""
    with open(path, "rb") as f:
        d = f.read()
    if d[:2] != b"BM":
        raise ValueError("not a bmp")
    off = struct.unpack_from("<I", d, 10)[0]
    w, h = struct.unpack_from("<ii", d, 18)
    bpp = struct.unpack_from("<H", d, 28)[0]
    W, H = abs(w), abs(h)
    stride = (W * (bpp // 8) + 3) & ~3

    def px(x, y):
        row = (H - 1 - y) if h > 0 else y
        i = off + row * stride + x * (bpp // 8)
        return d[i + 2], d[i + 1], d[i]

    return W, H, px


def busy(path):
    """How many distinct colors a coarse sample of the picture has. A blank frame has one or two."""
    try:
        W, H, px = bmp(path)
    except (OSError, ValueError):
        return 0
    seen = set()
    for y in range(0, H, max(1, H // 40)):
        for x in range(0, W, max(1, W // 30)):
            r, g, b = px(x, y)
            seen.add((r >> 4, g >> 4, b >> 4))
    return len(seen)


def tmpdir():
    return tempfile.mkdtemp(prefix="yard-test-")


# ---------------------------------------------------------------------------- quick

def quick():
    say("== quick: self-tests and rotation ==")
    d = tmpdir()
    rc, _ = run("probe", d, env={"PROBE_SELFTEST": "1", "CAB_SCREENSHOT": os.path.join(d, "probe.bmp")})
    check(rc == 0 and os.path.exists(os.path.join(d, "probe.bmp")), "probe self-test quits and draws")
    rc, err = run("keep", d, env={"KEEP_SELFTEST": "1"})
    check(rc == 0 and (best(d, "keep.sav") or 0) >= 1, f"keep self-test catches and saves ({read(d, 'keep.sav')!r})")
    rc, err = run("lamp", d, env={"LAMP_SELFTEST": "1"})
    check(rc == 0 and (best(d, "lamp.sav") or 0) >= 1, f"lamp self-test wakes a night and saves ({read(d, 'lamp.sav')!r})")
    rc, _ = run("yard", d, env={"YARD_SELFTEST": "1"})
    check(rc == 0 and best(d, "yard.sav") is not None, "yard self-test saves the row")
    rc, _ = run("yard", d, args=("keep",), env={"KEEP_SELFTEST": "1"})
    check(rc == 0, "yard runs a cart by name (yard keep)")
    for cart in ("yard", "keep", "lamp", "tea", "chest"):
        r = subprocess.run([os.path.join(BIN, "yard"), "--check", cart], cwd=d, capture_output=True, text=True,
                           env={**os.environ, "SDL_VIDEODRIVER": "dummy", "SDL_AUDIODRIVER": "dummy",
                                "CAB_SCRIPT": "/dev/null", "YARD_CHECK_FRAMES": "120"}, timeout=120)
        check(r.returncode == 0 and r.stdout.startswith("ok:"), f"cart {cart} boots and runs 120 frames ({r.stdout.strip()})")
    # The panel is mounted 90 degrees clockwise: the top of the game lands on the left of the framebuffer.
    shot = os.path.join(d, "fb.bmp")
    rc, _ = run("keep", d, script="", frames=6,
                env={"CAB_RAW_FB": "1", "CAB_TESTCARD": "1", "CAB_SCREENSHOT": shot, "CAB_SCREENSHOT_FRAME": "3"})
    try:
        W, H, px = bmp(shot)
        reds, blues = [], []
        for y in range(0, H, 4):
            for x in range(0, W, 4):
                r, g, b = px(x, y)
                if r > 180 and g < 90 and b < 90:
                    reds.append(x)
                elif b > 150 and r < 90 and g < 140:
                    blues.append(x)
        rm = sum(reds) / max(1, len(reds))
        bm = sum(blues) / max(1, len(blues))
        check((W, H) == (1024, 768), f"raw framebuffer is 1024x768 ({W}x{H})")
        check(len(reds) > 10 and len(blues) > 10 and rm < W * 0.35 and bm > W * 0.65,
              f"rotation: game top on the left (red x {rm:.0f}), bottom on the right (blue x {bm:.0f})")
    except (OSError, ValueError) as ex:
        check(False, f"rotation shot readable ({ex})")
    # The GL path rotates the same way.
    shot = os.path.join(d, "orbfb.bmp")
    rc, err = run("orb", d, script="", frames=6,
                  env={"CAB_RAW_FB": "1", "CAB_SCREENSHOT": shot, "CAB_SCREENSHOT_FRAME": "3"})
    check(rc == 0 and busy(shot) > 3, "orb draws through OpenGL ES 2 on the rotated framebuffer")
    shutil.rmtree(d, ignore_errors=True)


# ---------------------------------------------------------------------------- play

def play():
    say("== play: one session of each game ==")
    out = os.path.join(HERE, "out", "play")
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out)
    d = tmpdir()

    def shots(title, frames, quit_at):
        return script(title, *[f"{f} shot {out}/{title.lower().replace(' ', '')}-{f}.bmp" for f in frames], f"{quit_at} quit")

    rc, err = run("keep", d, script=shots("Keep", [5, 600, 1500], 1600), env={"CAB_AUTOPLAY": "1"})
    check(rc == 0 and (best(d, "keep.sav") or 0) > 5, f"keep: the built-in player scores and saves ({read(d, 'keep.sav')!r})")
    check(busy(f"{out}/keep-600.bmp") > 20, "keep: the orchard is drawn")

    rc, err = run("lamp", d, script=shots("Lamp", [5, 400, 1500], 1600), env={"CAB_AUTOPLAY": "1"})
    check(rc == 0 and (best(d, "lamp.sav") or 0) >= 1, f"lamp: a night is woken and saved ({read(d, 'lamp.sav')!r})")
    check("lamp night 1 done" in err, "lamp: the constellation completes")

    rc, err = run("tea", d, script=shots("Tea", [100, 1000, 1500], 1600), env={"CAB_AUTOPLAY": "1"})
    sav = read(d, "tea.sav") or ""
    check(rc == 0 and "visits 1" in sav, "tea: she arrives and the visit is saved")
    check("tea cheer" in err and "pip teacup" in sav and "moth ribbon" in sav and "pearl flower" in sav,
          "tea: nine cares reach the cheer, and the gifts are saved")
    check("tea treat" in err, "tea: she catches treats on the way to the party")
    check("photos 1" in sav and "tea photo 1" in err, "tea: the cheer hangs a photo on the wall and saves it")

    rc, err = run("chest", d, script=shots("Chest", [20, 300, 1500], 1600), env={"CAB_AUTOPLAY": "1"})
    check(rc == 0 and (best(d, "chest.sav", "gems") or 0) >= 1, f"chest: Zam bows and a gem is saved ({read(d, 'chest.sav')!r})")
    check("chest key" in err and "chest sword" in err, "chest: key, chest, sword in that order")

    # Orb: dive, then hold right into the first gate (it closes the right side).
    rc, err = run("orb", d, script=script("Orb", "10 down LOW", "11 up LOW", "20 down RIGHT",
                                          f"30 shot {out}/orb-dive.bmp", f"5 shot {out}/orb-title.bmp", "240 quit"))
    check(rc == 0 and (best(d, "orb.sav") or 0) > 0, f"orb: steering into a gate crashes and saves ({read(d, 'orb.sav')!r})")
    check(busy(f"{out}/orb-dive.bmp") > 10, "orb: the well is drawn")

    # The Yard: down to Lamp, open it, quit Lamp with 1P+2P, land back on Lamp.
    s = "\n".join([
        "title=The Yard", "10 down DOWN", "11 up DOWN", "30 down LOW", "31 up LOW", f"25 shot {out}/yard.bmp",
        f"150 shot {out}/yard-back.bmp", "160 quit",
        "title=Lamp", "20 down 1P", "20 down 2P", f"10 shot {out}/yard-lamp.bmp",
    ]) + "\n"
    rc, err = run("yard", d, script=s, frames=400)
    check(rc == 0 and best(d, "yard.sav") == 1 and "yard open lamp" in err, "yard: opens Lamp and comes back on its row")
    check(busy(f"{out}/yard.bmp") > 20 and busy(f"{out}/yard-back.bmp") > 20, "yard: the menu is drawn before and after")
    say(f"  pictures in {out}")
    shutil.rmtree(d, ignore_errors=True)


# ---------------------------------------------------------------------------- stress

def stress():
    say("== stress: the edges ==")
    out = os.path.join(HERE, "out", "stress")
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out)

    # 1P+2P held for a second quits every game, and nothing else needs to happen first.
    for game, title in (("keep", "Keep"), ("lamp", "Lamp"), ("tea", "Tea"), ("chest", "Chest"), ("orb", "Orb"),
                        ("yard", "The Yard")):
        d = tmpdir()
        marker = os.path.join(d, "late.bmp")
        rc, err = run(game, d, script=script(title, "5 down 1P", "5 down 2P", f"200 shot {marker}"), frames=400)
        check(rc == 0 and not os.path.exists(marker), f"{game}: holding 1P+2P quits")
        shutil.rmtree(d, ignore_errors=True)

    # Keep.
    d = tmpdir()
    with open(os.path.join(d, "keep.sav"), "w") as f:
        f.write("best 99999\n")
    rc, err = run("keep", d, frames=900, script="", env={"CAB_AUTOPLAY": "1"})
    check(best(d, "keep.sav") == 99999, "keep: a lower score never replaces the record")
    with open(os.path.join(d, "keep.sav"), "w") as f:
        f.write("best 99999999999\n")
    rc, err = run("keep", d, env={"KEEP_SELFTEST": "1"})
    check(rc == 0 and 0 < (best(d, "keep.sav") or 0) < 1000, "keep: an impossible record loads as none")
    os.remove(os.path.join(d, "keep.sav"))
    rc, err = run("keep", d, script=script("Keep", "720 down LOW", "721 up LOW", "800 quit"))
    check("keep demo" in err and "keep demo off" in err, "keep: the attract demo starts when idle and a press ends it")
    check(read(d, "keep.sav") is None, "keep: the demo never writes a record")
    a = tmpdir()
    run("keep", a, frames=1200, script="", env={"CAB_AUTOPLAY": "1", "CAB_SEED": "7"})
    b = tmpdir()
    run("keep", b, frames=1200, script="", env={"CAB_AUTOPLAY": "1", "CAB_SEED": "7"})
    check(read(a, "keep.sav") == read(b, "keep.sav") and read(a, "keep.sav"), "keep: the same seed plays the same round")
    rc, err = run("keep", d, script="", frames=1200, args=("-fast",), env={"CAB_AUTOPLAY": "1"})
    check(rc == 0 and (best(d, "keep.sav") or 0) > 0, "keep: -fast runs and saves")
    for x in (d, a, b):
        shutil.rmtree(x, ignore_errors=True)

    # Lamp.
    d = tmpdir()
    rc, err = run("lamp", d, script="", frames=2000, args=("-fast",), env={"CAB_AUTOPLAY": "1"})
    check((best(d, "lamp.sav") or 0) >= 1, "lamp: -fast still wakes a night")
    rc, err = run("lamp", d, script=script("Lamp", f"700 shot {out}/lamp-demo.bmp", "710 quit"))
    check("lamp demo" in err, "lamp: the attract demo starts when idle")
    shutil.rmtree(d, ignore_errors=True)

    # Tea: a button held from the menu must not pour a pile of tea; TL and TR care too.
    d = tmpdir()
    rc, err = run("tea", d, script=script("Tea", "0 down LOW", "1300 quit"))
    check("tea party" in err and "tea heart" not in err, "tea: a held button hurries the flight and pours nothing")
    rc, err = run("tea", d, script=script("Tea", "1100 down TL", "1101 up TL", "1140 down TR", "1141 up TR",
                                         "1180 down RIGHT", "1181 up RIGHT", "1200 down LOW", "1201 up LOW",
                                         f"1201 shot {out}/tea-heart.bmp", "1260 quit"))
    check("tea heart Pip 2" in err and "tea heart Moth 1" in err, "tea: TL, TR, and LOW each fill a heart; the stick moves the ring")
    check("pip teacup" in (read(d, "tea.sav") or ""), "tea: the gift is saved the moment it is given")
    with open(os.path.join(d, "tea.sav"), "w") as f:
        f.write("visits 0\npip teacup\n")
    rc, err = run("tea", d, script=script("Tea", f"960 shot {out}/tea-door.bmp", "1000 quit"))
    check("tea say Pip kept a teacup." in err, "tea: a cat who kept a gift runs to the door next visit")
    with open(os.path.join(d, "tea.sav"), "w") as f:
        f.write("visits banana\npip sparkles\n\x00\x01\n")
    rc, err = run("tea", d, script=script("Tea", "1000 quit"))
    check(rc == 0 and "visits 1" in (read(d, "tea.sav") or ""), "tea: a broken save opens as the first visit")
    with open(os.path.join(d, "tea.sav"), "w") as f:
        f.write("visits 2\n")
    rc, err = run("tea", d, script=script("Tea", f"1000 shot {out}/tea-nib.bmp", "1001 quit"))
    check("visits 3" in (read(d, "tea.sav") or "") and "tea say A kitten came to play." in err,
          "tea: Nib comes on the third visit")
    shutil.rmtree(d, ignore_errors=True)

    # Chest.
    d = tmpdir()
    rc, err = run("chest", d, script=script("Chest", "0 down LOW", "100 up LOW", "110 down TL", "111 up TL",
                                           "130 down TR", "131 up TR", "150 quit"))
    bolts = err.count("chest bolt")
    check(bolts == 2, f"chest: a held button waits for a new press; TL and TR shoot ({bolts} bolts)")
    with open(os.path.join(d, "chest.sav"), "w") as f:
        f.write("gems -4\n")
    rc, err = run("chest", d, script=script("Chest", "5 quit"))
    check("chest gems 0" in err, "chest: a broken save opens with no gems")
    rc, err = run("chest", d, script=script("Chest", f"200 shot {out}/chest-fight.bmp", "2400 quit"),
                  env={"CAB_AUTOPLAY": "1"})
    g = best(d, "chest.sav", "gems") or 0
    check(g >= 2, f"chest: the pile keeps every win ({g} gems)")
    shutil.rmtree(d, ignore_errors=True)

    # Chest: the walk to the key and the chest, then a zap from the side still hits (the sword aims itself).
    walk = ["0 down LEFT", "36 up LEFT", "36 down UP", "72 up UP", "72 down RIGHT", "104 up RIGHT", "104 down UP", "175 up UP"]
    d = tmpdir()
    rc, err = run("chest", d, script=script("Chest", *walk, "230 down LEFT", "260 up LEFT", "262 down LOW", "263 up LOW",
                                           "300 quit"))
    check("chest sword" in err and "chest mark 1" in err, "chest: in the fight the sword aims itself; a zap from the side hits")
    check("chest level 0" in err and "chest teleport" not in err, "chest: the first fight has no tricks")
    with open(os.path.join(d, "chest.sav"), "w") as f:
        f.write("gems 2\n")
    held = [f"{230 + 6 * i} down LOW" for i in range(200)] + [f"{232 + 6 * i} up LOW" for i in range(200)]
    rc, err = run("chest", d, script=script("Chest", *walk, *held, f"{230 + 6 * 200} quit"))
    check("chest level 2" in err and "chest teleport" in err and "chest shield" in err and "chest blocked" in err,
          "chest: after two gems Zam teleports and raises a shield that stops zaps")
    with open(os.path.join(d, "chest.sav"), "w") as f:
        f.write("gems 3\n")
    rc, err = run("chest", d, script=script("Chest", *walk, "1400 quit"))
    check("Three bubbles" in err, "chest: after three gems he throws three bubbles at once")
    shutil.rmtree(d, ignore_errors=True)

    # Tea: the song after the cheer, sixteen notes.
    d = tmpdir()
    presses = [f"{1000 + 34 * i} down LOW" for i in range(60)] + [f"{1002 + 34 * i} up LOW" for i in range(60)]
    moves = [f"{1000 + 34 * 3 * k + 20} down RIGHT" for k in range(1, 4)] + [f"{1000 + 34 * 3 * k + 24} up RIGHT" for k in range(1, 4)]
    rc, err = run("tea", d, script=script("Tea", *presses, *moves, f"{1000 + 34 * 60} quit"))
    check("tea cheer" in err and "tea song" in err, "tea: after the cheer every press plays the next note of a song")
    shutil.rmtree(d, ignore_errors=True)

    # The playtest tool: a live session, a few frames, a picture, a stop.
    try:
        subprocess.run([sys.executable, os.path.join(HERE, "playtest.py"), "start", "keep", "--name", "selftest"],
                       check=True, capture_output=True, timeout=60)
        r = subprocess.run([sys.executable, os.path.join(HERE, "playtest.py"), "do", "--name", "selftest",
                            "wait 5; tap LOW; look; hold RIGHT 10"], capture_output=True, text=True, timeout=60)
        subprocess.run([sys.executable, os.path.join(HERE, "playtest.py"), "stop", "--name", "selftest"],
                       capture_output=True, timeout=60)
        check("sheet:" in r.stdout and "now: frame 22 in Keep" in r.stdout,
              "playtest: a live session steps frames, presses the deck, and keeps a picture")
    except (subprocess.SubprocessError, OSError) as ex:
        check(False, f"playtest: a live session ({ex})")

    # Orb: the card file, the idle demo, and a clean title.
    d = tmpdir()
    card = os.path.join(d, "card")
    os.makedirs(card)
    with open(os.path.join(card, "label"), "w") as f:
        f.write("hello from the card\n")
    rc, err = run("orb", d, script=script("Orb", "700 quit"), env={"CAB_EXT": card})
    check(read(card, "orb-card") == "hello from the card\n", "orb: copies the card label")
    check("orb demo" in err and read(d, "orb.sav") is None, "orb: the idle demo plays and never saves")
    rc, err = run("orb", d, script="", frames=2000, env={"CAB_AUTOPLAY": "1"})
    check(rc == 0 and "orb dive" in err, "orb: the built-in pilot dives the well")
    shutil.rmtree(d, ignore_errors=True)

    # The Yard: wrap upward to Chest, open it, quit; a missing game leaves a note and the menu stays.
    d = tmpdir()
    s = "\n".join(["title=The Yard", "10 down UP", "11 up UP", "30 down LOW", "31 up LOW", "200 quit",
                   "title=Chest", "10 down 1P", "10 down 2P"]) + "\n"
    rc, err = run("yard", d, script=s, frames=600)
    check(best(d, "yard.sav") == 4 and "yard open chest" in err, "yard: up from the top row wraps to Chest")
    # A cart that falls over, and a native game whose program is missing: the menu stays.
    lone = os.path.join(d, "bin")
    os.makedirs(lone)
    shutil.copy(os.path.join(BIN, "yard"), lone)
    shelf = os.path.join(d, "carts")
    shutil.copytree(os.path.join(HERE, "carts"), shelf)
    with open(os.path.join(shelf, "keep", "main.lua"), "a") as f:
        f.write("\nfunction update() local t = nil; t.boom = 1 end\n")
    e = tmpdir()
    rc, err = run("yard", e, script=script("The Yard", "10 down LOW", "11 up LOW", f"100 shot {out}/yard-stumbled.bmp",
                                           "120 quit"), binary=os.path.join(lone, "yard"), env={"YARD_CARTS": shelf},
                  frames=900)
    check(rc == 0 and "keep error" in err and "keep stumbled" in err, "yard: a cart that errors shows its gentle screen and the menu comes back")
    e = tmpdir()
    rc, err = run("yard", e, script=script("The Yard", "10 down UP", "11 up UP", "12 down UP", "13 up UP", "14 down UP",
                                           "15 up UP", "40 down LOW", "41 up LOW", f"80 shot {out}/yard-missing.bmp", "100 quit"),
                  binary=os.path.join(lone, "yard"), env={"YARD_CARTS": shelf}, frames=600)
    check(rc == 0 and "could not open orb" in err, "yard: a missing game leaves a note and the menu stays")
    with open(os.path.join(d, "keep.sav"), "w") as f:
        f.write("best 42\n")
    rc, err = run("yard", d, script=script("The Yard", f"20 shot {out}/yard-stats.bmp", "21 quit"))
    check(rc == 0 and busy(f"{out}/yard-stats.bmp") > 20, "yard: draws with saves from other games present")
    shutil.rmtree(d, ignore_errors=True)
    say(f"  pictures in {out}")


# ---------------------------------------------------------------------------- system

def system():
    say("== system: the sandbox, the pack, the deploy tools, the templates ==")
    yard = os.path.join(BIN, "yard")
    shelf = tmpdir()

    def cart(cid, main):
        os.makedirs(os.path.join(shelf, cid))
        with open(os.path.join(shelf, cid, "info.lua"), "w") as f:
            f.write(f"return {{title = '{cid}', save = '{cid}'}}\n")
        with open(os.path.join(shelf, cid, "main.lua"), "w") as f:
            f.write(main)

    cart("loop", "function update() while true do end end\n")
    cart("hog", "local t = {}\nfunction update() for i = 1, 100000 do t[#t + 1] = string.rep('x', 1000) .. i end end\n")
    cart("leak", "function update() for i = 1, 40 do gfx.layer(1024, 1024) end end\n")
    cart("typo", "local score = 0\nfunction update() score = scroe + 1 end\n")
    cart("leaky", "function update() count = 1 end\n")
    cart("escape", "function init() local g = _G\n"
                   "  log('reach', rawget(g, 'io'), rawget(g, 'os'), rawget(g, 'require'), rawget(g, 'load'), rawget(g, 'dofile'),\n"
                   "      rawget(g, 'debug'), rawget(g, 'package'), string.dump)\n"
                   "  log('paths', pcall(gfx.image, '../../x.png'), pcall(import, '../x'), pcall(readtext, '/etc/passwd'))\n"
                   "  game.quit() end\n")

    def check_cart(cid, frames=300):
        r = subprocess.run([yard, "--check", cid], cwd=shelf, capture_output=True, text=True, timeout=300,
                           env={**os.environ, "SDL_VIDEODRIVER": "dummy", "SDL_AUDIODRIVER": "dummy",
                                "CAB_SCRIPT": "/dev/null", "YARD_CARTS": shelf, "YARD_CHECK_FRAMES": str(frames)})
        return r.stdout + r.stderr

    check("never ends" in check_cart("loop"), "sandbox: a loop that never ends is stopped with a plain message")
    check("memory" in check_cart("hog"), "sandbox: a cart that eats memory is stopped at its cap")
    check(check_cart("leak", 120).startswith("ok:"), "sandbox: layers made every frame are collected under the cap")
    check("unknown name 'scroe'" in check_cart("typo"), "sandbox: a misspelled name is an error, not a quiet nil")
    check("new global 'count'" in check_cart("leaky"), "sandbox: a forgotten 'local' inside update() is an error")
    out = check_cart("escape")
    check("reach nil nil nil nil nil nil nil nil" in out and "paths false" in out and out.count("false") >= 3,
          "sandbox: no io, os, require, load, debug, bytecode, or paths out of the cart")

    # The pack: built by ./cart pack, read back by the runtime, and a flipped bit drops just that cart.
    pak = os.path.join(shelf, "yard.pak")
    r = subprocess.run([sys.executable, os.path.join(HERE, "cart"), "pack", "--out", pak], capture_output=True, text=True)
    check(r.returncode == 0 and os.path.getsize(pak) == 4 << 20, "pack: ./cart pack makes a full-size yard.pak")
    empty = tmpdir()
    env = {**os.environ, "YARD_PAK": pak, "YARD_CARTS": empty}
    r = subprocess.run([yard, "--list"], cwd=empty, capture_output=True, text=True, env=env)
    listed = [l.split()[0] for l in r.stdout.splitlines() if "pak:" in l]
    check(set(listed) >= {"yard", "keep", "lamp", "orb", "tea", "chest"}, f"pack: the runtime reads every cart from it ({listed})")
    data = bytearray(open(pak, "rb").read())
    data[data.find(b"keep catch")] ^= 1
    bad = os.path.join(shelf, "bad.pak")
    open(bad, "wb").write(data)
    r = subprocess.run([yard, "--list"], cwd=empty, capture_output=True, text=True, env={**env, "YARD_PAK": bad})
    listed = [l.split()[0] for l in r.stdout.splitlines() if "pak:" in l]
    check("keep" not in listed and "tea" in listed and "checksum" in r.stderr, "pack: a damaged cart is skipped, the rest still load")

    # data_patch --overwrite: same-size file into its own blocks, nothing else moves.
    if shutil.which("mke2fs") and shutil.which("debugfs"):
        sys.path.insert(0, os.path.join(os.path.dirname(HERE), "tools"))
        import data_patch
        for bs in (1024, 4096):
            img = os.path.join(shelf, f"fs{bs}.img")
            with open(img, "wb") as f:
                f.truncate(16 << 20)
            subprocess.run(["mke2fs", "-q", "-t", "ext2", "-b", str(bs), img], check=True)
            a, b = os.path.join(shelf, "a.bin"), os.path.join(shelf, "b.bin")
            open(a, "wb").write(os.urandom(700000))
            open(b, "wb").write(os.urandom(700000))
            subprocess.run(["debugfs", "-w", "-R", f"write {a} pak", img], capture_output=True, check=True)
            before = subprocess.run(["debugfs", "-R", "blocks /pak", img], capture_output=True, text=True).stdout
            data_patch.overwrite(img, b, "pak")
            after = subprocess.run(["debugfs", "-R", "blocks /pak", img], capture_output=True, text=True).stdout
            dump = os.path.join(shelf, "dump.bin")
            subprocess.run(["debugfs", "-R", f"dump /pak {dump}", img], capture_output=True)
            fsck = subprocess.run(["e2fsck", "-fn", img], capture_output=True)
            check(before == after and open(dump, "rb").read() == open(b, "rb").read() and fsck.returncode == 0,
                  f"deploy: --overwrite rewrites a file in its own blocks (ext2, {bs}-byte blocks), fsck clean")
    else:
        say("  skip data_patch --overwrite (no e2fsprogs)")

    # Every template makes a cart that passes the gate.
    for t in sorted(os.listdir(os.path.join(HERE, "templates"))):
        tshelf = tmpdir()
        cid = f"t{t}"
        shutil.copytree(os.path.join(HERE, "templates", t), os.path.join(tshelf, cid))
        for name in os.listdir(os.path.join(tshelf, cid)):
            p = os.path.join(tshelf, cid, name)
            text = open(p).read().replace("{{ID}}", cid).replace("{{TITLE}}", t.title()).replace("{{SIZE}}", "small")
            open(p, "w").write(text)
        r = subprocess.run([yard, "--check", cid], cwd=tshelf, capture_output=True, text=True, timeout=300,
                           env={**os.environ, "SDL_VIDEODRIVER": "dummy", "SDL_AUDIODRIVER": "dummy", "CAB_AUTOPLAY": "1",
                                "CAB_SCRIPT": "/dev/null", "YARD_CARTS": tshelf, "YARD_CHECK_FRAMES": "900"})
        check(r.stdout.startswith("ok:"), f"template {t}: a new cart runs 15 seconds on its bot ({r.stdout.strip()[:60]})")
    r = subprocess.run([sys.executable, os.path.join(HERE, "tools", "bin2c.py"), "--check"], capture_output=True, text=True)
    check(r.returncode == 0, "the embedded font and library are fresh (tools/bin2c.py --check)")
    shutil.rmtree(shelf, ignore_errors=True)


# ---------------------------------------------------------------------------- love

LOVE_RUN = os.path.join(HERE, "out", "love-x86", "run.sh")
LOVE_CARTS = {"chest": "Chest", "keep": "Keep", "lamp": "Lamp", "tea": "Tea"}


def cart_lines(text, cid):
    return [l for l in text.splitlines() if l.startswith(cid + " ")]


def love():
    say("== love: the GPU runtime against the C runtime")
    if not os.path.exists(LOVE_RUN):
        say("  skip: no out/love-x86 (games/love/build.sh x86)")
        return
    d = tmpdir()
    yl = os.path.join(d, "yard.love")
    subprocess.run([os.path.join(HERE, "cart"), "love-pack", "--out", yl], check=True, capture_output=True)
    base = {"YARD_CARTS": os.path.join(HERE, "carts"), "SDL_AUDIODRIVER": "dummy"}
    # OpenAL ignores SDL_AUDIODRIVER; its null driver keeps ALSA from looking for a sound card.
    lenv = dict(base, YARD_HEADLESS="1", SDL_VIDEODRIVER="offscreen", ALSOFT_DRIVERS="null")
    # 1. The same seed and the same bot: every log line matches, so the game logic is the same.
    for cid, title in LOVE_CARTS.items():
        c_dir, l_dir = tmpdir(), tmpdir()
        sc = script(title, "1200 quit")
        _, c_err = run("yard", c_dir, sc, dict(base, CAB_AUTOPLAY="1"), args=(cid,), timeout=300)
        _, l_err = run("love", l_dir, sc, dict(lenv, CAB_AUTOPLAY="1"), args=(yl, cid), timeout=600, binary=LOVE_RUN)
        a, b = cart_lines(c_err, cid), cart_lines(l_err, cid)
        check(a and a == b, f"{cid}: the bot's game logs the same {len(a)} lines on both runtimes")
        check(read(c_dir, f"{cid}.sav") == read(l_dir, f"{cid}.sav"), f"{cid}: the same save file on both runtimes")
    # 2. The menu launches a cart in the same process and comes back to a drawn menu.
    m_dir = tmpdir()
    back, inlamp = os.path.join(m_dir, "back.png"), os.path.join(m_dir, "inlamp.png")
    sc = (f"title=The Yard\n10 down DOWN\n11 up DOWN\n30 down LOW\n31 up LOW\n150 shot {back}\n160 quit\n"
          f"title=Lamp\n10 shot {inlamp}\n20 down 1P\n20 down 2P\n")
    code, err = run("love", m_dir, sc, dict(lenv, CAB_MAX_FRAMES="400"), args=(yl,), timeout=300, binary=LOVE_RUN)
    check(code == 0, f"the menu runs, launches Lamp, and quits cleanly (exit {code})")

    def colors(path):
        try:
            from PIL import Image
        except ImportError:
            return 99 if os.path.exists(path) else 0
        try:
            im = Image.open(path).convert("RGB").resize((30, 40))
        except OSError:
            return 0
        px = im.tobytes()
        return len({(px[i] >> 4, px[i + 1] >> 4, px[i + 2] >> 4) for i in range(0, len(px), 3)})
    check(colors(inlamp) > 8, "Lamp draws a picture when the menu starts it")
    check(colors(back) > 8, "the menu draws again after Lamp quits")
    check("error" not in err.lower(), "no error on the way")


def main():
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    subprocess.run(["make", "-s", "TARGET=pc"], cwd=HERE, check=True)
    if which in ("quick", "all"):
        quick()
    if which in ("play", "all"):
        play()
    if which in ("stress", "all"):
        stress()
    if which in ("system", "all"):
        system()
    if which in ("love", "all"):
        love()
    say(f"== {passes} passed, {len(failures)} failed ==")
    for f in failures:
        say(f"  FAIL {f}")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
