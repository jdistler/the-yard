#!/usr/bin/env python3
"""The Shelf's test pipeline: does every game on the card load, draw, move, and make sound? And on the
cabinet, does it run at full speed?

    tools/shelf_check.py                  every game, on the PC (x86 cores, headless): ~5 minutes
    tools/shelf_check.py --only arcade    one system (or a file name: --only "Contra.nes")
    tools/shelf_check.py --cab            also each game's emulation speed on the cabinet's CPU (PLAY_BENCH,
                                          niced beside Home; ~8 s a game; refuses if the cabinet is busy)

The PC pass runs games/out/pc/play with a scripted deck: 1-player (Start, or coin and start on arcade boards)
a few times, then the stick and the lower button, for 40 s of game time, taking a picture every 5 s and
recording the sound. A game passes when the core loads it, the picture is not blank, it changes over time, and
the sound is not silent. Writes OUT/report.md, OUT/<system>.png (a contact sheet: four moments per game) and
OUT/results.tsv. OUT is ~/partycade-build/check/latest (the previous run moves to .../previous).

Cores for the PC: ~/partycade-build/pc-cores (x86 builds of every core, including the squashfs's own MAME 2000
and Genesis Plus GX, from the same sources). See games/shelf/README.md.
"""
import argparse
import concurrent.futures as cf
import os
import shutil
import statistics
import struct
import subprocess
import sys
import wave

from PIL import Image, ImageChops, ImageDraw, ImageStat

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
PLAY = os.path.join(REPO, "games", "out", "pc", "play")
LIB = os.path.expanduser("~/partycade-card/library")
CORES = os.path.expanduser("~/partycade-build/pc-cores")
OUTROOT = os.path.expanduser("~/partycade-build/check")
FRAMES = 2400                       # 40 s of game time
SHOTS = list(range(300, FRAMES + 1, 300))


def games():
    out = []
    for line in open(os.path.join(LIB, "index.tsv")):
        if line.startswith("#"):
            continue
        f = line.rstrip("\n").split("\t")
        out.append({"sys": f[0], "file": f[1], "title": f[2]})
    return out


def script(sysid):
    """1P a few times (past logos and title screens), then play: right held, the lower button tapped."""
    lines = ["title=*"]
    for f in (90, 240, 420, 600, 780, 960):
        lines += [f"{f} down 1P", f"{f + 6} up 1P"]
    lines += ["1100 down RIGHT"]
    for f in range(1120, FRAMES, 40):
        lines += [f"{f} down LOW", f"{f + 8} up LOW"]
    for f in SHOTS:
        lines.append(f"{f} shot SHOT{f}")
    lines.append(f"{FRAMES + 1} quit")
    return "\n".join(lines) + "\n"


def game_area(im):
    """The picture between the bands: rows whose middle column is not the bands' dark gradient."""
    return im.crop((0, 120, im.width, im.height - 150)) if im.height > 600 else im


def run_one(g, out):
    # (no spaces: the deck script's "shot PATH" ends a path at a space)
    d = os.path.join(out, "runs", g["sys"], "".join(c if c.isalnum() or c in "._-" else "_" for c in g["file"]))
    os.makedirs(d, exist_ok=True)
    sc = script(g["sys"]).replace("SHOT", d + "/shot")
    open(os.path.join(d, "deck.cab"), "w").write(sc)
    env = dict(os.environ, SDL_VIDEODRIVER="offscreen", SDL_AUDIODRIVER="dummy", CAB_SCALE="1",
               CAB_SCRIPT=os.path.join(d, "deck.cab"), PLAY_LIB=LIB, PLAY_CORES_DIR=CORES,
               CAB_AUDIO_WAV=os.path.join(d, "sound"), PLAY_LOG=os.path.join(d, "log"))
    # The player writes saves into PLAY_LIB/saves: keep the PC test's saves away from the staged card.
    env["PLAY_LIB"] = os.path.join(d, "lib")
    os.makedirs(env["PLAY_LIB"], exist_ok=True)
    for name in ("index.tsv",):
        shutil.copy(os.path.join(LIB, name), env["PLAY_LIB"])
    os.makedirs(os.path.join(env["PLAY_LIB"], "system", "mame2000"), exist_ok=True)
    hs = os.path.join(LIB, "system", "mame2000", "hiscore.dat")
    if os.path.exists(hs):
        shutil.copy(hs, os.path.join(env["PLAY_LIB"], "system", "mame2000"))
    # Williams boards' settings memory (games/shelf/nvram): blank, they stop on FACTORY SETTINGS RESTORED.
    nv = os.path.join(REPO, "games", "shelf", "nvram")
    nvd = os.path.join(env["PLAY_LIB"], "saves", "arcade", "mame2000", "nvram")
    os.makedirs(nvd, exist_ok=True)
    for f in os.listdir(nv):
        shutil.copy(os.path.join(nv, f), nvd)
    rom = os.path.join(LIB, g["sys"], g["file"])
    try:
        r = subprocess.run([PLAY, g["sys"], rom], env=env, capture_output=True, text=True, errors="replace", timeout=240)
        code, err = r.returncode, r.stdout + r.stderr
    except subprocess.TimeoutExpired:
        code, err = -9, "timeout"
    res = dict(g, code=code, notes=[])
    log = (open(os.path.join(d, "log"), errors="replace").read() if os.path.exists(os.path.join(d, "log")) else "") + err
    if "refused" in log or "dlopen" in log or code not in (0,):
        res["notes"].append(f"exit {code}" + (": core refused the file" if "refused" in log else ""))
    shots = [os.path.join(d, f"shot{f}") for f in SHOTS if os.path.exists(os.path.join(d, f"shot{f}"))]
    res["shots"] = shots
    lit, changes = [], []
    prev = None
    for p in shots:
        im = game_area(Image.open(p).convert("RGB"))
        st = ImageStat.Stat(im.convert("L"))
        lit.append(st.stddev[0])
        if prev is not None:
            changes.append(ImageStat.Stat(ImageChops.difference(im, prev).convert("L")).mean[0])
        prev = im
    res["detail"] = max(lit) if lit else 0
    res["motion"] = sum(1 for c in changes if c > 1.0)
    if not shots:
        res["notes"].append("no pictures")
    elif res["detail"] < 8:
        res["notes"].append("blank picture")
    elif res["motion"] < 2:
        res["notes"].append("picture hardly changes (stuck?)")
    wavs = [os.path.join(d, f) for f in os.listdir(d) if f.endswith(".wav")]
    res["sound"] = 0.0
    if wavs:
        try:
            w = wave.open(wavs[0])
            n = w.getnframes()
            w.setpos(min(n // 4, n))
            data = w.readframes(min(n, 44100 * 20))
            samples = struct.unpack("<%dh" % (len(data) // 2), data[: len(data) // 2 * 2])
            res["sound"] = statistics.pstdev(samples[::7]) if samples else 0
        except Exception as e:
            res["notes"].append(f"sound unreadable: {e}")
    if res["sound"] < 30:
        if g["sys"] == "arcade":
            # The PC's MAME 2000 (today's source) is silent on some boards the cabinet's 2020 build plays with
            # sound (Bomb Jack, Joust, Defender): only --cab's measure counts for arcade sound.
            res["soft"] = "silent on the PC core"
        else:
            res["notes"].append("silent")
    res["ok"] = not res["notes"]
    return res


def sheet(results, path):
    """Four moments per game (10, 20, 30, 40 s), a row each, with the verdict."""
    tw, th = 144, 192
    rows = len(results)
    im = Image.new("RGB", (260 + 4 * (tw + 6), rows * (th + 8) + 8), (12, 8, 20))
    dr = ImageDraw.Draw(im)
    for i, r in enumerate(results):
        y = 8 + i * (th + 8)
        dr.text((8, y + 8), r["title"][:34], fill=(255, 240, 220))
        dr.text((8, y + 28), "OK" if r["ok"] else "; ".join(r["notes"])[:40], fill=(120, 230, 140) if r["ok"] else (255, 120, 120))
        dr.text((8, y + 48), f"detail {r['detail']:.0f}  motion {r['motion']}  sound {r['sound']:.0f}", fill=(170, 160, 200))
        if r.get("cab"):
            dr.text((8, y + 68), f"cabinet {r['cab']}", fill=(170, 160, 200))
        for k, p in enumerate([s for s in r["shots"] if s.endswith(tuple(str(f) for f in (600, 1200, 1800, 2400)))]):
            try:
                t = Image.open(p).convert("RGB").resize((tw, th))
                im.paste(t, (260 + k * (tw + 6), y))
            except Exception:
                pass
    im.save(path)


def cab_bench(results):
    host = subprocess.run([os.path.join(HERE, "cab.sh"), "host"], capture_output=True, text=True).stdout.strip()
    ssh = ["ssh", "-i", os.path.expanduser("~/yard_key_ecdsa"), "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=no",
           "-o", "UserKnownHostsFile=/dev/null", "-o", "LogLevel=ERROR", "-o", "ConnectTimeout=8", f"root@{host}"]
    busy = subprocess.run(ssh + ["pidof yard play PacMan Galaga start.sh tvplay >/dev/null && echo busy; true"],
                          capture_output=True, text=True).stdout
    if "busy" in busy:
        print("cabinet busy: no speed pass")
        return
    for r in results:
        # Safe beside Home: wait for 50 MB free first, and cap the player at 100 MB of address space so a
        # board that runs away is killed, not the machine starved (2026-11-07: the cabinet dropped off the
        # network during an uncapped pass, cause not known).
        cmd = (f"n=0; while [ $(awk '/MemAvailable/ {{print int($2/1024)}}' /proc/meminfo) -lt 50 ] && [ $n -lt 20 ]; "
               f"do sleep 1; n=$((n+1)); done; cd /mnt/sdcard/library && (ulimit -v 102400; PLAY_LIB=$PWD PLAY_BENCH=6 "
               f"SDL_VIDEODRIVER=dummy nice -n 19 bin/play {r['sys']} \"{r['sys']}/{r['file']}\") 2>&1 "
               f"| grep -E 'bench|refused' | head -1")
        try:
            out = subprocess.run(ssh + [cmd], capture_output=True, text=True, timeout=120).stdout.strip()
        except subprocess.TimeoutExpired:
            out = "timeout"
        if "timeout" == out or not subprocess.run(ssh + ["true"], capture_output=True).returncode == 0:
            print("  the cabinet stopped answering: speed pass abandoned", flush=True)
            r["cab"] = "cabinet lost"
            return
        if out.startswith("bench"):
            fps = float(out.split(":")[1].split()[0])
            need = float(out.split("needs ")[1].split(")")[0])
            snd = float(out.split("sound ")[1]) if "sound " in out else -1
            r["cab"] = f"{fps:.0f} fps (needs {need:.0f}), sound {snd:.0f}"
            if 0 <= snd < 30:
                r["notes"].append("silent on the cabinet")
                r["ok"] = False
            if fps < need * 1.25:
                r["notes"].append(f"slow on the cabinet: {fps:.0f} fps of {need:.0f} needed")
                r["ok"] = False
        else:
            r["cab"] = out or "no answer"
            r["notes"].append("cabinet: " + (out or "crashed"))
            r["ok"] = False
        print(f"  cabinet {r['sys']}/{r['file']}: {r['cab']}", flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="a system id or a file name")
    ap.add_argument("--cab", action="store_true", help="also measure each game's speed on the cabinet")
    ap.add_argument("--jobs", type=int, default=max(2, (os.cpu_count() or 4) // 2))
    a = ap.parse_args()
    if not os.path.exists(PLAY):
        sys.exit("build the player first: make -C games TARGET=pc out/pc/play")
    gs = [g for g in games() if not a.only or a.only in (g["sys"], g["file"])]
    out = os.path.join(OUTROOT, "latest")
    if os.path.isdir(out):
        prev = os.path.join(OUTROOT, "previous")
        shutil.rmtree(prev, ignore_errors=True)
        os.rename(out, prev)
    os.makedirs(out)
    print(f"{len(gs)} game(s) on the PC, {a.jobs} at a time")
    with cf.ThreadPoolExecutor(a.jobs) as ex:
        results = list(ex.map(lambda g: run_one(g, out), gs))
    if a.cab:
        print("speed and sound on the cabinet, one game at a time", flush=True)
        cab_bench(results)
    by_sys = {}
    for r in results:
        by_sys.setdefault(r["sys"], []).append(r)
    for sysid, rs in by_sys.items():
        sheet(rs, os.path.join(out, f"{sysid}.png"))
    # Flags a person has already looked at (games/shelf/reviewed.tsv).
    rev = {}
    for line in open(os.path.join(REPO, "games", "shelf", "reviewed.tsv")):
        if line.strip() and not line.startswith("#"):
            f = line.rstrip("\n").split("\t")
            rev[(f[0], f[1])] = f[2] if len(f) > 2 else "reviewed"
    for r in results:
        if not r["ok"] and (r["sys"], r["file"]) in rev and not any("cabinet" in n or "exit" in n for n in r["notes"]):
            r["ok"], r["soft"] = True, "reviewed: " + rev[(r["sys"], r["file"])]
    bad = [r for r in results if not r["ok"]]
    with open(os.path.join(out, "report.md"), "w") as f:
        f.write(f"# Shelf check: {len(results) - len(bad)} of {len(results)} pass\n\n")
        f.write("| system | game | verdict | detail | motion | sound | cabinet |\n|---|---|---|---|---|---|---|\n")
        for r in sorted(results, key=lambda r: (r["ok"], r["sys"], r["title"])):
            f.write(f"| {r['sys']} | {r['title']} | {('ok' + (' (' + r['soft'] + ')' if r.get('soft') else '')) if r['ok'] else '; '.join(r['notes'])} | {r['detail']:.0f} | "
                    f"{r['motion']} | {r['sound']:.0f} | {r.get('cab', '')} |\n")
    with open(os.path.join(out, "results.tsv"), "w") as f:
        for r in results:
            f.write("\t".join([r["sys"], r["file"], "ok" if r["ok"] else "; ".join(r["notes"]), r.get("cab", "")]) + "\n")
    print(f"{len(results) - len(bad)} of {len(results)} pass -> {out}/report.md")
    for r in bad:
        print(f"  {r['sys']}/{r['file']}: {'; '.join(r['notes'])}")


if __name__ == "__main__":
    main()
