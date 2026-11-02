#!/usr/bin/env python3
"""Every idle show, played start to finish by Home on the PC's LÖVE (offscreen, a fixed 1/60 s a frame), with a
picture every few seconds: fails on any Lua error, and writes a contact sheet per show to look over.

  tools/show_lint.py [SHOW...] [--every SECONDS] [--out DIR]
"""
import argparse, glob, os, subprocess, sys, tempfile

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAMES = os.path.join(ROOT, "games")
RUN = os.path.join(GAMES, "out", "love-x86", "run.sh")
ENV = dict(os.environ, HOME_HEADLESS="1", SDL_VIDEODRIVER="offscreen", SDL_AUDIODRIVER="dummy", ALSOFT_DRIVERS="null",
           HOME_DT="0.0166667", HOME_SKIP_INTRO="1", HOME_UT_JSON="/nonexistent")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("shows", nargs="*")
    ap.add_argument("--every", type=float, default=20)
    ap.add_argument("--out", default=os.path.join(tempfile.gettempdir(), "show_lint"))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    # every Lua file parses (a syntax error in a module Home loads first means no Home at all)
    home = os.path.join(GAMES, "love", "home")
    luajit = os.path.join(GAMES, "out", "love-x86", "luajit")
    bad = [f for f in sorted(glob.glob(os.path.join(home, "*.lua")))
           if subprocess.run([luajit, "-e", f"assert(loadfile({f!r}))"], capture_output=True).returncode]
    if bad:
        print("does not parse:", " ".join(os.path.basename(f) for f in bad))
        sys.exit(1)
    love = os.path.join(a.out, "home.love")
    subprocess.check_call([os.path.join(GAMES, "cart"), "home-pack", "--out", love], stdout=subprocess.DEVNULL)
    listing = os.path.join(a.out, "shows.txt")
    subprocess.run([RUN, love], env=dict(ENV, HOME_SHOW_LIST=listing), stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL, timeout=60)
    bad = 0
    for line in open(listing):
        sid = line.split()[0]
        if sid == "night" or (a.shows and sid not in a.shows):
            continue
        d = os.path.join(a.out, sid)
        os.makedirs(d, exist_ok=True)
        for f in glob.glob(os.path.join(d, "*.png")):
            os.remove(f)
        log = os.path.join(d, "log.txt")
        if os.path.exists(log):
            os.remove(log)
        # the show's length: from Home (its module's LEN), else ten minutes
        script = os.path.join(d, "script.txt")
        with open(script, "w") as s:
            t = 2.0
            while t < 720:
                s.write(f"{int(t * 60)} shot {d}/t{int(t):04d}.png\n")
                t += a.every
            s.write(f"{720 * 60} quit\n")
        subprocess.run([RUN, love], env=dict(ENV, HOME_SHOW=sid, HOME_SCRIPT=script, HOME_LOG=log, HOME_SHOW_ONCE="1"),
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1800)
        text = open(log).read() if os.path.exists(log) else ""
        errors = [l for l in text.splitlines() if "ERROR" in l]
        shots = sorted(glob.glob(os.path.join(d, "t*.png")))
        print(f"{sid:14s} {len(shots):3d} pictures  {'ERROR: ' + errors[0] if errors else 'ok'}")
        if errors:
            bad += 1
        for k in range(0, len(shots), 12):
            sheet = Image.new("RGB", (192 * 6, 256 * 2))
            dr = ImageDraw.Draw(sheet)
            for i, f in enumerate(shots[k:k + 12]):
                sheet.paste(Image.open(f).convert("RGB").resize((192, 256)), ((i % 6) * 192, (i // 6) * 256))
                dr.text(((i % 6) * 192 + 4, (i // 6) * 256 + 4), os.path.basename(f), fill=(255, 255, 0))
            sheet.save(os.path.join(a.out, f"{sid}_{k // 12}.png"))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
