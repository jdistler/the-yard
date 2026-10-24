#!/usr/bin/env python3
"""Play a game a few frames at a time, the way the cabinet runs it, and look at the result.

    python3 playtest.py start tea                 a fresh session (saves in its own folder)
    python3 playtest.py do "wait 60; look; hold RIGHT 20; tap LOW; film 40 every 4"
    python3 playtest.py listen                    the notes heard so far, and a spectrogram
    python3 playtest.py stop
    python3 playtest.py perf chest                instructions per frame, and a Cortex-A7 guess

What makes it the cabinet and not a window on a PC:
  * The game draws through the cabinet path: the 1024x768 framebuffer, turned -90 degrees
    (CAB_RAW_FB=1). Every picture here is that framebuffer turned back to the upright panel,
    768x1024, so the scaling and the letterbox are the panel's own.
  * The deck is one joystick on player 0 with the panel's names: UP DOWN LEFT RIGHT, LOW TL
    TR (the three right of the stick), 1P 2P (the two left of it). The stick is strict
    four-way by default (CAB_FOURWAY=1): of two directions held, the newer wins, because
    nobody has measured whether this stick can report a diagonal. --eight lifts that.
  * Time is frames at 60 Hz. Nothing moves between commands. "wait 60" is one second.
  * Sound is the game's own synth pulled 735 samples a frame into a WAV (CAB_AUDIO_WAV), so a
    note can be matched to the frame that started it. Audio block N is what frame N started.
    The real panel adds the ALSA buffer on top, about 23 ms (1024 samples).
  * Saves are real files in the session's data folder, the stand-in for /data/Games.
  * 1P+2P held for 60 frames quits, as on the cabinet. The Yard launches the other games as
    child processes, so a session started on the Yard can walk into any game and back.
    A game opening or closing ends the step in progress on its own first frame, and frame
    numbers count per game. "now:" always names the game on screen.

Macro words for "do" (separate with ; or new lines):
    tap X [n]       press X for n frames (default 4), then let go for 2 frames
    hold X N        hold X for N frames, then let go
    press X         hold X until release
    release [X]     let go of X, or of everything
    wait N          run N frames
    look [label]    keep a picture of the next frame
    film N [every K]  run N frames, keeping every Kth picture (default 6)
    until REGEX [max N]   run until the game logs a line matching REGEX (default max 1200)
    quit
Each "do" prints the frames kept (a sheet.png under the session), the new log lines, the
sound onsets with note names, and the state. Pictures stay in the session's frames folder.
"""
import json
import math
import os
import re
import shutil
import signal
import socket
import subprocess
import sys
import time
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BIN = ROOT / "out" / "pc"
SESSIONS = ROOT / "out" / "playtest"
TITLES = {"yard": "The Yard", "keep": "Keep", "lamp": "Lamp", "orb": "Orb", "tea": "Tea", "chest": "Chest"}
BUTTONS = {"UP", "DOWN", "LEFT", "RIGHT", "LOW", "TL", "TR", "1P", "2P"}


def sdir(name):
    return SESSIONS / name


# ----------------------------------------------------------------------------- server

def serve(name):
    """Runs detached: owns the game's stdin and stdout and answers one client at a time."""
    d = sdir(name)
    meta = json.loads((d / "session.json").read_text())
    env = dict(os.environ)
    env.update(meta["env"])
    log = open(d / "game.log", "ab", buffering=0)
    game = subprocess.Popen([str(BIN / meta["game"]), *meta["args"]], cwd=d / "data", env=env,
                            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=log, bufsize=0)
    sock_path = d / "sock"
    if sock_path.exists():
        sock_path.unlink()
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(str(sock_path))
    srv.listen(1)
    out = game.stdout

    def read_line():
        line = b""
        while not line.endswith(b"\n"):
            ch = out.read(1)
            if not ch:
                return None
            line += ch
        return line.decode(errors="replace").rstrip("\n")

    pending = []
    first = read_line()
    if first:
        pending.append(first)
    while True:
        conn, _ = srv.accept()
        data = b""
        while not data.endswith(b"\n"):
            chunk = conn.recv(65536)
            if not chunk:
                break
            data += chunk
        req = json.loads(data.decode())
        replies = list(pending)
        pending = []
        if req.get("stop"):
            try:
                game.stdin.write(b"quit\n")
                game.stdin.flush()
            except OSError:
                pass
            conn.sendall((json.dumps({"lines": [], "alive": False}) + "\n").encode())
            conn.close()
            break
        alive = game.poll() is None
        if alive and req["cmds"]:
            try:
                game.stdin.write(("\n".join(req["cmds"]) + "\n").encode())
                game.stdin.flush()
            except OSError:
                alive = False
        need = req["readies"]
        got = 0
        while alive and got < need:
            line = read_line()
            if line is None:
                alive = False
                break
            replies.append(line)
            if line.startswith("ready "):
                got += 1
        conn.sendall((json.dumps({"lines": replies, "alive": game.poll() is None}) + "\n").encode())
        conn.close()
        if game.poll() is not None and not req["cmds"]:
            pass
    try:
        game.wait(timeout=5)
    except subprocess.TimeoutExpired:
        game.kill()
    srv.close()
    sock_path.unlink(missing_ok=True)


def call(name, cmds, readies, stop=False):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(str(sdir(name) / "sock"))
    s.sendall((json.dumps({"cmds": cmds, "readies": readies, "stop": stop}) + "\n").encode())
    data = b""
    while not data.endswith(b"\n"):
        chunk = s.recv(65536)
        if not chunk:
            break
        data += chunk
    s.close()
    return json.loads(data.decode())


# ----------------------------------------------------------------------------- pictures

def panel_view(path):
    """The raw 1024x768 framebuffer, turned back upright and cropped to the picture."""
    from PIL import Image
    im = Image.open(path).convert("RGB")
    if im.width > im.height:
        im = im.rotate(-90, expand=True)
    bbox = im.point(lambda v: 255 if v > 3 else 0).convert("L").getbbox()
    if bbox and (bbox[2] - bbox[0]) > im.width * 0.5:
        im = im.crop(bbox)
    return im


def deck(draw, x, y, held, w):
    """The control deck as the player sees it, with what is held lit."""
    on, off, ink = (255, 210, 90), (70, 64, 96), (20, 16, 30)
    draw.rectangle([x, y, x + w, y + 46], fill=(34, 30, 52))
    cx = x + 18
    draw.ellipse([cx - 7, y + 6, cx + 7, y + 20], fill=on if "1P" in held else off)
    draw.ellipse([cx - 7, y + 26, cx + 7, y + 40], fill=on if "2P" in held else off)
    sx, sy = x + 60, y + 23
    draw.ellipse([sx - 17, sy - 17, sx + 17, sy + 17], fill=(52, 46, 74))
    for name, dx, dy in (("UP", 0, -11), ("DOWN", 0, 11), ("LEFT", -11, 0), ("RIGHT", 11, 0)):
        draw.ellipse([sx + dx - 5, sy + dy - 5, sx + dx + 5, sy + dy + 5], fill=on if name in held else off)
    bx = x + 104
    draw.ellipse([bx, y + 6, bx + 16, y + 22], fill=on if "TL" in held else off)
    draw.ellipse([bx + 22, y + 6, bx + 38, y + 22], fill=on if "TR" in held else off)
    draw.ellipse([bx + 8, y + 26, bx + 24, y + 42], fill=on if "LOW" in held else off)
    del ink


def loudness(name, title=None):
    """RMS per frame (735 samples) of one game's audio in the session, and the WAV path.
    Each game process writes its own file (audio-<Title>.wav); frames count per process."""
    d = sdir(name)
    if title:
        path = d / ("audio-" + re.sub(r"[^A-Za-z0-9]", "", title) + ".wav")
        wavs = [path] if path.exists() else []
    else:
        wavs = sorted(d.glob("audio-*.wav"), key=lambda p: p.stat().st_mtime)
    if not wavs:
        return [], None
    path = wavs[-1]
    try:
        import numpy as np
        w = wave.open(str(path))
        n = w.getnframes()
        a = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float32)
        mono = (a[0::2] + a[1::2]) * 0.5
        blocks = len(mono) // 735
        rms = [float(np.sqrt(np.mean(mono[i * 735:(i + 1) * 735] ** 2))) for i in range(blocks)]
        return rms, path
    except Exception:
        return [], path


NOTE = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def onsets(name, f0, f1, title=None):
    """Frames in [f0, f1) where a sound starts, with its strongest pitch as a note name."""
    import numpy as np
    rms, path = loudness(name, title)
    if not path:
        return []
    w = wave.open(str(path))
    a = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32)
    mono = (a[0::2] + a[1::2]) * 0.5
    found = []
    for f in range(max(1, f0), min(f1, len(rms))):
        if rms[f] > 120 and rms[f] > rms[f - 1] * 1.6 + 40:
            seg = mono[f * 735:f * 735 + 4096]
            if len(seg) < 1024:
                continue
            spec = np.abs(np.fft.rfft(seg * np.hanning(len(seg))))
            spec[:int(80 * len(seg) / 44100)] = 0
            k = int(np.argmax(spec))
            hz = k * 44100 / len(seg)
            flat = float(np.exp(np.mean(np.log(spec[1:] + 1e-6))) / (np.mean(spec[1:]) + 1e-6))
            if flat > 0.35 or hz <= 0:
                label = "noise"
            else:
                m = int(round(69 + 12 * math.log2(hz / 440)))
                label = f"{NOTE[m % 12]}{m // 12 - 1}"
            found.append((f, label, int(rms[f])))
    return found


def sheet(name, shots, dest, title=None):
    from PIL import Image, ImageDraw
    rms, _ = loudness(name, title)
    tiles = []
    for path, label, held, frame in shots:
        try:
            im = panel_view(path)
        except OSError:
            continue
        tw = 240
        th = int(im.height * tw / im.width)
        im = im.resize((tw, th), Image.LANCZOS)
        tile = Image.new("RGB", (tw, th + 66), (20, 16, 30))
        tile.paste(im, (0, 0))
        d = ImageDraw.Draw(tile)
        d.text((4, th + 2), label[:38], fill=(235, 235, 235))
        deck(d, 0, th + 18, held, tw)
        if rms and 0 <= frame < len(rms):
            lv = min(1.0, rms[frame] / 4000.0)
            d.rectangle([150, th + 22, 150 + int(84 * lv), th + 30], fill=(120, 220, 255))
            d.text((150, th + 32), f"snd {int(rms[frame])}", fill=(150, 150, 190))
        tiles.append(tile)
    if not tiles:
        return None
    cols = min(5, len(tiles))
    rows = (len(tiles) + cols - 1) // cols
    tw, th = tiles[0].size
    out = Image.new("RGB", (cols * (tw + 4), rows * (th + 4)), (10, 8, 18))
    for i, t in enumerate(tiles):
        out.paste(t, ((i % cols) * (tw + 4), (i // cols) * (th + 4)))
    out.save(dest)
    return dest


# ----------------------------------------------------------------------------- commands

def start(argv):
    import argparse
    ap = argparse.ArgumentParser(prog="playtest.py start")
    ap.add_argument("game", choices=sorted(TITLES))
    ap.add_argument("--name", default="main")
    ap.add_argument("--keep-saves", action="store_true", help="reuse the session's saves")
    ap.add_argument("--save", action="append", default=[], help="FILE=TEXT written into the data folder first")
    ap.add_argument("--seed", default="1")
    ap.add_argument("--fast", action="store_true", help="the menu's speed setting (-fast)")
    ap.add_argument("--eight", action="store_true", help="let the stick report diagonals")
    ap.add_argument("--window", action="store_true", help="the upright PC window instead of the cabinet framebuffer")
    a = ap.parse_args(argv)
    subprocess.check_call(["make", "-s", "TARGET=pc"], cwd=ROOT)
    d = sdir(a.name)
    if (d / "sock").exists():
        try:
            call(a.name, [], 0, stop=True)
        except OSError:
            pass
        time.sleep(0.3)
    keep = None
    if a.keep_saves and (d / "data").exists():
        keep = {p.name: p.read_bytes() for p in (d / "data").iterdir() if p.is_file()}
    shutil.rmtree(d, ignore_errors=True)
    (d / "data").mkdir(parents=True)
    (d / "frames").mkdir()
    for k, v in (keep or {}).items():
        (d / "data" / k).write_bytes(v)
    for item in a.save:
        fname, _, text = item.partition("=")
        (d / "data" / fname).write_text(text.replace("\\n", "\n"))
    env = {
        "SDL_VIDEODRIVER": "offscreen" if a.game == "orb" else "dummy",
        "SDL_AUDIODRIVER": "dummy",
        "CAB_CONTROL": "1",
        "CAB_SEED": a.seed,
        "CAB_AUDIO_WAV": str(d / "audio"),
        "CAB_SCALE": "1",
    }
    if not a.window:
        env["CAB_RAW_FB"] = "1"
    if not a.eight:
        env["CAB_FOURWAY"] = "1"
    meta = {"game": a.game, "args": ["-fast"] if a.fast else [], "env": env, "batch": 0, "log_at": 0,
            "replay": [], "held": []}
    (d / "session.json").write_text(json.dumps(meta))
    subprocess.Popen([sys.executable, __file__, "_serve", a.name], start_new_session=True,
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=open(d / "server.log", "w"))
    for _ in range(100):
        if (d / "sock").exists():
            break
        time.sleep(0.05)
    r = call(a.name, ["sync"], 1)
    print(f"session {a.name}: {a.game} ({TITLES[a.game]}) in {d}")
    print("  " + " / ".join(r["lines"][-1:]))


def parse_ready(line):
    m = re.match(r"ready (\d+) ([^|]*)\|(.*)", line)
    if not m:
        return None
    return int(m.group(1)), m.group(2), set(m.group(3).split())


def do(argv):
    name = "main"
    if argv and argv[0] == "--name":
        name, argv = argv[1], argv[2:]
    text = " ".join(argv)
    d = sdir(name)
    meta = json.loads((d / "session.json").read_text())
    meta["batch"] += 1
    batch = meta["batch"]
    shots = []
    state = {"frame": None, "title": "", "held": set(meta.get("held", [])), "alive": True}
    replay = meta["replay"]

    def run(cmds, readies):
        r = call(name, cmds, readies)
        for line in r["lines"]:
            p = parse_ready(line)
            if p:
                state["frame"], state["title"], state["held"] = p
            elif line.startswith("err"):
                print("  game:", line)
        state["alive"] = r["alive"]
        return r

    def frame_now():
        if state["frame"] is None:
            run(["sync"], 1)
        return state["frame"]

    def step(n):
        run([f"step {n}"], 1)

    def set_button(b, down):
        b = b.upper()
        if b not in BUTTONS:
            raise SystemExit(f"no button {b}; the deck has {' '.join(sorted(BUTTONS))}")
        replay.append(f"{frame_now()} {'down' if down else 'up'} {b}")
        run([f"{'down' if down else 'up'} {b}", "sync"], 1)

    def log_since():
        try:
            with open(d / "game.log", "rb") as f:
                f.seek(meta["log_at"])
                data = f.read()
                meta["log_at"] += len(data)
            return data.decode(errors="replace").splitlines()
        except OSError:
            return []

    start_frame = frame_now()
    start_title = state["title"]
    ops = [o.strip() for o in re.split(r"[;\n]", text) if o.strip()]
    for op in ops:
        if not state["alive"]:
            print("  the game has exited")
            break
        w = op.split()
        cmd = w[0].lower()
        if cmd == "tap":
            # A hand lets go before it presses again: the release gets two frames of its own.
            n = int(w[2]) if len(w) > 2 else 4
            set_button(w[1], True)
            step(n)
            set_button(w[1], False)
            step(2)
        elif cmd == "hold":
            set_button(w[1], True)
            step(int(w[2]))
            set_button(w[1], False)
        elif cmd == "press":
            set_button(w[1], True)
        elif cmd == "release":
            if len(w) > 1:
                set_button(w[1], False)
            else:
                for b in sorted(state["held"]):
                    replay.append(f"{frame_now()} up {b}")
                run(["release", "sync"], 1)
        elif cmd == "wait":
            step(int(w[1]))
        elif cmd == "look":
            label = " ".join(w[1:])
            f = frame_now() + 1
            meta["pics"] = meta.get("pics", 0) + 1
            path = d / "frames" / f"p{meta['pics']:05d}-{re.sub(r'[^A-Za-z0-9]', '', state['title'])}-{f:06d}.bmp"
            run([f"shot {path}", "step 1"], 1)
            shots.append((path, f"{f} {label}".strip(), set(state["held"]), f))
        elif cmd == "film":
            n = int(w[1])
            k = int(w[3]) if len(w) > 3 and w[2] == "every" else 6
            meta["pics"] = meta.get("pics", 0) + 1
            tmp = d / "frames" / f"film{meta['pics']:05d}"
            tmp.mkdir(exist_ok=True)
            held = set(state["held"])
            f0 = frame_now()
            run([f"every {k} {tmp}", f"step {n}", "every 0"], 1)
            for p in sorted(tmp.glob("f*.bmp")):
                fr = int(p.stem[1:])
                if f0 < fr <= f0 + n:
                    shots.append((p, f"{fr}", held, fr))
        elif cmd == "until":
            m = re.match(r"""until\s+(?:"([^"]+)"|'([^']+)'|(\S+))(?:\s+max\s+(\d+))?""", op)
            rx = re.compile(m.group(1) or m.group(2) or m.group(3))
            limit = int(m.group(4) or 1200)
            spent = 0
            hit = None
            while spent < limit and state["alive"]:
                step(5)
                spent += 5
                for line in log_since():
                    print("  log:", line)
                    if rx.search(line):
                        hit = line
                if hit:
                    break
            print(f"  until {rx.pattern!r}: {'met after ' + str(spent) + ' frames' if hit else 'not met in ' + str(spent)}")
        elif cmd == "quit":
            run(["quit"], 0)
            state["alive"] = False
        else:
            raise SystemExit(f"unknown word {cmd!r}; see python3 playtest.py --help")
    end_frame = state["frame"] if state["frame"] is not None else start_frame
    for line in log_since():
        print("  log:", line)
    if shots:
        dest = sheet(name, shots, d / f"sheet-{batch:03d}.png", state["title"] if state["title"] == start_title else None)
        if dest:
            print(f"  sheet: {dest}  ({len(shots)} pictures)")
    sounds = []
    if state["title"] != start_title:
        print("  sound: the game changed during this batch; python3 playtest.py listen has each game's notes")
    else:
        try:
            sounds = onsets(name, start_frame, (end_frame or 0) + 1, state["title"])
        except Exception as ex:
            print("  sound: could not read", ex)
    if state["title"] != start_title:
        pass
    elif sounds:
        print("  sound: " + ", ".join(f"{f}:{lab}" for f, lab, _ in sounds[:40]) + (" ..." if len(sounds) > 40 else ""))
    else:
        print("  sound: nothing started")
    held = " ".join(sorted(state["held"])) or "nothing"
    print(f"  now: frame {end_frame} in {state['title'] or '?'}, holding {held}{'' if state['alive'] else ', game exited'}")
    files = sorted(p.name + "=" + p.read_text(errors="replace").strip().replace("\n", " | ")
                   for p in (d / "data").iterdir() if p.suffix == ".sav")
    if files:
        print("  saves: " + "; ".join(files))
    meta["held"] = sorted(state["held"])
    meta["replay"] = replay
    (d / "session.json").write_text(json.dumps(meta))
    (d / "replay.cab").write_text("\n".join(replay) + "\n")


def listen(argv):
    import numpy as np
    from PIL import Image
    name = argv[1] if argv[:1] == ["--name"] else "main"
    rms, path = loudness(name)
    if not path:
        raise SystemExit("no audio yet")
    print(f"  {path}: {len(rms)} frames, peak rms {int(max(rms) if rms else 0)}")
    ons = onsets(name, 0, len(rms))
    print("  onsets: " + ", ".join(f"{f}:{lab}" for f, lab, _ in ons))
    w = wave.open(str(path))
    a = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32)
    mono = (a[0::2] + a[1::2]) * 0.5
    cols = []
    for f in range(len(mono) // 735):
        seg = mono[f * 735:f * 735 + 2048]
        if len(seg) < 2048:
            break
        spec = np.abs(np.fft.rfft(seg * np.hanning(2048)))[:600]
        cols.append(np.log1p(spec))
    if cols:
        m = np.array(cols).T[::-1]
        m = (255 * m / (m.max() + 1e-6)).astype(np.uint8)
        im = Image.fromarray(m).resize((min(2400, m.shape[1] * 2), 300))
        dest = sdir(name) / "spectrogram.png"
        im.save(dest)
        print(f"  spectrogram (time left to right, one column per frame, 0 to 13 kHz bottom to top): {dest}")


def stop(argv):
    name = argv[1] if argv[:1] == ["--name"] else "main"
    try:
        call(name, [], 0, stop=True)
        print(f"session {name} stopped")
    except OSError:
        print(f"session {name} was not running")


def perf(argv):
    game = argv[0]
    frames = int(argv[1]) if len(argv) > 1 else 600
    if not shutil.which("valgrind"):
        raise SystemExit("needs valgrind")
    tmp = SESSIONS / f"perf-{game}"
    shutil.rmtree(tmp, ignore_errors=True)
    tmp.mkdir(parents=True)
    exe = tmp / game
    subprocess.check_call(["cc", "-std=gnu99", "-O2", "-g", f"-I{ROOT}/common", f"-I{ROOT}/../build/sdl2-2.0.7-include",
                           "-o", str(exe), str(ROOT / game / f"{game}.c"), *map(str, (ROOT / "common").glob("*.c")),
                           "/lib/x86_64-linux-gnu/libSDL2-2.0.so.0", "-lm"])
    env = dict(os.environ, SDL_VIDEODRIVER="offscreen" if game == "orb" else "dummy", SDL_AUDIODRIVER="dummy",
               CAB_SCALE="1", CAB_SCRIPT="/dev/null", CAB_AUTOPLAY="1", CAB_MAX_FRAMES=str(frames))
    subprocess.run(["valgrind", "--tool=callgrind", f"--callgrind-out-file={tmp}/cg.out", str(exe)], cwd=tmp, env=env,
                   capture_output=True)
    ann = subprocess.run(["callgrind_annotate", f"{tmp}/cg.out"], capture_output=True, text=True).stdout
    total = sdl = 0
    for line in ann.splitlines():
        m = re.match(r"\s*([\d,]+) \(", line)
        if not m:
            continue
        v = int(m.group(1).replace(",", ""))
        if "PROGRAM TOTALS" in line:
            total = v
        elif "libSDL2" in line and not sdl:
            sdl = v
    own = (total - sdl) / frames / 1e6
    print(f"{game}: {own:.1f} M instructions a frame of the game's own work (SDL's PC-side copy left out)")
    print(f"  Cortex-A7 at 1.008 GHz, guessing 0.5 to 0.8 instructions a cycle: {own / 0.8:.1f} to {own / 0.5:.1f} ms of 16.7")
    print("  The top of the profile:")
    for line in [l for l in ann.splitlines() if re.match(r"\s*[\d,]+ \(", l)][1:8]:
        print("   ", line.strip()[:110])


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        print(__doc__)
        return
    cmd, rest = sys.argv[1], sys.argv[2:]
    if cmd == "_serve":
        serve(rest[0])
    elif cmd == "start":
        start(rest)
    elif cmd == "do":
        do(rest)
    elif cmd == "listen":
        listen(rest)
    elif cmd == "stop":
        stop(rest)
    elif cmd == "perf":
        perf(rest)
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
