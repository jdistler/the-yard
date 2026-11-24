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
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time

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
    for cart in ("yard", "keep", "lamp", "tea", "chest", "dig", "chomp", "kart", "safari", "tower", "garden", "bake", "band", "rocket"):
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
    check(rc == 0 and (best(d, "chest.sav", "gems") or 0) >= 1, f"chest: Zam and Pika bow and a gem is saved ({read(d, 'chest.sav')!r})")
    check("chest key" in err and "chest sword" in err, "chest: key, chest, sword in that order")
    check("chest zambow" in err and "chest pikapop" in err and "chest pika " in err and "chest victory" in err,
          "chest: after Zam bows, Pika jumps out and beating him triggers the victory celebration")

    rc, err = run("dig", d, script=shots("Dig", [20, 300, 1200], 1400), env={"CAB_AUTOPLAY": "1"})
    check(rc == 0 and (best(d, "dig.sav") or 0) >= 1, f"dig: a cave is cleared and saved ({read(d, 'dig.sav')!r})")
    check("dig pop" in err and "dig clear 1" in err and (best(d, "dig.sav", "gems") or 0) >= 1,
          "dig: pops critters, collects gems, and clears cave 1")

    rc, err = run("chomp", d, script=shots("Chomp", [60, 400, 1200], 1800), env={"CAB_AUTOPLAY": "1"})
    check(rc == 0 and "chomp stage 1" in err and ("chomp ghost" in err or "chomp clear 1" in err),
          f"chomp: bot plays maze, chomps ghosts or clears stage ({read(d, 'chomp.sav')!r})")

    for cid, title, key, log_want in (
        ("kart", "Star Kart", "best", "kart finish 1"),
        ("safari", "Safari", "caught", "safari catch"),
        ("tower", "Tower", "best", "tower rescue 1"),
        ("garden", "Garden", "blooms", "garden parade"),
        ("bake", "Bake", "treats", "bake serve 1"),
        ("band", "Band", "songs", "band encore 1"),
        ("rocket", "Starship", "best", "rocket land 1"),
    ):
        rc, err = run(cid, d, script=shots(title, [20, 300, 900], 1200), env={"CAB_AUTOPLAY": "1"})
        check(rc == 0 and (best(d, f"{cid}.sav", key) or 0) >= 1 and log_want in err,
              f"{cid}: bot plays, logs '{log_want}', and saves {key} ({read(d, f'{cid}.sav')!r})")

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
    for game, title in (("keep", "Keep"), ("lamp", "Lamp"), ("tea", "Tea"), ("chest", "Chest"), ("dig", "Dig"),
                        ("orb", "Orb"), ("yard", "The Yard")):
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
    check("chest fairies 3" in err, "chest: three purple fairies on the path after three gems")
    shutil.rmtree(d, ignore_errors=True)

    # Chest: the path's purple fairies and the bubble wand.
    d = tmpdir()
    rc, err = run("chest", d, script=script("Chest", "900 quit"))
    check("chest fairies 1" in err and "chest puff" in err and "chest hurt 3" in err and "chest pathback" in err,
          "chest: the first path has one purple fairy; three of her bubbles send him back to the start")
    rc, err = run("chest", d, script=script("Chest", "10 down LOW", "12 up LOW", "120 quit"))
    check("chest rescue" in err and "chest friends 1" in err, "chest: the wand aims itself; a bubbled fairy turns gold")
    rc, err = run("chest", d, script=script("Chest", "180 down LOW", "182 up LOW", "260 quit"))
    check("chest puff" in err and "chest popped" in err and "chest hurt" not in err,
          "chest: a wand bubble pops a purple bubble coming at him")
    rc, err = run("chest", d, script=script("Chest", "5 down LOW", "7 up LOW", *walk, "420 quit"))
    check("chest friend " in err and "chest wrap" in err, "chest: in the fight his gold fairy flies to Zam and wraps him")
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

    # Dig: held button waits for release; TL and TR pump; broken save opens fresh.
    d = tmpdir()
    rc, err = run("dig", d, script=script("Dig", "0 down LOW", "80 up LOW", "90 down TL", "91 up TL",
                                         "110 down TR", "111 up TR", "130 quit"))
    pumps = err.count("dig pump")
    check(pumps == 2, f"dig: a held button waits for a new press; TL and TR pump ({pumps} pumps)")
    with open(os.path.join(d, "dig.sav"), "w") as f:
        f.write("best -9\ngems nope\n")
    rc, err = run("dig", d, script=script("Dig", "5 quit"))
    check("dig best 0" in err, "dig: a broken save opens fresh")
    shutil.rmtree(d, ignore_errors=True)

    # The Yard: wrap upward to Starship (the last row), open it, quit; a missing game leaves a note and the menu stays.
    d = tmpdir()
    s = "\n".join(["title=The Yard", "10 down UP", "11 up UP", "30 down LOW", "31 up LOW", "200 quit",
                   "title=Starship", "10 down 1P", "10 down 2P"]) + "\n"
    rc, err = run("yard", d, script=s, frames=600)
    check(best(d, "yard.sav") == 13 and "yard open rocket" in err, "yard: up from the top row wraps to Starship")
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
    rc, err = run("yard", e, script=script("The Yard", "10 down DOWN", "11 up DOWN", "12 down DOWN", "13 up DOWN",
                                           "40 down LOW", "41 up LOW", f"80 shot {out}/yard-missing.bmp", "100 quit"),
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
    check(set(listed) >= {"yard", "keep", "lamp", "orb", "tea", "chest", "dig", "chomp", "kart", "safari", "tower", "garden", "bake", "band", "rocket"}, f"pack: the runtime reads every cart from it ({listed})")
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
            # A padded file, as deploy makes them: a program with zero runs inside, then zeros to the slot size.
            def padded(seed):
                r = __import__("random").Random(seed)
                body = bytes(r.getrandbits(8) for _ in range(200000)) + b"\0" * 9000 + bytes(r.getrandbits(8) for _ in range(50000))
                return body + b"\0" * ((1 << 20) - len(body))
            p1, p2 = os.path.join(shelf, "p1.bin"), os.path.join(shelf, "p2.bin")
            open(p1, "wb").write(padded(1))
            open(p2, "wb").write(padded(2))
            subprocess.run(["debugfs", "-w", "-R", f"write {p1} old", img], capture_output=True, check=True)
            try:
                data_patch.overwrite(img, p2, "old")
                holes_refused = False
            except SystemExit as e:
                holes_refused = "has holes" in str(e)
            check(holes_refused, f"deploy: a file debugfs left sparse is refused in place, with the fix named ({bs})")
            data_patch.put(img, p1, "slot", 0o755, 0, 0)
            data_patch.overwrite(img, p2, "slot")
            subprocess.run(["debugfs", "-R", f"dump /slot {dump}", img], capture_output=True)
            fsck = subprocess.run(["e2fsck", "-fn", img], capture_output=True)
            check(open(dump, "rb").read() == open(p2, "rb").read() and fsck.returncode == 0,
                  f"deploy: --put allocates every block of a padded file, so the next update is in place ({bs})")
            tmp_cat = os.path.join(shelf, "cat.bin")
            old_mode = data_patch.stat(img, "old")["mode"] & 0o7777
            check(data_patch.same_on_disk(img, p2, "slot", 0o755, tmp_cat)
                  and not data_patch.same_on_disk(img, p1, "slot", 0o755, tmp_cat)
                  and not data_patch.same_on_disk(img, p2, "slot", 0o644, tmp_cat)
                  and not data_patch.same_on_disk(img, p1, "old", old_mode, tmp_cat),
                  f"deploy: --put leaves an identical file alone, but not one with other bytes, mode, or holes ({bs})")
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

    # The menu scrolls: with the deploy's three test rows it has seventeen, and the stick reaches the last one.
    mshelf = tmpdir()
    for c in ("yard", "keep", "lamp", "orb", "tea", "chest", "dig", "chomp", "kart", "safari", "tower", "garden", "bake", "band", "rocket"):
        shutil.copytree(os.path.join(HERE, "carts", c), os.path.join(mshelf, c))
    for c in (("love", "label", "loveprobe"), ("love", "label", "loveyard"), ("sysprobe", "label", "sysprobe")):
        shutil.copytree(os.path.join(HERE, *c), os.path.join(mshelf, c[-1]))
    presses = "".join(f"{f} down DOWN\n{f + 1} up DOWN\n" for f in range(20, 20 + 10 * 16, 10))
    shot = os.path.join(mshelf, "menu.bmp")
    sc = f"title=The Yard\n{presses}200 shot {shot}\n210 down LOW\n211 up LOW\n"
    open(os.path.join(mshelf, "m.cab"), "w").write(sc)
    r = subprocess.run([yard, "--check", "yard"], cwd=mshelf, capture_output=True, text=True, timeout=300,
                       env={**os.environ, "SDL_VIDEODRIVER": "dummy", "SDL_AUDIODRIVER": "dummy", "CAB_SCALE": "1",
                            "CAB_SCRIPT": os.path.join(mshelf, "m.cab"), "YARD_CARTS": mshelf, "YARD_CHECK_FRAMES": "250",
                            "CAB_MAX_FRAMES": "251"})
    check("yard open sysprobe" in r.stdout + r.stderr, "the menu scrolls to its last row and opens it")
    check(busy(shot) > 8, "the scrolled menu draws a picture")
    shutil.rmtree(mshelf, ignore_errors=True)
    # The log a play test on the cabinet leaves behind (/data/Games/yard.log there; YARD_LOG here).
    lshelf = tmpdir()
    logp = os.path.join(lshelf, "yard.log")
    open(os.path.join(lshelf, "s.cab"), "w").write("title=The Yard\n40 down DOWN\n41 up DOWN\n60 down LOW\n61 up LOW\n")
    open(logp, "w").write("x" * (300 * 1024))   # an old, full log moves to yard.log.1
    subprocess.run([yard], cwd=lshelf, capture_output=True, text=True, timeout=300,
                   env={**os.environ, "SDL_VIDEODRIVER": "dummy", "SDL_AUDIODRIVER": "dummy", "CAB_SCALE": "1",
                        "CAB_SCRIPT": os.path.join(lshelf, "s.cab"), "CAB_MAX_FRAMES": "700", "YARD_LOG": logp,
                        "YARD_STATS": "1", "YARD_CARTS": os.path.join(HERE, "carts")})
    text = read(lshelf, "yard.log") or ""
    check(all(k in text for k in ("yard: start the menu", "cab: The Yard: video", "cab: audio", "yard open lamp",
                                  "yard: start lamp", "stats lamp frame 300", "lamp night 1")),
          "the log keeps each start's facts, the cart opened, frame times, and the cart's own lines")
    check(os.path.getsize(os.path.join(lshelf, "yard.log.1")) == 300 * 1024 and len(text) < 64 * 1024,
          "a log over 256 KB moves to yard.log.1 and a new one starts")
    shutil.rmtree(lshelf, ignore_errors=True)
    # A card laid out as SDCARD.md says: carts in yard/carts/<id>/ are listed; an id already shipped is not replaced.
    card = tmpdir()
    os.makedirs(os.path.join(card, "yard", "carts"))
    shutil.copytree(os.path.join(HERE, "carts", "keep"), os.path.join(card, "yard", "carts", "cardkeep"))
    info = os.path.join(card, "yard", "carts", "cardkeep", "info.lua")
    text = open(info).read().replace('title = "Keep"', 'title = "Card Keep"')
    open(info, "w").write(text)
    shutil.copytree(os.path.join(HERE, "carts", "lamp"), os.path.join(card, "yard", "carts", "keep"))
    r = subprocess.run([yard, "--list"], capture_output=True, text=True, timeout=60, env={**os.environ, "CAB_EXT": card})
    lines = r.stdout.splitlines()
    check(any(l.startswith("cardkeep") and "Card Keep" in l and card in l for l in lines),
          "a cart in the card's yard/carts is listed")
    check(not any(l.startswith("keep ") and card in l for l in lines), "a card cart cannot replace a shipped one")
    shutil.rmtree(card, ignore_errors=True)
    # The supervisor and the stock menu (on by default on the cabinet; YARD_SUPERVISE=1 here). A small
    # script stands in for /usr/bin/game.
    sup = tmpdir()
    fake = os.path.join(sup, "fakegame")
    open(fake, "w").write("#!/bin/sh\nwhile :; do sleep 1; done\n")
    os.chmod(fake, 0o755)

    def pids_of(name):
        out = []
        for d in os.listdir("/proc"):
            if d.isdigit():
                try:
                    st = open(f"/proc/{d}/stat").read()
                except OSError:
                    continue
                if f"({name})" in st and ") Z" not in st:
                    out.append(int(d))
        return out

    def run_sup(extra, script="title=The Yard\n30 quit\n", wait=60, keep_running=False):
        open(os.path.join(sup, "s.cab"), "w").write(script)
        logp = os.path.join(sup, "yard.log")
        if os.path.exists(logp):
            os.remove(logp)
        e = {**os.environ, "SDL_VIDEODRIVER": "dummy", "SDL_AUDIODRIVER": "dummy", "CAB_SCALE": "1",
             "CAB_SCRIPT": os.path.join(sup, "s.cab"), "YARD_LOG": logp, "YARD_SUPERVISE": "1",
             "YARD_STOCK_MENU": fake, "YARD_CARTS": os.path.join(HERE, "carts"), "YARD_CONF": os.path.join(sup, "conf"),
             **extra}
        p = subprocess.Popen([yard], cwd=sup, env=e, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)
        try:
            p.wait(timeout=wait)
        except subprocess.TimeoutExpired:
            if not keep_running:
                raise
            os.killpg(p.pid, 9)
            p.wait()
        return read(sup, "yard.log") or ""

    def stop_fakes():
        for pid in pids_of("fakegame"):
            os.kill(pid, 9)
        time.sleep(0.2)

    stop_fakes()
    first = subprocess.Popen([fake], start_new_session=True)
    time.sleep(0.3)
    open(os.path.join(sup, "conf"), "w").write("")
    log_text = run_sup({})
    adj = open(f"/proc/{first.pid}/oom_score_adj").read().strip()
    # Lowering a score needs CAP_SYS_RESOURCE: root on the cabinet has it, some test sandboxes do not.
    can_lower = subprocess.run(["sh", "-c", "echo -1 > /proc/self/oom_score_adj"], capture_output=True).returncode == 0
    protected = ("is protected from the OOM killer" in log_text and adj == "-1000") if can_lower \
        else "could not be protected" in log_text
    check(protected and pids_of("fakegame") == [first.pid],
          f"supervisor: the stock menu is protected from the OOM killer and left running (adj {adj}"
          f"{'' if can_lower else ', this sandbox cannot lower scores'})")
    first.kill()
    first.wait()
    stop_fakes()
    log_text = run_sup({})
    again = pids_of("fakegame")
    env_ok = again and "XDG_CONFIG_HOME=/userdata/" in open(f"/proc/{again[0]}/environ").read()
    check("started the stock menu again" in log_text and len(again) == 1 and env_ok,
          "supervisor: a stock menu that is gone is started again, with its own settings, when The Yard quits")
    stop_fakes()
    first = subprocess.Popen([fake], start_new_session=True)
    time.sleep(0.3)
    open(os.path.join(sup, "conf"), "w").write("stock_menu stop\n")
    log_text = run_sup({})
    first.wait(timeout=10)
    now = pids_of("fakegame")
    check("stopped the stock menu" in log_text and "started the stock menu again" in log_text and len(now) == 1
          and now[0] != first.pid, "supervisor: 'stock_menu stop' frees the stock menu's memory and starts it after")
    stop_fakes()
    open(os.path.join(sup, "conf"), "w").write("")
    log_text = run_sup({}, "title=The Yard\n30 down LOW\n31 up LOW\ntitle=Keep\n20 quit\n", wait=8,
                       keep_running=True)
    check("yard open keep" in log_text and "cart keep returned 0" in log_text
          and log_text.count("yard: start the menu") >= 2,
          "supervisor: the menu exits, the cart runs on its own, and a fresh menu comes back")
    # A game that cannot start: the fresh menu still says so (yard.returned).
    mc = os.path.join(sup, "mcarts")
    shutil.copytree(os.path.join(HERE, "carts", "yard"), os.path.join(mc, "yard"))
    shutil.copytree(os.path.join(HERE, "sysprobe", "label", "sysprobe"), os.path.join(mc, "sysprobe"))
    # Up once wraps to the last row, the probe (the PC runtime also lists the tree's own carts).
    log_text = run_sup({"YARD_CARTS": mc}, "title=The Yard\n30 down UP\n31 up UP\n60 down LOW\n61 up LOW\n",
                       wait=8, keep_running=True)
    check("native sysprobe returned 127" in log_text and "could not open sysprobe" in log_text,
          "supervisor: a game that is missing is still reported by the fresh menu")
    stop_fakes()
    # GPU yard first: a stand-in loveyard that exits with a chosen code.
    nd = os.path.join(sup, "native")
    os.makedirs(nd, exist_ok=True)
    failed = os.path.join(sup, "gpu-failed")
    def gpu_first(code):
        open(os.path.join(nd, "loveyard"), "w").write(f"#!/bin/sh\necho ran >> {nd}/ran\nexit {code}\n")
        os.chmod(os.path.join(nd, "loveyard"), 0o755)
        return run_sup({"YARD_NATIVE_DIR": nd, "YARD_GPU_FAILED": failed, "YARD_STOCK_FREEZE": freeze},
                       wait=20, keep_running=True)
    # The stock menu leaves this file when it is stopped mid-game; a menu started with it there stays black.
    freeze = os.path.join(sup, "minigui_freeze")
    open(freeze, "w").close()
    for f in os.listdir(sup):
        if f.endswith(".sav"):
            os.remove(os.path.join(sup, f))
    first = subprocess.Popen([fake], start_new_session=True)
    time.sleep(0.3)
    log_text = gpu_first(0)
    now = pids_of("fakegame")
    check("GPU yard returned 0" in log_text and "start the menu" not in log_text and "stopped the stock menu" in log_text
          and len(now) == 1 and now[0] != first.pid,
          "supervisor: The Yard opens on GPU yard, and leaving it leaves The Yard (stock menu back)")
    check(not os.path.exists(freeze) and "leftover" in log_text,
          "supervisor: the stock menu's leftover freeze file is removed before it starts again (else it stays black)")
    stop_fakes()
    log_text = gpu_first(10)
    check("GPU yard returned 10" in log_text and "classic Yard was asked for" in log_text and "start the menu" in log_text
          and not os.path.exists(failed), "supervisor: GPU yard's 'Classic yard' row opens the classic menu")
    stop_fakes()
    log_text = gpu_first(3)
    check("GPU yard failed (3)" in log_text and "start the menu" in log_text and os.path.exists(failed),
          "supervisor: a GPU yard that fails falls back to the classic menu")
    open(os.path.join(nd, "ran"), "w").write("")
    log_text = gpu_first(0)
    check(read(nd, "ran") == "" and "GPU yard returned" not in log_text and "start the menu" in log_text,
          "supervisor: after a failure, the rest of the boot opens on the classic menu")
    stop_fakes()
    # A row with memory = "all" (GPU yard): the stock menu is stopped just before it runs, not before.
    mm = os.path.join(sup, "mmcarts")
    shutil.copytree(os.path.join(HERE, "carts", "yard"), os.path.join(mm, "yard"))
    os.makedirs(os.path.join(mm, "memhog"))
    open(os.path.join(mm, "memhog", "info.lua"), "w").write(
        'return { title = "Memhog", native = "memhog", memory = "all", order = 0 }\n')
    for f in os.listdir(sup):
        if f.endswith(".sav"):
            os.remove(os.path.join(sup, f))   # the menu remembers its last row
    first = subprocess.Popen([fake], start_new_session=True)
    time.sleep(0.3)
    log_text = run_sup({"YARD_CARTS": mm}, "title=The Yard\n30 down LOW\n31 up LOW\n",
                       wait=8, keep_running=True)
    try:
        first.wait(timeout=5)
    except subprocess.TimeoutExpired:
        pass
    i_stop = log_text.find("stopped the stock menu")
    check(first.poll() is not None and i_stop >= 0 and "for memhog" in log_text
          and i_stop > log_text.find("yard: start the menu") and "native memhog returned 127" in log_text,
          "supervisor: a row with memory = \"all\" stops the stock menu just before it runs (GPU yard)")
    stop_fakes()
    shutil.rmtree(sup, ignore_errors=True)
    for script_path in (("sysprobe", "sysprobe.sh"), ("net", "yardnet.sh"), ("love", "loveprobe.sh")):
        r = subprocess.run(["sh", "-n", os.path.join(HERE, *script_path)], capture_output=True, text=True)
        check(r.returncode == 0, f"the cabinet script {script_path[-1]} parses (sh -n)")
    yardnet_checks()
    # Again with the cabinet's own shell and tools (busybox 1.27, under qemu), when the rootfs dump is here:
    # the stock tar has no -z, which only this run can catch.
    rootfs = os.environ.get("YARD_ROOTFS", os.path.expanduser("~/partycade-dumps/2026-10-23_raw_plug3032slc/rootfs"))
    if os.path.exists(os.path.join(rootfs, "bin", "busybox")) and shutil.which("qemu-arm-static"):
        yardnet_checks(rootfs)
    else:
        say("  skip: yardnet with the cabinet's busybox (no rootfs dump or qemu-arm-static)")
    shutil.rmtree(shelf, ignore_errors=True)


def yardnet_checks(rootfs=None):
    """games/net/yardnet.sh against a fake cabinet: a fake AC600, fake insmod/mount, a fake stick.
    With rootfs, the script runs in the cabinet's busybox ash and uses its busybox applets."""
    tag = "yardnet (cabinet busybox)" if rootfs else "yardnet"
    d = tmpdir()
    games, sysd, proc, tmp, fakebin, stick = (os.path.join(d, n) for n in ("Games", "sys", "proc", "tmp", "bin", "stick"))
    for p in (games, os.path.join(sysd, "class", "net", "lo"), os.path.join(sysd, "bus", "usb", "devices", "1-1"),
              os.path.join(proc, "sys", "kernel"), tmp, fakebin, os.path.join(stick, "yard")):
        os.makedirs(p, exist_ok=True)
    open(os.path.join(sysd, "bus", "usb", "devices", "1-1", "idVendor"), "w").write("2357\n")
    open(os.path.join(sysd, "bus", "usb", "devices", "1-1", "idProduct"), "w").write("011e\n")
    for n, t in (("uptime", "10.00 5.00\n"), ("modules", ""), ("mounts", ""), ("sys/kernel/panic_on_oops", "1\n")):
        open(os.path.join(proc, n), "w").write(t)
    calls = os.path.join(d, "calls.txt")
    fakes = {
        # insmod: "loads" a module, and the driver makes a Wi-Fi interface.
        "insmod": f'echo "insmod $1" >> {calls}; m=$(basename "$1" .ko); echo "$m 1 0 - Live 0x0" >> {proc}/modules\n'
                  f'[ "$m" = 8821au ] && mkdir -p {sysd}/class/net/wlan0/phy80211\nexit 0\n',
        "mount": f'eval t=\\${{$#}}; cp -a {stick}/. "$t"/; echo "mount $*" >> {calls}\n',
        "umount": f't="$1"; rm -rf {stick}; mkdir -p {stick}; cp -a "$t"/. {stick}/; rm -rf "$t"/*; echo umount >> {calls}\n',
        "ip": f'[ -f {d}/addr ] && [ "$5" = wlan0 ] && echo "    inet 192.168.1.50/24 brd x scope global wlan0"\nexit 0\n',
        "ifconfig": "exit 0\n", "udhcpc": f'echo "udhcpc $2" >> {calls}\n', "dmesg": "echo fake dmesg\n",
        "sync": "exit 0\n", "lsusb": "exit 0\n", "free": "exit 0\n", "df": "exit 0\n", "sleep": "exit 0\n",
    }
    for n, body in fakes.items():
        p = os.path.join(fakebin, n)
        open(p, "w").write("#!/bin/sh\n" + body)
        os.chmod(p, 0o755)
    shell = ["sh"]
    if rootfs:
        bb = os.path.join(rootfs, "bin", "busybox")
        for n in ("tar", "gzip", "sha256sum", "cut", "grep", "cat", "cp", "mv", "rm", "mkdir", "chmod", "touch",
                  "tail", "head", "awk", "wc", "ls", "cmp", "date", "uptime", "basename", "printf"):
            if n not in fakes:
                p = os.path.join(fakebin, n)
                open(p, "w").write(f'#!/bin/sh\nexec qemu-arm-static -L {rootfs} {bb} {n} "$@"\n')
                os.chmod(p, 0o755)
        shell = ["qemu-arm-static", "-L", rootfs, bb, "ash"]
    # The Wi-Fi bundle: two "modules", a wpa_supplicant that records how it was started, and the id list.
    w = os.path.join(d, "w")
    os.makedirs(w)
    for n in ("cfg80211.ko", "8821au.ko"):
        open(os.path.join(w, n), "w").write("x")
    open(os.path.join(w, "wpa_supplicant"), "w").write(f'#!/bin/sh\necho "wpa $*" >> {calls}\n')
    os.chmod(os.path.join(w, "wpa_supplicant"), 0o755)
    open(os.path.join(w, "usb-ids.txt"), "w").write("2357:011e\n")
    subprocess.run(["tar", "-czf", os.path.join(games, "wifi.tar.gz"), "-C", w, "."], check=True)
    env = dict(os.environ, PATH=fakebin + ":" + os.environ["PATH"], YARDNET_GAMES=games, YARDNET_SYS=sysd,
               YARDNET_PROC=proc, YARDNET_TMP=tmp)
    script_path = os.path.join(HERE, "net", "yardnet.sh")

    def once():
        subprocess.run(shell + [script_path, "--once"], env=env, timeout=120, capture_output=True)
        return read(games, "net.log") or "", (open(calls).read() if os.path.exists(calls) else "")

    def reboot():   # /tmp and the loaded modules do not survive a power cycle; /data does
        shutil.rmtree(tmp); os.makedirs(tmp)
        open(os.path.join(proc, "modules"), "w").write("")
        shutil.rmtree(os.path.join(sysd, "class", "net", "wlan0"), ignore_errors=True)

    log, c = once()
    check("no " in log and "wifi.conf" in log and "insmod" not in c,
          f"{tag}: the AC600 without a wifi.conf loads nothing and says what is missing")
    # A stick: the Wi-Fi settings, a file to put in /data/Games, and a script; then the logs come back on it.
    open(os.path.join(stick, "yard", "wifi.conf"), "w").write('network={\n ssid="home"\n psk=00\n}\n')
    open(os.path.join(d, "hello.txt"), "w").write("hi\n")
    subprocess.run(["tar", "-cf", os.path.join(stick, "yard", "put.tar"), "-C", d, "hello.txt"], check=True)
    open(os.path.join(stick, "yard", "run.sh"), "w").write("echo ran-on-cabinet\n")
    os.makedirs(os.path.join(sysd, "block", "sda"))
    log, c = once()
    check(read(os.path.join(games, "net"), "wifi.conf") is not None and read(games, "hello.txt") == "hi\n",
          f"{tag}: a stick's yard/wifi.conf and yard/put.tar go into /data/Games")
    check(read(os.path.join(stick, "yard"), "run.log") == "ran-on-cabinet\n" and os.path.exists(os.path.join(stick, "yard", "done.txt"))
          and os.path.exists(os.path.join(stick, "yard", "logs", "net.log")),
          f"{tag}: the stick's run.sh runs, and the logs and done.txt are written back to it")
    check("insmod" in c and c.index("cfg80211.ko") < c.index("8821au.ko") and "wpa -B -i wlan0 -D nl80211" in c,
          f"{tag}: with a wifi.conf it loads cfg80211, then 8821au, then starts wpa_supplicant on wlan0")
    check(read(os.path.join(proc, "sys", "kernel"), "panic_on_oops") == "0\n" and os.path.exists(os.path.join(games, "net", "wifi.trying")),
          f"{tag}: an oops is not made a panic, and the guard file is set during the start")
    # The stick stays in: it is read once per insertion, not every pass.
    n_mounts = c.count("mount ")
    log, c = once()
    check(c.count("mount ") == n_mounts, f"{tag}: a stick left in is read only once")
    # Two starts that never finished (a freeze or reset each time): the third boot leaves Wi-Fi alone.
    shutil.rmtree(os.path.join(sysd, "block", "sda"))
    reboot(); log, c = once()
    check("did not finish" in log and "1 time" in log and c.count("insmod") == 4,
          f"{tag}: a start that did not finish is counted, and Wi-Fi is tried once more")
    reboot(); open(calls, "w").write(""); log, c = once()
    check("not trying again" in log and "insmod" not in c, f"{tag}: after two failed starts it stops trying")
    # A stick resets that; a clean start (an address, here) clears the guard.
    os.makedirs(os.path.join(sysd, "block", "sda"))
    reboot(); open(calls, "w").write(""); open(os.path.join(d, "addr"), "w").write("")
    log, c = once()
    log, c = once()
    check("insmod" in c and "start finished cleanly" in log and not os.path.exists(os.path.join(games, "net", "wifi.trying")),
          f"{tag}: a stick clears the failed starts, and an address clears the guard file")


# ---------------------------------------------------------------------------- love

LOVE_RUN = os.path.join(HERE, "out", "love-x86", "run.sh")
LOVE_CARTS = {
    "chest": "Chest", "dig": "Dig", "chomp": "Chomp", "keep": "Keep", "lamp": "Lamp", "tea": "Tea",
    "kart": "Star Kart", "safari": "Safari", "tower": "Tower",
    "garden": "Garden", "bake": "Bake", "band": "Band", "rocket": "Starship",
}


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
    # game.gpu: false on the C runtime, true on LÖVE (carts use it only to choose a drawing).
    gc = tmpdir()
    os.makedirs(os.path.join(gc, "gpucheck"))
    open(os.path.join(gc, "gpucheck", "info.lua"), "w").write('return { title = "Gpucheck" }\n')
    open(os.path.join(gc, "gpucheck", "main.lua"), "w").write(
        'function init() log("gpucheck " .. tostring(game.gpu)) end\nfunction update() end\nfunction draw() end\n')
    c_dir, l_dir = tmpdir(), tmpdir()
    _, c_err = run("yard", c_dir, script("Gpucheck", "30 quit"), dict(base, YARD_CARTS=gc), args=("gpucheck",), timeout=120)
    _, l_err = run("love", l_dir, script("Gpucheck", "30 quit"), dict(lenv, YARD_CARTS=gc), args=(yl, "gpucheck"),
                   timeout=300, binary=LOVE_RUN)
    check("gpucheck false" in c_err and "gpucheck true" in l_err,
          "game.gpu is false on the C runtime and true on the GPU runtime")
    # Interactive music (music.track, music.cue, music.play{keep}): the same on both runtimes, and a wrong
    # `at` is an error the cart can read.
    mc = tmpdir()
    os.makedirs(os.path.join(mc, "musiccheck"))
    open(os.path.join(mc, "musiccheck", "info.lua"), "w").write('return { title = "Musiccheck", save = "musiccheck" }\n')
    open(os.path.join(mc, "musiccheck", "main.lua"), "w").write(
        'local A = {bpm = 240, steps = 2, {"C5 E5 G5 E5", wave = "tri", vol = 0.1}, {"C3 - G2 -", wave = "sine"}}\n'
        'local f = 0\n'
        'function init() music.play(A) music.track(2, 0) end\n'
        'function update() f = f + 1\n'
        '  if f == 5 then music.track(2, 1) music.cue{wave = "sine", note = 72, at = "beat"} end\n'
        '  if f == 20 then A.keep = true music.play(A) log("kept " .. tostring(music.step() > 0)) end\n'
        '  if f == 25 then log("badat " .. tostring(not pcall(music.cue, {at = "later"}))) end\n'
        '  if f == 30 then music.stop() music.cue{note = 60} log("musicdone") end\n'
        '  if f == 35 then save.set("gift", 7) save.set("bow", "gold") save.write()\n'
        '    log("peek " .. save.peek("musiccheck", "gift", 0) .. " " .. save.peek("musiccheck", "bow", 3) .. " "\n'
        '        .. save.peek("musiccheck", "bow", "x") .. " " .. save.peek("nosuchcart", "gift", 9)) end end\n'
        'function draw() end\n')
    c_dir, l_dir = tmpdir(), tmpdir()
    # (CAB_AUDIO_WAV: the C synth pulled once a frame, so the sequencer runs without a sound device)
    wav = os.path.join(c_dir, "m")
    _, c_err = run("yard", c_dir, script("Musiccheck", "60 quit"), dict(base, YARD_CARTS=mc, CAB_AUDIO_WAV=wav),
                   args=("musiccheck",), timeout=120)
    pcm = b"".join(open(os.path.join(c_dir, f), "rb").read()[44:] for f in os.listdir(c_dir) if f.endswith(".wav"))
    check(len(pcm) > 0 and max(pcm) > 8, f"the C runtime's music check made sound ({len(pcm)} bytes)")
    _, l_err = run("love", l_dir, script("Musiccheck", "60 quit"), dict(lenv, YARD_CARTS=mc), args=(yl, "musiccheck"),
                   timeout=300, binary=LOVE_RUN)
    for name, err in (("C", c_err), ("GPU", l_err)):
        check("peek 7 3 gold 9" in err, f"save.peek reads another cart's save, with save.get's defaults, on the {name} runtime")
        check(all(w in err for w in ("kept true", "badat true", "musicdone")),
              f"interactive music (track levels, cues on the beat, keep) works on the {name} runtime")
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
    # 3. On the cabinet a native program (Orb) runs after LÖVE quits: the menu writes the request and exits.
    n_dir = tmpdir()
    req = os.path.join(n_dir, "launch")
    sc = "title=The Yard\n10 down DOWN\n11 up DOWN\n20 down DOWN\n21 up DOWN\n40 down LOW\n41 up LOW\n"
    code, err = run("love", n_dir, sc, dict(lenv, CAB_MAX_FRAMES="600", YARD_LAUNCH_FILE=req), args=(yl,),
                    timeout=300, binary=LOVE_RUN)
    check(code == 0 and (read(n_dir, "launch") or "").strip() == "native:orb",
          f"GPU menu: opening Orb asks the launcher for it and quits LÖVE (exit {code})")
    # 4. Started again after it, the menu says how it went.
    code, err = run("love", n_dir, "title=The Yard\n30 quit\n", dict(lenv, YARD_RETURNED="orb missing"), args=(yl,),
                    timeout=300, binary=LOVE_RUN)
    check("could not open orb" in err, "GPU menu: a native program that could not start is reported (yard.returned)")
    # 4. GPU yard's last row is "Classic yard" (its own row and the LÖVE probe are hidden); the classic menu's
    # last row is "GPU yard" instead. Up from the first row wraps to the last.
    lc = tmpdir()
    shutil.copytree(os.path.join(HERE, "carts", "yard"), os.path.join(lc, "yard"))
    shutil.copytree(os.path.join(HERE, "carts", "keep"), os.path.join(lc, "keep"))
    for n in ("loveyard", "loveprobe", "classic"):
        shutil.copytree(os.path.join(HERE, "love", "label", n), os.path.join(lc, n))
    sc = "title=The Yard\n20 down UP\n21 up UP\n40 down LOW\n41 up LOW\n"
    g_dir = tmpdir()
    code, err = run("love", g_dir, sc, dict(lenv, CAB_MAX_FRAMES="600", YARD_CARTS=lc,
                                            YARD_LAUNCH_FILE=os.path.join(g_dir, "launch")),
                    args=(yl,), timeout=300, binary=LOVE_RUN)
    check((read(g_dir, "launch") or "").strip() == "native:classic",
          "GPU menu: the last row is 'Classic yard', and it asks the launcher for the classic menu")
    k_dir = tmpdir()
    _, k_err = run("yard", k_dir, sc, dict(base, YARD_CARTS=lc, CAB_MAX_FRAMES="600"), timeout=180)
    check("yard open loveyard" in k_err and "classic" not in k_err.split("yard open")[-1][:20],
          "classic menu: the last row is 'GPU yard', and 'Classic yard' is not shown")
    # 5. Outlined labels painted inside a clip (the menu's row titles) hold their text. 2026-10-27: the clip
    # carried onto the label's canvas, nothing was painted, and the cabinet showed magenta blocks.
    # The list clips only with more rows than fit, as on the cabinet (its test rows): every cart and label.
    d_dir, rows_dir = tmpdir(), tmpdir()
    for base_dir in (os.path.join(HERE, "carts"), os.path.join(HERE, "love", "label")):
        for n in os.listdir(base_dir):
            if os.path.isfile(os.path.join(base_dir, n, "info.lua")) and not os.path.exists(os.path.join(rows_dir, n)):
                shutil.copytree(os.path.join(base_dir, n), os.path.join(rows_dir, n))
    _, err = run("love", d_dir, "title=The Yard\n60 quit\n", dict(lenv, YARD_LABEL_DEBUG="1", YARD_CARTS=rows_dir),
                 args=(yl,), timeout=300, binary=LOVE_RUN)
    painted = re.findall(r'label "([^"]+)" \d+x\d+ covered (\d+) of', err)
    rows = [n for n, c in painted if n in ("Keep", "Lamp", "Tea", "Chest")]
    empty = [n for n, c in painted if int(c) == 0]
    check(len(rows) >= 3 and not empty,
          f"GPU menu: every outlined label holds its text, row titles in the clip too ({len(painted)} painted, empty: {empty})")


# The classics' save files as they were on the cabinet (2026-10-27), and the high scores each game showed on
# its attract screen then (tools/cabview screenshots): Home's decoders must agree.
CLASSIC_SAVES = {'DigDug.sav': '010000010000010000010000017800001c351c2635261a351a2735271d2e20000101010107', 'DigDugII.sav': '000002000000204b415a5520ffffff050000020000002059414d4120ffffff04000002000000534947455255ffffff030000020000004a554e4b4f20ffffff020000020000004d4959554b49ffffff01', 'Galaga.sav': '00080604042400000000022400000000022400000000022400000000022413181c172a170a2a0a162a160c2a0c', 'Galaxian.sav': '603300', 'Mappy.sav': '0020000003424548001987000355484f0017560002484f5900121300024441500010320001505941', 'PacLand.sav': '0008000000e4e5e5e5e50000000000000003000000e4e5e5e5e60000000000000003000000e4e5e5e6e60000000000000003000000e4e5e6e6e60000000000000003000000e4e6e6e6e6', 'PacMan.sav': '601702', 'PacManFast.sav': '908501', 'PacManPlus.sav': '701800', 'PacMania.sav': '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f245600000000010200020101000000007f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a6a600010000055441520000900005444149000080000446465000007000045041430000600003424f4f000050000357414e00004000024b415a00003000025a554e0000200001544f4d000010000154414d', 'PacandPal.sav': '003000001a251aff00300000202520ff00300000212521ff00300000222522ff00300000232523ff', 'Rompers.sav': '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f258300000000010200020005000100004d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a6a6000029db00001388000010e50000105900000fa000000001000701050000000005000000000000000403020500000000040108050000000004000000414f45595549414f45414f454a4f450b05060605', 'Speed.cfg': '010000000000000000000000', 'SuperPacMan.sav': '003000004e404e200030000041404120003000004d404d200030000043404320003000004f404f20'}
CLASSIC_SCORES = "0=18590 1=30000 2=30000 3=1870 4=80000 5=100000 6=44680 7=3360 8=20000 9=17800 10=20000 11=107150"


# ---------------------------------------------------------------------------- home

def home():
    say("== home: Partycade Home's choices (headless, scripted)")
    if not os.path.exists(LOVE_RUN):
        say("  skip: no out/love-x86 (games/love/build.sh x86)")
        return
    d = tmpdir()
    hl = os.path.join(d, "home.love")
    subprocess.run([os.path.join(HERE, "cart"), "home-pack", "--out", hl], check=True, capture_output=True)

    def home_run(lines, mode=None):
        w = tmpdir()
        sc = os.path.join(w, "script")
        # Frames, uncapped (~600/s on the PC): a launch writes its request after a 0.6 s flash.
        last = max(int(l.split()[0]) for l in lines)
        open(sc, "w").write("\n".join(lines + [f"{last + 2000} quit"]) + "\n")
        env = dict(os.environ, SDL_AUDIODRIVER="dummy", SDL_VIDEODRIVER="offscreen", ALSOFT_DRIVERS="null",
                   HOME_HEADLESS="1", HOME_SKIP_INTRO="1", HOME_SCRIPT=sc, HOME_REQ=os.path.join(w, "req"),
                   HOME_STATE=os.path.join(w, "state"), HOME_LOG=os.path.join(w, "log"),
                   HOME_GAMES=os.path.join(w, "games"), HOME_ART=os.path.join(w, "art"))
        if mode:
            env["HOME_MODE"] = mode
        r = subprocess.run([LOVE_RUN, hl], cwd=w, env=env, capture_output=True, text=True, timeout=120)
        if os.environ.get("HOME_TEST_DEBUG"):
            say(r.stdout + r.stderr + (read(w, "log") or ""))
        return (read(w, "req") or "").strip()

    games = tmpdir()
    for name, hexbytes in CLASSIC_SAVES.items():
        b = bytes.fromhex(hexbytes)
        if name.endswith(".sav") and len(b) > 200:
            b = b[:2048].ljust(2048, b"\0") + b[2048:]
        open(os.path.join(games, name), "wb").write(b)
    w = tmpdir()
    open(os.path.join(w, "script"), "w").write("5 quit\n")
    env = dict(os.environ, SDL_AUDIODRIVER="dummy", SDL_VIDEODRIVER="offscreen", ALSOFT_DRIVERS="null",
               HOME_HEADLESS="1", HOME_SKIP_INTRO="1", HOME_SCRIPT=os.path.join(w, "script"),
               HOME_LOG=os.path.join(w, "log"), HOME_GAMES=games)
    subprocess.run([LOVE_RUN, hl], cwd=w, env=env, capture_output=True, timeout=120)
    got = ((read(w, "log") or "").split("high scores: ") + [""])[1].split("\n")[0].strip()
    check(got == CLASSIC_SCORES, f"Home: the twelve classics' high scores decode as the games show them ({got})")
    # Back from Galaxian with a better score than it had at launch: celebrated; the same score: not.
    for before, want in (("100", True), ("3360", False)):
        open(os.path.join(w, "state"), "w").write(f"sel 8\nscore 7 {before}\n")
        env["HOME_STATE"] = os.path.join(w, "state")
        open(os.path.join(w, "log"), "w").close()
        subprocess.run([LOVE_RUN, hl], cwd=w, env=env, capture_output=True, timeout=120)
        hit = "new high score 7" in (read(w, "log") or "")
        check(hit == want, f"Home: back from a classic, a new high score is celebrated only when it is new (was {before})")
    # The secret code: party mode, and it changes nothing (the card, the classics' settings, no launch).
    w2 = tmpdir()
    g2 = os.path.join(w2, "games")
    os.makedirs(g2)
    open(os.path.join(g2, "Speed.cfg"), "wb").write(bytes([1] + [0] * 11))
    code = ["up", "up", "down", "down", "left", "right", "left", "right", "tl", "low"]
    open(os.path.join(w2, "script"), "w").write(
        "".join(f"{30 + 3 * i} press {k}\n" for i, k in enumerate(code)) + "2000 quit\n")
    open(os.path.join(w2, "state"), "w").write("sel 1\n")
    env2 = dict(env, HOME_GAMES=g2, HOME_SCRIPT=os.path.join(w2, "script"), HOME_STATE=os.path.join(w2, "state"),
                HOME_LOG=os.path.join(w2, "log"), HOME_REQ=os.path.join(w2, "req"))
    subprocess.run([LOVE_RUN, hl], cwd=w2, env=env2, capture_output=True, timeout=120)
    check("party mode" in (read(w2, "log") or "") and not os.path.exists(os.path.join(w2, "req"))
          and open(os.path.join(g2, "Speed.cfg"), "rb").read() == bytes([1] + [0] * 11),
          "Home: the secret code starts party mode, launches nothing, and leaves the classics' settings as they were")
    # The night show's schedule: every night ends and is full (2026-10-27: a night whose last gap was shorter
    # than a scene spun for ever and froze Home).
    nd = tmpdir()
    shutil.copy(os.path.join(HERE, "love", "home", "night.lua"), nd)
    open(os.path.join(nd, "conf.lua"), "w").write("function love.conf(t) t.window = false t.modules.audio = false end\n")
    open(os.path.join(nd, "main.lua"), "w").write(
        'local N = require("night")\n'
        'function love.load()\n'
        '  local fewest = 1e9\n'
        '  for night = 0, 1999 do\n'
        '    local seen, n = {}, 0\n'
        '    for at = 0, N.CYCLE - 1, 60 do\n'
        '      local _, e = N.scene_at(night * N.CYCLE + at)\n'
        '      if e and not seen[e.t0] then seen[e.t0] = true n = n + 1 end\n'
        '    end\n'
        '    fewest = math.min(fewest, n)\n'
        '  end\n'
        '  print("fewest scenes in a night " .. fewest)\n'
        '  love.event.quit()\n'
        'end\n')
    r = subprocess.run([LOVE_RUN, nd], env=dict(os.environ, SDL_VIDEODRIVER="offscreen"), capture_output=True,
                       text=True, timeout=60)
    m = re.search(r"fewest scenes in a night (\d+)", r.stdout)
    check(m and int(m.group(1)) >= 20, f"Home: the night show's schedule ends for 2000 nights, each full ({r.stdout.strip()})")
    req = home_run(["30 press low"])
    check(req.startswith("classic 0 "), f"Home: the lower button on the first card asks for Pac-Man ({req!r})")
    req = home_run(["30 press 1p"])
    check(req.startswith("classic 0 "), f"Home: a 1-player tap starts the game too ({req!r})")
    # Headless runs uncapped (~600 fps on the PC) and the hold is in seconds: 1500 frames is over a second.
    req = home_run(["30 down 1p", "33 down 2p", "1500 up 1p", "1500 up 2p"], mode="preview")
    check(req == "yard", f"Home preview: holding 1P + 2P goes back to The Yard and starts nothing ({req!r})")
    req = home_run(["30 down 1p", "33 down 2p", "45 up 2p", "46 up 1p"], mode="preview")
    check(req == "", f"Home preview: a short 1P + 2P press does nothing ({req!r})")
    req = home_run(["30 down 1p", "33 down 2p", "1500 up 1p", "1500 up 2p"])
    check(req == "", f"Home at power-on: the 1P + 2P hold does not leave the front end ({req!r})")
    req = home_run(["40 up 1p"])
    check(req == "", f"Home: a 1-player release it never saw pressed (the end of a game's exit hold) starts nothing ({req!r})")
    req = home_run(["30 down 1p", "1500 up 1p"])
    check(req == "", f"Home: a long 1-player hold is not a tap ({req!r})")
    # FAVORITES (favs.lua): the empty card starts nothing; a game's time is credited once, and its card launches it.
    w = tmpdir()
    stats = os.path.join(w, "stats.tsv")
    st = os.path.join(w, "state")
    sc = os.path.join(w, "script")
    env = dict(os.environ, SDL_AUDIODRIVER="dummy", SDL_VIDEODRIVER="offscreen", ALSOFT_DRIVERS="null",
               HOME_HEADLESS="1", HOME_SKIP_INTRO="1", HOME_SCRIPT=sc, HOME_REQ=os.path.join(w, "req"),
               HOME_STATE=st, HOME_LOG=os.path.join(w, "log"), HOME_GAMES=os.path.join(w, "games"),
               HOME_ART=os.path.join(w, "art"), HOME_STATS=stats, SHELF_LIB=os.path.join(w, "nolib"))
    open(st, "w").write("sel 2\nselkey fav:none\nshow auto\n")
    open(sc, "w").write("30 press up\n40 press low\n2000 quit\n")
    subprocess.run([LOVE_RUN, hl], cwd=w, env=env, capture_output=True, timeout=120)
    check((read(w, "req") or "").strip() == "", "Home: the empty FAVORITES card starts nothing")
    open(st, "w").write("sel 2\nselkey classic:6\nplayed 8\nplayedkey classic:6\nshow auto\nran 125\n")
    open(sc, "w").write("30 quit\n")
    subprocess.run([LOVE_RUN, hl], cwd=w, env=env, capture_output=True, timeout=120)
    got = read(w, "stats.tsv") or ""
    check("classic:6\t1\t125\t" in got and "ran" not in (read(w, "state") or ""),
          f"Home: a game's play time is credited to what was launched, once ({got.strip()!r})")
    open(st, "w").write("sel 1\nselkey fav:classic:6\nshow auto\n")
    # (after 0.6 s: just back from a game, Home ignores a lower button still being mashed)
    open(sc, "w").write("900 press low\n3000 quit\n")
    if os.path.exists(os.path.join(w, "req")):
        os.remove(os.path.join(w, "req"))
    subprocess.run([LOVE_RUN, hl], cwd=w, env=env, capture_output=True, timeout=120)
    req = (read(w, "req") or "").strip()
    check(req.startswith("classic 6 "), f"Home: the FAVORITES card launches the game it stands for ({req!r})")
    # 2026-11-08: ut_season.txt written while a game was "in" (no score, no detail) crashed Home on the next
    # power-on before ut.json existed (main.lua update_cards: string.upper(g.detail) on nil).
    ut_season = os.path.join(w, "ut_season.txt")
    open(ut_season, "w").write(
        "team\t7\t6-2\n"
        "game\t2026-11-07T17:00Z\t1\tin\t2\tMIZ\tMissouri\tMissouri\t0\t0\t\t\t0\tMemorial Stadium\t\t18\n"
        "game\t2026-11-14T05:00Z\t0\tpre\t2\tLSU\tLSU\tLSU\t0\t0\t\t\t0\tTiger Stadium (LA)\t\t14\n")
    open(sc, "w").write("30 quit\n")
    open(os.path.join(w, "log"), "w").close()
    env_ut = dict(env, HOME_UT_JSON=os.path.join(w, "no_ut.json"), HOME_UT_SEASON=ut_season, HOME_UT_NOW="10")
    r = subprocess.run([LOVE_RUN, hl], cwd=w, env=env_ut, capture_output=True, text=True, timeout=120)
    ut_log = read(w, "log") or ""
    check(r.returncode == 0 and "ERROR" not in ut_log and "utgame: season 2 games" in ut_log,
          f"Home: a cached ut_season.txt with an 'in' row starts cleanly at cold boot (rc {r.returncode})")
    # guard.lua and homeloop's safe mode: a module that fails is turned off, not Home; safe mode still plays.
    for failing in ("longhorns", "tv", "games card"):
        w2 = tmpdir()
        sc2 = os.path.join(w2, "script")
        open(sc2, "w").write("40 press low\n3000 quit\n")
        env2 = dict(env, HOME_SCRIPT=sc2, HOME_REQ=os.path.join(w2, "req"), HOME_STATE=os.path.join(w2, "state"),
                    HOME_LOG=os.path.join(w2, "log"), HOME_STATS=os.path.join(w2, "stats.tsv"),
                    HOME_FAIL_MODULE=failing)
        r = subprocess.run([LOVE_RUN, hl], cwd=w2, env=env2, capture_output=True, text=True, timeout=120)
        lg = read(w2, "log") or ""
        req = (read(w2, "req") or "").strip()
        check(r.returncode == 0 and "is off until Home restarts" in lg and req.startswith("classic 0"),
              f"Home: the {failing} module failing turns it off, and Home still plays ({req!r})")
    w2 = tmpdir()
    sc2 = os.path.join(w2, "script")
    open(sc2, "w").write("40 press low\n3000 quit\n")
    env2 = dict(env, HOME_SCRIPT=sc2, HOME_REQ=os.path.join(w2, "req"), HOME_STATE=os.path.join(w2, "state"),
                HOME_LOG=os.path.join(w2, "log"), HOME_STATS=os.path.join(w2, "stats.tsv"), HOME_SAFE="1")
    r = subprocess.run([LOVE_RUN, hl], cwd=w2, env=env2, capture_output=True, text=True, timeout=120)
    req = (read(w2, "req") or "").strip()
    check(r.returncode == 0 and "SAFE MODE" in (read(w2, "log") or "") and req.startswith("classic 0"),
          f"Home in safe mode starts and plays a classic ({req!r})")
    homeloop_checks()
    # HOME_REFACTOR.md's gates: the characterization tour matches its golden pixel for pixel, and main.lua stays
    # inside LuaJIT's limits, no higher than the last checkpoint (lower these as the refactor lands).
    r = subprocess.run([sys.executable, os.path.join(HERE, "..", "tools", "home_tour.py")], capture_output=True,
                       text=True, timeout=900)
    check(r.returncode == 0, f"Home: the characterization tour matches its golden ({r.stdout.strip()[-200:]})")
    import json
    mt = json.loads(subprocess.run([sys.executable, os.path.join(HERE, "..", "tools", "home_metrics.py"), "--json"],
                                   capture_output=True, text=True).stdout)
    check(mt["main_locals"] <= 118 and mt["max_upvalues"] <= 32 and mt["main_slots"] <= 122,
          f"Home: main.lua within its refactor ceilings (locals {mt['main_locals']}/118, upvalues "
          f"{mt['max_upvalues']}/32, slots {mt['main_slots']}/122)")
    check(mt["globals"] == ["home_note"],
          f"Home: main.lua writes no global by accident (a local that lost its declaration): {mt['globals']}")
    # Home's Yard cards come from the carts' own info.lua (cartinfo.lua): one per cart, the cart's title, and its
    # stat line from its save as The Yard shows it.
    w3 = tmpdir()
    g3 = os.path.join(w3, "games")
    os.makedirs(g3)
    open(os.path.join(g3, "tea.sav"), "w").write("visits 3\n")
    open(os.path.join(g3, "garden.sav"), "w").write("blooms 1\n")
    sc3 = os.path.join(w3, "script")
    open(sc3, "w").write("30 quit\n")
    env3 = dict(env, HOME_SCRIPT=sc3, HOME_REQ=os.path.join(w3, "req"), HOME_STATE=os.path.join(w3, "state"),
                HOME_LOG=os.path.join(w3, "log"), HOME_STATS=os.path.join(w3, "stats.tsv"), HOME_GAMES=g3)
    subprocess.run([LOVE_RUN, hl], cwd=w3, env=env3, capture_output=True, text=True, timeout=120)
    lg3 = read(w3, "log") or ""
    want = []
    for cid in sorted(os.listdir(os.path.join(HERE, "carts"))):
        info = read(os.path.join(HERE, "carts", cid), "info.lua") or ""
        m = re.search(r'title\s*=\s*"([^"]+)"', info)
        if m and "system = true" not in info:
            want.append(f"yard card {cid}: {m.group(1).upper()}")
    missing = [x for x in want if x not in lg3]
    check(want and not missing and "skipped" not in lg3,
          f"Home: a Yard card for each of the {len(want)} carts, titled from its info.lua (missing {missing})")
    check("yard card tea: TEA / 3 VISITS" in lg3 and "yard card garden: GARDEN / 1 BLOOM" in lg3,
          "Home: a Yard card's stat line is the cart's own info.stat on its save")


def sound():
    """Every game's sound, from its bot's run on the C runtime written to a WAV (CAB_AUDIO_WAV): it plays, it has
    no long silence, it seldom reaches its limiter, and no game is far louder or quieter than the rest (a child
    switching games hears no jump). Nobody has to listen for these (SYSTEM_AUDIT.md E2)."""
    import array, math, statistics
    say("== sound: every game's music and effects, measured")
    levels = {}
    for cid, title in LOVE_CARTS.items():
        d = tmpdir()
        env = dict(os.environ, YARD_CARTS=os.path.join(HERE, "carts"), SDL_AUDIODRIVER="dummy",
                   SDL_VIDEODRIVER="dummy", CAB_AUTOPLAY="1", CAB_AUDIO_WAV=os.path.join(d, "a"))
        run("yard", d, script(title, "1800 quit"), env, args=(cid,), timeout=300)
        wavs = [f for f in os.listdir(d) if f.endswith(".wav")]
        raw = open(os.path.join(d, wavs[0]), "rb").read()[44:] if wavs else b""
        a = array.array("h")
        a.frombytes(raw[:len(raw) // 2 * 2])
        win = 8820  # 0.1 s of stereo samples
        rms = [math.sqrt(sum(x * x for x in a[i:i + win]) / win) for i in range(0, len(a) - win, win)]
        loud = [r for r in rms if r > 30]
        level = math.sqrt(sum(r * r for r in loud) / len(loud)) if loud else 0
        quiet = run_ = 0
        for r in rms:
            run_ = run_ + 1 if r < 30 else 0
            quiet = max(quiet, run_)
        peak = max((abs(x) for x in a), default=0)
        at_peak = sum(1 for x in a if abs(x) >= peak - 1) / max(1, len(a))
        db = 20 * math.log10(level / 32767) if level else -99
        levels[cid] = db
        check(level > 300 and quiet < 50 and at_peak < 0.01,
              f"{cid}: plays ({db:.1f} dBFS), longest silence {quiet / 10:.1f} s, {at_peak * 100:.2f}% at its limiter")
    if levels:
        mid = statistics.median(levels.values())
        far = {c: round(v - mid, 1) for c, v in levels.items() if abs(v - mid) > 5}
        check(not far, f"every game within 5 dB of the others' middle ({mid:.1f} dBFS); outside: {far}")


def leaks(images, lua):
    """A slow leak in a long run's samples (KB). Pictures: their floor (the lowest point of a stretch, once let-go
    layers are collected) still rising from the middle third of the run to the last; a game may hold one more
    layer for a while (Garden's dusk), a leak keeps lifting the floor. Caught: Garden's unbake leak (2026-11-23,
    768 KB a garden) and Bake's window (2026-11-24, floor +149 KB a minute). Lua: past 10 MB (games sit at 2 to
    5; its collector swings too much in two minutes for a trend; the runtime stops a game at 32).
    (SYSTEM_AUDIT.md E1)"""
    t = len(images) // 3
    grew = t >= 2 and min(images[2 * t:]) > min(images[t:2 * t]) + 80
    return bool(grew), bool(lua and max(lua) > 10240)


def endurance():
    """Each game for two minutes of its bot on the GPU runtime (the cabinet's), its memory sampled every 300 frames."""
    say("== endurance: two minutes of each game, memory must stop growing")
    if not os.path.exists(LOVE_RUN):
        say("  skip: no out/love-x86 (games/love/build.sh x86)")
        return
    old_bake = [808, 841, 841, 881, 955, 995, 874, 948, 1024, 1024, 1097, 1138, 1138, 999, 1073, 1108, 1148, 1222,
                1175, 1175, 1249, 1311, 1311, 1246]
    dusk = [768] * 15 + [1536, 1536, 768, 1536, 768, 1536, 1536, 1536, 1536]
    check(leaks([768 * i for i in range(1, 10)], [2000])[0] and leaks(old_bake, [2000])[0]
          and not leaks(dusk, [2000])[0] and leaks([800] * 9, [3000, 12000])[1],
          "endurance: the leak test catches Garden's and Bake's old leaks, not Garden's dusk")
    d = tmpdir()
    yl = os.path.join(d, "yard.love")
    subprocess.run([os.path.join(HERE, "cart"), "love-pack", "--out", yl], check=True, capture_output=True)
    lenv = {"YARD_CARTS": os.path.join(HERE, "carts"), "SDL_AUDIODRIVER": "dummy", "YARD_HEADLESS": "1",
            "SDL_VIDEODRIVER": "offscreen", "ALSOFT_DRIVERS": "null", "CAB_AUTOPLAY": "1", "YARD_STATS": "1",
            "YARD_STATS_COLLECT": "1"}
    for cid, title in LOVE_CARTS.items():
        w = tmpdir()
        _, err = run("love", w, script(title, "7200 quit"), lenv, args=(yl, cid), timeout=600, binary=LOVE_RUN)
        im = [int(x) for x in re.findall(r"^stats \S+ frame \d+ .* images (\d+)KB", err, re.M)]
        lu = [int(x) for x in re.findall(r"^stats \S+ frame \d+ .* lua (\d+)KB", err, re.M)]
        grew, rose = leaks(im, lu)
        check(len(im) >= 10 and not grew and not rose,
              f"{cid}: memory flat over two minutes (images {im[:1]}..{max(im) if im else '?'} KB, lua up to "
              f"{max(lu) if lu else '?'} KB)")


def homeloop_checks():
    """homeloop's failure ladder, run on the PC with folders of its own (HOMELOOP_*) and a stand-in for LÖVE that
    fails or chooses on cue: retry, the last good Home, safe mode, the stock menu; logs never on /data."""
    hl = os.path.join(HERE, "love", "home", "homeloop.sh")
    shells = [["busybox", "sh"]] if shutil.which("busybox") else []
    shells.append(["sh"])

    def setup(home_love, good=None):
        w = tmpdir()
        h, t, card, games = (os.path.join(w, n) for n in ("home", "tmp", "card", "games"))
        for d in (h, t, os.path.join(card, "partycade"), games):
            os.makedirs(d)
        open(os.path.join(h, "home.love"), "w").write(home_love)
        if good is not None:
            open(os.path.join(card, "partycade", "home.good.love"), "w").write(good)
        # The stand-in: logs which file it ran and HOME_SAFE; "bad" fails at once; "good"/"v1" writes a request
        # nobody knows (a choice; homeloop logs it and starts Home again). After 6 runs it ends homeloop.
        run = os.path.join(w, "run.sh")
        open(run, "w").write(
            "#!/bin/sh\n"
            f"echo \"$(cat \"$1\") safe=$HOME_SAFE\" >> {w}/runs\n"
            f"[ $(wc -l < {w}/runs) -ge 6 ] && {{ kill -9 $PPID; exit 0; }}\n"
            "[ \"$(cat \"$1\")\" = bad ] && exit 1\n"
            "echo nosuch > \"$HOME_REQ\"\n")
        os.chmod(run, 0o755)
        env = dict(os.environ, HOMELOOP_H=h, HOMELOOP_TMP=t, HOMELOOP_CARD=card, HOMELOOP_RUN=run,
                   HOMELOOP_GAMES=games, HOMELOOP_NO_VMLOG="1")
        return w, env

    for sh in shells:
        name = " ".join(sh)
        # 1. A broken Home and no good copy: retry, safe mode, then the stock menu (which can't start here: exit).
        w, env = setup("bad")
        subprocess.run(sh + [hl], env=env, capture_output=True, timeout=60)
        runs = (read(w, "runs") or "").split("\n")
        lg = read(os.path.join(w, "card", "partycade", "logs"), "home.log") or ""
        check(runs[:3] == ["bad safe=0", "bad safe=0", "bad safe=1"] and "the original menu" in lg,
              f"homeloop ({name}): a Home that fails as it starts: retry, safe mode, then the stock menu ({runs[:4]})")
        # 2. A broken push with a good copy on the card: retry, then the good one, which keeps running.
        w, env = setup("bad", good="good")
        subprocess.run(sh + [hl], env=env, capture_output=True, timeout=60)
        runs = (read(w, "runs") or "").split("\n")
        lg = read(os.path.join(w, "card", "partycade", "logs"), "home.log") or ""
        check(runs[:4] == ["bad safe=0", "bad safe=0", "good safe=0", "good safe=0"] and "last good Home" in lg,
              f"homeloop ({name}): a broken push runs the last good Home before safe mode ({runs[:4]})")
        # 3. A Home that reaches a choice is kept as the last good one; the logs stay off /data (here: the card).
        w, env = setup("v1")
        subprocess.run(sh + [hl], env=env, capture_output=True, timeout=60)
        kept = read(os.path.join(w, "card", "partycade"), "home.good.love")
        logpath = (read(os.path.join(w, "tmp"), "home.logpath") or "").strip()
        check(kept == "v1" and logpath.startswith(os.path.join(w, "card")),
              f"homeloop ({name}): a Home that worked is kept on the card, and its log is there ({kept!r})")


def shows():
    """SHOWS_BLUEPRINT.md's gate: no scene of a show goes more than 15 s without something happening
    (tools/show_pulse.py, every show start to end: ~25 minutes, so not part of "all"). The night sky has its own
    gentler rules and is checked by eye."""
    import json, tempfile
    out = tempfile.mkdtemp(prefix="show-pulse-")
    ids = ["freedom", "texas", "longhorns", "space", "summer", "halloween", "thanksgiving", "christmas", "newyear",
           "easter", "valentine"]
    subprocess.run([sys.executable, os.path.join(os.path.dirname(HERE), "tools", "show_pulse.py")] + ids + ["--out", out],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=7200)
    for sid in ids:
        path = os.path.join(out, sid + ".json")
        if not os.path.exists(path):
            check(False, f"show {sid}: measured")
            continue
        for r in json.load(open(path)):
            check(r["stale"] <= 15, f"show {sid}, {r['title']}: longest still stretch {r['stale']} s (at most 15)")


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
    if which in ("home", "all"):
        home()
    if which in ("sound", "all"):
        sound()
    if which in ("endurance", "all"):
        endurance()
    if which == "shows":
        shows()
    say(f"== {passes} passed, {len(failures)} failed ==")
    for f in failures:
        say(f"  FAIL {f}")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
