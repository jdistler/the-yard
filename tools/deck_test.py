#!/usr/bin/env python3
"""The deck, measured: what the stick and buttons really send.

    tools/deck_test.py [SECONDS]      default 45; then, at the cabinet: each diagonal (up-left, up-right,
                                      down-right, down-left) held a second, two slow circles, two fast circles,
                                      then each button tapped as fast as you can

Reads the deck's events with the kernel's timestamps (cabctl watch, nothing on the screen) and reports:
diagonals (two directions down together: the stick is 8-way to the electronics), the shortest presses and
gaps (bounce: a switch that chatters shows presses or gaps of a few ms), and the time grid events land on
(the deck's microcontroller reports at its own cadence over the UART; that is the input latency floor).
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
secs = int(sys.argv[1]) if len(sys.argv) > 1 else 45
print(f"recording {secs} s: diagonals, circles, fast taps...", flush=True)
out = subprocess.run([os.path.join(HERE, "cab.sh"), "watch", str(secs)], capture_output=True, text=True).stdout
ev = []
for line in out.splitlines():
    f = line.split()
    if len(f) >= 4 and f[2] in ("down", "up"):
        ev.append((float(f[3]), f[1], f[2]))
if not ev:
    sys.exit("no events (nobody touched the deck?)")
DIRS = {"up", "down", "left", "right"}
held, diag, combos = set(), 0, set()
down_at, last_up, presses, gaps = {}, {}, [], []
for t, k, v in ev:
    if v == "down":
        if k in last_up:
            gaps.append(((t - last_up[k]) * 1000, k))
        down_at[k] = t
        held.add(k)
    else:
        if k in down_at:
            presses.append(((t - down_at.pop(k)) * 1000, k))
        last_up[k] = t
        held.discard(k)
    d = held & DIRS
    if len(d) > 1:
        diag += 1
        combos.add("+".join(sorted(d)))
print(f"{len(ev)} events")
print("stick:", ("8-WAY electrically: diagonals " + ", ".join(sorted(combos))) if diag else
      "never two directions at once: 4-way (gated, or the deck reports one direction)")
presses.sort()
gaps.sort()
print("shortest presses (ms):", ", ".join(f"{d:.1f} {k}" for d, k in presses[:6]))
print("shortest gaps between presses of one control (ms):", ", ".join(f"{d:.1f} {k}" for d, k in gaps[:6]))
chatter = [p for p in presses if p[0] < 12] + [g for g in gaps if g[0] < 12]
print("chatter (under 12 ms):", len(chatter), "" if not chatter else "<- the switches bounce; debounce needed")
# The grid: differences between successive events of different controls arriving in one report share a time.
ts = sorted(set(round(t * 1000, 1) for t, _, _ in ev))
steps = sorted(round(b - a, 1) for a, b in zip(ts, ts[1:]) if b - a < 60)
print("smallest distinct times between events (ms):", steps[:12])
same = sum(1 for (a, _, _), (b, _, _) in zip(ev, ev[1:]) if abs(a - b) < 0.0005)
print(f"events arriving together (same report): {same}")
