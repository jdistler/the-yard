"""The Egg Hunt's pictures (easter.lua). Painted: the bluebonnet meadow (and with the hunt's live oak), the
kitchen with the dye cups, the cascarones fiesta's yard. The eggs, the dipping, the bunny, the confetti, the
cartons and the secret level live.
"""
import math

from paint import Paint, W, H, hexc, mix, rng
from scenery import cloud, live_oak, hill_band, haze, wildflowers, grass_tufts


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


def meadow(oak=False):
    p = Paint()
    sky(p, 580, [(0, "#4a8ae8"), (1, "#dcecfa")])
    for i, (x, y, s) in enumerate([(150, 150, 0.8), (480, 110, 0.7), (680, 220, 0.55)]):
        cloud(p, x, y, s, hexc("#ffffff", 0.96), hexc("#c8d8ec", 0.96), 1000 + i)
    hill_band(p, 545, 30, "#7a9aa0", 1003, top_col="#8aaab0")
    haze(p, 470, 580, "#dcecfa", 0.4)
    hill_band(p, 575, 22, "#5a8a50", 1004, top_col="#6a9a5a")
    p.fill_rect(0, 560, W, H - 560, p.lin(0, 560, 0, H, [(0, "#5a9a40"), (1, "#2e6a20")]))
    grass_tufts(p, 565, H, 1005, 1000)
    wildflowers(p, 568, H, 1006, 4200)
    if oak:
        live_oak(p, 110, 610, 1.4, "day", 1007)
    p.grain(0.018, 1008)
    return p


def kitchen():
    p = Paint()
    p.fill_rect(0, 0, W, 640, p.lin(0, 0, 0, 640, [(0, "#fff6e4"), (1, "#f4e2c8")]))
    for y in range(0, 640, 34):
        for x in range((y // 34 % 2) * 17, W, 34):
            p.fill_rect(x + 1, y + 1, 32, 32, hexc("#ffffff", 0.22))
    # the window: spring outside
    p.fill_rect(250, 60, 268, 220, "#ffffff")
    p.fill_rect(260, 70, 248, 200, p.lin(0, 70, 0, 270, [(0, "#8ac0f0"), (1, "#e0f0d0")]))
    p.cr.save()
    p.cr.rectangle(260, 70, 248, 200)
    p.cr.clip()
    hill_band(p, 230, 14, "#6a9a50", 1010, bottom=270)
    p.cr.restore()
    p.fill_rect(380, 70, 8, 200, "#ffffff")
    for side in (0, 1):
        cx = 228 if side == 0 else 492
        p.fill_rect(cx, 50, 48, 250, p.lin(cx, 0, cx + 48, 0, [(0, "#f4a0b8"), (0.5, "#ffc0d0"), (1, "#f4a0b8")]))
    # the table and the six cups of dye (the egg dipping is live)
    p.fill_rect(0, 640, W, H - 640, p.lin(0, 640, 0, H, [(0, "#d8a878"), (1, "#a8784a")]))
    for i in range(10):
        p.fill_rect(0, 650 + i * 38, W, 1.5, hexc("#7a4a24", 0.35))
    cols = ["#ff4d73", "#4d99ff", "#ffd933", "#4dd966", "#a666f2", "#ff8c33"]
    for i, c in enumerate(cols):
        x = 84 + i * 120
        p.ellipse(x + 3, 672, 50, 10, hexc("#5a3a20", 0.3))
        p.fill_rect(x - 44, 560, 88, 110, hexc("#f0f4ff", 0.7), r=6)
        p.fill_rect(x - 40, 590, 80, 76, hexc(c, 0.9), r=4)
        p.fill_rect(x - 40, 590, 80, 6, hexc("#ffffff", 0.35), r=3)
        p.fill_rect(x - 36, 566, 8, 96, hexc("#ffffff", 0.5), r=3)
    # an egg carton waiting
    p.fill_rect(560, 860, 180, 56, "#c8b8a0", r=6)
    for k in range(6):
        p.ellipse(578 + k * 29, 876, 12, 10, "#e8dcc8")
    p.grain(0.015, 1011)
    return p


def fiesta():
    p = Paint()
    sky(p, 720, [(0, "#5ab0f0"), (1, "#ffe6b8")])
    cloud(p, 600, 320, 0.6, hexc("#ffffff", 0.95), hexc("#d8d8e4", 0.95), 1020)
    # papel picado overhead: two strings of cut-paper flags
    cols = ["#ff4d80", "#4db3ff", "#ffd933", "#66d966", "#bf73ff", "#ff8c33"]
    for row in range(2):
        p.line([(0, 80 + row * 120), (W, 100 + row * 120)], "#5a5a5a", 2)
        for i in range(10):
            c = cols[(i + row) % 6]
            x = i * 80 + row * 40
            y = 82 + row * 120 + i * 2
            p.fill_rect(x, y, 64, 70, c)
            for k in range(4):
                p.circle(x + 10 + k * 15, y + 14, 4, hexc("#ffffff", 0.5))
            p.circle(x + 32, y + 34, 10, hexc("#ffffff", 0.55))
            p.fill_rect(x + 12, y + 52, 40, 6, hexc("#ffffff", 0.55))
            for k in range(7):
                p.poly([(x + k * 9, y + 70), (x + k * 9 + 9, y + 70), (x + k * 9 + 4.5, y + 76)], c)
    # the yard
    p.fill_rect(0, 720, W, H - 720, p.lin(0, 720, 0, H, [(0, "#8ab04a"), (1, "#5a8a30")]))
    grass_tufts(p, 724, H, 1021, 900, col="#6a9a3a")
    # the table (its cartons are live), its sign
    p.fill_rect(200, 560, 368, 22, p.lin(0, 560, 0, 582, [(0, "#8a5a34"), (1, "#5a3a1e")]), r=4)
    p.fill_rect(220, 582, 16, 120, "#5a3a1e")
    p.fill_rect(532, 582, 16, 120, "#5a3a1e")
    p.fill_rect(196, 440, 376, 60, "#ffffff", r=8)
    label(p, 384, 482, "CASCARONES  50¢", 30, "#d82a73")
    p.grain(0.015, 1022)
    return p


PAINTS = {
    "meadow": lambda: meadow(False),
    "meadow_oak": lambda: meadow(True),
    "kitchen": kitchen,
    "fiesta": fiesta,
}
