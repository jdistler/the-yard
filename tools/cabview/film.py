#!/usr/bin/env python3
"""tools/cabview/film.py OUT_DIR < stream: split `cabctl record`'s PPM stream into upright PNGs.

Writes OUT_DIR/NNNN.png (the player's view), OUT_DIR/timeline.txt (time, framebuffer, the program holding
the display, mean colour), and OUT_DIR/sheet.png (every frame small, with its time). tools/cab.sh film runs it.
"""
import io
import os
import sys

from PIL import Image, ImageDraw


def frames(data):
    i = 0
    while i < len(data):
        if data[i:i + 2] != b"P6":
            return
        header, fields = [], []
        j = i + 2
        comment = ""
        while len(fields) < 3:
            line_end = data.index(b"\n", j)
            line = data[j:line_end].decode().strip()
            j = line_end + 1
            if line.startswith("#"):
                comment = line[1:].strip()
                continue
            fields += line.split()
        w, h, _ = (int(x) for x in fields[:3])
        size = w * h * 3
        yield comment, Image.frombytes("RGB", (w, h), data[j:j + size])
        i = j + size


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    data = sys.stdin.buffer.read()
    shots, lines = [], []
    for n, (comment, im) in enumerate(frames(data)):
        up = im.rotate(-90, expand=True)
        up.save(os.path.join(out, f"{n:04d}.png"))
        px = list(up.resize((24, 32)).getdata())
        mean = tuple(sum(p[k] for p in px) // len(px) for k in range(3))
        lines.append(f"{n:04d} {comment} mean {mean}")
        shots.append((comment, up))
    open(os.path.join(out, "timeline.txt"), "w").write("\n".join(lines) + "\n")
    if shots:
        tw, th = shots[0][1].size
        cols = 10
        rows = (len(shots) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * tw, rows * (th + 14)), (20, 20, 20))
        d = ImageDraw.Draw(sheet)
        for n, (comment, up) in enumerate(shots):
            x, y = (n % cols) * tw, (n // cols) * (th + 14)
            sheet.paste(up, (x, y + 14))
            d.text((x + 2, y + 1), comment.replace("fb ", "").split(" master")[0][2:], fill=(255, 255, 0))
        sheet.save(os.path.join(out, "sheet.png"))
    print(f"{len(shots)} frames in {out}")


if __name__ == "__main__":
    main()
