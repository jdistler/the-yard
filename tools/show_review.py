#!/usr/bin/env python3
"""The shows' review: one command that plays a show on the PC (headless, a fixed 1/60 s a frame), records what
it shows and does, measures every scene against SHOWS_BLUEPRINT.md, and writes a report to read and pictures to
look at. SHOWS_PIPELINE.md has the workflow it belongs to.

  tools/show_review.py SHOW [SHOW ...] [--scenes 2,5] [--out DIR] [--jobs 4] [--baseline] [--cab] [--flicker]

What it does, per show:
  1. builds home.love, lists the show's scenes (Home's HOME_SHOW_SEGS) and every song's shape (song_info.lua)
  2. plays each scene (in parallel, each from its own start: what a kid gets picking the scene's tile) with a
     frame a second and Home's trace (HOME_TRACE: the scene, the song, the camera, every sound, words on screen);
     a Lua error fails it
  3. measures each scene:
       life     motion, new, beats a minute, stale (the longest dead stretch), still     (show_pulse.py's measures)
       detail   cover: the share of the picture that ever moves; things: separate moving things a second;
                size: the median moving thing (px); light: mean brightness
       camera   shots, the longest hold, zoom range
       sound    sound cues a minute, the longest silence between cues
       music    the song(s), its loop, how many times a kid hears it go round
       words    every caption, plate and speech bubble, with its time
  4. findings: each scene against the gates and rules, worst first
  5. writes OUT/SHOW/report.md (the table, the findings, each scene's timeline), OUT/SHOW/scene_NN.png (a film
     strip of each scene: a frame every few seconds, the second-by-second life and sounds under it),
     OUT/SHOW/review.json; with a baseline (tools/show_baseline/SHOW.json) the report shows what changed
  --baseline   save this run as the baseline (after a round of work is done, commit it)
  --cab        also play the show on the cabinet and record its frame rate per scene (tools/show_cab.sh)
  --flicker    also run show_qa.py's flicker sheets for the scenes
  --env K=V    extra environment for Home: tools/show_fixtures/ has data to render with (the Longhorns' season
               board in season: --env HOME_UT_SCHED=tools/show_fixtures/ut_sched.json --env HOME_UT_NOW=1793750400)
  --keep       keep every frame, full size (OUT/SHOW/work/sNN/SSSS.png, SSSS: seconds into the scene)
  Also OUT/SHOW/show.png: the whole show on one sheet, a row a scene.
"""
import argparse, concurrent.futures, json, os, re, shutil, subprocess, sys, tempfile

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAMES = os.path.join(ROOT, "games")
RUN = os.path.join(GAMES, "out", "love-x86", "run.sh")
LUAJIT = os.path.join(GAMES, "out", "love-x86", "luajit")
BASE = os.path.join(ROOT, "tools", "show_baseline")
ENV = dict(os.environ, HOME_HEADLESS="1", SDL_VIDEODRIVER="offscreen", SDL_AUDIODRIVER="dummy", ALSOFT_DRIVERS="null",
           HOME_DT="0.0166667", HOME_SKIP_INTRO="1", HOME_UT_JSON="/nonexistent",
           HOME_SHOW_ART=os.path.join(GAMES, "out", "show-art"), HOME_THUMBS=os.path.join(GAMES, "love", "home", "thumbs"))

BLOCK, CHANGE = 32, 14            # the life measures (as show_pulse.py)
FINE = 16                         # the detail measures: 16 px blocks
BEAT, NEWBEAT = 0.12, 0.06
SKIP = 5                          # a scene's first seconds: its title card, the cut
W4, H4 = 192, 256                 # the frames, measured at a quarter size

# The gates (SHOWS_BLUEPRINT.md) and the rules' thresholds: (measure, red, yellow, which way is bad)
GATES = {
    "stale": (15, 8, "high"),           # s without a beat (12 is the blueprint's aim; over 15 fails test.py shows)
    "beats_per_min": (8, 14, "low"),
    "still": (0.5, 0.35, "high"),
    "new": (0.02, 0.04, "low"),
    "cover": (0.15, 0.3, "low"),        # the share of the picture that ever moves
    "things": (1.5, 2.5, "low"),        # separate moving things in a second (three layers of life)
    "cam_hold": (40, 25, "high"),       # s the camera holds one shot
    "sfx_gap": (30, 18, "high"),        # s without a sound cue
    "sfx_per_min": (1.5, 3, "low"),
    "loops": (3, 2, "high"),            # times the song goes round in the scene
}
WHY = {
    "stale": "dead stretch: nothing happens for {v:.0f} s (from {at})",
    "beats_per_min": "slow: {v:.1f} beats a minute (a beat every {gap:.0f} s)",
    "still": "still {pct:.0f}% of the time",
    "new": "the scene ends where it began (new {v:.3f}): the story does not move the picture on",
    "cover": "only {pct:.0f}% of the picture ever moves: a painting with small things on it",
    "things": "{v:.1f} things moving at once: the three layers of life are not all there",
    "cam_hold": "one shot for {v:.0f} s: move the camera (a push in, a pan, a cut to a close-up)",
    "sfx_gap": "no sound cue for {v:.0f} s",
    "sfx_per_min": "{v:.1f} sound cues a minute: cause and effect is heard as well as seen",
    "loops": "the song goes round {v:.1f} times ({song}, a {loop:.0f} s loop): the kids hear it repeat",
}


SONGS = {}
SFX_NAMES = set()


# the globals a show may read; any other is a local it forgot (a missing helper: an error the moment that line runs)
OK_GLOBALS = {"ipairs", "pairs", "math", "string", "table", "type", "require", "love", "tostring", "tonumber", "os", "io",
              "select", "unpack", "pcall", "error", "setmetatable", "getmetatable", "collectgarbage", "print", "next",
              "rawget", "rawset", "assert", "jit", "bit"}


def check_globals(show):
    """The show's Lua file read for globals it uses but nothing defines (LuaJIT's bytecode listing)."""
    path = os.path.join(GAMES, "love", "home", show + ".lua")
    if not os.path.exists(path):
        return []
    r = subprocess.run([LUAJIT, "-bl", path], capture_output=True, text=True)
    names = set(re.findall(r'GGET .*?"([A-Za-z_][A-Za-z0-9_]*)"', r.stdout))
    sets = set(re.findall(r'GSET .*?"([A-Za-z_][A-Za-z0-9_]*)"', r.stdout))
    return sorted(n for n in names - OK_GLOBALS - sets)


def build(out):
    love = os.path.join(out, "home.love")
    subprocess.check_call([os.path.join(GAMES, "cart"), "home-pack", "--out", love], stdout=subprocess.DEVNULL)
    segs = os.path.join(out, "segs.txt")
    subprocess.run([RUN, love], env=dict(ENV, HOME_SHOW_LIST=os.path.join(out, "shows.txt"), HOME_SHOW_SEGS=segs),
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60)
    songs = {}
    r = subprocess.run([LUAJIT, os.path.join(ROOT, "tools", "song_info.lua")], capture_output=True, text=True)
    if r.returncode != 0 or not r.stdout.strip():
        # (a song that doesn't load means no music at all in Home: stop here, not after an hour of rendering)
        sys.exit("songs.lua does not load:\n" + r.stderr.strip())
    for line in r.stdout.splitlines():
        s = json.loads(line)
        if "sfx" in s:
            SFX_NAMES.update(s["sfx"])
            continue
        songs[s["name"]] = s
    return love, segs, songs


def scenes_of(listing, show):
    segs, length = [], 0
    for line in open(listing):
        f = line.rstrip("\n").split(" ", 3)
        if f[0] != show:
            continue
        if f[1] == "len":
            length = int(float(f[2]))
        else:
            segs.append((int(float(f[2])), f[3]))
    out = []
    for i, (start, title) in enumerate(segs):
        end = segs[i + 1][0] if i + 1 < len(segs) else length
        out.append(dict(n=i + 1, title=title, start=start, end=end))
    return out


def play(love, show, sc, work, nocam=False):
    """One scene from its start: a frame a second (show time) and the trace. nocam: the camera held at the
    whole picture (HOME_NOCAM), so what moves is the world, not the camera."""
    d = os.path.join(work, f"s{sc['n']:02d}" + ("_world" if nocam else ""))
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)
    secs = sc["end"] - sc["start"]
    script = os.path.join(d, "script.txt")
    with open(script, "w") as s:
        for t in range(secs):
            s.write(f"{t * 60 + 30} shot {d}/{t:04d}.png\n")
        s.write(f"{secs * 60 + 40} quit\n")
    trace = os.path.join(d, "trace.txt")
    env = dict(ENV, HOME_SHOW=f"{show}:{sc['start']}", HOME_SCRIPT=script, HOME_TRACE=trace)
    if nocam:
        env["HOME_NOCAM"] = "1"
    r = subprocess.run([RUN, love], env=env,
                       capture_output=True, text=True, timeout=secs * 3 + 120)
    errors = [l for l in (r.stdout + r.stderr).splitlines()
              if re.search(r"rror|traceback|\.lua:\d+", l, re.I) and "frames:" not in l]
    return d, errors


def read_trace(path):
    ev = []
    if not os.path.exists(path):
        return ev
    for line in open(path):
        p = line.rstrip("\n").split(" ", 2)
        if len(p) < 3:
            continue
        ev.append((float(p[0]), p[1], p[2]))
    return ev


def grid(path, block):
    a = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    h, w = a.shape[0] // block, a.shape[1] // block
    return a[:h * block, :w * block].reshape(h, block, w, block, 3).mean(axis=(1, 3))


def changed(a, b):
    return np.abs(a - b).max(axis=2) > CHANGE


def shots_of(d, t0):
    ev = read_trace(os.path.join(d, "trace.txt"))
    shots = sorted((t, os.path.join(d, os.path.basename(p))) for t, k, p in ev if k == "shot")
    return [(t - t0, p) for t, p in shots if os.path.exists(p)]


def hero_moves(ev, t0, cams):
    """The seconds (show time, from the scene's start) in which one of the cast moved through the world by at least
    half its own size: someone doing something, whatever the camera is doing. (The trace's "crowd" lines: every
    one of the cast drawn, size and place on the screen; each is matched to the nearest of its size a second ago.)"""
    if not cams:
        return set()
    cam_t = [c[0] for c in cams]

    def world(tt, d, sx, sy):
        i = min(range(len(cam_t)), key=lambda j: abs(cam_t[j] - tt))
        cx, cy, z = cams[i][1]
        return ((sx - 384) / z + cx, (sy - 512) / z + cy, d / z)
    frames = []
    for t, k, rest in ev:
        if k != "crowd":
            continue
        f = [float(x) for x in rest.split()]
        tt = t - t0
        frames.append((tt, [world(tt, f[i], f[i + 1], f[i + 2]) for i in range(0, len(f) - 2, 3)]))
    moved = set()
    for sec in range(0, int(max((p[0] for p in frames), default=0)) + 2):
        win = [p for p in frames if sec - 1 < p[0] <= sec]
        if len(win) < 2:
            continue
        a, b = win[0][1], win[-1][1]
        for (bx, by, bd) in b:
            best = None
            for (ax, ay, ad) in a:
                if abs(ad - bd) <= 0.25 * bd:
                    dist = ((ax - bx) ** 2 + (ay - by) ** 2) ** 0.5
                    best = dist if best is None or dist < best else best
            if best is not None and best > 0.5 * bd:
                moved.add(sec)
                break
    return moved


def life(shots, cams=None, hero=None):
    """The life measures of a run of frames a second: motion, new, beats, stale, still; cover, things, size.
    cams: [(t, (x, y, z))], the camera through the scene: each second is looked at through that second's view
    (the frames being the world's, the camera held still, what moved is the world, at the size the kids see it)."""
    times = [t for t, _ in shots]
    small = [Image.open(p).convert("RGB").resize((W4, H4), Image.BOX) for _, p in shots]
    n = len(small)

    def view_at(t):
        if not cams:
            return (0, 0, W4, H4)
        c = min(cams, key=lambda c: abs(c[0] - t))[1]
        hw, hh = W4 / 2 / c[2], H4 / 2 / c[2]
        x, y = c[0] / 4, c[1] / 4
        return (max(0, x - hw), max(0, y - hh), min(W4, x + hw), min(H4, y + hh))
    views = [view_at(t) for t in times]
    cache = {}

    def look(i, v, size):
        k = (i, v, size)
        if k not in cache:
            cache[k] = np.asarray(small[i].crop(tuple(round(x) for x in v)).resize(size, Image.BOX), dtype=np.float32)
        return cache[k]
    gb, gf = (W4 * 4 // BLOCK, H4 * 4 // BLOCK), (W4 * 4 // FINE, H4 * 4 // FINE)
    lo = next((i for i, t in enumerate(times) if t >= SKIP), n - 1)
    motion, new = np.zeros(n), np.zeros(n)
    for i in range(1, n):
        motion[i] = changed(look(i, views[i], gb), look(i - 1, views[i], gb)).mean()
    beats, gap, worst, worst_at = [], 0, 0, times[lo]
    for i in range(lo, n):
        if i > lo:
            nov = np.ones(gb[::-1], bool)
            for j in (range(lo, i - 2) if i - lo > 2 else [lo]):
                nov &= changed(look(i, views[i], gb), look(j, views[i], gb))
            new[i] = nov.mean()
        if motion[i] >= BEAT or new[i] >= NEWBEAT or (hero and round(times[i] + 0.5) in hero):
            beats.append(times[i])
            gap = 0
        else:
            gap += 1
            if gap > worst:
                worst, worst_at = gap, times[i] - gap + 1
        # (the cache holds this second's views only)
        cache = {k: v for k, v in cache.items() if k[1] == views[min(i + 1, n - 1)]}
    dur = max(1, n - lo)
    ever = np.zeros(gf[::-1], int)
    things, sizes = [], []
    for i in range(max(lo, 1), n):
        ch = changed(look(i, views[i], gf), look(i - 1, views[i], gf))
        ever += ch
        lab, k = ndimage.label(ch)
        area = ndimage.sum(ch, lab, range(1, k + 1)) if k else np.zeros(0)
        keep = area[area >= 2]
        things.append(len(keep))
        z = W4 / max(1, views[i][2] - views[i][0])
        sizes.extend((keep * FINE * FINE).tolist())
    light = float(np.mean([np.asarray(im, dtype=np.float32).mean() for im in small[lo:]]))
    return dict(motion=float(motion[lo:].mean()), new=float(new[lo:].mean()), beats_per_min=len(beats) * 60 / dur,
                stale=worst, stale_at=worst_at, still=float((motion[lo:] < 0.03).mean()),
                cover=float((ever >= max(2, dur * 0.05)).mean()), things=float(np.mean(things)) if things else 0,
                size=int(np.median(sizes)) if sizes else 0, light=light,
                per_sec=dict(t=[round(x, 1) for x in times], motion=[round(float(x), 3) for x in motion],
                             new=[round(float(x), 3) for x in new]), dur=dur)


def measure(sc, d, dw, songs):
    """The scene's measures: its life from the world's frames (dw: the camera held still), what the kids see
    and hear from the show's own run (d: its frames, the camera, the sounds, the songs, the words)."""
    t0 = sc["start"]
    # (the song and the scene are chosen behind the curtain, before the show's clock runs: at the scene's start)
    ev = [(max(t, t0) if k in ("music", "act") else t, k, x) for t, k, x in read_trace(os.path.join(d, "trace.txt"))]
    shots = shots_of(d, t0)
    world = shots_of(dw, t0)
    if len(shots) < SKIP + 4 or len(world) < SKIP + 4:
        return None
    m = dict(n=sc["n"], title=sc["title"], start=t0, secs=sc["end"] - t0)
    cams = [(t - t0, tuple(float(x) for x in rest.split())) for t, k, rest in ev if k == "cam"]
    hero = hero_moves(ev, t0, cams)
    w = life(world, cams, hero)
    m["hero_secs"] = len(hero)
    seen = life(shots)
    dur = w.pop("dur")
    m.update(w)
    # what the camera adds: the seen picture's beats (a moving camera beats every second; the world's are the story)
    m["beats_seen"] = seen["beats_per_min"]
    m["stale_seen"] = seen["stale"]
    # camera
    cams = [(t - t0, [float(x) for x in rest.split()]) for t, k, rest in ev if k == "cam" and t - t0 >= SKIP - 0.01]
    if len(cams) > 2:
        cuts, moving, hold, worst_hold, zs = 0, 0, 0.0, 0.0, []
        for (ta, a), (tb, b) in zip(cams, cams[1:]):
            dt = max(tb - ta, 1e-3)
            dxy = abs(a[0] - b[0]) + abs(a[1] - b[1])
            dz = abs(a[2] - b[2])
            zs.append(b[2])
            if dxy > 80 or dz > 0.15:
                cuts += 1
                hold = 0
            elif dxy / dt > 6 or dz / dt > 0.01:
                moving += dt
                hold = 0
            else:
                hold += dt
                worst_hold = max(worst_hold, hold)
        m.update(cam_cuts=cuts, cam_moving=moving / max(1, cams[-1][0] - cams[0][0]), cam_hold=worst_hold,
                 zoom=(min(zs), max(zs)))
    # the cast's size on the screen (the biggest of them, each frame they're drawn)
    cast = [float(x.split()[0]) for t, k, x in ev if k == "cast" and t - t0 >= SKIP and float(x.split()[0]) > 0]
    if cast:
        m["cast_px"] = int(np.median(cast))
        m["cast_shown"] = len(cast) / max(1, len([1 for t, k, x in ev if k == "cast" and t - t0 >= SKIP]))
        m["hero_moving"] = m["hero_secs"] / max(1, m["secs"] - SKIP)
    # fonts made while the scene plays (each one a texture: made every frame, they ran the cabinet out of memory)
    m["fonts_made"] = len([1 for t, k, x in ev if k == "font" and t - t0 > 1])
    # particles (the cabinet's fill: big soft smoke is the costly kind)
    parts = [tuple(int(v) for v in x.split()) for t, k, x in ev if k == "parts"]
    if parts:
        m["smoke_max"] = max(p[0] for p in parts)
        m["sparks_max"] = max(p[1] for p in parts)
    # sound
    sfx = [(t - t0, x) for t, k, x in ev if k == "sfx" and t - t0 >= 0]
    marks = [SKIP] + [t for t, _ in sfx if t >= SKIP] + [m["secs"]]
    m.update(sfx_per_min=len([1 for t, _ in sfx if t >= SKIP]) * 60 / dur, sfx_gap=max(b - a for a, b in zip(marks, marks[1:])),
             sfx_names=sorted({x for _, x in sfx}))
    # music: the song(s), their loop, how often it goes round in this scene
    mus = [(t - t0, x) for t, k, x in ev if k == "music"]
    m["songs"] = []
    for i, (t, name) in enumerate(mus):
        until = mus[i + 1][0] if i + 1 < len(mus) else m["secs"]
        info = songs.get(name, {})
        heard = max(0.0, until - max(t, 0))
        loop = info.get("secs") or 0
        # (a song that hands over to another when it ends: the whole chain is what goes round)
        nxt, seen_chain = info.get("next"), {name}
        while nxt and nxt not in seen_chain:
            seen_chain.add(nxt)
            loop += songs.get(nxt, {}).get("secs") or 0
            nxt = songs.get(nxt, {}).get("next")
        if heard < 1:
            continue
        m["songs"].append(dict(name=name, from_=round(max(t, 0), 1), heard=round(heard, 1), loop=loop,
                               bpm=info.get("bpm"), drums=info.get("drums"), lanes=info.get("lanes")))
    longest = max(m["songs"], key=lambda s: s["heard"]) if m["songs"] else None
    m["loops"] = longest["heard"] / longest["loop"] if longest and longest["loop"] else 0
    m["song"] = longest["name"] if longest else "-"
    # words
    m["words"] = [(round(t - t0, 1), k, x) for t, k, x in ev if k in ("say", "caption", "plate")]
    m["timeline"] = sorted([(round(t - t0, 1), k, x) for t, k, x in ev if k in ("sfx", "music", "act", "say", "caption", "plate")])
    m["frames"] = [p for _, p in shots]
    m["frame_t"] = [t for t, _ in shots]
    return m


def findings(m, night=False):
    """The scene against the gates: [(level, measure, text)], worst first."""
    out = []
    for k, (red, yellow, bad) in GATES.items():
        if m.get(k) is None:
            continue
        v = m[k]
        if night and k in ("stale", "beats_per_min", "still", "new", "cover", "things", "light"):
            continue
        worse = (lambda x, lim: x > lim) if bad == "high" else (lambda x, lim: x < lim)
        level = "red" if worse(v, red) else "yellow" if worse(v, yellow) else None
        if not level:
            continue
        at = f"{int(m.get('stale_at', 0)) // 60}:{int(m.get('stale_at', 0)) % 60:02d} into the scene"
        text = WHY[k].format(v=v, at=at, pct=v * 100, gap=60 / max(v, 0.1), song=m.get("song"),
                             loop=max((s["loop"] for s in m.get("songs", [])), default=0))
        out.append((level, k, text))
    if m.get("light", 255) < 28 and not night:
        out.append(("yellow", "light", f"dark (mean brightness {m['light']:.0f}/255): small things on black read as nothing"))
    if m.get("size") and m["size"] < 900 and (m.get("cover") or 1) < 0.4:
        out.append(("yellow", "size", f"the moving things are small (median {m['size']} px, a {int(m['size'] ** 0.5)} px "
                                      "square): bring the hero closer or the camera in"))
    if m.get("cast_px") is not None and m.get("cast_shown", 0) > 0.3:
        px = m["cast_px"]
        if px < 85:
            out.append(("yellow", "hero", f"the cast is small on the screen (the biggest about {px} px across, median): "
                                          f"the blueprint's hero is a sixth of the screen (~170 px); bigger, or the camera in"))
    elif m.get("cast_shown") is not None and m.get("cast_shown", 0) <= 0.3:
        out.append(("info", "hero", f"the cast is on screen {m['cast_shown'] * 100:.0f}% of the scene: who is the hero?"))
    if m.get("fonts_made", 0) > 30:
        out.append(("red", "memory", f"{m['fonts_made']} fonts made while the scene plays: a text size that keeps "
                                     "changing makes a new font (and texture) each time; the cabinet runs out of memory"))
    if m.get("smoke_max", 0) > 250:
        out.append(("yellow", "fill", f"{m['smoke_max']} smoke puffs at once (cap 500): the cabinet is fill-bound, "
                                      "38 fps at Mission Control's launch with 500; emit a rate, keep them few"))
    if "cam_hold" not in m:
        out.append(("yellow", "camera", "no camera: the scene is one shot"))
    # the music and the sounds
    for sg in m.get("songs", []):
        info = SONGS.get(sg["name"], {})
        parts = info.get("parts") or []
        if sg["heard"] > 20 and sg["loop"] and sg["loop"] < 25:
            out.append(("yellow", "music", f"{sg['name']} is a {sg['loop']:.0f} s loop under {sg['heard']:.0f} s of scene: "
                                           "write it a B part or a longer form"))
        if sg["heard"] > 20 and parts and len(set(parts)) == 1:
            out.append(("yellow", "music", f"{sg['name']} is one part played {len(parts)} times: no B part, no lift"))
    names = [x for t, k, x in m.get("timeline", []) if k == "sfx"]
    missing = sorted({x for x in names if SFX_NAMES and x not in SFX_NAMES})
    if missing:
        out.append(("red", "sound", f"sound effects that don't exist (silent): {', '.join(missing)} (songs.lua M.SFX)"))
    if len(names) >= 6:
        top = max(set(names), key=names.count)
        if names.count(top) / len(names) > 0.6:
            out.append(("info", "sound", f"{names.count(top)} of {len(names)} sounds are '{top}': vary them"))
    words = len(m.get("words", []))
    if words and words * 60 / max(1, m["secs"]) > 8:
        out.append(("info", "words", f"{words} lines of words: is the story told in pictures first?"))
    rank = {"red": 0, "yellow": 1, "info": 2}
    return sorted(out, key=lambda f: rank[f[0]])


def film(m, path):
    """The scene's film strip: a frame every few seconds, and under each its seconds' life and sounds."""
    frames, times = m["frames"], m["frame_t"]
    step = max(2, int(np.ceil(len(frames) / 30)))
    picks = list(range(0, len(frames), step))
    cols, tw, th, band = 6, 192, 256, 44
    rows = (len(picks) + cols - 1) // cols
    im = Image.new("RGB", (cols * tw, 30 + rows * (th + band)), (16, 16, 22))
    d = ImageDraw.Draw(im)
    d.text((6, 8), f"{m['n']}. {m['title']}  ({m['secs']} s)   stale {m['stale']} s  beats/min {m['beats_per_min']:.1f}  "
                   f"cover {m['cover'] or 0:.2f}  things {m['things'] or 0:.1f}  song {m['song']}", fill=(255, 230, 120))
    sfx_t = [t for t, k, _ in m["timeline"] if k == "sfx"]
    word_t = [t for t, k, _ in m["timeline"] if k in ("say", "caption", "plate")]
    mo, nw = m["per_sec"]["motion"], m["per_sec"]["new"]
    for j, i in enumerate(picks):
        x, y = (j % cols) * tw, 30 + (j // cols) * (th + band)
        im.paste(Image.open(frames[i]).convert("RGB").resize((tw, th)), (x, y))
        t = times[i]
        d.text((x + 4, y + 4), f"{int(t) // 60}:{int(t) % 60:02d}", fill=(255, 255, 0))
        by = y + th + band - 4
        span = range(i, min(i + step, len(frames)))
        bw = (tw - 4) / step
        for k, s in enumerate(span):
            bx = x + 2 + k * bw
            mv, nv = (mo[s], nw[s]) if s < len(mo) else (0, 0)
            mh, nh = int(min(mv, 1) * 30), int(min(nv * 3, 1) * 30)
            d.rectangle([bx, by - mh, bx + bw / 2 - 1, by], fill=(80, 140, 255))
            d.rectangle([bx + bw / 2, by - nh, bx + bw - 1, by], fill=(255, 150, 40))
        t1 = times[span[-1]] + 1
        for st in sfx_t:
            if t <= st < t1:
                sx = x + 2 + (st - t) / max(1e-3, t1 - t) * (tw - 4)
                d.line([sx, y + th + 2, sx, y + th + 9], fill=(255, 255, 255), width=2)
        for wt in word_t:
            if t <= wt < t1:
                sx = x + 2 + (wt - t) / max(1e-3, t1 - t) * (tw - 4)
                d.rectangle([sx - 2, y + th + 2, sx + 2, y + th + 6], fill=(255, 220, 0))
    im.save(path)


def overview(show, rows, path):
    """The whole show on one sheet: a row a scene, six frames across it (its variety, its arc, the transitions)."""
    tw, th, lab = 128, 171, 150
    im = Image.new("RGB", (lab + 6 * tw, len(rows) * th), (16, 16, 22))
    d = ImageDraw.Draw(im)
    for r, m in enumerate(rows):
        fr = m["frames"]
        d.text((6, r * th + 6), f"{m['n']}. {m['title'][:20]}", fill=(255, 230, 120))
        d.text((6, r * th + 22), f"{m['secs']} s  stale {m['stale']}", fill=(200, 200, 200))
        d.text((6, r * th + 36), f"{m['song']}", fill=(160, 200, 255))
        for j in range(6):
            i = min(len(fr) - 1, int((j + 0.5) * len(fr) / 6))
            im.paste(Image.open(fr[i]).convert("RGB").resize((tw, th)), (lab + j * tw, r * th))
    im.save(path)


def fmt_t(t):
    return f"{int(t) // 60}:{int(t) % 60:02d}"


def report(show, rows, songs, out, base, cab):
    L = [f"# {show}: the review", "",
         "Every scene against SHOWS_BLUEPRINT.md's gates (SHOWS_PIPELINE.md has the workflow). The life measures "
         "(stale, beats, still, new, cover, things) are the world's, the camera held still; 'seen b/m' is with the camera. "
         "Film strips: `scene_NN.png` (blue: motion, orange: new, white ticks: sounds, yellow: words).", "",
         "| # | scene | secs | stale | beats/m | seen b/m | still | new | cover | things | cast px | cam hold | cuts | sfx/m | sfx gap | song (loops) | fps |",
         "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    by_title = {v.get("title"): v for v in (base or {}).values()}
    for m in rows:
        b = by_title.get(m["title"])               # (by title: a scene added before it moves its number)

        def cell(k, f):
            v = f.format(m[k]) if m.get(k) is not None else "-"
            if b and b.get(k) is not None and m.get(k) is not None and f.format(b[k]) != v:
                v += f" ({f.format(b[k])})"
            return v
        fps = cab.get(m["n"], "") if cab else ""
        L.append(f"| {m['n']} | {m['title']} | {m['secs']} | {cell('stale', '{:.0f}')} | {cell('beats_per_min', '{:.1f}')} | {m['beats_seen']:.0f} | "
                 f"{cell('still', '{:.2f}')} | {cell('new', '{:.3f}')} | {cell('cover', '{:.2f}')} | {cell('things', '{:.1f}')} | "
                 f"{cell('cast_px', '{:.0f}')} | {cell('cam_hold', '{:.0f}')} | {m.get('cam_cuts', '-')} | {cell('sfx_per_min', '{:.1f}')} | "
                 f"{cell('sfx_gap', '{:.0f}')} | {m['song']} ({m['loops']:.1f}) | {fps} |")
    if base:
        L += ["", "_(in brackets: the baseline, tools/show_baseline/%s.json)_" % show]
    L += ["", "## Findings", ""]
    total = {"red": 0, "yellow": 0}
    for m in rows:
        for lv, k, text in m["findings"]:
            if lv in total:
                total[lv] += 1
    L.append(f"{total['red']} red, {total['yellow']} yellow.")
    L.append("")
    for m in rows:
        if not m["findings"]:
            continue
        L.append(f"**{m['n']}. {m['title']}**")
        for lv, k, text in m["findings"]:
            L.append(f"- {'🔴' if lv == 'red' else '🟡' if lv == 'yellow' else 'ℹ️'} {text}")
        L.append("")
    # the music across the show: a song that carries on into the next scene keeps going round
    L += ["## The music", "", "| scene | song | bpm | drums | loop s | heard s | goes round |", "|---|---|---|---|---|---|---|"]
    run_song, run_heard = None, 0
    for m in rows:
        for s in m["songs"]:
            run_heard = run_heard + s["heard"] if s["name"] == run_song else s["heard"]
            run_song = s["name"]
            rounds = run_heard / s["loop"] if s["loop"] else 0
            L.append(f"| {m['n']} | {s['name']} | {s['bpm']} | {'yes' if s['drums'] else 'no'} | {s['loop']:.0f} | "
                     f"{s['heard']:.0f} | {rounds:.1f}{' ⚠' if rounds > 2 else ''} |")
    L += ["", "## Timelines", "", "What each scene does, second by second: its sounds, its words, its song.", ""]
    for m in rows:
        L.append(f"### {m['n']}. {m['title']}  ({fmt_t(m['start'])}, {m['secs']} s)")
        L.append("")
        line, last = [], None
        for t, k, x in m["timeline"]:
            if k == "act":
                continue
            item = f"{x}" if k == "sfx" else f"♪{x}" if k == "music" else f'"{x}"'
            if last is not None and int(t) == last:
                line[-1] += f", {item}"
            else:
                line.append(f"{fmt_t(t)} {item}")
                last = int(t)
        L.append("  ·  ".join(line) if line else "_(nothing: no sounds, no words)_")
        L.append("")
    open(os.path.join(out, "report.md"), "w").write("\n".join(L) + "\n")
    return total


def cab_fps(show, scenes):
    """The cabinet's frame rate and memory through the show (tools/show_cab.sh, a sample every 5 s), per scene:
    the lowest fps, and the least memory left for the whole cabinet (MB)."""
    length = scenes[-1]["end"]
    r = subprocess.run([os.path.join(ROOT, "tools", "show_cab.sh"), f"{show}:0", str(length + 20)],
                       capture_output=True, text=True)
    fps, mem = [], []
    for line in r.stdout.splitlines():
        kind, _, rest = line.partition(" ")
        for tok in rest.split():
            f = tok.split(":")
            try:
                if kind == "fps" and len(f) == 2:
                    fps.append((float(f[0]), float(f[1])))
                elif kind == "mem" and len(f) >= 3:
                    mem.append((float(f[0]), float(f[1]), float(f[2])))
            except ValueError:
                pass
    if "HOME DIED" in r.stdout:
        print("cabinet:", r.stdout[r.stdout.index("HOME DIED"):].strip())
    if not fps:
        print("cabinet:", r.stdout.strip() or r.stderr.strip())
        return {}
    t0 = fps[0][0] - 5
    res = {}
    for sc in scenes:
        inside = [f for t, f in fps if sc["start"] + 3 <= t - t0 < sc["end"]]
        left = [a for t, rss, a in mem if sc["start"] <= t - 3 < sc["end"]]
        if inside:
            res[sc["n"]] = f"{min(inside):.0f}" + (f" ({min(left):.0f} MB free)" if left else "")
    return res


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("shows", nargs="+")
    ap.add_argument("--scenes")
    ap.add_argument("--out", default=os.path.join(tempfile.gettempdir(), "show_review"))
    ap.add_argument("--jobs", type=int, default=4)
    ap.add_argument("--baseline", action="store_true")
    ap.add_argument("--cab", action="store_true")
    ap.add_argument("--flicker", action="store_true")
    ap.add_argument("--env", action="append", default=[], metavar="KEY=VALUE",
                    help="extra environment for Home (e.g. HOME_UT_SCHED=tools/show_fixtures/ut_sched.json: the "
                         "Longhorns' season board in season, HOME_UT_NOW=epoch)")
    ap.add_argument("--keep", action="store_true", help="keep every frame (OUT/SHOW/work/sNN/SSSS.png) to look at full size")
    a = ap.parse_args()
    for kv in a.env:
        k, _, v = kv.partition("=")
        if v and not v.startswith("/") and os.path.exists(os.path.join(ROOT, v)):
            v = os.path.join(ROOT, v)
        ENV[k] = v
    os.makedirs(a.out, exist_ok=True)
    love, listing, songs = build(a.out)
    SONGS.update(songs)
    bad = 0
    for show in a.shows:
        bad_globals = check_globals(show)
        if bad_globals:
            print(f"{show}: reads globals nothing defines (a missing local helper?): {', '.join(bad_globals)}")
            bad += 1
        scenes = scenes_of(listing, show)
        if not scenes:
            print(f"{show}: no scenes (not a show?)")
            bad += 1
            continue
        want = {int(x) for x in a.scenes.split(",")} if a.scenes else None
        todo = [s for s in scenes if not want or s["n"] in want]
        out = os.path.join(a.out, show)
        os.makedirs(out, exist_ok=True)
        work = os.path.join(out, "work")
        rows, errors = [], []
        with concurrent.futures.ThreadPoolExecutor(a.jobs) as ex:
            seen = ex.map(lambda s: play(love, show, s, work), todo)
            world = ex.map(lambda s: play(love, show, s, work, nocam=True), todo)
            for sc, (d, errs), (dw, _) in zip(todo, seen, world):
                errors += [f"scene {sc['n']}: {e}" for e in errs]
                m = measure(sc, d, dw, songs)
                if not m:
                    errors.append(f"scene {sc['n']}: no frames")
                    continue
                m["findings"] = findings(m, night=show == "night")
                film(m, os.path.join(out, f"scene_{sc['n']:02d}.png"))
                rows.append(m)
        if rows:
            overview(show, rows, os.path.join(out, "show.png"))
        cab = cab_fps(show, scenes) if a.cab and not want else {}
        base_path = os.path.join(BASE, show + ".json")
        base = json.load(open(base_path)) if os.path.exists(base_path) else None
        total = report(show, rows, songs, out, base, cab)
        keep = {str(m["n"]): {k: v for k, v in m.items() if k not in ("frames", "frame_t", "per_sec", "timeline")} for m in rows}
        json.dump(keep, open(os.path.join(out, "review.json"), "w"), indent=1, default=str)
        if a.baseline and not want:
            os.makedirs(BASE, exist_ok=True)
            slim = {n: {k: (round(v, 3) if isinstance(v, float) else v) for k, v in r.items()
                        if k in GATES or k in ("title", "size", "light", "cam_cuts", "song", "cast_px")} for n, r in keep.items()}
            json.dump(slim, open(base_path, "w"), indent=1)
        if a.flicker:
            subprocess.run([sys.executable, os.path.join(ROOT, "tools", "show_qa.py"), show, "--out", out]
                           + (["--segs", a.scenes] if a.scenes else []))
        if not a.keep:
            shutil.rmtree(work, ignore_errors=True)
        print(f"{show}: {len(rows)} scenes, {total['red']} red, {total['yellow']} yellow"
              f"{', ' + str(len(errors)) + ' errors' if errors else ''}  ->  {out}/report.md")
        for e in errors[:20]:
            print("  ERROR", e)
        bad += bool(errors)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
