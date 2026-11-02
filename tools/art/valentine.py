"""The Valentine's show's pictures (valentine.lua). The maze and the heart of dots stay black (arcade); painted:
the night sky, the candy wall and table, Pinky's door, Pac's Diner.
"""
import math

from paint import Paint, W, H, hexc, mix, rng
from scenery import stars, hill_band


def sky(p, y1, stops):
    p.fill_rect(0, 0, W, y1, p.lin(0, 0, 0, y1, stops))


def heart_path(p, x, y, s):
    cr = p.cr
    cr.move_to(x, y + s * 1.25)
    cr.curve_to(x - s * 1.4, y + s * 0.3, x - s * 1.1, y - s * 0.9, x, y - s * 0.25)
    cr.curve_to(x + s * 1.1, y - s * 0.9, x + s * 1.4, y + s * 0.3, x, y + s * 1.25)
    cr.close_path()


def heart(p, x, y, s, col):
    heart_path(p, x, y, s)
    p.src(col)
    p.cr.fill()


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


def rose(p, x, y, s):
    for i, (rr, c) in enumerate([(26, "#7a0e18"), (21, "#a8142a"), (15, "#c8243a"), (9, "#e04058")]):
        for k in range(5):
            a = k / 5 * 2 * math.pi + i * 0.6
            p.ellipse(x + math.cos(a) * rr * 0.35 * s, y + math.sin(a) * rr * 0.3 * s, rr * 0.62 * s, rr * 0.5 * s, c)


def night():
    p = Paint()
    sky(p, H, [(0, "#14061e"), (0.6, "#3a0c34"), (1, "#5a1838")])
    stars(p, 260, 800, 900)
    p.glow(384, 400, 460, "#ff6fa8", 0.15, 0.8)
    r = rng(901)
    for i in range(60):
        x, y = r.random() * W, 700 + r.random() * 324
        p.cr.save()
        p.cr.translate(x, y)
        p.cr.rotate(r.random() * 6.28)
        p.ellipse(0, 0, 7, 4, hexc(["#c8243a", "#e04058", "#ff8aa8"][i % 3], 0.55))
        p.cr.restore()
    p.grain(0.015, 902)
    return p


def candy():
    p = Paint()
    p.fill_rect(0, 0, W, 900, p.lin(0, 0, 0, 900, [(0, "#ffd0dc"), (1, "#f4a0b8")]))
    for y in range(30, 900, 80):
        for x in range((y // 80 % 2) * 40, W, 80):
            heart(p, x + 20, y, 9, hexc("#ffffff", 0.35))
    # a shelf with jars and a vase of roses
    p.fill_rect(500, 300, 240, 12, "#c87a8a")
    for i, c in enumerate(("#ff8aa8", "#a8e0ff", "#fff0a0")):
        p.fill_rect(510 + i * 74, 236, 50, 64, hexc(c, 0.6), r=8)
        p.fill_rect(514 + i * 74, 230, 42, 8, "#c87a8a", r=3)
    p.fill_rect(60, 220, 60, 80, hexc("#d8f0ff", 0.6), r=10)
    for k in range(5):
        p.line([(90, 230), (70 + k * 10, 150 + (k % 2) * 16)], "#2a6a2a", 2)
        rose(p, 70 + k * 10, 150 + (k % 2) * 16, 0.6)
    # the table
    p.fill_rect(0, 900, W, H - 900, p.lin(0, 900, 0, H, [(0, "#b86a5a"), (1, "#8a4a3e")]))
    for i in range(8):
        p.fill_rect(0, 910 + i * 14, W, 1, hexc("#5a2a20", 0.35))
    p.grain(0.015, 903)
    return p


def door():
    p = Paint()
    sky(p, H, [(0, "#14061e"), (0.6, "#2a0c2a"), (1, "#3a1428")])
    stars(p, 200, 400, 910)
    hill_band(p, 880, 10, "#1a0a16", 911)
    # Pinky's cottage: pink walls, a scalloped roof, a round window, the arched door (dark: she comes out live)
    p.fill_rect(420, 420, 300, 500, p.lin(420, 0, 720, 0, [(0, "#a85a7a"), (0.5, "#d87aa0"), (1, "#a85a7a")]))
    for k in range(12):
        p.fill_rect(420, 430 + k * 40, 300, 2, hexc("#7a3a5a", 0.4))
    p.poly([(400, 430), (740, 430), (570, 300)], "#5a2a4a")
    for k in range(6):
        y = 420 - k * 20
        half = 170 * (1 - (k + 1) / 7)
        for x in range(int(570 - half), int(570 + half), 22):
            p.ellipse(x + 11, y, 12, 8, "#7a3a5a")
    p.circle(570, 520, 34, "#3a1a2a")
    p.circle(570, 520, 28, "#ffd0e0")
    p.line([(542, 520), (598, 520)], "#3a1a2a", 3)
    p.line([(570, 492), (570, 548)], "#3a1a2a", 3)
    p.glow(570, 520, 60, "#ffb0d0", 0.4)
    p.fill_rect(492, 652, 156, 268, "#4a1e34", r=74)
    p.fill_rect(500, 660, 140, 260, "#0a0410", r=70)
    # a heart wreath, a lamp, flowers by the step
    for k in range(26):
        a = k / 26 * 2 * math.pi
        x, y = 570 + math.cos(a) * 24, 610 + math.sin(a) * 20 - abs(math.sin(a / 2)) * 0
        p.circle(x, y, 5, ["#c8243a", "#ff6fa8"][k % 2])
    p.fill_rect(670, 640, 6, 40, "#2a1a20")
    p.circle(673, 636, 9, "#ffe0b0")
    p.glow(673, 636, 50, "#ffc080", 0.55)
    for i in range(14):
        rose(p, 440 + i * 20, 918 + (i % 2) * 6, 0.5)
    p.fill_rect(470, 916, 200, 10, "#3a2030")
    p.grain(0.015, 912)
    return p


def diner():
    p = Paint()
    sky(p, 300, [(0, "#14061e"), (1, "#2a0c2a")])
    stars(p, 80, 240, 920)
    p.fill_rect(0, 300, W, 724, "#1f0f26")
    p.fill_rect(0, 300, W, 26, "#40c0c0")
    # the window: the street at night outside
    p.fill_rect(80, 360, 608, 260, p.lin(0, 360, 0, 620, [(0, "#0a0a24"), (1, "#1a1438")]))
    r = rng(921)
    for i in range(10):
        x = 90 + i * 60
        h = 60 + r.random() * 120
        p.fill_rect(x, 620 - h, 50, h, "#120e28")
        for k in range(int(h / 20)):
            if r.random() < 0.5:
                p.fill_rect(x + 8 + (k % 3) * 12, 620 - h + 8 + k * 18, 8, 10, "#ffd890")
    p.fill_rect(80, 600, 608, 20, "#2a2a30")
    p.poly([(120, 360), (200, 360), (120, 470)], hexc("#e8e8ff", 0.1))
    p.fill_rect(80, 620, 608, 40, "#1f0f26")
    # the booths, the table, the jukebox, the floor
    for x in (20, 588):
        p.fill_rect(x, 640, 160, 260, p.lin(x, 0, x + 160, 0, [(0, "#a81020"), (0.5, "#d82434"), (1, "#a81020")]), r=20)
        for k in range(5):
            p.fill_rect(x + 10 + k * 30, 650, 3, 240, hexc("#7a0a14", 0.6))
    p.fill_rect(160, 790, 448, 24, p.lin(0, 790, 0, 814, [(0, "#f0f0f8"), (1, "#b8b8c4")]), r=6)
    p.fill_rect(370, 814, 28, 90, "#c8c8d0")
    p.fill_rect(330, 896, 108, 8, "#a8a8b0", r=3)
    for i in range(16):
        p.fill_rect(i * 48, 900, 48, 124, "#f4f4f8" if i % 2 == 0 else "#141418")
        p.fill_rect(i * 48, 962, 48, 62, "#141418" if i % 2 == 0 else "#f4f4f8")
    p.fill_rect(698, 380, 60, 220, p.lin(698, 0, 758, 0, [(0, "#8a3a14"), (1, "#c86a2a")]), r=26)
    p.fill_rect(706, 420, 44, 60, "#ffe0a0", r=18)
    for k in range(5):
        p.fill_rect(706, 500 + k * 16, 44, 8, ["#ff4fd8", "#4fd0ff", "#ffd23f", "#7aff6a", "#ff7a3a"][k])
    p.glow(728, 450, 60, "#ffc060", 0.4)
    p.grain(0.015, 922)
    return p


PAINTS = {"night": night, "candy": candy, "door": door, "diner": diner}
