#!/usr/bin/env python3
"""tools/home_bench.py: Home measured on the cabinet (HOME_REFACTOR.md CP1, the G5 gate).

    tools/home_bench.py            run, compare with captures/home_tour/cabinet_baseline.tsv
    tools/home_bench.py --save     run and store the result as the baseline

Home is stopped (and the sound muted, tools/cab_quiet.sh), then started directly, twice: cold (the kernel's file
cache dropped first, as after power-on) and warm (as after a game). A script drives it through every section,
the attract and the night (HOME_SCRIPT, HOME_IDLE, HOME_NIGHT). Its state, stats and log are copies in /tmp, so
nothing the family uses is touched. Read from its log: startup (main.lua to the first frame), frames per second
by scene, hitches over 100 ms, texture memory, errors; and its RSS at the end. Home, the sound and homeloop are
put back afterwards, always.
"""
import os
import re
import statistics
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAB = os.path.join(ROOT, "tools", "cab.sh")
QUIET = os.path.join(ROOT, "tools", "cab_quiet.sh")
BASELINE = os.path.join(ROOT, "captures", "home_tour", "cabinet_baseline.tsv")

# ~70 s: sections right and left, down the Yard's cards, then hands off: attract at 6 s idle, night at 20 s.
SCRIPT = "\n".join(
    [f"{120 + 45 * i} press right" for i in range(7)] +
    [f"{450 + 45 * i} press left" for i in range(4)] +
    [f"{650 + 30 * i} press down" for i in range(8)] +
    ["4300 quit"]) + "\n"

RUN = r'''mode=$1
cp /data/home/state /tmp/hb.state 2>/dev/null; cp /mnt/sdcard/partycade/stats.tsv /tmp/hb.stats 2>/dev/null
rm -f /tmp/hb.log /tmp/hb.req
[ "$mode" = cold ] && { sync; echo 3 > /proc/sys/vm/drop_caches; }
cd /data/home
TZ=CST6CDT,M3.2.0,M11.1.0 HOME_SCRIPT=/tmp/hb.script HOME_LOG=/tmp/hb.log HOME_STATE=/tmp/hb.state \
  HOME_STATS=/tmp/hb.stats HOME_REQ=/tmp/hb.req HOME_ART=/data/home/art HOME_GAMES=/data/Games HOME_SKIP_INTRO=1 \
  HOME_IDLE=6 HOME_NIGHT=20 HOME_FPS_EVERY=120 /data/love/run.sh /data/home/home.love >/dev/null 2>&1 &
pid=$!
rss=0
while kill -0 $pid 2>/dev/null; do
  for p in $(pidof love.bin); do r=$(awk '/VmRSS/ {print $2}' /proc/$p/status 2>/dev/null); [ -n "$r" ] && [ "$r" -gt "$rss" ] && rss=$r; done
  sleep 2
done
echo "rss_max $rss"
cat /tmp/hb.log
'''


def ssh(cmd, stdin=None, timeout=300):
    return subprocess.run([CAB, "ssh", cmd], input=stdin, capture_output=True, text=True, timeout=timeout)


def measure(mode):
    ssh("cat > /tmp/hb.script", stdin=SCRIPT)
    out = ssh(f"sh -s {mode}", stdin=RUN, timeout=240).stdout
    m = re.search(r"startup: main\.lua ([\d.]+).*first frame ([\d.]+)", out)
    startup = round(float(m.group(2)) - float(m.group(1)), 2) if m else -1
    fps = {}
    for sc, f in re.findall(r"frames: ([\d.]+) fps .*?scene (\w+)", out):
        pass
    for f, sc in re.findall(r"frames: ([\d.]+) fps \([\d.]+ ms\), scene (\w+)", out):
        fps.setdefault(sc, []).append(float(f))
    tex = [int(x) for x in re.findall(r"textures (\d+) KB", out)]
    hitches = [int(x) for x in re.findall(r"hitch (\d+) ms", out)]
    rss = re.search(r"rss_max (\d+)", out)
    return {"mode": mode, "startup_s": startup,
            "menu_fps": round(statistics.median(fps["menu"]), 1) if fps.get("menu") else 0,
            "attract_fps": round(statistics.median(fps["attract"]), 1) if fps.get("attract") else 0,
            "night_fps": round(statistics.median(fps["night"]), 1) if fps.get("night") else 0,
            "textures_kb": max(tex) if tex else 0,
            "hitches_100ms": sum(1 for h in hitches if h >= 100), "worst_hitch_ms": max(hitches) if hitches else 0,
            "rss_mb": int(rss.group(1)) // 1024 if rss else 0,
            "errors": len(re.findall(r"ERROR", out))}


COLS = ["mode", "startup_s", "menu_fps", "attract_fps", "night_fps", "textures_kb", "hitches_100ms",
        "worst_hitch_ms", "rss_mb", "errors"]


def main():
    if subprocess.run([CAB, "host"], capture_output=True).returncode != 0:
        sys.exit("home_bench: the cabinet is not on the network")
    subprocess.run([QUIET, "on"], check=False)
    res = []
    try:
        for mode in ("cold", "warm"):
            r = measure(mode)
            res.append(r)
            print("  ".join(f"{c} {r[c]}" for c in COLS), flush=True)
    finally:
        subprocess.run([QUIET, "off"], check=False)
    base = {}
    if os.path.exists(BASELINE):
        for line in open(BASELINE):
            if line.startswith("#") or not line.strip():
                continue
            f = line.rstrip("\n").split("\t")
            base[f[0]] = dict(zip(COLS, f))
    if "--save" in sys.argv:
        os.makedirs(os.path.dirname(BASELINE), exist_ok=True)
        with open(BASELINE, "w") as f:
            f.write("# tools/home_bench.py --save: " + "\t".join(COLS) + "\n")
            for r in res:
                f.write("\t".join(str(r[c]) for c in COLS) + "\n")
        print(f"baseline written: {BASELINE}")
        return
    bad = []
    for r in res:
        b = base.get(r["mode"])
        if r["errors"]:
            bad.append(f"{r['mode']}: {r['errors']} ERROR line(s)")
        if not b:
            continue
        if r["startup_s"] > float(b["startup_s"]) + 0.3:
            bad.append(f"{r['mode']} startup {b['startup_s']} -> {r['startup_s']} s")
        for k in ("menu_fps", "attract_fps", "night_fps"):
            if r[k] < float(b[k]) - 3:
                bad.append(f"{r['mode']} {k} {b[k]} -> {r[k]}")
        if r["textures_kb"] > int(b["textures_kb"]) + 1024:
            bad.append(f"{r['mode']} textures {b['textures_kb']} -> {r['textures_kb']} KB")
        if r["rss_mb"] > int(b["rss_mb"]) + 3:
            bad.append(f"{r['mode']} rss {b['rss_mb']} -> {r['rss_mb']} MB")
    print("no regression against the baseline" if not bad else "REGRESSION: " + "; ".join(bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
