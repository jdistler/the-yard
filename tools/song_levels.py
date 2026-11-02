#!/usr/bin/env python3
"""Even out the songs' loudness: songcheck.lua renders each, then each song's gain moves it most of the way
(60%) toward one level, never past a peak of 0.95. Writes games/love/home/song_levels.lua (songs.lua applies it).
Sound effects are left alone.

  tools/song_levels.py
"""
import os, re, subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOME = os.path.join(ROOT, "games", "love", "home")
LUAJIT = os.path.join(ROOT, "games", "out", "love-x86", "luajit")
TARGET, PULL, PEAK = 0.19, 0.6, 0.95


def main():
    # measured without the levels (HOME_SONG_LEVELS=0)
    out = subprocess.run([LUAJIT, os.path.join(HOME, "songcheck.lua")], capture_output=True, text=True,
                         env=dict(os.environ, HOME_SONG_LEVELS="0")).stdout
    sfx = set(re.findall(r"^\s{2}(\w+) = ", open(os.path.join(HOME, "songs.lua")).read().split("M.SFX = {", 1)[1], re.M))
    levels = {}
    for line in out.splitlines():
        m = re.match(r"^(\w+)\s+[\d.]+ s .*rms ([\d.]+)\s+peak ([\d.]+)", line)
        if not m or m.group(1) in sfx:
            continue
        name, rms, peak = m.group(1), float(m.group(2)), float(m.group(3))
        want = TARGET * (rms / TARGET) ** (1 - PULL)
        g = min(want / rms, PEAK / peak)
        if abs(g - 1) > 0.03:
            levels[name] = round(g, 3)
    with open(os.path.join(HOME, "song_levels.lua"), "w") as f:
        f.write("-- Made by tools/song_levels.py: each song's gain, to even out loudness (songs.lua applies it).\n")
        f.write("return {\n")
        for k in sorted(levels):
            f.write(f"  {k} = {levels[k]},\n")
        f.write("}\n")
    print(f"{len(levels)} songs adjusted")


if __name__ == "__main__":
    main()
