"""The Freedom Show's pictures (freedom.lua): its sky changes all show long (dawn, day, red alert, the battle's
night, sunset), so the sky stays live; painted here, with transparency, what sits under it.

yard     the backyard from y = 560 down (houses over the fence, the white picket fence, flower beds in red,
         white and blue, the patio where Clyde grills, a lawn chair and cooler, the lawn mowed in stripes)
cloud    a fair-weather cumulus (440 x 180, drawn at half size)
hotdog   the celebratory hot dog (160 x 72, drawn at half size)
"""
import math

from paint import Paint, W, H, hexc, mix, rng
from scenery import cloud as cumulus, live_oak, grass_tufts

GROUND = 836
TOP = 560                       # the yard picture's top, on the screen


def yard():
    p = Paint(W, H - TOP)
    cr = p.cr
    cr.translate(0, -TOP)                                     # draw in screen coordinates
    r = rng(1776)
    # the neighbours' roofs and trees over the fence
    for (x, w, hgt, col, roof) in [(150, 170, 110, "#e8dcc8", "#6a4a3a"), (430, 200, 130, "#c8d4dc", "#4a4a52"),
                                   (660, 160, 100, "#f0e0c0", "#7a4a34")]:
        base = GROUND - 40
        p.fill_rect(x, base - hgt, w, hgt, p.lin(x, 0, x + w, 0, [(0, mix(col, "#000000", 0.12)), (1, col)]))
        p.poly([(x - 14, base - hgt), (x + w + 14, base - hgt), (x + w / 2, base - hgt - 56)],
               p.lin(0, base - hgt - 56, 0, base - hgt, [(0, mix(roof, "#000000", 0.2)), (1, roof)]))
        for i in range(3):
            p.fill_rect(x + 18 + i * (w - 36) / 3, base - hgt + 22, (w - 36) / 3 - 14, 28, "#4a5a6e")
            p.fill_rect(x + 18 + i * (w - 36) / 3, base - hgt + 22, (w - 36) / 3 - 14, 5, hexc("#ffffff", 0.5))
        p.fill_rect(x + w / 2 - 6, base - hgt - 50, 12, 24, mix(roof, "#000000", 0.2))
    # a flag on the neighbour's porch, a tree or two between
    oak = p.layer()
    live_oak(oak, 360, GROUND - 30, 0.55, "day", 1777)
    live_oak(oak, 600, GROUND - 26, 0.45, "day", 1778, flip=True)
    p.composite(oak)
    # the fence: posts, two rails, pickets with their points and shading
    fy = GROUND - 52
    p.fill_rect(0, fy + 22, W, 8, "#e8e8e4")
    p.fill_rect(0, fy + 48, W, 8, "#e8e8e4")
    for x in range(4, W, 26):
        pts = [(x, fy + 12), (x + 8, fy + 2), (x + 16, fy + 12), (x + 16, GROUND + 18), (x, GROUND + 18)]
        p.poly(pts, p.lin(x, 0, x + 16, 0, [(0, "#ffffff"), (0.7, "#f2f2ee"), (1, "#c8c8c4")]))
        p.fill_rect(x + 13, fy + 12, 3, GROUND + 6 - fy - 12, hexc("#9a9a96", 0.55))
    for x in range(4, W, 182):
        p.fill_rect(x - 3, fy - 4, 22, GROUND + 18 - fy + 4, "#f8f8f4")
        p.fill_rect(x - 5, fy - 8, 26, 6, "#ffffff")
    # the lawn: mowed stripes, darker toward us
    p.fill_rect(0, GROUND, W, H - GROUND, p.lin(0, GROUND, 0, H, [(0, "#4a9a34"), (1, "#1e5a1a")]))
    for i in range(10):
        x = i * 90 - 40
        p.poly([(x, GROUND), (x + 45, GROUND), (x + 45 + (x - 384) * 0.25 + 30, H), (x + (x - 384) * 0.25, H)], hexc("#ffffff", 0.05))
    grass_tufts(p, GROUND + 4, H, 1779, 1400, col="#3a7a2a")
    # flower beds along the fence: red, white and blue
    p.fill_rect(0, GROUND, W, 22, "#5a3a24")
    for i in range(140):
        x = r.random() * W
        y = GROUND + 2 + r.random() * 16
        c = ["#d8242a", "#ffffff", "#2a4ab8"][i % 3]
        for k in range(5):
            a = k / 5 * 2 * math.pi
            p.circle(x + math.cos(a) * 3, y + math.sin(a) * 3, 2.4, c)
        p.circle(x, y, 1.4, "#f8d84a")
    # the patio under the grill: flagstones
    for i in range(16):
        a = i / 16 * 2 * math.pi
        for k in range(2):
            rr = 30 + k * 40
            x, y = 640 + math.cos(a) * rr * 1.6, 944 + math.sin(a) * rr * 0.35
            p.ellipse(x, y, 22, 7, hexc("#c8bca4", 0.9))
    p.ellipse(640, 944, 34, 8, "#c8bca4")
    # a lawn chair and a cooler, right
    cx, cy = 728, 958
    for k in range(6):
        p.fill_rect(cx - 22, cy - 40 + k * 7, 44, 4, ["#d8242a", "#ffffff"][k % 2])
    p.line([(cx - 22, cy - 42), (cx - 26, cy + 4)], "#b8b8bc", 3)
    p.line([(cx + 22, cy - 42), (cx + 26, cy + 4)], "#b8b8bc", 3)
    p.fill_rect(cx - 30, cy - 4, 60, 5, "#d8d8dc")
    p.fill_rect(500, 976, 46, 30, "#2a5ab8", r=4)
    p.fill_rect(500, 976, 46, 9, "#ffffff", r=4)
    p.fill_rect(516, 972, 14, 5, "#888888", r=2)
    # a garden hose, coiled by the fence on the left
    for k in range(4):
        cr.save()
        cr.translate(200, 870)
        cr.scale(1, 0.4)
        cr.arc(0, 0, 18 + k * 5, 0, 2 * math.pi)
        cr.restore()
        cr.set_line_width(3)
        p.src("#2a8a3a")
        cr.stroke()
    p.grain(0.015, 1780)
    return p


def cloud():
    p = Paint(440, 180)
    cumulus(p, 220, 120, 1.55, hexc("#ffffff", 0.97), hexc("#c4d0e4", 0.97), 1781)
    return p


def hotdog():
    p = Paint(160, 72)
    p.ellipse(80, 46, 70, 22, p.lin(0, 24, 0, 68, [(0, "#f6c470"), (1, "#c8873a")]))
    p.ellipse(80, 30, 76, 15, p.lin(0, 16, 0, 46, [(0, "#d8603a"), (1, "#8a2a18")]))
    p.ellipse(60, 25, 36, 4, hexc("#ffb08a", 0.6))
    pts = [(14 + i * 10, 26 + (6 if i % 2 else -2)) for i in range(14)]
    p.line(pts, "#f8d020", 4.5)
    p.ellipse(80, 54, 64, 10, hexc("#ffe0a0", 0.35))
    return p


PAINTS = {"yard": yard, "cloud": cloud, "hotdog": hotdog}
ALPHA = ("yard", "cloud", "hotdog")
