"""The Longhorns show's pictures (longhorns.lua). Our own drawings: no official marks.

campus_dawn, campus_day   the South Mall looking north: the Main Building and the Tower, live oaks, the lawn
"""
import math

from paint import Paint, W, H, hexc, mix, rng

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


def cloud(p, x, y, s, top, bottom, seed):
    """A cumulus: puffs heaped in a dome over a soft, flattish base; lit from above, shaded under."""
    r = rng(seed)
    sh = p.layer()
    lay = p.layer()
    puffs = []
    for i in range(22):
        u = r.random() * 2 - 1
        px = x + u * 120 * s
        h = (1 - u * u) ** 0.8
        py = y - h * 34 * s * r.random() + r.random() * 6 * s
        pr = (16 + h * 26 + r.random() * 10) * s
        puffs.append((px, py, pr))
    for (px, py, pr) in puffs:
        sh.circle(px, py + pr * 0.3, pr * 0.85, hexc(bottom[:3] if isinstance(bottom, tuple) else bottom, 0.35))
    for (px, py, pr) in sorted(puffs, key=lambda q: q[1]):
        lay.circle(px, py, pr * 0.92, lay.lin(0, py - pr, 0, py + pr * 0.6, [(0, top), (0.55, top), (1, mix(top, bottom, 0.55))]))
    # the base: cut flat-ish and soft
    cut = p.layer()
    cut.composite(sh, blur=3)
    cut.composite(lay, blur=1.2)
    cut.cr.set_operator(0)                                  # CLEAR below the base line, feathered
    cut.cr.rectangle(0, y + 26 * s, W, H)
    cut.cr.fill()
    p.composite(cut, blur=1.5)


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
def live_oak(p, x, y, s, light, seed, flip=False):
    """A live oak: a heavy, crooked trunk, great limbs reaching out low and wide and visible under a broad, flat
    crown of leaf clumps (dark beneath, lit on top toward the light), with sky through it here and there."""
    r = rng(seed)
    warm = light == "dawn"
    d = -1 if flip else 1
    bark = "#35281f" if not warm else "#2f2228"
    bark_lt = "#6a5140" if not warm else "#7a5038"
    dk, md, lt, hi = (("#1b2e17", "#2b4621", "#44662d", "#6f9244") if not warm else
                      ("#1a2220", "#29352a", "#4a5534", "#a08a52"))
    cx0, cy0, rx, ry = x, y - 205 * s, 250 * s, 70 * s       # the crown: broad and flat
    tree = p.layer()
    # the great limbs, out from the trunk to the crown's edges, tapering
    for i in range(6):
        u = -1 + i / 5 * 2
        ex = x + u * rx * 0.95
        ey = cy0 + 20 * s + abs(u) * 18 * s
        w0 = (12 - abs(u) * 4) * s
        mx, my = x + (ex - x) * 0.35, y - 120 * s - (1 - abs(u)) * 30 * s
        tree.cr.move_to(x - w0, y - 100 * s)
        tree.cr.curve_to(mx - w0, my + 10 * s, ex - 10 * s * u, ey + 12 * s, ex, ey)
        tree.cr.curve_to(ex + 2 * s, ey - 4 * s, mx + w0, my - 6 * s, x + w0, y - 104 * s)
        tree.src(tree.lin(0, ey, 0, y - 100 * s, [(0, bark), (1, bark_lt)]))
        tree.cr.fill()
    # the trunk: thick, flaring at the root, lit on the light side
    tree.fill_path([("M", x - 34 * s, y + 6 * s), ("C", x - 16 * s, y - 24 * s, x - 22 * s, y - 70 * s, x - 20 * s, y - 112 * s),
                    ("L", x + 20 * s, y - 116 * s), ("C", x + 18 * s, y - 70 * s, x + 14 * s, y - 24 * s, x + 38 * s, y + 6 * s), ("Z",)],
                   tree.lin(x - 34 * s, 0, x + 38 * s, 0, [(0, bark), (0.62 if not flip else 0.38, bark_lt), (1, bark)]))
    # the crown, in clumps (each a few overlapping lumps), shadow to light
    def clump(lay, px, py, size, col):
        for _ in range(5):
            lay.ellipse(px + (r.random() - 0.5) * size * 1.6, py + (r.random() - 0.5) * size * 0.7,
                        size * (0.5 + r.random() * 0.5) * 1.3, size * (0.5 + r.random() * 0.5) * 0.85, col)
    def spot():
        while True:
            u, v = r.random() * 2 - 1, r.random() * 2 - 1
            if u * u + v * v <= 1:
                return cx0 + u * rx, cy0 + v * ry
    base = p.layer()
    for _ in range(70):
        px, py = spot()
        clump(base, px, py + 8 * s, 22 * s, dk)
    mid = p.layer()
    for _ in range(80):
        px, py = spot()
        if py < cy0 + ry * 0.45:
            clump(mid, px, py, 17 * s, md)
    lit = p.layer()
    for _ in range(60):
        px, py = spot()
        side = (px - cx0) / rx * d
        if py < cy0 + ry * 0.05 and side > -0.5:
            clump(lit, px, py - 4 * s, 12 * s, lt)
    top = p.layer()
    for _ in range(30):
        px, py = spot()
        side = (px - cx0) / rx * d
        if py < cy0 - ry * 0.35 and side > -0.2:
            clump(top, px, py - 6 * s, 7 * s, hi)
    for lay, b in ((base, 0.8), (mid, 0.6), (lit, 0.5), (top, 0.4)):
        tree.composite(lay, blur=b)
    # sky through the leaves
    for _ in range(10):
        px, py = spot()
        if cy0 - ry * 0.4 < py < cy0 + ry * 0.4:
            tree.cr.save()
            tree.cr.set_operator(0)
            tree.ellipse(px, py, (4 + r.random() * 6) * s, (2.5 + r.random() * 3) * s, "#000000")
            tree.cr.restore()
    sh = p.layer()
    sh.ellipse(x + 30 * s * d, y + 8 * s, 240 * s, 24 * s, hexc("#0f2210", 0.5))
    p.composite(sh, blur=10)
    p.composite(tree, blur=0.25)


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
