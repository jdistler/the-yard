/* Lamp: carry a lantern through a dark meadow and wake the fallen stars.
 * Walk-up band (CONTROLS.md), the "stick is the verb" shape: walking into a star wakes it.
 *
 * Each night some stars have fallen into the grass. Wake them all and they climb back into
 * the sky and draw a constellation. The lantern burns oil. Fireflies and woken stars fill
 * it. LOW (or TL, TR) lifts the lamp: a wide flare that costs oil and scares the moths.
 * Run dry and the light shrinks to an ember for a moment, then relights. Nothing is lost.
 *
 * Upright 240x320. lamp.sav is "best N": the most nights woken in one walk.
 * LAMP_SELFTEST=1 plays itself through the first night, saves, and checks the file.
 */
#include "gfx.h"
#include "sfx.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

#define W 240
#define H 320
#define SKY_H 90
#define FY0 92
#define FY1 306
#define FH (FY1 - FY0)
#define MAXS 10
#define NFLY 4
#define NMOTH 4

static const gcol INK = HEX(0x120e26), CREAM = HEX(0xfff6ea), GOLD = HEX(0xffd257);

typedef struct {
    const char *name;
    int n;
    float pt[MAXS][2]; /* 0..1 inside the sky band */
    int melody[MAXS];
} constellation;

static const constellation skies[] = {
    {"the Kite", 4, {{.5f, .1f}, {.75f, .45f}, {.5f, .85f}, {.25f, .45f}}, {72, 76, 79, 84}},
    {"the Teacup", 5, {{.2f, .3f}, {.8f, .3f}, {.72f, .8f}, {.28f, .8f}, {.92f, .5f}}, {67, 72, 76, 79, 84}},
    {"the Cat", 6, {{.3f, .15f}, {.38f, .45f}, {.62f, .45f}, {.7f, .15f}, {.66f, .85f}, {.34f, .85f}}, {72, 74, 76, 79, 81, 84}},
    {"the Key", 6, {{.15f, .5f}, {.3f, .25f}, {.3f, .75f}, {.6f, .5f}, {.85f, .5f}, {.85f, .8f}}, {60, 64, 67, 72, 76, 79}},
    {"the Fish", 7, {{.15f, .5f}, {.35f, .2f}, {.6f, .25f}, {.72f, .5f}, {.6f, .75f}, {.35f, .8f}, {.9f, .5f}}, {69, 72, 74, 76, 79, 81, 84}},
    {"the Crown", 7, {{.15f, .8f}, {.15f, .25f}, {.33f, .55f}, {.5f, .15f}, {.67f, .55f}, {.85f, .25f}, {.85f, .8f}}, {72, 76, 79, 84, 79, 76, 72}},
    {"the Whale", 8, {{.1f, .5f}, {.25f, .25f}, {.55f, .2f}, {.8f, .35f}, {.85f, .6f}, {.6f, .8f}, {.3f, .75f}, {.95f, .2f}}, {60, 62, 64, 67, 69, 72, 74, 76}},
    {"the Teapot", 9, {{.3f, .2f}, {.7f, .2f}, {.8f, .5f}, {.7f, .85f}, {.3f, .85f}, {.2f, .5f}, {.05f, .35f}, {.95f, .3f}, {.5f, .05f}}, {67, 69, 72, 74, 76, 79, 81, 84, 86}},
    {"the Dragon", 10, {{.05f, .7f}, {.18f, .45f}, {.32f, .6f}, {.45f, .35f}, {.58f, .55f}, {.7f, .3f}, {.82f, .45f}, {.92f, .2f}, {.95f, .55f}, {.82f, .8f}}, {60, 64, 67, 69, 72, 76, 79, 81, 84, 88}},
};
#define NSKIES (int)(sizeof skies / sizeof skies[0])

typedef struct {
    float x, y;
    int awake;   /* 0 asleep in the grass, 1 climbing, 2 in the sky */
    float t;     /* climb progress */
} fallen;

typedef struct {
    float x, y, vx, vy, t;
    int on, cool;
} mover;

enum { S_TITLE, S_NIGHT, S_DONE };

static fallen st[MAXS];
static mover fly[NFLY], moth[NMOTH];
static int state, night, nstars, woke, best, frame, idle_t, demo, self_test, fast, saved_best;
static int flare_t, flare_cd, done_t, ember_t, ouch_t;
static float px, py, vx, vy, oil, radius, step_anim, facing = 1;
static float light[W * FH];
static float deco[48][3];
static gsurf *field_bg;
static int field_night = -1;

static const sfx_song tune = {
    66, 4, 3,
    {
        {"C4 - - - - - - - A3 - - - - - - - F3 - - - - - - - G3 - - - - - - - ", W_SINE, 0.16f, 0.6f, 0.3f, 0, 0, -0.2f},
        {"E4 - - - - - - - C4 - - - - - - - A3 - - - - - - - B3 - - - - - - - ", W_SINE, 0.12f, 0.6f, 0.3f, 0, 0, 0.2f},
        {". . . . G5 . . . . . . . E5 . . . . . . . C5 . . . . . . . D5 . . . ", W_TRI, 0.06f, 0.4f, 0.01f, 0, 0, 0},
    }};

static const constellation *sky(void) { return &skies[(night - 1) % NSKIES]; }

static float sky_x(int i) { return 30 + sky()->pt[i][0] * (W - 60); }
static float sky_y(int i) { return 14 + sky()->pt[i][1] * (SKY_H - 26); }

static void place_stars(void)
{
    nstars = sky()->n;
    woke = 0;
    for (int i = 0; i < nstars; i++) {
        int tries = 0;
        float x, y;
        int ok;
        do {
            x = rng_range(18, W - 18);
            y = rng_range(FY0 + 18, FY1 - 18);
            ok = (x - px) * (x - px) + (y - py) * (y - py) > 40 * 40;
            for (int j = 0; j < i && ok; j++)
                if ((x - st[j].x) * (x - st[j].x) + (y - st[j].y) * (y - st[j].y) < 34 * 34)
                    ok = 0;
        } while (!ok && ++tries < 200);
        st[i].x = x;
        st[i].y = y;
        st[i].awake = 0;
        st[i].t = 0;
    }
}

static void spawn_fly(mover *f)
{
    f->on = 1;
    f->x = rng_range(16, W - 16);
    f->y = rng_range(FY0 + 16, FY1 - 16);
    f->t = rng_f() * 6.28f;
}

static void make_deco(void)
{
    for (int i = 0; i < 48; i++) {
        deco[i][0] = rng_range(0, W);
        deco[i][1] = rng_range(FY0 + 4, FY1 - 2);
        deco[i][2] = (float)rng_int(0, 5);
    }
}

static void begin_night(int n)
{
    night = n;
    state = S_NIGHT;
    oil = 100;
    flare_t = flare_cd = ember_t = 0;
    place_stars();
    for (int i = 0; i < NFLY; i++) {
        fly[i].on = 0;
        if (i < 3)
            spawn_fly(&fly[i]);
    }
    for (int i = 0; i < NMOTH; i++) {
        moth[i].on = i < (night - 2 < 0 ? 0 : night - 2);
        moth[i].x = rng_f() < 0.5f ? -10 : W + 10;
        moth[i].y = rng_range(FY0 + 20, FY1 - 20);
        moth[i].vx = moth[i].vy = 0;
        moth[i].cool = 60 + i * 60;
    }
    make_deco();
    field_night = -1;
    sfx_slide(W_SINE, 300, 600, 0.4f, 0.2f);
    cab_log("lamp night %d (%s, %d stars)", night, sky()->name, nstars);
}

static void save_best(void)
{
    if (best > saved_best && demo <= 0) {
        if (cab_score_save("lamp", best) == 0)
            saved_best = best;
        else
            cab_log("lamp: score save failed");
    }
}

static void wake(int i)
{
    st[i].awake = 1;
    st[i].t = 0;
    woke++;
    oil = clampf(oil + 18, 0, 100);
    sfx_note(W_TRI, sky()->melody[woke - 1], 0.6f, 0.45f);
    sfx_note(W_SINE, sky()->melody[woke - 1] + 12, 0.4f, 0.15f);
    part_burst(st[i].x, st[i].y, 22, 2.2f, 40, 2.f, GOLD, PART_STAR);
    gfx_shake(1.5f);
    cab_log("lamp star %d/%d", woke, nstars);
}

/* ------------------------------------------------------------------ the built-in walker */

static void bot(void)
{
    float tx = px, ty = py, bd = 1e9f;
    cab_bot_clear();
    if (state == S_TITLE) {
        if (frame % 40 == 5)
            cab_bot(CAB_LOW, 1);
        return;
    }
    if (state != S_NIGHT)
        return;
    for (int i = 0; i < nstars; i++) {
        float d;
        if (st[i].awake)
            continue;
        d = (st[i].x - px) * (st[i].x - px) + (st[i].y - py) * (st[i].y - py);
        if (d < bd) {
            bd = d;
            tx = st[i].x;
            ty = st[i].y;
        }
    }
    if (oil < 35)
        for (int i = 0; i < NFLY; i++) {
            float d;
            if (!fly[i].on)
                continue;
            d = (fly[i].x - px) * (fly[i].x - px) + (fly[i].y - py) * (fly[i].y - py);
            if (d < bd * 1.5f) {
                bd = d;
                tx = fly[i].x;
                ty = fly[i].y;
            }
        }
    if (tx < px - 2)
        cab_bot(CAB_LEFT, 1);
    if (tx > px + 2)
        cab_bot(CAB_RIGHT, 1);
    if (ty < py - 2)
        cab_bot(CAB_UP, 1);
    if (ty > py + 2)
        cab_bot(CAB_DOWN, 1);
    for (int i = 0; i < NMOTH; i++)
        if (moth[i].on && fabsf(moth[i].x - px) < 30 && fabsf(moth[i].y - py) < 30 && flare_cd == 0 && oil > 30)
            cab_bot(CAB_LOW, 1);
}

/* ------------------------------------------------------------------ drawing */

static void add_light(float cx, float cy, float r, float k)
{
    int x0 = (int)(cx - r), x1 = (int)(cx + r + 1), y0 = (int)(cy - r) - FY0, y1 = (int)(cy + r + 1) - FY0;
    float inv = 1.f / (r * r);
    if (x0 < 0)
        x0 = 0;
    if (x1 > W)
        x1 = W;
    if (y0 < 0)
        y0 = 0;
    if (y1 > FH)
        y1 = FH;
    for (int y = y0; y < y1; y++) {
        float dy = y + FY0 + 0.5f - cy;
        float *row = light + y * W;
        for (int x = x0; x < x1; x++) {
            float dx = x + 0.5f - cx;
            float v = 1.f - (dx * dx + dy * dy) * inv;
            if (v > 0)
                row[x] += v * v * k;
        }
    }
}

static void apply_darkness(void)
{
    /* Multiply the meadow by its light, and lean the shadows blue. Tables keep it to
     * integer work per pixel: the cabinet's A7 does this 51 thousand times a frame. */
    static int ready;
    static Uint16 fr[257], fg[257], fb[257];
    static Uint8 blue[257];
    if (!ready) {
        for (int i = 0; i <= 256; i++) {
            float k = i / 256.f;
            fr[i] = (Uint16)(k * (0.75f + 0.25f * k) * 256);
            fg[i] = (Uint16)(k * (0.85f + 0.15f * k) * 256);
            fb[i] = (Uint16)(k * 256);
            blue[i] = (Uint8)(14 * (1 - k));
        }
        ready = 1;
    }
    for (int y = 0; y < FH; y++) {
        Uint32 *p = gfx_screen.px + (y + FY0) * W;
        float *l = light + y * W;
        for (int x = 0; x < W; x++) {
            int ki = (int)(l[x] * 256.f);
            Uint32 c = p[x];
            unsigned r, g, b;
            if (ki >= 256)
                continue;
            r = (((c >> 16) & 255) * fr[ki]) >> 8;
            g = (((c >> 8) & 255) * fg[ki]) >> 8;
            b = ((c & 255) * fb[ki] >> 8) + blue[ki];
            p[x] = 0xff000000u | (r << 16) | (g << 8) | (b > 255 ? 255 : b);
        }
    }
}

static void draw_sky(void)
{
    const constellation *c = sky();
    float glow = state == S_DONE ? clampf(done_t / 40.f, 0, 1) : 0;
    gfx_vgrad(0, 0, W, SKY_H, col_mix(HEX(0x05061a), HEX(0x1a2058), glow), col_mix(HEX(0x18163c), HEX(0x4a3a7a), glow));
    for (int i = 0; i < 40; i++) {
        int x = (i * 53 + 11) % W, y = (i * 29 + 7) % (SKY_H - 4);
        gfx_pixel(x, y, col_alpha(HEX(0xc0c8ff), 60 + (int)(40 * sinf(frame * 0.04f + i))));
    }
    if (state == S_TITLE)
        return;
    /* Lines between stars already home. */
    for (int i = 1; i < c->n; i++) {
        int both = st[i].awake == 2 && st[i - 1].awake == 2;
        gcol lc = both ? col_alpha(HEX(0xffe8a0), 200) : HEXA(0x6a6aa0, 50);
        if (both || state == S_NIGHT)
            gfx_line(sky_x(i - 1), sky_y(i - 1), sky_x(i), sky_y(i), both ? 1.4f : 1.f, lc);
    }
    for (int i = 0; i < c->n; i++) {
        float x = sky_x(i), y = sky_y(i);
        if (st[i].awake == 2) {
            gfx_glow(x, y, 10 + glow * 6, HEXA(0xffd060, 160));
            gfx_star(x, y, 4.5f, frame * 0.02f + i, CREAM);
        } else {
            gfx_ring(x, y, 3.5f, 1, HEXA(0x8a8ac8, 120));
        }
    }
    if (state == S_DONE) {
        float k = ease_out_back(clampf(done_t / 30.f, 0, 1));
        gfx_text_c(W / 2, (int)(SKY_H - 16 * k), 1, GOLD, INK, "%s is awake", c->name);
    }
}

static void paint_field(void)
{
    gfx_clip(0, FY0, W, FH);
    gfx_vgrad(0, FY0, W, FH, HEX(0x3a6a4a), HEX(0x2a5a3c));
    for (int i = 0; i < 48; i++) {
        float x = deco[i][0], y = deco[i][1];
        switch ((int)deco[i][2]) {
        case 0:
        case 1:
            gfx_tri(x - 3, y, x, y - 7, x + 1, y, HEX(0x5a9a5a));
            gfx_tri(x, y, x + 3, y - 6, x + 4, y, HEX(0x4a8a4a));
            break;
        case 2:
            gfx_circle(x, y, 2, i % 2 ? HEX(0xff9ac8) : HEX(0xfff09a));
            gfx_pixel((int)x, (int)y, HEX(0xffffff));
            break;
        case 3:
            gfx_ellipse(x, y, 7, 4, HEX(0x6a7a7a));
            gfx_ellipse(x - 1, y - 1, 5, 2.5f, HEX(0x8a9a9a));
            break;
        default:
            gfx_circle(x, y - 6, 9, HEX(0x24503a));
            gfx_rect((int)x - 1, (int)y - 2, 3, 6, HEX(0x4a3a2a));
        }
    }
    gfx_noclip();
}

static void draw_field(void)
{
    int key = state == S_TITLE ? 0 : night;
    gfx_rect(0, SKY_H, W, FY0 - SKY_H, HEX(0x0a0818));
    if (!field_bg)
        field_bg = gfx_surf_new(W, H);
    if (field_bg && field_night != key) {
        gfx_target(field_bg);
        paint_field();
        gfx_target(NULL);
        field_night = key;
    }
    if (field_bg) {
        gfx_clip(0, FY0, W, FH);
        gfx_blit(field_bg, 0, 0);
        gfx_noclip();
    } else
        paint_field();
    gfx_clip(0, FY0, W, FH);
    for (int i = 0; i < nstars && state != S_TITLE; i++) {
        if (st[i].awake)
            continue;
        gfx_star(st[i].x, st[i].y, 6, 0.3f, HEX(0x9aa0c0));
        gfx_star(st[i].x, st[i].y, 4, 0.3f, HEX(0xd8dcf0));
    }
    gfx_noclip();
}

static void draw_wren(void)
{
    float x = px, y = py;
    float bob = sinf(step_anim) * 1.2f;
    float lx = x + facing * 7, ly = y - 8 + bob * 0.5f;
    gfx_ellipse(x, y + 7, 7, 2.5f, HEXA(0x000000, 90));
    /* Cloak, head, hood. */
    gfx_tri(x - 7, y + 7, x, y - 7 + bob, x + 7, y + 7, HEX(0x2a3a8a));
    gfx_tri(x - 5, y + 7, x, y - 3 + bob, x + 5, y + 7, HEX(0x3a4aa8));
    gfx_circle_o(x, y - 7 + bob, 5, HEX(0xf2d2b0), INK, 1);
    gfx_ellipse(x, y - 10 + bob, 6, 3.5f, HEX(0x2a3a8a));
    gfx_circle(x + facing * 2, y - 6 + bob, 0.9f, INK);
    /* The lantern. */
    gfx_line(x + facing * 3, y - 2, lx, ly - 4, 1, HEX(0x8a7050));
    gfx_rrect_o(lx - 3, ly - 4, 6, 8, 1.5f, HEX(0xffd27a), INK, 1);
    gfx_rect((int)lx - 1, (int)ly - 2, 3, 4, ember_t > 0 ? HEX(0xa04020) : HEX(0xfff6c8));
}

static void draw(void)
{
    draw_sky();
    draw_field();
    if (state != S_TITLE) {
        for (int i = 0; i < NFLY; i++)
            if (fly[i].on)
                gfx_circle(fly[i].x, fly[i].y, 1.5f, HEX(0xe8ff90));
        for (int i = 0; i < NMOTH; i++)
            if (moth[i].on) {
                float wing = fabsf(sinf(frame * 0.6f + i)) * 4;
                gfx_ellipse(moth[i].x - 3, moth[i].y, 3, 1 + wing, HEX(0xb8a890));
                gfx_ellipse(moth[i].x + 3, moth[i].y, 3, 1 + wing, HEX(0xb8a890));
                gfx_ellipse(moth[i].x, moth[i].y, 1.5f, 3, HEX(0x6a5a4a));
            }
        draw_wren();
    }
    /* Light. */
    for (int i = 0; i < W * FH; i++)
        light[i] = 0.07f;
    if (state == S_TITLE) {
        float cx = W / 2 + sinf(frame * 0.02f) * 40, cy = 220 + cosf(frame * 0.03f) * 30;
        add_light(cx, cy, 90, 1.1f);
    } else {
        add_light(px + facing * 7, py - 8, radius, 1.15f);
        for (int i = 0; i < NFLY; i++)
            if (fly[i].on)
                add_light(fly[i].x, fly[i].y, 14, 0.5f + 0.3f * sinf(frame * 0.2f + i));
        for (int i = 0; i < nstars; i++)
            if (st[i].awake == 1)
                add_light(st[i].x, st[i].y + (FY0 - st[i].y) * st[i].t, 40 * (1 - st[i].t) + 10, 0.9f);
        if (state == S_DONE)
            for (int i = 0; i < W * FH; i++)
                light[i] += clampf(done_t / 60.f, 0, 0.6f);
    }
    apply_darkness();
    if (state != S_TITLE) {
        /* Sleeping stars breathe through the dark, so they can be found. */
        for (int i = 0; i < nstars; i++)
            if (!st[i].awake) {
                float b = 0.5f + 0.5f * sinf(frame * 0.05f + i * 1.3f);
                gfx_glow(st[i].x, st[i].y, 9 + b * 4, col_alpha(HEX(0x9aa8ff), (int)(40 + b * 60)));
            } else if (st[i].awake == 1) {
                float k = ease_in_out(st[i].t);
                float x = lerpf(st[i].x, sky_x(i), k), y = lerpf(st[i].y, sky_y(i), k);
                gfx_glow(x, y, 16, HEXA(0xffd060, 220));
                gfx_star(x, y, 5, frame * 0.2f, CREAM);
                if (frame % 2 == 0)
                    part_spawn(x, y, rng_range(-0.3f, 0.3f), 0.4f, 24, 1.5f, HEXA(0xffe090, 200), PART_GLOW);
            }
        for (int i = 0; i < NFLY; i++)
            if (fly[i].on)
                gfx_glow(fly[i].x, fly[i].y, 6, col_alpha(HEX(0xd8ff70), 120 + (int)(80 * sinf(frame * 0.2f + i))));
        gfx_glow(px + facing * 7, py - 8, ember_t > 0 ? 8 : 16, ember_t > 0 ? HEXA(0xff5020, 150) : HEXA(0xffb040, 140));
    }
    part_update();
    part_draw();
    /* HUD under the field. */
    gfx_rect(0, FY1, W, H - FY1, HEX(0x0a0818));
    if (state != S_TITLE) {
        gfx_text_o(4, FY1 + 3, 1, CREAM, INK, "night %d", night);
        gfx_rrect(56, FY1 + 4, 80, 6, 3, HEX(0x2a2244));
        gfx_rrect(56, FY1 + 4, 80 * oil / 100.f, 6, 3, oil < 25 ? HEX(0xff7040) : HEX(0xffc040));
        gfx_star(146, FY1 + 7, 4, 0, GOLD);
        gfx_text_o(153, FY1 + 3, 1, GOLD, INK, "%d/%d", woke, nstars);
        gfx_text_o(W - 4 - gfx_text_w(1, "best %d", best), FY1 + 3, 1, HEX(0xa0a0d0), INK, "best %d", best);
    }
    if (state == S_TITLE) {
        float bob = sinf(frame * 0.05f) * 3;
        gfx_text_c(W / 2, (int)(16 + bob), 5, GOLD, INK, "Lamp");
        gfx_text_c(W / 2, 62, 1, HEX(0xc0c8ff), HEXA(0, 0), "wake the stars that fell");
        gfx_rrect(24, 140, W - 48, 74, 10, HEXA(0x0a0818, 200));
        gfx_text_c(W / 2, 148, 1, CREAM, HEXA(0, 0), "walk into a star to wake it");
        gfx_text_c(W / 2, 160, 1, HEX(0xd8ff90), HEXA(0, 0), "fireflies fill the lamp");
        gfx_text_c(W / 2, 172, 1, HEX(0xffc080), HEXA(0, 0), "button: lift the lamp");
        if ((frame / 30) % 2)
            gfx_text_c(W / 2, 190, 2, CREAM, INK, "press to start");
        if (best > 0)
            gfx_text_c(W / 2, 230, 1, GOLD, INK, "best %d nights", best);
    }
    if (ouch_t > 0)
        gfx_text_c((int)px, (int)py - 28, 1, HEX(0xffa080), INK, "a moth!");
    if (ember_t > 0)
        gfx_text_c(W / 2, FY0 + 8, 1, HEX(0xffb080), INK, "the lamp is out... it will relight");
    if (demo > 0)
        gfx_text_c(W / 2, FY0 + 20, 1, HEXA(0xfff6ea, 200), INK, "demo - press to play");
    if (state == S_TITLE)
        gfx_text_c(W / 2, H - 10, 1, HEXA(0x8080b0, 200), HEXA(0, 0), "hold 1P+2P to leave");
    gfx_present();
}

/* ------------------------------------------------------------------ update */

static void update(void)
{
    int dx = cab_down(0, CAB_RIGHT) - cab_down(0, CAB_LEFT);
    int dy = cab_down(0, CAB_DOWN) - cab_down(0, CAB_UP);
    int lift = cab_pressed(0, CAB_LOW) || cab_pressed(0, CAB_TL) || cab_pressed(0, CAB_TR);
    float maxv = (fast ? 2.4f : 1.8f) * (ember_t > 0 ? 0.6f : 1.f);
    float target;
    vx = approach(vx, dx * maxv, 0.25f);
    vy = approach(vy, dy * maxv, 0.25f);
    px = clampf(px + vx, 8, W - 8);
    py = clampf(py + vy, FY0 + 10, FY1 - 8);
    if (dx)
        facing = (float)dx;
    if (dx || dy)
        step_anim += 0.3f;
    /* Oil and the light it gives. */
    oil -= fast ? 0.07f : 0.05f;
    if (lift && flare_cd == 0 && oil > 8 && ember_t == 0) {
        flare_t = 40;
        flare_cd = 70;
        oil -= 12;
        sfx_slide(W_SINE, 400, 900, 0.35f, 0.3f);
        sfx_noise(0.2f, 0.08f, 12000);
        part_burst(px, py - 8, 16, 2.5f, 30, 2.f, HEXA(0xffc060, 220), PART_GLOW);
        for (int i = 0; i < NMOTH; i++)
            if (moth[i].on) {
                float ax = moth[i].x - px, ay = moth[i].y - py, d = sqrtf(ax * ax + ay * ay) + 1;
                moth[i].vx = ax / d * 4;
                moth[i].vy = ay / d * 4;
                moth[i].cool = 120;
            }
    }
    if (flare_t > 0)
        flare_t--;
    if (flare_cd > 0)
        flare_cd--;
    if (oil <= 0 && ember_t == 0) {
        oil = 0;
        ember_t = 150;
        sfx_slide(W_TRI, 400, 100, 0.6f, 0.3f);
        cab_log("lamp out");
    }
    if (ember_t > 0 && --ember_t == 0) {
        oil = 60;
        sfx_slide(W_TRI, 200, 600, 0.3f, 0.25f);
    }
    target = ember_t > 0 ? 14 : 28 + oil * 0.5f + (flare_t > 0 ? 50 * flare_t / 40.f : 0);
    radius = approach(radius, target, 0.15f);
    /* Stars. */
    for (int i = 0; i < nstars; i++) {
        if (!st[i].awake) {
            float ax = st[i].x - px, ay = st[i].y - (py - 2);
            if (ax * ax + ay * ay < 13 * 13)
                wake(i);
        } else if (st[i].awake == 1) {
            st[i].t += 0.025f;
            if (st[i].t >= 1) {
                st[i].awake = 2;
                sfx_tone(W_SINE, 1800, 0.08f, 0.12f);
                part_burst(sky_x(i), sky_y(i), 10, 1.5f, 24, 1.5f, CREAM, PART_STAR);
            }
        }
    }
    {
        int home = 0;
        for (int i = 0; i < nstars; i++)
            home += st[i].awake == 2;
        if (home == nstars) {
            int arp[] = {60, 64, 67, 72, 76, 79};
            state = S_DONE;
            done_t = 0;
            sfx_arp(W_TRI, arp, 6, 0.09f, 0.4f);
            if (night > best && demo <= 0)
                best = night;
            save_best();
            cab_log("lamp night %d done", night);
        }
    }
    /* Fireflies wander; touching one fills the lamp. */
    for (int i = 0; i < NFLY; i++) {
        mover *f = &fly[i];
        if (!f->on) {
            if (rng_int(0, 300) == 0)
                spawn_fly(f);
            continue;
        }
        f->t += 0.03f;
        f->x = clampf(f->x + cosf(f->t * 1.3f + i) * 0.6f, 8, W - 8);
        f->y = clampf(f->y + sinf(f->t * 0.9f + i * 2) * 0.5f, FY0 + 8, FY1 - 8);
        if ((f->x - px) * (f->x - px) + (f->y - py) * (f->y - py) < 12 * 12) {
            f->on = 0;
            oil = clampf(oil + 30, 0, 100);
            sfx_note(W_SINE, 88, 0.12f, 0.25f);
            sfx_note(W_SINE, 93, 0.12f, 0.15f);
            part_burst(f->x, f->y, 10, 1.6f, 24, 1.5f, HEX(0xe8ff90), PART_GLOW);
        }
    }
    /* Moths drift toward the light and nibble the oil. */
    for (int i = 0; i < NMOTH; i++) {
        mover *m = &moth[i];
        float ax, ay, d;
        if (!m->on)
            continue;
        if (m->cool > 0) {
            m->cool--;
            m->x += m->vx;
            m->y += m->vy;
            m->vx *= 0.97f;
            m->vy *= 0.97f;
        } else {
            ax = px - m->x;
            ay = py - 10 - m->y;
            d = sqrtf(ax * ax + ay * ay) + 1;
            m->vx = approach(m->vx, ax / d * 0.9f + sinf(frame * 0.1f + i) * 0.6f, 0.05f);
            m->vy = approach(m->vy, ay / d * 0.9f + cosf(frame * 0.13f + i) * 0.6f, 0.05f);
            m->x += m->vx;
            m->y += m->vy;
            if (d < 10) {
                oil = clampf(oil - 20, 0, 100);
                m->cool = 150;
                m->vx = -ax / d * 3;
                m->vy = -ay / d * 3;
                ouch_t = 50;
                sfx_noise(0.2f, 0.2f, 3000);
                gfx_shake(2);
            }
        }
        m->x = clampf(m->x, -12, W + 12);
        m->y = clampf(m->y, FY0, FY1);
    }
    if (ouch_t > 0)
        ouch_t--;
}

int main(int argc, char **argv)
{
    self_test = getenv("LAMP_SELFTEST") != NULL;
    fast = cab_fast(argc, argv);
    if (gfx_init("Lamp", W, H) != 0)
        return 1;
    sfx_init();
    sfx_master(0.36f);
    rng_seed_auto();
    best = saved_best = cab_score_load("lamp");
    music_play(&tune);
    make_deco();
    state = S_TITLE;
    night = 1;
    px = W / 2;
    py = 220;
    if (self_test || getenv("CAB_AUTOPLAY"))
        demo = -1;
    while (cab_poll()) {
        int any = cab_human_any();
        int press = cab_pressed(0, CAB_LOW) || cab_pressed(0, CAB_TL) || cab_pressed(0, CAB_TR);
        if (demo > 0 && any) {
            demo = 0;
            cab_bot_clear();
            state = S_TITLE;
            idle_t = 0;
            part_clear();
        }
        if (demo)
            bot();
        if (state == S_TITLE) {
            idle_t = any ? 0 : idle_t + 1;
            if (press) {
                px = W / 2;
                py = 220;
                begin_night(1);
            } else if (idle_t > 600 && !demo) {
                demo = 1;
                cab_log("lamp demo");
                px = W / 2;
                py = 220;
                begin_night(1);
            }
        } else if (state == S_NIGHT) {
            update();
        } else {
            done_t++;
            if (done_t > 170) {
                if (demo > 0 && night >= 2) {
                    demo = 0;
                    cab_bot_clear();
                    state = S_TITLE;
                } else
                    begin_night(night + 1);
            }
        }
        draw();
        frame++;
        if (self_test && best >= 1 && saved_best >= 1) {
            if (cab_score_load("lamp") != best)
                return 1;
            break;
        }
        if (self_test && frame > 4000)
            return 1;
    }
    save_best();
    cab_shutdown();
    return 0;
}
