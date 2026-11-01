#!/usr/bin/env python3
"""tvplay's glyph sheet: Home's font (Fredoka SemiBold) rasterised at the sizes tvplay draws, into one alpha
atlas, gzipped (tvplay reads it with zlib).

  games/tv/mkfont.py OUT.gz

Format (little-endian): "TVF1", atlas w u16, h u16, sizes u16; per size: px u16, line height u16, ascent u16,
glyph count u16, then per glyph: codepoint u16, x u16, y u16, w u8, h u8, xoff s8, yoff s8, advance u8, pad u8;
then w*h alpha bytes. yoff is from the baseline down to the glyph's top (negative = above).
"""
import gzip, os, struct, sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
TTF = os.path.join(HERE, "..", "engine", "fonts", "Fredoka-SemiBold.ttf")
SIZES = [22, 28, 34, 46]
CHARS = [c for c in range(32, 127)] + [c for c in range(0xA0, 0x100)] + [0x2013, 0x2014, 0x2026, 0x2022]
W = 1024


def main(out):
    glyphs, metas = [], []
    for px in SIZES:
        f = ImageFont.truetype(TTF, px)
        asc, desc = f.getmetrics()
        gl = []
        for c in CHARS:
            ch = chr(c)
            box = f.getbbox(ch)
            adv = round(f.getlength(ch))
            if box is None or box[2] <= box[0]:
                gl.append((c, None, 0, 0, adv))
                continue
            x0, y0, x1, y1 = box
            im = Image.new("L", (x1 - x0 + 2, y1 - y0 + 2), 0)
            ImageDraw.Draw(im).text((1 - x0, 1 - y0), ch, font=f, fill=255)
            # yoff: from the baseline (asc below the text origin) to the glyph image's top
            gl.append((c, im, x0 - 1, y0 - 1 - asc, adv))
        metas.append((px, asc + desc, asc, gl))
    # Shelf packing.
    x = y = shelf = 0
    places = []
    for px, lh, asc, gl in metas:
        for g in gl:
            im = g[1]
            if im is None:
                places.append((0, 0))
                continue
            if x + im.width > W:
                x, y, shelf = 0, y + shelf + 1, 0
            places.append((x, y))
            x += im.width + 1
            shelf = max(shelf, im.height)
    H = 1
    while H < y + shelf + 1:
        H *= 2
    atlas = Image.new("L", (W, H), 0)
    blob = [b"TVF1", struct.pack("<HHH", W, H, len(metas))]
    i = 0
    for px, lh, asc, gl in metas:
        blob.append(struct.pack("<HHHH", px, lh, asc, len(gl)))
        for c, im, xo, yo, adv in gl:
            gx, gy = places[i]
            i += 1
            w, h = (im.width, im.height) if im else (0, 0)
            if im:
                atlas.paste(im, (gx, gy))
            blob.append(struct.pack("<HHHBBbbBB", c, gx, gy, w, h, xo, yo, min(adv, 255), 0))
    blob.append(atlas.tobytes())
    with gzip.GzipFile(out, "wb", 9, mtime=0) as fh:
        fh.write(b"".join(blob))
    print(f"{out}: atlas {W}x{H}, sizes {SIZES}, {len(CHARS)} characters, {os.path.getsize(out)} bytes")


if __name__ == "__main__":
    main(sys.argv[1])
