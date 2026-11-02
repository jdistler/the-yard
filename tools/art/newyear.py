"""The New Year's Eve show's pictures (newyear.lua). Each laid out under its scene's live parts (the disco ball,
the floor's colours, balloons, the dancers, the chalk's words, the ball coming down, the clock, the countdown,
fireworks, sparklers: all live).
"""
import math

from paint import Paint, W, H, hexc, mix, rng
from scenery import stars, windows_grid

PARTY = ["#ff4fd8", "#ffd23f", "#4fd0ff", "#7aff6a", "#ff7a3a"]


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


def skyline(p, base, seed, col="#0c0a1c", lit=0.5, tall=1.0):
    r = rng(seed)
    x = -10
    while x < W:
        w = 40 + r.random() * 60
        h = (120 + r.random() * 260) * tall
        p.fill_rect(x, base - h, w, h + 400, p.lin(x, 0, x + w, 0, [(0, col), (1, mix(col, "#2a2240", 0.5))]))
        windows_grid(p, x + 4, base - h + 8, w - 8, h - 16, max(2, int(w / 14)), max(2, int(h / 16)), True, int(x) + seed,
                     glass=mix(col, "#2a2240", 0.3), light="#ffd890", frac=lit)
        if r.random() < 0.3:
            p.fill_rect(x + w / 2 - 1.5, base - h - 30, 3, 30, col)
            p.circle(x + w / 2, base - h - 30, 2.5, "#ff4a4a")
        x += w + 2


def streamers(p, seed, y0=0, n=10):
    r = rng(seed)
    for i in range(n):
        c = PARTY[i % len(PARTY)]
        x0 = r.random() * W
        pts = []
        for k in range(30):
            t = k / 29
            pts.append((x0 + math.sin(t * 8 + i) * 24, y0 + t * (200 + r.random() * 60)))
        p.line(pts, hexc(c, 0.85), 4)


def confetti(p, n, seed, y0=0, y1=H):
    r = rng(seed)
    for i in range(n):
        x, y = r.random() * W, y0 + r.random() * (y1 - y0)
        c = PARTY[r.randrange(len(PARTY))]
        p.cr.save()
        p.cr.translate(x, y)
        p.cr.rotate(r.random() * 6.28)
        p.fill_rect(-3, -1.5, 6, 3, hexc(c, 0.85))
        p.cr.restore()


# ------------------------------------------------------------------ the titles
def open_screen():
    p = Paint()
    sky(p, H, [(0, "#04041a"), (0.7, "#1a0c34"), (1, "#3a1440")])
    stars(p, 160, 600, 600)
    skyline(p, 1024, 601, tall=0.8)
    streamers(p, 602, -20, 9)
    confetti(p, 160, 603, 0, 300)
    p.grain(0.015, 604)
    return p


def midnight():
    p = Paint()
    sky(p, H, [(0, "#04041a"), (0.6, "#14082e"), (1, "#3a1030")])
    stars(p, 120, 500, 610)
    skyline(p, 960, 611, lit=0.7, tall=0.9)
    p.fill_rect(0, 900, W, H - 900, p.lin(0, 900, 0, H, [(0, "#1a1028"), (1, "#0a0614")]))
    confetti(p, 200, 612)
    p.grain(0.015, 613)
    return p


# ------------------------------------------------------------------ the party (the disco ball, the floor's lights, balloons, the clock, the dancers are live)
def party():
    p = Paint()
    p.fill_rect(0, 0, W, 760, p.lin(0, 0, 0, 760, [(0, "#16081e"), (1, "#2a1032")]))
    # the walls: panels, sconces
    for x in range(0, W, 128):
        p.fill_rect(x + 8, 40, 112, 680, hexc("#ffffff", 0.03), r=6)
    for x in (60, 708):
        p.fill_rect(x - 10, 420, 20, 30, "#c8a860", r=4)
        p.glow(x, 420, 70, "#ffc070", 0.35)
    # the banner: HAPPY NEW YEAR on pennants
    word = "HAPPY NEW YEAR"
    n = len(word)
    for i, ch in enumerate(word):
        t = i / (n - 1)
        x = 60 + t * 648
        y = 280 + math.sin(t * math.pi) * 40
        if ch == " ":
            continue
        c = PARTY[i % len(PARTY)]
        p.poly([(x - 20, y), (x + 20, y), (x, y + 46)], c)
        label(p, x, y + 16, ch, 18, "#1a0a20")
    p.line([(40, 280), (384, 324), (728, 280)], hexc("#e8e8f0", 0.7), 1.5)
    streamers(p, 620, 0, 8)
    # the dance floor's frame, dark between the lit tiles
    p.fill_rect(0, 760, W, H - 760, "#0a0610")
    for r_ in range(6):
        for c in range(8):
            p.fill_rect(c * 96 + 2, 760 + r_ * 44 + 2, 92, 40, "#1a1220")
    confetti(p, 120, 621, 760, H)
    p.grain(0.015, 622)
    return p


# ------------------------------------------------------------------ resolutions (the chalk's words and checks are live)
def chalkboard():
    p = Paint()
    p.fill_rect(0, 0, W, H, p.lin(0, 0, 0, H, [(0, "#3a2a20"), (1, "#1e140e")]))
    for x in range(0, W, 40):
        p.fill_rect(x, 0, 2, H, hexc("#000000", 0.15))
    # the board: a wooden frame, the slate, chalk dust and old ghost words
    p.fill_rect(40, 150, 688, 700, p.lin(40, 0, 728, 0, [(0, "#6a4228"), (0.5, "#8a5a38"), (1, "#5a3820")]), r=10)
    p.fill_rect(60, 170, 648, 660, p.lin(0, 170, 0, 830, [(0, "#1e3a2a"), (1, "#16301f")]))
    r = rng(630)
    lay = p.layer()
    for i in range(30):
        lay.ellipse(60 + r.random() * 648, 170 + r.random() * 660, 40 + r.random() * 100, 8 + r.random() * 20, hexc("#ffffff", 0.05))
    p.composite(lay, blur=8)
    # the tray, a sponge, chalk
    p.fill_rect(40, 850, 688, 20, "#5a3820")
    p.fill_rect(500, 838, 70, 16, "#e8c860", r=4)
    for i in range(3):
        p.fill_rect(600 + i * 26, 842, 20, 7, ["#ffffff", "#ffd8e8", "#d8f0ff"][i], r=3)
    p.grain(0.02, 631)
    return p


# ------------------------------------------------------------------ the ball drop (the ball, the clock, the countdown, the crowd are live)
def square():
    p = Paint()
    sky(p, 760, [(0, "#02020e"), (1, "#16082a")])
    stars(p, 60, 300, 640)
    r = rng(641)
    # the buildings round the square, billboards glowing
    for i in range(8):
        x, h = i * 100 - 10, 300 + (i % 3) * 120
        p.fill_rect(x, 760 - h, 92, h + 10, p.lin(x, 0, x + 92, 0, [(0, "#0a0814"), (1, "#16122a")]))
        windows_grid(p, x + 6, 760 - h + 12, 80, h - 40, 4, int(h / 30), True, 642 + i, glass="#141024", light="#ffd890", frac=0.55)
        if i != 3 and i != 4:
            bc = PARTY[i % len(PARTY)]
            by = 760 - h + 40 + (i % 2) * 60
            p.fill_rect(x + 6, by, 80, 54, hexc(bc, 0.9), r=3)
            p.fill_rect(x + 10, by + 4, 72, 46, p.lin(0, by, 0, by + 50, [(0, mix(bc, "#ffffff", 0.3)), (1, bc)]), r=2)
            p.glow(x + 46, by + 27, 80, bc, 0.3)
    # the tower under the ball: narrow, its own sign
    p.fill_rect(344, 470, 80, 300, p.lin(344, 0, 424, 0, [(0, "#1a1630"), (0.5, "#2a2448"), (1, "#141028")]))
    for k in range(5):
        p.fill_rect(350, 500 + k * 48, 68, 34, hexc(PARTY[k % len(PARTY)], 0.85), r=2)
    # the street: lit, crowded
    p.fill_rect(0, 760, W, H - 760, p.lin(0, 760, 0, H, [(0, "#1a1428"), (1, "#0a0814")]))
    for i in range(140):
        x, y = r.random() * W, 790 + r.random() * 220
        p.circle(x, y, 10 + r.random() * 4, "#120e1c")
    confetti(p, 140, 643, 0, 760)
    p.grain(0.015, 644)
    return p


# ------------------------------------------------------------------ Auld Lang Syne (the cast, their sparklers are live)
def rooftop():
    p = Paint()
    sky(p, H, [(0, "#02041a"), (0.7, "#0e0c2e"), (1, "#24142e")])
    stars(p, 260, 640, 650)
    skyline(p, 760, 651, col="#0a0a1c", lit=0.6, tall=0.7)
    p.fill_rect(0, 720, W, 60, hexc("#ffb060", 0.06))
    # the roof: a parapet, string lights, a few plants
    p.fill_rect(0, 800, W, H - 800, p.lin(0, 800, 0, H, [(0, "#2a2232"), (1, "#141018")]))
    p.fill_rect(0, 790, W, 16, "#3a3040")
    pts = [(x, 600 + math.sin(x / W * math.pi * 2) * 30 + (x / W) * 40) for x in range(0, W + 1, 12)]
    p.line(pts, hexc("#2a2a30", 0.9), 1.4)
    for i, (x, y) in enumerate(pts[::3]):
        c = ["#fff0c0", "#ffd890", "#ffe8b0"][i % 3]
        p.circle(x, y + 8, 4, c)
        p.glow(x, y + 8, 18, "#ffd080", 0.45)
    for x in (60, 708):
        p.fill_rect(x - 22, 830, 44, 40, "#5a3a2a", r=4)
        for k in range(9):
            a = -math.pi * (0.1 + k / 8 * 0.8)
            p.line([(x, 830), (x + math.cos(a) * 40, 830 + math.sin(a) * 50)], "#2a5a2a", 4)
    p.grain(0.015, 652)
    return p


PAINTS = {
    "open": open_screen,
    "party": party,
    "chalkboard": chalkboard,
    "square": square,
    "midnight": midnight,
    "rooftop": rooftop,
}
