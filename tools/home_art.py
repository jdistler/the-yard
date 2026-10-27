#!/usr/bin/env python3
"""Logo cards for Partycade Home, cut from the stock menu's own pictures (the vendor's artwork: they stay on
the cabinet and in games/out, never in git).

  home_art.py ROOTFS OUT_DIR    ROOTFS: the extracted system image (e.g. ~/partycade-dumps/*/rootfs)

Each game's settings page (gameN_settings.jpg, 1024x768, sideways) shows its logo centred near the top, on
black, larger than on the menu screen. (Until 2026-10-27 the logos were cut from the menu screens, where they
sit on a blurred coloured tile with a white frame: the cards carried those along, and the user saw a partial
border.) The logo is the bright shapes around the biggest one, which leaves out the maze below, the divider
line above, and the page's other art; enclosed small holes (inside letters) stay, big dark enclosed areas
(Galaga's swoosh) become transparent. The edge is softened by half a pixel. Needs numpy, scipy, Pillow.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

IMG = "usr/local/share/minigui/res/images"
BAND = (96, 290)
SCALE = 1.5          # rows of the upright page that hold the logo (the divider is at 90)


def cut(page):
    """page: upright HxWx3 uint8. Returns an RGBA uint8 array, cropped to the logo."""
    y0, y1 = BAND
    band = page[y0:y1].astype(float)
    mx = band.max(axis=2)
    mn = band.min(axis=2)
    # Logo pixels: bright, or strongly coloured. The maze is dim blue lines and small brown dots.
    strong = (mx > 110) | ((mx - mn) > 90) & (mx > 70)
    lab, n = ndimage.label(strong)
    if n == 0:
        raise ValueError("no logo found")
    sizes = ndimage.sum(strong, lab, range(1, n + 1))
    big = int(np.argmax(sizes)) + 1
    ys, xs = np.nonzero(lab == big)
    bx0, by0, bx1, by1 = xs.min(), ys.min(), xs.max(), ys.max()
    # The box grows with every shape it touches, until it stops (Pac-Man Plus is separate letters).
    keep = np.zeros_like(strong)
    pad = 26
    objs = ndimage.find_objects(lab)
    taken = set()
    grown = True
    while grown:
        grown = False
        for i, sl in enumerate(objs, start=1):
            if i in taken:
                continue
            sy, sx = sl
            h, w = sy.stop - sy.start, sx.stop - sx.start
            if sx.stop < bx0 - pad or sx.start > bx1 + pad or sy.stop < by0 - pad or sy.start > by1 + pad:
                continue
            if (w > 200 and h < 8) or (sizes[i - 1] < 6 and i != big):
                continue
            taken.add(i)
            keep |= lab == i
            bx0, by0 = min(bx0, sx.start), min(by0, sy.start)
            bx1, by1 = max(bx1, sx.stop - 1), max(by1, sy.stop - 1)
            grown = True
    # Close tiny gaps (outlines), then fill small enclosed holes (inside letters); big ones stay see-through.
    m = ndimage.binary_closing(keep, iterations=2) | keep
    holes = ndimage.binary_fill_holes(m) & ~m
    hl, hn = ndimage.label(holes)
    if hn:
        hs = ndimage.sum(holes, hl, range(1, hn + 1))
        small = np.isin(hl, np.nonzero(hs < 900)[0] + 1)
        m |= small
    # Dark outlines around the letters: pixels next to the logo that are darker than the black page's noise
    # are part of it too (Dig Dug's black outline is drawn on black: it is simply kept as opaque black).
    m = m | (ndimage.binary_dilation(m, iterations=1) & (mx < 40))
    alpha = ndimage.gaussian_filter(m.astype(float), 0.6)
    alpha = np.clip(alpha * 1.15, 0, 1)
    ys, xs = np.nonzero(alpha > 0.02)
    cy0, cy1, cx0, cx1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgba = np.dstack([band, alpha * 255])[cy0:cy1, cx0:cx1]
    return rgba.clip(0, 255).astype(np.uint8)


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    root, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    for i in range(12):
        page = Image.open(os.path.join(root, IMG, f"game{i}_settings.jpg")).convert("RGB").rotate(-90, expand=True)
        rgba = cut(np.asarray(page))
        im = Image.fromarray(rgba, "RGBA")
        # Home shows a logo ~1.5x its size on the chosen card: made here with a better filter than the GPU's
        # (and the card scales it down a little, with mipmaps, which keeps it crisp).
        im = im.resize((round(im.width * SCALE), round(im.height * SCALE)), Image.LANCZOS)
        # 256 colours (with alpha): a quarter of the size, no visible change on these flat logos (/userdata is
        # nearly full).
        im = im.quantize(256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
        im.save(os.path.join(out, f"classic_{i}.png"), optimize=True)
        print(f"classic_{i}.png {im.size[0]}x{im.size[1]}")


if __name__ == "__main__":
    main()
