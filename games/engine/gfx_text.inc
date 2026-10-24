/* TrueType text, included into gfx.c (it shares the clip, offset, and blend there).
 *
 * Fonts are rasterized on first use with stb_truetype, one glyph at a time, at the exact
 * pixel size asked for, and kept: a fill coverage map and an outline coverage map (the fill
 * grown by a disc). Drawing is then a blend of two small alpha maps per glyph. Printable
 * ASCII only. Font 0 is the built-in round face (Fredoka SemiBold, SIL OFL 1.1).
 */
#define STB_TRUETYPE_IMPLEMENTATION
#define STBTT_STATIC
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-function"
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#pragma GCC diagnostic ignored "-Wsign-compare"
#include "vendor/stb_truetype.h"
#pragma GCC diagnostic pop
#include "fonts/round_ttf.h"

#define FONT_MAX 8
#define FACE_MAX 40

typedef struct {
    int w, h, xoff, yoff;      /* fill box relative to the pen at the baseline */
    int ow, oh;                /* outline box: the fill box grown by r on every side */
    float adv;
    Uint8 *fill, *outl;
} gl_glyph;

typedef struct {
    int font, size, r, ascent, descent, line;
    float scale;
    gl_glyph g[96];
    Uint8 done[96];
} gl_face;

static stbtt_fontinfo fonts_info[FONT_MAX];
static unsigned char *fonts_data[FONT_MAX];
static int nfonts;
static gl_face *faces[FACE_MAX];
static int nfaces;

int gfx_font_add(const unsigned char *ttf, int len)
{
    unsigned char *copy;
    if (nfonts >= FONT_MAX || len < 12)
        return -1;
    copy = malloc((size_t)len);
    if (!copy)
        return -1;
    memcpy(copy, ttf, (size_t)len);
    if (!stbtt_InitFont(&fonts_info[nfonts], copy, stbtt_GetFontOffsetForIndex(copy, 0))) {
        free(copy);
        return -1;
    }
    fonts_data[nfonts] = copy;
    return nfonts++;
}

static void fonts_ready(void)
{
    if (!nfonts)
        gfx_font_add(round_ttf, (int)sizeof round_ttf);
}

static gl_face *face_get(int font, int size)
{
    gl_face *f;
    int a, d, l;
    fonts_ready();
    if (font < 0 || font >= nfonts)
        font = 0;
    if (size < 6)
        size = 6;
    if (size > 96)
        size = 96;
    for (int i = 0; i < nfaces; i++)
        if (faces[i]->font == font && faces[i]->size == size)
            return faces[i];
    f = calloc(1, sizeof *f);
    if (!f)
        return NULL;
    f->font = font;
    f->size = size;
    f->scale = stbtt_ScaleForPixelHeight(&fonts_info[font], (float)size);
    stbtt_GetFontVMetrics(&fonts_info[font], &a, &d, &l);
    f->ascent = (int)ceilf(a * f->scale);
    f->descent = (int)floorf(d * f->scale);
    f->line = (int)ceilf((a - d + l) * f->scale);
    f->r = size >= 14 ? (size + 6) / 12 : 1;
    if (nfaces < FACE_MAX)
        faces[nfaces++] = f;
    else {
        /* Too many sizes in use: drop the oldest. */
        gl_face *old = faces[0];
        for (int k = 0; k < 96; k++)
            if (old->done[k]) {
                free(old->g[k].fill);
                free(old->g[k].outl);
            }
        free(old);
        memmove(faces, faces + 1, sizeof faces[0] * (FACE_MAX - 1));
        faces[FACE_MAX - 1] = f;
    }
    return f;
}

static gl_glyph *glyph_get(gl_face *f, int ch)
{
    gl_glyph *g;
    int adv, lsb, x0, y0, x1, y1, r;
    if (ch < 32 || ch > 126)
        ch = '?';
    g = &f->g[ch - 32];
    if (f->done[ch - 32])
        return g;
    f->done[ch - 32] = 1;
    stbtt_GetCodepointHMetrics(&fonts_info[f->font], ch, &adv, &lsb);
    g->adv = adv * f->scale;
    stbtt_GetCodepointBitmapBox(&fonts_info[f->font], ch, f->scale, f->scale, &x0, &y0, &x1, &y1);
    g->w = x1 - x0;
    g->h = y1 - y0;
    g->xoff = x0;
    g->yoff = y0;
    if (g->w <= 0 || g->h <= 0) {
        g->w = g->h = 0;
        return g;
    }
    g->fill = calloc((size_t)g->w * g->h, 1);
    if (!g->fill) {
        g->w = g->h = 0;
        return g;
    }
    stbtt_MakeCodepointBitmap(&fonts_info[f->font], g->fill, g->w, g->h, g->w, f->scale, f->scale, ch);
    /* The outline: the fill grown by a disc of radius r. */
    r = f->r;
    g->ow = g->w + 2 * r;
    g->oh = g->h + 2 * r;
    g->outl = calloc((size_t)g->ow * g->oh, 1);
    if (g->outl) {
        for (int y = 0; y < g->oh; y++)
            for (int x = 0; x < g->ow; x++) {
                int best = 0;
                for (int dy = -r; dy <= r && best < 255; dy++)
                    for (int dx = -r; dx <= r; dx++) {
                        int sx = x - r + dx, sy = y - r + dy, v;
                        if (dx * dx + dy * dy > r * r + r || sx < 0 || sy < 0 || sx >= g->w || sy >= g->h)
                            continue;
                        v = g->fill[sy * g->w + sx];
                        if (v > best)
                            best = v;
                    }
                g->outl[y * g->ow + x] = (Uint8)best;
            }
    }
    return g;
}

static void coverage_map(const Uint8 *m, int w, int h, int x, int y, gcol c)
{
    unsigned a = COL_A(c);
    for (int yy = 0; yy < h; yy++) {
        int py = y + yy;
        Uint32 *row;
        if (py < clip_y0 || py >= clip_y1)
            continue;
        row = tgt->px + py * tgt->w;
        for (int xx = 0; xx < w; xx++) {
            int px = x + xx;
            unsigned cov = m[yy * w + xx];
            if (!cov || px < clip_x0 || px >= clip_x1)
                continue;
            cov = (cov * a + 127) / 255;
            if (cov)
                row[px] = blend(row[px], c, cov);
        }
    }
}

float gfx_ttf_width(int font, int size, const char *s)
{
    gl_face *f = face_get(font, size);
    float w = 0;
    if (!f)
        return 0;
    for (const unsigned char *p = (const unsigned char *)s; *p; p++) {
        w += glyph_get(f, *p)->adv;
        if (p[1])
            w += stbtt_GetCodepointKernAdvance(&fonts_info[f->font], *p, p[1]) * f->scale;
    }
    return w;
}

int gfx_ttf_line(int font, int size)
{
    gl_face *f = face_get(font, size);
    return f ? f->line : size;
}

/* Draw at (x, y): y is the top of the line. align: 0 left, 1 center, 2 right.
 * An outline color with alpha 0 draws no outline. Returns the width. */
float gfx_ttf(int font, int size, float x, float y, gcol c, gcol outline, int align, const char *s)
{
    gl_face *f = face_get(font, size);
    float w, pen;
    int base;
    if (!f)
        return 0;
    w = gfx_ttf_width(font, size, s);
    pen = x - (align == 1 ? w / 2 : align == 2 ? w : 0) + off_x;
    base = (int)floorf(y + off_y) + f->ascent;
    for (int pass = COL_A(outline) ? 0 : 1; pass < 2; pass++) {
        float p = pen;
        for (const unsigned char *q = (const unsigned char *)s; *q; q++) {
            gl_glyph *g = glyph_get(f, *q);
            int gx = (int)floorf(p + 0.5f) + g->xoff, gy = base + g->yoff;
            if (g->w) {
                if (pass == 0 && g->outl)
                    coverage_map(g->outl, g->ow, g->oh, gx - f->r, gy - f->r + (size >= 18 ? 1 : 0), outline);
                else if (pass == 1)
                    coverage_map(g->fill, g->w, g->h, gx, gy, c);
            }
            p += g->adv;
            if (q[1])
                p += stbtt_GetCodepointKernAdvance(&fonts_info[f->font], *q, q[1]) * f->scale;
        }
    }
    return w;
}
