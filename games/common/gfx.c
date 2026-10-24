/* gfx: software 2D renderer, text, sprites, particles, RNG, easing. See gfx.h. */
#include "gfx.h"

#include <math.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "font8x8_basic.h"

gsurf gfx_screen;
int gfx_frame;

static gsurf *tgt = &gfx_screen;
static int clip_x0, clip_y0, clip_x1, clip_y1; /* x1, y1 exclusive */
static int off_x, off_y;
static SDL_Texture *stream;
static float shake_amt;
static gcol flash_col;
static int flash_left, flash_len;
static Uint32 pace_at;

/* ------------------------------------------------------------------ setup */

int gfx_init(const char *title, int w, int h)
{
    if (cab_init(title, w, h) != 0)
        return -1;
    if (!gfx_screen.px) {
        gfx_screen.px = calloc((size_t)w * h, sizeof(Uint32));
        if (!gfx_screen.px)
            return -1;
    }
    gfx_screen.w = w;
    gfx_screen.h = h;
    stream = SDL_CreateTexture(cab_renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, w, h);
    if (!stream) {
        cab_log("gfx texture: %s", SDL_GetError());
        return -1;
    }
    gfx_target(NULL);
    shake_amt = 0;
    flash_left = 0;
    pace_at = 0;
    return 0;
}

void gfx_target(gsurf *s)
{
    tgt = s ? s : &gfx_screen;
    gfx_noclip();
}

gsurf *gfx_surf_new(int w, int h)
{
    gsurf *s = calloc(1, sizeof *s);
    if (!s)
        return NULL;
    s->px = calloc((size_t)w * h, sizeof(Uint32));
    if (!s->px) {
        free(s);
        return NULL;
    }
    s->w = w;
    s->h = h;
    return s;
}

void gfx_surf_free(gsurf *s)
{
    if (!s)
        return;
    free(s->px);
    free(s);
}

void gfx_clip(int x, int y, int w, int h)
{
    clip_x0 = x < 0 ? 0 : x;
    clip_y0 = y < 0 ? 0 : y;
    clip_x1 = x + w > tgt->w ? tgt->w : x + w;
    clip_y1 = y + h > tgt->h ? tgt->h : y + h;
}

void gfx_noclip(void)
{
    clip_x0 = clip_y0 = 0;
    clip_x1 = tgt->w;
    clip_y1 = tgt->h;
}

void gfx_offset(int dx, int dy)
{
    off_x = dx;
    off_y = dy;
}

void gfx_shake(float amount)
{
    if (amount > shake_amt)
        shake_amt = amount;
}

void gfx_flash(gcol c, int frames)
{
    flash_col = c;
    flash_left = flash_len = frames;
}

/* ------------------------------------------------------------------ color */

static inline Uint32 blend(Uint32 d, Uint32 c, unsigned a)
{
    unsigned ia;
    Uint32 rb, g;
    if (a >= 255)
        return c | 0xff000000u;
    if (a == 0)
        return d;
    ia = 256 - a;
    a += 1;
    rb = (((c & 0xff00ff) * a + (d & 0xff00ff) * ia) >> 8) & 0xff00ff;
    g = (((c & 0x00ff00) * a + (d & 0x00ff00) * ia) >> 8) & 0x00ff00;
    return 0xff000000u | rb | g;
}

static inline Uint32 add(Uint32 d, Uint32 c, unsigned a)
{
    unsigned r = ((d >> 16) & 255) + ((((c >> 16) & 255) * a) >> 8);
    unsigned g = ((d >> 8) & 255) + ((((c >> 8) & 255) * a) >> 8);
    unsigned b = (d & 255) + (((c & 255) * a) >> 8);
    if (r > 255)
        r = 255;
    if (g > 255)
        g = 255;
    if (b > 255)
        b = 255;
    return 0xff000000u | (r << 16) | (g << 8) | b;
}

gcol col_mix(gcol a, gcol b, float t)
{
    int ra, ga, ba, aa;
    if (t <= 0)
        return a;
    if (t >= 1)
        return b;
    ra = (int)(COL_R(a) + (COL_R(b) - (int)COL_R(a)) * t);
    ga = (int)(COL_G(a) + (COL_G(b) - (int)COL_G(a)) * t);
    ba = (int)(COL_B(a) + (COL_B(b) - (int)COL_B(a)) * t);
    aa = (int)(COL_A(a) + (COL_A(b) - (int)COL_A(a)) * t);
    return RGBA(ra, ga, ba, aa);
}

gcol col_alpha(gcol c, int a)
{
    if (a < 0)
        a = 0;
    if (a > 255)
        a = 255;
    return (c & 0xffffffu) | ((Uint32)a << 24);
}

gcol col_scale(gcol c, float k)
{
    int r = (int)(COL_R(c) * k), g = (int)(COL_G(c) * k), b = (int)(COL_B(c) * k);
    if (r > 255)
        r = 255;
    if (g > 255)
        g = 255;
    if (b > 255)
        b = 255;
    if (r < 0)
        r = 0;
    if (g < 0)
        g = 0;
    if (b < 0)
        b = 0;
    return RGBA(r, g, b, COL_A(c));
}

gcol col_hsv(float h, float s, float v)
{
    float r, g, b, f, p, q, t;
    int i;
    h = fmodf(h, 1.f);
    if (h < 0)
        h += 1.f;
    h *= 6.f;
    i = (int)h;
    f = h - i;
    p = v * (1 - s);
    q = v * (1 - s * f);
    t = v * (1 - s * (1 - f));
    switch (i % 6) {
    case 0: r = v, g = t, b = p; break;
    case 1: r = q, g = v, b = p; break;
    case 2: r = p, g = v, b = t; break;
    case 3: r = p, g = q, b = v; break;
    case 4: r = t, g = p, b = v; break;
    default: r = v, g = p, b = q; break;
    }
    return RGB((int)(r * 255), (int)(g * 255), (int)(b * 255));
}

/* ------------------------------------------------------------------ spans */

static inline void plot(int x, int y, gcol c, unsigned cov)
{
    unsigned a;
    if (x < clip_x0 || x >= clip_x1 || y < clip_y0 || y >= clip_y1)
        return;
    a = (COL_A(c) * cov) >> 8;
    if (a)
        tgt->px[y * tgt->w + x] = blend(tgt->px[y * tgt->w + x], c, a);
}

static void span(int x0, int x1, int y, gcol c)
{
    Uint32 *p;
    unsigned a = COL_A(c);
    if (y < clip_y0 || y >= clip_y1)
        return;
    if (x0 < clip_x0)
        x0 = clip_x0;
    if (x1 > clip_x1)
        x1 = clip_x1;
    if (x0 >= x1)
        return;
    p = tgt->px + y * tgt->w;
    if (a >= 255) {
        Uint32 v = c | 0xff000000u;
        for (int x = x0; x < x1; x++)
            p[x] = v;
    } else if (a) {
        for (int x = x0; x < x1; x++)
            p[x] = blend(p[x], c, a);
    }
}

void gfx_clear(gcol c)
{
    int n = tgt->w * tgt->h;
    Uint32 v = c | 0xff000000u;
    for (int i = 0; i < n; i++)
        tgt->px[i] = v;
}

void gfx_pixel(int x, int y, gcol c) { plot(x + off_x, y + off_y, c, 256); }

void gfx_rect(int x, int y, int w, int h, gcol c)
{
    x += off_x;
    y += off_y;
    for (int yy = y; yy < y + h; yy++)
        span(x, x + w, yy, c);
}

void gfx_rect_add(int x, int y, int w, int h, gcol c)
{
    unsigned a = COL_A(c);
    x += off_x;
    y += off_y;
    for (int yy = y < clip_y0 ? clip_y0 : y; yy < y + h && yy < clip_y1; yy++) {
        Uint32 *p = tgt->px + yy * tgt->w;
        for (int xx = x < clip_x0 ? clip_x0 : x; xx < x + w && xx < clip_x1; xx++)
            p[xx] = add(p[xx], c, a);
    }
}

void gfx_frame_rect(int x, int y, int w, int h, int t, gcol c)
{
    gfx_rect(x, y, w, t, c);
    gfx_rect(x, y + h - t, w, t, c);
    gfx_rect(x, y + t, t, h - 2 * t, c);
    gfx_rect(x + w - t, y + t, t, h - 2 * t, c);
}

/* Ordered dither keeps a long gradient from banding on the panel. */
static const unsigned char bayer4[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};

void gfx_vgrad(int x, int y, int w, int h, gcol top, gcol bot)
{
    x += off_x;
    y += off_y;
    if (h <= 0)
        return;
    for (int yy = y; yy < y + h; yy++) {
        int r0, g0, b0, xs, xe;
        Uint32 pat[4];
        float t;
        Uint32 *p;
        if (yy < clip_y0 || yy >= clip_y1)
            continue;
        t = h > 1 ? (float)(yy - y) / (float)(h - 1) : 0;
        r0 = (int)((COL_R(top) + (COL_R(bot) - COL_R(top)) * t) * 16);
        g0 = (int)((COL_G(top) + (COL_G(bot) - COL_G(top)) * t) * 16);
        b0 = (int)((COL_B(top) + (COL_B(bot) - COL_B(top)) * t) * 16);
        /* Four dithered colors for this row, repeated across it. */
        for (int k = 0; k < 4; k++) {
            int d = bayer4[(yy & 3) * 4 + k];
            int r = (r0 + d) >> 4, g = (g0 + d) >> 4, b = (b0 + d) >> 4;
            pat[k] = 0xff000000u | ((Uint32)(r > 255 ? 255 : r) << 16) | ((Uint32)(g > 255 ? 255 : g) << 8) |
                     (Uint32)(b > 255 ? 255 : b);
        }
        p = tgt->px + yy * tgt->w;
        xs = x < clip_x0 ? clip_x0 : x;
        xe = x + w < clip_x1 ? x + w : clip_x1;
        for (int xx = xs; xx < xe; xx++)
            p[xx] = pat[xx & 3];
    }
}

void gfx_blit(const gsurf *s, int x, int y)
{
    x += off_x;
    y += off_y;
    for (int sy = 0; sy < s->h; sy++) {
        int dy = y + sy, x0 = x, sx0 = 0, n = s->w;
        if (dy < clip_y0 || dy >= clip_y1)
            continue;
        if (x0 < clip_x0) {
            sx0 = clip_x0 - x0;
            n -= sx0;
            x0 = clip_x0;
        }
        if (x0 + n > clip_x1)
            n = clip_x1 - x0;
        if (n > 0)
            memcpy(tgt->px + dy * tgt->w + x0, s->px + sy * s->w + sx0, (size_t)n * sizeof(Uint32));
    }
}

void gfx_surf_clear(gsurf *s) { memset(s->px, 0, (size_t)s->w * s->h * sizeof(Uint32)); }

void gfx_blit_key(const gsurf *s, int x, int y)
{
    x += off_x;
    y += off_y;
    for (int sy = 0; sy < s->h; sy++) {
        int dy = y + sy;
        const Uint32 *src = s->px + sy * s->w;
        Uint32 *dst;
        int xa = x < clip_x0 ? clip_x0 : x, xb = x + s->w > clip_x1 ? clip_x1 : x + s->w;
        if (dy < clip_y0 || dy >= clip_y1)
            continue;
        dst = tgt->px + dy * tgt->w;
        for (int dx = xa; dx < xb; dx++) {
            Uint32 c = src[dx - x];
            if (c >> 24)
                dst[dx] = c;
        }
    }
}

void gfx_hgrad(int x, int y, int w, int h, gcol left, gcol right)
{
    for (int i = 0; i < w; i++)
        gfx_rect(x + i, y, 1, h, col_mix(left, right, w > 1 ? (float)i / (w - 1) : 0));
}

/* ------------------------------------------------------------------ shapes */

void gfx_circle(float cx, float cy, float r, gcol c)
{
    int y0, y1;
    if (r <= 0)
        return;
    cx += off_x;
    cy += off_y;
    y0 = (int)floorf(cy - r - 1);
    y1 = (int)ceilf(cy + r + 1);
    if (y0 < clip_y0)
        y0 = clip_y0;
    if (y1 > clip_y1)
        y1 = clip_y1;
    for (int y = y0; y < y1; y++) {
        float dy = y + 0.5f - cy;
        float ro = r + 0.5f, ri = r - 0.5f;
        float xo, xi;
        int a0, a1, b0, b1;
        if (dy * dy >= ro * ro)
            continue;
        xo = sqrtf(ro * ro - dy * dy);
        xi = ri > 0 && dy * dy < ri * ri ? sqrtf(ri * ri - dy * dy) : 0;
        /* Solid middle, then the edge pixels by distance. */
        b0 = (int)ceilf(cx - xi);
        b1 = (int)floorf(cx + xi);
        if (xi > 0 && b1 > b0)
            span(b0, b1, y, c);
        else
            b0 = b1 = (int)floorf(cx);
        a0 = (int)floorf(cx - xo);
        a1 = (int)ceilf(cx + xo);
        for (int x = a0; x < b0; x++) {
            float dx = x + 0.5f - cx, d = sqrtf(dx * dx + dy * dy);
            float cov = r - d + 0.5f;
            if (cov > 0)
                plot(x, y, c, cov >= 1 ? 256 : (unsigned)(cov * 256));
        }
        for (int x = b1 > b0 ? b1 : b0; x < a1; x++) {
            float dx = x + 0.5f - cx, d = sqrtf(dx * dx + dy * dy);
            float cov = r - d + 0.5f;
            if (cov > 0)
                plot(x, y, c, cov >= 1 ? 256 : (unsigned)(cov * 256));
        }
    }
}

void gfx_ellipse(float cx, float cy, float rx, float ry, gcol c)
{
    int y0, y1;
    if (rx <= 0 || ry <= 0)
        return;
    if (fabsf(rx - ry) < 0.01f) {
        gfx_circle(cx, cy, rx, c);
        return;
    }
    cx += off_x;
    cy += off_y;
    y0 = (int)floorf(cy - ry - 1);
    y1 = (int)ceilf(cy + ry + 1);
    if (y0 < clip_y0)
        y0 = clip_y0;
    if (y1 > clip_y1)
        y1 = clip_y1;
    for (int y = y0; y < y1; y++) {
        float dy = y + 0.5f - cy;
        float t = dy / (ry + 1.f);
        float hw, hwi;
        int a0, a1, b0, b1;
        if (t * t >= 1)
            continue;
        hw = (rx + 1.f) * sqrtf(1 - t * t);
        t = dy / (ry - 1.f > 0.5f ? ry - 1.f : 0.5f);
        hwi = t * t < 1 ? (rx - 1.f) * sqrtf(1 - t * t) : 0;
        b0 = (int)ceilf(cx - hwi);
        b1 = (int)floorf(cx + hwi);
        if (hwi > 0 && b1 > b0)
            span(b0, b1, y, c);
        else
            b0 = b1 = (int)floorf(cx);
        a0 = (int)floorf(cx - hw);
        a1 = (int)ceilf(cx + hw);
        for (int pass = 0; pass < 2; pass++) {
            int xs = pass ? (b1 > b0 ? b1 : b0) : a0, xe = pass ? a1 : b0;
            for (int x = xs; x < xe; x++) {
                float dx = x + 0.5f - cx;
                float nx = dx / rx, ny = dy / ry;
                float f = nx * nx + ny * ny - 1.f;
                float gx = 2 * dx / (rx * rx), gy = 2 * dy / (ry * ry);
                float g = sqrtf(gx * gx + gy * gy);
                float dist = g > 0 ? f / g : f;
                float cov = 0.5f - dist;
                if (cov > 0)
                    plot(x, y, c, cov >= 1 ? 256 : (unsigned)(cov * 256));
            }
        }
    }
}

void gfx_ring(float cx, float cy, float r, float thick, gcol c)
{
    int y0, y1;
    float ro = r + thick * 0.5f, ri = r - thick * 0.5f;
    cx += off_x;
    cy += off_y;
    y0 = (int)floorf(cy - ro - 1);
    y1 = (int)ceilf(cy + ro + 1);
    if (y0 < clip_y0)
        y0 = clip_y0;
    if (y1 > clip_y1)
        y1 = clip_y1;
    for (int y = y0; y < y1; y++) {
        float dy = y + 0.5f - cy;
        float xo;
        if (dy * dy >= (ro + 0.5f) * (ro + 0.5f))
            continue;
        xo = sqrtf((ro + 0.5f) * (ro + 0.5f) - dy * dy);
        for (int x = (int)floorf(cx - xo); x < (int)ceilf(cx + xo); x++) {
            float dx = x + 0.5f - cx, d = sqrtf(dx * dx + dy * dy);
            float cov = fminf(ro - d + 0.5f, d - ri + 0.5f);
            if (cov > 0)
                plot(x, y, c, cov >= 1 ? 256 : (unsigned)(cov * 256));
        }
    }
}

static inline float rbox_sd(float px, float py, float cx, float cy, float hx, float hy, float r)
{
    float qx = fabsf(px - cx) - (hx - r), qy = fabsf(py - cy) - (hy - r);
    float mx = qx > 0 ? qx : 0, my = qy > 0 ? qy : 0;
    float inside = qx > qy ? qx : qy;
    return sqrtf(mx * mx + my * my) + (inside < 0 ? inside : 0) - r;
}

void gfx_rrect(float x, float y, float w, float h, float r, gcol c)
{
    float cx, cy, hx, hy;
    int y0, y1, x0, x1;
    if (w <= 0 || h <= 0)
        return;
    if (r > w / 2)
        r = w / 2;
    if (r > h / 2)
        r = h / 2;
    if (r < 0)
        r = 0;
    x += off_x;
    y += off_y;
    cx = x + w / 2;
    cy = y + h / 2;
    hx = w / 2;
    hy = h / 2;
    y0 = (int)floorf(y);
    y1 = (int)ceilf(y + h);
    x0 = (int)floorf(x);
    x1 = (int)ceilf(x + w);
    if (y0 < clip_y0)
        y0 = clip_y0;
    if (y1 > clip_y1)
        y1 = clip_y1;
    for (int yy = y0; yy < y1; yy++) {
        float py = yy + 0.5f;
        int band = py - 0.5f >= y + r && py + 0.5f <= y + h - r;
        if (band) {
            /* Straight sides: solid between the edge pixels. */
            int edge = (int)ceilf(r) + 1;
            for (int xx = x0; xx < x0 + edge && xx < x1; xx++) {
                float cov = 0.5f - rbox_sd(xx + 0.5f, py, cx, cy, hx, hy, r);
                if (cov > 0)
                    plot(xx, yy, c, cov >= 1 ? 256 : (unsigned)(cov * 256));
            }
            span(x0 + edge, x1 - edge, yy, c);
            for (int xx = x1 - edge > x0 + edge ? x1 - edge : x0 + edge; xx < x1; xx++) {
                float cov = 0.5f - rbox_sd(xx + 0.5f, py, cx, cy, hx, hy, r);
                if (cov > 0)
                    plot(xx, yy, c, cov >= 1 ? 256 : (unsigned)(cov * 256));
            }
        } else {
            /* A corner row: per pixel near the ends, one span between the corners
             * when this row is fully inside vertically. */
            int full = py - 0.5f >= y && py + 0.5f <= y + h;
            int edge = (int)ceilf(r) + 2;
            if (full && x1 - x0 > 2 * edge) {
                for (int xx = x0; xx < x0 + edge; xx++) {
                    float cov = 0.5f - rbox_sd(xx + 0.5f, py, cx, cy, hx, hy, r);
                    if (cov > 0)
                        plot(xx, yy, c, cov >= 1 ? 256 : (unsigned)(cov * 256));
                }
                span(x0 + edge, x1 - edge, yy, c);
                for (int xx = x1 - edge; xx < x1; xx++) {
                    float cov = 0.5f - rbox_sd(xx + 0.5f, py, cx, cy, hx, hy, r);
                    if (cov > 0)
                        plot(xx, yy, c, cov >= 1 ? 256 : (unsigned)(cov * 256));
                }
            } else {
                for (int xx = x0; xx < x1; xx++) {
                    float cov = 0.5f - rbox_sd(xx + 0.5f, py, cx, cy, hx, hy, r);
                    if (cov > 0)
                        plot(xx, yy, c, cov >= 1 ? 256 : (unsigned)(cov * 256));
                }
            }
        }
    }
}

/* Even-odd scanline fill at pixel centers. Small polygons only (64 points). */
void gfx_poly(const float *xy, int n, gcol c)
{
    float miny = 1e9f, maxy = -1e9f;
    int y0, y1;
    if (n < 3 || n > 64)
        return;
    for (int i = 0; i < n; i++) {
        if (xy[i * 2 + 1] < miny)
            miny = xy[i * 2 + 1];
        if (xy[i * 2 + 1] > maxy)
            maxy = xy[i * 2 + 1];
    }
    y0 = (int)floorf(miny + off_y);
    y1 = (int)ceilf(maxy + off_y);
    if (y0 < clip_y0)
        y0 = clip_y0;
    if (y1 > clip_y1)
        y1 = clip_y1;
    for (int y = y0; y < y1; y++) {
        float xs[64];
        int k = 0;
        float py = y + 0.5f - off_y;
        for (int i = 0, j = n - 1; i < n; j = i++) {
            float ya = xy[i * 2 + 1], yb = xy[j * 2 + 1];
            if ((ya <= py && yb > py) || (yb <= py && ya > py)) {
                float xa = xy[i * 2], xb = xy[j * 2];
                xs[k++] = xa + (py - ya) * (xb - xa) / (yb - ya);
            }
        }
        for (int i = 1; i < k; i++)
            for (int j = i; j > 0 && xs[j - 1] > xs[j]; j--) {
                float t = xs[j];
                xs[j] = xs[j - 1];
                xs[j - 1] = t;
            }
        for (int i = 0; i + 1 < k; i += 2) {
            float l = xs[i] + off_x, r = xs[i + 1] + off_x;
            int li = (int)floorf(l), ri = (int)floorf(r);
            if (li == ri) {
                if (r - l > 0)
                    plot(li, y, c, (unsigned)((r - l) * 256));
                continue;
            }
            plot(li, y, c, (unsigned)((li + 1 - l) * 256));
            span(li + 1, ri, y, c);
            if (r - ri > 0)
                plot(ri, y, c, (unsigned)((r - ri) * 256));
        }
    }
}

void gfx_tri(float x0, float y0, float x1, float y1, float x2, float y2, gcol c)
{
    float p[6] = {x0, y0, x1, y1, x2, y2};
    gfx_poly(p, 3, c);
}

void gfx_line(float x0, float y0, float x1, float y1, float thick, gcol c)
{
    float hw = thick * 0.5f;
    float dx = x1 - x0, dy = y1 - y0;
    float len2 = dx * dx + dy * dy;
    float in2 = hw > 0.5f ? (hw - 0.5f) * (hw - 0.5f) : 0, out2 = (hw + 0.5f) * (hw + 0.5f);
    int ya, yb;
    x0 += off_x;
    x1 += off_x;
    y0 += off_y;
    y1 += off_y;
    ya = (int)floorf(fminf(y0, y1) - hw - 1);
    yb = (int)ceilf(fmaxf(y0, y1) + hw + 1);
    if (ya < clip_y0)
        ya = clip_y0;
    if (yb > clip_y1)
        yb = clip_y1;
    for (int y = ya; y < yb; y++) {
        float py = y + 0.5f;
        float xa = fminf(x0, x1) - hw - 1, xb = fmaxf(x0, x1) + hw + 1;
        /* Narrow the row to the strip around the line when it is steep enough. */
        if (fabsf(dy) > 0.001f) {
            float len = sqrtf(len2);
            float t = (py - y0) / dy;
            float xc = x0 + dx * t;
            float half = (hw + 1.5f) * len / fabsf(dy);
            if (xc - half > xa)
                xa = xc - half;
            if (xc + half < xb)
                xb = xc + half;
        }
        for (int x = (int)floorf(xa); x < (int)ceilf(xb); x++) {
            float px = x + 0.5f;
            float t = len2 > 0 ? ((px - x0) * dx + (py - y0) * dy) / len2 : 0;
            float qx, qy, d, cov;
            t = t < 0 ? 0 : t > 1 ? 1 : t;
            qx = x0 + dx * t - px;
            qy = y0 + dy * t - py;
            d = qx * qx + qy * qy;
            if (d <= in2) {
                plot(x, y, c, 256);
                continue;
            }
            if (d >= out2)
                continue;
            cov = hw - sqrtf(d) + 0.5f;
            if (cov > 0)
                plot(x, y, c, cov >= 1 ? 256 : (unsigned)(cov * 256));
        }
    }
}

void gfx_glow(float cx, float cy, float r, gcol c)
{
    int y0, y1, x0, x1;
    float inv;
    unsigned a = COL_A(c);
    if (r <= 0.5f)
        return;
    cx += off_x;
    cy += off_y;
    inv = 1.f / (r * r);
    y0 = (int)floorf(cy - r);
    y1 = (int)ceilf(cy + r);
    x0 = (int)floorf(cx - r);
    x1 = (int)ceilf(cx + r);
    if (y0 < clip_y0)
        y0 = clip_y0;
    if (y1 > clip_y1)
        y1 = clip_y1;
    if (x0 < clip_x0)
        x0 = clip_x0;
    if (x1 > clip_x1)
        x1 = clip_x1;
    for (int y = y0; y < y1; y++) {
        float dy = y + 0.5f - cy;
        Uint32 *p = tgt->px + y * tgt->w;
        float hw2 = r * r - dy * dy, hw;
        int xa, xb;
        if (hw2 <= 0)
            continue;
        hw = sqrtf(hw2);
        xa = (int)(cx - hw);
        xb = (int)(cx + hw) + 1;
        if (xa < x0)
            xa = x0;
        if (xb > x1)
            xb = x1;
        for (int x = xa; x < xb; x++) {
            float dx = x + 0.5f - cx;
            float k = 1.f - (dx * dx + dy * dy) * inv;
            if (k > 0) {
                unsigned w = (unsigned)(k * k * a);
                if (w)
                    p[x] = add(p[x], c, w);
            }
        }
    }
}

void gfx_circle_o(float cx, float cy, float r, gcol fill, gcol ink, float t)
{
    gfx_circle(cx, cy, r + t, ink);
    gfx_circle(cx, cy, r, fill);
}

void gfx_ellipse_o(float cx, float cy, float rx, float ry, gcol fill, gcol ink, float t)
{
    gfx_ellipse(cx, cy, rx + t, ry + t, ink);
    gfx_ellipse(cx, cy, rx, ry, fill);
}

void gfx_rrect_o(float x, float y, float w, float h, float r, gcol fill, gcol ink, float t)
{
    gfx_rrect(x - t, y - t, w + 2 * t, h + 2 * t, r + t, ink);
    gfx_rrect(x, y, w, h, r, fill);
}

void gfx_star(float cx, float cy, float r, float rot, gcol c)
{
    float p[20];
    for (int i = 0; i < 10; i++) {
        float a = rot - 1.5707963f + i * 0.6283185f;
        float rr = (i & 1) ? r * 0.45f : r;
        p[i * 2] = cx + cosf(a) * rr;
        p[i * 2 + 1] = cy + sinf(a) * rr;
    }
    gfx_poly(p, 10, c);
}

void gfx_heart(float cx, float cy, float s, gcol c)
{
    gfx_circle(cx - s * 0.5f, cy - s * 0.2f, s * 0.55f, c);
    gfx_circle(cx + s * 0.5f, cy - s * 0.2f, s * 0.55f, c);
    gfx_tri(cx - s * 1.03f, cy, cx + s * 1.03f, cy, cx, cy + s * 1.05f, c);
    gfx_rect((int)(cx - s * 0.5f), (int)(cy - s * 0.2f), (int)(s), (int)(s * 0.4f), c);
}

void gfx_dim(float k)
{
    int n = tgt->w * tgt->h;
    unsigned m = (unsigned)(clampf(k, 0, 1) * 256);
    for (int i = 0; i < n; i++) {
        Uint32 p = tgt->px[i];
        Uint32 rb = ((p & 0xff00ff) * m >> 8) & 0xff00ff;
        Uint32 g = ((p & 0x00ff00) * m >> 8) & 0x00ff00;
        tgt->px[i] = 0xff000000u | rb | g;
    }
}

/* ------------------------------------------------------------------ toon */

int toon_pass = 1;
float toon_t = 2.f;
gcol toon_ink = 0xff3a2a44u;

void toon_circle(float cx, float cy, float r, gcol c)
{
    if (toon_pass == 0)
        gfx_circle(cx, cy, r + toon_t, toon_ink);
    else
        gfx_circle(cx, cy, r, c);
}

void toon_ellipse(float cx, float cy, float rx, float ry, gcol c)
{
    if (toon_pass == 0)
        gfx_ellipse(cx, cy, rx + toon_t, ry + toon_t, toon_ink);
    else
        gfx_ellipse(cx, cy, rx, ry, c);
}

void toon_rrect(float x, float y, float w, float h, float r, gcol c)
{
    if (toon_pass == 0)
        gfx_rrect(x - toon_t, y - toon_t, w + 2 * toon_t, h + 2 * toon_t, r + toon_t, toon_ink);
    else
        gfx_rrect(x, y, w, h, r, c);
}

void toon_line(float x0, float y0, float x1, float y1, float thick, gcol c)
{
    if (toon_pass == 0)
        gfx_line(x0, y0, x1, y1, thick + 2 * toon_t, toon_ink);
    else
        gfx_line(x0, y0, x1, y1, thick, c);
}

void toon_poly(const float *xy, int n, gcol c)
{
    if (toon_pass == 0) {
        gfx_poly(xy, n, toon_ink);
        for (int i = 0, j = n - 1; i < n; j = i++)
            gfx_line(xy[j * 2], xy[j * 2 + 1], xy[i * 2], xy[i * 2 + 1], 2 * toon_t, toon_ink);
    } else
        gfx_poly(xy, n, c);
}

void toon_tri(float x0, float y0, float x1, float y1, float x2, float y2, gcol c)
{
    float p[6] = {x0, y0, x1, y1, x2, y2};
    toon_poly(p, 3, c);
}

/* ------------------------------------------------------------------ sprites */

gsprite *gfx_sprite_make(const char *const *rows, int nrows, const char *keys, const gcol *pal)
{
    gsprite *s;
    int w = 0;
    for (int i = 0; i < nrows; i++)
        if ((int)strlen(rows[i]) > w)
            w = (int)strlen(rows[i]);
    s = calloc(1, sizeof *s);
    if (!s)
        return NULL;
    s->w = w;
    s->h = nrows;
    s->px = calloc((size_t)w * nrows, sizeof(Uint32));
    if (!s->px) {
        free(s);
        return NULL;
    }
    for (int y = 0; y < nrows; y++)
        for (int x = 0; rows[y][x]; x++) {
            const char *k = strchr(keys, rows[y][x]);
            if (rows[y][x] != '.' && rows[y][x] != ' ' && k)
                s->px[y * w + x] = pal[k - keys];
        }
    return s;
}

void gfx_sprite(const gsprite *s, int x, int y, int scale, int flip, gcol tint)
{
    if (!s)
        return;
    x += off_x;
    y += off_y;
    if (scale < 1)
        scale = 1;
    for (int sy = 0; sy < s->h; sy++)
        for (int sx = 0; sx < s->w; sx++) {
            Uint32 c = s->px[sy * s->w + (flip ? s->w - 1 - sx : sx)];
            if (!COL_A(c))
                continue;
            if (tint)
                c = col_mix(c | 0xff000000u, tint | 0xff000000u, COL_A(tint) / 255.f) | (c & 0xff000000u);
            for (int yy = 0; yy < scale; yy++) {
                int py = y + sy * scale + yy;
                if (py < clip_y0 || py >= clip_y1)
                    continue;
                for (int xx = 0; xx < scale; xx++) {
                    int px = x + sx * scale + xx;
                    if (px < clip_x0 || px >= clip_x1)
                        continue;
                    tgt->px[py * tgt->w + px] = blend(tgt->px[py * tgt->w + px], c, COL_A(c));
                }
            }
        }
}

/* ------------------------------------------------------------------ text */

static signed char glyph_l[128], glyph_r[128];
static int glyphs_ready;

static void glyph_metrics(void)
{
    for (int ch = 0; ch < 128; ch++) {
        int l = 8, r = -1;
        for (int y = 0; y < 8; y++)
            for (int x = 0; x < 8; x++)
                if ((font8x8_basic[ch][y] >> x) & 1) {
                    if (x < l)
                        l = x;
                    if (x > r)
                        r = x;
                }
        if (r < 0) {
            l = 0;
            r = 2; /* space: three columns */
        }
        glyph_l[ch] = (signed char)l;
        glyph_r[ch] = (signed char)r;
    }
    glyphs_ready = 1;
}

static int str_w(const char *s, int scale)
{
    int w = 0;
    if (!glyphs_ready)
        glyph_metrics();
    for (; *s; s++) {
        int ch = *s & 0x7f;
        w += (glyph_r[ch] - glyph_l[ch] + 2) * scale;
    }
    return w > 0 ? w - scale : 0;
}

static void draw_str(int x, int y, int scale, gcol c, const char *s)
{
    if (!glyphs_ready)
        glyph_metrics();
    x += off_x;
    y += off_y;
    for (; *s; s++) {
        int ch = *s & 0x7f;
        int l = glyph_l[ch], r = glyph_r[ch];
        for (int gy = 0; gy < 8; gy++) {
            unsigned bits = font8x8_basic[ch][gy];
            int gx = l;
            while (gx <= r) {
                int run;
                if (!((bits >> gx) & 1)) {
                    gx++;
                    continue;
                }
                run = gx;
                while (run <= r && ((bits >> run) & 1))
                    run++;
                for (int yy = 0; yy < scale; yy++)
                    span(x + (gx - l) * scale, x + (run - l) * scale, y + gy * scale + yy, c);
                gx = run;
            }
        }
        x += (r - l + 2) * scale;
    }
}

#define FMT(buf)                                  \
    char buf[256];                                \
    do {                                          \
        va_list ap;                               \
        va_start(ap, fmt);                        \
        vsnprintf(buf, sizeof buf, fmt, ap);      \
        va_end(ap);                               \
    } while (0)

int gfx_text_w(int scale, const char *fmt, ...)
{
    FMT(buf);
    return str_w(buf, scale);
}

void gfx_text(int x, int y, int scale, gcol c, const char *fmt, ...)
{
    FMT(buf);
    draw_str(x, y, scale, c, buf);
}

static void outlined(int x, int y, int scale, gcol c, gcol ink, const char *s)
{
    static const int d[8][2] = {{-1, -1}, {0, -1}, {1, -1}, {-1, 0}, {1, 0}, {-1, 1}, {0, 1}, {1, 1}};
    int t = scale >= 3 ? 2 : 1;
    for (int k = 0; k < 8; k++)
        draw_str(x + d[k][0] * t, y + d[k][1] * t, scale, ink, s);
    if (scale >= 2)
        draw_str(x, y + t + 1, scale, ink, s);
    draw_str(x, y, scale, c, s);
}

void gfx_text_o(int x, int y, int scale, gcol c, gcol ink, const char *fmt, ...)
{
    FMT(buf);
    outlined(x, y, scale, c, ink, buf);
}

void gfx_text_c(int cx, int y, int scale, gcol c, gcol ink, const char *fmt, ...)
{
    FMT(buf);
    if (COL_A(ink))
        outlined(cx - str_w(buf, scale) / 2, y, scale, c, ink, buf);
    else
        draw_str(cx - str_w(buf, scale) / 2, y, scale, c, buf);
}

void gfx_text_s(int x, int y, int scale, gcol c, gcol shadow, const char *fmt, ...)
{
    FMT(buf);
    draw_str(x + scale, y + scale, scale, shadow, buf);
    draw_str(x, y, scale, c, buf);
}

/* ------------------------------------------------------------------ particles */

#define PART_MAX 512
static gpart parts[PART_MAX];
static int nparts;

gpart *part_spawn(float x, float y, float vx, float vy, int life, float size, gcol c, int kind)
{
    gpart *p;
    if (nparts >= PART_MAX) {
        /* Recycle the oldest-looking one: the first. */
        memmove(parts, parts + 1, sizeof(gpart) * (PART_MAX - 1));
        nparts = PART_MAX - 1;
    }
    p = &parts[nparts++];
    memset(p, 0, sizeof *p);
    p->x = x;
    p->y = y;
    p->vx = vx;
    p->vy = vy;
    p->life = p->max = life > 0 ? life : 1;
    p->size = size;
    p->c = c;
    p->kind = kind;
    p->drag = 0.98f;
    return p;
}

void part_burst(float x, float y, int n, float speed, int life, float size, gcol c, int kind)
{
    for (int i = 0; i < n; i++) {
        float a = rng_f() * 6.2831853f;
        float s = speed * (0.35f + 0.65f * rng_f());
        gpart *p = part_spawn(x, y, cosf(a) * s, sinf(a) * s, life / 2 + rng_int(0, life / 2), size, c, kind);
        p->rot = rng_f() * 6.28f;
        p->spin = rng_range(-0.2f, 0.2f);
    }
}

void part_text(float x, float y, gcol c, const char *s)
{
    gpart *p = part_spawn(x, y, 0, -0.7f, 50, 1, c, PART_TEXT);
    p->drag = 0.97f;
    snprintf(p->text, sizeof p->text, "%s", s);
}

void part_update(void)
{
    int j = 0;
    for (int i = 0; i < nparts; i++) {
        gpart *p = &parts[i];
        if (--p->life <= 0)
            continue;
        p->vy += p->grav;
        p->vx *= p->drag;
        p->vy *= p->drag;
        p->x += p->vx;
        p->y += p->vy;
        p->size += p->grow;
        p->rot += p->spin;
        if (j != i)
            parts[j] = *p;
        j++;
    }
    nparts = j;
}

void part_draw(void)
{
    for (int i = 0; i < nparts; i++) {
        gpart *p = &parts[i];
        float t = (float)p->life / p->max;
        int a = (int)(COL_A(p->c) * (t < 0.3f ? t / 0.3f : 1.f));
        gcol c = col_alpha(p->c, a);
        float s = p->size;
        switch (p->kind) {
        case PART_GLOW:
            gfx_glow(p->x, p->y, s * (0.6f + 0.4f * t), c);
            break;
        case PART_STAR:
            gfx_star(p->x, p->y, s * (0.5f + 0.5f * t), p->rot, c);
            break;
        case PART_HEART:
            gfx_heart(p->x, p->y, s, c);
            break;
        case PART_SQUARE:
            gfx_rect((int)(p->x - s / 2), (int)(p->y - s / 2), (int)s < 1 ? 1 : (int)s, (int)s < 1 ? 1 : (int)s, c);
            break;
        case PART_RING:
            gfx_ring(p->x, p->y, s, 1.5f, c);
            break;
        case PART_TEXT: {
            int sc = s >= 2 ? 2 : 1;
            gfx_text_c((int)p->x, (int)p->y, sc, c, col_alpha(RGB(20, 16, 30), a), "%s", p->text);
            break;
        }
        default:
            gfx_circle(p->x, p->y, s * (0.4f + 0.6f * t), c);
        }
    }
}

void part_clear(void) { nparts = 0; }
int part_count(void) { return nparts; }

/* ------------------------------------------------------------------ rng, math */

static Uint32 rng_state = 0x9e3779b9u;

void rng_seed(Uint32 s) { rng_state = s ? s : 0x9e3779b9u; }

void rng_seed_auto(void)
{
    const char *s = getenv("CAB_SEED");
    if (s && s[0])
        rng_seed((Uint32)strtoul(s, NULL, 10));
    else if (cab_scripted() || getenv("CAB_AUTOPLAY"))
        rng_seed(1);
    else
        rng_seed((Uint32)time(NULL) ^ (SDL_GetTicks() * 2654435761u));
}

Uint32 rng_u32(void)
{
    Uint32 x = rng_state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    return rng_state = x;
}

float rng_f(void) { return (rng_u32() >> 8) * (1.f / 16777216.f); }
float rng_range(float lo, float hi) { return lo + (hi - lo) * rng_f(); }
int rng_int(int lo, int hi) { return hi <= lo ? lo : lo + (int)(rng_u32() % (Uint32)(hi - lo + 1)); }

float clampf(float v, float lo, float hi) { return v < lo ? lo : v > hi ? hi : v; }
float lerpf(float a, float b, float t) { return a + (b - a) * t; }
float ease_out_cubic(float t)
{
    t = clampf(t, 0, 1) - 1;
    return t * t * t + 1;
}
float ease_in_out(float t)
{
    t = clampf(t, 0, 1);
    return t * t * (3 - 2 * t);
}
float ease_out_back(float t)
{
    const float c1 = 1.70158f, c3 = c1 + 1;
    t = clampf(t, 0, 1) - 1;
    return 1 + c3 * t * t * t + c1 * t * t;
}
float ease_out_elastic(float t)
{
    t = clampf(t, 0, 1);
    if (t == 0 || t == 1)
        return t;
    return powf(2, -10 * t) * sinf((t * 10 - 0.75f) * 2.0943951f) + 1;
}
float approach(float v, float target, float rate) { return v + (target - v) * rate; }

/* ------------------------------------------------------------------ present */

static void quit_meter(void)
{
    float q = cab_quit_progress();
    int w = gfx_screen.w, h = gfx_screen.h;
    int bw, bh, bx, by;
    gsurf *keep = tgt;
    if (q <= 0)
        return;
    gfx_target(NULL);
    bw = w * 3 / 4;
    bh = w >= 300 ? 44 : 34;
    bx = (w - bw) / 2;
    by = h / 2 - bh / 2;
    gfx_rrect(bx - 3, by - 3, bw + 6, bh + 6, 10, RGBA(8, 6, 16, 220));
    gfx_rrect(bx, by, bw, bh, 8, RGBA(40, 34, 64, 240));
    gfx_rrect(bx + 4, by + bh - 14, (bw - 8) * q, 10, 4, RGB(255, 200, 90));
    gfx_text_c(w / 2, by + 6, w >= 300 ? 2 : 1, RGB(255, 246, 234), RGBA(0, 0, 0, 0), "leaving...");
    gfx_target(keep);
}

void gfx_present(void)
{
    SDL_Rect dst = {0, 0, gfx_screen.w, gfx_screen.h};
    gsurf *keep = tgt;
    gfx_target(NULL);
    if (flash_left > 0) {
        gfx_rect(0, 0, gfx_screen.w, gfx_screen.h,
                 col_alpha(flash_col, COL_A(flash_col) * flash_left / (flash_len ? flash_len : 1)));
        flash_left--;
    }
    quit_meter();
    /* The rotation check in check.sh looks for a red band at the top and a blue one at the bottom. */
    if (getenv("CAB_TESTCARD")) {
        gfx_rect(0, 0, gfx_screen.w, 8, RGB(220, 40, 40));
        gfx_rect(0, gfx_screen.h - 8, gfx_screen.w, 8, RGB(40, 80, 220));
    }
    SDL_UpdateTexture(stream, NULL, gfx_screen.px, gfx_screen.w * 4);
    if (shake_amt > 0.3f) {
        dst.x = (int)rng_range(-shake_amt, shake_amt);
        dst.y = (int)rng_range(-shake_amt, shake_amt);
        shake_amt *= 0.85f;
    } else
        shake_amt = 0;
    SDL_SetRenderDrawColor(cab_renderer, 0, 0, 0, 255);
    SDL_RenderClear(cab_renderer);
    SDL_RenderCopy(cab_renderer, stream, NULL, &dst);
    cab_present();
    gfx_target(keep);
    gfx_frame++;
    /* Without vsync (the dummy driver, some PCs) wait out a 60 Hz frame. A script runs flat out. */
    if (!cab_scripted()) {
        SDL_RendererInfo ri;
        SDL_GetRendererInfo(cab_renderer, &ri);
        if (!(ri.flags & SDL_RENDERER_PRESENTVSYNC) && !getenv("CAB_PACE")) {
            Uint32 now = SDL_GetTicks();
            if (!pace_at)
                pace_at = now;
            pace_at += 16;
            if ((Sint32)(pace_at - now) > 0)
                SDL_Delay(pace_at - now);
            else
                pace_at = now;
        }
    }
}
