#!/usr/bin/env python3
"""tools/cab_bench.py: every Yard game on the cabinet, measured, against a stored baseline (SYSTEM_AUDIT.md E3).

    tools/cab_bench.py                 all games, 25 s each (about 5 minutes), compared to the baseline
    tools/cab_bench.py tea garden      just these
    tools/cab_bench.py --secs 40       longer runs
    tools/cab_bench.py --save          write the results as the new baseline (captures/bench/baseline.tsv)

The games' saves are copied aside before each run and put back after it. The cabinet goes quiet first (tools/cab_quiet.sh on: Home stopped, screen black, sound muted; the kids may be
near) and is always put back afterwards, even when a run fails. Each game runs from yard.pak on the GPU runtime
the way Home starts it, with its bot playing (CAB_AUTOPLAY=1) and YARD_STATS=1 every 300 frames. A result line:
drawn fps (mean of the samples after the first), logic steps/s, picture memory (max), Lua (max), the process's
RSS, and errors in its log. Worse than the baseline by more than the margins below is reported as a regression
and the exit code is 1.
"""
import argparse
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAB = os.path.join(ROOT, "tools", "cab.sh")
QUIET = os.path.join(ROOT, "tools", "cab_quiet.sh")
BASELINE = os.path.join(ROOT, "captures", "bench", "baseline.tsv")
GAMES = ["keep", "lamp", "tea", "chest", "dig", "chomp", "kart", "safari", "tower", "garden", "bake", "band",
         "rocket"]
# A regression: fps down by more than this many frames, steps/s below this, pictures up by more than this many KB,
# or any error line.
FPS_DROP, STEPS_MIN, IMAGES_GROW = 6, 54, 400

# The bot plays for real and its game saves: every save is copied aside first and put back after, so the kids'
# progress is never touched (2026-11-23/24 runs before this did not, and wrote bot progress into their saves).
RUN = r'''c=$1; s=$2
cd /data/Games && rm -f /tmp/bench-$c.log /tmp/bench-$c.out
rm -rf /tmp/bench-saves && mkdir -p /tmp/bench-saves && cp -p /data/Games/*.sav /tmp/bench-saves/ 2>/dev/null
( YARD_PAK=/data/Games/yard.pak YARD_LOG=/tmp/bench-$c.log CAB_AUTOPLAY=1 YARD_STATS=1 \
    /data/love/run.sh /data/love/yard.love $c >/tmp/bench-$c.out 2>&1 & )
sleep $s
rss=0
for p in $(pidof love.bin); do rss=$(awk '/VmRSS/ {print $2}' /proc/$p/status); kill $p; done
sleep 1
for f in /data/Games/*.sav; do [ -f "/tmp/bench-saves/${f##*/}" ] || rm -f "$f"; done
cp -p /tmp/bench-saves/*.sav /data/Games/ 2>/dev/null && sync
echo "saves restored $(ls /tmp/bench-saves | wc -l)"
echo "rss $rss"
echo "errors $(cat /tmp/bench-$c.log /tmp/bench-$c.out 2>/dev/null | grep -ciE 'error|traceback|stumbled')"
grep -h "^stats $c " /tmp/bench-$c.out /tmp/bench-$c.log 2>/dev/null | sort -u -t' ' -k4,4n
'''


def ssh(cmd, stdin=None, timeout=120):
    return subprocess.run([CAB, "ssh", cmd], input=stdin, capture_output=True, text=True, timeout=timeout)


def measure(cid, secs):
    r = ssh(f"sh -s {cid} {secs}", stdin=RUN, timeout=secs + 60)
    out = r.stdout
    stats = re.findall(r"frame (\d+) .*?\(([\d.]+) fps drawn, ([\d.]+) steps/s.*?lua (\d+)KB images (\d+)KB", out)
    rss = re.search(r"^rss (\d+)", out, re.M)
    errs = re.search(r"^errors (\d+)", out, re.M)
    if not stats:
        return {"game": cid, "fps": 0, "steps": 0, "images": 0, "lua": 0, "rss": 0,
                "errors": int(errs.group(1)) if errs else -1, "note": (r.stderr or out).strip()[-200:]}
    later = stats[1:] or stats
    return {"game": cid,
            "fps": round(sum(float(s[1]) for s in later) / len(later), 1),
            "steps": round(min(float(s[2]) for s in later), 1),
            "lua": max(int(s[3]) for s in stats), "images": max(int(s[4]) for s in stats),
            "rss": int(rss.group(1)) // 1024 if rss else 0, "errors": int(errs.group(1)) if errs else -1}


COLS = ["game", "fps", "steps", "images", "lua", "rss", "errors"]


def read_baseline():
    if not os.path.exists(BASELINE):
        return {}
    rows = {}
    for line in open(BASELINE):
        if line.startswith("#") or not line.strip():
            continue
        f = line.rstrip("\n").split("\t")
        rows[f[0]] = dict(zip(COLS, [f[0]] + [float(x) for x in f[1:len(COLS)]]))
    return rows


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("games", nargs="*")
    ap.add_argument("--secs", type=int, default=25)
    ap.add_argument("--save", action="store_true")
    a = ap.parse_args()
    games = a.games or GAMES
    base = read_baseline()
    if subprocess.run([CAB, "host"], capture_output=True).returncode != 0:
        sys.exit("cab_bench: the cabinet is not on the network")
    subprocess.run([QUIET, "on"], check=False)
    results = []
    try:
        for cid in games:
            m = measure(cid, a.secs)
            results.append(m)
            b = base.get(cid)
            bad = []
            if m["errors"] != 0:
                bad.append(f"{m['errors']} error line(s)")
            if m["steps"] < STEPS_MIN:
                bad.append(f"logic at {m['steps']} steps/s")
            if b and m["fps"] < b["fps"] - FPS_DROP:
                bad.append(f"fps {b['fps']} -> {m['fps']}")
            if b and m["images"] > b["images"] + IMAGES_GROW:
                bad.append(f"images {int(b['images'])} -> {m['images']} KB")
            m["verdict"] = "; ".join(bad) or "ok"
            print(f"{cid:8s} fps {m['fps']:5.1f}  steps {m['steps']:5.1f}  images {m['images']:6d} KB  "
                  f"lua {m['lua']:5d} KB  rss {m['rss']:3d} MB  {m['verdict']}", flush=True)
    finally:
        subprocess.run([QUIET, "off"], check=False)
    if a.save:
        os.makedirs(os.path.dirname(BASELINE), exist_ok=True)
        rows = dict(base)
        for m in results:
            rows[m["game"]] = m
        with open(BASELINE, "w") as f:
            f.write("# tools/cab_bench.py --save: " + "\t".join(COLS) + " (fps mean, steps min, KB, KB, MB)\n")
            for g in GAMES:
                if g in rows:
                    r = rows[g]
                    f.write("\t".join(str(int(r[c]) if c in ("images", "lua", "rss", "errors") else r[c])
                                      for c in COLS) + "\n")
        print(f"baseline written: {BASELINE}")
    sys.exit(0 if all(m["verdict"] == "ok" for m in results) else 1)


if __name__ == "__main__":
    main()
