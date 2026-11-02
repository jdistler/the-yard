#!/usr/bin/env python3
"""The SHOWS section's tiles: a picture of each segment of each idle show, rendered by Home itself on the PC's
LÖVE (offscreen, a fixed 1/60 s a frame), 120 x 160, into games/love/home/thumbs/<show>_<segment>.png
(segment 0: the whole show, a copy of the segment the show names as its THUMB).

  tools/show_thumbs.py [SHOW...]
"""
import os, shutil, subprocess, sys, tempfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAMES = os.path.join(ROOT, "games")
OUT = os.path.join(GAMES, "love", "home", "thumbs")
RUN = os.path.join(GAMES, "out", "love-x86", "run.sh")
ENV = dict(os.environ, HOME_HEADLESS="1", SDL_VIDEODRIVER="offscreen", SDL_AUDIODRIVER="dummy", ALSOFT_DRIVERS="null",
           HOME_DT="0.0166667", HOME_SKIP_INTRO="1")


def run(love, env, seconds=60):
    subprocess.run([RUN, love], env=dict(ENV, **env), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                   timeout=seconds, check=False)


def main():
    only = set(sys.argv[1:])
    os.makedirs(OUT, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="thumbs")
    love = os.path.join(tmp, "home.love")
    subprocess.check_call([os.path.join(GAMES, "cart"), "home-pack", "--out", love], stdout=subprocess.DEVNULL)
    listing = os.path.join(tmp, "shows.txt")
    run(love, {"HOME_SHOW_LIST": listing})
    for line in open(listing):
        sid, n, thumb = line.split()
        if only and sid not in only:
            continue
        for seg in range(1, int(n) + 1):
            shot = os.path.join(tmp, f"{sid}_{seg}.png")
            script = os.path.join(tmp, "script.txt")
            # 5 s in: past the fade-ins
            open(script, "w").write(f"300 shot {shot}\n302 quit\n")
            run(love, {"HOME_SHOW": f"{sid}@{seg}", "HOME_SCRIPT": script, "HOME_LOG": os.path.join(tmp, "log.txt")})
            if not os.path.exists(shot):
                print(f"{sid} {seg}: no picture (see {tmp}/log.txt)")
                continue
            # (256 colours: half the bytes, the same at this size; the cabinet's /data is ~96% full)
            Image.open(shot).convert("RGB").resize((120, 160), Image.LANCZOS).quantize(
                colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG).save(
                os.path.join(OUT, f"{sid}_{seg}.png"), optimize=True)
            print(f"{sid} {seg}")
        src = os.path.join(OUT, f"{sid}_{thumb}.png")
        if os.path.exists(src):
            shutil.copy(src, os.path.join(OUT, f"{sid}_0.png"))
    shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
