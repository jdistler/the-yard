"""Scenery the shows' painters share (tools/art): clouds, live oaks, crowds, night skies, hills, water, plants.
"""
import math

from paint import Paint, W, H, hexc, mix, rng


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


def crowd_band(p, x0, y0, x1, y1, seed, rows, fill=0.8, light=1.0, palette=None):
    """Rows of fans, smaller toward the top (further away): heads and shirts, orange and white, here and there a
    hand up."""
    r = rng(seed)
    for i in range(rows):
        k = i / max(1, rows - 1)
        y = y1 - (y1 - y0) * k
        size = 7.5 - 4.5 * k
        # the row's step
        p.fill_rect(x0, y - size * 0.6, x1 - x0, size * 0.5, hexc("#5a5560", 0.6 * light))
        x = x0 + r.random() * size
        while x < x1:
            if r.random() < fill:
                if palette:
                    shirt = palette[0] if r.random() < 0.72 else (palette[1] if r.random() < 0.85 else "#3a3a40")
                else:
                    shirt = "#e86a10" if r.random() < 0.72 else ("#f4f1ea" if r.random() < 0.85 else "#3a3a40")
                p.fill_rect(x - size * 0.45, y - size * 1.5, size * 0.9, size * 1.0, mix(shirt, "#000000", 0.15 * (1 - light)))
                skin = ["#f0c9a8", "#c99572", "#8a5a3c", "#f6d8c0", "#6a4430"][r.randrange(5)]
                p.circle(x, y - size * 1.85, size * 0.38, skin)
                if r.random() < 0.06:
                    p.fill_rect(x + size * 0.2, y - size * 3.2, size * 0.22, size * 1.2, skin)
            x += size * (1.0 + r.random() * 0.25)


def night_sky(p, seed=5):
    p.fill_rect(0, 0, W, H, p.lin(0, 0, 0, H, [(0, "#04040f"), (0.6, "#120a24"), (1, "#24122a")]))
    r = rng(seed)
    for i in range(260):
        x, y = r.random() * W, r.random() * 680
        b = r.random()
        p.circle(x, y, 0.5 + b * 1.1, hexc("#fff6e0", 0.35 + b * 0.6))




# ------------------------------------------------------------------ land
def hill_band(p, y, amp, col, seed, bottom=H, freq=1.0, top_col=None):
    """A line of hills: a smooth ridge (a few sines) at about y, filled down to bottom; lighter at its top edge."""
    r = rng(seed)
    ph = [r.random() * 6.28 for _ in range(3)]
    pts = []
    for i in range(0, 97):
        x = i * W / 96
        yy = y - amp * (0.55 * math.sin(x * 0.006 * freq + ph[0]) + 0.3 * math.sin(x * 0.017 * freq + ph[1])
                        + 0.15 * math.sin(x * 0.041 * freq + ph[2]))
        pts.append((x, yy))
    cr = p.cr
    cr.move_to(0, bottom)
    for (x, yy) in pts:
        cr.line_to(x, yy)
    cr.line_to(W, bottom)
    cr.close_path()
    p.src(p.lin(0, y - amp, 0, y + 60, [(0, top_col or col), (1, col)]) if top_col else col)
    cr.fill()
    return pts


def haze(p, y0, y1, col, a):
    """Air between us and the far hills: a band fading in toward the horizon."""
    p.fill_rect(0, y0, W, y1 - y0, p.lin(0, y0, 0, y1, [(0, hexc(col, 0)), (1, hexc(col, a))]))


def water(p, y0, y1, top, bottom, seed, glints=None, lines=60):
    """Open water: a gradient, ripple lines (thin, lighter), and a glint path under glints = (x, colour)."""
    p.fill_rect(0, y0, W, y1 - y0, p.lin(0, y0, 0, y1, [(0, top), (1, bottom)]))
    r = rng(seed)
    for i in range(lines):
        k = r.random()
        y = y0 + (y1 - y0) * k * k
        w = 20 + k * 120 * r.random()
        x = r.random() * W
        p.fill_rect(x, y, w, 1 + k * 2, hexc("#ffffff", 0.05 + 0.08 * k))
        p.fill_rect(x + 4, y + 1 + k * 2, w * 0.8, 1 + k, hexc("#000000", 0.05))
    if glints:
        gx, gc = glints
        for i in range(40):
            k = i / 40
            y = y0 + 4 + (y1 - y0) * k
            w = (8 + k * 90) * (0.5 + r.random() * 0.8)
            p.fill_rect(gx - w / 2 + (r.random() - 0.5) * 30 * k, y, w, 1.5 + k * 2.5, hexc(gc, 0.55 * (1 - k * 0.7)))


# ------------------------------------------------------------------ the sky at night
def milky_way(p, x0, y0, x1, y1, seed, width=110, bright=1.0):
    """The Milky Way from (x0, y0) to (x1, y1): a glow, dust lanes, thousands of stars thick in the band."""
    r = rng(seed)
    dx, dy = x1 - x0, y1 - y0
    ln = math.hypot(dx, dy)
    nx, ny = -dy / ln, dx / ln
    glow = p.layer()
    for i in range(70):
        t = i / 69
        cx, cy = x0 + dx * t, y0 + dy * t
        wv = width * (0.7 + 0.5 * math.sin(t * 7 + 1))
        glow.ellipse(cx, cy, wv * 1.1, wv * 0.7, hexc("#c8c0ff", 0.05 * bright))
        glow.ellipse(cx + nx * 8, cy + ny * 8, wv * 0.6, wv * 0.35, hexc("#ffe8d0", 0.06 * bright))
    p.composite(glow, blur=22)
    # dust: dark lanes along it
    dust = p.layer()
    for i in range(40):
        t = r.random()
        off = (r.random() - 0.4) * width * 0.5
        cx, cy = x0 + dx * t + nx * off, y0 + dy * t + ny * off
        dust.ellipse(cx, cy, 40 + r.random() * 50, 8 + r.random() * 10, hexc("#05040c", 0.35))
    p.composite(dust, blur=10)
    for i in range(int(5000 * bright)):
        t = r.random()
        off = r.gauss(0, width * 0.42)
        cx, cy = x0 + dx * t + nx * off, y0 + dy * t + ny * off
        b = r.random()
        p.circle(cx, cy, 0.35 + b * 0.55, hexc("#ffffff" if r.random() < 0.8 else "#ffe0c0", 0.25 + b * 0.6))


def stars(p, n, y_max, seed, big=0.03):
    r = rng(seed)
    for i in range(n):
        x, y = r.random() * W, r.random() ** 1.3 * y_max
        b = r.random()
        p.circle(x, y, 0.45 + b * 0.9, hexc("#fff8ec", 0.3 + b * 0.65))
        if r.random() < big:
            p.glow(x, y, 7, "#fff6e0", 0.6)


# ------------------------------------------------------------------ plants
def palm(p, x, y, h, lean, seed, col="#2f5a2a", trunk="#6a4a30"):
    """A palm: a curved, ringed trunk and a crown of drooping fronds (each a spine with leaflets)."""
    r = rng(seed)
    tx, ty = x + lean, y - h
    cr = p.cr
    # the trunk: a tapering curve, rings across it
    for i in range(40):
        t = i / 40
        cx = x + lean * t * t
        cy = y - h * t
        w = 11 - 5 * t
        p.ellipse(cx, cy, w, 4, mix(trunk, "#000000", 0.15 if i % 2 else 0))
    # the fronds
    for i in range(11):
        a = -math.pi * (0.05 + i / 10 * 0.9) + (r.random() - 0.5) * 0.15
        ln = 90 + r.random() * 30
        ex, ey = tx + math.cos(a) * ln, ty + math.sin(a) * ln * 0.5 + ln * 0.35
        mx, my = tx + math.cos(a) * ln * 0.5, ty + math.sin(a) * ln * 0.6
        for k in range(16):
            t = k / 16
            px = (1 - t) ** 2 * tx + 2 * (1 - t) * t * mx + t * t * ex
            py = (1 - t) ** 2 * ty + 2 * (1 - t) * t * my + t * t * ey
            leaf = 18 * (1 - t * 0.6)
            for s in (-1, 1):
                p.line([(px, py), (px + s * leaf * 0.35, py + leaf)], mix(col, "#000000", 0.25 * r.random()), 2.2)
        cr.move_to(tx, ty)
        cr.curve_to(mx, my, mx, my, ex, ey)
        cr.set_line_width(2.4)
        p.src(mix(col, "#000000", 0.3))
        cr.stroke()


def prickly_pear(p, x, y, s, seed, col="#4f7a3a"):
    r = rng(seed)
    pads = [(x, y - 26 * s, 0)]
    for i in range(5):
        bx, by, _ = pads[r.randrange(len(pads))]
        a = -math.pi / 2 + (r.random() - 0.5) * 1.6
        pads.append((bx + math.cos(a) * 34 * s, by + math.sin(a) * 30 * s, a))
    for (px, py, a) in pads:
        p.cr.save()
        p.cr.translate(px, py)
        p.cr.rotate(a + math.pi / 2)
        p.ellipse(0, 0, 16 * s, 24 * s, p.lin(-16 * s, 0, 16 * s, 0, [(0, mix(col, "#000000", 0.25)), (0.6, col), (1, mix(col, "#ffffff", 0.15))]))
        for k in range(6):
            p.circle((r.random() - 0.5) * 18 * s, (r.random() - 0.5) * 30 * s, 0.9 * s, "#e8e0b0")
        p.cr.restore()
        if r.random() < 0.4:
            p.ellipse(px, py - 26 * s, 4 * s, 5 * s, "#c8304a")


def ocotillo(p, x, y, s, seed, col="#3a4a2a"):
    r = rng(seed)
    for i in range(9):
        a = -math.pi / 2 + (i - 4) * 0.13 + (r.random() - 0.5) * 0.06
        ln = (140 + r.random() * 50) * s
        ex, ey = x + math.cos(a) * ln, y + math.sin(a) * ln
        p.line([(x, y), ((x + ex) / 2 + (r.random() - 0.5) * 8, (y + ey) / 2), (ex, ey)], col, 3 * s)
        if r.random() < 0.6:
            p.ellipse(ex, ey - 6 * s, 3 * s, 8 * s, "#e8402a")


def wildflowers(p, y0, y1, seed, n=4000, blue=0.78):
    """A field of bluebonnets (blue spikes, white tips) and Indian paintbrush (red-orange), farther ones smaller
    and denser."""
    r = rng(seed)
    pts = []
    for i in range(n):
        k = r.random() ** 0.7
        y = y0 + (y1 - y0) * k
        pts.append((r.random() * W, y, k))
    pts.sort(key=lambda q: q[1])
    for (x, y, k) in pts:
        s = 0.35 + k * 1.6
        if r.random() < blue:
            col = mix("#2a3fb0", "#4a6ae0", r.random())
            p.ellipse(x, y - 5 * s, 2.2 * s, 6 * s, col)
            p.ellipse(x, y - 11 * s, 1.4 * s, 1.8 * s, "#f4f4ff")
            p.line([(x, y), (x, y + 4 * s)], "#3a6a2a", 0.8 * s)
        else:
            col = mix("#e8401a", "#ff7a2a", r.random())
            p.ellipse(x, y - 4 * s, 2.6 * s, 5 * s, col)
            p.line([(x, y), (x, y + 4 * s)], "#3a6a2a", 0.8 * s)


def grass_tufts(p, y0, y1, seed, n=1500, col="#3c6a28"):
    r = rng(seed)
    for i in range(n):
        k = r.random()
        y = y0 + (y1 - y0) * k
        x = r.random() * W
        h = 3 + k * 10
        p.line([(x, y), (x + (r.random() - 0.5) * 4, y - h)], mix(col, "#a8c070" if r.random() < 0.3 else "#1a3014", r.random() * 0.5), 0.8 + k)


# ------------------------------------------------------------------ buildings
def windows_grid(p, x, y, w, h, cols, rows, lit, seed, glass="#2c3444", light="#ffd890", frac=0.0):
    r = rng(seed)
    cw, rh = w / cols, h / rows
    for i in range(cols):
        for j in range(rows):
            on = r.random() < frac
            p.fill_rect(x + i * cw + cw * 0.18, y + j * rh + rh * 0.2, cw * 0.64, rh * 0.6, light if on and lit else glass)
