#!/usr/bin/env python3
"""Stage one of our games onto a copy of a fresh raw dump. Does not touch the cabinet.

  games/stage_game.py --raw RAW --out DIR --game yard --bundle keep,lamp

RAW must be a rawdump from the Mask ROM session you will restore in. The default
edit points tile 10 (Dig Dug II) from The Yard at this game. Pass --from / --to
if start.sh on that dump says something else.

Prints the block list and the rk_restore.py command. Run that only after the user
has approved those exact blocks in writing. A diff of RAW in that same session
must say none before the restore.
"""
import argparse
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAMES = os.path.join(ROOT, "games")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--raw", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--game", required=True)
    ap.add_argument("--bundle", default="", help="comma-separated extra binaries to install beside --game")
    ap.add_argument("--from", dest="old", default="GAME_NAME=yard")
    ap.add_argument("--to", default=None)
    ap.add_argument("--repair", action="store_true",
                    help="fix a power-cut data filesystem in the copy before staging")
    a = ap.parse_args()
    names = [a.game] + [n for n in a.bundle.split(",") if n]
    for name in names:
        if not name.replace("_", "").replace("-", "").isalnum():
            raise SystemExit(f"game name {name!r} must be letters, digits, _ or -")
    missing = [n for n in names if not os.path.isfile(os.path.join(GAMES, "out", "cab", n))]
    if missing:
        print("building cabinet binaries:", " ".join(missing))
        subprocess.check_call(["./build.sh", "cab"], cwd=GAMES)
    puts = []
    for name in names:
        binary = os.path.join(GAMES, "out", "cab", name)
        if not os.path.isfile(binary):
            raise SystemExit(f"missing {binary}")
        puts.append(f"{binary}:Games/{name}:755")
    new = a.to or f"GAME_NAME={a.game}"
    os.makedirs(a.out, exist_ok=True)
    cmd = [
        sys.executable, os.path.join(ROOT, "tools", "data_patch.py"),
        os.path.abspath(a.raw), os.path.abspath(a.out),
        "--replace", f"start.sh:{a.old}:{new}",
    ]
    for put in puts:
        cmd.extend(["--put", put])
    if a.repair:
        cmd.append("--repair")
    print("offline patch only; the cabinet is not written", flush=True)
    subprocess.check_call(cmd)
    print("\nDiff RAW in this same Mask ROM session. It must say none. Then, only with written")
    print("approval for the blocks in BLOCKS.txt, run the restore command printed above.")


if __name__ == "__main__":
    main()
