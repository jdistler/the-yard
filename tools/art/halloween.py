"""The Halloween show's pictures (halloween.lua). Each laid out under its scene's live parts (windows flicker, bats
fly, doors open, pumpkins get carved and lit, skeletons dance, the witch flies: all live).
"""
import math

from paint import Paint, W, H, hexc, mix, rng
from scenery import stars, hill_band


def sky(p, y1, stops):
    p.fill_rect(0, 0, W, y1, p.lin(0, 0, 0, y1, stops))


def label(p, x, y, text, size, col, font="serif", bold=True):
    cr = p.cr
    cr.save()
    cr.select_font_face(font, 0, 1 if bold else 0)
    cr.set_font_size(size)
    e = cr.text_extents(text)
    p.src(col)
    cr.move_to(x - e.width / 2 - e.x_bearing, y)
    cr.show_text(text)
    cr.restore()


def moon(p, x, y, r, col="#f4ecc8", glow=0.45):
    p.glow(x, y, r * 2.4, "#c8b8ff", glow * 0.6)
    p.circle(x, y, r, p.rad(x - r * 0.25, y - r * 0.25, r * 0.1, r * 1.1, [(0, mix(col, "#ffffff", 0.3)), (1, mix(col, "#a89870", 0.3))]))
    rr = rng(int(x + y))
    for i in range(10):
        a = rr.random() * 6.28
        d = rr.random() * r * 0.7
        p.circle(x + math.cos(a) * d, y + math.sin(a) * d, r * (0.06 + rr.random() * 0.12), hexc("#a89870", 0.3))


def dead_tree(p, x, base, s, col="#0a0610", seed=1):
    r = rng(seed)
    def branch(x0, y0, ang, ln, w, depth):
        x1, y1 = x0 + math.cos(ang) * ln, y0 + math.sin(ang) * ln
        p.line([(x0, y0), ((x0 + x1) / 2 + (r.random() - 0.5) * ln * 0.2, (y0 + y1) / 2), (x1, y1)], col, w)
        if depth > 0:
            for k in range(2 + (r.random() < 0.4)):
                branch(x1, y1, ang + (r.random() - 0.5) * 1.3, ln * (0.55 + r.random() * 0.2), w * 0.62, depth - 1)
    p.fill_path([("M", x - 18 * s, base), ("C", x - 8 * s, base - 60 * s, x - 10 * s, base - 120 * s, x - 6 * s, base - 170 * s),
                 ("L", x + 6 * s, base - 170 * s), ("C", x + 10 * s, base - 120 * s, x + 8 * s, base - 60 * s, x + 20 * s, base), ("Z",)], col)
    for a in (-2.2, -1.6, -1.0):
        branch(x, base - 160 * s, a, 70 * s, 7 * s, 4)


def tombstone(p, x, y, w, h, text, seed):
    r = rng(seed)
    p.fill_path([("M", x - w / 2, y), ("L", x - w / 2, y - h * 0.6), ("C", x - w / 2, y - h * 1.15, x + w / 2, y - h * 1.15, x + w / 2, y - h * 0.6),
                 ("L", x + w / 2, y), ("Z",)], p.lin(x - w / 2, 0, x + w / 2, 0, [(0, "#3a3a48"), (0.4, "#6a6a7a"), (1, "#2a2a36")]))
    for i in range(6):
        p.line([(x - w * 0.3 + r.random() * w * 0.6, y - h * r.random()), (x - w * 0.3 + r.random() * w * 0.6, y - h * r.random())],
               hexc("#1a1a22", 0.4), 1)
    if text:
        size = min(13, w * 1.6 / max(4, len(text)))
        label(p, x, y - h * 0.5, text, size, "#1a1a24")
    p.ellipse(x, y + 2, w * 0.7, 6, hexc("#000000", 0.4))
    for i in range(10):
        p.line([(x - w / 2 + r.random() * w, y), (x - w / 2 + r.random() * w + (r.random() - 0.5) * 6, y - 6 - r.random() * 8)], "#1a2a14", 1.2)


def iron_fence(p, y, col="#06040a"):
    for x in range(0, W + 24, 24):
        p.poly([(x, y), (x + 6, y - 20), (x + 12, y), (x + 12, 1024), (x, 1024)], col)
    p.fill_rect(0, y + 10, W, 6, col)


def fog(p, y, seed, a=0.25):
    lay = p.layer()
    r = rng(seed)
    for i in range(40):
        lay.ellipse(r.random() * W, y + r.random() * 60, 80 + r.random() * 120, 14 + r.random() * 16, hexc("#b8c0d8", a))
    p.composite(lay, blur=10)


def night(p, y1, seed, top="#08041a", bottom="#3a1438"):
    sky(p, y1, [(0, top), (1, bottom)])
    stars(p, 160, y1 - 160, seed)


# ------------------------------------------------------------------ titles
def open_screen():
    p = Paint()
    night(p, H, 500, "#06020e", "#2a0c24")
    moon(p, 640, 170, 70)
    hill_band(p, 900, 30, "#06040a", 501)
    dead_tree(p, 110, 910, 1.4, seed=502)
    dead_tree(p, 680, 905, 1.1, seed=503)
    fog(p, 880, 504, 0.2)
    p.grain(0.015, 505)
    return p


def finale():
    p = Paint()
    night(p, 840, 510, "#0a0218", "#3a0c24")
    moon(p, 600, 160, 70)
    hill_band(p, 820, 16, "#0c0810", 511, bottom=H)
    p.fill_rect(0, 840, W, H - 840, p.lin(0, 840, 0, H, [(0, "#140c14"), (1, "#060406")]))
    dead_tree(p, 60, 840, 1.1, seed=512)
    dead_tree(p, 720, 836, 0.9, seed=513)
    fog(p, 830, 514, 0.18)
    p.grain(0.015, 515)
    return p


# ------------------------------------------------------------------ the haunted house (windows flicker live; the attic ghost, bats, lightning live)
def house():
    p = Paint()
    night(p, 760, 520, "#06021a", "#3a1840")
    moon(p, 560, 200, 110)
    hill = "#0a0614"
    p.ellipse(384, 760, 520, 200, hill)
    hx, hy = 384, 600
    wall = "#16101e"
    # the house: siding, a gable roof, the turret, the chimney, the porch
    p.fill_rect(hx - 150, hy - 140, 300, 160, p.lin(hx - 150, 0, hx + 150, 0, [(0, "#0e0a14"), (0.6, wall), (1, "#1e1626")]))
    for k in range(10):
        p.fill_rect(hx - 150, hy - 132 + k * 16, 300, 1.5, hexc("#000000", 0.4))
    p.poly([(hx - 170, hy - 140), (hx + 170, hy - 140), (hx, hy - 260)], "#0c0812")
    for k in range(7):
        y = hy - 150 - k * 15
        half = 160 * (1 - (k + 1) / 8)
        p.line([(hx - half, y), (hx + half, y)], hexc("#2a2030", 0.6), 1)
    p.fill_rect(hx + 70, hy - 300, 50, 170, p.lin(hx + 70, 0, hx + 120, 0, [(0, "#0e0a14"), (1, "#1e1626")]))
    p.poly([(hx + 60, hy - 300), (hx + 130, hy - 300), (hx + 95, hy - 370)], "#0a0610")
    p.line([(hx + 95, hy - 370), (hx + 95, hy - 392)], "#0a0610", 2)
    p.fill_rect(hx - 140, hy - 210, 14, 70, "#0e0a12")
    # broken shutters, dark windows (the light in them is live)
    for (wx, wy) in ((-110, -110), (-40, -110), (40, -110), (-110, -50), (80, -50), (95, -260)):
        x, y = hx + wx, hy + wy
        p.fill_rect(x - 3, y - 3, 40, 50, "#0a060e")
        p.fill_rect(x, y, 34, 44, "#1a1418")
        if wy != -260:
            p.fill_rect(x - 12, y - 2, 10, 48, "#241a2a")
            p.poly([(x + 36, y), (x + 46, y + 4), (x + 44, y + 50), (x + 36, y + 46)], "#241a2a")
    # the porch: a sagging roof, posts, steps
    p.poly([(hx - 70, hy - 30), (hx + 70, hy - 26), (hx + 82, hy - 10), (hx - 82, hy - 12)], "#0c0812")
    for x in (hx - 66, hx + 60):
        p.fill_rect(x, hy - 12, 6, 32, "#0c0812")
    p.fill_rect(hx - 20, hy - 30, 40, 50, "#06040a")
    for k in range(3):
        p.fill_rect(hx - 40 - k * 6, hy + 20 + k * 6, 80 + k * 12, 6, "#100c16")
    # the dead tree, the graveyard
    dead_tree(p, 120, 760, 1.3, seed=521)
    p.fill_rect(0, 760, W, H - 760, p.lin(0, 760, 0, H, [(0, "#120c18"), (1, "#06040a")]))
    for i, (x, y, t) in enumerate(((120, 880, "R.I.P."), (260, 900, "HIGH SCORE"), (420, 870, "PAC'S DIET"), (580, 900, "R.I.P."), (690, 880, None))):
        tombstone(p, x, y, 80, 70, t, 522 + i)
    fog(p, 920, 527, 0.2)
    iron_fence(p, 950)
    p.grain(0.015, 528)
    return p


# ------------------------------------------------------------------ carving the pumpkins (the pumpkins and the knife are live)
def kitchen():
    p = Paint()
    p.fill_rect(0, 0, W, 620, p.lin(0, 0, 0, 620, [(0, "#1e1020"), (1, "#3a2228")]))
    # the window: the moon, a bare branch
    p.fill_rect(260, 60, 248, 240, "#2a1810")
    p.fill_rect(270, 70, 228, 220, p.lin(0, 70, 0, 290, [(0, "#0a0a2a"), (1, "#3a1a3a")]))
    moon(p, 420, 150, 40, glow=0.3)
    p.line([(270, 260), (360, 210), (420, 230)], "#06040a", 4)
    p.fill_rect(380, 70, 8, 220, "#2a1810")
    p.fill_rect(270, 176, 228, 8, "#2a1810")
    # shelves, jars, a cobweb in the corner
    p.fill_rect(30, 120, 180, 10, "#3a2418")
    p.fill_rect(560, 160, 180, 10, "#3a2418")
    for i, c in enumerate(("#5a8a3a", "#8a3a5a", "#c8a03a", "#3a6a8a")):
        p.fill_rect(44 + i * 42, 84, 30, 36, hexc(c, 0.7), r=5)
        p.fill_rect(46 + i * 42, 80, 26, 6, "#4a3a2a")
    for i in range(3):
        p.fill_rect(580 + i * 54, 120, 36, 40, "#6a4a30", r=3)
    cx, cy = 0, 0
    for k in range(6):
        a = k / 5 * math.pi / 2
        p.line([(cx, cy), (cx + math.cos(a) * 140, cy + math.sin(a) * 140)], hexc("#d8d8e8", 0.25), 1)
    for rr in (30, 60, 90, 120):
        pts = [(math.cos(k / 10 * math.pi / 2) * rr, math.sin(k / 10 * math.pi / 2) * rr) for k in range(11)]
        p.line(pts, hexc("#d8d8e8", 0.2), 1)
    # the table: boards, newspaper under the pumpkins
    p.fill_rect(0, 620, W, H - 620, p.lin(0, 620, 0, H, [(0, "#5a3820"), (1, "#2e1c10")]))
    for y in range(640, H, 46):
        p.fill_rect(0, y, W, 3, hexc("#1a0e06", 0.6))
    for (x, y) in ((130, 560), (384, 560), (638, 560), (130, 830), (384, 830), (638, 830)):
        p.poly([(x - 110, y + 70), (x + 100, y + 60), (x + 110, y + 100), (x - 100, y + 110)], hexc("#d8d4c4", 0.75))
        for k in range(5):
            p.fill_rect(x - 90, y + 72 + k * 7, 170, 2, hexc("#4a4a4a", 0.35))
    p.grain(0.015, 531)
    return p


# ------------------------------------------------------------------ trick or treat (doors, porch lights, little pumpkins, the costumes are live)
def street():
    p = Paint()
    night(p, 700, 540, "#06041e", "#341a40")
    moon(p, 120, 140, 60)
    for i in range(3):
        x = 30 + i * 250
        base = ["#2a1e34", "#30202e", "#262030"][i]
        p.fill_rect(x, 420, 210, 330, p.lin(x, 0, x + 210, 0, [(0, mix(base, "#000000", 0.3)), (1, base)]))
        for k in range(20):
            p.fill_rect(x, 428 + k * 16, 210, 1.2, hexc("#000000", 0.35))
        p.poly([(x - 10, 420), (x + 220, 420), (x + 105, 330)], "#16101c")
        p.fill_rect(x + 20, 470, 50, 60, "#3a2a22")
        p.fill_rect(x + 24, 474, 42, 52, "#e8a050" if i != 1 else "#1a1420")
        p.fill_rect(x + 140, 470, 50, 60, "#3a2a22")
        p.fill_rect(x + 144, 474, 42, 52, "#1a1420" if i != 1 else "#e8a050")
        p.fill_rect(x + 76, 616, 58, 134, "#140e10")
        p.fill_rect(x + 80, 620, 50, 130, "#4a2a1a")
        p.fill_rect(x + 60, 750, 90, 8, "#3a3036")
        # cobwebs, a hanging ghost decoration
        p.line([(x + 10, 430), (x + 40, 460)], hexc("#d8d8e8", 0.25), 1)
        p.ellipse(x + 180, 450, 8, 12, hexc("#e8e8f0", 0.8))
    # the sidewalk, the street, the curb
    p.fill_rect(0, 750, W, H - 750, p.lin(0, 750, 0, H, [(0, "#3a3840"), (1, "#1e1c22")]))
    p.fill_rect(0, 800, W, 8, "#4a4850")
    r = rng(541)
    for i in range(20):
        p.fill_rect(i * 40, 752, 2, 48, hexc("#000000", 0.4))
    for i in range(60):
        x, y = r.random() * W, 760 + r.random() * 260
        p.ellipse(x, y, 5, 3, hexc(["#c8401a", "#e8801a", "#8a4a1a"][i % 3], 0.6))
    p.grain(0.015, 542)
    return p


# ------------------------------------------------------------------ the graveyard dance (the dancers, the ghosts, the fog are live)
def graveyard():
    p = Paint()
    night(p, 760, 550, "#040616", "#1a3040")
    moon(p, 384, 260, 150, col="#e8f0d8")
    hill_band(p, 740, 20, "#0a1014", 551, bottom=800)
    # a chapel on the hill, crooked crosses
    p.fill_rect(600, 640, 90, 110, "#0a0e12")
    p.poly([(590, 640), (700, 640), (645, 590)], "#0a0e12")
    p.fill_rect(640, 560, 10, 40, "#0a0e12")
    p.fill_rect(630, 572, 30, 8, "#0a0e12")
    for (x, y, a) in ((60, 790, 0.1), (330, 780, -0.15), (470, 790, 0.2)):
        p.cr.save()
        p.cr.translate(x, y)
        p.cr.rotate(a)
        p.fill_rect(-3, -50, 6, 50, "#141820")
        p.fill_rect(-15, -38, 30, 6, "#141820")
        p.cr.restore()
    p.fill_rect(0, 760, W, H - 760, p.lin(0, 760, 0, H, [(0, "#142018"), (1, "#060a08")]))
    for i, (x, y) in enumerate(((80, 860), (200, 880), (560, 880), (690, 860))):
        tombstone(p, x, y, 70, 60, None, 552 + i)
    dead_tree(p, 720, 770, 1.0, seed=556)
    p.grain(0.015, 557)
    return p


# ------------------------------------------------------------------ the witch's moon (the witch, the potion, the fire are live)
def witch():
    p = Paint()
    sky(p, H, [(0, "#06021a"), (0.6, "#2a0c34"), (1, "#3a0c2a")])
    stars(p, 140, 600, 560)
    moon(p, 384, 380, 220, col="#f0e0b0", glow=0.5)
    # a castle on the ridge, against the moon
    hill_band(p, 700, 30, "#08040e", 561, bottom=H)
    cx = 560
    p.fill_rect(cx - 60, 560, 120, 150, "#08040e")
    for (tx, th) in ((-70, 200), (60, 180), (-10, 230)):
        p.fill_rect(cx + tx - 14, 710 - th, 28, th, "#08040e")
        p.poly([(cx + tx - 18, 710 - th), (cx + tx + 18, 710 - th), (cx + tx, 710 - th - 40)], "#08040e")
    p.fill_rect(cx - 6, 500, 4, 16, "#ffd080")
    # the cauldron and its logs (the potion, the bubbles, the fire are live)
    p.fill_rect(300, 950, 168, 20, "#3a2010", r=8)
    p.fill_rect(310, 935, 148, 18, "#4a2a14", r=8)
    p.ellipse(384, 880, 140, 90, p.rad(350, 850, 10, 150, [(0, "#3a3a44"), (1, "#0a0a0e")]))
    p.fill_rect(250, 820, 268, 30, p.lin(0, 820, 0, 850, [(0, "#4a4a54"), (1, "#14141a")]), r=10)
    p.grain(0.015, 562)
    return p


PAINTS = {
    "open": open_screen,
    "house": house,
    "kitchen": kitchen,
    "street": street,
    "graveyard": graveyard,
    "witch": witch,
    "finale": finale,
}
