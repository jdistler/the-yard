"""Painting the shows' backgrounds on the PC (pycairo), for Home to show as pictures (tools/show_art.py).

A Paint is a 768 x 1024 picture drawn at twice that size and scaled down (smooth edges), in Home's coordinates.
Helpers: gradients, shapes, soft shadows and glows (a blurred layer), grain, and saving as PNG and ETC1 (.pkm:
the cabinet's Mali-400 reads ETC1 directly, 0.5 bytes a pixel: a full screen is 393 KB of graphics memory).
"""
import math
import os
import random
import struct

import cairo
import numpy as np
from PIL import Image, ImageFilter

W, H = 768, 1024
SS = 2                                                  # supersampling


def hexc(c, a=1.0):
    if isinstance(c, (tuple, list)):
        return (c[0], c[1], c[2], c[3] if len(c) > 3 else a)
    c = c.lstrip("#")
    return (int(c[0:2], 16) / 255, int(c[2:4], 16) / 255, int(c[4:6], 16) / 255, a)


def mix(a, b, k):
    a, b = hexc(a), hexc(b)
    return tuple(a[i] + (b[i] - a[i]) * k for i in range(4))


class Paint:
    def __init__(self, w=W, h=H, bg=None):
        self.w, self.h = w, h
        self.surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, w * SS, h * SS)
        self.cr = cairo.Context(self.surf)
        self.cr.scale(SS, SS)
        self.cr.set_line_join(cairo.LINE_JOIN_ROUND)
        self.cr.set_line_cap(cairo.LINE_CAP_ROUND)
        if bg:
            self.fill_rect(0, 0, w, h, bg)

    # ------------------------------------------------------------------ colour sources
    def lin(self, x0, y0, x1, y1, stops):
        g = cairo.LinearGradient(x0, y0, x1, y1)
        for off, c in stops:
            g.add_color_stop_rgba(off, *hexc(c))
        return g

    def rad(self, cx, cy, r0, r1, stops, sx=1.0, sy=1.0):
        g = cairo.RadialGradient(cx / sx, cy / sy, r0, cx / sx, cy / sy, r1)
        for off, c in stops:
            g.add_color_stop_rgba(off, *hexc(c))
        if sx != 1 or sy != 1:
            m = cairo.Matrix(xx=1 / sx, yy=1 / sy)
            g.set_matrix(m)
        return g

    def src(self, s):
        if isinstance(s, cairo.Pattern):
            self.cr.set_source(s)
        else:
            self.cr.set_source_rgba(*hexc(s))

    # ------------------------------------------------------------------ shapes
    def fill_rect(self, x, y, w, h, s, r=0):
        self.rrect(x, y, w, h, r)
        self.src(s)
        self.cr.fill()

    def rrect(self, x, y, w, h, r=0):
        cr = self.cr
        if r <= 0:
            cr.rectangle(x, y, w, h)
            return
        r = min(r, w / 2, h / 2)
        cr.new_sub_path()
        cr.arc(x + w - r, y + r, r, -math.pi / 2, 0)
        cr.arc(x + w - r, y + h - r, r, 0, math.pi / 2)
        cr.arc(x + r, y + h - r, r, math.pi / 2, math.pi)
        cr.arc(x + r, y + r, r, math.pi, 1.5 * math.pi)
        cr.close_path()

    def poly(self, pts, s, close=True):
        cr = self.cr
        cr.move_to(*pts[0])
        for p in pts[1:]:
            cr.line_to(*p)
        if close:
            cr.close_path()
        self.src(s)
        cr.fill()

    def path(self, cmds):
        """cmds: ("M", x, y), ("L", x, y), ("C", x1, y1, x2, y2, x, y), ("Z",)"""
        cr = self.cr
        for c in cmds:
            if c[0] == "M":
                cr.move_to(c[1], c[2])
            elif c[0] == "L":
                cr.line_to(c[1], c[2])
            elif c[0] == "C":
                cr.curve_to(*c[1:])
            elif c[0] == "Z":
                cr.close_path()

    def fill_path(self, cmds, s):
        self.path(cmds)
        self.src(s)
        self.cr.fill()

    def circle(self, x, y, r, s):
        self.cr.arc(x, y, r, 0, 2 * math.pi)
        self.src(s)
        self.cr.fill()

    def ellipse(self, x, y, rx, ry, s):
        cr = self.cr
        cr.save()
        cr.translate(x, y)
        cr.scale(rx, ry)
        cr.arc(0, 0, 1, 0, 2 * math.pi)
        cr.restore()
        self.src(s)
        cr.fill()

    def line(self, pts, s, width=1.0):
        cr = self.cr
        cr.move_to(*pts[0])
        for p in pts[1:]:
            cr.line_to(*p)
        cr.set_line_width(width)
        self.src(s)
        cr.stroke()

    # ------------------------------------------------------------------ layers: soft shadows, glows, grain
    def layer(self):
        """A transparent layer the same size, to draw on and then blur/composite."""
        return Paint(self.w, self.h)

    def composite(self, other, blur=0.0, alpha=1.0, op=cairo.OPERATOR_OVER):
        surf = other.surf
        if blur > 0:
            # (blurred premultiplied: blurring straight alpha drags black in from the clear pixels, a dark rim)
            img = to_pil(surf).convert("RGBa").filter(ImageFilter.GaussianBlur(blur * SS)).convert("RGBA")
            surf = from_pil(img)
        cr = self.cr
        cr.save()
        cr.identity_matrix()
        cr.set_operator(op)
        cr.set_source_surface(surf, 0, 0)
        cr.paint_with_alpha(alpha)
        cr.restore()

    def glow(self, x, y, r, c, alpha=1.0, sy=1.0):
        g = self.rad(x, y * 1.0, 0, r, [(0, hexc(c, alpha)), (0.4, hexc(c, alpha * 0.35)), (1, hexc(c, 0))], 1.0, sy)
        self.cr.save()
        self.cr.set_operator(cairo.OPERATOR_ADD)
        self.src(g)
        self.cr.rectangle(x - r, y - r * sy, 2 * r, 2 * r * sy)
        self.cr.fill()
        self.cr.restore()

    def grain(self, amount=0.03, seed=1):
        """A little noise over everything: paint, not plastic (and ETC1 bands less on gradients)."""
        a = np.ndarray(shape=(self.h * SS, self.w * SS, 4), dtype=np.uint8, buffer=self.surf.get_data())
        rng = np.random.default_rng(seed)
        n = (rng.standard_normal((self.h * SS, self.w * SS, 1)) * amount * 255).astype(np.int16)
        rgb = a[:, :, :3].astype(np.int16) + n
        a[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
        self.surf.mark_dirty()

    # ------------------------------------------------------------------ out
    def image(self):
        img = to_pil(self.surf)
        return img.resize((self.w, self.h), Image.LANCZOS)

    def save(self, base, alpha=False):
        os.makedirs(os.path.dirname(base), exist_ok=True)
        img = self.image()
        if alpha:
            img.save(base + ".png", optimize=True)
            return img
        rgb = img.convert("RGB")
        rgb.save(base + ".png", optimize=True)
        write_pkm(rgb, base + ".pkm")
        return rgb


def to_pil(surf):
    w, h = surf.get_width(), surf.get_height()
    buf = surf.get_data()
    a = np.ndarray(shape=(h, w, 4), dtype=np.uint8, buffer=buf).copy()
    # cairo: premultiplied BGRA
    b, g, r, al = a[:, :, 0].astype(np.float32), a[:, :, 1].astype(np.float32), a[:, :, 2].astype(np.float32), a[:, :, 3]
    with np.errstate(divide="ignore", invalid="ignore"):
        k = np.where(al > 0, 255.0 / al, 0)
    out = np.dstack([np.clip(r * k, 0, 255), np.clip(g * k, 0, 255), np.clip(b * k, 0, 255), al]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def from_pil(img):
    img = img.convert("RGBA")
    a = np.asarray(img).astype(np.float32)
    al = a[:, :, 3:4] / 255.0
    pre = np.dstack([a[:, :, 2:3] * al, a[:, :, 1:2] * al, a[:, :, 0:1] * al, a[:, :, 3:4]]).astype(np.uint8)
    pre = np.ascontiguousarray(pre)
    surf = cairo.ImageSurface.create_for_data(bytearray(pre.tobytes()), cairo.FORMAT_ARGB32, img.width, img.height)
    return surf


def write_pkm(rgb, path):
    """ETC1 in a PKM file (LÖVE reads it as CompressedImageData)."""
    import etcpak
    w, h = rgb.size
    pw, ph = (w + 3) // 4 * 4, (h + 3) // 4 * 4
    if (pw, ph) != (w, h):
        canvas = Image.new("RGB", (pw, ph))
        canvas.paste(rgb, (0, 0))
        rgb = canvas
    rgba = rgb.convert("RGBA").tobytes()
    data = etcpak.compress_etc1_rgb_dither(rgba, pw, ph) if hasattr(etcpak, "compress_etc1_rgb_dither") else \
        etcpak.compress_to_etc1_dither(rgba, pw, ph)
    with open(path, "wb") as f:
        f.write(b"PKM 10" + struct.pack(">HHHHH", 0, pw, ph, w, h))
        f.write(data)


def decode_pkm(path):
    """What the cabinet will show: the .pkm decoded back (for checking)."""
    import texture2ddecoder
    with open(path, "rb") as f:
        d = f.read()
    pw, ph, w, h = struct.unpack(">HHHH", d[8:16])
    rgba = texture2ddecoder.decode_etc1(d[16:], pw, ph)
    img = Image.frombytes("RGBA", (pw, ph), rgba, "raw", "BGRA")
    return img.crop((0, 0, w, h)).convert("RGB")


def rng(seed):
    return random.Random(seed)
