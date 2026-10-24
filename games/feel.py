#!/usr/bin/env python3
"""Play a reel of each game and write how it looks and how it answers the hand.

  python3 feel.py
  python3 feel.py chest lamp

Headless. Does not flash. Needs Pillow. Each game gets games/out/feel/<name>/:
  strip.png    a contact sheet of the reel: the game playing itself (CAB_AUTOPLAY)
  open.png     the first picture, 2x
  payoff.png   a picture two thirds of the way into the reel, 2x
  report.txt   what happened, and the hand-response numbers

Hand response (CONTROLS.md, "a press answers on the same frame"): the reel presses the
game's verb on a known frame and compares the picture just before and just after with
the change between two quiet frames. A press that moves no more pixels than the idle
animation is flagged. games/out/feel/SUMMARY.txt has one line per game, and sheet.png
puts every game side by side.

test.py is the correctness check. This is for looking.
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parent
BIN = ROOT / "out" / "pc"
FEEL = ROOT / "out" / "feel"

# frames: the reel length. every: a picture each N frames. payoff: a log line to find the moment.
# press: (title, frames before the press, button) for the hand-response measure, after setup lines.
REELS = [
    {"name": "yard", "title": "The Yard", "frames": 240, "every": 20, "payoff": None,
     "press": ["40 down DOWN", "41 up DOWN"], "at": 40},
    {"name": "keep", "title": "Keep", "frames": 1800, "every": 150, "payoff": r"keep catch (\d+)",
     "press": ["30 down LOW", "31 up LOW", "90 down LEFT"], "at": 90},
    {"name": "lamp", "title": "Lamp", "frames": 1800, "every": 150, "payoff": r"lamp night \d+ done",
     "press": ["20 down LOW", "21 up LOW", "90 down LOW", "91 up LOW"], "at": 90},
    {"name": "orb", "title": "Orb", "frames": 1500, "every": 125, "payoff": r"dive crash",
     "press": ["40 down LOW", "41 up LOW"], "at": 40},
    {"name": "tea", "title": "Tea", "frames": 1500, "every": 125, "payoff": r"tea cheer",
     "press": ["60 down LOW"], "at": 60},
    {"name": "chest", "title": "Chest", "frames": 1500, "every": 125, "payoff": r"chest win",
     "press": ["60 down LOW", "61 up LOW"], "at": 60},
]


def env_for(name):
    e = dict(os.environ)
    e.update({"SDL_VIDEODRIVER": "offscreen" if name == "orb" else "dummy", "SDL_AUDIODRIVER": "dummy",
              "CAB_SCALE": "1"})
    return e


def run(name, cwd, script, extra=None):
    e = env_for(name)
    path = Path(cwd) / "reel.cab"
    path.write_text(script)
    e["CAB_SCRIPT"] = str(path)
    if extra:
        e.update(extra)
    p = subprocess.run([str(BIN / name)], cwd=cwd, env=e, capture_output=True, text=True, timeout=300)
    return p.stderr


def label(im, text):
    d = ImageDraw.Draw(im)
    d.rectangle([0, im.height - 14, im.width, im.height], fill=(20, 16, 30))
    d.text((4, im.height - 13), text, fill=(230, 230, 230))
    return im


def changed(a, b):
    diff = ImageChops.difference(a.convert("RGB"), b.convert("RGB")).convert("L")
    return sum(1 for v in diff.getdata() if v > 24)


def reel(r):
    name = r["name"]
    dest = FEEL / name
    shutil.rmtree(dest, ignore_errors=True)
    dest.mkdir(parents=True)
    tmp = Path(tempfile.mkdtemp(prefix=f"feel-{name}-"))
    lines = [f"title={r['title']}"]
    for f in range(0, r["frames"], r["every"]):
        lines.append(f"{f + 2} shot {tmp}/r{f + 2:05d}.bmp")
    lines.append(f"{r['frames']} quit")
    log = run(name, tmp, "\n".join(lines) + "\n", {"CAB_AUTOPLAY": "1"})
    shots = sorted(tmp.glob("r*.bmp"))
    report = [f"{name}: {len(shots)} pictures over {r['frames']} frames, the built-in player at the deck"]
    if r["payoff"]:
        report.append(f"payoff '{r['payoff']}': {len(re.findall(r['payoff'], log))} times")
    # Contact sheet.
    if shots:
        ims = [Image.open(p).convert("RGB") for p in shots]
        w, h = ims[0].size
        cols = 6 if len(ims) > 6 else len(ims)
        rows = (len(ims) + cols - 1) // cols
        scale = 0.5 if w > 300 else 0.75
        tw, th = int(w * scale), int(h * scale)
        sheet = Image.new("RGB", (cols * (tw + 4), rows * (th + 4)), (14, 12, 24))
        for i, (p, im) in enumerate(zip(shots, ims)):
            t = label(im.resize((tw, th), Image.LANCZOS), p.stem[1:].lstrip("0") or "0")
            sheet.paste(t, ((i % cols) * (tw + 4), (i // cols) * (th + 4)))
        sheet.save(dest / "strip.png")
        ims[0].resize((w * 2 if w < 300 else w, h * 2 if w < 300 else h), Image.NEAREST).save(dest / "open.png")
        last = ims[len(ims) * 2 // 3]
        last.resize((w * 2 if w < 300 else w, h * 2 if w < 300 else h), Image.NEAREST).save(dest / "payoff.png")
    # Hand response.
    at = r["at"]
    lines = [f"title={r['title']}", *r["press"]]
    for f in (at - 3, at - 2, at - 1, at, at + 1):
        lines.append(f"{f} shot {tmp}/h{f:05d}.bmp")
    lines.append(f"{at + 3} quit")
    run(name, tmp, "\n".join(lines) + "\n", {"CAB_SEED": "3"})
    try:
        quiet = changed(Image.open(tmp / f"h{at - 3:05d}.bmp"), Image.open(tmp / f"h{at - 2:05d}.bmp"))
        before = changed(Image.open(tmp / f"h{at - 2:05d}.bmp"), Image.open(tmp / f"h{at - 1:05d}.bmp"))
        press = changed(Image.open(tmp / f"h{at - 1:05d}.bmp"), Image.open(tmp / f"h{at:05d}.bmp"))
        noise = max(quiet, before)
        verdict = "answers on the press frame" if press > noise * 1.5 + 30 else "LOOK: the press frame is not louder than idle"
        report.append(f"hand: {press} px changed on the press frame, {noise} between quiet frames: {verdict}")
        flag = None if "answers" in verdict else "slow hand response"
    except (OSError, ValueError) as ex:
        report.append(f"hand: could not measure ({ex})")
        flag = "no hand measure"
    (dest / "report.txt").write_text("\n".join(report) + "\n")
    shutil.rmtree(tmp, ignore_errors=True)
    return report, flag


def main():
    want = sys.argv[1:]
    reels = [r for r in REELS if not want or r["name"] in want]
    if not reels:
        raise SystemExit(f"no reel named {want}. Have: {' '.join(r['name'] for r in REELS)}")
    subprocess.check_call(["make", "-s", "TARGET=pc"], cwd=ROOT)
    FEEL.mkdir(parents=True, exist_ok=True)
    summary = []
    for r in reels:
        print(f"== {r['name']} ==", flush=True)
        report, flag = reel(r)
        print("\n".join(report))
        summary.append(f"{r['name']}: {flag or 'answers on the frame'}")
    (FEEL / "SUMMARY.txt").write_text("\n".join(summary) + "\n")
    # One sheet with every game's payoff picture.
    opens = [Image.open(FEEL / r["name"] / "payoff.png").convert("RGB") for r in reels if (FEEL / r["name"] / "payoff.png").exists()]
    if opens:
        h = 512
        ims = [im.resize((int(im.width * h / im.height), h), Image.LANCZOS) for im in opens]
        sheet = Image.new("RGB", (sum(i.width for i in ims) + 6 * (len(ims) - 1), h), (14, 12, 24))
        x = 0
        for im in ims:
            sheet.paste(im, (x, 0))
            x += im.width + 6
        sheet.save(FEEL / "sheet.png")
    print("== summary ==")
    print("\n".join(summary))


if __name__ == "__main__":
    main()
