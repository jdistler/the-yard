"""The Christmas show's pictures (christmas.lua). Each laid out under its scene's live parts (the lights twinkle,
the snow falls, the fire burns, the tree gets trimmed, the sleigh flies, the cookies go: all live).
"""
import math

from paint import Paint, W, H, hexc, mix, rng
from scenery import stars, hill_band, prickly_pear, grass_tufts

GHOSTS = ["#ff2e33", "#ff8cd8", "#40f2ff", "#ffa633"]


def sky(p, y1, stops):
    p.fill_rect(0, 0, W, y1, p.lin(0, 0, 0, y1, stops))


def label(p, x, y, text, size, col, font="serif", bold=True, align="center", rot=0):
    cr = p.cr
    cr.save()
    cr.translate(x, y)
    cr.rotate(rot)
    cr.select_font_face(font, 0, 1 if bold else 0)
    cr.set_font_size(size)
    e = cr.text_extents(text)
    p.src(col)
    cr.move_to(-(e.width / 2 + e.x_bearing) if align == "center" else 0, 0)
    cr.show_text(text)
    cr.restore()


def pine(p, x, base, h, seed, snow=True, col="#1e4a2e"):
    """A spruce: tiers of drooping boughs, snow on their tops."""
    r = rng(seed)
    tiers = 7
    p.fill_rect(x - h * 0.03, base - h * 0.12, h * 0.06, h * 0.14, "#3a2418")
    for i in range(tiers):
        k = i / tiers
        y = base - h * 0.1 - k * h * 0.85
        w = h * 0.38 * (1 - k * 0.85)
        p.fill_path([("M", x, y - h * 0.16), ("C", x + w * 0.4, y - h * 0.08, x + w * 0.9, y - h * 0.01, x + w, y + h * 0.02),
                     ("C", x + w * 0.5, y + h * 0.0, x - w * 0.5, y + h * 0.0, x - w, y + h * 0.02),
                     ("C", x - w * 0.9, y - h * 0.01, x - w * 0.4, y - h * 0.08, x, y - h * 0.16), ("Z",)],
                    p.lin(x - w, 0, x + w, 0, [(0, mix(col, "#000000", 0.35)), (0.6, col), (1, mix(col, "#000000", 0.15))]))
        if snow:
            p.fill_path([("M", x, y - h * 0.16), ("C", x + w * 0.3, y - h * 0.1, x + w * 0.6, y - h * 0.06, x + w * 0.8, y - h * 0.02),
                         ("C", x + w * 0.4, y - h * 0.05, x - w * 0.4, y - h * 0.05, x - w * 0.8, y - h * 0.02),
                         ("C", x - w * 0.6, y - h * 0.06, x - w * 0.3, y - h * 0.1, x, y - h * 0.16), ("Z",)], "#f4f8ff")


def snow_ground(p, y, seed, col0="#e8eefc", col1="#b8c4e4"):
    hill_band(p, y, 10, col0, seed, top_col="#ffffff")
    p.fill_rect(0, y + 10, W, H - y - 10, p.lin(0, y, 0, H, [(0, col0), (1, col1)]))
    r = rng(seed + 1)
    for i in range(200):
        p.circle(r.random() * W, y + 10 + r.random() * (H - y), 0.8 + r.random(), hexc("#ffffff", 0.7))


def snowman(p, x, y, s, tumbleweed=False):
    if tumbleweed:
        r = rng(int(x))
        for (dy, rr) in ((0, 34), (-52, 26), (-90, 18)):
            p.circle(x, y + dy * s, rr * s, "#a8885a")
            for i in range(30):
                a = r.random() * 6.28
                p.line([(x + math.cos(a) * rr * 0.2 * s, y + dy * s + math.sin(a) * rr * 0.2 * s),
                        (x + math.cos(a + 1) * rr * s, y + dy * s + math.sin(a + 1) * rr * s)], "#6a4a2a", 1.2)
        p.ellipse(x, y - 108 * s, 22 * s, 5 * s, "#3a2414")
        p.fill_rect(x - 12 * s, y - 128 * s, 24 * s, 20 * s, "#3a2414", r=4)
        p.fill_rect(x - 24 * s, y - 60 * s, 48 * s, 8 * s, "#c4202a")
        return
    for (dy, rr) in ((0, 40), (-58, 30), (-102, 22)):
        p.circle(x + 3 * s, y + dy * s + 4 * s, rr * s, hexc("#8a96c0", 0.5))
        p.circle(x, y + dy * s, rr * s, p.lin(x - rr * s, 0, x + rr * s, 0, [(0, "#ffffff"), (1, "#c8d0ec")]))
    for k in range(3):
        p.circle(x, y - 48 * s - k * 14 * s, 3.5 * s, "#2a2a30")
    p.circle(x - 8 * s, y - 108 * s, 3 * s, "#2a2a30")
    p.circle(x + 8 * s, y - 108 * s, 3 * s, "#2a2a30")
    p.poly([(x, y - 102 * s), (x + 26 * s, y - 98 * s), (x, y - 96 * s)], "#ff7a1a")
    p.fill_rect(x - 32 * s, y - 84 * s, 64 * s, 10 * s, "#c4202a", r=4)
    p.fill_rect(x + 14 * s, y - 84 * s, 10 * s, 34 * s, "#c4202a", r=3)
    p.ellipse(x, y - 122 * s, 26 * s, 5 * s, "#1a1a20")
    p.fill_rect(x - 16 * s, y - 152 * s, 32 * s, 30 * s, "#1a1a20", r=3)
    p.fill_rect(x - 16 * s, y - 130 * s, 32 * s, 5 * s, "#c4202a")
    for side in (-1, 1):
        p.line([(x + side * 28 * s, y - 60 * s), (x + side * 60 * s, y - 84 * s), (x + side * 70 * s, y - 96 * s)], "#4a3020", 3 * s)


def present(p, x, y, w, h, col, ribbon):
    p.fill_rect(x, y, w, h, p.lin(x, 0, x + w, 0, [(0, mix(col, "#000000", 0.25)), (0.4, col), (1, mix(col, "#000000", 0.1))]))
    p.fill_rect(x + w / 2 - 4, y, 8, h, ribbon)
    p.fill_rect(x, y + h / 2 - 4, w, 8, ribbon)
    p.ellipse(x + w / 2 - 10, y - 4, 10, 6, ribbon)
    p.ellipse(x + w / 2 + 10, y - 4, 10, 6, ribbon)


def night_snow_sky(p, y1, seed):
    sky(p, y1, [(0, "#04061a"), (0.7, "#141a44"), (1, "#26305e")])
    stars(p, 220, y1 - 100, seed)


# ------------------------------------------------------------------ the titles
def open_screen():
    p = Paint()
    night_snow_sky(p, H, 400)
    p.glow(384, 440, 420, "#6a7ac8", 0.25, 0.8)
    snow_ground(p, 860, 401)
    for (x, h) in ((70, 300), (170, 220), (600, 260), (700, 320), (520, 180)):
        pine(p, x, 900 + (x % 3) * 10, h, 402 + x)
    p.grain(0.015, 403)
    return p


def finale():
    p = Paint()
    sky(p, H, [(0, "#04061a"), (0.6, "#1a1030"), (1, "#3a1424")])
    stars(p, 200, 600, 410)
    snow_ground(p, 780, 411)
    for (x, h) in ((60, 360), (150, 260), (620, 300), (716, 380)):
        pine(p, x, 820 + (x % 3) * 10, h, 412 + x)
    p.glow(384, 760, 360, "#ffb060", 0.15, 0.4)
    p.grain(0.015, 413)
    return p


# ------------------------------------------------------------------ the house on the cul-de-sac (its lights, the window's tree bulbs, the inflatables, the snow are live)
def street():
    p = Paint()
    night_snow_sky(p, 720, 420)
    p.glow(640, 120, 120, "#e8f0ff", 0.35)
    p.circle(640, 120, 36, "#f6f2dc")
    p.circle(628, 112, 8, hexc("#c8c4b0", 0.5))
    # neighbours' rooflines behind
    for (x, w, top) in ((-20, 170, 540), (630, 170, 520)):
        p.poly([(x, 720), (x, top + 40), (x + w / 2, top), (x + w, top + 40), (x + w, 720)], "#121426")
        p.poly([(x - 6, top + 44), (x + w / 2, top - 2), (x + w + 6, top + 44), (x + w, top + 50), (x + w / 2, top + 10), (x, top + 50)], "#e8eefc")
        p.fill_rect(x + 30, top + 70, 26, 30, "#ffd890")
    pine(p, 690, 730, 260, 421)
    pine(p, 60, 730, 230, 422)
    # the house: siding, the roof under snow, the window, the door
    p.fill_rect(160, 470, 450, 260, p.lin(160, 0, 610, 0, [(0, "#4a2a22"), (0.5, "#6a3a2e"), (1, "#4a2a22")]))
    for k in range(16):
        p.fill_rect(160, 478 + k * 16, 450, 1.5, hexc("#000000", 0.25))
    p.poly([(130, 480), (640, 480), (520, 330), (250, 330)], p.lin(0, 330, 0, 480, [(0, "#2a1c18"), (1, "#3a2620")]))
    p.poly([(130, 482), (640, 482), (628, 462), (520, 330), (250, 330), (142, 462)], hexc("#f4f8ff", 1))
    p.poly([(146, 464), (624, 464), (516, 344), (254, 344)], p.lin(0, 344, 0, 464, [(0, "#2a1c18"), (1, "#3a2620")]))
    for i in range(6):
        p.ellipse(180 + i * 80, 482, 34, 8, "#f4f8ff")
    p.fill_rect(380, 290, 40, 70, "#5a2a22")
    p.fill_rect(374, 284, 52, 12, "#f4f8ff")
    # icicles under the eaves
    r = rng(423)
    for x in range(140, 636, 9):
        p.poly([(x, 482), (x + 6, 482), (x + 3, 490 + r.random() * 18)], hexc("#e8f4ff", 0.85))
    # the window: warm light, a tree inside (its bulbs are live)
    p.fill_rect(194, 534, 162, 132, "#2a1812")
    p.fill_rect(200, 540, 150, 120, p.lin(0, 540, 0, 660, [(0, "#ffe0a0"), (1, "#ffb860")]))
    p.poly([(275, 548), (230, 655), (320, 655)], p.lin(230, 0, 320, 0, [(0, "#0e3a1a"), (1, "#1e5a2a")]))
    p.fill_rect(270, 652, 10, 8, "#4a2a18")
    p.fill_rect(272, 540, 6, 120, "#2a1812")
    p.fill_rect(200, 597, 150, 6, "#2a1812")
    p.glow(275, 600, 160, "#ffc070", 0.25)
    p.fill_rect(190, 664, 170, 8, "#f4f8ff")
    # the door, the wreath
    p.fill_rect(436, 576, 98, 156, "#2a1812")
    p.fill_rect(440, 580, 90, 150, p.lin(440, 0, 530, 0, [(0, "#5a1612"), (1, "#7a2018")]))
    for (yy, hh) in ((592, 50), (656, 60)):
        p.fill_rect(452, yy, 66, hh, hexc("#000000", 0.15), r=4)
    p.circle(518, 660, 4, "#d8b04a")
    for k in range(28):
        a = k / 28 * 2 * math.pi
        p.circle(485 + math.cos(a) * 22, 620 + math.sin(a) * 22, 7, "#1e5a2a" if k % 2 else "#2a6a34")
    for k in range(8):
        a = k / 8 * 2 * math.pi
        p.circle(485 + math.cos(a) * 22, 620 + math.sin(a) * 22, 3, "#d8242a")
    p.poly([(474, 638), (496, 638), (485, 652)], "#d8242a")
    p.ellipse(478, 636, 8, 5, "#d8242a")
    p.ellipse(492, 636, 8, 5, "#d8242a")
    p.glow(485, 740, 60, "#ffd890", 0.4)
    # the yard: snow, the walk, the snowman
    snow_ground(p, 712, 424)
    p.poly([(452, 732), (518, 732), (600, H), (380, H)], p.lin(0, 732, 0, H, [(0, "#c8d0e8"), (1, "#a8b4d4")]))
    snowman(p, 110, 880, 1.1)
    p.grain(0.015, 425)
    return p


# ------------------------------------------------------------------ across the moon (the sleigh and the reindeer are live)
def sleigh():
    p = Paint()
    night_snow_sky(p, 800, 430)
    p.glow(384, 330, 300, "#d8e0ff", 0.35)
    p.circle(384, 330, 130, p.rad(360, 300, 10, 140, [(0, "#fffef0"), (1, "#e8e4cc")]))
    r = rng(431)
    for i in range(14):
        a = r.random() * 6.28
        rr = r.random() * 100
        p.circle(384 + math.cos(a) * rr, 330 + math.sin(a) * rr, 6 + r.random() * 18, hexc("#c8c4a8", 0.35))
    # the rooftops: snowy roofs, chimneys with smoke, lit windows
    for i in range(6):
        x = i * 140 - 20
        dy = (i % 2) * 30
        p.fill_rect(x, 820 - dy, 120, 260, p.lin(x, 0, x + 120, 0, [(0, "#0e0c1e"), (1, "#1a1830")]))
        p.poly([(x - 10, 820 - dy), (x + 130, 820 - dy), (x + 60, 760 - dy)], "#141228")
        p.fill_rect(x + 80, 760 - dy, 18, 50, "#2a1a1e")
        p.fill_rect(x + 77, 756 - dy, 24, 8, "#f4f8ff")
        p.poly([(x - 10, 820 - dy), (x + 60, 760 - dy), (x + 130, 820 - dy), (x + 120, 826 - dy), (x + 60, 770 - dy), (x, 826 - dy)], "#f4f8ff")
        for (wx, wy) in ((x + 20, 860), (x + 70, 860), (x + 20, 920), (x + 70, 920)):
            on = r.random() < 0.7
            p.fill_rect(wx, wy, 24, 30, "#ffd890" if on else "#1e1c34")
            if on:
                p.glow(wx + 12, wy + 15, 30, "#ffc060", 0.25)
            p.fill_rect(wx + 11, wy, 2, 30, "#141228")
    p.grain(0.015, 432)
    return p


# ------------------------------------------------------------------ a Texas Christmas (the lights on the cactus, the armadillo, cowboy Santa are live)
def texas():
    p = Paint()
    sky(p, 640, [(0, "#3a7ad8"), (1, "#dceefc")])
    p.glow(620, 120, 160, "#fff4c0", 0.45)
    p.circle(620, 120, 44, "#fff2c0")
    hill_band(p, 610, 20, "#8a9a6a", 440, bottom=700, top_col="#a8b480")
    p.fill_rect(0, 640, W, H - 640, p.lin(0, 640, 0, H, [(0, "#c8a46a"), (1, "#9a7a48")]))
    grass_tufts(p, 650, H, 441, 900, col="#a8904a")
    # the ranch gate: posts, the crossbar, the hanging sign, a wreath on it
    for x in (40, 300):
        p.fill_rect(x, 420, 18, 240, p.lin(x, 0, x + 18, 0, [(0, "#3a2414"), (0.5, "#6a4428"), (1, "#3a2414")]))
    p.fill_rect(30, 410, 300, 20, p.lin(0, 410, 0, 430, [(0, "#6a4428"), (1, "#3a2414")]))
    for x in (90, 270):
        p.line([(x, 430), (x, 470)], "#3a3a3a", 2)
    p.fill_rect(70, 470, 220, 70, "#f4ead2", r=6)
    p.fill_rect(70, 470, 220, 70, hexc("#8a6a40", 0.1), r=6)
    label(p, 180, 506, "IT'S 72°", 28, "#b42418", font="sans")
    label(p, 180, 532, "AND SUNNY", 20, "#4a4a52", font="sans")
    for k in range(20):
        a = k / 20 * 2 * math.pi
        p.circle(180 + math.cos(a) * 16, 392 + math.sin(a) * 16, 5, "#2a6a34")
    p.ellipse(180, 412, 7, 4, "#d8242a")
    # the prickly pear (its lights are live) and the tumbleweed snowman
    prickly_pear(p, 560, 790, 1.6, 442, col="#3a7a40")
    snowman(p, 420, 930, 0.9, tumbleweed=True)
    p.grain(0.02, 443)
    return p


# ------------------------------------------------------------------ trimming the tree (the tree, the fire, the ghosts are live)
def room():
    p = Paint()
    p.fill_rect(0, 0, W, H, p.lin(0, 0, 0, H, [(0, "#5a2018"), (1, "#2a0c08")]))
    for x in range(0, W, 52):
        p.fill_rect(x, 0, 22, 760, hexc("#7a2a20", 0.6))
        for y in range(26, 760, 60):
            p.circle(x + 37, y, 3, hexc("#d8a040", 0.35))
    p.fill_rect(0, 740, W, 20, "#3a1810")
    # the floor, a rug
    p.fill_rect(0, 760, W, H - 760, p.lin(0, 760, 0, H, [(0, "#6a3a1e"), (1, "#3a1e0e")]))
    for x in range(-40, W, 60):
        p.line([(x, 760), (x - 30, H)], hexc("#2a1408", 0.4), 1.5)
    p.ellipse(260, 930, 240, 50, hexc("#8a1a18", 0.6))
    # the fireplace: brick, the hearth, the mantel with garland, the stockings
    p.fill_rect(470, 520, 260, 260, p.lin(0, 520, 0, 780, [(0, "#8a3a28"), (1, "#5a2418")]))
    r = rng(450)
    for row in range(13):
        y = 526 + row * 20
        for x in range(470 + (row % 2) * 16, 730, 32):
            p.fill_rect(x + 1, y + 1, 30, 18, hexc("#000000" if r.random() < 0.5 else "#c86a4a", 0.12))
    p.fill_rect(520, 600, 160, 180, p.lin(0, 600, 0, 780, [(0, "#1a0a06"), (1, "#3a1a0e")]))
    p.fill_rect(500, 770, 200, 14, "#4a4a50")
    for i in range(3):
        p.fill_rect(560 + i * 30, 760, 26, 10, "#4a2a18", r=4)
    p.fill_rect(450, 500, 300, 26, p.lin(0, 500, 0, 526, [(0, "#6a3a24"), (1, "#3a1e10")]))
    for k in range(30):
        x = 452 + k * 10
        p.circle(x, 498 + math.sin(k * 0.6) * 4, 8, "#1e4a26" if k % 2 else "#2a5a30")
    for k in range(8):
        p.circle(470 + k * 38, 500, 4, ["#d8242a", "#f0c020"][k % 2])
    names = ["PAC", "BLINKY", "PINKY", "INKY", "CLYDE"]
    cols = ["#ffdc26"] + GHOSTS
    for i, nm in enumerate(names):
        sx = 470 + i * 56
        p.fill_rect(sx, 526, 34, 60, p.lin(sx, 0, sx + 34, 0, [(0, "#a8141a"), (1, "#d8242a")]))
        p.poly([(sx, 586), (sx + 34, 586), (sx + 50, 600), (sx + 40, 612), (sx, 600)], "#c41c22")
        p.fill_rect(sx - 2, 526, 38, 14, "#ffffff", r=4)
        p.circle(sx + 17, 560, 7, cols[i])
        label(p, sx + 17, 537, nm[:5], 7, "#a8141a", font="sans")
    # presents under where the tree stands
    for (x, y, col, rib) in ((60, 860, "#2a6ad8", "#f0c020"), (300, 880, "#c4202a", "#f0c020"), (160, 900, "#2a8a3a", "#ffffff"),
                             (380, 920, "#f0c020", "#c4202a")):
        present(p, x, y, 70, 50, col, rib)
    p.grain(0.015, 451)
    return p


# ------------------------------------------------------------------ cookies for Santa (the cookies, the milk's level, the sneaking ghosts are live)
def cookies():
    p = Paint()
    p.fill_rect(0, 0, W, 620, p.lin(0, 0, 0, 620, [(0, "#f8e8c8"), (1, "#e8c898")]))
    # the window: snow falling outside, night
    p.fill_rect(80, 80, 300, 300, "#f4ecd8")
    p.fill_rect(92, 92, 276, 276, p.lin(0, 92, 0, 368, [(0, "#0a1030"), (1, "#2a3a6a")]))
    stars_r = rng(460)
    for i in range(60):
        p.circle(92 + stars_r.random() * 276, 92 + stars_r.random() * 276, 1.5 + stars_r.random() * 1.5, hexc("#ffffff", 0.8))
    p.cr.save()
    p.cr.rectangle(92, 92, 276, 276)
    p.cr.clip()
    hill_band(p, 330, 8, "#e8eefc", 461, bottom=368)
    p.cr.restore()
    p.fill_rect(226, 92, 8, 276, "#f4ecd8")
    p.fill_rect(92, 226, 276, 8, "#f4ecd8")
    # a garland over the window, a candle on the sill
    for k in range(32):
        x = 70 + k * 10
        p.circle(x, 76 + math.sin(k / 31 * math.pi) * 22, 7, "#1e5a2a" if k % 2 else "#2a6a34")
    p.fill_rect(300, 330, 12, 46, "#f6efd8")
    p.ellipse(306, 326, 4, 8, "#ffd060")
    p.glow(306, 324, 40, "#ffc060", 0.6)
    # the table
    p.fill_rect(0, 620, W, H - 620, p.lin(0, 620, 0, H, [(0, "#8a5a34"), (1, "#5a3818")]))
    for y in range(640, H, 46):
        p.fill_rect(0, y, W, 2, hexc("#3a2010", 0.4))
    # the plate (its cookies are live), the gingerbread men
    p.ellipse(306, 708, 204, 72, hexc("#3a2010", 0.35))
    p.ellipse(300, 700, 200, 70, "#f4f4f6")
    p.ellipse(300, 698, 176, 58, "#e8e8ec")
    for i in range(2):
        x = 250 + i * 100
        gb = "#b8642a"
        p.circle(x, 640, 18, gb)
        p.fill_rect(x - 16, 652, 32, 40, gb, r=8)
        p.fill_rect(x - 30, 656, 60, 12, gb, r=6)
        p.fill_rect(x - 16, 684, 12, 24, gb, r=5)
        p.fill_rect(x + 4, 684, 12, 24, gb, r=5)
        p.line([(x - 10, 676), (x + 10, 676)], "#ffffff", 2)
        p.circle(x - 6, 636, 2.2, "#ffffff")
        p.circle(x + 6, 636, 2.2, "#ffffff")
        p.circle(x, 662, 2.5, "#d8242a")
        p.circle(x, 670, 2.5, "#2a8a3a")
    # the glass (the milk in it is live), the note for Santa
    p.fill_rect(556, 556, 98, 158, hexc("#ffffff", 0.35), r=8)
    p.fill_rect(560, 560, 90, 150, hexc("#e8f0ff", 0.3), r=8)
    p.fill_rect(564, 566, 8, 136, hexc("#ffffff", 0.5), r=4)
    p.cr.save()
    p.cr.translate(560, 800)
    p.cr.rotate(-0.1)
    p.fill_rect(-10, -10, 190, 120, "#fffbee")
    for k in range(4):
        p.fill_rect(-4, 18 + k * 24, 178, 1, hexc("#8ab0e0", 0.6))
    p.cr.restore()
    p.grain(0.015, 462)
    return p


# ------------------------------------------------------------------ silent night (the windows going out, the carolers, the bell, the sleigh, the star, the snow are live)
def silent():
    p = Paint()
    night_snow_sky(p, 760, 470)
    r = rng(471)
    houses = [(20, 120, 640), (150, 110, 660), (270, 90, 620), (380, 140, 650), (540, 120, 670), (670, 100, 640)]
    for (x, w, top) in houses:
        p.fill_rect(x, top, w, 760 - top + 100, p.lin(x, 0, x + w, 0, [(0, "#0e0e1e"), (1, "#181830")]))
        p.poly([(x - 8, top), (x + w + 8, top), (x + w / 2, top - 50)], "#121224")
        p.poly([(x - 8, top), (x + w / 2, top - 50), (x + w + 8, top), (x + w, top + 6), (x + w / 2, top - 40), (x, top + 6)], "#f0f4ff")
        # (the windows dark: their lights are live, going out one by one)
        for k in range(2):
            wx = x + 18 + k * (w - 60)
            p.fill_rect(wx, top + 40, 24, 30, "#16162a")
            p.fill_rect(wx + 11, top + 40, 2, 30, "#0e0e1e")
    # the church: the steeple, its window lit, a little bell tower
    p.fill_rect(440, 420, 60, 240, p.lin(440, 0, 500, 0, [(0, "#10102a"), (1, "#1c1c38")]))
    p.poly([(430, 420), (510, 420), (470, 300)], "#141430")
    p.poly([(430, 420), (470, 300), (510, 420), (502, 424), (470, 316), (438, 424)], "#e8eefc")
    p.fill_rect(468, 270, 4, 34, "#c8a860")
    p.fill_rect(462, 280, 16, 4, "#c8a860")
    p.fill_rect(458, 470, 24, 40, "#ffd08a", r=10)
    p.glow(470, 490, 50, "#ffc060", 0.35)
    snow_ground(p, 740, 472)
    for (x, h) in ((110, 160), (640, 180), (360, 120)):
        pine(p, x, 800, h, 473 + x)
    p.grain(0.015, 474)
    return p


PAINTS = {
    "open": open_screen,
    "street": street,
    "sleigh": sleigh,
    "texas": texas,
    "room": room,
    "cookies": cookies,
    "silent": silent,
    "finale": finale,
}
