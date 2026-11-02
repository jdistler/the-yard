#!/usr/bin/env python3
"""A close look at every segment of a show: for each, frames early, middle and late at full size, and a flicker
map (two consecutive frames 1/60 s apart: what changed, in red over a grey copy; sudden blobs that are not
motion are flicker). One sheet per segment, to read at full size.

  tools/show_qa.py SHOW [--out DIR] [--segs 1,3]
"""
import argparse, os, subprocess, sys, tempfile

from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAMES = os.path.join(ROOT, "games")
RUN = os.path.join(GAMES, "out", "love-x86", "run.sh")
ENV = dict(os.environ, HOME_HEADLESS="1", SDL_VIDEODRIVER="offscreen", SDL_AUDIODRIVER="dummy", ALSOFT_DRIVERS="null",
           HOME_DT="0.0166667", HOME_SKIP_INTRO="1", HOME_UT_JSON="/nonexistent",
           HOME_SHOW_ART=os.path.join(GAMES, "out", "show-art"), HOME_THUMBS=os.path.join(GAMES, "love", "home", "thumbs"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("show")
    ap.add_argument("--out", default=os.path.join(tempfile.gettempdir(), "show_qa"))
    ap.add_argument("--segs")
    a = ap.parse_args()
    out = os.path.join(a.out, a.show)
    os.makedirs(out, exist_ok=True)
    love = os.path.join(a.out, "home.love")
    subprocess.check_call([os.path.join(GAMES, "cart"), "home-pack", "--out", love], stdout=subprocess.DEVNULL)
    listing = os.path.join(a.out, "shows.txt")
    subprocess.run([RUN, love], env=dict(ENV, HOME_SHOW_LIST=listing), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                   timeout=60)
    nseg = 0
    for line in open(listing):
        f = line.split()
        if f[0] == a.show:
            nseg = int(f[1])
    want = [int(x) for x in a.segs.split(",")] if a.segs else list(range(0, nseg + 1))
    seg_len = {}
    for seg in want:
        # the segment from its start: frames at 3 s, then the middle and late of ~40 s; consecutive pairs for flicker
        times = [3, 12, 24, 36]
        script = os.path.join(out, f"s{seg}.txt")
        with open(script, "w") as s:
            for t in times:
                fr = int(t * 60)
                s.write(f"{fr} shot {out}/seg{seg}_t{t}.png\n{fr + 1} shot {out}/seg{seg}_t{t}b.png\n")
            s.write(f"{int(times[-1] * 60) + 5} quit\n")
        spec = a.show if seg == 0 else f"{a.show}@{seg}"
        subprocess.run([RUN, love], env=dict(ENV, HOME_SHOW=spec, HOME_SCRIPT=script), stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=300)
        sheet = Image.new("RGB", (512 * len(times), 683 + 342), (20, 20, 20))
        d = ImageDraw.Draw(sheet)
        for i, t in enumerate(times):
            p1, p2 = f"{out}/seg{seg}_t{t}.png", f"{out}/seg{seg}_t{t}b.png"
            if not (os.path.exists(p1) and os.path.exists(p2)):
                continue
            im1, im2 = Image.open(p1).convert("RGB"), Image.open(p2).convert("RGB")
            sheet.paste(im1.resize((512, 683)), (i * 512, 0))
            diff = ImageChops.difference(im1, im2).convert("L").point(lambda v: 255 if v > 40 else 0)
            base = im1.convert("L").point(lambda v: v // 3).convert("RGB")
            red = Image.new("RGB", im1.size, (255, 40, 40))
            base.paste(red, (0, 0), diff)
            sheet.paste(base.resize((256, 342)), (i * 512 + 128, 683))
            d.text((i * 512 + 6, 4), f"seg {seg}  +{t}s", fill=(255, 255, 0))
        sheet.save(f"{out}/sheet_seg{seg}.png")
        print(f"{a.show} seg {seg}: {out}/sheet_seg{seg}.png")


if __name__ == "__main__":
    main()
