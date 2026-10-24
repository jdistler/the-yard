/* Keep: catch what falls. Walk-up band (CONTROLS.md).
 *
 * The stick moves Pip's basket along the bottom of an orchard at sunset. Fruit shakes on
 * the branch before it drops, and its shadow grows on the grass where it will land.
 * LOW is a dash in the way you are leaning (TL and TR dash too). A dash is never needed
 * to catch, it only makes the far ones reachable. Catches in a row build a multiplier.
 * Three misses end the round. Bees come later; catching one costs a heart.
 *
 * Upright 240x320. keep.sav is "best N", written at the end of a round and on quit.
 * KEEP_SELFTEST=1 plays itself until a catch, saves, and checks the file.
 * CAB_AUTOPLAY=1 lets the built-in player run from the first frame (tests, the reel).
 */
#include "gfx.h"
#include "sfx.h"

#include <math.h>
#include <stdlib.h>

#define W 240
#define H 320
#define GROUND 292
#define BASKET_W 40
#define MAXF 8

static const gcol INK = HEX(0x2a1630), CREAM = HEX(0xfff6ea), GOLD = HEX(0xffd257);

enum { T_APPLE, T_PEAR, T_GOLD, T_BEE };
enum { S_TITLE, S_PLAY, S_OVER };

typedef struct {
    int on, type, hang;   /* hang: frames left shaking on the branch */
    float x, y, vy, vx, phase;
} fruit_t;

static fruit_t fr[MAXF];
static int state, score, best, lives, combo, mult, frame, spawn_in, dash_cd, dash_t, hurt_t;
static int over_t, idle_t, demo, new_best, catches, fast, saved_best, round_frames;
static float px, vx, lean, squash, face = 1;
static int self_test;

static const sfx_song tune = {
    118, 4, 4,
    {
        {"E5 . G5 . A5 . G5 E5 . . D5 . C5 . D5 . E5 . G5 . A5 . C6 . A5 . G5 . E5 . . .", W_SQUARE, 0.07f, 0.06f, 0.005f, 0, 0.25f, -0.2f},
        {"C3 . . C3 G2 . . . A2 . . A2 E2 . . . F2 . . F2 C3 . . . G2 . . G2 D3 . G2 .", W_TRI, 0.30f, 0.08f, 0.004f, 0, 0, 0},
        {"K . H . S . H . K . H K S . H . K . H . S . H . K . H K S . H H", W_NOISE, 0.10f, 0.05f, 0, 0, 0, 0.2f},
        {"C5 - - - - - - - A4 - - - - - - - F4 - - - - - - - G4 - - - - - - - ", W_SINE, 0.05f, 0.3f, 0.2f, 0, 0, 0.3f},
    }};

static float level(void)
{
    float l = score / 18.f + round_frames / 3600.f;
    return fast ? l * 1.3f + 0.6f : l;
}

static int tree_x(void)
{
    /* Branch spots along the canopy. */
    static const int xs[] = {22, 44, 66, 90, 112, 134, 158, 180, 202, 220};
    return xs[rng_int(0, 9)];
}

static void spawn(void)
{
    fruit_t *f = NULL;
    for (int i = 0; i < MAXF; i++)
        if (!fr[i].on) {
            f = &fr[i];
            break;
        }
    if (!f)
        return;
    f->on = 1;
    f->vx = 0;
    {
        int r = rng_int(0, 99);
        float l = level();
        if (score >= 10 && r < (int)(8 + l * 4) && r < 24)
            f->type = T_BEE;
        else if (r > 94)
            f->type = T_GOLD;
        else if (r > 74)
            f->type = T_PEAR;
        else
            f->type = T_APPLE;
    }
    f->x = (float)tree_x();
    f->y = 48 + rng_range(0, 10);
    f->vy = 0;
    f->phase = rng_f() * 6.28f;
    f->hang = f->type == T_BEE ? 20 : (int)(46 - clampf(level() * 6, 0, 22));
    if (f->type == T_BEE) {
        f->y = 40;
        f->vx = rng_f() < 0.5f ? -1.f : 1.f;
    }
}

static void reset_round(void)
{
    for (int i = 0; i < MAXF; i++)
        fr[i].on = 0;
    score = 0;
    lives = 3;
    combo = 0;
    mult = 1;
    spawn_in = 30;
    px = W / 2;
    vx = 0;
    dash_cd = dash_t = hurt_t = 0;
    new_best = 0;
    catches = 0;
    round_frames = 0;
    part_clear();
}

static void save_best(void)
{
    if (best > saved_best && demo <= 0) {
        if (cab_score_save("keep", best) == 0)
            saved_best = best;
        else
            cab_log("keep: score save failed");
    }
}

static void end_round(void)
{
    int arp[] = {67, 64, 60, 55};
    state = S_OVER;
    over_t = 0;
    sfx_arp(W_TRI, arp, 4, 0.12f, 0.4f);
    music_volume(0.35f);
    save_best();
    cab_log("keep over %d best %d", score, best);
}

static void catch_fruit(fruit_t *f)
{
    static const int pent[] = {72, 74, 76, 79, 81, 84, 86, 88, 91, 93};
    int pts = f->type == T_GOLD ? 5 : f->type == T_PEAR ? 2 : 1;
    char buf[12];
    gcol c = f->type == T_GOLD ? GOLD : f->type == T_PEAR ? HEX(0xc8e05a) : HEX(0xff5a4a);
    combo++;
    catches++;
    mult = 1 + combo / 6;
    if (mult > 5)
        mult = 5;
    score += pts * mult;
    if (score > best && demo <= 0) {
        if (!new_best && best > 0) {
            int fan[] = {72, 76, 79, 84};
            sfx_arp(W_SQUARE, fan, 4, 0.07f, 0.25f);
            part_text(W / 2, 110, GOLD, "NEW BEST");
        }
        new_best = 1;
        best = score;
    }
    sfx_note(W_TRI, pent[combo % 10], 0.18f, 0.45f);
    if (f->type == T_GOLD) {
        int arp[] = {84, 88, 91, 96};
        sfx_arp(W_SINE, arp, 4, 0.05f, 0.3f);
        gfx_flash(HEXA(0xfff0b0, 90), 10);
    }
    squash = 1.f;
    snprintf(buf, sizeof buf, mult > 1 ? "+%dx%d" : "+%d", pts, mult);
    part_text(f->x, GROUND - 46, c, buf);
    part_burst(f->x, GROUND - 26, 10 + pts * 3, 2.4f, 30, 2.f, c, f->type == T_GOLD ? PART_STAR : PART_DOT);
    if (combo % 6 == 0) {
        part_burst(px, GROUND - 20, 18, 3.f, 40, 2.5f, GOLD, PART_STAR);
        sfx_slide(W_SQUARE, 600, 1200, 0.2f, 0.18f);
    }
    cab_log("keep catch %d", score);
}

static void lose_life(float x, int bee)
{
    lives--;
    combo = 0;
    mult = 1;
    hurt_t = 40;
    gfx_shake(5);
    sfx_slide(W_SQUARE, 220, 70, 0.25f, 0.35f);
    sfx_noise(0.15f, 0.3f, 6000);
    part_burst(x, bee ? GROUND - 24 : GROUND, 16, 2.2f, 34, 2.2f, bee ? HEX(0xffd84a) : HEX(0xd23a3a), PART_DOT);
    cab_log("keep miss lives %d", lives);
    if (lives <= 0)
        end_round();
}

/* ------------------------------------------------------------------ the built-in player */

static void bot(void)
{
    fruit_t *target = NULL;
    float best_t = 1e9f;
    cab_bot_clear();
    if (state != S_PLAY) {
        if ((state == S_TITLE && frame % 40 == 5) || (state == S_OVER && over_t > 60 && over_t % 30 == 0))
            cab_bot(CAB_LOW, 1);
        return;
    }
    for (int i = 0; i < MAXF; i++) {
        fruit_t *f = &fr[i];
        float t;
        if (!f->on || f->type == T_BEE)
            continue;
        /* Frames until it reaches the basket. */
        t = f->hang + (f->vy > 0 ? (GROUND - 30 - f->y) / (f->vy + 1.f) : 60);
        if (t < best_t) {
            best_t = t;
            target = f;
        }
    }
    if (target) {
        float dx = target->x - px;
        for (int i = 0; i < MAXF; i++)
            if (fr[i].on && fr[i].type == T_BEE && fabsf(fr[i].x - target->x) < 26 && fr[i].y > 150)
                dx = target->x + (fr[i].x < target->x ? 30 : -30) - px;
        if (dx < -4)
            cab_bot(CAB_LEFT, 1);
        else if (dx > 4)
            cab_bot(CAB_RIGHT, 1);
        if (fabsf(dx) > 80 && best_t < 50 && dash_cd == 0 && frame % 2)
            cab_bot(CAB_LOW, 1);
    }
}

/* ------------------------------------------------------------------ drawing */

static void draw_fruit(int type, float x, float y, float wob, float dir)
{
    float r = 6.f;
    switch (type) {
    case T_BEE: {
        float wing = sinf(frame * 1.2f) * 2.5f;
        gfx_ellipse(x - 3, y - 5 - wing, 4, 2.5f, HEXA(0xe0f4ff, 200));
        gfx_ellipse(x + 3, y - 5 + wing, 4, 2.5f, HEXA(0xe0f4ff, 200));
        gfx_ellipse_o(x, y, 7, 5, HEX(0xffd02a), INK, 1.2f);
        gfx_rect((int)x - 2, (int)y - 5, 2, 10, INK);
        gfx_rect((int)x + 2, (int)y - 5, 2, 10, INK);
        gfx_circle(x + (dir > 0 ? 5 : -5), y - 1, 1.2f, INK);
        break;
    }
    case T_PEAR:
        gfx_circle_o(x, y + 2, r, HEX(0xc8e05a), INK, 1.2f);
        gfx_circle_o(x, y - 4, r - 2.5f, HEX(0xc8e05a), INK, 1.2f);
        gfx_circle(x, y + 2, r - 0.2f, HEX(0xc8e05a));
        gfx_circle(x - 2, y, 1.8f, HEXA(0xffffff, 150));
        gfx_line(x, y - 8, x + 1 + wob, y - 11, 1.2f, HEX(0x5a3a20));
        break;
    case T_GOLD:
        gfx_glow(x, y, 16, HEXA(0xffd060, 160));
        gfx_star(x, y, 8, frame * 0.08f, INK);
        gfx_star(x, y, 6.5f, frame * 0.08f, GOLD);
        gfx_circle(x - 1.5f, y - 1.5f, 1.5f, CREAM);
        break;
    default:
        gfx_circle_o(x, y, r, HEX(0xff5a4a), INK, 1.2f);
        gfx_circle(x - 2, y - 2, 2, HEXA(0xffffff, 140));
        gfx_line(x, y - 5, x + wob, y - 9, 1.2f, HEX(0x5a3a20));
        gfx_ellipse(x + 3 + wob, y - 8, 2.6f, 1.4f, HEX(0x6fd36f));
    }
}

static void paint_world(void)
{
    float sx = 0;
    gfx_vgrad(0, 0, W, 200, HEX(0x3b2a6e), HEX(0xff9a6a));
    gfx_vgrad(0, 200, W, GROUND - 200, HEX(0xff9a6a), HEX(0xffc98a));
    gfx_glow(120 - sx, 196, 70, HEXA(0xffe0a0, 120));
    gfx_circle(120 - sx, 200, 22, HEX(0xfff0c4));
    {
        float far_[] = {-20, 236, 50, 214, 100, 230, 150, 210, 200, 226, 260, 212, 260, 300, -20, 300};
        float mid[] = {-20, 262, 60, 244, 130, 258, 190, 240, 260, 254, 260, 300, -20, 300};
        for (int i = 0; i < 16; i += 2)
            far_[i] -= sx * 2;
        for (int i = 0; i < 14; i += 2)
            mid[i] -= sx * 4;
        gfx_poly(far_, 8, HEX(0xb06a8a));
        gfx_poly(mid, 7, HEX(0x7a4a7a));
    }
    gfx_vgrad(0, GROUND - 14, W, H - GROUND + 14, HEX(0x5cae58), HEX(0x2f6e3a));
    for (int i = 0; i < 24; i++) {
        int gx = (i * 37) % W;
        gfx_tri(gx, GROUND - 13, gx + 3, GROUND - 19, gx + 6, GROUND - 13, HEX(0x6cc066));
    }
    /* The orchard canopy across the top. */
    gfx_rect(8, 0, 10, 60, HEX(0x5a3a28));
    gfx_rect(222, 0, 10, 60, HEX(0x5a3a28));
    for (int i = 0; i < 13; i++) {
        float cx = i * 20.f, cy = 26 + (i % 3) * 7;
        gfx_circle(cx, cy + 4, 20, HEX(0x24603a));
        gfx_circle(cx + 4, cy - 2, 16, HEX(0x2f7a44));
        gfx_circle(cx + 6, cy - 6, 8, HEX(0x3f9452));
    }
}

static void draw_world(void)
{
    static gsurf *bg;
    if (!bg && (bg = gfx_surf_new(W, H)) != NULL) {
        gfx_target(bg);
        paint_world();
        gfx_target(NULL);
    }
    if (bg)
        gfx_blit(bg, 0, 0);
    else
        paint_world();
}

static void draw_player(void)
{
    float x = px, y = GROUND - 4;
    float sq = squash * 0.25f;
    float bw = BASKET_W * (1 + sq), bh = 18 * (1 - sq * 0.8f);
    float look = face * 1.5f;
    int blink = (frame % 180) < 6;
    if (hurt_t > 0 && (hurt_t / 4) % 2)
        return;
    /* Dash trail. */
    if (dash_t > 0)
        for (int k = 1; k <= 3; k++)
            gfx_rrect(x - bw / 2 - vx * k * 2, y - bh, bw, bh, 5, HEXA(0xffffff, 60 - k * 15));
    gfx_ellipse(x, GROUND + 2, bw * 0.55f, 4, HEXA(0x1a3a20, 120));
    /* Pip the hedgehog peeks over the basket. */
    {
        float hx = x + lean * 3, hy = y - bh - 10 + sq * 6;
        for (int k = -3; k <= 3; k++)
            gfx_tri(hx + k * 5 - 4, hy - 4, hx + k * 5, hy - 17 + abs(k) * 2, hx + k * 5 + 4, hy - 4, HEX(0x6a4a3a));
        gfx_ellipse_o(hx, hy, 15, 12, HEX(0x8a6450), INK, 1.5f);
        gfx_ellipse(hx + look, hy + 3, 10, 8, HEX(0xf2d2b0));
        if (blink) {
            gfx_rect((int)(hx - 6 + look), (int)hy, 4, 1, INK);
            gfx_rect((int)(hx + 3 + look), (int)hy, 4, 1, INK);
        } else {
            gfx_circle(hx - 4 + look, hy + 0.5f, 1.8f, INK);
            gfx_circle(hx + 5 + look, hy + 0.5f, 1.8f, INK);
            gfx_pixel((int)(hx - 4 + look), (int)hy - 1, CREAM);
            gfx_pixel((int)(hx + 5 + look), (int)hy - 1, CREAM);
        }
        gfx_circle(hx + look * 2, hy + 5, 1.8f, INK);
        if (hurt_t > 20)
            gfx_text_c((int)hx, (int)hy - 26, 1, HEX(0xff6060), HEXA(0, 0), "ouch");
    }
    gfx_rrect_o(x - bw / 2, y - bh, bw, bh, 5, HEX(0xc98a4b), INK, 1.5f);
    for (int k = 1; k < 4; k++)
        gfx_rect((int)(x - bw / 2 + 2), (int)(y - bh + k * bh / 4), (int)bw - 4, 1, HEX(0x9a6430));
    gfx_rrect(x - bw / 2 - 2, y - bh - 2, bw + 4, 5, 2, HEX(0xdba060));
    if (mult > 1) {
        gfx_rrect(x + bw / 2 - 2, y - bh - 14, 18, 11, 4, GOLD);
        gfx_text((int)(x + bw / 2 + 1), (int)(y - bh - 12), 1, INK, "x%d", mult);
    }
}

static void draw_hud(void)
{
    for (int i = 0; i < 3; i++) {
        gcol c = i < lives ? HEX(0xff5a7a) : HEXA(0x2a1630, 140);
        gfx_heart(14 + i * 15, 82, 5.5f, INK);
        gfx_heart(14 + i * 15, 82, 4.3f, c);
    }
    gfx_text_c(W / 2, 72, 3, CREAM, INK, "%d", score);
    gfx_text_o(W - 4 - gfx_text_w(1, "best %d", best), 78, 1, GOLD, INK, "best %d", best);
}

static void draw(void)
{
    draw_world();
    for (int i = 0; i < MAXF; i++) {
        fruit_t *f = &fr[i];
        if (!f->on)
            continue;
        if (f->type != T_BEE) {
            /* Where it will land: a shadow that sharpens as it falls. */
            float k = clampf((f->y - 40) / (GROUND - 60), 0, 1);
            gfx_ellipse(f->x, GROUND + 1, 4 + k * 5, 2 + k, col_alpha(HEX(0x1a3a20), 60 + (int)(k * 100)));
        }
    }
    draw_player();
    for (int i = 0; i < MAXF; i++) {
        fruit_t *f = &fr[i];
        float wob = 0;
        if (!f->on)
            continue;
        if (f->hang > 0)
            wob = sinf(frame * 0.9f + f->phase) * (f->hang < 20 ? 2.f : 1.f);
        draw_fruit(f->type, f->x + (f->hang > 0 ? wob : 0), f->y, wob, f->vx);
    }
    part_update();
    part_draw();
    if (state == S_PLAY || state == S_OVER)
        draw_hud();
    if (state == S_TITLE) {
        float bob = sinf(frame * 0.05f) * 3;
        gfx_rrect(26, 96 + bob, W - 52, 106, 12, HEXA(0x2a1630, 200));
        gfx_text_c(W / 2, (int)(104 + bob), 5, GOLD, INK, "Keep");
        gfx_text_c(W / 2, (int)(150 + bob), 1, CREAM, HEXA(0, 0), "catch the fruit in Pip's basket");
        gfx_text_c(W / 2, (int)(164 + bob), 1, HEX(0xffc0a0), HEXA(0, 0), "button dashes   three misses end");
        if ((frame / 30) % 2)
            gfx_text_c(W / 2, (int)(182 + bob), 2, CREAM, INK, "press to start");
        if (best > 0)
            gfx_text_c(W / 2, 212, 1, GOLD, INK, "best %d", best);
    }
    if (state == S_OVER) {
        float k = ease_out_back(clampf(over_t / 30.f, 0, 1));
        gfx_rrect(30, 110 - (1 - k) * 60, W - 60, 92, 12, HEXA(0x2a1630, 220));
        gfx_text_c(W / 2, (int)(120 - (1 - k) * 60), 2, HEX(0xffb0a0), INK, "the basket's full");
        gfx_text_c(W / 2, (int)(140 - (1 - k) * 60), 4, CREAM, INK, "%d", score);
        if (new_best && score > 0)
            gfx_text_c(W / 2, (int)(176 - (1 - k) * 60), 1, GOLD, HEXA(0, 0), "a new best!");
        else
            gfx_text_c(W / 2, (int)(176 - (1 - k) * 60), 1, GOLD, HEXA(0, 0), "best %d", best);
        if (over_t > 50 && (frame / 30) % 2)
            gfx_text_c(W / 2, 188, 1, CREAM, HEXA(0, 0), "press to play again");
    }
    if (demo > 0)
        gfx_text_c(W / 2, 104, 1, HEXA(0xfff6ea, 200 + (int)(sinf(frame * 0.1f) * 50)), INK, "demo - press to play");
    gfx_text_o(4, H - 11, 1, HEXA(0xd0f0c0, 200), HEXA(0x1a3a20, 200), "1P+2P quit");
    gfx_present();
}

/* ------------------------------------------------------------------ update */

static void update(void)
{
    int left = cab_down(0, CAB_LEFT), right = cab_down(0, CAB_RIGHT);
    int dash = cab_pressed(0, CAB_LOW) || cab_pressed(0, CAB_TL) || cab_pressed(0, CAB_TR);
    int dir = right - left;
    float accel = 0.9f, maxv = fast ? 4.2f : 3.4f;
    round_frames++;
    if (dir)
        face = (float)dir;
    if (dash && dash_cd == 0) {
        vx = face * (fast ? 9.f : 8.f);
        dash_t = 9;
        dash_cd = 22;
        sfx_slide(W_NOISE, 3000, 9000, 0.14f, 0.2f);
        part_burst(px, GROUND - 2, 8, 1.5f, 20, 2, HEXA(0xe8f0c0, 200), PART_DOT);
    }
    if (dash_t > 0)
        dash_t--;
    else {
        vx += dir * accel;
        if (!dir)
            vx *= 0.72f;
        vx = clampf(vx, -maxv, maxv);
    }
    if (dash_cd > 0)
        dash_cd--;
    px += vx;
    if (px < BASKET_W / 2 + 2) {
        px = BASKET_W / 2 + 2;
        vx = 0;
    }
    if (px > W - BASKET_W / 2 - 2) {
        px = W - BASKET_W / 2 - 2;
        vx = 0;
    }
    lean = approach(lean, clampf(vx / 3.f, -1, 1), 0.3f);
    squash *= 0.82f;
    if (hurt_t > 0)
        hurt_t--;
    if (--spawn_in <= 0) {
        int live = 0;
        for (int i = 0; i < MAXF; i++)
            live += fr[i].on;
        if (live < 1 + (int)clampf(level(), 0, 3))
            spawn();
        spawn_in = (int)clampf(70 - level() * 12, 26, 70) + rng_int(0, 14);
    }
    for (int i = 0; i < MAXF; i++) {
        fruit_t *f = &fr[i];
        float g = 0.06f + clampf(level() * 0.012f, 0, 0.06f);
        float rim = GROUND - 22;
        if (!f->on)
            continue;
        if (f->hang > 0) {
            if (--f->hang == 0)
                sfx_tone(W_SINE, 900, 0.04f, 0.08f);
            continue;
        }
        if (f->type == T_BEE) {
            f->vy = 1.1f + level() * 0.1f;
            f->x += f->vx * 1.2f;
            if (f->x < 12 || f->x > W - 12)
                f->vx = -f->vx;
            f->y += f->vy;
        } else {
            f->vy = clampf(f->vy + g, 0, fast ? 6.f : 5.f);
            f->y += f->vy;
        }
        if (f->y >= rim - 6 && f->y <= rim + 8 && fabsf(f->x - px) < BASKET_W / 2 + 4) {
            f->on = 0;
            if (f->type == T_BEE) {
                cab_log("keep sting");
                lose_life(f->x, 1);
            } else
                catch_fruit(f);
            continue;
        }
        if (f->y > GROUND) {
            f->on = 0;
            if (f->type == T_BEE)
                continue;
            lose_life(f->x, 0);
            if (state != S_PLAY)
                return;
        }
    }
}

int main(int argc, char **argv)
{
    int quit_saved = 0;
    self_test = getenv("KEEP_SELFTEST") != NULL;
    fast = cab_fast(argc, argv);
    if (gfx_init("Keep", W, H) != 0)
        return 1;
    sfx_init();
    sfx_master(0.42f);
    rng_seed_auto();
    best = saved_best = cab_score_load("keep");
    music_play(&tune);
    reset_round();
    state = S_TITLE;
    if (self_test || getenv("CAB_AUTOPLAY"))
        demo = -1; /* plays from the first frame; -1 means it is a test, not the attract loop */
    while (cab_poll()) {
        int any = cab_human_any();
        if (demo > 0 && any) {
            /* A real hand ends the attract loop. */
            demo = 0;
            cab_log("keep demo off");
            cab_bot_clear();
            reset_round();
            state = S_TITLE;
            idle_t = 0;
        }
        if (demo)
            bot();
        if (state == S_TITLE) {
            idle_t = any ? 0 : idle_t + 1;
            if (cab_pressed(0, CAB_LOW) || cab_pressed(0, CAB_TL) || cab_pressed(0, CAB_TR)) {
                reset_round();
                state = S_PLAY;
                music_volume(1.f);
                sfx_slide(W_SQUARE, 400, 800, 0.12f, 0.2f);
            } else if (idle_t > 600 && !demo) {
                demo = 1;
                idle_t = 0;
                cab_log("keep demo");
            }
        } else if (state == S_PLAY) {
            update();
        } else {
            over_t++;
            if (over_t > 50 && (cab_pressed(0, CAB_LOW) || cab_pressed(0, CAB_TL) || cab_pressed(0, CAB_TR))) {
                reset_round();
                state = S_PLAY;
                music_volume(1.f);
            } else if (demo > 0 && over_t > 240) {
                demo = 0;
                cab_bot_clear();
                reset_round();
                state = S_TITLE;
            }
        }
        draw();
        frame++;
        if (self_test && catches >= 1 && frame > 8) {
            int stored = best;
            if (cab_score_save("keep", stored) != 0 || cab_score_load("keep") != stored)
                return 1;
            quit_saved = 1;
            break;
        }
        if (self_test && frame > 900)
            return 1;
    }
    if (!quit_saved && demo <= 0)
        save_best();
    cab_shutdown();
    return 0;
}
