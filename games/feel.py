#!/usr/bin/env python3
"""Play a short reel of each game and write how it feels.

  python3 feel.py
  python3 feel.py chest lamp

Headless. Does not flash. Each game gets games/out/feel/<name>/:
  report.txt   numbers and the lines worth changing
  strip.png    the reel, upright, nearest-neighbor
  open.png     the first picture, 2x
  payoff.png   the last picture, 2x

A reel frame file frame-NNNN.bmp is the picture after script frame N-1.
A press on script frame T shows up in frame-(T+1).bmp. The raw frames are
removed after the report; the strip and the two stills stay.

Read the report, look at the strip, change the game, run this again for
that game. stress.sh is still the correctness check.
"""
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
BIN = ROOT / "out" / "pc"
FEEL = ROOT / "out" / "feel"

# A reel is the first thing a player does, not the edge-case suite.
REELS = [
    {
        "name": "keep",
        "title": "Keep",
        "bin": "keep",
        "quit": 150,
        "play": "keep",
        "script": """
5 down LOW
6 up LOW
8 down LEFT
70 up LEFT
70 down RIGHT
""",
    },
    {
        "name": "lamp",
        "title": "Lamp",
        "bin": "lamp",
        "quit": 180,
        "play": "lamp",
        "script": """
0 down RIGHT
50 up RIGHT
50 down UP
90 up UP
90 down LEFT
""",
    },
    {
        "name": "yard",
        "title": "The Yard",
        "bin": "yard",
        "quit": 40,
        "script": """
8 down DOWN
10 up DOWN
18 down DOWN
20 up DOWN
28 down DOWN
30 up DOWN
""",
    },
    {
        "name": "orb",
        "title": "Orb",
        "bin": "orb",
        "quit": 90,
        "script": """
0 down RIGHT
40 up RIGHT
50 down LOW
""",
    },
    {
        "name": "tea",
        "title": "Tea",
        "bin": "tea",
        "quit": 48,
        "note": "The castle is a long flight on purpose. This reel checks that the stick shows.",
        "script": """
6 down UP
""",
    },
    {
        "name": "chest",
        "title": "Chest",
        "bin": "chest",
        "quit": 200,
        "script": """
0 down LEFT
0 down UP
40 up LEFT
40 down RIGHT
76 up RIGHT
120 down LOW
121 up LOW
124 down LOW
125 up LOW
128 down LOW
129 up LOW
132 down LOW
133 up LOW
136 down LOW
137 up LOW
140 down LOW
141 up LOW
144 down LOW
145 up LOW
148 down LOW
149 up LOW
152 down LOW
153 up LOW
""",
    },
]


def parse_script(text):
    presses = []
    for line in text.splitlines():
        parts = line.split()
        if len(parts) >= 3 and parts[1] == "down":
            presses.append((int(parts[0]), parts[2]))
    return presses


def load_frame(directory, n):
    path = directory / f"frame-{n:04d}.bmp"
    if not path.is_file():
        return None
    return Image.open(path).convert("RGB")


def changed_pixels(a, b):
    if a.size != b.size:
        b = b.resize(a.size, Image.NEAREST)
    pa, pb = a.tobytes(), b.tobytes()
    n = 0
    step = 6 if len(pa) > 400000 else 3
    # step 6 counts every other pixel; multiply back so the number is in pixels.
    for i in range(0, len(pa) - 2, step):
        if abs(pa[i] - pb[i]) > 18 or abs(pa[i + 1] - pb[i + 1]) > 18 or abs(pa[i + 2] - pb[i + 2]) > 18:
            n += 1
    if step == 6:
        n *= 2
    return n


def field_stats(im):
    px = im.load()
    w, h = im.size
    counts = {}
    samples = 0
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            p = px[x, y]
            q = (p[0] // 16, p[1] // 16, p[2] // 16)
            counts[q] = counts.get(q, 0) + 1
            samples += 1
    mode = max(counts, key=counts.get)
    flat = counts[mode] / samples
    return flat, 1 - flat, 0, 0.5


def answer_delay(shot_dir, script_frame, have):
    """Frames after the press until 40 pixels move. The press's own picture is file script_frame+1."""
    base_n = script_frame  # file drawn before this press, when it exists
    if base_n < 1:
        base_n = 1
    base = load_frame(shot_dir, base_n)
    if base is None:
        return None
    for ahead in range(1, 9):
        n = script_frame + ahead
        if n not in have:
            continue
        im = load_frame(shot_dir, n)
        if im is None:
            continue
        if changed_pixels(base, im) >= 40:
            base.close()
            im.close()
            return ahead - 1 if script_frame >= 1 else ahead
        im.close()
    base.close()
    return None


def compose_strip(shot_dir, frames, dest):
    cells = []
    for n in frames:
        im = load_frame(shot_dir, n)
        if im is None:
            continue
        w = 180
        h = max(1, int(im.height * w / im.width))
        cells.append((n, im.resize((w, h), Image.NEAREST)))
        im.close()
    if not cells:
        return
    cols = 4
    rows = (len(cells) + cols - 1) // cols
    label = 16
    cell_w = cells[0][1].width
    cell_h = max(c.height for _, c in cells)
    sheet = Image.new("RGB", (cols * cell_w, rows * (cell_h + label)), (20, 18, 28))
    draw = ImageDraw.Draw(sheet)
    for i, (n, im) in enumerate(cells):
        x = (i % cols) * cell_w
        y = (i // cols) * (cell_h + label)
        sheet.paste(im, (x, y))
        draw.text((x + 4, y + cell_h + 1), f"s{n - 1}", fill=(255, 246, 234))
        im.close()
    sheet.save(dest)


def save_still(shot_dir, n, dest):
    im = load_frame(shot_dir, n)
    if im is None:
        return
    im.resize((im.width * 2, im.height * 2), Image.NEAREST).save(dest)
    im.close()


def shot_run(binary, title, script, quit_at):
    """Run one scripted play. Returns (shot_dir, work_dir, log_text, returncode)."""
    work = Path(tempfile.mkdtemp(prefix="feel-"))
    shot = work / "frames"
    shot.mkdir()
    script_path = work / "reel.cab"
    script_path.write_text(f"title={title}\n{script.strip()}\n{quit_at} quit\n")
    env = os.environ.copy()
    env.update({
        "SDL_VIDEODRIVER": "dummy",
        "SDL_AUDIODRIVER": "dummy",
        "SDL_HINT_RENDER_VSYNC": "0",
        "CAB_SCRIPT": str(script_path),
        "CAB_SCRIPT_LOG": "1",
        "CAB_SCALE": "1",
        "CAB_MAX_FRAMES": str(quit_at + 5),
        "CAB_SHOTDIR": str(shot),
        "CAB_SHOT_EVERY": "1",
    })
    proc = subprocess.run(
        [str(binary)], cwd=work, env=env,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    )
    return shot, work, proc.stdout, proc.returncode


def tile_from_picture(im):
    """The falling tile is the only green core. Returns its top-left, or None."""
    px = im.load()
    xs, ys = [], []
    for y in range(im.height):
        for x in range(im.width):
            r, g, b = px[x, y]
            if g > 160 and r < 80 and 70 < b < 160:
                xs.append(x)
                ys.append(y)
    if len(xs) < 4:
        return None
    return int(round(sum(xs) / len(xs) - 3.5)), int(round(sum(ys) / len(ys) - 3.5))


def steer(commands, holding, px, ix, start, end):
    """Hold the stick so the paddle center meets the tile. Returns holding, px."""
    for frame in range(start, end + 1):
        center = px + 18
        want = None
        if center < ix + 4 - 4:
            want = "RIGHT"
        elif center > ix + 4 + 4:
            want = "LEFT"
        if want != holding:
            if holding:
                commands.append(f"{frame} up {holding}")
            if want:
                commands.append(f"{frame} down {want}")
            holding = want
        if want == "RIGHT":
            px = min(200, px + 3)
        elif want == "LEFT":
            px = max(4, px - 3)
    return holding, px


def plan_keep(binary):
    """Watch the tile, catch it, then watch the next one and line up again."""
    shot, work, _, code = shot_run(binary, "Keep", "2 down LOW\n3 up LOW", 12)
    im = load_frame(shot, 4)
    found = tile_from_picture(im) if im is not None else None
    if im is not None:
        im.close()
    shutil.rmtree(work)
    if code != 0 or found is None:
        return None
    ix, iy = found
    # File 4 is the picture after script frame 3. The start frame is 2, and the
    # tile has fallen two frames by then (iy should be 32).
    if abs(iy - 32) > 6:
        return None
    px = (240 - 36) // 2
    catch = 2 + 127
    commands = ["2 down LOW", "3 up LOW"]
    holding, px = steer(commands, None, px, ix, 3, catch)
    lined = ix + 8 >= px and ix <= px + 36
    if holding:
        commands.append(f"{catch + 1} up {holding}")
        holding = None
    # The catch drops a new tile. Look at that picture and follow it.
    script = "\n".join(commands)
    shot, work, _, code = shot_run(binary, "Keep", script, catch + 4)
    im = load_frame(shot, catch + 1)
    nxt = tile_from_picture(im) if im is not None else None
    if im is not None:
        im.close()
    shutil.rmtree(work)
    follow = ""
    if code == 0 and nxt is not None and nxt[1] < 80:
        holding, px = steer(commands, None, px, nxt[0], catch + 2, catch + 80)
        follow = f" Then followed the next tile at x={nxt[0]}."
        lined = lined and nxt[0] + 8 >= px and nxt[0] <= px + 36
    if holding:
        commands.append(f"{catch + 81} up {holding}")
    note = (
        f"Watched the tile at x={ix} and steered the paddle. "
        + ("It is lined up for the catch." if lined else "The paddle did not reach the tile.")
        + follow
    )
    return "\n".join(commands), catch + 80, note


def plan_lamp(binary):
    """Walk the lamp onto every star. The positions are the ones the game uses."""
    del binary
    stars = [(120, 160), (36, 150), (70, 240), (176, 250), (200, 168), (190, 64), (48, 70)]
    px, py = 116, 156
    frame = 0
    holding = None
    commands = []

    def hold(direction):
        nonlocal holding, frame
        if direction == holding:
            return
        if holding:
            commands.append(f"{frame} up {holding}")
        if direction:
            commands.append(f"{frame} down {direction}")
        holding = direction

    def clamp():
        nonlocal px, py
        px = min(224, max(8, px))
        py = min(292, max(70, py))

    for tx, ty in stars:
        guard = 0
        while (px + 4 - tx) ** 2 + (py + 4 - ty) ** 2 >= 18 * 18 and guard < 400:
            dx = tx - (px + 4)
            dy = ty - (py + 4)
            x_blocked = abs(dx) <= 2 or (dx < 0 and px <= 8) or (dx > 0 and px >= 224)
            y_blocked = abs(dy) <= 2 or (dy < 0 and py <= 70) or (dy > 0 and py >= 292)
            if not x_blocked and (abs(dx) >= abs(dy) or y_blocked):
                hold("RIGHT" if dx > 0 else "LEFT")
                px += 2 if dx > 0 else -2
            elif not y_blocked:
                hold("DOWN" if dy > 0 else "UP")
                py += 2 if dy > 0 else -2
            else:
                break
            clamp()
            frame += 1
            guard += 1
    # Step off the last star so its core is visible in the payoff.
    tx, ty = stars[-1]
    # Leave toward the middle, so the lamp does not sit on the title.
    away_right = tx < 120
    for _ in range(20):
        if (px + 4 - tx) ** 2 + (py + 4 - ty) ** 2 > 28 * 28:
            break
        hold("RIGHT" if away_right else "LEFT")
        px += 2 if away_right else -2
        clamp()
        frame += 1
    if holding:
        commands.append(f"{frame} up {holding}")
    note = f"Walked the lamp across all 7 stars in {frame} frames."
    return "\n".join(commands), frame + 8, note


def prepare(reel):
    binary = BIN / reel["bin"]
    if reel.get("play") == "keep":
        planned = plan_keep(binary)
        if planned:
            reel["script"], reel["quit"], reel["note"] = planned
    elif reel.get("play") == "lamp":
        reel["script"], reel["quit"], reel["note"] = plan_lamp(binary)


def judge_play(name, shot, last_n, log_text, lines, flags):
    if name == "keep":
        im = load_frame(shot, last_n)
        missed = False
        if im is not None:
            px = im.load()
            for y in range(80, 100):
                for x in range(8, 80):
                    r, g, b = px[x, y]
                    if r > 180 and g < 100 and b < 100:
                        missed = True
            im.close()
        if missed:
            flags.append("played: the tile fell past the paddle")
            lines.append("played: missed")
        else:
            lines.append("played: caught")
    elif name == "lamp":
        im = load_frame(shot, last_n)
        awake = 0
        if im is not None:
            px = im.load()
            for sx, sy in ((120, 160), (48, 70), (190, 64), (36, 150), (200, 168), (70, 240), (176, 250)):
                r, g, b = px[sx, sy]
                if g > 140 and r > 180:
                    awake += 1
            im.close()
        lines.append(f"played: {awake}/7 stars awake")
        if awake < 7:
            flags.append(f"played: only {awake} of 7 stars woke")
    elif name == "chest":
        if "chest win" in log_text:
            lines.append("played: the fight was won")
        else:
            flags.append("played: the fight was not won on this reel")
            lines.append("played: no win")


def run_reel(reel):
    name = reel["name"]
    out = FEEL / name
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    presses = parse_script(reel["script"])
    quit_at = reel["quit"]
    shot, work, log_text, code = shot_run(BIN / reel["bin"], reel["title"], reel["script"], quit_at)
    (out / "play.log").write_text(log_text)
    have = set()
    for path in shot.glob("frame-*.bmp"):
        have.add(int(path.stem.split("-")[1]))
    lines = []
    flags = []
    if code != 0:
        flags.append(f"the game exited {code}")
    if not have:
        flags.append("no frames were drawn")
        text = "\n".join(flags) + "\n"
        (out / "report.txt").write_text(text)
        shutil.rmtree(work)
        return flags

    first_n = min(have)
    last_n = max(have)
    opening = load_frame(shot, first_n)
    payoff = load_frame(shot, last_n)
    flat, ink, _, _ = field_stats(opening)
    flat2, ink2, _, _ = field_stats(payoff)
    opening.close()
    payoff.close()
    sample = load_frame(shot, first_n)
    lines.append(f"{name}: {len(have)} frames, picture {sample.size[0]}x{sample.size[1]}")
    sample.close()
    lines.append(f"opening flat {flat:.0%}  ink {ink:.0%}")
    lines.append(f"payoff  flat {flat2:.0%}  ink {ink2:.0%}")
    if reel.get("note"):
        lines.append(reel["note"])
    if ink < 0.08:
        flags.append(f"opening ink is {ink:.0%}: a few marks on an empty field")

    verbs = {"LOW", "TL", "TR"}
    sticks = {"UP", "DOWN", "LEFT", "RIGHT"}
    if reel.get("play"):
        lines.append("the player watched the picture and drove the stick")
        presses = []
    for frame, button in presses:
        if button not in verbs and button not in sticks:
            continue
        kind = "button" if button in verbs else "stick"
        if frame == 0:
            early = load_frame(shot, 1)
            later = load_frame(shot, 8) if 8 in have else None
            moved = changed_pixels(early, later) if early and later else 0
            if early:
                early.close()
            if later:
                later.close()
            lines.append(f"{kind} {button} at 0: held from the first picture, {moved} pixels by frame 8")
            if moved < 40:
                flags.append(f"{kind} {button} held from the start barely moves the picture")
            continue
        delay = answer_delay(shot, frame, have)
        if delay is None:
            flags.append(f"{kind} {button} at {frame} did not move 40 pixels within 8 frames")
            lines.append(f"{kind} {button} at {frame}: no visible change in 8 frames")
        else:
            lines.append(f"{kind} {button} at {frame}: picture changed {delay} frame(s) later")
            if delay > 2:
                flags.append(f"{kind} {button} at {frame} took {delay} frames to show")

    judge_play(name, shot, last_n, log_text, lines, flags)
    beats = []
    for raw in log_text.splitlines():
        if raw.startswith("script "):
            continue
        if "GL " in raw or raw.startswith("GLSL") or raw.startswith("orb triangles"):
            continue
        beats.append(raw)
    if beats:
        lines.append("log:")
        lines.extend("  " + b for b in beats[:24])

    pick = [first_n, last_n]
    for frame, button in presses:
        for n in (frame + 1, frame + 5):
            if n in have:
                pick.append(n)
    if len(pick) < 8:
        step = max(1, len(have) // 8)
        ordered = sorted(have)
        pick.extend(ordered[::step])
    pick = sorted(set(pick))[:16]
    compose_strip(shot, pick, out / "strip.png")
    save_still(shot, first_n, out / "open.png")
    save_still(shot, last_n, out / "payoff.png")
    if flags:
        lines.append("look at:")
        lines.extend("  " + f for f in flags)
    else:
        lines.append("look at: nothing measured. Read the strip anyway.")
    lines.append(f"strip: {out / 'strip.png'}")
    (out / "report.txt").write_text("\n".join(lines) + "\n")
    shutil.rmtree(work)
    return flags


def main():
    want = sys.argv[1:]
    reels = [r for r in REELS if not want or r["name"] in want]
    if not reels:
        raise SystemExit(f"no reel named {want}. Have: {' '.join(r['name'] for r in REELS)}")
    subprocess.check_call(["make", "-s", "TARGET=pc"], cwd=ROOT)
    FEEL.mkdir(parents=True, exist_ok=True)
    summary = []
    for reel in reels:
        prepare(reel)
        print(f"== {reel['name']} ==", flush=True)
        flags = run_reel(reel)
        report = (FEEL / reel["name"] / "report.txt").read_text()
        print(report, end="" if report.endswith("\n") else "\n")
        if flags:
            summary.append(f"{reel['name']}: " + "; ".join(flags))
        else:
            summary.append(f"{reel['name']}: quiet")
    text = "\n".join(summary) + "\n"
    (FEEL / "SUMMARY.txt").write_text(text)
    print("== summary ==")
    print(text, end="")


if __name__ == "__main__":
    main()
