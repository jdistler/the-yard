"""The Summer show's pictures (summer.lua). Each laid out under its scene's live parts (boats, the float, the
pontoon, the dive, swimmers, the snow cone melting, the thermometer, the tubers, rain, lightning, the rainbow, the
swing, the fireflies: all live).
"""
import math

from paint import Paint, W, H, hexc, mix, rng
from scenery import cloud, live_oak, hill_band, haze, water, stars, grass_tufts


def sky(p, y1, stops):
    p.fill_rect(0, 0, W, y1, p.lin(0, 0, 0, y1, stops))


def label(p, x, y, text, size, col, font="sans", bold=True):
    cr = p.cr
    cr.save()
    cr.select_font_face(font, 0, 1 if bold else 0)
    cr.set_font_size(size)
    e = cr.text_extents(text)
    p.src(col)
    cr.move_to(x - e.width / 2 - e.x_bearing, y)
    cr.show_text(text)
    cr.restore()


def sun(p, x, y, r):
    p.glow(x, y, r * 3.5, "#ffd890", 0.45)
    p.circle(x, y, r, p.rad(x, y, 0, r, [(0, "#fffbe0"), (1, "#ffe890")]))


# ------------------------------------------------------------------ titles
def open_screen():
    p = Paint()
    sky(p, H, [(0, "#3a8ae8"), (0.6, "#a8c8f0"), (1, "#ffd090")])
    sun(p, 384, 330, 90)
    for i, (x, y, s) in enumerate([(130, 160, 0.7), (640, 120, 0.6)]):
        cloud(p, x, y, s, hexc("#ffffff", 0.95), hexc("#d8d0d0", 0.95), 800 + i)
    hill_band(p, 900, 18, "#4a6a5a", 801, top_col="#6a8a6a")
    water(p, 930, H, "#3a7aa8", "#1e5a7a", 802, glints=(384, "#fff0c0"), lines=40)
    p.grain(0.015, 803)
    return p


def finale():
    p = Paint()
    sky(p, 760, [(0, "#3a5ab8"), (0.6, "#e88a6a"), (1, "#ffb060")])
    sun(p, 384, 640, 140)
    hill_band(p, 740, 14, "#4a3a5a", 810, bottom=780)
    water(p, 760, H, "#3a3a6a", "#141a3a", 811, glints=(384, "#ffb060"), lines=80)
    # the dock: boards on posts, out from the left
    p.fill_rect(0, 830, 520, 16, p.lin(0, 830, 0, 846, [(0, "#4a3020"), (1, "#2a1a10")]))
    for i in range(14):
        p.fill_rect(i * 38, 830, 1.5, 16, hexc("#000000", 0.4))
    for i in range(6):
        x = 20 + i * 96
        p.fill_rect(x, 846, 12, 120, p.lin(x, 0, x + 12, 0, [(0, "#1a100a"), (1, "#3a2414")]))
    p.grain(0.015, 812)
    return p


# ------------------------------------------------------------------ Lake Travis
def lake():
    p = Paint()
    sky(p, 520, [(0, "#2a6ad8"), (1, "#c8e2f8")])
    sun(p, 620, 110, 46)
    cloud(p, 200, 150, 0.7, hexc("#ffffff", 0.95), hexc("#c8d8ec", 0.95), 820)
    # the hills across the lake, houses on them
    hill_band(p, 500, 30, "#5a7a5a", 821, bottom=540, top_col="#7a9a6a")
    haze(p, 430, 530, "#c8e2f8", 0.35)
    r = rng(822)
    for i in range(12):
        x = 30 + r.random() * 460
        y = 488 + r.random() * 30
        p.fill_rect(x, y, 10, 7, "#f0ece0")
        p.poly([(x - 1, y), (x + 11, y), (x + 5, y - 5)], "#a85a3a")
    water(p, 520, H, "#3a8ab8", "#1a5a7a", 823, lines=120)
    # the limestone cliffs on the right: ledges, cedars on top, the waterline stain
    cliff = [(520, 520), (768, 400), (768, 760), (620, 760), (560, 640)]
    p.poly(cliff, p.lin(520, 0, 768, 0, [(0, "#d8ccb0"), (0.5, "#efe6d0"), (1, "#c8bca0")]))
    for i in range(6):
        y = 470 + i * 50
        p.fill_rect(560 + i * 30 - 20, y, 208 - i * 30 + 40, 5, hexc("#9a8a6a", 0.8))
        p.fill_rect(560 + i * 30 - 20, y + 5, 208 - i * 30 + 40, 10, hexc("#8a7a5a", 0.25))
    p.fill_rect(560, 730, 208, 30, hexc("#6a6a5a", 0.4))
    for i in range(14):
        x = 600 + r.random() * 160
        p.ellipse(x, 400 + (x - 600) * -0.2 + r.random() * 10, 16 + r.random() * 14, 10, "#2e5a2a")
    p.grain(0.018, 824)
    return p


# ------------------------------------------------------------------ Barton Springs
def springs():
    p = Paint()
    sky(p, 470, [(0, "#3a72d8"), (1, "#d8ecf8")])
    for i, x in enumerate((90, 330, 640)):
        live_oak(p, x, 505, 1.15 - i * 0.12, "day", 830 + i, flip=(i == 2))
    # the hill: grass, the towels
    p.fill_rect(0, 480, W, 125, p.lin(0, 480, 0, 605, [(0, "#6a9a4a"), (1, "#4a7a30")]))
    grass_tufts(p, 485, 600, 833, 500, col="#5a8a3a")
    cols = ["#e8402a", "#3a6ad8", "#f0c820", "#5ac85a", "#e85aa8", "#ffffff", "#2ab8b8"]
    for i in range(7):
        x, y = 40 + i * 104, 540 + (i % 2) * 20
        p.fill_rect(x, y, 60, 24, cols[i], r=3)
        for k in range(4):
            p.fill_rect(x + k * 15, y, 7, 24, hexc("#ffffff", 0.25))
    # the pool: cold clear water over the limestone bottom
    p.fill_rect(0, 600, W, H - 600, p.lin(0, 600, 0, H, [(0, "#5ac0c8"), (1, "#1e7a8a")]))
    r = rng(834)
    for i in range(70):
        x, y = r.random() * W, 640 + r.random() * 380
        p.ellipse(x, y, 20 + r.random() * 40, 6 + r.random() * 8, hexc("#e8f0e0", 0.18))
    lay = p.layer()
    for i in range(50):
        x, y = r.random() * W, 640 + r.random() * 380
        lay.ellipse(x, y, 30, 3, hexc("#ffffff", 0.25))
    p.composite(lay, blur=1.5)
    p.fill_rect(0, 600, W, 10, "#c8bca0")
    # the diving board
    p.fill_rect(520, 586, 200, 14, p.lin(0, 586, 0, 600, [(0, "#ffffff"), (1, "#b8c0c8")]), r=3)
    p.fill_rect(690, 600, 20, 60, "#a8b0b8")
    p.fill_rect(700, 560, 4, 30, "#a8b0b8")
    p.line([(700, 560), (730, 560)], "#a8b0b8", 3)
    p.grain(0.015, 835)
    return p


# ------------------------------------------------------------------ snow cones (Pac-Man, the bottles, the cone, the thermometer's mercury, the line are live)
def snocone():
    p = Paint()
    sky(p, 640, [(0, "#4a8ae8"), (1, "#f8ead0")])
    sun(p, 120, 120, 60)
    p.fill_rect(0, 640, W, H - 640, p.lin(0, 640, 0, H, [(0, "#d8c098"), (1, "#a8906a")]))
    r = rng(840)
    for i in range(300):
        p.ellipse(r.random() * W, 650 + r.random() * 374, 2, 1.2, hexc("#7a6a4a", 0.3))
    # the stand: walls, the window (dark inside), the striped awning, the sign
    p.fill_rect(160, 360, 448, 360, p.lin(160, 0, 608, 0, [(0, "#e8e4dc"), (0.5, "#ffffff"), (1, "#dcd8d0")]), r=6)
    for k in range(18):
        p.fill_rect(160, 368 + k * 20, 448, 1.5, hexc("#c8c0b0", 0.6))
    p.fill_rect(196, 436, 376, 148, "#c8c0b4")
    p.fill_rect(200, 440, 368, 140, p.lin(0, 440, 0, 580, [(0, "#2a2034"), (1, "#3a3048")]))
    p.fill_rect(190, 580, 388, 12, "#d8242a")
    for i in range(8):
        col = "#e8285a" if i % 2 == 0 else "#ffffff"
        p.poly([(140 + i * 61, 360), (201 + i * 61, 360), (196 + i * 61, 400), (145 + i * 61, 400)], col)
        p.ellipse(170 + i * 61, 400, 26, 8, col)
    p.fill_rect(220, 296, 328, 52, "#ffffff", r=8)
    label(p, 384, 336, "SNO-BALLS", 40, "#e8285a")
    # the thermometer's body (its mercury and reading are live)
    p.fill_rect(660, 400, 50, 280, "#f4f4f4", r=20)
    p.fill_rect(666, 406, 38, 268, hexc("#d8e8f0", 0.6), r=16)
    for k in range(12):
        p.fill_rect(692, 420 + k * 20, 12, 2, "#5a5a62")
    p.circle(685, 660, 22, "#f4f4f4")
    p.grain(0.015, 841)
    return p


# ------------------------------------------------------------------ tubing the river (the tubers, the cooler, the turtle's head, the ripples are live)
def tubing():
    p = Paint()
    sky(p, 430, [(0, "#3a72d8"), (1, "#d0e4f6")])
    cloud(p, 380, 120, 0.7, hexc("#ffffff", 0.95), hexc("#c8d8ec", 0.95), 850)
    # bald cypresses along the banks: tall, feathery, knees at their feet
    for i, x in enumerate((40, 160, 620, 730)):
        p.fill_path([("M", x - 22, 520), ("C", x - 10, 440, x - 8, 340, x - 4, 250), ("L", x + 4, 250),
                     ("C", x + 8, 340, x + 10, 440, x + 22, 520), ("Z",)], p.lin(x - 22, 0, x + 22, 0, [(0, "#4a3428"), (0.5, "#7a5a40"), (1, "#3a2818")]))
        r = rng(851 + i)
        for k in range(140):
            yy = 220 + r.random() * 230
            w = 50 * (1 - abs(yy - 300) / 260)
            p.ellipse(x + (r.random() - 0.5) * w * 2, yy, 6 + r.random() * 8, 4 + r.random() * 4,
                      ["#2a5a2a", "#3e7a34", "#5a8a3a"][k % 3])
    p.fill_rect(0, 420, W, 100, p.lin(0, 420, 0, 520, [(0, "#6a8a4a"), (1, "#4a6a30")]))
    grass_tufts(p, 425, 515, 855, 500, col="#5a7a3a")
    water(p, 500, H, "#4a9a8a", "#1e5a58", 856, lines=110)
    # the log and the turtle's shell (his head bobs, live)
    p.fill_rect(520, 560, 200, 26, p.lin(0, 560, 0, 586, [(0, "#7a5a3a"), (1, "#4a3020")]), r=12)
    for k in range(5):
        p.ellipse(560 + k * 34, 572, 10, 3, hexc("#3a2414", 0.5))
    p.ellipse(620, 552, 28, 14, p.lin(592, 0, 648, 0, [(0, "#3a5a2a"), (1, "#5a7a3a")]))
    for k in range(5):
        p.ellipse(606 + k * 7, 550, 4, 3, hexc("#2a4a1a", 0.6))
    p.ellipse(620, 590, 110, 8, hexc("#0a2a28", 0.35))
    p.grain(0.015, 857)
    return p


# ------------------------------------------------------------------ the summer storm (clouds, rain, lightning, the rainbow are live)
def storm(light):
    p = Paint()
    dark = light == "dark"
    sky(p, 640, [(0, "#2a2e3a" if dark else "#3a72d8"), (1, "#5a5e66" if dark else "#d0e4f6")])
    hill_band(p, 630, 20, "#2a3a26" if dark else "#5a8a4a", 860, bottom=680)
    p.fill_rect(0, 640, W, H - 640, p.lin(0, 640, 0, H, [(0, "#2e4a24" if dark else "#5a8a3a"), (1, "#1a2a14" if dark else "#3a6a28")]))
    grass_tufts(p, 650, H, 861, 900, col="#2a4a20" if dark else "#4a7a30")
    # a farmhouse far off, a windbreak of trees
    p.fill_rect(560, 590, 90, 50, "#d8d0c0" if not dark else "#5a5850")
    p.poly([(552, 592), (658, 592), (605, 560)], "#7a3a2a" if not dark else "#3a2a26")
    for k in range(8):
        p.circle(40 + k * 50, 620, 26, "#2e5a2a" if not dark else "#1a2a18")
    if dark:
        p.fill_rect(0, 0, W, H, hexc("#1a1e2a", 0.25))
    p.grain(0.018, 862)
    return p


# ------------------------------------------------------------------ fireflies on the porch (the swing and its riders, the fireflies are live)
def porch(light):
    p = Paint()
    late = light == "night"
    sky(p, 700, [(0, "#0a0c22" if late else "#5a4a8a"), (1, "#1a1a3a" if late else "#ff9a5a")])
    if late:
        stars(p, 220, 600, 870)
    hill_band(p, 690, 16, "#141a10" if late else "#2a3a20", 871, bottom=720)
    p.fill_rect(0, 680, W, H - 680, p.lin(0, 680, 0, H, [(0, "#1e2a16" if late else "#2a3a1e"), (1, "#0e140a")]))
    live_oak(p, 150, 720, 1.25, "dawn" if not late else "day", 872)
    if late:
        p.fill_rect(0, 0, W, H, hexc("#000814", 0.35))
    # the porch: floor, posts, the beam the swing hangs from, the lit window, a screen door
    p.fill_rect(420, 700, 348, 30, "#4a3424")
    p.fill_rect(420, 730, 348, 294, "#2a1e14")
    for x in (440, 740):
        p.fill_rect(x, 480, 12, 220, "#5a4230")
    p.fill_rect(430, 470, 338, 16, "#5a4230")
    p.fill_rect(560, 420, 210, 280, "#3a2a20")
    p.fill_rect(600, 500, 40, 50, "#ffd890")
    p.glow(620, 525, 80, "#ffc070", 0.45 if late else 0.3)
    p.fill_rect(619, 500, 2, 50, "#3a2a20")
    p.fill_rect(600, 524, 40, 2, "#3a2a20")
    p.fill_rect(680, 560, 50, 140, hexc("#1a120c", 0.9))
    p.glow(720, 690, 20, "#ffd890", 0.4)
    p.grain(0.015, 873)
    return p


PAINTS = {
    "open": open_screen,
    "lake": lake,
    "springs": springs,
    "snocone": snocone,
    "tubing": tubing,
    "storm_clear": lambda: storm("clear"),
    "storm_dark": lambda: storm("dark"),
    "porch_dusk": lambda: porch("dusk"),
    "porch_night": lambda: porch("night"),
    "finale": finale,
}
