/* Chest: walk to the key, open the chest, take the sword, duel Zam.
 * Walk-up band (CONTROLS.md). The stick walks. LOW shoots. TL and TR shoot too.
 * Upright 384x512. A grown-up reads the cream band. chest.sav is "gems N".
 * The spec is DESIGN.md beside this file; the rules and the lines below are its own.
 */
#include "gfx.h"
#include "sfx.h"

#include <fcntl.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define W 384
#define H 512
#define BAND 32
#define SPEED 2
#define POP_FRAMES 40
#define WRAP_FRAMES 120
#define REACT_FRAMES 120
#define WIN_FRAMES 120
#define RESTART_FRAMES 50
#define SHOT_GAP 20
#define MARKS_WIN 9
#define KEY_X 128
#define KEY_Y 348
#define ZX 192
#define ZY 118

enum { PATH, POP, FIGHT, WINBOW, RESTART };
enum { FAIRY_NONE, FAIRY_GOLD, FAIRY_BLUE, FAIRY_PURPLE };

static const gcol CREAM = HEX(0xfff6ea), INK = HEX(0x3a2a44), CAPE = HEX(0x3a6ea5),
                  SKIN = HEX(0xf4c7a1), GOLD = HEX(0xf2c14e), WOOD = HEX(0xc4844a), BROWN = HEX(0xa0673a),
                  SPOON = HEX(0xbabec8), BLUE = HEX(0x6eb5ff), PURPLE = HEX(0x7a5af5), ROSE = HEX(0xe86b9a),
                  WHITE = HEX(0xfffcf8), HELM = HEX(0xc8d0e0);

static int phase, frame, gems, marks, pips;
static int nx, ny, face_x, face_y, has_key, has_sword;
static int pop_t, bow_t, fight_t, hop, react_left, shot_cool, saw_release;
static int telegraph, bubble_on;
static float bx, by, bvx, bvy;
static int aim_x, aim_y;
static int fairy, fairy_x, fairy_y, wrap, wrap_alive;
static int ring_on, ring_x, ring_y, ring_r, ring_safe;
static int star_on, star_x, star_y, star_life;
static int bolt_on, bolt_x0, bolt_y0, bolt_x1, bolt_y1, splash_on, splash_x, splash_y;
static int hurt_cool, shot_once, spoon_flash, goodbye_played;
static char react[40], shown[40];
/* Pictures only: how long a laser stays on screen, walking, the pile's hop. */
static int beam_t, beam_x0, beam_y0, beam_x1, beam_y1, walk_t, pile_hop, moving;
static float deco[40][3];

static const sfx_song path_bed = {
    96, 2, 3,
    {
        {"C5 . E5 . G5 . E5 . D5 . F5 . A5 . G5 . ", W_TRI, 0.08f, 0.2f, 0.01f, 0, 0, -0.2f},
        {"C3 - - - G2 - - - D3 - - - G2 - - - ", W_SINE, 0.16f, 0.3f, 0.02f, 0, 0, 0},
        {"H . . . H . . . H . . . H . H . ", W_NOISE, 0.03f, 0.04f, 0, 0, 0, 0.3f},
    }};
static const sfx_song fight_bed = {
    132, 4, 3,
    {
        {"G4 . . G4 A4 . C5 . G4 . . E4 D4 . E4 . G4 . . G4 A4 . C5 . D5 . C5 . A4 . . . ", W_SQUARE, 0.045f, 0.06f, 0.005f, 0, 0.25f, -0.2f},
        {"C3 . C3 . G2 . G2 . A2 . A2 . F2 . G2 . ", W_TRI, 0.2f, 0.06f, 0.004f, 0, 0, 0},
        {"K . H . S . H . K . H K S . H . ", W_NOISE, 0.06f, 0.05f, 0, 0, 0, 0.2f},
    }};

static void tone(float hz, float dur, float vol) { sfx_tone(W_TRI, hz, dur, vol); }

static void notes(const int *m, int n, float step, float vol) { sfx_arp(W_TRI, m, n, step, vol); }

/* ------------------------------------------------------------------ save */

static void fsync_parent(const char *file)
{
    char dir[256];
    char *slash;
    int fd;
    snprintf(dir, sizeof dir, "%s", file);
    slash = strrchr(dir, '/');
    if (!slash)
        snprintf(dir, sizeof dir, ".");
    else if (slash == dir)
        slash[1] = 0;
    else
        *slash = 0;
    fd = open(dir, O_RDONLY | O_DIRECTORY);
    if (fd < 0)
        return;
    fsync(fd);
    close(fd);
}

static void load_gems(void)
{
    FILE *f = fopen("chest.sav", "r");
    char line[80];
    gems = 0;
    if (!f)
        return;
    while (fgets(line, sizeof line, f)) {
        int n;
        if (sscanf(line, "gems %d", &n) == 1) {
            if (n < 0)
                n = 0;
            if (n > 100000)
                n = 100000;
            gems = n;
        }
    }
    fclose(f);
}

static int save_gems(void)
{
    FILE *f = fopen("chest.sav.tmp", "w");
    if (!f)
        return -1;
    fprintf(f, "gems %d\n", gems);
    if (fflush(f) != 0 || fsync(fileno(f)) != 0) {
        fclose(f);
        unlink("chest.sav.tmp");
        return -1;
    }
    if (fclose(f) != 0) {
        unlink("chest.sav.tmp");
        return -1;
    }
    if (rename("chest.sav.tmp", "chest.sav") != 0)
        return -1;
    fsync_parent("chest.sav");
    return 0;
}

/* ------------------------------------------------------------------ the rules */

static void say(const char *s)
{
    if (!strcmp(shown, s))
        return;
    snprintf(shown, sizeof shown, "%s", s);
    cab_log("chest say %s", shown);
}

static void react_to(const char *s)
{
    snprintf(react, sizeof react, "%s", s);
    react_left = REACT_FRAMES;
}

static int near_chest(void) { return ny < 268 && nx > 156 && nx < 236; }

static int near_key(void)
{
    int dx = nx - KEY_X;
    int dy = ny - KEY_Y;
    return dx * dx + dy * dy < 36 * 36;
}

static void clear_fight(void)
{
    marks = 0;
    pips = 0;
    fight_t = 0;
    telegraph = 0;
    bubble_on = 0;
    fairy = FAIRY_NONE;
    wrap = 0;
    wrap_alive = 0;
    ring_on = 0;
    star_on = 0;
    star_life = 0;
    shot_once = 0;
    hurt_cool = 0;
}

static void take_key(void)
{
    has_key = 1;
    cab_log("chest key %d", frame);
    sfx_note(W_TRI, 84, 0.3f, 0.35f);
    sfx_note(W_SINE, 96, 0.2f, 0.15f);
    part_burst(KEY_X, KEY_Y - 20, 18, 2.5f, 34, 2.5f, GOLD, PART_STAR);
    react_to("The key is his.");
}

static void begin_pop(void)
{
    if (phase != PATH || !has_key)
        return;
    phase = POP;
    pop_t = 0;
    cab_log("chest pop %d", frame);
    {
        int m[] = {72, 76, 79, 84};
        notes(m, 4, 0.08f, 0.35f);
    }
    gfx_shake(4);
    part_burst(ZX, 170, 30, 3.5f, 40, 3, GOLD, PART_STAR);
    music_play(&fight_bed);
    react_to("Pop! He threw the sword.");
}

static void begin_win(void)
{
    phase = WINBOW;
    bow_t = 0;
    if (gems < 100000)
        gems++;
    save_gems();
    cab_log("chest win %d", frame);
    cab_log("chest gems %d", gems);
    {
        int m[] = {72, 76, 79, 84, 88};
        notes(m, 5, 0.1f, 0.38f);
    }
    for (int i = 0; i < 30; i++) {
        gpart *p = part_spawn(ZX + rng_range(-40, 40), ZY, rng_range(-3, 3), rng_range(-5, -1), 70, rng_range(3, 5),
                              i % 3 ? ROSE : GOLD, i % 2 ? PART_STAR : PART_SQUARE);
        p->grav = 0.15f;
        p->drag = 0.99f;
        p->spin = 0.1f;
    }
    pile_hop = 30;
    music_play(&path_bed);
    react_to("Treasure for the pile.");
}

static void add_marks(int n, int big)
{
    marks += n;
    spoon_flash = 16;
    if (big) {
        int m[] = {79, 84};
        cab_log("chest big");
        notes(m, 2, 0.07f, 0.4f);
        gfx_shake(5);
        part_burst(ZX, ZY, 34, 4.f, 40, 3, GOLD, PART_STAR);
        part_text(ZX, ZY - 70, GOLD, "+3");
        react_to("The big bubble popped.");
    } else {
        cab_log("chest mark %d", marks);
        tone(784, 0.1f, 0.3f);
        part_burst(ZX, ZY - 20, 10, 2.f, 24, 2, CREAM, PART_STAR);
        react_to("The sword nicked him.");
    }
    if (marks >= MARKS_WIN && phase == FIGHT)
        begin_win();
}

static void hurt(void)
{
    if (phase != FIGHT || hurt_cool > 0)
        return;
    pips++;
    hurt_cool = 40;
    ny += 16;
    if (ny > 450)
        ny = 450;
    cab_log("chest hurt %d %d", pips, frame);
    sfx_slide(W_TRI, 300, 110, 0.25f, 0.35f);
    gfx_shake(4);
    part_burst(nx, ny - 10, 14, 2.5f, 30, 3, PURPLE, PART_RING);
    if (pips >= 3) {
        int m[] = {79, 76};
        phase = RESTART;
        bow_t = 0;
        cab_log("chest restart %d", frame);
        notes(m, 2, 0.14f, 0.3f);
        react_to("Pop. The sword stayed.");
    } else
        react_to("That bubble got him.");
}

static void fire(void)
{
    int x = nx;
    int y = ny - 8;
    int dx = face_x;
    int dy = face_y;
    int len = has_sword ? 460 : 52;
    int hit = 0;
    if (dx == 0 && dy == 0)
        dy = -1;
    bolt_on = 1;
    bolt_x0 = x;
    bolt_y0 = y;
    cab_log("chest bolt");
    if (has_sword)
        sfx_slide(W_SQUARE, 1400, 500, 0.12f, 0.16f);
    else
        sfx_tone(W_SINE, 1300, 0.07f, 0.2f);
    for (int i = 0; i < len; i++) {
        x += dx;
        y += dy;
        if (x < 4 || x > W - 4 || y < 8 || y > H - 36) {
            splash_on = 1;
            splash_x = x;
            splash_y = y;
            break;
        }
        if (!has_key && (x - KEY_X) * (x - KEY_X) + (y - KEY_Y) * (y - KEY_Y) < 30 * 30)
            take_key();
        if (has_key && phase == PATH && y < 268 && x > 156 && x < 236)
            begin_pop();
        if (has_sword && phase == FIGHT && y < 210 && x > 70 && x < 314) {
            hit = 1;
            break;
        }
    }
    bolt_x1 = x;
    bolt_y1 = y;
    beam_t = has_sword ? 10 : 7;
    beam_x0 = bolt_x0;
    beam_y0 = bolt_y0;
    beam_x1 = x;
    beam_y1 = y;
    if (splash_on)
        part_burst(splash_x, splash_y, 8, 2.f, 18, 2, CREAM, PART_DOT);
    if (!hit || phase != FIGHT)
        return;
    shot_once = 1;
    if (wrap > 0) {
        wrap = 0;
        wrap_alive = 0;
        add_marks(3, 1);
    } else
        add_marks(1, 0);
}

static void spawn_bubble(void)
{
    float dx, dy, mag;
    bubble_on = 1;
    bx = (fight_t / 150) % 2 ? 150.f : 234.f;
    by = 72.f;
    dx = (float)aim_x - bx;
    dy = (float)aim_y - by;
    mag = sqrtf(dx * dx + dy * dy);
    if (mag < 1.f)
        mag = 1.f;
    bvx = dx * 2.5f / mag;
    bvy = dy * 2.5f / mag;
    sfx_slide(W_SINE, 500, 300, 0.2f, 0.2f);
}

static void fight_step(void)
{
    int dx, dy;
    fight_t++;
    if (wrap > 0) {
        if (--wrap == 0 && wrap_alive) {
            wrap_alive = 0;
            add_marks(1, 0);
        }
    }
    if (hurt_cool > 0)
        hurt_cool--;
    if (spoon_flash > 0)
        spoon_flash--;
    if (phase != FIGHT)
        return;
    if (telegraph > 0) {
        if (--telegraph == 0)
            spawn_bubble();
    } else if (wrap == 0 && fairy == FAIRY_NONE && (fight_t % 150) == 40) {
        telegraph = 30;
        aim_x = nx;
        aim_y = ny;
        tone(659, 0.12f, 0.2f);
    }
    if (bubble_on) {
        float dxb, dyb;
        bx += bvx;
        by += bvy;
        dxb = bx - (float)nx;
        dyb = by - (float)ny;
        if (dxb * dxb + dyb * dyb < 30.f * 30.f) {
            bubble_on = 0;
            hurt();
        } else if (by > H - 40 || bx < 0 || bx > W)
            bubble_on = 0;
    }
    if (fairy == FAIRY_NONE && wrap == 0 && !ring_on && !star_on) {
        if (fight_t == 70 || fight_t == 460)
            fairy = FAIRY_GOLD, fairy_x = 40, fairy_y = 180;
        else if (fight_t == 250)
            fairy = FAIRY_BLUE, fairy_x = 340, fairy_y = 240;
        else if ((shot_once && fight_t == 190) || fight_t == 520)
            fairy = FAIRY_PURPLE, fairy_x = 48, fairy_y = 300;
        if (fairy != FAIRY_NONE)
            sfx_note(W_SINE, fairy == FAIRY_PURPLE ? 67 : 88, 0.2f, 0.18f);
    }
    if (fairy == FAIRY_GOLD) {
        dx = ZX - fairy_x;
        dy = 130 - fairy_y;
        if (dx > 4)
            fairy_x += 4;
        else if (dx < -4)
            fairy_x -= 4;
        if (dy > 4)
            fairy_y += 4;
        else if (dy < -4)
            fairy_y -= 4;
        if (abs(dx) < 12 && abs(dy) < 12) {
            fairy = FAIRY_NONE;
            wrap = WRAP_FRAMES;
            wrap_alive = 1;
            bubble_on = 0;
            telegraph = 0;
            cab_log("chest wrap %d", frame);
            sfx_note(W_SINE, 88, 0.4f, 0.3f);
            part_burst(ZX, ZY, 16, 2.5f, 30, 2.5f, GOLD, PART_GLOW);
            react_to("Gold fairy has him.");
        }
    } else if (fairy == FAIRY_BLUE || fairy == FAIRY_PURPLE) {
        dx = nx - fairy_x;
        dy = ny - fairy_y;
        if (dx > 3)
            fairy_x += 3;
        else if (dx < -3)
            fairy_x -= 3;
        if (dy > 3)
            fairy_y += 3;
        else if (dy < -3)
            fairy_y -= 3;
        if (abs(dx) < 14 && abs(dy) < 14) {
            ring_on = 1;
            ring_x = nx;
            ring_y = ny;
            ring_r = 8;
            ring_safe = fairy == FAIRY_BLUE;
            fairy = FAIRY_NONE;
        }
    }
    if (ring_on) {
        int rdx = nx - ring_x;
        int rdy = ny - ring_y;
        int inside = rdx * rdx + rdy * rdy < (ring_r + 6) * (ring_r + 6);
        if (!ring_safe && !inside) {
            ring_on = 0;
            tone(880, 0.08f, 0.25f);
            part_burst(ring_x, ring_y, 12, 2.f, 20, 2, PURPLE, PART_DOT);
        } else if (ring_safe && ring_r > 22) {
            int m[] = {76, 79};
            ring_on = 0;
            star_on = 1;
            star_x = nx - 28;
            star_y = ny;
            star_life = 180;
            cab_log("chest star %d", frame);
            notes(m, 2, 0.1f, 0.3f);
            part_burst(nx, ny, 14, 2.5f, 24, 2, BLUE, PART_DOT);
            react_to("Walk over the star.");
        } else if (!ring_safe && ring_r > 26 && inside) {
            ring_on = 0;
            hurt();
        } else {
            ring_r += 1;
            if (!ring_safe && ring_r % 4 == 0)
                sfx_tone(W_SINE, 300 + ring_r * 12, 0.06f, 0.08f);
        }
    }
    if (star_on) {
        int sdx = nx - star_x;
        int sdy = ny - star_y;
        if (sdx * sdx + sdy * sdy < 22 * 22) {
            star_on = 0;
            wrap = WRAP_FRAMES;
            wrap_alive = 1;
            bubble_on = 0;
            telegraph = 0;
            cab_log("chest wrap %d", frame);
            sfx_note(W_SINE, 88, 0.4f, 0.3f);
            part_burst(star_x, star_y, 16, 2.5f, 30, 2.5f, GOLD, PART_STAR);
            react_to("The star wrapped him.");
        } else if (--star_life <= 0)
            star_on = 0;
    }
}

/* ------------------------------------------------------------------ pictures */

static const char *rest_line(void)
{
    if (cab_down(0, CAB_1P) && cab_down(0, CAB_2P))
        return "The gems will stay.";
    if (phase == POP)
        return "Pop! He threw the sword.";
    if (phase == WINBOW)
        return "Treasure for the pile.";
    if (phase == RESTART)
        return "Pop. The sword stayed.";
    if (phase == FIGHT) {
        if (telegraph > 0)
            return "A laser is coming.";
        if (wrap > 0)
            return "Gold fairy has him.";
        if (ring_on && ring_safe)
            return "A blue bubble. Catch it.";
        if (star_on)
            return "Walk over the star.";
        if (ring_on && !ring_safe)
            return "Purple. Step out of it.";
        if (face_y >= 0)
            return "Aim up. He's the boss.";
        return "Gold one. He's the boss.";
    }
    if (!has_key) {
        if (hop > 0)
            return "The lock wants the key.";
        if (cab_down(0, CAB_LEFT) || cab_down(0, CAB_RIGHT) || cab_down(0, CAB_UP) || cab_down(0, CAB_DOWN))
            return "He walks to the chest.";
        return "The key is glowing.";
    }
    return "The key is his.";
}

static void gem(float x, float y, float s, gcol c)
{
    float p[12] = {x - 7 * s, y - 2 * s, x - 4 * s, y - 7 * s, x + 4 * s, y - 7 * s, x + 7 * s, y - 2 * s, x, y + 8 * s, x, y + 8 * s};
    toon_t = 1.5f;
    for (toon_pass = 0; toon_pass < 2; toon_pass++)
        toon_poly(p, 5, c);
    gfx_tri(x - 4 * s, y - 7 * s, x, y - 2 * s, x - 7 * s, y - 2 * s, col_scale(c, 1.25f));
    gfx_line(x - 7 * s, y - 2 * s, x + 7 * s, y - 2 * s, 1, col_scale(c, 0.7f));
    gfx_circle(x - 2 * s, y - 4 * s, 1.2f * s, HEXA(0xffffff, 220));
}

static void paint_ground(void)
{
    gfx_vgrad(0, 0, W, H - BAND, HEX(0x86d683), HEX(0x6cc06a));
    for (int i = 0; i < 40; i++) {
        float x = deco[i][0], y = deco[i][1];
        int k = (int)deco[i][2];
        if (k < 3) {
            gfx_tri(x - 4, y, x - 1, y - 8, x + 1, y, HEX(0x5cb05a));
            gfx_tri(x, y, x + 3, y - 7, x + 5, y, HEX(0x5cb05a));
        } else if (k == 3) {
            for (int j = 0; j < 5; j++)
                gfx_circle(x + cosf(j * 1.257f) * 3, y + sinf(j * 1.257f) * 3, 2.5f, i % 2 ? HEX(0xffffff) : HEX(0xffb0d0));
            gfx_circle(x, y, 2, GOLD);
        } else {
            gfx_ellipse_o(x, y, 8, 5, HEX(0xa8b0b8), INK, 1.5f);
            gfx_ellipse(x - 2, y - 2, 4, 2, HEX(0xc8d0d8));
        }
    }
    /* Bushes along the sides. */
    for (int i = 0; i < 7; i++) {
        float y = 60 + i * 64;
        gfx_circle_o(-6, y, 26, HEX(0x4aa04e), INK, 2);
        gfx_circle(-2, y - 6, 12, HEX(0x5cb860));
        gfx_circle_o(W + 6, y + 30, 26, HEX(0x4aa04e), INK, 2);
        gfx_circle(W + 2, y + 24, 12, HEX(0x5cb860));
    }
    /* The path up to the chest. */
    gfx_rrect(140, 188, 104, H - BAND - 188 + 10, 30, HEX(0xead6b8));
    gfx_rrect(146, 192, 92, H - BAND - 192 + 10, 26, CREAM);
    for (int i = 0; i < 9; i++) {
        float y = 210 + i * 30;
        gfx_ellipse(160 + (i % 2) * 50, y, 10, 5, HEXA(0xd8c4a4, 140));
    }
}

static void draw_ground(void)
{
    static gsurf *bg;
    if (!bg && (bg = gfx_surf_new(W, H)) != NULL) {
        gfx_target(bg);
        paint_ground();
        gfx_target(NULL);
    }
    if (bg)
        gfx_blit(bg, 0, 0);
    else
        paint_ground();
}

static void draw_pile(void)
{
    int n = gems < 8 ? gems : 8;
    float hopy = pile_hop > 0 ? -fabsf(sinf(pile_hop * 0.3f)) * 8 : 0;
    gfx_ellipse_o(44, 44, 34, 12, HEX(0xd8a850), INK, 2);
    for (int i = 0; i < n; i++) {
        float x = 22 + (i % 4) * 14 + (i / 4) * 7, y = 40 - (i / 4) * 10 + hopy * (i == n - 1);
        gem(x, y, 1.f, i % 3 == 2 ? BLUE : ROSE);
    }
    if (gems > 8) {
        gfx_glow(44, 20, 24, HEXA(0xffe080, 160 + (int)(sinf(frame * 0.1f) * 60)));
        gfx_star(44, 20, 6, frame * 0.05f, GOLD);
    }
    if (gems > 0)
        gfx_text_o(84, 36, 1, CREAM, INK, "%d", gems);
}

static void draw_chest_box(int open)
{
    float lift = open ? 22.f : (float)hop;
    float glow = open ? 1 : 0;
    float pulse = 0.5f + 0.5f * sinf(frame * 0.12f);
    if (glow)
        gfx_glow(ZX, 160, 80, HEXA(0xffd060, 140));
    toon_t = 2.5f;
    for (toon_pass = 0; toon_pass < 2; toon_pass++) {
        toon_rrect(152, 164, 80, 36, 5, WOOD);
        if (!open)
            toon_rrect(146, 144 - lift, 92, 26, 12, HEX(0xd0904e));
        else
            toon_rrect(146, 120, 92, 14, 6, HEX(0xd0904e));
    }
    gfx_rect(152, 172, 80, 6, GOLD);
    gfx_rect(152, 188, 80, 4, HEXA(0x8a5a2a, 160));
    gfx_rect(164, 164, 6, 36, GOLD);
    gfx_rect(214, 164, 6, 36, GOLD);
    if (!open) {
        gfx_rect(146, 158 - (int)lift, 92, 5, GOLD);
        gfx_rrect_o(182, 160 - lift, 20, 20, 4, GOLD, INK, 2);
        if (!has_key || frame % 40 < 20)
            gfx_glow(ZX, 170 - lift, 12 + pulse * 6, HEXA(0xffe080, (int)(80 + pulse * 100)));
        gfx_circle(ZX, 167 - lift, 3, INK);
        gfx_tri(ZX - 2, 168 - lift, ZX + 2, 168 - lift, ZX, 175 - lift, INK);
    } else
        gfx_rect(152, 160, 80, 6, HEX(0x5a3010));
}

static void draw_key(float x, float y)
{
    float bob = sinf(frame * 0.08f) * 3;
    y += bob;
    gfx_glow(x, y - 10, 34, HEXA(0xffe080, 120 + (int)(sinf(frame * 0.1f) * 50)));
    toon_t = 2.5f;
    for (toon_pass = 0; toon_pass < 2; toon_pass++) {
        toon_rrect(x - 4, y - 16, 8, 30, 3, GOLD);
        toon_circle(x, y - 26, 12, GOLD);
        toon_rrect(x + 2, y + 2, 11, 5, 2, GOLD);
        toon_rrect(x + 2, y + 9, 8, 5, 2, GOLD);
    }
    gfx_circle(x, y - 26, 5, HEX(0x86d683));
    gfx_circle(x - 5, y - 31, 2.5f, HEXA(0xffffff, 200));
    if (frame % 20 == 0)
        part_spawn(x + rng_range(-12, 12), y - 26 + rng_range(-12, 12), 0, -0.4f, 30, 3, GOLD, PART_STAR);
}

static void spoon(float x, float y, int flash)
{
    gcol steel = flash ? WHITE : SPOON;
    toon_t = 2;
    for (toon_pass = 0; toon_pass < 2; toon_pass++) {
        toon_rrect(x - 2.5f, y - 2, 5, 36, 2, steel);
        toon_ellipse(x, y - 12, 12, 15, steel);
    }
    gfx_ellipse(x - 3, y - 15, 4, 7, HEXA(0xffffff, flash ? 255 : 170));
    if (flash)
        gfx_glow(x, y - 12, 26, HEXA(0xffffff, 200));
}

static void draw_zam(float cx, float cy, int flash, int bow)
{
    float b = bow ? 14.f : 0.f;
    float sway = sinf(frame * 0.05f) * 2;
    float stache = sinf(frame * 0.08f) * 2;
    float tap = flash ? sinf(frame * 0.8f) * 4 : 0;
    cy += b;
    toon_t = 2.5f;
    for (toon_pass = 0; toon_pass < 2; toon_pass++) {
        /* Legs and feet on the chest. */
        toon_rrect(cx - 13, cy + 34, 9, 30, 4, GOLD);
        toon_rrect(cx + 4, cy + 34, 9, 30, 4, GOLD);
        toon_rrect(cx - 18, cy + 58, 16, 8, 4, GOLD);
        toon_rrect(cx + 2, cy + 58, 16, 8, 4, GOLD);
        /* Arms up, holding the spoons. */
        toon_line(cx - 18, cy + 10, cx - 38 + sway, cy - 26 + tap, 9, GOLD);
        toon_line(cx + 18, cy + 10, cx + 38 + sway, cy - 26 - tap, 9, GOLD);
        /* Tall body, plates like a vest. */
        toon_rrect(cx - 19, cy + 2, 38, 42, 12, GOLD);
        toon_ellipse(cx - 24, cy + 8, 13, 9, BROWN);
        toon_ellipse(cx + 24, cy + 8, 13, 9, BROWN);
        toon_rrect(cx - 14, cy + 14, 28, 20, 6, BROWN);
        /* Head. */
        toon_ellipse(cx + sway * 0.3f, cy - 22, 27, 26, GOLD);
        /* A tuft of gold fur on top. */
        toon_circle(cx - 8, cy - 46, 7, GOLD);
        toon_circle(cx + 2, cy - 50, 8, GOLD);
        toon_circle(cx + 11, cy - 45, 6, GOLD);
    }
    spoon(cx - 40 + sway, cy - 40 + tap, flash);
    spoon(cx + 40 + sway, cy - 40 - tap, flash);
    gfx_rect((int)cx - 3, (int)cy + 18, 6, 12, GOLD);
    gfx_circle(cx - 8, cy + 24, 1.5f, GOLD);
    gfx_circle(cx + 8, cy + 24, 1.5f, GOLD);
    /* Narrow eyes, a happy brow. */
    {
        float hx = cx + sway * 0.3f;
        if (bow) {
            gfx_line(hx - 15, cy - 26, hx - 6, cy - 26, 3, INK);
            gfx_line(hx + 6, cy - 26, hx + 15, cy - 26, 3, INK);
        } else {
            gfx_ellipse(hx - 10, cy - 27, 6, 3.5f, WHITE);
            gfx_ellipse(hx + 10, cy - 27, 6, 3.5f, WHITE);
            gfx_circle(hx - 9 + (nx - cx) * 0.02f, cy - 27, 2.2f, INK);
            gfx_circle(hx + 11 + (nx - cx) * 0.02f, cy - 27, 2.2f, INK);
            gfx_line(hx - 16, cy - 34, hx - 4, cy - 32, 2.5f, BROWN);
            gfx_line(hx + 4, cy - 32, hx + 16, cy - 34, 2.5f, BROWN);
        }
        gfx_ellipse(hx, cy - 18, 5, 4, HEX(0xd89a2a));
        /* The mustache: the widest thing on him, curled at both ends. */
        toon_t = 2;
        for (toon_pass = 0; toon_pass < 2; toon_pass++) {
            for (int side = -1; side <= 1; side += 2) {
                float p[] = {hx, cy - 14, hx + side * 22, cy - 12 + stache, hx + side * 46, cy - 6 + stache,
                             hx + side * 66, cy + 4 + stache * 1.5f, hx + side * 64, cy + 10 + stache,
                             hx + side * 44, cy + 2, hx + side * 20, cy - 4, hx, cy - 8};
                toon_poly(p, 8, BROWN);
                toon_circle(hx + side * 70, cy + 14 + stache * 1.5f, 8, BROWN);
            }
        }
        gfx_circle(hx + 70, cy + 14 + stache * 1.5f, 3, HEX(0x7a4a2a));
        gfx_circle(hx - 70, cy + 14 + stache * 1.5f, 3, HEX(0x7a4a2a));
        gfx_line(hx - 4, cy - 1, hx + 4, cy - 1, 2, HEX(0x7a4a2a));
    }
    /* Marks so far: nine little lights over his head. */
    if (phase == FIGHT || phase == WINBOW) {
        for (int i = 0; i < MARKS_WIN; i++) {
            float x = cx - 48 + i * 12, y = cy - 76;
            gfx_circle(x, y, 4.5f, INK);
            gfx_circle(x, y, 3.2f, i < marks ? GOLD : HEX(0x5a4a6a));
            if (i < marks)
                gfx_glow(x, y, 8, HEXA(0xffe080, 100));
        }
    }
}

static void draw_ned(void)
{
    int sword = has_sword && phase != PATH && phase != POP;
    float step = moving ? sinf(walk_t * 0.35f) : 0;
    float x = (float)nx, y = (float)ny;
    float fx = (float)face_x, fy = (float)(face_x == 0 && face_y == 0 ? -1 : face_y);
    int blink = frame % 160 < 6;
    if (hurt_cool > 0 && (hurt_cool / 4) % 2)
        return;
    gfx_ellipse(x, y + 34, 16, 5, HEXA(0x2a5a2a, 110));
    toon_t = 2.5f;
    for (toon_pass = 0; toon_pass < 2; toon_pass++) {
        /* Cape behind, trailing the way he walks. */
        {
            float p[] = {x - 13, y + 2, x + 13, y + 2, x + 17 - fx * 6, y + 30 + fabsf(step) * 2, x - 17 - fx * 6,
                         y + 30 + fabsf(step) * 2};
            toon_poly(p, 4, CAPE);
        }
        toon_rrect(x - 9 + step * 2, y + 20, 7, 14, 3, HEX(0x5a4a6a));
        toon_rrect(x + 2 - step * 2, y + 20, 7, 14, 3, HEX(0x5a4a6a));
        toon_rrect(x - 10, y + 2, 20, 22, 7, HEX(0x5a8ac8));
        toon_circle(x, y - 10, 15, SKIN);
        /* Round helmet. */
        toon_ellipse(x, y - 18, 17, 11, HELM);
    }
    gfx_rect((int)x - 17, (int)y - 17, 34, 3, HEX(0x9aa4b8));
    gfx_ellipse(x - 6, y - 22, 5, 3, HEXA(0xffffff, 200));
    gfx_circle(x, y - 30, 3, ROSE);
    if (fy < 0 && fx == 0) {
        /* Facing the chest: the back of his head. */
        gfx_ellipse(x, y - 6, 12, 7, HEX(0xb07a50));
    } else {
        float ex = fx * 4;
        if (blink) {
            gfx_line(x - 6 + ex, y - 8, x - 2 + ex, y - 8, 2, INK);
            gfx_line(x + 2 + ex, y - 8, x + 6 + ex, y - 8, 2, INK);
        } else {
            gfx_circle(x - 4 + ex, y - 8, 2.2f, INK);
            gfx_circle(x + 4 + ex, y - 8, 2.2f, INK);
        }
        gfx_ellipse(x - 8 + ex, y - 3, 3, 2, HEXA(0xff8fa0, 120));
        gfx_ellipse(x + 8 + ex, y - 3, 3, 2, HEXA(0xff8fa0, 120));
        gfx_line(x - 3 + ex, y - 2, x + 3 + ex, y - 2, 1.5f, INK);
    }
    if (has_key && !sword && phase == PATH) {
        gfx_glow(x + 14, y + 4, 12, HEXA(0xffe080, 120));
        gfx_rrect_o(x + 12, y - 2, 5, 14, 2, GOLD, INK, 1.5f);
        gfx_circle_o(x + 14.5f, y - 4, 4.5f, GOLD, INK, 1.5f);
    }
    if (sword || (phase == POP && pop_t > 20)) {
        float sx = x + fx * 18 + (fx == 0 ? 14 : 0), sy = y - 4 + fy * 10;
        float tx = sx + fx * 26, ty = sy + fy * 26;
        if (fx != 0 && fy != 0) {
            tx = sx + fx * 18;
            ty = sy + fy * 18;
        }
        gfx_line(sx, sy, tx, ty, 9, INK);
        gfx_line(sx, sy, tx, ty, 5, GOLD);
        gfx_line(sx - fy * 7, sy + fx * 7, sx + fy * 7, sy - fx * 7, 6, INK);
        gfx_line(sx - fy * 6, sy + fx * 6, sx + fy * 6, sy - fx * 6, 3.5f, BROWN);
        gfx_glow(tx, ty, 10, HEXA(0xffe080, 120));
    }
    if (phase == FIGHT || phase == RESTART || phase == WINBOW)
        for (int i = 0; i < 3; i++) {
            float px = x - 16 + i * 16, py = y - 46;
            gfx_circle(px, py, 6, INK);
            gfx_circle(px, py, 4.5f, i < pips ? ROSE : HEXA(0xfff6ea, 230));
            gfx_circle(px - 1.5f, py - 1.5f, 1.4f, HEXA(0xffffff, 200));
        }
}

static void draw_fairy(float x, float y, gcol c, int full)
{
    float wing = fabsf(sinf(frame * 0.5f)) * 5;
    gfx_glow(x, y, 22, col_alpha(c, 120));
    gfx_ellipse(x - 10, y - 4, 7, 4 + wing, HEXA(0xffffff, 200));
    gfx_ellipse(x + 10, y - 4, 7, 4 + wing, HEXA(0xffffff, 200));
    gfx_circle_o(x, y, 8, c, INK, 2);
    gfx_circle(x - 2.5f, y - 1, 1.3f, INK);
    gfx_circle(x + 2.5f, y - 1, 1.3f, INK);
    if (full)
        gfx_star(x, y + 10, 5, frame * 0.1f, GOLD);
    if (frame % 3 == 0)
        part_spawn(x, y + 6, rng_range(-0.3f, 0.3f), 0.5f, 20, 2, col_alpha(c, 200), PART_GLOW);
}

static void bubble(float x, float y, float r, gcol c, int fill)
{
    float wob = sinf(frame * 0.2f) * 0.06f;
    if (fill)
        gfx_ellipse(x, y, r * (1 + wob), r * (1 - wob), col_alpha(c, 70));
    gfx_ring(x, y, r, 3, col_alpha(c, 230));
    gfx_ellipse(x - r * 0.4f, y - r * 0.45f, r * 0.22f, r * 0.12f, HEXA(0xffffff, 200));
}

static void draw(void)
{
    const char *line;
    int open = phase != PATH;
    int flash = spoon_flash > 0 || telegraph > 0;
    draw_ground();
    draw_pile();
    draw_chest_box(open);
    if (!has_key)
        draw_key(KEY_X, KEY_Y);
    if (phase == POP) {
        float k = ease_out_back(clampf((float)pop_t / POP_FRAMES, 0, 1));
        draw_zam(ZX, 150 - 32 * k, flash, 0);
        if (pop_t > 4 && pop_t < 30) {
            /* The sword arcs into his hand. */
            float t = (pop_t - 4) / 26.f;
            float sx = lerpf(ZX + 40, nx, t), sy = lerpf(ZY - 40, ny - 10, t) - sinf(t * 3.14159f) * 80;
            gfx_glow(sx, sy, 16, HEXA(0xffe080, 200));
            gfx_star(sx, sy, 8, frame * 0.4f, GOLD);
        }
    } else if (phase == FIGHT || phase == WINBOW || phase == RESTART)
        draw_zam(ZX, ZY, flash, phase == WINBOW || phase == RESTART);
    if (telegraph > 0)
        gfx_glow(nx, ny, 26 + (30 - telegraph), HEXA(0x7a5af5, 90));
    if (wrap > 0)
        bubble(ZX, ZY, 70 + sinf(frame * 0.15f) * 3, GOLD, 1);
    if (star_on) {
        gfx_glow(star_x, star_y, 22, HEXA(0xffe080, 160));
        gfx_star(star_x, star_y, 11, frame * 0.05f, INK);
        gfx_star(star_x, star_y, 9, frame * 0.05f, GOLD);
    }
    draw_ned();
    if (ring_on) {
        bubble(ring_x, ring_y, ring_r + 14, ring_safe ? BLUE : PURPLE, 1);
        if (ring_safe)
            gfx_star(ring_x, ring_y - 4, 7, frame * 0.1f, GOLD);
        if (!ring_safe) {
            float k = clampf((ring_r - 8) / 18.f, 0, 1);
            gfx_ring(ring_x, ring_y, 40, 2, col_alpha(PURPLE, (int)(60 + k * 160)));
        }
    }
    if (fairy != FAIRY_NONE)
        draw_fairy(fairy_x, fairy_y, fairy == FAIRY_GOLD ? GOLD : fairy == FAIRY_BLUE ? BLUE : PURPLE, fairy == FAIRY_BLUE);
    if (bubble_on)
        bubble(bx, by, 13, PURPLE, 1);
    if (beam_t > 0) {
        float k = beam_t / 10.f;
        int sw = has_sword;
        gfx_line(beam_x0, beam_y0, beam_x1, beam_y1, (sw ? 10 : 6) * k + 2, col_alpha(GOLD, (int)(160 * k)));
        gfx_line(beam_x0, beam_y0, beam_x1, beam_y1, (sw ? 4 : 2.5f) * k + 1, col_alpha(WHITE, (int)(255 * k)));
        gfx_glow(beam_x1, beam_y1, 18 * k + 4, HEXA(0xffe080, 200));
        beam_t--;
    }
    part_update();
    part_draw();
    if (react_left)
        line = react;
    else
        line = rest_line();
    gfx_rect(0, H - BAND, W, BAND, CREAM);
    gfx_rect(0, H - BAND, W, 2, HEXA(0x3a2a44, 60));
    gfx_text_c(W / 2, H - BAND + 9, 2, INK, HEXA(0, 0), "%s", line);
    say(line);
    gfx_present();
}

/* ------------------------------------------------------------------ autoplay (tests, the reel) */

static void bot(void)
{
    int tx = nx, ty = ny, settled;
    cab_bot_clear();
    if (phase == PATH) {
        tx = has_key ? ZX : KEY_X;
        ty = has_key ? 240 : KEY_Y;
    } else if (phase == FIGHT) {
        /* Two posts under Zam, a dodge for the bubble, out of a purple ring, onto a star. */
        tx = sinf(frame * 0.012f) > 0 ? 140 : 244;
        ty = 400;
        if (star_on) {
            tx = star_x;
            ty = star_y;
        }
        if (ring_on && !ring_safe) {
            tx = ring_x + (ring_x < ZX ? 80 : -80);
            ty = ring_y;
        }
        if (bubble_on && fabsf(bx - nx) < 50 && by < ny)
            tx = nx + (bx < nx ? 60 : -60);
    } else
        return;
    settled = abs(tx - nx) < 6 && abs(ty - ny) < 6;
    if (!settled) {
        if (tx < nx - 2)
            cab_bot(CAB_LEFT, 1);
        if (tx > nx + 2)
            cab_bot(CAB_RIGHT, 1);
        if (ty < ny - 2)
            cab_bot(CAB_UP, 1);
        if (ty > ny + 2)
            cab_bot(CAB_DOWN, 1);
    } else if (phase == FIGHT) {
        /* Face Zam with a tap of up, then shoot. */
        if (face_y >= 0 || face_x != 0)
            cab_bot(CAB_UP, 1);
        else if (frame % 2)
            cab_bot(CAB_LOW, 1);
    }
}

int main(int argc, char **argv)
{
    int autoplay = getenv("CAB_AUTOPLAY") != NULL;
    (void)argc;
    (void)argv;
    if (gfx_init("Chest", W, H) != 0)
        return 1;
    sfx_init();
    sfx_master(0.17f);
    sfx_limit(3000);
    rng_seed_auto();
    load_gems();
    cab_log("chest gems %d", gems);
    for (int i = 0; i < 40; i++) {
        float x;
        do
            x = rng_range(16, W - 16);
        while (x > 128 && x < 256);
        deco[i][0] = x;
        deco[i][1] = rng_range(70, H - BAND - 8);
        deco[i][2] = (float)rng_int(0, 4);
    }
    music_play(&path_bed);
    nx = 200;
    ny = 420;
    face_x = 0;
    face_y = -1;
    while (cab_poll()) {
        int pressed, held, mx = 0, my = 0;
        if (autoplay)
            bot();
        pressed = cab_pressed(0, CAB_LOW) || cab_pressed(0, CAB_TL) || cab_pressed(0, CAB_TR);
        held = cab_down(0, CAB_LOW) || cab_down(0, CAB_TL) || cab_down(0, CAB_TR);
        bolt_on = 0;
        splash_on = 0;
        if (!held)
            saw_release = 1;
        if (cab_down(0, CAB_LEFT))
            mx--;
        if (cab_down(0, CAB_RIGHT))
            mx++;
        if (cab_down(0, CAB_UP))
            my--;
        if (cab_down(0, CAB_DOWN))
            my++;
        moving = 0;
        if (phase != WINBOW && phase != RESTART) {
            nx += mx * SPEED;
            ny += my * SPEED;
            if (nx < 24)
                nx = 24;
            if (nx > W - 24)
                nx = W - 24;
            if (ny < 230)
                ny = 230;
            if (ny > 450)
                ny = 450;
            if (mx || my) {
                moving = 1;
                walk_t++;
                face_x = mx;
                face_y = my;
                if (mx && my) {
                    face_x = 0;
                    face_y = my;
                }
                if (walk_t % 16 == 0)
                    part_spawn(nx, ny + 32, rng_range(-0.5f, 0.5f), -0.3f, 18, 2.5f, HEXA(0xe8f0d0, 160), PART_DOT);
            }
        }
        if (!has_key && near_key())
            take_key();
        if (phase == PATH && near_chest()) {
            if (has_key)
                begin_pop();
            else if (hop == 0) {
                hop = 10;
                tone(330, 0.1f, 0.25f);
                react_to("The lock wants the key.");
            }
        }
        if (shot_cool > 0)
            shot_cool--;
        if (saw_release && (pressed || (held && shot_cool == 0))) {
            fire();
            shot_cool = SHOT_GAP;
        }
        if (phase == POP) {
            if (++pop_t >= POP_FRAMES) {
                phase = FIGHT;
                has_sword = 1;
                clear_fight();
                cab_log("chest sword %d", frame);
            }
        } else if (phase == FIGHT)
            fight_step();
        else if (phase == WINBOW) {
            if (++bow_t >= WIN_FRAMES) {
                phase = PATH;
                has_key = 0;
                has_sword = 0;
                clear_fight();
                react_left = REACT_FRAMES;
                snprintf(react, sizeof react, "%s", "The key is back. Go on.");
            }
        } else if (phase == RESTART) {
            if (++bow_t >= RESTART_FRAMES) {
                phase = FIGHT;
                has_sword = 1;
                clear_fight();
            }
        }
        if (hop > 0)
            hop--;
        if (pile_hop > 0)
            pile_hop--;
        if (react_left > 0)
            react_left--;
        if (cab_down(0, CAB_1P) && cab_down(0, CAB_2P) && !goodbye_played) {
            int m[] = {79, 76};
            notes(m, 2, 0.16f, 0.3f);
            goodbye_played = 1;
        }
        draw();
        frame++;
    }
    cab_shutdown();
    return 0;
}
