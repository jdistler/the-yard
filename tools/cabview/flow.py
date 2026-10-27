#!/usr/bin/env python3
"""tools/cabview/flow.py: drive the cabinet like a player and check what the screen shows.

    tools/cabview/flow.py yard       stock menu -> Dig Dug II -> GPU yard -> hold 1P+2P -> stock menu again
    tools/cabview/flow.py home       stock menu -> Dig Dug II -> GPU yard -> Home preview
    tools/cabview/flow.py classic    stock menu -> Pac-Man -> hold 1P 5 s (the stock exit) -> stock menu again

Every step saves a screenshot (captures/screen/flow-<name>-<time>/NN-step.png, the player's view) and checks
it: not black, no magenta blocks (unpainted GPU memory, 2026-10-27), and the step's own expectation. It uses
tools/cab.sh (shot, key, hold) and so sees the scanned-out framebuffer, not what a program meant to draw.
Takes the screen: do not run it while someone is playing. Exit code 1 when a check fails.
Nothing is written on the cabinet (its /tmp is RAM: 2026-10-27, test screenshots kept there got the stock
menu killed for memory).
"""
import os
import subprocess
import sys
import time

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
CAB = os.path.join(ROOT, "tools", "cab.sh")
failures = []


def cab(*args, capture=True):
    r = subprocess.run([CAB, *args], capture_output=capture, text=True)
    return r.stdout.strip() if capture else ""


class Flow:
    def __init__(self, name):
        self.dir = os.path.join(ROOT, "captures", "screen", f"flow-{name}-{time.strftime('%Y%m%d-%H%M%S')}")
        os.makedirs(self.dir)
        self.n = 0

    def shot(self, step):
        self.n += 1
        path = os.path.join(self.dir, f"{self.n:02d}-{step}.png")
        cab("shot", path)
        return path

    def check(self, ok, what):
        print(("  ok   " if ok else "  FAIL ") + what, flush=True)
        if not ok:
            failures.append(what)
        return ok


def stats(path):
    """(lit, magenta, mean): the share of non-black pixels, of pure-magenta pixels, and the mean color."""
    im = Image.open(path).convert("RGB").resize((192, 256))
    px = list(im.getdata())
    lit = sum(1 for p in px if max(p) > 24) / len(px)
    magenta = sum(1 for r, g, b in px if r > 240 and b > 240 and g < 70) / len(px)
    mean = tuple(sum(p[i] for p in px) // len(px) for i in range(3))
    return lit, magenta, mean


def look(f, step, expect=None, why=""):
    """Screenshot, then the generic checks and the step's own (expect(stats) -> bool)."""
    p = f.shot(step)
    lit, magenta, mean = stats(p)
    f.check(lit > 0.05, f"{step}: the screen shows a picture ({lit:.0%} lit) [{os.path.basename(p)}]")
    f.check(magenta < 0.002, f"{step}: no magenta blocks ({magenta:.1%})")
    if expect:
        f.check(expect(lit, magenta, mean), f"{step}: {why} (mean color {mean})")
    return p


def stock_menu_look(lit, magenta, mean):
    return mean[2] > 120 and mean[2] > mean[0] + 40  # the stock menu is mostly sky blue


def yard_look(lit, magenta, mean):
    return mean[2] > mean[1] and mean[0] < 90 and mean[2] < 120  # The Yard: a dark purple night


def procs():
    return cab("ssh", "ps | grep -E '[l]ove.bin|[s]tart.sh|/usr/bin/[g]ame'")


def wait_for(cond, timeout, every=1.0):
    t0 = time.time()
    while time.time() - t0 < timeout:
        if cond():
            return True
        time.sleep(every)
    return False


def wait_screen(f, step, cond, timeout, why):
    """Screenshots every 2 s until cond(stats) holds (the last one is kept and checked)."""
    t0 = time.time()
    while True:
        p = os.path.join(f.dir, "wait.png")
        cab("shot", p)
        st = stats(p)
        if cond(*st) or time.time() - t0 > timeout:
            os.remove(p)
            return look(f, step, cond, why)
        time.sleep(2)


def started(name):
    return cab("ssh", f"ps | grep -c '[s]tart.sh {name} '") not in ("", "0")


def fresh_stock_menu(f):
    """A known start: the stock menu started again (the highlight on Pac-Man), past its intro and the
    copyright page (presses during those are lost)."""
    cab("stop")
    cab("menu")
    wait_screen(f, "stock-menu", stock_menu_look, 45, "the stock menu is on screen")
    time.sleep(1)


def into_gpu_yard(f):
    for k in ("down", "down", "down", "right"):
        cab("key", k)
        time.sleep(0.5)
    look(f, "dig-dug-ii-highlighted", stock_menu_look, "still the stock menu")
    cab("key", "low")
    time.sleep(1.5)
    look(f, "controls-page")
    cab("key", "1p")
    f.check(wait_for(lambda: started("10"), 10), "the stock menu ran tile 10 (Dig Dug II: The Yard)")
    ok = wait_for(lambda: "love.bin" in procs(), 20)
    f.check(ok, "GPU yard started (love.bin running)")
    wait_screen(f, "gpu-yard", yard_look, 15, "The Yard's menu is on screen")


def leave_yard(f):
    cab("hold", "1p", "2p", "2500")
    ok = wait_for(lambda: "love.bin" not in procs(), 15)
    f.check(ok, "GPU yard quit on a 1P+2P hold")
    wait_for(lambda: "game" in procs(), 15)
    wait_screen(f, "stock-menu-after-yard", stock_menu_look, 30, "the stock menu came back visibly")
    left = cab("ssh", "ls /tmp/.minigui_freeze 2>/dev/null")
    f.check(not left, "no leftover /tmp/.minigui_freeze")


def flow_yard():
    f = Flow("yard")
    fresh_stock_menu(f)
    into_gpu_yard(f)
    for k in ("down", "down"):
        cab("key", k)
        time.sleep(0.4)
    look(f, "gpu-yard-moved", yard_look, "The Yard's menu after moving the highlight")
    leave_yard(f)
    return f


def flow_home():
    f = Flow("home")
    fresh_stock_menu(f)
    into_gpu_yard(f)
    # The Yard opens on the last row used (yard.sav "best N", from 0). Rows by order: Keep, Lamp, Orb, Tea,
    # Chest, then Home preview (94), so it is row 5.
    out = cab("ssh", "cat /data/Games/yard.sav")
    row = int(out.split()[1]) if out.startswith("best ") else 0
    for _ in range(abs(5 - row)):
        cab("key", "down" if row < 5 else "up")
        time.sleep(0.4)
    time.sleep(0.4)
    look(f, "yard-home-row", yard_look, f"The Yard, Home preview highlighted (from row {row})")
    cab("key", "low")
    f.check(wait_for(lambda: "homeloop" in cab("ssh", "ps | grep [h]omeloop"), 15), "Home preview started (homeloop)")
    time.sleep(8)
    p = look(f, "home")
    for k in ("down", "right", "down"):
        cab("key", k)
        time.sleep(0.8)
        look(f, "home-" + k)
    # Leave the preview: its last card is "BACK TO THE YARD"; 1P+2P held leaves too, with a meter.
    held = subprocess.Popen([CAB, "hold", "1p", "2p", "2500"], stdout=subprocess.DEVNULL)
    time.sleep(0.75)  # the hold is 1 s; ssh takes a moment to start it
    p = f.shot("home-hold-meter")
    im = Image.open(p).convert("RGB").crop((100, 470, 668, 570)).resize((114, 20))
    bar = sum(1 for r, g, b in im.getdata() if r > 230 and 170 < g < 225 and b < 130)
    f.check(bar > 20, f"home-hold-meter: the hold meter's bar is filling ({bar} px) [{os.path.basename(p)}]")
    held.wait()
    f.check(wait_for(lambda: "homeloop" not in cab("ssh", "ps | grep [h]omeloop"), 15),
            "Home preview quit on a 1P+2P hold")
    wait_screen(f, "yard-after-home", yard_look, 20, "back in The Yard")
    leave_yard(f)
    return f


def flow_classic():
    f = Flow("classic")
    fresh_stock_menu(f)
    cab("key", "low")
    time.sleep(1.5)
    look(f, "controls-page")
    cab("key", "1p")
    f.check(wait_for(lambda: started("0"), 10), "the stock menu ran tile 0 (Pac-Man)")
    time.sleep(6)
    look(f, "pac-man")
    t0 = time.time()
    cab("hold", "1p", "5500")
    f.check(wait_for(lambda: not started("0"), 10), f"Pac-Man quit on a 5.5 s 1P hold ({time.time() - t0:.1f} s)")
    alive = "game" in procs()
    f.check(alive, "the stock menu is still running (not killed for memory)")
    wait_screen(f, "stock-menu-after-pac-man", stock_menu_look, 20, "the stock menu came back visibly")
    return f


def main():
    which = sys.argv[1] if len(sys.argv) > 1 else "yard"
    f = {"yard": flow_yard, "home": flow_home, "classic": flow_classic}[which]()
    print(f"screens: {f.dir}")
    print(f"== {len(failures)} failed ==")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
