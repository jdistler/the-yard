/* Light, included into gfx.c. A light map over part of the picture: start it at an ambient
 * level, add round lights, then apply it, which darkens everything by how little light
 * reached it and leans the shadows toward a tint. Lamp's meadow at night is this. */
static float *lm;
static int lm_x, lm_y, lm_w, lm_h, lm_cap;

void gfx_light_begin(int x, int y, int w, int h, float ambient)
{
    if (x < 0) {
        w += x;
        x = 0;
    }
    if (y < 0) {
        h += y;
        y = 0;
    }
    if (x + w > tgt->w)
        w = tgt->w - x;
    if (y + h > tgt->h)
        h = tgt->h - y;
    if (w <= 0 || h <= 0) {
        lm_w = lm_h = 0;
        return;
    }
    if (w * h > lm_cap) {
        free(lm);
        lm = malloc(sizeof(float) * (size_t)w * h);
        lm_cap = lm ? w * h : 0;
        if (!lm) {
            lm_w = lm_h = 0;
            return;
        }
    }
    lm_x = x;
    lm_y = y;
    lm_w = w;
    lm_h = h;
    for (int i = 0; i < w * h; i++)
        lm[i] = ambient;
}

/* A soft round light: full k at the middle, falling off to nothing at r. */
void gfx_light_add(float cx, float cy, float r, float k)
{
    int x0, x1, y0, y1;
    float inv;
    if (!lm_w || r <= 0)
        return;
    cx += off_x - lm_x;
    cy += off_y - lm_y;
    x0 = (int)(cx - r);
    x1 = (int)(cx + r + 1);
    y0 = (int)(cy - r);
    y1 = (int)(cy + r + 1);
    inv = 1.f / (r * r);
    if (x0 < 0)
        x0 = 0;
    if (x1 > lm_w)
        x1 = lm_w;
    if (y0 < 0)
        y0 = 0;
    if (y1 > lm_h)
        y1 = lm_h;
    for (int y = y0; y < y1; y++) {
        float dy = y + 0.5f - cy;
        float *row = lm + y * lm_w;
        for (int x = x0; x < x1; x++) {
            float dx = x + 0.5f - cx;
            float v = 1.f - (dx * dx + dy * dy) * inv;
            if (v > 0)
                row[x] += v * v * k;
        }
    }
}

void gfx_light_fill(float k)
{
    for (int i = 0; i < lm_w * lm_h; i++)
        lm[i] += k;
}

/* Darken by the light. Warm light keeps reds a little longer than blues; the dark leans
 * toward tint (Lamp uses a touch of blue, 0x00000e). Tables keep it to integer work per
 * pixel, which matters on the cabinet's A7. */
void gfx_light_apply(gcol tint)
{
    static int ready;
    static Uint16 fr[257], fg[257], fb[257];
    Uint8 tr[257], tg[257], tb[257];
    if (!ready) {
        for (int i = 0; i <= 256; i++) {
            float k = i / 256.f;
            fr[i] = (Uint16)(k * (0.75f + 0.25f * k) * 256);
            fg[i] = (Uint16)(k * (0.85f + 0.15f * k) * 256);
            fb[i] = (Uint16)(k * 256);
        }
        ready = 1;
    }
    for (int i = 0; i <= 256; i++) {
        float d = 1 - i / 256.f;
        tr[i] = (Uint8)(COL_R(tint) * d);
        tg[i] = (Uint8)(COL_G(tint) * d);
        tb[i] = (Uint8)(COL_B(tint) * d);
    }
    for (int y = 0; y < lm_h; y++) {
        Uint32 *p = tgt->px + (y + lm_y) * tgt->w + lm_x;
        const float *l = lm + y * lm_w;
        for (int x = 0; x < lm_w; x++) {
            int ki = (int)(l[x] * 256.f);
            Uint32 c = p[x];
            unsigned r, g, b;
            if (ki >= 256)
                continue;
            if (ki < 0)
                ki = 0;
            r = ((((c >> 16) & 255) * fr[ki]) >> 8) + tr[ki];
            g = ((((c >> 8) & 255) * fg[ki]) >> 8) + tg[ki];
            b = (((c & 255) * fb[ki]) >> 8) + tb[ki];
            p[x] = 0xff000000u | ((r > 255 ? 255 : r) << 16) | ((g > 255 ? 255 : g) << 8) | (b > 255 ? 255 : b);
        }
    }
}

/* Everything outside the circle in c: the iris wipe between scenes. */
void gfx_iris(float cx, float cy, float r, gcol c)
{
    int h = tgt->h, w = tgt->w;
    if (r <= 0) {
        gfx_rect(-off_x, -off_y, w, h, c);
        return;
    }
    for (int y = 0; y < h; y++) {
        float dy = y + 0.5f - cy;
        if (dy * dy >= r * r)
            gfx_rect(-off_x, y - off_y, w, 1, c);
        else {
            float dx = sqrtf(r * r - dy * dy);
            int a = (int)(cx - dx), b = (int)(cx + dx);
            gfx_rect(-off_x, y - off_y, a, 1, c);
            gfx_rect(b - off_x, y - off_y, w - b, 1, c);
        }
    }
}
