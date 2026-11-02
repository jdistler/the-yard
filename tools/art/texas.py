"""The Texas show's pictures (texas.lua): A Day Across Texas. Each laid out under its scene's live parts.
"""
import math

from paint import Paint, W, H, hexc, mix, rng
from scenery import (cloud, live_oak, night_sky, hill_band, haze, water, milky_way, stars, palm, prickly_pear,
                     ocotillo, wildflowers, grass_tufts, windows_grid, crowd_band)


def sky(p, y1, stops):
    p.fill_rect(0, 0, W, y1, p.lin(0, 0, 0, y1, stops))


def label(p, x, y, text, size, col, font="sans", bold=True, center=True):
    cr = p.cr
    cr.save()
    cr.select_font_face(font, 0, 1 if bold else 0)
    cr.set_font_size(size)
    e = cr.text_extents(text)
    p.src(col)
    cr.move_to(x - (e.width / 2 + e.x_bearing if center else 0), y)
    cr.show_text(text)
    cr.restore()


# ------------------------------------------------------------------ the Lone Star at first light (the pole and the flag are live)
def open_dawn():
    p = Paint()
    sky(p, H, [(0, "#0b0d33"), (0.45, "#3a2a5e"), (0.75, "#b0587a"), (0.92, "#f0946a"), (1, "#ffc890")])
    stars(p, 120, 360, 3)
    p.glow(520, 900, 520, "#ffb070", 0.35, 0.5)
    # the land in silhouette: a ridge, a live oak, a windmill, a fence
    sil = "#140c18"
    hill_band(p, 900, 14, sil, 4)
    oak = p.layer()
    live_oak(oak, 560, 902, 0.62, "day", 6)
    cr = oak.cr
    cr.save(); cr.identity_matrix(); cr.set_operator(5); cr.set_source_rgba(0.08, 0.05, 0.1, 1); cr.paint(); cr.restore()
    p.composite(oak)
    wx, wy = 690, 905
    p.line([(wx - 18, wy), (wx, wy - 150)], sil, 3)
    p.line([(wx + 18, wy), (wx, wy - 150)], sil, 3)
    for k in range(4):
        y = wy - 30 - k * 32
        p.line([(wx - 18 + k * 4, y), (wx + 18 - k * 4, y)], sil, 1.6)
    for i in range(14):
        a = i / 14 * 2 * math.pi
        p.line([(wx, wy - 155), (wx + math.cos(a) * 26, wy - 155 + math.sin(a) * 26)], sil, 2.4)
    p.poly([(wx, wy - 158), (wx + 40, wy - 164), (wx + 42, wy - 150), (wx, wy - 152)], sil)
    for i in range(10):
        x = 230 + i * 30
        p.fill_rect(x, 884 - i * 0.8, 3, 22, sil)
    p.line([(230, 890), (520, 882)], sil, 1)
    p.fill_rect(0, 910, W, H - 910, sil)
    p.grain(0.015, 5)
    return p


# ------------------------------------------------------------------ the Gulf at Galveston (the sun, its path, the boat, the waves, the pelicans are live)
def coast(light):
    p = Paint()
    dawn = light == "dawn"
    sky(p, 560, [(0, "#141a4e" if dawn else "#3a72c8"), (0.6, "#c86a7a" if dawn else "#8ab8e6"), (1, "#ffb37a" if dawn else "#f0dcc6")])
    if dawn:
        stars(p, 50, 200, 9)
    for i, (x, y, s) in enumerate([(160, 180, 0.8), (430, 120, 0.6), (690, 230, 0.55)]):
        if dawn:
            cloud(p, x, y, s, hexc("#ffb48a", 0.9), hexc("#6a4a7a", 0.9), 20 + i)
        else:
            cloud(p, x, y, s, hexc("#ffffff", 0.95), hexc("#c0d0e6", 0.95), 20 + i)
    # the far shore: Galveston's line of buildings, faint in the haze
    far = "#6a5a7a" if dawn else "#9aaecc"
    r = rng(30)
    x = 0
    while x < 260:
        w = 18 + r.random() * 22
        hgt = 10 + r.random() * 36
        p.fill_rect(x, 556 - hgt, w, hgt + 4, far)
        x += w + 2
    # the sea
    water(p, 560, 870, "#3a3a6a" if dawn else "#2a6a98", "#2a5a72" if dawn else "#1e5a72", 31, lines=120)
    # the pier: deck, railing, piles, lamps, the bait shop at the end
    deck = "#4a3428"
    p.fill_rect(470, 740, 300, 12, deck)
    p.fill_rect(470, 752, 300, 4, "#2a1c16")
    for x in range(476, 770, 34):
        p.fill_rect(x, 756, 7, 80, p.lin(x, 0, x + 7, 0, [(0, "#2a1e18"), (1, "#5a4234")]))
        p.fill_rect(x - 1, 800, 9, 3, hexc("#ffffff", 0.15))
    for x in range(476, 770, 17):
        p.fill_rect(x, 722, 2, 18, deck)
    p.fill_rect(470, 722, 300, 3, deck)
    p.fill_rect(640, 690, 110, 50, "#e8dcc4" if not dawn else "#c8a08a")
    p.poly([(632, 692), (758, 692), (744, 672), (646, 672)], "#b8483a")
    p.fill_rect(660, 704, 24, 18, "#3a4a5a")
    p.fill_rect(700, 704, 24, 18, "#3a4a5a")
    for x in (500, 580):
        p.fill_rect(x, 700, 3, 22, "#2a2a2a")
        p.circle(x + 1.5, 698, 4, "#ffe0a0" if dawn else "#f0f0e0")
        if dawn:
            p.glow(x + 1.5, 698, 16, "#ffd08a", 0.7)
    # the beach: wet sand at the edge, dry above, shells, footprints, dune grass
    p.fill_rect(0, 866, W, H - 866, p.lin(0, 866, 0, H, [(0, "#b8a280" if dawn else "#c8b48c"), (0.12, "#e0c8a0"), (1, "#ecd8b0")]))
    p.fill_rect(0, 866, W, 18, hexc("#6a5a48", 0.35))
    for i in range(40):
        x, y = r.random() * W, 900 + r.random() * 120
        p.ellipse(x, y, 2.5, 1.6, hexc("#ffffff", 0.7))
    for i in range(12):
        x, y = 300 + i * 26, 940 + (i % 2) * 14 + i * 5
        p.ellipse(x, y, 5, 3, hexc("#9a8462", 0.5))
    grass = "#7a8a4a"
    for i in range(70):
        x = r.random() * 220
        y = 1024 - r.random() * 30
        p.line([(x, y), (x + (r.random() - 0.3) * 20, y - 30 - r.random() * 40)], grass, 1.4)
    # the palm, left
    palm(p, 60, 1024, 330, 60, 33, col="#1f3a24" if dawn else "#2f5a2a", trunk="#3a2a22" if dawn else "#6a4a30")
    p.grain(0.02, 34)
    return p


# ------------------------------------------------------------------ the Hill Country in bluebonnet season (the mockingbird, butterflies, the armadillo are live)
def hills():
    p = Paint()
    sky(p, 640, [(0, "#2f6cc8"), (0.7, "#8ab8ea"), (1, "#dcecf8")])
    for i, (x, y, s) in enumerate([(140, 150, 0.9), (460, 110, 0.7), (680, 230, 0.6), (330, 290, 0.5)]):
        cloud(p, x, y, s, hexc("#ffffff", 0.97), hexc("#bcd0e8", 0.97), 40 + i)
    hill_band(p, 560, 34, "#7a9aa8", 41, top_col="#8aaab8")
    haze(p, 480, 600, "#dcecf8", 0.45)
    hill_band(p, 615, 26, "#5a8a5e", 42, top_col="#6a9a66")
    haze(p, 560, 650, "#dcecf8", 0.25)
    hill_band(p, 690, 20, "#3e7a32", 43, top_col="#5a9040")
    live_oak(p, 150, 720, 1.25, "day", 44)
    live_oak(p, 610, 700, 0.95, "day", 45, flip=True)
    # the meadow and the flowers
    p.fill_rect(0, 700, W, H - 700, p.lin(0, 700, 0, H, [(0, "#4a8a34"), (1, "#2e6a20")]))
    grass_tufts(p, 700, H, 46, 1200)
    wildflowers(p, 704, H, 47, 5200)
    # a fence: cedar posts and wire, the one the mockingbird sits on
    for x in (520, 585, 650, 715, 780):
        top = 760 - (x - 650) * 0.06
        p.fill_rect(x, top, 14, 92, p.lin(x, 0, x + 14, 0, [(0, "#4a3424"), (0.5, "#7a5a40"), (1, "#3a2818")]))
    for k in range(3):
        p.line([(500, 780 + k * 22), (W, 772 + k * 22)], hexc("#3a3a3a", 0.8), 1.2)
    prickly_pear(p, 60, 1000, 1.0, 48)
    p.grain(0.018, 49)
    return p


# ------------------------------------------------------------------ Round Rock: Brushy Creek's round rock (ripples, foam are live); the donuts
def creek():
    p = Paint()
    sky(p, 520, [(0, "#3a72c8"), (1, "#cfe2f4")])
    cloud(p, 200, 140, 0.8, hexc("#ffffff", 0.96), hexc("#c0d2e8", 0.96), 50)
    cloud(p, 590, 90, 0.6, hexc("#ffffff", 0.96), hexc("#c0d2e8", 0.96), 51)
    hill_band(p, 470, 14, "#3e6a34", 52, bottom=620, top_col="#5a8a46")
    live_oak(p, 90, 560, 1.05, "day", 53)
    live_oak(p, 680, 545, 0.88, "day", 54, flip=True)
    # the limestone bank, in shelves
    p.fill_rect(0, 556, W, 90, p.lin(0, 556, 0, 646, [(0, "#d8ceb4"), (1, "#a89a7c")]))
    r = rng(55)
    for k in range(4):
        y = 566 + k * 20
        p.fill_rect(0, y, W, 2, hexc("#7a6c54", 0.6))
        for i in range(30):
            x = r.random() * W
            p.fill_rect(x, y - 16, 1.2, 16, hexc("#7a6c54", 0.4))
    # the creek
    water(p, 640, 900, "#3a7a7e", "#1e5258", 56, lines=90)
    p.fill_rect(0, 640, W, 8, hexc("#ffffff", 0.18))
    # the rock: a great round boulder of limestone, sunlit on top, wet at the waterline
    p.ellipse(392, 802, 120, 30, hexc("#0a2a2c", 0.45))
    p.ellipse(384, 760, 112, 72, p.lin(300, 690, 470, 830, [(0, "#efe6d2"), (0.5, "#c8bca0"), (1, "#7a7058")]))
    for i in range(40):
        a = r.random() * 2 * math.pi
        rr = r.random() ** 0.5
        p.ellipse(384 + math.cos(a) * 90 * rr, 760 + math.sin(a) * 56 * rr, 3 + r.random() * 5, 1.5 + r.random() * 3,
                  hexc("#5a5040" if r.random() < 0.5 else "#ffffff", 0.18))
    p.ellipse(356, 728, 62, 26, hexc("#ffffff", 0.18))
    p.fill_rect(272, 800, 224, 16, hexc("#2a4a48", 0.35))
    # the near bank: gravel, grass
    p.fill_rect(0, 896, W, H - 896, p.lin(0, 896, 0, H, [(0, "#b8ac90"), (1, "#8a7c62")]))
    for i in range(500):
        p.ellipse(r.random() * W, 900 + r.random() * 124, 2 + r.random() * 3, 1.5 + r.random() * 2, hexc("#ffffff" if r.random() < 0.4 else "#3a3022", 0.25))
    grass_tufts(p, 950, H, 57, 400, col="#5a7a3a")
    p.grain(0.02, 58)
    return p


def donuts():
    p = Paint()
    p.fill_rect(0, 0, W, H, p.lin(0, 0, 0, H, [(0, "#fbe3b8"), (1, "#e8a860")]))
    p.glow(384, 300, 500, "#fff0c8", 0.4, 0.8)
    # the counter
    p.fill_rect(0, 800, W, H - 800, p.lin(0, 800, 0, H, [(0, "#c8a07a"), (1, "#9a7050")]))
    for i in range(12):
        p.fill_rect(0, 810 + i * 18, W, 1, hexc("#6a4a30", 0.25))
    # the box: lid up, the inside, the shadow
    p.ellipse(390, 800, 330, 26, hexc("#4a2a10", 0.35))
    p.poly([(104, 420), (664, 420), (620, 300), (148, 300)], p.lin(0, 300, 0, 420, [(0, "#e8e2d8"), (1, "#c8c0b4")]))
    label(p, 384, 380, "ROUND ROCK", 40, "#d86a18", font="serif")
    p.fill_rect(104, 420, 560, 360, p.lin(0, 420, 0, 780, [(0, "#ffffff"), (1, "#e8e2d8")]), r=14)
    p.fill_rect(116, 432, 536, 336, "#f6efe2", r=10)
    # six glazed donuts: dough, the glaze running, its shine, the hole
    r = rng(60)
    for row in range(2):
        for c in range(3):
            x, y = 210 + c * 174, 520 + row * 160
            p.ellipse(x + 4, y + 8, 76, 64, hexc("#7a4a20", 0.25))
            p.ellipse(x, y, 72, 62, p.lin(x - 72, y - 62, x + 72, y + 62, [(0, "#e89a48"), (1, "#a85a20")]))
            glaze = p.lin(x - 66, y - 60, x + 66, y + 50, [(0, "#ffd890"), (0.5, "#f0a848"), (1, "#c8742a")])
            cr = p.cr
            cr.save()
            cr.translate(x, y - 4)
            cr.move_to(66, 0)
            for i in range(1, 41):
                a = i / 40 * 2 * math.pi
                rr = 1 + 0.06 * math.sin(a * 7 + c + row)
                cr.line_to(math.cos(a) * 66 * rr, math.sin(a) * 54 * rr)
            cr.close_path()
            cr.restore()
            p.src(glaze)
            cr.fill()
            p.ellipse(x - 26, y - 28, 22, 8, hexc("#fffbe8", 0.65))
            p.ellipse(x + 30, y + 22, 14, 5, hexc("#fffbe8", 0.25))
            p.ellipse(x, y - 2, 19, 15, "#f6efe2")
            p.ellipse(x, y + 2, 19, 13, hexc("#a85a20", 0.45))
            for k in range(14):
                a = r.random() * 2 * math.pi
                p.ellipse(x + math.cos(a) * 46, y + math.sin(a) * 38, 3, 1.4, hexc("#fff4d0", 0.5))
    p.grain(0.015, 61)
    return p


# ------------------------------------------------------------------ Austin: the Capitol up Congress Avenue (the cars, lane dashes, the busker's notes are live)
def capitol(p, x, base):
    pink = "#e2b4a4"
    pink_sh = "#b88070"
    pink_lt = "#f2cebe"
    # the wings
    p.fill_rect(x - 300, base - 120, 600, 120, p.lin(0, base - 120, 0, base, [(0, pink_lt), (1, pink)]))
    p.fill_rect(x - 304, base - 126, 608, 8, pink_lt)
    for i in range(12):
        wx = x - 282 + i * 48
        if abs(wx + 9 - x) < 60:
            continue
        for wy in (base - 104, base - 58):
            p.fill_rect(wx, wy, 18, 30, "#5a4a52")
            p.fill_rect(wx, wy, 18, 4, pink_lt)
    # the portico: pediment, columns
    p.poly([(x - 84, base - 120), (x + 84, base - 120), (x, base - 162)], p.lin(0, base - 162, 0, base - 120, [(0, pink_lt), (1, pink)]))
    p.poly([(x - 70, base - 124), (x + 70, base - 124), (x, base - 154)], hexc(pink_sh, 0.5))
    for i in range(6):
        cx = x - 66 + i * 26
        p.fill_rect(cx, base - 118, 12, 100, p.lin(cx, 0, cx + 12, 0, [(0, pink_sh), (0.5, pink_lt), (1, pink_sh)]))
    # the drum: two tiers of columns
    p.fill_rect(x - 94, base - 252, 188, 132, p.lin(x - 94, 0, x + 94, 0, [(0, pink_sh), (0.4, pink_lt), (1, pink)]))
    for i in range(9):
        cx = x - 84 + i * 21
        p.fill_rect(cx, base - 244, 7, 112, p.lin(cx, 0, cx + 7, 0, [(0, pink_lt), (1, pink_sh)]))
        p.fill_rect(cx + 8, base - 236, 11, 40, "#5a4a52")
        p.fill_rect(cx + 8, base - 180, 11, 40, "#5a4a52")
    p.fill_rect(x - 104, base - 264, 208, 14, pink_lt)
    # the dome, ribbed
    cr = p.cr
    cr.save()
    cr.arc(x, base - 262, 100, math.pi, 2 * math.pi)
    cr.close_path()
    cr.restore()
    p.src(p.lin(x - 100, 0, x + 100, 0, [(0, pink_sh), (0.35, pink_lt), (1, pink)]))
    cr.fill()
    for i in range(-4, 5):
        a = math.pi / 2 + i * 0.32
        p.line([(x + math.cos(a + math.pi) * 0, base - 360), (x - math.sin(i * 0.32) * 100, base - 262 - math.cos(i * 0.32) * 4)],
               hexc(pink_sh, 0.6), 1.6)
    for k in range(3):
        yy = base - 290 - k * 22
        half = math.sqrt(max(0, 100 ** 2 - (base - 262 - yy) ** 2))
        for i in range(-4, 5):
            p.fill_rect(x + i * half / 5 - 3, yy, 6, 9, hexc("#5a4a52", 0.8))
    # the lantern and the Goddess of Liberty
    p.fill_rect(x - 18, base - 392, 36, 34, pink_lt)
    for i in range(4):
        p.fill_rect(x - 14 + i * 8, base - 386, 4, 24, "#5a4a52")
    p.arc_pie = None
    cr.save()
    cr.arc(x, base - 392, 18, math.pi, 2 * math.pi)
    cr.close_path()
    cr.restore()
    p.src(pink)
    cr.fill()
    p.fill_rect(x - 3, base - 430, 6, 22, "#c8a860")
    p.circle(x, base - 434, 4, "#c8a860")
    p.line([(x + 2, base - 430), (x + 8, base - 444)], "#c8a860", 2)
    p.circle(x + 8, base - 446, 2.6, "#ffe8a0")


def austin():
    p = Paint()
    sky(p, 700, [(0, "#2f68c4"), (0.7, "#8ab8ea"), (1, "#d8e8f6")])
    cloud(p, 160, 140, 0.8, hexc("#ffffff", 0.96), hexc("#c0d2e8", 0.96), 70)
    cloud(p, 610, 100, 0.65, hexc("#ffffff", 0.96), hexc("#c0d2e8", 0.96), 71)
    # downtown behind: glass towers, haze-blue
    r = rng(72)
    for (x, hgt, w) in [(10, 300, 60), (76, 380, 54), (136, 270, 64), (560, 420, 58), (624, 330, 64), (694, 450, 70)]:
        p.fill_rect(x, 700 - hgt, w, hgt, p.lin(x, 0, x + w, 0, [(0, "#7a90b0"), (0.6, "#a8bcd8"), (1, "#8aa0c0")]))
        for k in range(int(hgt / 12)):
            p.fill_rect(x + 4, 700 - hgt + 8 + k * 12, w - 8, 2, hexc("#ffffff", 0.18))
    p.poly([(694, 250), (764, 250), (729, 210)], "#8aa0c0")
    haze(p, 300, 700, "#d8e8f6", 0.35)
    # the Tower beyond, small and pale
    tx = 502
    p.fill_rect(tx - 20, 330, 40, 370, p.lin(tx - 20, 0, tx + 20, 0, [(0, "#c8bea8"), (1, "#e8e0cc")]))
    for k in range(16):
        p.fill_rect(tx - 14, 340 + k * 20, 28, 8, hexc("#7a7468", 0.45))
    p.fill_rect(tx - 26, 300, 52, 34, "#e8e0cc")
    p.circle(tx, 318, 9, "#f4efe2")
    p.poly([(tx - 24, 300), (tx + 24, 300), (tx, 270)], "#c86a4a")
    capitol(p, 384, 700)
    # trees along the avenue's sides
    for side in (-1, 1):
        for i, (yy, s) in enumerate([(712, 0.35), (740, 0.5), (790, 0.7)]):
            x = 384 + side * (60 + (yy - 700) * 1.2 + 110 * s)
            p.circle(x, yy - 40 * s, 36 * s, "#3a6a2a")
            p.circle(x + side * 10 * s, yy - 52 * s, 24 * s, "#5a8a3a")
            p.fill_rect(x - 3 * s, yy - 14 * s, 6 * s, 20 * s, "#4a3424")
    # Congress Avenue: asphalt, the curbs, the sidewalks, storefronts at the sides
    p.poly([(0, 700), (330, 700), (0, 820)], "#8a9a6a")
    p.poly([(W, 700), (438, 700), (W, 820)], "#8a9a6a")
    p.poly([(330, 700), (438, 700), (W, H), (0, H)], p.lin(0, 700, 0, H, [(0, "#4a4a52"), (1, "#2e2e34")]))
    p.poly([(330, 700), (322, 700), (-20, H), (0, H)], "#cfc8b8")
    p.poly([(438, 700), (446, 700), (W + 20, H), (W, H)], "#cfc8b8")
    for i in range(30):
        y = 702 + (i / 30) ** 2 * 322
        k = (y - 700) / 324
        p.fill_rect(330 - 330 * k + 10, y, 1 + k * 3, 1 + k * 4, hexc("#ffffff", 0.08))
    # the taco truck, parked on the right
    tx0, ty0 = 600, 830
    p.fill_rect(tx0, ty0, 150, 80, p.lin(0, ty0, 0, ty0 + 80, [(0, "#ffffff"), (1, "#dcd8d0")]), r=8)
    p.fill_rect(tx0, ty0, 150, 22, "#2a9a8a", r=8)
    label(p, tx0 + 75, ty0 + 17, "TACOS", 17, "#ffffff")
    p.fill_rect(tx0 + 18, ty0 + 30, 70, 32, "#2a2a30")
    p.fill_rect(tx0 + 14, ty0 + 30, 78, 6, "#e8402a")
    for i in range(4):
        p.fill_rect(tx0 + 20 + i * 16, ty0 + 34, 12, 4, ["#e8402a", "#f0c020", "#2a9a4a", "#ffffff"][i])
    p.fill_rect(tx0 + 104, ty0 + 30, 34, 50, "#3a3a44")
    for wx in (tx0 + 26, tx0 + 124):
        p.circle(wx, ty0 + 82, 13, "#1a1a1e")
        p.circle(wx, ty0 + 82, 6, "#8a8a90")
    p.fill_rect(tx0 + 92, ty0 + 70, 12, 6, "#c8c8cc")
    # the busker: a stool, him (the guitar's neck and notes are live)
    p.fill_rect(84, 896, 36, 6, "#5a3a24")
    p.fill_rect(88, 902, 4, 22, "#5a3a24")
    p.fill_rect(112, 902, 4, 22, "#5a3a24")
    p.fill_rect(92, 856, 20, 44, "#2a3a5a", r=4)
    p.fill_rect(94, 898, 7, 26, "#22304a")
    p.fill_rect(104, 898, 7, 26, "#22304a")
    p.circle(102, 846, 9, "#e8c0a0")
    p.ellipse(102, 840, 12, 4, "#e8d0a0")
    p.fill_rect(96, 828, 12, 12, "#e8d0a0", r=3)
    p.ellipse(112, 888, 17, 13, p.lin(96, 0, 128, 0, [(0, "#7a4018"), (1, "#c8742a")]))
    p.circle(112, 888, 4, "#2a1a10")
    p.fill_rect(70, 904, 22, 12, "#3a2a1a", r=3)
    p.grain(0.018, 73)
    return p


# ------------------------------------------------------------------ Fort Worth: the Stockyards (the cattle drive is live)
def stockyards():
    p = Paint()
    sky(p, 520, [(0, "#3a6ac0"), (0.7, "#a8c0e0"), (1, "#f8d8a0")])
    cloud(p, 380, 90, 0.7, hexc("#fff8ec", 0.95), hexc("#d8c0b0", 0.95), 80)
    fronts = [(0, 200, "#9a5a40", "SALOON"), (200, 170, "#c09a70", "BOOTS"), (370, 200, "#8a6a50", "HOTEL"),
              (570, 198, "#a8604a", "GENERAL STORE")]
    r = rng(81)
    for (x, w, col, name) in fronts:
        # the false front, the building, its brick or boards
        p.fill_rect(x, 420, w, 330, p.lin(0, 420, 0, 750, [(0, mix(col, "#ffffff", 0.12)), (1, mix(col, "#000000", 0.2))]))
        p.fill_rect(x + 10, 372, w - 20, 50, mix(col, "#ffffff", 0.08))
        p.fill_rect(x + 6, 366, w - 12, 8, mix(col, "#000000", 0.3))
        for k in range(22):
            y = 424 + k * 15
            p.fill_rect(x, y, w, 1, hexc("#000000", 0.12))
            for i in range(8):
                p.fill_rect(x + ((k % 2) * 12 + i * 24) % w, y, 1, 15, hexc("#000000", 0.08))
        p.fill_rect(x + 14, 384, w - 28, 26, "#f4ead2")
        label(p, x + w / 2, 404, name, 17, "#5a2a14", font="serif")
        # windows with shutters, the door
        for i in range(2):
            wx = x + 26 + i * (w - 92)
            p.fill_rect(wx, 476, 44, 62, "#2a2226")
            p.fill_rect(wx + 2, 478, 40, 58, p.lin(0, 478, 0, 536, [(0, "#4a5a6a"), (1, "#2a3440")]))
            p.fill_rect(wx + 20, 478, 3, 58, "#2a2226")
            p.fill_rect(wx - 4, 474, 52, 4, "#f4ead2")
        p.fill_rect(x + w / 2 - 20, 640, 40, 110, "#2a1e18")
        p.fill_rect(x + w / 2 - 17, 644, 34, 50, "#5a4a3a")
        # the porch: roof, posts, rail
        p.fill_rect(x, 596, w, 12, "#4a3424")
        p.poly([(x, 596), (x + w, 596), (x + w, 588), (x, 588)], "#6a4a30")
        for px in range(int(x) + 4, int(x + w) - 4, 46):
            p.fill_rect(px, 608, 6, 142, "#5a3e28")
        p.fill_rect(x, 700, w, 4, "#5a3e28")
    # the arch over Exchange Avenue
    p.fill_rect(118, 230, 14, 520, "#2a2a30")
    p.fill_rect(636, 230, 14, 520, "#2a2a30")
    cr = p.cr
    cr.set_line_width(10)
    cr.arc(384, 380, 260, math.pi + 0.55, 2 * math.pi - 0.55)
    p.src("#2a2a30")
    cr.stroke()
    p.fill_rect(196, 188, 376, 54, "#2a2a30", r=6)
    p.fill_rect(200, 192, 368, 46, "#f4ecd8", r=6)
    label(p, 384, 224, "FORT WORTH STOCKYARDS", 26, "#8a2a1a", font="serif")
    # the brick street
    p.fill_rect(0, 750, W, H - 750, p.lin(0, 750, 0, H, [(0, "#9a4a34"), (1, "#7a3a2a")]))
    for row in range(16):
        y = 754 + row * 18
        p.fill_rect(0, y, W, 2, hexc("#3a1810", 0.55))
        for x in range((row % 2) * 22, W, 44):
            p.fill_rect(x, y, 2, 18, hexc("#3a1810", 0.45))
            if r.random() < 0.25:
                p.fill_rect(x + 2, y + 2, 40, 14, hexc("#ffffff" if r.random() < 0.5 else "#000000", 0.05))
    p.grain(0.02, 82)
    return p


# ------------------------------------------------------------------ San Antonio: the Alamo (the birds are live)
def alamo():
    p = Paint()
    sky(p, 760, [(0, "#2f62bc"), (0.7, "#8ab4e6"), (1, "#dce8f4")])
    cloud(p, 560, 140, 0.8, hexc("#ffffff", 0.96), hexc("#c0d2e8", 0.96), 90)
    stone, sh, lt = "#e6d8b8", "#b8a888", "#f4ead2"
    x0, x1, top, base = 170, 598, 360, 760
    # the facade, its famous curved parapet
    cr = p.cr
    cr.move_to(x0, base)
    cr.line_to(x0, top + 60)
    cr.line_to(x0 + 70, top + 60)
    cr.line_to(x0 + 70, top + 80)
    cr.line_to(x0 + 110, top + 80)
    for i in range(0, 41):
        u = i / 40
        b = 1 - (2 * u - 1) ** 2
        cr.line_to(x0 + 110 + u * (x1 - x0 - 220), top + 80 - b * b * 86 - (8 if abs(u - 0.5) < 0.08 else 0))
    cr.line_to(x1 - 70, top + 80)
    cr.line_to(x1 - 70, top + 60)
    cr.line_to(x1, top + 60)
    cr.line_to(x1, base)
    cr.close_path()
    p.src(p.lin(x0, 0, x1, 0, [(0, sh), (0.15, stone), (0.7, lt), (1, stone)]))
    cr.fill()
    # weathered limestone: blocks, stains
    r = rng(91)
    for k in range(30):
        y = top + 90 + k * 13
        p.fill_rect(x0, y, x1 - x0, 1, hexc("#8a7a5a", 0.35))
    for i in range(160):
        p.ellipse(x0 + r.random() * (x1 - x0), top + 90 + r.random() * 300, 4 + r.random() * 14, 2 + r.random() * 5,
                  hexc("#8a7a5a" if r.random() < 0.6 else "#ffffff", 0.08))
    # the cornice line, the pilasters, the niches with their shells, the door and the window
    p.fill_rect(x0, 578, x1 - x0, 8, sh)
    p.fill_rect(x0, 574, x1 - x0, 4, lt)
    for px in (x0 + 30, x0 + 90, x1 - 110, x1 - 50):
        p.fill_rect(px, top + 150, 20, base - top - 150, p.lin(px, 0, px + 20, 0, [(0, sh), (0.5, lt), (1, sh)]))
        p.fill_rect(px - 4, top + 146, 28, 6, lt)
        p.fill_rect(px - 2, 568, 24, 10, sh)
    for nx in (x0 + 62, x1 - 82):
        for ny in (520, 640):
            p.fill_rect(nx - 11, ny, 22, 52, "#6a5a48")
            cr.arc(nx, ny, 11, math.pi, 2 * math.pi)
            p.src("#6a5a48")
            cr.fill()
            for k in range(5):
                a = math.pi + k * math.pi / 4
                p.line([(nx, ny), (nx + math.cos(a) * 10, ny + math.sin(a) * 10)], hexc(lt, 0.6), 1)
    p.fill_rect(342, 598, 84, 162, sh)
    p.fill_rect(344, 600, 80, 160, "#3a2a20")
    cr.arc(384, 600, 40, math.pi, 2 * math.pi)
    p.src("#3a2a20")
    cr.fill()
    for i in range(4):
        p.fill_rect(348 + i * 19, 606, 14, 150, hexc("#5a4030", 0.8))
    for k in range(9):
        a = math.pi + k * math.pi / 8
        p.line([(384 + math.cos(a) * 42, 600 + math.sin(a) * 42), (384 + math.cos(a) * 52, 600 + math.sin(a) * 52)], sh, 3)
    p.fill_rect(370, 470, 28, 40, "#3a2a20")
    cr.arc(384, 470, 14, math.pi, 2 * math.pi)
    p.src("#3a2a20")
    cr.fill()
    # the flags, Texas and the United States, at the poles (still: the live ones wave)
    for fx in (120, 660):
        p.fill_rect(fx - 2, 300, 4, 460, p.lin(fx - 2, 0, fx + 2, 0, [(0, "#8a8a90"), (1, "#d8d8dc")]))
        p.circle(fx, 298, 4, "#c8a860")
    live_oak(p, 18, 790, 0.62, "day", 92)
    live_oak(p, 752, 796, 0.55, "day", 94, flip=True)
    # the plaza: flagstones
    p.fill_rect(0, 760, W, H - 760, p.lin(0, 760, 0, H, [(0, "#d8c8a4"), (1, "#b0a080")]))
    for k in range(12):
        y = 768 + k * k * 2.2 + k * 8
        p.fill_rect(0, y, W, 1.4, hexc("#7a6a4a", 0.35))
    for i in range(80):
        p.fill_rect(r.random() * W, 770 + r.random() * 250, 1.2, 10 + r.random() * 20, hexc("#7a6a4a", 0.25))
    p.grain(0.02, 93)
    return p


# ------------------------------------------------------------------ Central Texas barbecue (the fire's glow and the smoke are live)
def bbq():
    p = Paint()
    p.fill_rect(0, 0, W, H, p.lin(0, 0, 0, H, [(0, "#3a2418"), (0.5, "#2a1a12"), (1, "#140c08")]))
    p.glow(380, 360, 420, "#ff8a3a", 0.12, 0.6)
    # the pit room's wall: old brick, black with smoke
    r = rng(100)
    for row in range(30):
        y = row * 18
        for x in range((row % 2) * 24, W, 48):
            p.fill_rect(x + 1, y + 1, 46, 16, hexc("#5a3020" if r.random() < 0.6 else "#3a2016", 0.35 + r.random() * 0.3))
    p.fill_rect(0, 0, W, 540, p.lin(0, 0, 0, 540, [(0, hexc("#000000", 0.5)), (1, hexc("#000000", 0.1))]))
    # stacked post oak
    for i in range(24):
        x, y = 600 + (i % 6) * 26, 470 - (i // 6) * 22
        p.ellipse(x, y, 13, 11, "#5a3a24")
        p.ellipse(x, y, 9, 7, "#c8a070")
        p.ellipse(x, y, 4, 3, "#8a6a48")
    # the smoker: the barrel, its lid seam, the firebox, the stack, the thermometer
    p.fill_rect(140, 300, 420, 130, p.lin(0, 300, 0, 430, [(0, "#3a3a3e"), (0.35, "#1a1a1c"), (1, "#0a0a0c")]), r=60)
    p.fill_rect(160, 362, 380, 5, "#4a4a4e")
    p.fill_rect(330, 340, 50, 8, "#6a6a70", r=4)
    p.fill_rect(80, 340, 90, 110, p.lin(0, 340, 0, 450, [(0, "#2a2a2e"), (1, "#0a0a0c")]), r=6)
    p.fill_rect(96, 398, 58, 38, "#1a0a06")
    p.fill_rect(520, 160, 26, 160, p.lin(520, 0, 546, 0, [(0, "#1a1a1c"), (0.4, "#4a4a4e"), (1, "#141416")]))
    p.circle(220, 334, 12, "#d8d8dc")
    p.circle(220, 334, 9, "#f4f4f0")
    p.line([(220, 334), (226, 328)], "#c4202a", 1.6)
    for wx in (190, 500):
        p.circle(wx, 450, 22, "#0e0e10")
        p.circle(wx, 450, 8, "#3a3a3e")
    # the table: butcher paper, the brisket sliced (bark, smoke ring), sausage, white bread, pickles, onion
    p.poly([(70, 560), (700, 520), (720, 920), (60, 960)], p.lin(0, 520, 0, 960, [(0, "#e2c294"), (1, "#c8a070")]))
    for i in range(10):
        p.line([(80 + i * 64, 556 - i * 4), (70 + i * 66, 950 - i * 4)], hexc("#8a6a40", 0.15), 2)
    for i in range(6):
        x, y = 140 + i * 58, 640 + i * 4
        p.fill_rect(x - 2, y - 2, 54, 124, hexc("#1a0a04", 0.4), r=7)
        p.fill_rect(x, y, 50, 120, "#1e1008", r=6)
        p.fill_rect(x + 4, y + 5, 42, 110, "#8a2a24", r=5)
        p.fill_rect(x + 8, y + 10, 34, 100, p.lin(0, y, 0, y + 110, [(0, "#a85a40"), (1, "#8a4632")]), r=4)
        for k in range(5):
            p.fill_rect(x + 10, y + 20 + k * 18, 30, 1.5, hexc("#ffd8b0", 0.35))
        p.fill_rect(x + 12, y + 30, 26, 4, hexc("#fff0d8", 0.45))
    for i in range(3):
        sx, sy = 500 + i * 16, 600 + i * 26
        p.fill_rect(sx, sy, 150, 34, p.lin(0, sy, 0, sy + 34, [(0, "#8a2a1a"), (1, "#4a120a")]), r=17)
        p.fill_rect(sx + 12, sy + 6, 120, 5, hexc("#ff9a7a", 0.4), r=3)
        for k in range(3):
            p.fill_rect(sx + 30 + k * 34, sy + 2, 2, 30, hexc("#2a0a04", 0.4))
    p.fill_rect(120, 800, 110, 96, "#f4ecdc", r=10)
    p.fill_rect(140, 790, 110, 96, "#fffaf0", r=10)
    p.fill_rect(140, 790, 110, 10, "#e8c890", r=6)
    for i in range(5):
        x, y = 330 + i * 34, 840 + (i % 2) * 14
        p.ellipse(x, y, 16, 10, "#4a7a2a")
        p.ellipse(x, y, 11, 6, "#8ab04a")
        p.circle(x - 4, y - 2, 1.5, "#d8e8a0")
    for i in range(3):
        cr = p.cr
        cr.set_line_width(3)
        cr.save()
        cr.translate(540 + i * 30, 820)
        cr.scale(1, 0.55)
        cr.arc(0, 0, 22 - i * 5, 0, 2 * math.pi)
        cr.restore()
        p.src("#f4ece0")
        cr.stroke()
    p.grain(0.02, 101)
    return p


# ------------------------------------------------------------------ the Panhandle at golden hour (lightning, the windmill's blades, the pump jack's beam are live)
def panhandle():
    p = Paint()
    sky(p, 700, [(0, "#3a3060"), (0.5, "#a85a6a"), (0.85, "#f0904a"), (1, "#ffc070")])
    p.glow(250, 600, 360, "#ffc070", 0.55, 0.55)
    p.circle(250, 610, 34, "#fff0c0")
    # the supercell: the anvil spread flat, the tower, the dark base, rain
    cell = p.layer()
    cell.poly([(330, 250), (W, 205), (W, 275), (600, 295), (420, 282)], "#4a3a5a")
    for (x, y, rr) in [(600, 330, 60), (660, 350, 72), (720, 330, 66), (640, 400, 72), (712, 410, 64), (580, 410, 52), (690, 270, 40)]:
        cell.ellipse(x, y, rr * 1.2, rr, cell.lin(0, y - rr, 0, y + rr, [(0, "#8a6a7a"), (1, "#3a2e44")]))
    cell.fill_rect(520, 440, 248, 36, "#2a2236", r=14)
    p.composite(cell, blur=2)
    p.fill_rect(530, 470, 238, 170, p.lin(0, 470, 0, 640, [(0, hexc("#5a5a70", 0.55)), (1, hexc("#5a5a70", 0.1))]))
    for i in range(30):
        x = 530 + i * 8
        p.line([(x, 476), (x - 40, 640)], hexc("#8a8aa0", 0.25), 1.2)
    # Palo Duro: canyon walls in bands of red, orange and cream, eroded, lit from the low sun on the left
    strata = ["#9a321c", "#c85c36", "#e8a070", "#f0dcb8", "#b44a2e", "#8a321e", "#6a2616"]
    r = rng(112)
    for m, (x, w, y) in enumerate([(-60, 380, 520), (290, 300, 556), (520, 320, 596)]):
        # the silhouette: a flat cap, slopes broken into ledges
        top = []
        n = 30
        for i in range(n + 1):
            u = i / n
            edge = min(u, 1 - u) * 2
            lift = (min(1, edge * 4) ** 0.5) * 1.0
            top.append((x + u * w, y + (1 - lift) * 150 + r.random() * 6 * lift))
        cr = p.cr
        cr.move_to(x, y + 190)
        for pt in top:
            cr.line_to(*pt)
        cr.line_to(x + w, y + 190)
        cr.close_path()
        cr.save()
        cr.clip()
        band_h = 190 / len(strata)
        for j, c in enumerate(strata):
            yy = y + j * band_h
            cr.move_to(x - 20, yy)
            for i in range(21):
                cr.line_to(x + i * w / 20, yy + math.sin(i * 1.3 + j + m) * 3)
            cr.line_to(x + w + 20, yy + band_h + 4)
            cr.line_to(x - 20, yy + band_h + 4)
            cr.close_path()
            p.src(p.lin(x, 0, x + w, 0, [(0, mix(c, "#ffc890", 0.3)), (0.55, c), (1, mix(c, "#2a1020", 0.4))]))
            cr.fill()
        for k in range(18):
            gx = x + 20 + r.random() * (w - 40)
            p.line([(gx, y + 10), (gx + (r.random() - 0.5) * 20, y + 190)], hexc("#2a0a08", 0.18), 1.5 + r.random() * 2)
        cr.restore()
        p.fill_rect(x, y + 160, w, 30, hexc("#4a1a10", 0.35))
    haze(p, 540, 700, "#ffb070", 0.25)
    # the plains: wheat
    p.fill_rect(0, 700, W, H - 700, p.lin(0, 700, 0, H, [(0, "#e8b060"), (1, "#a8742a")]))
    r = rng(110)
    for i in range(1800):
        k = r.random()
        y = 704 + k * 320
        x = r.random() * W
        h = 6 + k * 18
        p.line([(x, y), (x + (r.random() - 0.5) * 4, y - h)], hexc("#ffe0a0" if r.random() < 0.5 else "#8a5a20", 0.55), 0.8 + k)
    # the windmill's tower and tail (the wheel turns live), the pump jack's base and frame
    for (a, b) in (((130, 900), (160, 600)), ((190, 900), (160, 600))):
        p.line([a, b], "#1e1612", 4)
    for y in range(640, 880, 60):
        p.line([(130 + (900 - y) * 0.1, y), (190 - (900 - y) * 0.1, y)], "#1e1612", 2.4)
        p.line([(130 + (900 - y) * 0.1, y), (190 - (900 - y - 60) * 0.1, y + 60)], "#1e1612", 1.4)
    p.poly([(160, 586), (230, 576), (236, 600), (160, 594)], "#1e1612")
    p.fill_rect(520, 880, 180, 14, "#1a1a1e")
    p.poly([(590, 880), (610, 790), (630, 880)], "#1a1a1e")
    p.line([(600, 836), (620, 836)], "#1a1a1e", 3)
    p.fill_rect(686, 868, 30, 14, "#2a2a30")
    p.grain(0.02, 111)
    return p


# ------------------------------------------------------------------ the Congress Avenue Bridge at dusk (the bats are live)
def bats(light):
    p = Paint()
    late = light == "night"
    sky(p, 600, [(0, "#1a1440" if late else "#3a2e6a"), (0.6, "#6a3a6a" if late else "#c0607a"), (1, "#a85a5a" if late else "#ffa070")])
    if late:
        stars(p, 70, 300, 120)
    # downtown: towers in silhouette, windows lit
    r = rng(121)
    blds = [(0, 120), (60, 200), (130, 160), (190, 260), (260, 180), (330, 300), (400, 220), (470, 340), (550, 200), (620, 260), (690, 170)]
    for (x, hgt) in blds:
        p.fill_rect(x, 600 - hgt, 66, hgt, p.lin(x, 0, x + 66, 0, [(0, "#16122a"), (1, "#221a36")]))
        windows_grid(p, x + 4, 600 - hgt + 8, 58, hgt - 16, 5, int(hgt / 14), True, 122 + x, glass="#1a1630",
                     light="#ffd890", frac=0.45 if late else 0.3)
    p.poly([(470, 260), (536, 260), (503, 220)], "#16122a")
    p.fill_rect(500, 190, 3, 32, "#16122a")
    p.circle(501, 190, 3, "#ff4a4a")
    # Lady Bird Lake: the city in it, rippled
    water(p, 600, H, "#3a2a50" if late else "#5a3a60", "#0e0a1c", 123, lines=140)
    for (x, hgt) in blds:
        for k in range(int(hgt / 22)):
            if r.random() < 0.5:
                p.fill_rect(x + 8 + r.random() * 50, 664 + k * 9, 10 + r.random() * 20, 2, hexc("#ffd890", 0.25))
    # the bridge: deck, railing, lamps, arches with their shadows
    p.fill_rect(0, 638, W, 24, "#120e1c")
    p.fill_rect(0, 634, W, 4, "#2a2236")
    for i in range(7):
        cx = 55 + i * 110
        cr = p.cr
        cr.move_to(cx - 55, 662)
        cr.line_to(cx + 55, 662)
        cr.line_to(cx + 55, 780)
        cr.line_to(cx + 48, 780)
        cr.arc_negative(cx, 730, 48, 0, math.pi)
        cr.line_to(cx - 55, 780)
        cr.close_path()
        p.src("#0e0a16")
        cr.fill()
        p.fill_rect(cx - 55, 772, 14, 60, hexc("#0e0a16", 0.6))
    for i in range(6):
        x = 40 + i * 140
        p.fill_rect(x, 606, 4, 30, "#1a1626")
        p.circle(x + 2, 604, 4.5, "#ffe0a0")
        p.glow(x + 2, 604, 26, "#ffd080", 0.6)
    # the crowd on the bank
    for i in range(20):
        x = 18 + i * 39
        p.circle(x, 986 - (i % 3) * 4, 9, "#08060e")
        p.fill_rect(x - 10, 994 - (i % 3) * 4, 20, 34, "#08060e", r=6)
    p.grain(0.02, 124)
    return p


# ------------------------------------------------------------------ Big Bend at night (the twinkling, a shooting star, the Marfa lights, the coyote are live)
def bigbend():
    p = Paint()
    sky(p, 790, [(0, "#020210"), (0.7, "#0a0a24"), (1, "#1a1430")])
    stars(p, 900, 760, 130, big=0.02)
    milky_way(p, 40, 720, 600, -40, 131, width=120)
    # the Chisos: a jagged ridge, the far ranges lighter
    hill_band(p, 700, 40, "#120e22", 132, bottom=800, freq=2.2)
    ridge = [(0, 700), (80, 640), (140, 660), (210, 560), (260, 600), (330, 520), (380, 580), (450, 540), (520, 610),
             (600, 590), (680, 640), (768, 620)]
    cr = p.cr
    cr.move_to(0, 800)
    for pt in ridge:
        cr.line_to(*pt)
    cr.line_to(W, 800)
    cr.close_path()
    p.src("#07050e")
    cr.fill()
    p.glow(384, 790, 400, "#3a2a5a", 0.25, 0.25)
    # the desert floor, ocotillo, prickly pear, in starlight
    p.fill_rect(0, 770, W, H - 770, p.lin(0, 770, 0, H, [(0, "#0e0c16"), (1, "#040306")]))
    r = rng(133)
    for i in range(300):
        p.ellipse(r.random() * W, 790 + r.random() * 234, 2 + r.random() * 3, 1 + r.random(), hexc("#3a3448", 0.4))
    ocotillo(p, 120, 980, 1.0, 134, col="#020205")
    ocotillo(p, 640, 960, 0.9, 135, col="#020205")
    prickly_pear(p, 330, 990, 1.0, 136, col="#06060a")
    prickly_pear(p, 470, 1000, 0.9, 137, col="#06060a")
    p.grain(0.012, 138)
    return p


# ------------------------------------------------------------------ the Lone Star under the stars (the pole and the flag are live)
def finale():
    p = Paint()
    sky(p, H, [(0, "#020212"), (0.6, "#0e0a2a"), (1, "#24163a")])
    stars(p, 700, 900, 140, big=0.02)
    milky_way(p, 760, 760, 120, -60, 141, width=100, bright=0.8)
    hill_band(p, 960, 10, "#06040c", 142)
    p.glow(560, 1000, 360, "#4a2a5a", 0.3, 0.3)
    p.grain(0.012, 143)
    return p


PAINTS = {
    "open": open_dawn,
    "coast_dawn": lambda: coast("dawn"),
    "coast_day": lambda: coast("day"),
    "hills": hills,
    "creek": creek,
    "donuts": donuts,
    "austin": austin,
    "stockyards": stockyards,
    "alamo": alamo,
    "bbq": bbq,
    "panhandle": panhandle,
    "bats_dusk": lambda: bats("dusk"),
    "bats_night": lambda: bats("night"),
    "bigbend": bigbend,
    "finale": finale,
}
