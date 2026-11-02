"""The Longhorns show's pictures (longhorns.lua). Our own drawings: no official marks.

campus_dawn, campus_day   the South Mall looking north: the Main Building and the Tower, live oaks, the lawn
"""
import math

from paint import Paint, W, H, hexc, mix, rng
from scenery import cloud, live_oak, crowd_band, night_sky

STONE = "#e9dcc0"          # the Tower's Texas limestone, in light
STONE_SH = "#bfae8c"
STONE_DK = "#9a8a6c"
ROOF = "#b5532f"
ORANGE = "#bf5700"         # burnt orange


# ------------------------------------------------------------------ sky and clouds
def sky(p, light):
    if light == "dawn":
        p.fill_rect(0, 0, W, 760, p.lin(0, 0, 0, 760, [(0, "#2a2b5e"), (0.42, "#7a5a8c"), (0.72, "#e98f6f"), (1, "#ffd39a")]))
        p.glow(640, 640, 420, "#ffb36b", 0.55, 0.7)
        p.glow(640, 650, 120, "#fff1c8", 0.9)
        p.circle(640, 655, 38, "#fff6dc")
    else:
        p.fill_rect(0, 0, W, 760, p.lin(0, 0, 0, 760, [(0, "#2f6cc4"), (0.55, "#6fa3df"), (1, "#d9ecf8")]))
        p.glow(660, 120, 360, "#fffbe6", 0.35)
    clouds(p, light)


def clouds(p, light):
    if light == "dawn":
        top, bot = hexc("#ffc9a8", 0.95), hexc("#8a6a92", 0.95)
        spots = [(140, 210, 1.0), (520, 150, 0.8), (330, 330, 0.7), (690, 300, 0.6), (80, 420, 0.55)]
    else:
        top, bot = hexc("#ffffff", 0.97), hexc("#b9cbe2", 0.97)
        spots = [(150, 190, 1.0), (560, 130, 0.85), (360, 320, 0.7), (690, 290, 0.65), (60, 430, 0.5)]
    for i, (x, y, s) in enumerate(spots):
        cloud(p, x, y, s, top, bot, 10 + i)


# ------------------------------------------------------------------ the Tower and the Main Building
def tower(p, cx, light):
    """The Tower: shaft, clock stage, the observation deck's colonnade, the temple top. Light from the right."""
    warm = light == "dawn"
    lit = mix(STONE, "#ffd2a0", 0.45) if warm else hexc(STONE)
    mid = mix(STONE_SH, "#c98f6c", 0.3) if warm else hexc(STONE_SH)
    dark = mix(STONE_DK, "#5a4a6a", 0.35) if warm else hexc(STONE_DK)
    win = hexc("#3b3a44") if not warm else hexc("#3a2f40")
    sw = 92                               # the shaft's width
    x0, x1 = cx - sw / 2, cx + sw / 2
    side = 14                             # the right face, seen a little
    top_y, base_y = 300, 600
    # the shaft: the front lit across, the right face in shade (or the sun's at dawn)
    p.fill_rect(x0, top_y, sw, base_y - top_y, p.lin(x0, 0, x1, 0, [(0, mid), (0.25, lit), (1, lit)]))
    p.poly([(x1, top_y), (x1 + side, top_y + 6), (x1 + side, base_y), (x1, base_y)],
           p.lin(x1, 0, x1 + side, 0, [(0, mid if not warm else mix(lit, "#ffb070", 0.4)), (1, dark if not warm else mid)]))
    # the corner piers and the four bays of windows between them
    p.fill_rect(x0, top_y, 10, base_y - top_y, mid)
    p.fill_rect(x1 - 10, top_y, 10, base_y - top_y, p.lin(0, 0, 0, 1, [(0, lit), (1, lit)]))
    bay_w = (sw - 20 - 3 * 6) / 4
    for b in range(4):
        bx = x0 + 10 + b * (bay_w + 6)
        p.fill_rect(bx, top_y + 14, bay_w, base_y - top_y - 30, mix(lit, mid, 0.55))
        for f in range(19):
            wy = top_y + 18 + f * 14.2
            p.fill_rect(bx + 3, wy, bay_w - 6, 8.5, win)
            p.fill_rect(bx + 3, wy + 8.5, bay_w - 6, 1.5, mix(lit, "#ffffff", 0.3))
        if b < 3:
            p.fill_rect(bx + bay_w, top_y + 14, 6, base_y - top_y - 30, lit)
    # the clock stage
    cs_y = top_y - 84
    p.fill_rect(x0 - 8, cs_y, sw + 16, 84, p.lin(x0 - 8, 0, x1 + 8, 0, [(0, mid), (0.2, lit), (1, lit)]))
    p.poly([(x1 + 8, cs_y), (x1 + 8 + side, cs_y + 6), (x1 + 8 + side, top_y), (x1 + 8, top_y)], mid if not warm else lit)
    p.fill_rect(x0 - 12, cs_y - 8, sw + 24, 10, lit)
    p.fill_rect(x0 - 12, top_y - 4, sw + 24, 8, mid)
    # the clock: a face with a gold ring, hands at the hour the light says
    ccx, ccy = cx, cs_y + 42
    p.circle(ccx, ccy, 31, mix("#c8a24a", "#8a6a2a", 0.2))
    p.circle(ccx, ccy, 27, "#f4eedd")
    for i in range(12):
        a = i * math.pi / 6
        p.line([(ccx + math.sin(a) * 23, ccy - math.cos(a) * 23), (ccx + math.sin(a) * 27, ccy - math.cos(a) * 27)], "#5b4a2a", 2.4)
    hh = 7.2 if warm else 10.5
    ah, am = hh / 12 * 2 * math.pi, (hh % 1) * 2 * math.pi
    p.line([(ccx, ccy), (ccx + math.sin(ah) * 15, ccy - math.cos(ah) * 15)], "#2b2116", 3.2)
    p.line([(ccx, ccy), (ccx + math.sin(am) * 23, ccy - math.cos(am) * 23)], "#2b2116", 2.2)
    p.circle(ccx, ccy, 3, "#c8a24a")
    # the observation deck: a balustrade, then a colonnade under a cornice
    od_y = cs_y - 62
    p.fill_rect(x0 - 16, cs_y - 14, sw + 32, 14, mid)
    for i in range(15):
        p.fill_rect(x0 - 12 + i * ((sw + 24) / 14) - 2, cs_y - 13, 4, 11, lit)
    p.fill_rect(x0 - 10, od_y, sw + 20, 48, hexc("#2c2833"))
    for i in range(7):
        colx = x0 - 8 + i * ((sw + 16) / 6) - 5
        p.fill_rect(colx, od_y, 10, 48, p.lin(colx, 0, colx + 10, 0, [(0, mid), (0.5, lit), (1, mid)]))
    p.fill_rect(x0 - 16, od_y - 12, sw + 32, 12, lit)
    p.fill_rect(x0 - 16, od_y - 2, sw + 32, 3, mid)
    # the top: a smaller stage, its columns, a low tiled roof and the lantern
    t_y = od_y - 64
    tw = sw - 24
    p.fill_rect(cx - tw / 2, t_y, tw, 52, p.lin(cx - tw / 2, 0, cx + tw / 2, 0, [(0, mid), (0.3, lit), (1, lit)]))
    for i in range(5):
        colx = cx - tw / 2 + 6 + i * ((tw - 12) / 4) - 4
        p.fill_rect(colx, t_y + 8, 8, 40, lit)
        if i < 4:
            p.fill_rect(colx + 8, t_y + 12, (tw - 12) / 4 - 8, 34, hexc("#3a3440"))
    p.fill_rect(cx - tw / 2 - 6, t_y - 8, tw + 12, 10, lit)
    roof = [(cx - tw / 2 - 4, t_y - 8), (cx + tw / 2 + 4, t_y - 8), (cx + 14, t_y - 40), (cx - 14, t_y - 40)]
    p.poly(roof, p.lin(cx - tw / 2, 0, cx + tw / 2, 0, [(0, "#8e3f24"), (0.6, ROOF), (1, "#d06a3e")]))
    for i in range(1, 6):
        yy = t_y - 8 - i * 5.5
        k = (t_y - 8 - yy) / 32
        p.line([(cx - tw / 2 - 4 + k * (tw / 2 - 10), yy), (cx + tw / 2 + 4 - k * (tw / 2 - 10), yy)], hexc("#6e2e18", 0.5), 0.8)
    p.fill_rect(cx - 9, t_y - 62, 18, 22, lit)
    p.poly([(cx - 11, t_y - 62), (cx + 11, t_y - 62), (cx, t_y - 84)], mix(ROOF, "#d4a24a", 0.4))
    p.line([(cx, t_y - 84), (cx, t_y - 104)], mix("#c8a24a", "#ffffff", 0.2), 2.4)
    p.circle(cx, t_y - 104, 3, "#d8b25a")
    if warm:
        # the sun's gold along the right edges
        p.fill_rect(x1 + side - 3, top_y + 6, 3, base_y - top_y - 6, hexc("#ffc27a", 0.8))
        p.fill_rect(x1 + 8 + side - 3, cs_y + 6, 3, 84 - 6, hexc("#ffc27a", 0.8))


def main_building(p, cx, light):
    warm = light == "dawn"
    lit = mix(STONE, "#ffd2a0", 0.4) if warm else hexc(STONE)
    mid = mix(STONE_SH, "#c98f6c", 0.3) if warm else hexc(STONE_SH)
    dark = mix(STONE_DK, "#5a4a6a", 0.4) if warm else hexc(STONE_DK)
    y0, y1 = 556, 700
    x0, x1 = 28, W - 28
    # the roofs: the long hipped red tile roof, the central block a little higher
    p.poly([(x0 - 6, y0 + 6), (x1 + 6, y0 + 6), (x1 - 30, y0 - 22), (x0 + 30, y0 - 22)],
           p.lin(0, y0 - 22, 0, y0 + 6, [(0, "#7c3420"), (1, ROOF)]))
    for i in range(1, 5):
        yy = y0 + 6 - i * 5.6
        k = i / 5
        p.line([(x0 - 6 + 36 * k, yy), (x1 + 6 - 36 * k, yy)], hexc("#5e2614", 0.45), 0.8)
    # the walls: three stories, the centre pavilion forward
    p.fill_rect(x0, y0 + 4, x1 - x0, y1 - y0 - 4, p.lin(0, y0, 0, y1, [(0, lit), (1, mid)]))
    p.fill_rect(x0, y0 + 4, x1 - x0, 10, mid)                 # the cornice's shadow
    p.fill_rect(x0 - 4, y0 + 2, x1 - x0 + 8, 5, lit)
    # the windows: arched below, square above
    n = 22
    step = (x1 - x0 - 40) / n
    for i in range(n):
        wx = x0 + 20 + i * step + step * 0.22
        ww = step * 0.56
        if abs(wx + ww / 2 - cx) < 120:
            continue
        p.fill_rect(wx, y0 + 26, ww, 18, hexc("#3a3440"))
        p.fill_rect(wx, y0 + 56, ww, 18, hexc("#3a3440"))
        p.rrect(wx, y0 + 88, ww, 34, ww / 2)
        p.src("#352f3a")
        p.cr.fill()
        p.fill_rect(wx - 2, y0 + 122, ww + 4, 3, lit)
    # the centre: a portico of columns, the inscription band above it
    pw = 230
    px0 = cx - pw / 2
    p.fill_rect(px0 - 10, y0 - 6, pw + 20, y1 - y0 + 6, p.lin(0, y0, 0, y1, [(0, lit), (1, mid)]))
    p.fill_rect(px0 - 14, y0 - 12, pw + 28, 10, lit)
    p.fill_rect(px0 - 6, y0 + 6, pw + 12, 16, mid)
    p.cr.save()
    p.cr.select_font_face("serif", 0, 1)
    p.cr.set_font_size(6.4)
    p.src(mix(dark, "#000000", 0.2))
    t = "YE SHALL KNOW THE TRUTH AND THE TRUTH SHALL MAKE YOU FREE"
    ext = p.cr.text_extents(t)
    p.cr.move_to(cx - ext.width / 2, y0 + 17)
    p.cr.show_text(t)
    p.cr.restore()
    p.fill_rect(px0, y0 + 26, pw, y1 - y0 - 40, hexc("#2e2a34"))
    for i in range(7):
        colx = px0 + 6 + i * (pw - 12) / 6 - 8
        p.fill_rect(colx, y0 + 26, 16, y1 - y0 - 40, p.lin(colx, 0, colx + 16, 0, [(0, mid), (0.45, lit), (1, mid)]))
        p.fill_rect(colx - 3, y0 + 24, 22, 5, lit)
        p.fill_rect(colx - 3, y1 - 18, 22, 5, lit)
    for i in range(6):
        dx = px0 + 6 + i * (pw - 12) / 6 + 12
        p.rrect(dx, y0 + 70, (pw - 12) / 6 - 24, 50, 8)
        p.src(hexc("#f2c879", 0.35 if warm else 0.12))
        p.cr.fill()
    # the terrace and the steps down to the mall
    p.fill_rect(x0 - 10, y1 - 12, x1 - x0 + 20, 12, mid)
    for i in range(6):
        sw = pw + 40 + i * 26
        p.fill_rect(cx - sw / 2, y1 + i * 5, sw, 5, mix(lit, mid, i / 6))


# ------------------------------------------------------------------ trees, the mall
def mall(p, light):
    warm = light == "dawn"
    g0 = "#5f8a3a" if not warm else "#5a6a3e"
    g1 = "#3e6a26" if not warm else "#3a4a2e"
    p.fill_rect(0, 700, W, H - 700, p.lin(0, 700, 0, H, [(0, g0), (1, g1)]))
    # mowing stripes
    for i in range(9):
        y = 712 + i * i * 4.2
        p.fill_rect(0, y, W, 3 + i * 1.4, hexc("#ffffff", 0.035))
    # the walk, narrowing to the steps
    p.poly([(300, 731), (468, 731), (590, H), (178, H)], p.lin(0, 731, 0, H, [(0, "#e9dfc6" if not warm else "#e5c9a8"), (1, "#cfc1a0")]))
    for i in range(10):
        y = 731 + i * i * 3.3
        k = (y - 731) / (H - 731)
        p.line([(300 - 122 * k, y), (468 + 122 * k, y)], hexc("#a89878", 0.5), 1)
    # the lamps along the walk
    for side in (-1, 1):
        for i, (yy, s) in enumerate([(760, 0.5), (820, 0.7), (910, 0.95)]):
            x = 384 + side * (100 + (yy - 731) * 0.46)
            p.fill_rect(x - 1.5 * s, yy - 70 * s, 3 * s, 70 * s, "#2a2a2e")
            p.ellipse(x, yy - 74 * s, 7 * s, 9 * s, "#f6ecd2" if not warm else "#ffd9a0")
            if warm:
                p.glow(x, yy - 74 * s, 26 * s, "#ffcf8a", 0.7)


def campus(light):
    p = Paint()
    sky(p, light)
    # far trees behind the building
    for i in range(16):
        p.circle(20 + i * 50, 600 + (i % 3) * 8, 46, "#2d4a28" if light != "dawn" else "#3a3a40")
    tower(p, 384, light)
    main_building(p, 384, light)
    mall(p, light)
    live_oak(p, 70, 820, 1.05, light, 3)
    live_oak(p, 710, 830, 1.0, light, 4, flip=True)
    if light == "dawn":
        p.fill_rect(0, 0, W, H, p.lin(0, 0, 0, H, [(0, hexc("#ff9a5a", 0.0)), (1, hexc("#ff9a5a", 0.08))]))
    p.grain(0.022, 7)
    return p


PAINTS = {
    "campus_dawn": lambda: campus("dawn"),
    "campus_day": lambda: campus("day"),
}


# ------------------------------------------------------------------ the longhorn (our own drawing)
def longhorn_path(p, cx, cy, s):
    """A longhorn steer's head, front on: horns sweeping out and up at the tips, ears under them, the face
    tapering to a rounded muzzle. s: half the horns' span."""
    R = [("M", 0, -0.19),
         ("C", 0.08, -0.19, 0.15, -0.21, 0.21, -0.24),
         ("C", 0.38, -0.30, 0.62, -0.25, 0.81, -0.35),
         ("C", 0.91, -0.41, 0.97, -0.49, 1.00, -0.58),
         ("C", 1.00, -0.47, 0.96, -0.37, 0.87, -0.29),
         ("C", 0.68, -0.10, 0.44, -0.07, 0.26, -0.06),
         ("C", 0.34, -0.03, 0.37, 0.02, 0.33, 0.05),
         ("C", 0.27, 0.07, 0.21, 0.05, 0.18, 0.02),
         ("C", 0.17, 0.16, 0.145, 0.33, 0.115, 0.47),
         ("C", 0.095, 0.57, 0.055, 0.61, 0.0, 0.61)]
    cr = p.cr
    def pt(x, y, m):
        return cx + x * s * m, cy + y * s
    cr.move_to(*pt(R[0][1], R[0][2], 1))
    for c in R[1:]:
        cr.curve_to(*pt(c[1], c[2], 1), *pt(c[3], c[4], 1), *pt(c[5], c[6], 1))
    # the left half: the same, mirrored, back up to the top
    L = list(reversed(R))
    for i in range(len(L) - 1):
        c, prev = L[i], L[i + 1]
        cr.curve_to(*pt(c[3], c[4], -1), *pt(c[1], c[2], -1), *pt(prev[-2], prev[-1], -1))
    cr.close_path()


def longhorn(p, cx, cy, s, glow=True):
    if glow:
        p.glow(cx, cy - 0.1 * s, 1.15 * s, "#ff7a1a", 0.32, 0.55)
    # a soft shadow, the head, then light on the upper edges (a bevel)
    sh = p.layer()
    longhorn_path(sh, cx + 0.01 * s, cy + 0.025 * s, s)
    sh.src(hexc("#000000", 0.45))
    sh.cr.fill()
    p.composite(sh, blur=0.012 * s)
    longhorn_path(p, cx, cy, s)
    p.src(p.lin(0, cy - 0.6 * s, 0, cy + 0.6 * s, [(0, "#ff8a2a"), (0.45, ORANGE), (1, "#8a3c00")]))
    p.cr.fill_preserve()
    hl = p.layer()
    longhorn_path(hl, cx, cy - 0.012 * s, s)
    hl.src(hexc("#ffd0a0", 0.55))
    hl.cr.fill()
    cut = p.layer()
    longhorn_path(cut, cx, cy + 0.006 * s, s)
    cut.src("#000000")
    cut.cr.fill()
    hl.composite(cut, op=9)                                 # DEST_OUT: only a sliver along the top edges
    p.composite(hl, blur=0.003 * s)
    # the brow and the nose's line, faint
    p.line([(cx, cy - 0.12 * s), (cx, cy + 0.46 * s)], hexc("#6a2e00", 0.25), 0.012 * s)


def open_screen():
    p = Paint()
    p.fill_rect(0, 0, W, H, p.lin(0, 0, 0, H, [(0, "#1a0b05"), (0.55, "#3a1606"), (1, "#5a2408")]))
    p.glow(384, 420, 520, "#ff6a10", 0.28, 0.8)
    # a few rays behind
    for i in range(14):
        a = i / 14 * 2 * math.pi
        p.poly([(384, 420), (384 + math.cos(a - 0.05) * 900, 420 + math.sin(a - 0.05) * 900),
                (384 + math.cos(a + 0.05) * 900, 420 + math.sin(a + 0.05) * 900)], hexc("#ff8a2a", 0.035))
    longhorn(p, 384, 420, 330)
    p.grain(0.02, 3)
    return p


# ------------------------------------------------------------------ the Tower at night
def tower_night(mode):
    """mode: "dark" (unlit, the Hex Rally's night), "win" (an orange top over a white shaft), "one" (all orange,
    the 1 in the windows)."""
    p = Paint()
    night_sky(p)
    cx = 384
    orange_top = mode in ("win", "one")
    shaft_orange = mode == "one"
    # light pouring off it
    if mode != "dark":
        p.glow(cx, 230, 360, "#ff7a1a", 0.35 if mode == "one" else 0.22, 1.6)
    dim = mode == "dark"
    top_c = "#ff8c2a" if orange_top else ("#5c5a66" if dim else STONE)
    top_sh = "#c25a10" if orange_top else ("#3e3c48" if dim else STONE_SH)
    sh_c = "#ff8c2a" if shaft_orange else ("#fff6e6" if mode == "win" else "#4a4854")
    sh_sh = "#c25a10" if shaft_orange else ("#d8cfc0" if mode == "win" else "#34323e")
    sw, x0, x1, top_y, base_y = 92, cx - 46, cx + 46, 300, 640
    win = "#ffe9b0" if mode != "dark" else "#1a1822"
    p.fill_rect(x0, top_y, sw, base_y - top_y, p.lin(x0, 0, x1, 0, [(0, sh_sh), (0.3, sh_c), (1, sh_c)]))
    p.poly([(x1, top_y), (x1 + 14, top_y + 6), (x1 + 14, base_y), (x1, base_y)], sh_sh)
    bay_w = (sw - 20 - 18) / 4
    for b in range(4):
        bx = x0 + 10 + b * (bay_w + 6)
        p.fill_rect(bx, top_y + 14, bay_w, base_y - top_y - 30, mix(sh_c, sh_sh, 0.5))
        for f in range(21):
            wy = top_y + 18 + f * 14.2
            lit = (mode == "one" and b in (1, 2) and 0 < f < 20) or (mode == "dark" and (f * 7 + b * 3) % 11 == 0)
            p.fill_rect(bx + 3, wy, bay_w - 6, 8.5, "#fff2c8" if lit else mix(win, sh_sh, 0.7 if mode != "dark" else 0))
    if mode == "one":
        # the 1: the two middle bays lit, a foot at the bottom, a flag at the top
        p.fill_rect(x0 + 10 + bay_w + 6 - 2, top_y + 16, bay_w * 2 + 10, base_y - top_y - 34, hexc("#fff4d0", 0.92))
        p.fill_rect(x0 + 6, base_y - 34, sw - 12, 16, hexc("#fff4d0", 0.92))
        p.poly([(x0 + 10 + bay_w + 4, top_y + 16), (x0 + 6, top_y + 52), (x0 + 6, top_y + 70), (x0 + 10 + bay_w + 4, top_y + 44)],
               hexc("#fff4d0", 0.92))
        p.glow(cx, 470, 180, "#fff0c0", 0.25, 1.6)
    # the top stack, as by day but in its light
    cs_y = top_y - 84
    p.fill_rect(x0 - 8, cs_y, sw + 16, 84, p.lin(x0, 0, x1, 0, [(0, top_sh), (0.3, top_c), (1, top_c)]))
    p.fill_rect(x0 - 12, cs_y - 8, sw + 24, 10, top_c)
    ccx, ccy = cx, cs_y + 42
    p.circle(ccx, ccy, 31, "#c8a24a" if not dim else "#5a5040")
    p.circle(ccx, ccy, 27, "#fff3d6" if not dim else "#6c6656")
    p.line([(ccx, ccy), (ccx + 13, ccy + 4)], "#2b2116", 3)
    p.line([(ccx, ccy), (ccx - 2, ccy - 22)], "#2b2116", 2.2)
    od_y = cs_y - 62
    p.fill_rect(x0 - 16, cs_y - 14, sw + 32, 14, top_sh)
    p.fill_rect(x0 - 10, od_y, sw + 20, 48, "#2a1608" if orange_top else "#16141c")
    for i in range(7):
        colx = x0 - 8 + i * ((sw + 16) / 6) - 5
        p.fill_rect(colx, od_y, 10, 48, p.lin(colx, 0, colx + 10, 0, [(0, top_sh), (0.5, top_c), (1, top_sh)]))
    p.fill_rect(x0 - 16, od_y - 12, sw + 32, 12, top_c)
    t_y = od_y - 64
    tw = sw - 24
    p.fill_rect(cx - tw / 2, t_y, tw, 52, p.lin(cx - tw / 2, 0, cx + tw / 2, 0, [(0, top_sh), (0.3, top_c), (1, top_c)]))
    for i in range(5):
        colx = cx - tw / 2 + 6 + i * ((tw - 12) / 4) - 4
        if i < 4:
            p.fill_rect(colx + 8, t_y + 12, (tw - 12) / 4 - 8, 34, "#2a1608" if orange_top else "#16141c")
    p.fill_rect(cx - tw / 2 - 6, t_y - 8, tw + 12, 10, top_c)
    p.poly([(cx - tw / 2 - 4, t_y - 8), (cx + tw / 2 + 4, t_y - 8), (cx + 14, t_y - 40), (cx - 14, t_y - 40)],
           "#a04a20" if not dim else "#4a2a24")
    p.fill_rect(cx - 9, t_y - 62, 18, 22, top_c)
    p.poly([(cx - 11, t_y - 62), (cx + 11, t_y - 62), (cx, t_y - 84)], "#c07a3a" if not dim else "#4a3a30")
    p.line([(cx, t_y - 84), (cx, t_y - 104)], "#d8b25a", 2.4)
    if orange_top:
        p.glow(cx, cs_y - 20, 140, "#ffa040", 0.35, 1.2)
    # the Main Building, lit from below (or dark)
    y0, y1 = 590, 720
    mb = "#c9a77e" if mode != "dark" else "#2c2a34"
    p.fill_rect(30, y0, W - 60, y1 - y0, p.lin(0, y0, 0, y1, [(0, mix(mb, "#000000", 0.2)), (1, mb)]))
    p.poly([(24, y0 + 4), (W - 24, y0 + 4), (W - 54, y0 - 22), (54, y0 - 22)], "#5a2618" if mode != "dark" else "#24161a")
    for i in range(22):
        wx = 50 + i * 31
        if abs(wx - cx) < 120:
            continue
        lit = mode != "dark" and (i * 5) % 7 < 3 or (mode == "dark" and i % 9 == 0)
        p.fill_rect(wx, y0 + 20, 14, 16, "#ffd890" if lit else "#1c1820")
        p.rrect(wx, y0 + 64, 14, 30, 7)
        p.src("#ffcf80" if lit else "#1c1820")
        p.cr.fill()
    pw = 230
    p.fill_rect(cx - pw / 2, y0 - 8, pw, y1 - y0 + 8, mb)
    p.fill_rect(cx - pw / 2 + 6, y0 + 24, pw - 12, y1 - y0 - 40, "#ffd07a" if mode != "dark" else "#141218")
    for i in range(7):
        colx = cx - pw / 2 + 6 + i * (pw - 12) / 6 - 8
        p.fill_rect(colx, y0 + 24, 16, y1 - y0 - 40, mix(mb, "#ffffff", 0.15))
    # live oaks, black against it
    for (x, s, fl) in ((30, 0.85, False), (740, 0.8, True)):
        sil = p.layer()
        live_oak(sil, x, 860, s, "day", 30 + x, fl)
        data = sil.surf
        cr = sil.cr
        cr.save()
        cr.identity_matrix()
        cr.set_operator(5)                                  # ATOP: everything the tree is, made dark
        cr.set_source_rgba(0.03, 0.03, 0.05, 1)
        cr.paint()
        cr.restore()
        p.composite(sil)
    # the South Mall, dark, and a soft orange on the lawn
    p.fill_rect(0, 720, W, H - 720, p.lin(0, 720, 0, H, [(0, "#0c100c"), (1, "#050705")]))
    if mode != "dark":
        p.glow(cx, 740, 300, "#ff7a1a", 0.12, 0.35)
    p.grain(0.018, 9)
    return p


PAINTS.update({
    "open": open_screen,
    "tower_dark": lambda: tower_night("dark"),
    "tower_win": lambda: tower_night("win"),
    "tower_one": lambda: tower_night("one"),
})


# ------------------------------------------------------------------ the stadium, across the field from the sideline
def stadium_day():
    p = Paint()
    p.fill_rect(0, 0, W, 330, p.lin(0, 0, 0, 330, [(0, "#2f6cc4"), (1, "#bcd8f2")]))
    for i, (x, y, s) in enumerate([(130, 90, 0.8), (520, 60, 0.7), (680, 160, 0.5)]):
        cloud(p, x, y, s, hexc("#ffffff", 0.95), hexc("#b9cbe2", 0.95), 40 + i)
    # the far side: the upper deck and the suites, light towers above
    for lx in (60, 708):
        p.fill_rect(lx - 4, 60, 8, 200, "#8a8d96")
        p.fill_rect(lx - 34, 46, 68, 34, "#3c3f48")
        for i in range(4):
            for j in range(2):
                p.fill_rect(lx - 30 + i * 16, 50 + j * 15, 12, 11, "#f4f6ff")
    p.fill_rect(0, 196, W, 70, p.lin(0, 196, 0, 266, [(0, "#d4cec4"), (1, "#a8a29a")]))      # the suites' face
    for i in range(32):
        p.fill_rect(8 + i * 24, 214, 18, 16, "#2c3a4c")
        p.fill_rect(8 + i * 24, 214, 18, 4, hexc("#9fc4e8", 0.6))
    p.fill_rect(0, 190, W, 8, "#bf5700")
    p.cr.save()
    p.cr.select_font_face("sans", 0, 1)
    p.cr.set_font_size(16)
    p.src("#ffffff")
    t = "DARRELL K ROYAL - TEXAS MEMORIAL STADIUM"
    e = p.cr.text_extents(t)
    p.cr.move_to(W / 2 - e.width / 2, 252)
    p.cr.show_text(t)
    p.cr.restore()
    # the stands: an upper bowl, a walkway, the lower bowl down to the wall
    p.fill_rect(0, 266, W, 340, "#3e3a44")
    crowd_band(p, 0, 270, W, 380, 7, 16, 0.85, 0.85)
    p.fill_rect(0, 382, W, 12, "#2a2830")
    p.fill_rect(0, 392, W, 4, "#bf5700")
    crowd_band(p, 0, 396, W, 590, 8, 22, 0.88, 1.0)
    # the aisles
    for i in range(7):
        x = 50 + i * 112
        p.poly([(x - 3, 270), (x + 3, 270), (x + 5, 590), (x - 5, 590)], hexc("#d8d2c8", 0.55))
    # the wall and the sideline
    p.fill_rect(0, 590, W, 22, p.lin(0, 590, 0, 612, [(0, "#bf5700"), (1, "#8a3e00")]))
    p.cr.save()
    p.cr.select_font_face("sans", 0, 1)
    p.cr.set_font_size(14)
    p.src("#ffffff")
    for i, t in enumerate(["HOOK 'EM", "TEXAS FOOTBALL", "THE EYES OF TEXAS", "HOOK 'EM"]):
        p.cr.move_to(30 + i * 200, 606)
        p.cr.show_text(t)
    p.cr.restore()
    # the field: perspective, the yard lines converging away
    gy0 = 612
    p.fill_rect(0, gy0, W, H - gy0, p.lin(0, gy0, 0, H, [(0, "#3c7a2e"), (1, "#2e6a22")]))
    vx, vy = 384, -900                                       # where the yard lines meet
    def at(x_near, y):                                       # a yard line's x at height y
        k = (y - vy) / (H - vy)
        return vx + (x_near - vx) * k
    for i in range(-8, 9):
        xn = 384 + i * 150
        # mowing: alternate shades between lines
        if i % 2 == 0:
            p.poly([(at(xn, gy0), gy0), (at(xn + 150, gy0), gy0), (at(xn + 150, H), H), (at(xn, H), H)], hexc("#ffffff", 0.045))
        p.poly([(at(xn - 2.5, gy0), gy0), (at(xn + 2.5, gy0), gy0), (at(xn + 3.5, H), H), (at(xn - 3.5, H), H)], hexc("#ffffff", 0.85))
        # hash marks between
        for j in range(1, 5):
            xm = xn + j * 30
            for yy in (680, 840):
                p.line([(at(xm, yy - 8), yy - 8), (at(xm, yy + 8), yy + 8)], hexc("#ffffff", 0.8), 2)
    # the sideline and the numbers
    p.fill_rect(0, 618, W, 5, hexc("#ffffff", 0.9))
    p.cr.save()
    p.cr.select_font_face("serif", 0, 1)
    for i, n in ((-2, "30"), (-1, "40"), (0, "50"), (1, "40"), (2, "30")):
        xn = 384 + i * 150 * 2 / 2
        x = at(384 + i * 300, 760)
        p.cr.set_font_size(52)
        p.src(hexc("#ffffff", 0.88))
        e = p.cr.text_extents(n)
        p.cr.move_to(x - e.width / 2, 790)
        p.cr.show_text(n)
    p.cr.restore()
    # the longhorn at midfield, laid on the grass
    p.cr.save()
    p.cr.translate(384, 920)
    p.cr.scale(1.0, 0.42)
    longhorn(p, 0, 0, 150, glow=False)
    p.cr.restore()
    p.grain(0.02, 11)
    return p


PAINTS["stadium_day"] = stadium_day


# ------------------------------------------------------------------ the field from above (the drive scrolls it)
FIELD_YD = 14                       # pixels a yard, as longhorns.lua's drive
FIELD_TOP = 400                     # beyond the far end zone's back line: the sideline, the wall (the camera goes there)


def field_y(yd):
    """Where yard line yd (0: our goal line, 100: theirs; the end zones -10..0 and 100..110) is in the picture."""
    return FIELD_TOP + (110 - yd) * FIELD_YD


def numeral(p, x, y, text, size, rot):
    cr = p.cr
    cr.save()
    cr.translate(x, y)
    cr.rotate(rot)
    cr.select_font_face("serif", 0, 1)
    cr.set_font_size(size)
    e = cr.text_extents(text)
    cr.move_to(-e.width / 2 - e.x_bearing, e.height / 2)
    p.src(hexc("#ffffff", 0.92))
    cr.show_text(text)
    cr.restore()


def field_long():
    h = field_y(-10) + FIELD_TOP
    p = Paint(W, h)
    p.fill_rect(0, 0, W, h, "#2f6e26")
    # beyond the end lines: the turf apron, a stripe, then the wall with its banner
    for (y0, y1, wall_at_top) in ((0, field_y(110), True), (field_y(-10), h, False)):
        p.fill_rect(0, y0, W, y1 - y0, "#27601f")
        wy = y0 + 60 if wall_at_top else y1 - 120
        p.fill_rect(0, wy, W, 60, p.lin(0, wy, 0, wy + 60, [(0, "#8a3e00"), (1, "#bf5700")]))
        p.cr.save()
        p.cr.select_font_face("sans", 0, 1)
        p.cr.set_font_size(26)
        p.src("#ffffff")
        for i, t in enumerate(["HOOK 'EM", "TEXAS FIGHT", "HOOK 'EM"]):
            p.cr.move_to(40 + i * 260, wy + 40)
            p.cr.show_text(t)
        p.cr.restore()
        p.fill_rect(0, wy - 60 if wall_at_top else wy + 60, W, 60, "#3a3440")
    # mowing: a shade every five yards
    for yd in range(-10, 110, 5):
        if (yd // 5) % 2 == 0:
            p.fill_rect(0, field_y(yd + 5), W, 5 * FIELD_YD, hexc("#ffffff", 0.05))
    # the end zones
    for (a, b, word, col) in ((100, 110, "TEXAS", "#bf5700"), (-10, 0, "LONGHORNS", "#bf5700")):
        y0, y1 = field_y(b), field_y(a)
        p.fill_rect(12, y0, W - 24, y1 - y0, col)
        for i in range(-10, 40):
            x = i * 26
            p.poly([(x, y0), (x + 10, y0), (x + 10 + (y1 - y0) * 0.6, y1), (x + (y1 - y0) * 0.6, y1)], hexc("#000000", 0.06))
        cr = p.cr
        cr.save()
        cr.select_font_face("serif", 0, 1)
        cr.set_font_size(96 if word == "TEXAS" else 78)
        e = cr.text_extents(word)
        ty = (y0 + y1) / 2 + e.height / 2
        if word == "LONGHORNS":
            cr.translate(W / 2, (y0 + y1) / 2)
            cr.rotate(math.pi)
            cr.translate(-W / 2, -(y0 + y1) / 2)
        p.src(hexc("#000000", 0.25))
        cr.move_to(W / 2 - e.width / 2 - e.x_bearing + 3, ty + 3)
        cr.show_text(word)
        p.src("#ffffff")
        cr.move_to(W / 2 - e.width / 2 - e.x_bearing, ty)
        cr.show_text(word)
        cr.restore()
    # the lines: sidelines, goal lines, every five yards; hashes every yard
    white = hexc("#ffffff", 0.9)
    p.fill_rect(8, field_y(110), 6, field_y(-10) - field_y(110), white)
    p.fill_rect(W - 14, field_y(110), 6, field_y(-10) - field_y(110), white)
    for yd in range(0, 101, 5):
        p.fill_rect(12, field_y(yd) - 2, W - 24, 4 if yd % 10 == 0 else 3, white)
    for yd in range(1, 100):
        y = field_y(yd)
        for x in (26, 300, 468, W - 26):
            p.fill_rect(x - 7, y - 1, 14, 2, white)
    p.fill_rect(12, field_y(110) - 3, W - 24, 5, white)
    p.fill_rect(12, field_y(-10) - 2, W - 24, 5, white)
    # the numbers, turned to face the sidelines, with the arrows toward the nearer goal
    for yd in range(10, 100, 10):
        n = yd if yd <= 50 else 100 - yd
        t = f"{n // 10} {n % 10}"
        y = field_y(yd)
        numeral(p, 82, y, t, 44, math.pi / 2)
        numeral(p, W - 82, y, t, 44, -math.pi / 2)
        if yd != 50:
            d = 1 if yd > 50 else -1                         # the arrow points at the nearer goal
            for x in (82 + 14, W - 82 - 14):
                p.poly([(x - 14 if x < W / 2 else x + 14, y - d * 44), (x - 20 if x < W / 2 else x + 8, y - d * 36),
                        (x - 8 if x < W / 2 else x + 20, y - d * 36)], white)
    # the longhorn at midfield
    longhorn(p, W / 2, field_y(50) + 20, 170)
    # the goal posts, from above: the crossbar and the two uprights' shadows
    for yd, d in ((110, -1), (-10, 1)):
        y = field_y(yd) + d * 4
        p.fill_rect(W / 2 - 66, y - 3, 132, 6, "#f2d22a")
    p.grain(0.025, 13)
    return p


PAINTS["field_long"] = field_long


# ------------------------------------------------------------------ the crowd, close (Hook 'em)
def fan_close(p, x, y, s, r):
    """A fan in the stands, close: shoulders in the shirt, a head (a cap or a cowboy hat sometimes), an arm up."""
    shirt = "#e86a10" if r.random() < 0.7 else ("#f4f1ea" if r.random() < 0.8 else "#2a2a30")
    skin = ["#f0c9a8", "#c99572", "#8a5a3c", "#f6d8c0", "#6a4430"][r.randrange(5)]
    hair = ["#2a1c14", "#5a3a20", "#b08a50", "#111111", "#7a4020"][r.randrange(5)]
    # shoulders
    p.fill_path([("M", x - 13 * s, y + 6 * s), ("C", x - 13 * s, y - 8 * s, x - 7 * s, y - 12 * s, x, y - 12 * s),
                 ("C", x + 7 * s, y - 12 * s, x + 13 * s, y - 8 * s, x + 13 * s, y + 6 * s), ("Z",)],
                p.lin(x - 13 * s, 0, x + 13 * s, 0, [(0, mix(shirt, "#000000", 0.25)), (0.5, shirt), (1, mix(shirt, "#000000", 0.15))]))
    # an arm up: Hook 'em, or just a fist
    if r.random() < 0.3:
        ax = x + (9 if r.random() < 0.5 else -9) * s
        p.fill_rect(ax - 2 * s, y - 34 * s, 4 * s, 24 * s, skin)
        p.circle(ax, y - 34 * s, 3.2 * s, skin)
        if r.random() < 0.7:
            p.fill_rect(ax - 2.4 * s, y - 43 * s, 1.6 * s, 8 * s, skin)
            p.fill_rect(ax + 1.0 * s, y - 42 * s, 1.6 * s, 7 * s, skin)
    # the head
    p.ellipse(x, y - 17 * s, 5.6 * s, 6.4 * s, skin)
    k = r.random()
    if k < 0.18:                                             # a cowboy hat
        p.ellipse(x, y - 21 * s, 10 * s, 2.6 * s, "#e8d6b0" if r.random() < 0.6 else "#3a2a20")
        p.fill_rect(x - 5 * s, y - 28 * s, 10 * s, 7 * s, "#e8d6b0" if r.random() < 0.6 else "#3a2a20")
    elif k < 0.4:                                            # a cap
        p.fill_path([("M", x - 6 * s, y - 19 * s), ("C", x - 6 * s, y - 26 * s, x + 6 * s, y - 26 * s, x + 6 * s, y - 19 * s), ("Z",)],
                    "#bf5700" if r.random() < 0.7 else "#f4f1ea")
    else:
        p.fill_path([("M", x - 5.8 * s, y - 18 * s), ("C", x - 6 * s, y - 25 * s, x + 6 * s, y - 25 * s, x + 5.8 * s, y - 18 * s), ("Z",)], hair)


def crowd_close():
    p = Paint()
    p.fill_rect(0, 0, W, H, p.lin(0, 0, 0, H, [(0, "#0a0a14"), (0.15, "#1a1622"), (0.65, "#2a1a18"), (1, "#120a08")]))
    # the light banks up on the rim, their glare
    for lx in (120, 384, 648):
        p.glow(lx, 50, 260, "#fff4d8", 0.35, 0.6)
        p.fill_rect(lx - 70, 30, 140, 40, "#2a2c34")
        for i in range(6):
            for j in range(2):
                p.fill_rect(lx - 64 + i * 22, 34 + j * 18, 18, 14, "#fffbe8")
    # the stands: rows of fans from the back (small) to the front (big)
    r = rng(21)
    p.fill_rect(0, 140, W, 540, "#2a2430")
    rows = 13
    for i in range(rows):
        k = i / (rows - 1)
        y = 160 + k * k * 380 + k * 120
        s = 0.75 + k * 1.15
        p.fill_rect(0, y + 4 * s, W, 6 * s, hexc("#4a4250", 0.8))
        x = -10 + r.random() * 20 * s
        while x < W + 20:
            fan_close(p, x, y, s, r)
            x += 22 * s * (0.9 + r.random() * 0.3)
    # signs held up
    for (x, y, t, col) in ((140, 330, "HOOK 'EM", "#ffffff"), (560, 300, "TEXAS FIGHT", "#ffffff"), (390, 470, "HORNS UP", "#ffffff")):
        p.fill_rect(x - 58, y - 18, 116, 34, "#bf5700")
        p.cr.save()
        p.cr.select_font_face("sans", 0, 1)
        p.cr.set_font_size(15)
        e = p.cr.text_extents(t)
        p.src(col)
        p.cr.move_to(x - e.width / 2 - e.x_bearing, y + 5)
        p.cr.show_text(t)
        p.cr.restore()
    # the rail, then the dark below where the hand comes up
    p.fill_rect(0, 676, W, 10, "#8a8d96")
    p.fill_rect(0, 686, W, H - 686, p.lin(0, 686, 0, H, [(0, "#1c120c"), (1, "#0a0604")]))
    p.glow(384, 860, 360, "#ff7a1a", 0.18, 0.6)
    p.grain(0.02, 15)
    return p


PAINTS["crowd_close"] = crowd_close


# ------------------------------------------------------------------ the State Fair and the Cotton Bowl (Red River)
def big_tex(p, x, base):
    """Big Tex, 55 feet of him: boots, jeans, a belt and buckle, a plaid western shirt, a bandana, the hat. His
    right arm (waving) is longhorns.lua's."""
    # boots and jeans
    for dx in (-26, 26):
        p.fill_rect(x + dx - 18, base - 210, 36, 180, p.lin(x + dx - 18, 0, x + dx + 18, 0, [(0, "#24345e"), (0.5, "#33467a"), (1, "#22305a")]))
        p.fill_rect(x + dx - 18, base - 210, 36, 4, "#1a2440")
        p.fill_path([("M", x + dx - 20, base - 40), ("L", x + dx + 18, base - 40), ("L", x + dx + 22, base - 8),
                     ("C", x + dx + 36, base - 8, x + dx + 40, base, x + dx + 34, base), ("L", x + dx - 20, base), ("Z",)], "#6a3a1a")
        p.fill_rect(x + dx - 20, base - 44, 38, 8, "#8a5228")
    # the shirt: plaid, tucked in, the belt
    sx0, sx1, sy0, sy1 = x - 56, x + 56, base - 390, base - 205
    p.fill_rect(sx0, sy0, sx1 - sx0, sy1 - sy0, "#c4302a", r=10)
    for i in range(9):
        p.fill_rect(sx0 + 4 + i * 13, sy0, 5, sy1 - sy0, hexc("#ffffff", 0.22))
        p.fill_rect(sx0, sy0 + 6 + i * 21, sx1 - sx0, 5, hexc("#ffffff", 0.22))
        p.fill_rect(sx0 + 9 + i * 13, sy0, 2, sy1 - sy0, hexc("#1a2a5a", 0.35))
    p.fill_rect(x - 2, sy0 + 20, 4, sy1 - sy0 - 24, hexc("#7a1a14", 0.6))
    for i in range(5):
        p.circle(x + 6, sy0 + 40 + i * 30, 2.4, "#f4ead0")
    p.fill_rect(sx0, sy1 - 14, sx1 - sx0, 16, "#3a2414")
    p.fill_rect(x - 14, sy1 - 16, 28, 20, "#d8b25a", r=4)
    # his left arm down by his side
    p.fill_rect(sx0 - 26, sy0 + 14, 30, 150, "#b82c26", r=12)
    p.circle(sx0 - 11, sy0 + 172, 15, "#e8b892")
    # the bandana, the head, the face, the hat
    p.poly([(x - 30, sy0 + 2), (x + 30, sy0 + 2), (x, sy0 + 30)], "#1f4a8a")
    p.ellipse(x, sy0 - 40, 36, 44, p.lin(x - 36, 0, x + 36, 0, [(0, "#d9a27e"), (0.5, "#f0c29c"), (1, "#d49a76")]))
    p.ellipse(x - 13, sy0 - 48, 4, 5, "#2a1a10")
    p.ellipse(x + 13, sy0 - 48, 4, 5, "#2a1a10")
    p.fill_path([("M", x - 16, sy0 - 22), ("C", x - 8, sy0 - 12, x + 8, sy0 - 12, x + 16, sy0 - 22), ("C", x + 8, sy0 - 16, x - 8, sy0 - 16, x - 16, sy0 - 22)], "#7a2a1a")
    p.ellipse(x, sy0 - 36, 5, 7, hexc("#b8805a", 0.6))
    p.ellipse(x, sy0 - 74, 88, 15, p.lin(0, sy0 - 88, 0, sy0 - 60, [(0, "#fffaf0"), (1, "#d8d0bc")]))
    p.fill_path([("M", x - 44, sy0 - 76), ("C", x - 46, sy0 - 130, x - 20, sy0 - 136, x, sy0 - 124),
                 ("C", x + 20, sy0 - 136, x + 46, sy0 - 130, x + 44, sy0 - 76), ("Z",)],
                p.lin(x - 44, 0, x + 44, 0, [(0, "#e2dccb"), (0.5, "#fffcf4"), (1, "#d6cfbc")]))
    p.fill_rect(x - 44, sy0 - 92, 88, 10, "#3a2a20")


def fair():
    p = Paint()
    p.fill_rect(0, 0, W, 610, p.lin(0, 0, 0, 610, [(0, "#3d76c8"), (0.6, "#9cc0e6"), (1, "#ffe0a8")]))
    p.glow(700, 520, 380, "#ffd08a", 0.35, 0.5)
    for i, (x, y, s) in enumerate([(300, 110, 0.7), (640, 80, 0.55)]):
        cloud(p, x, y, s, hexc("#ffffff", 0.95), hexc("#d8c8c0", 0.95), 60 + i)
    # the Cotton Bowl beyond: its long Art Deco front, the name over the gate
    p.fill_rect(0, 470, W, 140, p.lin(0, 470, 0, 610, [(0, "#e9dcc0"), (1, "#c8b694")]))
    for i in range(24):
        p.fill_rect(10 + i * 32, 500, 14, 90, hexc("#a8946c", 0.55))
    p.fill_rect(0, 462, W, 12, "#bfa982")
    gx = 384
    p.fill_rect(gx - 120, 430, 240, 180, p.lin(0, 430, 0, 610, [(0, "#f0e4c8"), (1, "#cdb994")]))
    # the gate: an arch, lit inside, columns either side
    p.rrect(gx - 54, 500, 108, 110, 52)
    p.src(p.lin(0, 500, 0, 610, [(0, "#5a4a3a"), (1, "#c8a46a")]))
    p.cr.fill()
    p.rrect(gx - 40, 516, 80, 94, 38)
    p.src(p.lin(0, 516, 0, 610, [(0, "#2a2228"), (0.7, "#6a5040"), (1, "#e8c890")]))
    p.cr.fill()
    for dx in (-84, -66, 66, 84):
        p.fill_rect(gx + dx - 5, 486, 10, 124, p.lin(gx + dx - 5, 0, gx + dx + 5, 0, [(0, "#c8b28a"), (0.5, "#f4ead2"), (1, "#c8b28a")]))
    p.cr.save()
    p.cr.select_font_face("serif", 0, 1)
    p.cr.set_font_size(26)
    e = p.cr.text_extents("COTTON BOWL")
    p.src("#7a5a2a")
    p.cr.move_to(gx - e.width / 2 - e.x_bearing, 474)
    p.cr.show_text("COTTON BOWL")
    p.cr.restore()
    for i in range(5):
        p.fill_rect(gx - 110 + i * 52, 430, 8, 30, "#c8b28a")
    # the midway in front: striped tents, flags on strings
    for i, (x, col) in enumerate([(70, "#d8302a"), (230, "#2a6ad8"), (560, "#e8b020"), (720, "#2aa84a")]):
        p.poly([(x - 60, 610), (x + 60, 610), (x + 60, 570), (x, 530), (x - 60, 570)], "#f8f4ec")
        for j in range(4):
            p.poly([(x - 60 + j * 30, 570), (x - 45 + j * 30, 570), (x, 530)], col)
            p.fill_rect(x - 60 + j * 30, 570, 15, 40, col)
    r = rng(70)
    for row in range(2):
        pts = [(0, 250 + row * 90), (W, 280 + row * 80)]
        p.line(pts, hexc("#ffffff", 0.6), 1.2)
        for i in range(30):
            t = i / 29
            x = t * W
            y = 250 + row * 90 + (30 - row * 10) * t + math.sin(t * math.pi) * 24
            col = ["#d8302a", "#2a6ad8", "#e8b020", "#2aa84a", "#ffffff"][i % 5]
            p.poly([(x - 6, y), (x + 6, y), (x, y + 12)], col)
    # the Texas Star's legs and hub (the wheel turns in longhorns.lua)
    wx, wy = 600, 300
    for d in (-1, 1):
        p.poly([(wx - 6, wy), (wx + 6, wy), (wx + d * 64 + 6, 610), (wx + d * 64 - 6, 610)], "#d8dce6")
        for k in range(1, 6):
            y = wy + k * 52
            p.line([(wx + d * (k * 10.5), y), (wx - d * (k * 10.5), y + 40)], hexc("#c0c6d2", 0.8), 2)
    p.circle(wx, wy, 14, "#e8ecf4")
    p.circle(wx, wy, 6, "#8a90a0")
    # Big Tex
    big_tex(p, 170, 610)
    # the stands: Texas's half orange, OU's half crimson, split at the fifty
    p.fill_rect(0, 610, W, 150, "#3a3440")
    crowd_band(p, 0, 616, W // 2, 756, 71, 14, 0.9, 1.0, ("#e86a10", "#f4f1ea"))
    crowd_band(p, W // 2, 616, W, 756, 72, 14, 0.9, 1.0, ("#9a1a24", "#efe6d0"))
    p.fill_rect(W // 2 - 2, 610, 4, 150, "#ffffff")
    p.fill_rect(0, 756, W, 10, p.lin(0, 0, W, 0, [(0, "#bf5700"), (0.5, "#bf5700"), (0.5001, "#841617"), (1, "#841617")]))
    # the field
    p.fill_rect(0, 766, W, H - 766, p.lin(0, 766, 0, H, [(0, "#3c7a2e"), (1, "#2c6620")]))
    for i in range(9):
        x = 384 + (i - 4) * 110
        p.poly([(x - 2, 766), (x + 2, 766), (x + (x - 384) * 0.5 + 3, H), (x + (x - 384) * 0.5 - 3, H)], hexc("#ffffff", 0.7))
    p.grain(0.02, 73)
    return p


PAINTS["fair"] = fair


# ------------------------------------------------------------------ the Rose Bowl, Jan 4, 2006: the field near the goal line
RB_YD, RB_GOAL = 24, 300                         # as longhorns.lua's replay: px a yard, the goal line's y


def rose(p, x, y, s):
    """A rose: layered petals in red, a stem and two leaves."""
    p.line([(x, y + 18 * s), (x - 4 * s, y + 70 * s)], "#2a6a2a", 5 * s)
    for d in (-1, 1):
        p.ellipse(x + d * 14 * s - 2 * s, y + 46 * s, 14 * s, 7 * s, "#2f7a30")
    for i, (r, c) in enumerate([(26, "#7a0e18"), (21, "#a8142a"), (15, "#c8243a"), (9, "#e04058")]):
        for k in range(5):
            a = k / 5 * 2 * math.pi + i * 0.6
            p.ellipse(x + math.cos(a) * r * 0.35 * s, y + math.sin(a) * r * 0.3 * s, r * 0.62 * s, r * 0.5 * s, c)


def rosebowl():
    p = Paint()
    p.fill_rect(0, 0, W, H, p.lin(0, 0, 0, H, [(0, "#2a6420"), (1, "#2f7026")]))
    for yd in range(-10, 32, 5):
        if (yd // 5) % 2 == 0:
            p.fill_rect(0, RB_GOAL + yd * RB_YD, W, 5 * RB_YD, hexc("#ffffff", 0.045))
    # beyond the end line, then the end zone with its name
    p.fill_rect(0, 0, W, RB_GOAL - 10 * RB_YD, "#244e1c")
    ez0, ez1 = RB_GOAL - 10 * RB_YD, RB_GOAL
    p.fill_rect(10, ez0, W - 20, ez1 - ez0, p.lin(0, ez0, 0, ez1, [(0, "#6a0c18"), (1, "#8a1424")]))
    p.cr.save()
    p.cr.select_font_face("serif", 0, 1)
    p.cr.set_font_size(78)
    e = p.cr.text_extents("ROSE BOWL")
    p.src(hexc("#000000", 0.3))
    p.cr.move_to(W / 2 - e.width / 2 - e.x_bearing + 3, (ez0 + ez1) / 2 + e.height / 2 + 3)
    p.cr.show_text("ROSE BOWL")
    p.src("#f6d36a")
    p.cr.move_to(W / 2 - e.width / 2 - e.x_bearing, (ez0 + ez1) / 2 + e.height / 2)
    p.cr.show_text("ROSE BOWL")
    p.cr.restore()
    rose(p, 90, (ez0 + ez1) / 2 - 20, 0.9)
    rose(p, W - 90, (ez0 + ez1) / 2 - 20, 0.9)
    white = hexc("#ffffff", 0.9)
    p.fill_rect(8, ez0, 6, H - ez0, white)
    p.fill_rect(W - 14, ez0, 6, H - ez0, white)
    p.fill_rect(10, ez0 - 3, W - 20, 6, white)
    p.fill_rect(10, RB_GOAL - 3, W - 20, 6, white)
    for yd in range(5, 31, 5):
        p.fill_rect(10, RB_GOAL + yd * RB_YD - 2, W - 20, 4, white)
    for yd in range(1, 31):
        y = RB_GOAL + yd * RB_YD
        for x in (24, 300, 468, W - 24):
            p.fill_rect(x - 7, y - 1, 14, 2, white)
    # the two-point line, the numbers
    p.fill_rect(380, RB_GOAL + 3 * RB_YD - 1, 8, 3, white)
    for yd in (10, 20, 30):
        numeral(p, 70, RB_GOAL + yd * RB_YD, f"{yd // 10} 0", 42, math.pi / 2)
        numeral(p, W - 70, RB_GOAL + yd * RB_YD, f"{yd // 10} 0", 42, -math.pi / 2)
    # the goal post's shadow, the pylons
    p.fill_rect(W / 2 - 60, ez0 + 4, 120, 6, "#f2d22a")
    for x in (10, W - 20):
        p.fill_rect(x, RB_GOAL - 8, 10, 10, "#ff8c1a")
        p.fill_rect(x, ez0 - 2, 10, 10, "#ff8c1a")
    p.grain(0.025, 81)
    return p


PAINTS["rosebowl"] = rosebowl


# ------------------------------------------------------------------ the stadium's wall (Legends: the banners hang on it)
def legends_wall():
    p = Paint()
    p.fill_rect(0, 0, W, 200, p.lin(0, 0, 0, 200, [(0, "#2f6cc4"), (1, "#a8ccef")]))
    cloud(p, 160, 70, 0.6, hexc("#ffffff", 0.95), hexc("#b9cbe2", 0.95), 90)
    cloud(p, 600, 50, 0.5, hexc("#ffffff", 0.95), hexc("#b9cbe2", 0.95), 91)
    # flags on the parapet
    for x, kind in ((140, "us"), (628, "tx")):
        p.fill_rect(x - 2, 40, 4, 130, "#b8bcc6")
        if kind == "tx":
            p.fill_rect(x + 2, 46, 26, 40, "#1a3a8a")
            p.fill_rect(x + 28, 46, 44, 20, "#ffffff")
            p.fill_rect(x + 28, 66, 44, 20, "#c4202a")
        else:
            for i in range(7):
                p.fill_rect(x + 2, 46 + i * 40 / 7, 70, 40 / 7, "#c4202a" if i % 2 == 0 else "#ffffff")
            p.fill_rect(x + 2, 46, 30, 23, "#1a3a8a")
    # the wall: limestone courses, a cornice, arches with depth
    p.fill_rect(0, 160, W, 520, p.lin(0, 160, 0, 680, [(0, "#efe4ca"), (1, "#d4c6a4")]))
    r = rng(92)
    for row in range(26):
        y = 176 + row * 20
        p.fill_rect(0, y, W, 1.2, hexc("#a8946c", 0.45))
        off = (row % 2) * 24
        for i in range(17):
            x = off + i * 48
            p.fill_rect(x, y - 20, 1.2, 20, hexc("#a8946c", 0.35))
            if r.random() < 0.3:
                p.fill_rect(x + 1, y - 19, 46, 18, hexc("#ffffff" if r.random() < 0.5 else "#8a7a5a", 0.06))
    p.fill_rect(0, 152, W, 18, "#d8c8a4")
    p.fill_rect(0, 166, W, 6, "#a8946c")
    for i in range(8):
        x = 10 + i * 96
        p.rrect(x, 180, 70, 64, 35)
        p.src(p.lin(0, 180, 0, 244, [(0, "#3a3440"), (1, "#6a5e5a")]))
        p.cr.fill()
        p.rrect(x - 4, 176, 78, 6, 3)
        p.src("#c8b48c")
        p.cr.fill()
    # the inscription band under the arches
    p.fill_rect(0, 250, W, 4, "#bf5700")
    p.grain(0.02, 93)
    return p


PAINTS["legends_wall"] = legends_wall
