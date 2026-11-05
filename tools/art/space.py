"""Mission Control's pictures (space.lua). Each laid out under its scene's live parts (the visitors, the track on
the big screen, the consoles' lights, the poll, the rocket, staging, the station and the spacewalk, Earthrise,
the flags and the hop, the capsule, the helicopter: all live).
"""
import math

from paint import Paint, W, H, hexc, mix, rng
from scenery import cloud, live_oak, stars, milky_way, water, grass_tufts


def sky(p, y1, stops):
    p.fill_rect(0, 0, W, y1, p.lin(0, 0, 0, y1, stops))


def label(p, x, y, text, size, col, font="sans", bold=True, rot=0):
    cr = p.cr
    cr.save()
    cr.translate(x, y)
    cr.rotate(rot)
    cr.select_font_face(font, 0, 1 if bold else 0)
    cr.set_font_size(size)
    e = cr.text_extents(text)
    p.src(col)
    cr.move_to(-e.width / 2 - e.x_bearing, e.height / 2)
    cr.show_text(text)
    cr.restore()


def deep_space(p, seed, n=500):
    p.fill_rect(0, 0, W, H, "#020208")
    lay = p.layer()
    r = rng(seed)
    for i in range(10):
        lay.ellipse(r.random() * W, r.random() * H, 120 + r.random() * 200, 60 + r.random() * 120,
                    hexc(["#3a1a5a", "#1a2a6a", "#5a1a3a"][i % 3], 0.18))
    p.composite(lay, blur=40)
    stars(p, n, H, seed + 1, big=0.03)


def earth_disc(p, cx, cy, rr, seed, tilt=0.0):
    """The Earth: oceans, continents (Texas on the Gulf among them), clouds, the air glowing at the edge."""
    p.glow(cx, cy, rr * 1.12, "#6ab0ff", 0.55)
    p.circle(cx, cy, rr, p.rad(cx - rr * 0.3, cy - rr * 0.4, rr * 0.1, rr * 1.1, [(0, "#2a6ad8"), (0.7, "#0e3a8a"), (1, "#061a4a")]))
    cr = p.cr
    cr.save()
    cr.arc(cx, cy, rr - 2, 0, 2 * math.pi)
    cr.clip()
    r = rng(seed)
    # North America, with Texas's shape at the Gulf
    for (dx, dy, sx, sy, col) in [(-0.35, -0.2, 0.28, 0.2, "#4a7a3a"), (-0.25, -0.05, 0.18, 0.14, "#8a7a4a"),
                                  (-0.18, 0.06, 0.1, 0.08, "#a8864a"), (0.25, -0.1, 0.22, 0.16, "#5a8a40"),
                                  (0.35, 0.15, 0.14, 0.2, "#7a8a4a"), (-0.05, 0.3, 0.12, 0.12, "#4a7a3a")]:
        x, y = cx + dx * rr, cy + dy * rr
        for k in range(9):
            p.ellipse(x + (r.random() - 0.5) * sx * rr, y + (r.random() - 0.5) * sy * rr, sx * rr * (0.3 + r.random() * 0.3),
                      sy * rr * (0.3 + r.random() * 0.3), col)
    for i in range(70):
        a = r.random() * 6.28
        d = r.random() ** 0.6 * rr
        p.ellipse(cx + math.cos(a) * d, cy + math.sin(a) * d, 20 + r.random() * 80, 4 + r.random() * 12, hexc("#ffffff", 0.5))
    # the night side
    cr.restore()
    p.glow(cx, cy, rr * 1.02, "#a8d8ff", 0.12)


# ------------------------------------------------------------------ titles
def open_screen():
    p = Paint()
    deep_space(p, 700)
    milky_way(p, -40, 300, 820, 760, 701, width=100, bright=0.7)
    p.grain(0.012, 702)
    return p


# ------------------------------------------------------------------ Rocket Park (the visitors are live)
def saturn_v(p, x0, y, s=1.0):
    """The Saturn V on its side: the F-1 bells, the first stage's black and white roll pattern, the S-II, the
    S-IVB, the instrument unit, the Apollo spacecraft and its escape tower."""
    bells = "#3a3a40"
    for i in range(5):
        p.poly([(x0, y - 50 + i * 22), (x0 + 40, y - 40 + i * 20), (x0 + 40, y - 30 + i * 20), (x0, y - 30 + i * 22)],
               p.lin(x0, 0, x0 + 40, 0, [(0, "#1a1a1e"), (1, bells)]))
    p.fill_rect(x0 + 40, y - 56, 300, 112, p.lin(0, y - 56, 0, y + 56, [(0, "#ffffff"), (0.6, "#e8e8ec"), (1, "#a8a8b0")]))
    for x in (x0 + 40, x0 + 120, x0 + 210):
        p.fill_rect(x, y - 56, 14, 112, "#1a1a1e")
    p.fill_rect(x0 + 170, y - 56, 60, 36, "#1a1a1e")
    label(p, x0 + 270, y - 6, "USA", 22, "#1a1a1e", rot=-math.pi / 2)
    p.fill_rect(x0 + 340, y - 46, 200, 92, p.lin(0, y - 46, 0, y + 46, [(0, "#ffffff"), (0.6, "#e8e8ec"), (1, "#a8a8b0")]))
    p.fill_rect(x0 + 340, y - 46, 14, 92, "#1a1a1e")
    p.fill_rect(x0 + 440, y - 46, 14, 92, "#1a1a1e")
    p.fill_rect(x0 + 540, y - 34, 110, 68, p.lin(0, y - 34, 0, y + 34, [(0, "#ffffff"), (1, "#a8a8b0")]))
    p.fill_rect(x0 + 540, y - 34, 14, 68, "#1a1a1e")
    p.poly([(x0 + 650, y - 34), (x0 + 700, y - 16), (x0 + 700, y + 16), (x0 + 650, y + 34)], "#d8d8dc")
    p.line([(x0 + 700, y), (x0 + 740, y)], "#c4202a", 3)
    for k in range(4):
        p.line([(x0 + 700, y - 10 + k * 7), (x0 + 720, y)], "#8a2a1a", 1)
    p.ellipse(x0 + 345, y, 8, 46, hexc("#000000", 0.25))


def houston():
    p = Paint()
    sky(p, 640, [(0, "#3a72c8"), (1, "#dce8f4")])
    cloud(p, 200, 130, 0.8, hexc("#ffffff", 0.96), hexc("#c0d2e8", 0.96), 710)
    cloud(p, 600, 90, 0.6, hexc("#ffffff", 0.96), hexc("#c0d2e8", 0.96), 711)
    live_oak(p, 90, 650, 1.1, "day", 712)
    live_oak(p, 690, 650, 0.95, "day", 713, flip=True)
    p.fill_rect(0, 640, W, H - 640, p.lin(0, 640, 0, H, [(0, "#5a8a3a"), (1, "#2e5a1e")]))
    grass_tufts(p, 650, H, 714, 900)
    # the shelter: a long roof on columns, its shadow
    p.fill_rect(10, 330, 748, 26, p.lin(0, 330, 0, 356, [(0, "#d8d8dc"), (1, "#8a8a92")]))
    p.fill_rect(10, 356, 748, 6, hexc("#000000", 0.25))
    p.fill_rect(0, 360, W, 300, hexc("#000000", 0.12))
    for x in range(40, 750, 100):
        p.fill_rect(x, 360, 12, 290, p.lin(x, 0, x + 12, 0, [(0, "#a8a8b0"), (0.5, "#e8e8ec"), (1, "#8a8a92")]))
    saturn_v(p, 30, 520)
    for x in (120, 320, 520, 640):
        p.fill_rect(x, 576, 14, 90, "#5a5a62")
        p.fill_rect(x - 10, 660, 34, 8, "#4a4a52")
    # the path the visitors walk
    p.fill_rect(0, 690, W, 26, hexc("#d8ccb0", 0.8))
    p.grain(0.018, 715)
    return p


# ------------------------------------------------------------------ the control room (the track, the consoles' lights, the controllers, the poll are live)
def control():
    p = Paint()
    p.fill_rect(0, 0, W, H, p.lin(0, 0, 0, H, [(0, "#1e2028"), (1, "#0c0d12")]))
    for x in range(0, W, 48):
        p.fill_rect(x, 0, 2, 520, hexc("#ffffff", 0.025))
    # the big screen: its frame, the world map
    p.fill_rect(30, 110, 708, 300, "#2a2c34", r=6)
    p.fill_rect(40, 120, 688, 280, p.lin(0, 120, 0, 400, [(0, "#06101e"), (1, "#0a1a2e")]))
    for i in range(9):
        p.fill_rect(40 + i * 86, 120, 1, 280, hexc("#3a7ac8", 0.35))
    for i in range(5):
        p.fill_rect(40, 120 + i * 70, 688, 1, hexc("#3a7ac8", 0.35))
    cont = [(130, 190, 80, 46), (170, 230, 30, 30), (250, 280, 40, 70), (390, 180, 100, 50), (420, 250, 50, 60),
            (560, 210, 110, 60), (640, 300, 40, 26)]
    for (x, y, rx, ry) in cont:
        p.ellipse(x, y, rx, ry, hexc("#4ac86a", 0.35))
        p.ellipse(x, y, rx * 0.7, ry * 0.7, hexc("#6ae88a", 0.18))
    # the clocks and side screens
    for (x, t) in ((90, "GET 004:12:31"), (384, "MET 004:12:31"), (678, "HOU 14:22:09")):
        p.fill_rect(x - 80, 70, 160, 30, "#06101e", r=3)
        label(p, x, 85, t, 16, "#ff9a3a")
    # the tiers: steps, rails (the consoles on them are live)
    for tier in range(3):
        y = 560 + tier * 150
        p.fill_rect(0, y + 40, W, 110, p.lin(0, y + 40, 0, y + 150, [(0, "#2a2c34"), (1, "#16171c")]))
        p.fill_rect(0, y + 36, W, 6, "#3a3c46")
    p.grain(0.015, 720)
    return p


# ------------------------------------------------------------------ the launch: on the pad, then high up (the rocket, the count, staging are live)
def pad():
    p = Paint()
    sky(p, H, [(0, "#4a82d8"), (0.8, "#e8ddc8"), (1, "#f0e0c0")])
    cloud(p, 160, 200, 0.7, hexc("#ffffff", 0.95), hexc("#c8d2e4", 0.95), 730)
    cloud(p, 640, 140, 0.5, hexc("#ffffff", 0.95), hexc("#c8d2e4", 0.95), 731)
    # the sea beyond, the shore
    water(p, 780, 830, "#5a8ab8", "#3a6a98", 732, lines=30)
    p.fill_rect(0, 830, W, 40, "#d8ccaa")
    # the tower: red girders, its arm (live), the lightning mast
    p.fill_rect(520, 230, 50, 640, p.lin(520, 0, 570, 0, [(0, "#8a1a12"), (0.5, "#c42a1a"), (1, "#7a1810")]))
    for y in range(240, 860, 40):
        p.line([(520, y), (570, y + 40)], "#5a0e08", 3)
        p.line([(570, y), (520, y + 40)], "#5a0e08", 3)
    p.fill_rect(540, 180, 10, 50, "#c42a1a")
    p.line([(545, 180), (545, 150)], "#8a8a92", 2)
    # the pad, the flame trench
    p.fill_rect(150, 866, 470, 50, p.lin(0, 866, 0, 916, [(0, "#a8a8b0"), (1, "#6a6a72")]))
    p.fill_rect(330, 880, 110, 36, "#2a2a30")
    p.fill_rect(0, 910, W, H - 910, p.lin(0, 910, 0, H, [(0, "#b0a888"), (1, "#8a8064")]))
    p.grain(0.018, 733)
    return p


def high():
    p = Paint()
    sky(p, H, [(0, "#000006"), (0.7, "#0a1440"), (1, "#2a4a9a")])
    stars(p, 260, 700, 740)
    p.glow(384, 1500, 1100, "#6ab0ff", 0.4, 0.55)
    p.circle(384, 1900, 1050, p.rad(300, 900, 100, 1100, [(0, "#3a7ae8"), (1, "#0a2a6a")]))
    r = rng(741)
    for i in range(40):
        x = r.random() * W
        p.ellipse(x, 880 + r.random() * 160, 40 + r.random() * 90, 6 + r.random() * 10, hexc("#ffffff", 0.45))
    p.grain(0.012, 742)
    return p


# ------------------------------------------------------------------ orbit (the station, the spacewalk, the sunrise are live)
def orbit():
    p = Paint()
    deep_space(p, 750, 400)
    earth_disc(p, 384, 1700, 1100, 751)
    # the land on the curve we see: the Gulf coast and Texas, Mexico below it, Florida off to the right
    cr = p.cr
    cr.save()
    cr.arc(384, 1700, 1096, 0, 2 * math.pi)
    cr.clip()
    land = "#5a7a3a"
    p.fill_path([("M", 60, 700), ("C", 160, 640, 300, 640, 360, 680), ("C", 390, 720, 420, 760, 470, 780),
                 ("C", 430, 820, 380, 850, 340, 900), ("C", 300, 860, 250, 820, 200, 800), ("C", 140, 790, 80, 760, 60, 700), ("Z",)],
                p.lin(60, 640, 470, 900, [(0, "#4a6a34"), (0.5, "#6a7a40"), (1, "#3e6a2e")]))
    p.fill_path([("M", 470, 780), ("C", 520, 760, 600, 740, 680, 720), ("C", 700, 760, 690, 800, 660, 830),
                 ("C", 620, 820, 560, 810, 520, 800), ("Z",)], land)
    p.fill_path([("M", 200, 800), ("C", 230, 880, 260, 960, 300, 1024), ("L", 120, 1024), ("C", 140, 940, 160, 860, 200, 800), ("Z",)], "#6a8a3a")
    r = rng(753)
    for i in range(260):
        x, y = 40 + r.random() * 700, 650 + r.random() * 370
        p.ellipse(x, y, 4 + r.random() * 14, 3 + r.random() * 8, hexc(["#8a7a4a", "#3a5a2a", "#5a7a3a"][i % 3], 0.35))
    lay = p.layer()
    for i in range(90):
        x, y = r.random() * W, 640 + r.random() * 380
        lay.ellipse(x, y, 30 + r.random() * 90, 6 + r.random() * 12, hexc("#ffffff", 0.6))
    p.composite(lay, blur=3)
    cr.restore()
    p.glow(384, 610, 500, "#a8d8ff", 0.25, 0.12)
    p.grain(0.012, 752)
    return p


# ------------------------------------------------------------------ the Moon (Earthrise, the lander, the walk, the flags, the rover are live)
def moon_surface():
    p = Paint()
    p.fill_rect(0, 0, W, H, "#020206")
    stars(p, 400, 640, 760)
    # the ground: grey dust, craters, the horizon's rim
    p.fill_rect(0, 640, W, H - 640, p.lin(0, 640, 0, H, [(0, "#9a9aa0"), (1, "#5a5a62")]))
    r = rng(761)
    for i in range(26):
        x, y = r.random() * W, 680 + r.random() * 330
        rr = 14 + r.random() * 60 * ((y - 640) / 380)
        p.ellipse(x, y, rr * 1.08, rr * 0.34, hexc("#c8c8cc", 0.5))
        p.ellipse(x, y + rr * 0.02, rr, rr * 0.3, p.lin(0, y - rr * 0.3, 0, y + rr * 0.3, [(0, "#4a4a52"), (1, "#8a8a92")]))
        p.ellipse(x, y + rr * 0.06, rr * 0.7, rr * 0.18, hexc("#7a7a82", 0.6))
    for i in range(600):
        p.circle(r.random() * W, 650 + r.random() * 374, 0.6 + r.random(), hexc("#ffffff" if r.random() < 0.5 else "#2a2a30", 0.25))
    p.grain(0.015, 762)
    return p


# ------------------------------------------------------------------ splashdown (the capsule, its chutes, the helicopter are live)
def ocean():
    p = Paint()
    sky(p, 640, [(0, "#3a72c8"), (1, "#dce8f4")])
    for i, (x, y, s) in enumerate([(150, 160, 0.8), (520, 110, 0.7), (660, 260, 0.5)]):
        cloud(p, x, y, s, hexc("#ffffff", 0.96), hexc("#c0d2e8", 0.96), 770 + i)
    water(p, 640, H, "#2a6a9a", "#0e3a5a", 773, lines=160)
    # the recovery ship on the horizon
    sx = 120
    p.poly([(sx - 90, 628), (sx + 110, 628), (sx + 96, 644), (sx - 80, 644)], "#5a6270")
    p.fill_rect(sx - 70, 616, 170, 12, "#6a7280")
    p.fill_rect(sx + 30, 596, 26, 20, "#5a6270")
    p.fill_rect(sx + 40, 584, 4, 12, "#5a6270")
    p.grain(0.015, 774)
    return p


PAINTS = {
    "open": open_screen,
    "houston": houston,
    "control": control,
    "pad": pad,
    "high": high,
    "orbit": orbit,
    "moon": moon_surface,
    "ocean": ocean,
}
