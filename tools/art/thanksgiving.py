"""The Thanksgiving show's pictures (thanksgiving.lua). Each laid out under its scene's live parts.
"""
import math

from paint import Paint, W, H, hexc, mix, rng
from scenery import cloud, live_oak, hill_band, haze, grass_tufts, windows_grid, crowd_band

LEAVES = ["#c8401a", "#e8801a", "#f0b820", "#a8301a", "#d86a2a", "#8a4a1a"]


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


def leaf(p, x, y, s, rot, col):
    """An oak leaf: lobed, a vein down the middle."""
    cr = p.cr
    cr.save()
    cr.translate(x, y)
    cr.rotate(rot)
    cr.scale(s, s)
    cr.move_to(0, -14)
    for i, (a, b) in enumerate([(5, -10), (9, -5), (6, -1), (10, 4), (5, 7), (0, 12)]):
        cr.curve_to(a + 3, b - 3, a + 3, b + 1, a, b)
    for (a, b) in [(-5, 7), (-10, 4), (-6, -1), (-9, -5), (-5, -10), (0, -14)]:
        cr.curve_to(a - 3, b + 1, a - 3, b - 3, a, b)
    cr.close_path()
    cr.restore()
    p.src(col)
    cr.fill()
    p.line([(x, y), (x + math.sin(rot) * -12 * s, y + math.cos(rot) * 12 * s)], hexc("#5a2a10", 0.5), 0.8 * s)


def pumpkin(p, x, y, r, col="#e8701a"):
    for k, dx in enumerate((-0.55, 0.55, -0.25, 0.25, 0)):
        p.ellipse(x + dx * r, y, r * 0.55, r * 0.8,
                  p.lin(x + dx * r - r * 0.5, 0, x + dx * r + r * 0.5, 0, [(0, mix(col, "#7a2a08", 0.4)), (0.5, col), (1, mix(col, "#7a2a08", 0.3))]))
    p.fill_rect(x - r * 0.08, y - r * 0.95, r * 0.16, r * 0.3, "#4a5a2a", r=2)
    p.ellipse(x - r * 0.25, y - r * 0.4, r * 0.14, r * 0.3, hexc("#ffd090", 0.35))


def hay_bale(p, x, y, w, h):
    p.fill_rect(x, y, w, h, p.lin(0, y, 0, y + h, [(0, "#f0d070"), (1, "#c09a40")]), r=8)
    r = rng(int(x * 7 + y))
    for i in range(60):
        xx = x + r.random() * w
        yy = y + r.random() * h
        p.line([(xx, yy), (xx + (r.random() - 0.5) * 12, yy + (r.random() - 0.5) * 4)], hexc("#8a6a20", 0.5), 1)
    p.fill_rect(x, y + h * 0.3, w, 3, "#7a5a24")
    p.fill_rect(x, y + h * 0.7, w, 3, "#7a5a24")


def harvest_border(p):
    """Leaves, wheat, pumpkins and corn along the bottom, leaves in the top corners."""
    r = rng(300)
    for i in range(140):
        x = r.random() * W
        y = H - r.random() ** 2 * 200
        leaf(p, x, y, 1.6 + r.random() * 1.4, r.random() * 6.28, LEAVES[r.randrange(len(LEAVES))])
    for corner in (0, W):
        for i in range(40):
            x = corner + (r.random() * 160) * (1 if corner == 0 else -1)
            y = r.random() ** 2 * 160
            leaf(p, x, y, 1.4 + r.random(), r.random() * 6.28, LEAVES[r.randrange(len(LEAVES))])
    for (x, rr) in ((120, 54), (220, 38), (610, 48), (690, 34)):
        pumpkin(p, x, H - 70, rr)
    for k in range(9):
        x = 360 + k * 6
        p.line([(384, H - 20), (x - 30 + k * 2, H - 210 + abs(k - 4) * 12)], "#c8a04a", 3)
        p.ellipse(x - 30 + k * 2, H - 220 + abs(k - 4) * 12, 5, 14, "#e0b860")


def open_screen():
    p = Paint()
    sky(p, H, [(0, "#3a1408"), (0.6, "#8a3a12"), (1, "#c86a20")])
    p.glow(384, 460, 420, "#ffb050", 0.3, 0.8)
    harvest_border(p)
    p.grain(0.02, 301)
    return p


def finale():
    p = Paint()
    sky(p, H, [(0, "#3a1408"), (0.55, "#9a4a18"), (1, "#d07a28")])
    p.glow(384, 520, 440, "#ffc060", 0.32, 0.8)
    harvest_border(p)
    p.grain(0.02, 302)
    return p


# ------------------------------------------------------------------ the parade (balloons, handlers, the float, confetti are live)
def parade():
    p = Paint()
    sky(p, 560, [(0, "#5a86d0"), (1, "#e2e8f4")])
    cloud(p, 380, 120, 0.8, hexc("#ffffff", 0.95), hexc("#c8d2e4", 0.95), 310)
    r = rng(311)
    # the avenue's buildings: brick and limestone, cornices, windows, a flag or two
    for (x, w, hgt, col) in [(0, 130, 400, "#8a5a4a"), (126, 104, 320, "#c8b8a4"), (538, 116, 360, "#7a6a74"),
                             (650, 120, 420, "#a87a5a")]:
        p.fill_rect(x, 620 - hgt, w, hgt, p.lin(x, 0, x + w, 0, [(0, mix(col, "#000000", 0.15)), (1, col)]))
        p.fill_rect(x - 4, 620 - hgt - 8, w + 8, 10, mix(col, "#ffffff", 0.2))
        for wy in range(int(620 - hgt + 22), 590, 38):
            for wx in range(int(x) + 12, int(x + w) - 22, 26):
                p.fill_rect(wx, wy, 14, 22, "#3a4a5e")
                p.fill_rect(wx, wy, 14, 3, hexc("#ffffff", 0.4))
                p.fill_rect(wx - 2, wy + 22, 18, 3, mix(col, "#ffffff", 0.25))
    for (x, y) in ((230, 380), (538, 400)):
        p.line([(x, y), (x + (40 if x < 384 else -40), y - 20)], "#c8c8cc", 2)
        fx = x + (40 if x < 384 else -40)
        for k in range(7):
            p.fill_rect(fx - (0 if x < 384 else 30), y - 20 + k * 3, 30, 3, "#c4202a" if k % 2 == 0 else "#ffffff")
        p.fill_rect(fx - (0 if x < 384 else 30), y - 20, 12, 10, "#1a3a8a")
    haze(p, 300, 620, "#e2e8f4", 0.25)
    # the crowd behind the barriers, the barriers, the avenue
    p.fill_rect(0, 560, W, 70, "#4a4a52")
    crowd_band(p, 0, 562, W, 628, 312, 7, 0.95, 1.0, ("#c4302a", "#2a5ab8"))
    p.fill_rect(0, 620, W, H - 620, p.lin(0, 620, 0, H, [(0, "#8a8a90"), (1, "#5a5a62")]))
    for i in range(14):
        x = i * 60
        p.fill_rect(x, 630, 54, 10, "#2a4ab8")
        p.fill_rect(x + 4, 640, 3, 14, "#c8c8cc")
        p.fill_rect(x + 46, 640, 3, 14, "#c8c8cc")
    for k in range(6):
        y = 700 + k * 60
        p.fill_rect(0, y, W, 2, hexc("#ffffff", 0.06))
    p.fill_rect(380, 660, 8, 364, hexc("#f0d020", 0.5))
    p.grain(0.02, 313)
    return p


# ------------------------------------------------------------------ the farm (the turkey and Pac-Man are live; the bale it hides behind is at 60..180)
def farm():
    p = Paint()
    sky(p, 620, [(0, "#5a90e0"), (0.7, "#c8d8f0"), (1, "#f8e0b8")])
    cloud(p, 180, 130, 0.8, hexc("#ffffff", 0.96), hexc("#c8d2e4", 0.96), 320)
    hill_band(p, 600, 18, "#8a9a4a", 321, bottom=700, top_col="#a8b05a")
    # the barn: red boards, white trim, the loft, the X doors, the roof
    bx = 480
    p.fill_rect(bx, 380, 240, 220, p.lin(bx, 0, bx + 240, 0, [(0, "#8a1a14"), (0.5, "#b42a20"), (1, "#7a1810")]))
    for i in range(24):
        p.fill_rect(bx + i * 10, 380, 1.2, 220, hexc("#000000", 0.18))
    p.poly([(bx - 14, 382), (bx + 120, 286), (bx + 254, 382)], p.lin(0, 286, 0, 382, [(0, "#5a5a60"), (1, "#3a3a40")]))
    p.poly([(bx - 6, 380), (bx + 120, 296), (bx + 246, 380), (bx + 234, 380), (bx + 120, 308), (bx + 6, 380)], "#f4f0e8")
    p.fill_rect(bx + 100, 330, 40, 36, "#f4f0e8")
    p.fill_rect(bx + 106, 336, 28, 30, "#3a2018")
    p.fill_rect(bx + 80, 470, 80, 130, "#f4f0e8")
    p.fill_rect(bx + 86, 476, 68, 124, "#9a2018")
    p.line([(bx + 86, 476), (bx + 154, 600)], "#f4f0e8", 5)
    p.line([(bx + 154, 476), (bx + 86, 600)], "#f4f0e8", 5)
    p.fill_rect(bx + 30, 420, 30, 30, "#f4f0e8")
    p.fill_rect(bx + 34, 424, 22, 22, "#2a3a4a")
    p.fill_rect(bx + 180, 420, 30, 30, "#f4f0e8")
    p.fill_rect(bx + 184, 424, 22, 22, "#2a3a4a")
    # a silo
    p.fill_rect(728, 340, 40, 260, p.lin(728, 0, 768, 0, [(0, "#9a9aa0"), (0.5, "#d8d8dc"), (1, "#8a8a90")]))
    for k in range(12):
        p.fill_rect(728, 350 + k * 22, 40, 2, hexc("#5a5a60", 0.6))
    # the field
    p.fill_rect(0, 600, W, H - 600, p.lin(0, 600, 0, H, [(0, "#c8a850"), (1, "#8a6a2a")]))
    grass_tufts(p, 610, H, 322, 1500, col="#b89a40")
    # the rail fence
    for y in (640, 680):
        p.fill_rect(0, y, W, 8, p.lin(0, y, 0, y + 8, [(0, "#8a6440"), (1, "#5a3e24")]))
    for x in range(10, W, 80):
        p.fill_rect(x, 618, 10, 94, p.lin(x, 0, x + 10, 0, [(0, "#5a3e24"), (1, "#8a6440")]))
    # the hay bales (the turkey hides behind the left one), the pumpkin patch
    hay_bale(p, 60, 790, 120, 60)
    hay_bale(p, 240, 850, 120, 60)
    for i in range(5):
        x, y = 480 + i * 60, 960 - (i % 2) * 20
        p.line([(x - 40, y + 10), (x + 40, y + 6)], "#4a6a2a", 2)
        pumpkin(p, x, y, 26)
    p.grain(0.02, 323)
    return p


# ------------------------------------------------------------------ autumn on the porch (the raking, the leaf pile, the porch's cast are live)
def autumn(light):
    p = Paint()
    dusk = light == "dusk"
    sky(p, 700, [(0, "#4a3a7a" if dusk else "#5a86d0"), (0.7, "#e07a4a" if dusk else "#f0c890"), (1, "#ffb060" if dusk else "#ffe0a0")])
    p.glow(560, 560, 300, "#ffb060", 0.5 if dusk else 0.3, 0.6)
    hill_band(p, 640, 22, "#8a5a2a" if dusk else "#a87a3a", 330, bottom=740, top_col="#c8904a")
    haze(p, 560, 700, "#ffb060", 0.25)
    p.fill_rect(0, 640, W, H - 640, p.lin(0, 640, 0, H, [(0, "#8a6a2a"), (1, "#5a3e1a")]))
    grass_tufts(p, 650, H, 331, 900, col="#9a7a3a")
    # the old oak in its colours, leaves on the ground under it
    r = rng(332)
    p.poly([(170, 900), (214, 900), (204, 600), (178, 600)], p.lin(170, 0, 214, 0, [(0, "#3a2414"), (0.6, "#6a4a30"), (1, "#3a2414")]))
    for (a, b) in [((190, 640), (90, 520)), ((190, 620), (310, 500)), ((192, 600), (200, 440))]:
        p.line([a, b], "#4a3020", 12)
    for i in range(420):
        a = r.random() * 2 * math.pi
        rr = r.random() ** 0.6
        x, y = 200 + math.cos(a) * 170 * rr, 480 + math.sin(a) * 100 * rr
        leaf(p, x, y, 1.2 + r.random(), r.random() * 6.28, LEAVES[r.randrange(len(LEAVES))])
    # (a few leaves scattered on the grass: the pile is raked live)
    for i in range(46):
        leaf(p, 20 + r.random() * 370, 760 + r.random() * 240, 1.0 + r.random() * 0.6, r.random() * 6.28, LEAVES[r.randrange(len(LEAVES))])
    # the porch: boards, steps, the rail, pumpkins, a hay bale, a corn stalk bundle
    p.fill_rect(400, 760, 368, 200, p.lin(0, 760, 0, 960, [(0, "#8a5a3a"), (1, "#5a3a24")]))
    for y in range(780, 960, 20):
        p.fill_rect(400, y, 368, 2, hexc("#2a1a10", 0.5))
    for y in (960, 980, 1000):
        p.fill_rect(380 + (y - 960), y, 400, 20, mix("#6a4a30", "#000000", (y - 960) / 120))
    p.fill_rect(400, 696, 368, 12, "#f4efe4")
    for x in range(410, 768, 30):
        p.fill_rect(x, 704, 8, 56, "#ece6da")
    p.fill_rect(400, 600, 14, 160, "#f4efe4")
    for (x, y, rr) in ((460, 760, 34), (520, 770, 24), (700, 760, 30)):
        pumpkin(p, x, y - rr * 0.6, rr)
    hay_bale(p, 710, 860, 58, 46)
    for k in range(8):
        p.line([(430 + k * 3, 760), (420 + k * 5, 610)], "#c8a050", 3)
    p.fill_rect(424, 690, 30, 8, "#7a3a1a")
    p.grain(0.02, 333)
    return p


# ------------------------------------------------------------------ the table (the guests, the feast brought in and eaten, the candles are live)
def table():
    p = Paint()
    p.fill_rect(0, 0, W, H, p.lin(0, 0, 0, H, [(0, "#5a3020"), (1, "#2a140a")]))
    # wallpaper, the chair rail, wainscot
    for x in range(0, W, 48):
        p.fill_rect(x, 0, 20, 560, hexc("#7a4a2a", 0.6))
        for y in range(20, 560, 60):
            p.circle(x + 34, y, 4, hexc("#c8904a", 0.35))
    p.fill_rect(0, 540, W, 14, "#3a1e10")
    # the window: dusk outside, a lamp's glow
    p.fill_rect(272, 112, 224, 276, "#f0e6d2")
    p.fill_rect(280, 120, 208, 260, p.lin(0, 120, 0, 380, [(0, "#3a3a7a"), (0.7, "#c86a5a"), (1, "#f0a060")]))
    p.circle(440, 320, 16, "#fff0c0")
    hill_band(p, 360, 8, "#2a1e3a", 340, bottom=380)
    p.fill_rect(380, 120, 8, 260, "#f0e6d2")
    p.fill_rect(280, 246, 208, 8, "#f0e6d2")
    for side in (0, 1):
        x = 240 if side == 0 else 488
        p.fill_rect(x, 100, 40, 300, p.lin(x, 0, x + 40, 0, [(0, "#8a2a1a"), (0.5, "#b8402a"), (1, "#8a2a1a")]))
    p.glow(120, 300, 160, "#ffd890", 0.25)
    # the table: the cloth, the runner, plates, candles
    p.fill_rect(40, 600, 688, 340, "#8a2a18", r=12)
    p.fill_rect(70, 620, 628, 290, p.lin(0, 620, 0, 910, [(0, "#fbf6ea"), (1, "#e8dcc4")]), r=10)
    p.fill_rect(70, 700, 628, 70, hexc("#c8642a", 0.5))
    # the places: five plates along the far side (the guests sit behind them), two candlesticks (the flames are
    # live); the feast itself is live, brought in dish by dish and eaten
    for x in (150, 270, 384, 498, 618):
        p.ellipse(x, 655, 42, 18, "#ffffff")
        p.ellipse(x, 655, 30, 12, "#e8e4dc")
        p.fill_rect(x + 46, 640, 4, 30, "#c8c8cc")
    for x in (96, 672):
        p.fill_rect(x - 5, 700, 10, 50, "#f6efd8")
        p.ellipse(x, 752, 18, 7, "#c8a040")
    p.grain(0.02, 341)
    return p


# ------------------------------------------------------------------ football on TV (the game on the screen and the family are live)
TV = (150, 156, 468, 288)                     # the screen, live


def football():
    p = Paint()
    p.fill_rect(0, 0, W, H, p.lin(0, 0, 0, H, [(0, "#3a2e34"), (1, "#1a1418")]))
    for x in range(0, W, 64):
        p.fill_rect(x, 0, 2, 620, hexc("#000000", 0.2))
    p.glow(384, 300, 360, "#4a8aff", 0.15, 0.8)
    # a lamp, a picture frame with a longhorn
    p.fill_rect(680, 300, 6, 300, "#3a2a20")
    p.poly([(650, 300), (716, 300), (700, 250), (666, 250)], "#e8d8b0")
    p.glow(683, 290, 80, "#ffd890", 0.35)
    p.fill_rect(40, 180, 70, 90, "#7a5a3a")
    p.fill_rect(46, 186, 58, 78, "#bf5700")
    # the TV: its cabinet, its frame (the picture is live)
    x, y, w, h = TV
    p.fill_rect(300, 460, 168, 160, p.lin(0, 460, 0, 620, [(0, "#6a4a30"), (1, "#3a2818")]), r=4)
    p.fill_rect(310, 480, 148, 4, "#2a1a10")
    p.fill_rect(x - 16, y - 16, w + 32, h + 32, "#0e0e12", r=12)
    p.fill_rect(x - 8, y - 8, w + 16, h + 16, "#1a1a20", r=6)
    p.fill_rect(x, y, w, h, "#000000")
    # the rug, the couch (everyone sits on it, live)
    p.fill_rect(0, 620, W, H - 620, p.lin(0, 620, 0, H, [(0, "#6a4a3a"), (1, "#3a2820")]))
    p.ellipse(384, 940, 360, 70, hexc("#bf5700", 0.35))
    p.fill_rect(40, 700, 688, 90, p.lin(0, 700, 0, 790, [(0, "#7a4a34"), (1, "#5a3424")]), r=30)
    p.fill_rect(60, 760, 648, 180, p.lin(0, 760, 0, 940, [(0, "#6a3e2a"), (1, "#4a2a1c")]), r=30)
    p.fill_rect(80, 800, 608, 80, p.lin(0, 800, 0, 880, [(0, "#8a5a40"), (1, "#6a4230")]), r=20)
    for k in range(3):
        p.fill_rect(80 + k * 203, 800, 2, 80, hexc("#2a1810", 0.5))
    p.fill_rect(20, 720, 70, 200, "#6a3e2a", r=24)
    p.fill_rect(678, 720, 70, 200, "#6a3e2a", r=24)
    p.grain(0.02, 351)
    return p


# ------------------------------------------------------------------ pie (the pies, a slice at a time, are live)
def pie_counter():
    p = Paint()
    p.fill_rect(0, 0, W, 700, p.lin(0, 0, 0, 700, [(0, "#fbe8c8"), (1, "#f0c890")]))
    # the kitchen: tiles, a window with checked curtains
    for y in range(0, 700, 32):
        for x in range((y // 32 % 2) * 16, W, 32):
            p.fill_rect(x + 1, y + 1, 30, 30, hexc("#ffffff", 0.18))
    p.fill_rect(250, 40, 268, 200, "#ffffff")
    p.fill_rect(260, 50, 248, 180, p.lin(0, 50, 0, 230, [(0, "#8ab8ea"), (1, "#e8f0f8")]))
    for side in (0, 1):
        cx = 230 if side == 0 else 470
        for k in range(8):
            for j in range(12):
                if (k + j) % 2 == 0:
                    p.fill_rect(cx + k * 8, 30 + j * 18, 8, 18, hexc("#c4302a", 0.7))
    # the counter: wood, a checked cloth
    p.fill_rect(0, 700, W, H - 700, p.lin(0, 700, 0, H, [(0, "#c8905a"), (1, "#8a5a30")]))
    for y in range(700, H, 40):
        for x in range((y // 40 % 2) * 40, W, 80):
            p.fill_rect(x, y, 40, 40, hexc("#c4302a", 0.25))
    p.grain(0.02, 361)
    return p


PAINTS = {
    "open": open_screen,
    "parade": parade,
    "farm": farm,
    "autumn_day": lambda: autumn("day"),
    "autumn_dusk": lambda: autumn("dusk"),
    "table": table,
    "football": football,
    "pie": pie_counter,
    "finale": finale,
}
