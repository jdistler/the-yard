"""Starlight's own pictures (main.lua): the living menu's world, one painting a season, and the marquee board.

The world: a big Texas night sky (the Milky Way, stars), a small-town horizon at about y 700-800 (a porch-lit house,
live oaks, a windmill, the water tower, the town's lights far off), the ground under the info panel. The STARLIGHT
marquee board hangs at the top (y 14-166); its neon letters and its chaser bulbs are drawn live by Home.

Seasons (main.lua picks one by the calendar and the Longhorns' news): base, christmas, halloween, thanksgiving,
newyear, valentine, easter, spring (bluebonnets), summer, july4, gameday (the Tower lit orange on the horizon).
"""
import math

from paint import Paint, W, H, hexc, mix, rng
from scenery import live_oak, hill_band, stars, milky_way, wildflowers

HORIZON = 760
BOARD = (64, 14, 640, 152)              # the marquee board: x, y, w, h (Home draws its bulbs on the frame's line)

SKIES = {
    "base": ("#03041a", "#0e1240", "#2a1e52"),
    "christmas": ("#02061c", "#0c1a44", "#24305a"),
    "halloween": ("#0a0414", "#22082a", "#4a1438"),
    "thanksgiving": ("#0a0618", "#2a1230", "#5a2a2a"),
    "newyear": ("#02021a", "#120a3a", "#2a0e48"),
    "valentine": ("#0e041a", "#2a0a34", "#5a1a48"),
    "easter": ("#0a0e2e", "#2a2e6a", "#6a4a8a"),
    "spring": ("#060a2a", "#1e2a62", "#5a3a7a"),
    "summer": ("#040a24", "#14245a", "#3a2a62"),
    "july4": ("#02041c", "#0c1648", "#2a1e52"),
    "gameday": ("#08041a", "#24102a", "#6a2a14"),
}


def label(p, x, y, text, size, col, font="Fredoka", bold=True):
    cr = p.cr
    cr.save()
    cr.select_font_face(font, 0, 1 if bold else 0)
    cr.set_font_size(size)
    e = cr.text_extents(text)
    p.src(col)
    cr.move_to(x - e.width / 2 - e.x_bearing, y)
    cr.show_text(text)
    cr.restore()


def board(p):
    """The marquee board: a dark enamel panel in a riveted steel frame, two struts down behind the sky."""
    x, y, w, h = BOARD
    for sx in (x + 70, x + w - 70):
        p.fill_rect(sx - 5, y + h, 10, 120, p.lin(sx - 5, 0, sx + 5, 0, [(0, "#14141c"), (0.5, "#3a3a46"), (1, "#14141c")]))
    p.glow(W / 2, y + h / 2, 420, "#ffb050", 0.14, 0.4)
    p.fill_rect(x - 6, y - 6, w + 12, h + 12, p.lin(0, y, 0, y + h, [(0, "#4a4652"), (0.5, "#2a2832"), (1, "#18161e")]), r=20)
    p.fill_rect(x + 10, y + 10, w - 20, h - 20, p.lin(0, y, 0, y + h, [(0, "#0e0a1a"), (1, "#06040e")]), r=12)
    # rivets on the frame between the bulbs' places
    for i in range(40):
        t = i / 40
        for (px, py) in ((x + t * w, y - 2), (x + t * w, y + h + 2)):
            p.circle(px, py, 1.6, "#6a6672")
    # faint tube mounts behind the letters
    for i in range(9):
        p.fill_rect(x + 60 + i * 64, y + 26, 2, h - 52, hexc("#ffffff", 0.04))


def town(p, season):
    """The horizon: hills, the town's lights far off, the water tower, a windmill, live oaks, the house with its
    porch light; the ground."""
    r = rng(2000)
    hill_band(p, HORIZON - 40, 22, "#0a0a1a", 2001, bottom=HORIZON + 20)
    # the town far off: a strip of tiny lights, the water tower, a steeple
    for i in range(160):
        x = r.random() * W
        y = HORIZON - 18 + r.random() * 16
        p.circle(x, y, 0.8 + r.random() * 0.8, hexc(["#ffd890", "#ffe8c0", "#ffb070"][i % 3], 0.6 + r.random() * 0.4))
    p.glow(W * 0.62, HORIZON - 10, 260, "#ffb060", 0.12, 0.25)
    tx = 560
    p.fill_rect(tx - 2, HORIZON - 120, 4, 90, "#08080e")
    p.fill_rect(tx - 26, HORIZON - 120, 4, 90, "#08080e")
    p.fill_rect(tx + 22, HORIZON - 120, 4, 90, "#08080e")
    p.ellipse(tx, HORIZON - 138, 40, 26, "#0a0a12")
    p.fill_rect(tx - 40, HORIZON - 140, 80, 16, "#0a0a12")
    label(p, tx, HORIZON - 128, "ROUND ROCK" if season != "gameday" else "HOOK 'EM", 9, hexc("#3a3a4a", 1))
    p.circle(tx, HORIZON - 168, 3, "#ff4040")
    # the Tower lit orange on game days, far off
    if season == "gameday":
        gx = 300
        p.glow(gx, HORIZON - 90, 120, "#ff8a2a", 0.45, 1.4)
        p.fill_rect(gx - 7, HORIZON - 130, 14, 110, "#ffe8d0")
        p.fill_rect(gx - 9, HORIZON - 150, 18, 22, "#ff8c2a")
        p.poly([(gx - 6, HORIZON - 150), (gx + 6, HORIZON - 150), (gx, HORIZON - 166)], "#ff8c2a")
    # the near ground
    p.fill_rect(0, HORIZON, W, H - HORIZON, p.lin(0, HORIZON, 0, H, [(0, "#0c0c16"), (1, "#040408")]))
    hill_band(p, HORIZON + 8, 10, "#0e0e18", 2002, bottom=H)
    # live oaks in silhouette
    for (x, s, fl, seed) in ((70, 0.62, False, 2003), (700, 0.55, True, 2004), (420, 0.38, False, 2005)):
        oak = p.layer()
        live_oak(oak, x, HORIZON + 30, s, "day", seed, fl)
        cr = oak.cr
        cr.save()
        cr.identity_matrix()
        cr.set_operator(5)
        cr.set_source_rgba(0.03, 0.03, 0.06, 1)
        cr.paint()
        cr.restore()
        p.composite(oak)
    # the windmill
    wx, wy = 640, HORIZON + 20
    for (a, b) in (((wx - 14, wy), (wx, wy - 120)), ((wx + 14, wy), (wx, wy - 120))):
        p.line([a, b], "#06060c", 3)
    for i in range(14):
        a = i / 14 * 2 * math.pi + 0.2
        p.line([(wx, wy - 124), (wx + math.cos(a) * 24, wy - 124 + math.sin(a) * 24)], "#06060c", 2.4)
    p.poly([(wx, wy - 127), (wx + 36, wy - 132), (wx + 38, wy - 120), (wx, wy - 121)], "#06060c")
    # the house: a porch-lit farmhouse on the left
    hx, hy = 210, HORIZON + 26
    p.fill_rect(hx - 70, hy - 70, 140, 70, "#0a0a12")
    p.poly([(hx - 82, hy - 70), (hx + 82, hy - 70), (hx, hy - 118)], "#08080e")
    p.fill_rect(hx - 74, hy - 30, 148, 6, "#0e0e16")
    for (wx2, wy2) in ((hx - 48, hy - 58), (hx + 30, hy - 58)):
        p.fill_rect(wx2, wy2, 18, 20, "#ffcf80")
        p.glow(wx2 + 9, wy2 + 10, 34, "#ffb860", 0.35)
    p.fill_rect(hx - 8, hy - 26, 16, 26, "#ffd890")
    p.glow(hx, hy - 30, 60, "#ffc070", 0.5)
    p.fill_rect(hx - 2, hy - 104, 4, 12, "#0a0a12")
    return (hx, hy)


def decorate(p, season, house):
    hx, hy = house
    r = rng(2100)
    if season == "christmas":
        cols = ["#ff3a3a", "#3aff6a", "#ffd23a", "#4ab0ff"]
        for i in range(18):
            t = i / 17
            x, y = hx - 82 + t * 164, hy - 70 - math.sin(t * math.pi) * 0 - abs(t - 0.5) * 0
            y = hy - 70 + (abs(t - 0.5) * 2) ** 2 * 0
            p.circle(hx - 82 + t * 82, hy - 70 - t * 48, 2.4, cols[i % 4])
            p.circle(hx + t * 82, hy - 118 + t * 48, 2.4, cols[(i + 2) % 4])
        for i in range(30):
            p.circle(r.random() * W, HORIZON + 4 + r.random() * 10, 2 + r.random() * 3, hexc("#e8eeff", 0.8))
        p.fill_rect(0, HORIZON + 6, W, 14, hexc("#c8d4f0", 0.35))
        p.poly([(hx - 82, hy - 70), (hx, hy - 118), (hx + 82, hy - 70), (hx + 70, hy - 66), (hx, hy - 110), (hx - 70, hy - 66)], "#dce4f8")
    elif season == "halloween":
        for i in range(5):
            x = 120 + i * 140
            p.circle(x, HORIZON + 22, 9, "#e8701a")
            p.glow(x, HORIZON + 20, 20, "#ff8a2a", 0.5)
        p.fill_rect(hx - 48, hy - 58, 18, 20, "#ff8a2a")
    elif season in ("july4",):
        p.fill_rect(hx + 60, hy - 120, 3, 60, "#14141c")
        for k in range(7):
            p.fill_rect(hx + 63, hy - 120 + k * 4, 30, 4, "#c4202a" if k % 2 == 0 else "#ffffff")
        p.fill_rect(hx + 63, hy - 120, 12, 14, "#1a3a8a")
    elif season in ("spring", "easter"):
        wildflowers(p, HORIZON + 4, HORIZON + 60, 2101, n=900)
    elif season == "thanksgiving":
        for i in range(4):
            p.circle(160 + i * 160, HORIZON + 22, 8, "#e8801a")
    elif season == "valentine":
        p.glow(W / 2, HORIZON - 40, 360, "#ff6fa8", 0.12, 0.4)


def world(season):
    p = Paint()
    top, mid, bot = SKIES[season]
    p.fill_rect(0, 0, W, HORIZON, p.lin(0, 0, 0, HORIZON, [(0, top), (0.6, mid), (1, bot)]))
    stars(p, 520, HORIZON - 60, 2010, big=0.03)
    milky_way(p, -60, 640, 840, 140, 2011, width=110, bright=0.85)
    house = town(p, season)
    decorate(p, season, house)
    board(p)
    p.grain(0.012, 2012)
    return p


PAINTS = {"world_" + s: (lambda s=s: world(s)) for s in SKIES}
