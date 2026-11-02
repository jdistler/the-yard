#!/usr/bin/env python3
"""Paint the shows' pictures (tools/art/<show>.py) into games/out/show-art/<show>/<name>.{png,pkm}.

  ~/.venvs/partycade-art/bin/python tools/show_art.py [SHOW[:NAME,...] ...] [--preview DIR]

Each painter module has PAINTS = {name: function returning a Paint}. The .pkm is ETC1 (what the cabinet loads,
from the SD card: cart push copies them to /mnt/sdcard/partycade/art); --preview writes what the ETC1 decodes
to, beside the PNG, for checking. Needs pycairo, numpy, Pillow, etcpak (the venv: SDCARD.md / STATUS.md).
"""
import argparse
import importlib
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "art"))
OUT = os.path.join(ROOT, "games", "out", "show-art")

from paint import decode_pkm  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("shows", nargs="*")
    ap.add_argument("--preview", action="store_true")
    a = ap.parse_args()
    shows = a.shows or sorted(f[:-3] for f in os.listdir(os.path.join(ROOT, "tools", "art"))
                              if f.endswith(".py") and f != "paint.py")
    for spec in shows:
        sid, _, names = spec.partition(":")
        mod = importlib.import_module(sid)
        want = names.split(",") if names else list(mod.PAINTS)
        for name in want:
            t0 = time.time()
            p = mod.PAINTS[name]()
            base = os.path.join(OUT, sid, name)
            alpha = name in getattr(mod, "ALPHA", ())
            p.save(base, alpha=alpha)
            if a.preview and not alpha:
                decode_pkm(base + ".pkm").save(base + ".etc1.png")
            size = os.path.getsize(base + (".png" if alpha else ".pkm"))
            print(f"{sid}/{name}: {size // 1024} KB ({time.time() - t0:.1f} s)")


if __name__ == "__main__":
    main()
