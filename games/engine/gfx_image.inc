/* Images, included into gfx.c. PNG files load with stb_image into the same ARGB layout as
 * gsprite, so pixel art from strings, PNG sheets, and layers all draw through one function. */
#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_PNG
#define STBI_NO_LINEAR
#define STBI_NO_HDR
#define STBI_FAILURE_USERMSG
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-function"
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#pragma GCC diagnostic ignored "-Wsign-compare"
#include "vendor/stb_image.h"
#pragma GCC diagnostic pop

static gsprite *from_rgba(unsigned char *rgba, int w, int h);

gsprite *gfx_image_load(const char *path)
{
    int w, h, n;
    unsigned char *rgba = stbi_load(path, &w, &h, &n, 4);
    if (!rgba) {
        cab_log("image %s: %s", path, stbi_failure_reason());
        return NULL;
    }
    return from_rgba(rgba, w, h);
}

int gfx_image_size(const unsigned char *data, int len, int *w, int *h)
{
    int n;
    return stbi_info_from_memory(data, len, w, h, &n);
}

gsprite *gfx_image_mem(const unsigned char *data, int len)
{
    int w, h, n;
    unsigned char *rgba = stbi_load_from_memory(data, len, &w, &h, &n, 4);
    if (!rgba) {
        cab_log("image: %s", stbi_failure_reason());
        return NULL;
    }
    return from_rgba(rgba, w, h);
}

static gsprite *from_rgba(unsigned char *rgba, int w, int h)
{
    gsprite *s;
    s = calloc(1, sizeof *s);
    if (!s || !(s->px = malloc((size_t)w * h * 4))) {
        free(s);
        stbi_image_free(rgba);
        return NULL;
    }
    s->w = w;
    s->h = h;
    for (int i = 0; i < w * h; i++)
        s->px[i] = ((Uint32)rgba[i * 4 + 3] << 24) | ((Uint32)rgba[i * 4] << 16) | ((Uint32)rgba[i * 4 + 1] << 8) |
                   rgba[i * 4 + 2];
    stbi_image_free(rgba);
    return s;
}

void gfx_sprite_free(gsprite *s)
{
    if (!s)
        return;
    free(s->px);
    free(s);
}

/* Draw the (sx, sy, sw, sh) part of an image so that its origin point (ox, oy, in source
 * pixels) lands on (x, y), scaled by (kx, ky) (negative flips), turned by rot radians.
 * Nearest sampling keeps pixel art crisp. alpha 0..255 multiplies the image's own alpha;
 * tint with alpha > 0 mixes every pixel toward that color by the tint's alpha. */
void gfx_image_draw(const Uint32 *px, int iw, int ih, int sx, int sy, int sw, int sh, float x, float y, float kx,
                    float ky, float rot, float ox, float oy, int alpha, gcol tint)
{
    float c = cosf(rot), s = sinf(rot);
    float corners[4][2] = {{0, 0}, {(float)sw, 0}, {(float)sw, (float)sh}, {0, (float)sh}};
    float minx = 1e9f, miny = 1e9f, maxx = -1e9f, maxy = -1e9f;
    int x0, y0, x1, y1;
    unsigned ta = COL_A(tint);
    if (!px || sw <= 0 || sh <= 0 || kx == 0 || ky == 0 || alpha <= 0)
        return;
    if (sx < 0 || sy < 0 || sx + sw > iw || sy + sh > ih)
        return;
    x += off_x;
    y += off_y;
    for (int i = 0; i < 4; i++) {
        float lx = (corners[i][0] - ox) * kx, ly = (corners[i][1] - oy) * ky;
        float wx = x + lx * c - ly * s, wy = y + lx * s + ly * c;
        minx = fminf(minx, wx);
        maxx = fmaxf(maxx, wx);
        miny = fminf(miny, wy);
        maxy = fmaxf(maxy, wy);
    }
    x0 = (int)floorf(minx);
    y0 = (int)floorf(miny);
    x1 = (int)ceilf(maxx);
    y1 = (int)ceilf(maxy);
    if (x0 < clip_x0)
        x0 = clip_x0;
    if (y0 < clip_y0)
        y0 = clip_y0;
    if (x1 > clip_x1)
        x1 = clip_x1;
    if (y1 > clip_y1)
        y1 = clip_y1;
    for (int yy = y0; yy < y1; yy++) {
        Uint32 *row = tgt->px + yy * tgt->w;
        float dy = yy + 0.5f - y;
        for (int xx = x0; xx < x1; xx++) {
            float dx = xx + 0.5f - x;
            /* Back to source space: undo the turn, then the scale. */
            float u = (dx * c + dy * s) / kx + ox, v = (-dx * s + dy * c) / ky + oy;
            int iu, iv;
            Uint32 p;
            unsigned a;
            if (u < 0 || v < 0 || u >= sw || v >= sh)
                continue;
            iu = (int)u;
            iv = (int)v;
            p = px[(sy + iv) * iw + sx + iu];
            a = (p >> 24) * (unsigned)alpha / 255;
            if (!a)
                continue;
            if (ta)
                p = blend(p | 0xff000000u, tint, ta);
            row[xx] = blend(row[xx], p, a);
        }
    }
}
