#!/usr/bin/env python3
"""Logo cards for Partycade Home, cut from the stock menu's own pictures (the vendor's artwork: they stay on
the cabinet and in games/out, never in git).

  home_art.py ROOTFS OUT_DIR    ROOTFS: the extracted system image (e.g. ~/partycade-dumps/*/rootfs)

The stock menu's game_N.jpg are whole menu screens (1024x768, sideways) with tile N highlighted: a 3x4 grid
of logo panels on yellow. Each logo is cut from a screen where it is not highlighted, wider than its tile
(logos overhang), and the yellow and the tile frame around it are made transparent by a flood fill from the
edges (yellow inside the letters, as in PAC-MAN, stays), with the panel's yellow glow faded out.
Needs numpy, scipy, Pillow.
"""
import os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

IMG = "usr/local/share/minigui/res/images"
YELLOW = (242, 201, 31)


def tile_boxes(screens):
    """Each tile's box (upright 768x1024 coordinates) from where its highlight differs from the average."""
    avg = np.mean(screens, axis=0)
    boxes = []
    for s in screens:
        d = np.abs(s - avg).sum(axis=2) > 90
        ys, xs = np.nonzero(d)
        boxes.append((int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())))
    return boxes


def cut(src, box):
    x0, y0, x1, y1 = box
    c = src[y0 - 6:y1 + 6, x0 - 34:x1 + 34].astype(float)
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    dy = np.sqrt((r - YELLOW[0]) ** 2 + (g - YELLOW[1]) ** 2 + (b - YELLOW[2]) ** 2)
    mx, mn = np.maximum(np.maximum(r, g), b), np.minimum(np.minimum(r, g), b)
    grey = (mn > 140) & ((mx - mn) < 60)
    near_edge = np.zeros(dy.shape, bool)
    near_edge[:12, :] = near_edge[-12:, :] = near_edge[:, :12] = near_edge[:, -12:] = True
    white = (r > 200) & (g > 200) & (b > 170)
    lab, _ = ndimage.label((dy < 70) | white | (grey & near_edge))
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    outside = np.isin(lab, list(edge))
    dist = ndimage.distance_transform_edt(~outside)
    yellowness = np.clip(1 - (dy - 30) / 110, 0, 1)
    alpha = np.ones(dy.shape)
    alpha[outside] = 0
    halo = (dist > 0) & (dist < 14)
    alpha[halo] *= 1 - yellowness[halo] * np.clip(1 - dist[halo] / 14, 0, 1)
    alpha[grey & near_edge] = 0
    return Image.fromarray(np.dstack([c, alpha * 255]).astype(np.uint8), "RGBA")


def main():
    root, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    screens = [np.asarray(Image.open(os.path.join(root, IMG, f"game_{i}.jpg")).convert("RGB")
                          .transpose(Image.ROTATE_270)).astype(int) for i in range(12)]
    boxes = tile_boxes(screens)
    for i, box in enumerate(boxes):
        cut(screens[(i + 1) % 12], box).save(os.path.join(out, f"classic_{i}.png"), optimize=True)
    print(f"{len(boxes)} cards -> {out} ({sum(os.path.getsize(os.path.join(out, f)) for f in os.listdir(out)) // 1024} KB)")


if __name__ == "__main__":
    main()
