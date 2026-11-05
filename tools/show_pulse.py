#!/usr/bin/env python3
"""How lively each scene of a show is, measured from the frames themselves. The show is rendered headless at
one frame a second and each frame cut into a 24x32 grid of 32 px blocks (mean colour); a block "changed" when
its colour moved more than a little.

  motion    the share of the screen that changed in the last second (anything moving)
  new       the share of the screen showing something not seen earlier in the scene (the story moving on;
            a loop, a sway, a twinkle are not new once they have been round once)
  beat      a second where at least BEAT of the screen changed, or NEWBEAT of it is new: something happened
  stale     the longest run of seconds with no beat (the dead time: what the kids are bored by)

  tools/show_pulse.py SHOW [SHOW ...] [--out DIR]     a table per scene, a strip PNG per show, a JSON
"""
import argparse, json, os, shutil, subprocess, sys, tempfile

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAMES = os.path.join(ROOT, "games")
RUN = os.path.join(GAMES, "out", "love-x86", "run.sh")
ENV = dict(os.environ, HOME_HEADLESS="1", SDL_VIDEODRIVER="offscreen", SDL_AUDIODRIVER="dummy", ALSOFT_DRIVERS="null",
           HOME_DT="0.0166667", HOME_SKIP_INTRO="1", HOME_UT_JSON="/nonexistent",
           HOME_SHOW_ART=os.path.join(GAMES, "out", "show-art"), HOME_THUMBS=os.path.join(GAMES, "love", "home", "thumbs"))
BLOCK, CHANGE = 32, 14          # block size (px); a block changed when a channel's mean moved this much (0-255)
BEAT, NEWBEAT = 0.12, 0.06
NIGHT = 90                      # seconds of each of the night's scenes
SKIP = 5                        # a scene's first seconds: its title card, the cut


def blocks(path):
    a = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    h, w = a.shape[0] // BLOCK, a.shape[1] // BLOCK
    return a[:h * BLOCK, :w * BLOCK].reshape(h, BLOCK, w, BLOCK, 3).mean(axis=(1, 3))


def changed(a, b):
    return (np.abs(a - b).max(axis=2) > CHANGE)


def segments(listing, show):
    segs, length = [], 0
    for line in open(listing):
        f = line.rstrip("\n").split(" ", 3)
        if f[0] != show:
            continue
        if f[1] == "len":
            length = int(float(f[2]))
        else:
            segs.append((int(float(f[2])), f[3]))
    return segs, length


def render(love, spec, frames, script, secs, at=0):
    with open(script, "w") as s:
        for t in range(secs):
            s.write(f"{t * 60 + 30} shot {frames}/{at + t:04d}.png\n")
        s.write(f"{secs * 60 + 40} quit\n")
    subprocess.run([RUN, love], env=dict(ENV, HOME_SHOW=spec, HOME_SCRIPT=script), stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL, timeout=secs * 2 + 120)


def measure(show, love, out, listing):
    segs, length = segments(listing, show)
    if show == "night":
        # the night's scenes loop for many minutes each: 90 s of each, one after the other
        segs = [(i * NIGHT, t) for i, (_, t) in enumerate(segs)]
        length = len(segs) * NIGHT
    if not segs:
        print(f"{show}: no segments", file=sys.stderr)
        return None
    frames = os.path.join(out, show + "_frames")
    shutil.rmtree(frames, ignore_errors=True)
    os.makedirs(frames)
    script = os.path.join(out, show + "_script.txt")
    if show == "night":
        for i in range(len(segs)):
            render(love, f"night@{i + 1}", frames, script, NIGHT, i * NIGHT)
    else:
        render(love, show + ":0", frames, script, length)
    have = sorted(f for f in os.listdir(frames) if f.endswith(".png"))
    grid = [blocks(os.path.join(frames, f)) for f in have]
    thumbs = [Image.open(os.path.join(frames, f)).convert("RGB").resize((96, 128)) for f in have]
    n = len(grid)
    bounds = [s[0] for s in segs] + [length]
    rows = []
    motion = np.zeros(n)
    new = np.zeros(n)
    for i in range(1, n):
        motion[i] = changed(grid[i], grid[i - 1]).mean()
    for k, (start, title) in enumerate(segs):
        end = min(bounds[k + 1], n)
        lo = start + SKIP
        if end - lo < 4:
            continue
        seen = [grid[lo]]
        beats, gap, worst, worst_at = [], 0, 0, lo
        for t in range(lo, end):
            if t > lo:
                # new: blocks unlike every frame of this scene up to 3 s ago (a 1-3 s loop does not count)
                nov = np.ones(grid[t].shape[:2], bool)
                for g in seen[:-2] if len(seen) > 2 else seen[:1]:
                    nov &= changed(grid[t], g)
                new[t] = nov.mean()
                seen.append(grid[t])
            beat = motion[t] >= BEAT or new[t] >= NEWBEAT
            if beat:
                beats.append(t)
                gap = 0
            else:
                gap += 1
                if gap > worst:
                    worst, worst_at = gap, t - gap + 1
        dur = end - lo
        rows.append(dict(seg=k + 1, title=title, start=start, end=end, secs=dur,
                         motion=round(float(motion[lo:end].mean()), 3), new=round(float(new[lo:end].mean()), 3),
                         beats_per_min=round(len(beats) * 60 / dur, 1), stale=worst, stale_at=worst_at,
                         still=round(float((motion[lo:end] < 0.03).mean()), 2)))
    strip(show, out, thumbs, motion, new, segs, length)
    shutil.rmtree(frames, ignore_errors=True)
    return rows


def strip(show, out, thumbs, motion, new, segs, length):
    """A picture of the whole show: a thumbnail every 5 s, under it the motion (blue) and new (orange) graphs."""
    cols = 24
    picks = list(range(0, len(thumbs), 5))
    rows_n = (len(picks) + cols - 1) // cols
    im = Image.new("RGB", (cols * 96, rows_n * (128 + 50)), (16, 16, 20))
    d = ImageDraw.Draw(im)
    starts = {s[0]: s[1] for s in segs}
    for j, t in enumerate(picks):
        x, y = (j % cols) * 96, (j // cols) * 178
        im.paste(thumbs[t], (x, y))
        d.text((x + 2, y + 2), f"{t // 60}:{t % 60:02d}", fill=(255, 255, 0))
        for tt in range(t, min(t + 5, len(thumbs))):
            xx = x + (tt - t) * 19
            mh, nh = int(min(motion[tt], 1) * 46), int(min(new[tt] * 3, 1) * 46)
            d.rectangle([xx, y + 176 - mh, xx + 8, y + 176], fill=(80, 140, 255))
            d.rectangle([xx + 9, y + 176 - nh, xx + 17, y + 176], fill=(255, 150, 40))
        for st in starts:
            if t <= st < t + 5:
                d.line([x, y, x, y + 176], fill=(255, 60, 60), width=2)
    im.save(os.path.join(out, f"{show}_strip.png"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("shows", nargs="+")
    ap.add_argument("--out", default=os.path.join(tempfile.gettempdir(), "show_pulse"))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    love = os.path.join(a.out, "home.love")
    subprocess.check_call([os.path.join(GAMES, "cart"), "home-pack", "--out", love], stdout=subprocess.DEVNULL)
    listing = os.path.join(a.out, "segs.txt")
    if not os.path.exists(listing):
        subprocess.run([RUN, love], env=dict(ENV, HOME_SHOW_LIST=os.path.join(a.out, "shows.txt"), HOME_SHOW_SEGS=listing),
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60)
    for show in a.shows:
        rows = measure(show, love, a.out, listing)
        if rows is None:
            continue
        json.dump(rows, open(os.path.join(a.out, f"{show}.json"), "w"), indent=1)
        print(f"\n{show}")
        print(f"  {'scene':34} {'secs':>4} {'motion':>6} {'new':>5} {'beats/m':>7} {'stale':>5} {'at':>5} {'still':>5}")
        for r in rows:
            print(f"  {r['title'][:34]:34} {r['secs']:4d} {r['motion']:6.3f} {r['new']:5.3f} {r['beats_per_min']:7.1f} "
                  f"{r['stale']:5d} {r['stale_at'] // 60:2d}:{r['stale_at'] % 60:02d} {r['still']:5.2f}")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
