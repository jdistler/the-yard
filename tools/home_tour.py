#!/usr/bin/env python3
"""tools/home_tour.py: Home's characterization tour (HOME_REFACTOR.md, checkpoint 0).

Home is played headless on the PC through fixed scripts (the menu's sections and cards, the info panel, the
shows' tiles, the idle attract, a show playing, the pictures between programs, and the launch requests), with
time, date and randomness pinned (HOME_DT, HOME_NOW, HOME_SEED). Every screenshot, rendered picture and request
is hashed. A refactor that changes no behaviour must reproduce every hash.

    tools/home_tour.py              run, compare with captures/home_tour/golden.tsv; exit 1 on any difference
    tools/home_tour.py --save       run and write the hashes as the new golden (review the pictures first!)
    tools/home_tour.py --twice      run twice and check the tour is deterministic (no golden involved)

Pictures land in games/out/home_tour/ (not in git); a difference names the step, so it can be opened and diffed.
The hashes belong to this PC's LÖVE build and GL driver: a new build or driver means a reviewed --save.
"""
import hashlib
import importlib.machinery
import importlib.util
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAMES = os.path.join(ROOT, "games")
LOVE_RUN = os.path.join(GAMES, "out", "love-x86", "run.sh")
OUT = os.path.join(GAMES, "out", "home_tour")
GOLDEN = os.path.join(ROOT, "captures", "home_tour", "golden.tsv")
NOW = "1795000000"   # 2026-11-19 (a Thursday in November: the menu's autumn world)


def home_pack(path):
    loader = importlib.machinery.SourceFileLoader("cartmod", os.path.join(GAMES, "cart"))
    spec = importlib.util.spec_from_loader("cartmod", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod.home_pack(path)


def presses(start, keys, gap=40):
    """Script lines: each key pressed `gap` frames apart, from frame `start`; returns (lines, next frame)."""
    lines, f = [], start
    for k in keys:
        lines.append(f"{f} press {k}")
        f += gap
    return lines, f


# The tour: (name, script builder, extra env). A builder gets the run's folder and returns script lines; a line
# "N shot NAME" becomes a screenshot NAME.png in that folder.
def menu_tour(w):
    L, f = [], 30
    L.append(f"{f} shot menu_classics")
    f += 10
    for i in range(7):                                  # every section to the right, a picture of each
        L.append(f"{f} press right")
        f += 45
        L.append(f"{f} shot section_{i + 1}")
        f += 5
    for i in range(3):                                  # back left to THE YARD, down its cards
        L.append(f"{f} press left")
        f += 45
    L.append(f"{f} shot back_left")
    for i in range(4):
        L.append(f"{f} press down")
        f += 30
        L.append(f"{f} shot down_{i + 1}")
        f += 5
    L.append(f"{f + 5} quit")
    return L


def shows_tiles_tour(w):
    L, f = [], 30
    for i in range(4):                                  # CLASSICS > GAMES > THE YARD > TV > SHOWS (FAVORITES and ARCADE
        # are empty on the PC: no plays yet, no card); open the first show's tiles
        L.append(f"{f} press right")
        f += 40
    L.append(f"{f} shot shows_section")
    L.append(f"{f + 10} press low")
    L.append(f"{f + 70} shot show_tiles")
    L.append(f"{f + 80} press down")
    L.append(f"{f + 120} shot show_tiles_down")
    L.append(f"{f + 130} press 2p")
    L.append(f"{f + 180} shot shows_back")
    L.append(f"{f + 190} quit")
    return L


def idle_tour(w):
    # HOME_IDLE=2: the attract after 2 s of no press; a press wakes it back to the menu.
    return ["200 shot attract_1", "320 shot attract_2", "330 press low", "380 shot attract_woken", "390 quit"]


def show_tour(w):
    return ["60 shot show_a", "600 shot show_b", "1500 shot show_c", "1510 quit"]


def wake_tour(w):
    # A press during a show: dark at once (the menu's pictures come back behind it), then the menu fades in.
    return ["300 press low", "302 shot wake_cover", "460 shot wake_menu", "470 quit"]


def launch_classic(w):
    return ["40 shot before_launch", "50 press low", "200 quit"]


def launch_cart(w):
    L, f = [], 30
    for i in range(2):                                  # CLASSICS -> GAMES -> THE YARD (ARCADE is empty here)
        L.append(f"{f} press right")
        f += 40
    L.append(f"{f} shot yard_first")
    L.append(f"{f + 10} press low")
    L.append(f"{f + 150} quit")
    return L


def intro_tour(w):
    return ["20 shot intro_a", "90 shot intro_b", "200 shot intro_c", "260 press up", "300 shot intro_done", "310 quit"]


def night_tour(w):
    # HOME_IDLE=1, HOME_NIGHT=3: attract after 1 s, the night scene after 3 s.
    return ["400 shot night_a", "700 shot night_b", "710 quit"]


def tv_tour(w):
    return ["30 press right", "70 press right", "110 press right", "150 shot tv_card", "160 press low",
            "230 shot tv_guide", "240 press down", "280 shot tv_guide_down", "290 press 2p", "340 shot tv_back",
            "350 quit"]


TOUR = [
    ("intro", intro_tour, {"HOME_SKIP_INTRO": "", "HOME_INTRO": "1"}),
    ("night", night_tour, {"HOME_IDLE": "1", "HOME_NIGHT": "3"}),
    ("tv", tv_tour, {}),
    ("menu", menu_tour, {}),
    ("shows", shows_tiles_tour, {}),
    ("idle", idle_tour, {"HOME_IDLE": "2"}),
    ("show_freedom", show_tour, {"HOME_SHOW": "freedom", "HOME_SHOW_ONCE": "1"}),
    ("wake", wake_tour, {"HOME_SHOW": "freedom", "HOME_SHOW_ONCE": "1"}),
    ("launch_classic", launch_classic, {}),
    ("launch_cart", launch_cart, {}),
]


def run_tour(hl, out):
    """All runs; returns {step: hash}."""
    hashes = {}
    base = dict(os.environ, SDL_AUDIODRIVER="dummy", SDL_VIDEODRIVER="offscreen", ALSOFT_DRIVERS="null",
                HOME_HEADLESS="1", HOME_SKIP_INTRO="1", HOME_DT=str(1 / 60), HOME_NOW=NOW, HOME_UT_NOW=NOW,
                HOME_SEED="7")
    for name, build, extra in TOUR:
        w = os.path.join(out, name)
        shutil.rmtree(w, ignore_errors=True)
        os.makedirs(os.path.join(w, "games"))
        lines = []
        for line in build(w):
            parts = line.split()
            if parts[1] == "shot":
                line = f"{parts[0]} shot {os.path.join(w, parts[2] + '.png')}"
            lines.append(line)
        open(os.path.join(w, "script"), "w").write("\n".join(lines) + "\n")
        env = dict(base, HOME_SCRIPT=os.path.join(w, "script"), HOME_LOG=os.path.join(w, "log"),
                   HOME_GAMES=os.path.join(w, "games"), HOME_STATE=os.path.join(w, "state"),
                   HOME_REQ=os.path.join(w, "req"), HOME_STATS=os.path.join(w, "stats.tsv"),
                   HOME_FB=os.path.join(w, "fb.raw"), **extra)
        subprocess.run([LOVE_RUN, hl], cwd=w, env=env, capture_output=True, timeout=600)
        log = open(os.path.join(w, "log")).read() if os.path.exists(os.path.join(w, "log")) else ""
        hashes[f"{name}/errors"] = "none" if "ERROR" not in log else "ERROR"
        for f in sorted(os.listdir(w)):
            p = os.path.join(w, f)
            if f.endswith(".png") or f in ("req", "fb.raw"):
                hashes[f"{name}/{f}"] = hashlib.sha256(open(p, "rb").read()).hexdigest()[:16]
        for want in [l.split()[2] for l in lines if l.split()[1] == "shot"]:
            key = f"{name}/{os.path.basename(want)}"
            hashes.setdefault(key, "MISSING")
    # The pictures between programs, rendered on their own (HOME_RENDER).
    for kind in ("boot", "back"):
        p = os.path.join(out, f"render_{kind}.gz")
        env = dict(base, HOME_RENDER=f"{kind}:{p}", HOME_ART=os.path.join(GAMES, "out", "home-art"))
        subprocess.run([LOVE_RUN, hl], env=env, capture_output=True, timeout=300)
        if os.path.exists(p):
            import gzip
            hashes[f"render/{kind}"] = hashlib.sha256(gzip.open(p).read()).hexdigest()[:16]
        else:
            hashes[f"render/{kind}"] = "MISSING"
    return hashes


def read_golden():
    g = {}
    if os.path.exists(GOLDEN):
        for line in open(GOLDEN):
            if line.strip() and not line.startswith("#"):
                k, v = line.rstrip("\n").split("\t")
                g[k] = v
    return g


def main():
    args = sys.argv[1:]
    os.makedirs(OUT, exist_ok=True)
    hl = home_pack(os.path.join(OUT, "home.love"))
    a = run_tour(hl, os.path.join(OUT, "run"))
    if "--twice" in args:
        b = run_tour(hl, os.path.join(OUT, "run2"))
        diff = sorted(k for k in set(a) | set(b) if a.get(k) != b.get(k))
        print(f"{len(a)} steps; " + ("deterministic" if not diff else f"NOT deterministic: {diff}"))
        sys.exit(1 if diff else 0)
    bad = [k for k, v in a.items() if v in ("MISSING", "ERROR")]
    if "--save" in args:
        if bad:
            sys.exit(f"not saved: {bad}")
        os.makedirs(os.path.dirname(GOLDEN), exist_ok=True)
        with open(GOLDEN, "w") as f:
            f.write("# tools/home_tour.py --save: step\tsha256[:16] (pictures in games/out/home_tour/run/)\n")
            for k in sorted(a):
                f.write(f"{k}\t{a[k]}\n")
        print(f"golden written: {len(a)} steps")
        return
    g = read_golden()
    if not g:
        sys.exit("no golden yet: run with --save after reviewing games/out/home_tour/run/")
    diff = sorted(k for k in set(a) | set(g) if a.get(k) != g.get(k))
    print(f"{len(a)} steps; " + ("all match the golden" if not diff and not bad else f"DIFFERENT: {diff} {bad}"))
    sys.exit(1 if diff or bad else 0)


if __name__ == "__main__":
    main()
