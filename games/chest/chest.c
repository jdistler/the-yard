/* Chest: walk to the key, open the chest, take the sword, duel Zam.
 * Walk-up band (CONTROLS.md). The stick walks. LOW shoots. TL and TR shoot too.
 * In the fight the sword points at Zam by itself, so every shot flies at him and the
 * stick is for dodging, for stars, and for stepping out of purple rings.
 * Zam learns a new trick as the pile grows: a teleport, a shield, three bubbles at once.
 * Upright 384x512. A grown-up reads the cream band. chest.sav is "gems N".
 * The spec is DESIGN.md beside this file.
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
#define POP_FRAMES 60
#define WRAP_FRAMES 120
#define REACT_FRAMES 120
#define WIN_FRAMES 160
#define RESTART_FRAMES 60
#define SHOT_GAP 12
#define HOLD_GAP 30
#define MARKS_WIN 9
#define ZX 192
#define ZY 118
#define FIGHT_TOP 300
#define TELE_FRAMES 40
#define SHIELD_FRAMES 90
#define MAXB 3
#define PILE_SHOWN 15

enum { PATH, POP, FIGHT, WINBOW, RESTART };
enum { FAIRY_NONE, FAIRY_GOLD, FAIRY_BLUE, FAIRY_PURPLE };

static const gcol CREAM = HEX(0xfff6ea), INK = HEX(0x3a2a44), CAPE = HEX(0x3a6ea5), SKIN = HEX(0xf4c7a1),
                  GOLD = HEX(0xf2c14e), WOOD = HEX(0xc4844a), BROWN = HEX(0x8a5a32), SPOON = HEX(0xbabec8),
                  BLUE = HEX(0x6eb5ff), PURPLE = HEX(0x7a5af5), ROSE = HEX(0xe86b9a), WHITE = HEX(0xfffcf8),
                  HELM = HEX(0xc8d0e0), FUR = HEX(0xf2c14e), FUR_DARK = HEX(0xd89a2a), CYAN = HEX(0x7fe8ff);

static int phase, frame, gems, marks, pips, level, marks_win = 9;
static int nx, ny, face_x, face_y, has_key, has_sword, key_x = 128, key_y = 348;
static int pop_t, bow_t, fight_t, hop, react_left, shot_cool, saw_release;
static int telegraph, spray;
static int fairy, fairy_x, fairy_y, wrap, wrap_alive;
static int ring_on, ring_x, ring_y, ring_r, ring_safe;
static int star_on, star_x, star_y, star_life;
static int splash_on, splash_x, splash_y;
static int hurt_cool, shot_once, spoon_flash, goodbye_played;
static char react[48], shown[48];
/* Zam: where he hovers, where he is going, his shield, his flinch. */
static float zx = ZX, zy = ZY;
static int spot = 1, tele_t, tele_to, shield_t, flinch_t, dizzy_t, bend_t;
/* Bubbles from the spoons. */
static int b_on[MAXB];
static float b_x[MAXB], b_y[MAXB], b_vx[MAXB], b_vy[MAXB];
/* Pictures only. */
static int beam_t, beam_x0, beam_y0, beam_x1, beam_y1, beam_blocked, walk_t, pile_hop, moving, prize_t, prize_kind;
static float deco[40][3];

static const int spots[3] = {128, 192, 256};
static const int key_spots[5][2] = {{128, 348}, {300, 356}, {72, 268}, {318, 270}, {84, 420}};

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
    int dx = nx - key_x, dy = ny - key_y;
    return dx * dx + dy * dy < 36 * 36;
}

/* Zam can be hit when he is all there: not mid-teleport. */
static int zam_solid(void) { return tele_t == 0 || tele_t > TELE_FRAMES - 4; }

static void clear_fight(void)
{
    marks = 0;
    pips = 0;
    fight_t = 0;
    telegraph = 0;
    spray = 0;
    memset(b_on, 0, sizeof b_on);
    fairy = FAIRY_NONE;
    wrap = 0;
    wrap_alive = 0;
    ring_on = 0;
    star_on = 0;
    star_life = 0;
    shot_once = 0;
    hurt_cool = 0;
    tele_t = 0;
    shield_t = 0;
    spot = 1;
    zx = ZX;
    /* He learns a trick for each of the first three gems, and takes three more zaps each time. */
    level = gems < 3 ? gems : 3;
    marks_win = MARKS_WIN + 3 * level;
}

static void take_key(void)
{
    has_key = 1;
    cab_log("chest key %d", frame);
    sfx_note(W_TRI, 84, 0.3f, 0.35f);
    sfx_note(W_SINE, 96, 0.2f, 0.15f);
    part_burst(key_x, key_y - 20, 18, 2.5f, 34, 2.5f, GOLD, PART_STAR);
    react_to("The key is his.");
}

static void begin_pop(void)
{
    if (phase != PATH || !has_key)
        return;
    phase = POP;
    react_left = 0;
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
    react_left = 80;
}

static void begin_win(void)
{
    phase = WINBOW;
    bow_t = 0;
    prize_kind = gems % 8;
    prize_t = 1;
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
        gpart *p = part_spawn(zx + rng_range(-40, 40), zy, rng_range(-3, 3), rng_range(-5, -1), 70, rng_range(3, 5),
                              i % 3 ? ROSE : GOLD, i % 2 ? PART_STAR : PART_SQUARE);
        p->grav = 0.15f;
        p->drag = 0.99f;
        p->spin = 0.1f;
    }
    memset(b_on, 0, sizeof b_on);
    tele_t = 0;
    shield_t = 0;
    ring_on = 0;
    star_on = 0;
    fairy = FAIRY_NONE;
    music_play(&path_bed);
    react_to("Treasure for the pile.");
}

static void add_marks(int n, int big)
{
    marks += n;
    spoon_flash = 16;
    flinch_t = 14;
    if (big) {
        int m[] = {79, 84};
        cab_log("chest big");
        notes(m, 2, 0.07f, 0.4f);
        gfx_shake(5);
        dizzy_t = 70;
        part_burst(zx, zy, 34, 4.f, 40, 3, GOLD, PART_STAR);
        part_text(zx, zy - 80, GOLD, "+3");
        react_to("The big bubble popped.");
    } else {
        cab_log("chest mark %d", marks);
        sfx_slide(W_SQUARE, 900, 600, 0.08f, 0.18f);
        part_burst(zx, zy - 10, 10, 2.f, 24, 2, CREAM, PART_STAR);
        react_to("The sword zapped him.");
    }
    if (marks >= marks_win && phase == FIGHT)
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

/* Before the sword: a short spark the way he faces, which can also tap the key and the lock. */
static void spark(void)
{
    int x = nx, y = ny - 8, dx = face_x, dy = face_y;
    if (dx == 0 && dy == 0)
        dy = -1;
    cab_log("chest bolt");
    sfx_tone(W_SINE, 1300, 0.07f, 0.2f);
    beam_x0 = x;
    beam_y0 = y;
    for (int i = 0; i < 52; i++) {
        x += dx;
        y += dy;
        if (!has_key && (x - key_x) * (x - key_x) + (y - key_y) * (y - key_y) < 30 * 30)
            take_key();
        if (has_key && phase == PATH && y < 268 && x > 156 && x < 236)
            begin_pop();
    }
    beam_x1 = x;
    beam_y1 = y;
    beam_t = 7;
    beam_blocked = 0;
}

/* With the sword: a laser that flies at Zam. A shield stops it, an empty spot lets it pass. */
static void laser(void)
{
    float sx = nx, sy = ny - 12;
    cab_log("chest bolt");
    sfx_slide(W_SQUARE, 1400, 500, 0.12f, 0.16f);
    beam_x0 = (int)sx;
    beam_y0 = (int)sy;
    beam_t = 10;
    beam_blocked = 0;
    shot_once = 1;
    if (phase != FIGHT) {
        beam_x1 = (int)zx;
        beam_y1 = (int)zy;
        return;
    }
    if (!zam_solid()) {
        /* He is not there: the laser flies on to the top of the meadow. */
        beam_x1 = (int)(sx + (zx - sx) * 1.6f);
        beam_y1 = 8;
        splash_on = 1;
        splash_x = beam_x1;
        splash_y = beam_y1;
        return;
    }
    if (shield_t > 0 && wrap == 0) {
        float k = (sy - (zy + 62)) / (sy - zy);
        beam_x1 = (int)(sx + (zx - sx) * k);
        beam_y1 = (int)(zy + 62);
        beam_blocked = 1;
        splash_on = 1;
        splash_x = beam_x1;
        splash_y = beam_y1;
        sfx_note(W_SINE, 100, 0.15f, 0.2f);
        react_to("His shield is up. Wait.");
        cab_log("chest blocked");
        return;
    }
    beam_x1 = (int)zx;
    beam_y1 = (int)zy;
    if (wrap > 0) {
        wrap = 0;
        wrap_alive = 0;
        add_marks(3, 1);
    } else
        add_marks(1, 0);
}

static void fire(void)
{
    if (has_sword && phase != PATH)
        laser();
    else
        spark();
    if (splash_on)
        part_burst(splash_x, splash_y, 8, 2.f, 18, 2, beam_blocked ? CYAN : CREAM, PART_DOT);
}

static void spawn_bubbles(void)
{
    int n = spray ? 3 : 1;
    for (int k = 0; k < n && k < MAXB; k++) {
        float bx = zx + (k - (n - 1) / 2.f) * 30, by = zy - 30;
        float dx = (float)nx - bx, dy = (float)ny - by, mag, a;
        mag = sqrtf(dx * dx + dy * dy);
        if (mag < 1)
            mag = 1;
        a = atan2f(dy, dx) + (k - (n - 1) / 2.f) * 0.38f;
        b_on[k] = 1;
        b_x[k] = bx;
        b_y[k] = by;
        b_vx[k] = cosf(a) * 2.3f;
        b_vy[k] = sinf(a) * 2.3f;
    }
    sfx_slide(W_SINE, 500, 300, 0.2f, 0.2f);
}

static void begin_teleport(void)
{
    int to;
    do
        to = rng_int(0, 2);
    while (to == spot);
    tele_t = TELE_FRAMES;
    tele_to = to;
    sfx_slide(W_SINE, 400, 1600, 0.25f, 0.2f);
    react_to("Zam jumped! Find him.");
    cab_log("chest teleport %d", to);
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
    /* His rhythm, from the second fight on, every five seconds: the spoons glow and the
     * bubbles come (he is open), then his shield goes up (zaps bounce off), then he
     * teleports. On the first fight there is only a bubble every two and a half seconds. */
    {
        int len = level == 0 ? 150 : 300, c = fight_t % len;
        if (tele_t > 0) {
            if (--tele_t == TELE_FRAMES / 2) {
                spot = tele_to;
                zx = spots[spot];
                part_burst(zx, zy, 16, 2.f, 26, 2.5f, HEX(0xc8a8ff), PART_STAR);
            }
        } else if (level >= 1 && c == (level >= 2 ? 250 : 180) && wrap == 0)
            begin_teleport();
        if (shield_t > 0) {
            if (--shield_t == 0 || wrap > 0)
                shield_t = 0;
        } else if (level >= 2 && c == 150 && wrap == 0 && tele_t == 0) {
            shield_t = SHIELD_FRAMES;
            sfx_note(W_SINE, 88, 0.3f, 0.25f);
            sfx_note(W_SINE, 95, 0.3f, 0.12f);
            react_to("His shield is up. Wait.");
            cab_log("chest shield");
        }
        if (telegraph > 0) {
            if (--telegraph == 0)
                spawn_bubbles();
        } else if (wrap == 0 && fairy == FAIRY_NONE && tele_t == 0 && c == 40) {
            telegraph = 30;
            spray = level >= 3 && (fight_t / len) % 2 == 1;
            tone(spray ? 587 : 659, 0.12f, 0.2f);
            if (spray)
                react_to("Three bubbles! Step away.");
        }
    }
    for (int k = 0; k < MAXB; k++) {
        float dxb, dyb;
        if (!b_on[k])
            continue;
        b_x[k] += b_vx[k];
        b_y[k] += b_vy[k];
        dxb = b_x[k] - (float)nx;
        dyb = b_y[k] - (float)ny;
        if (dxb * dxb + dyb * dyb < 28.f * 28.f) {
            b_on[k] = 0;
            hurt();
        } else if (b_y[k] > H - 40 || b_x[k] < 0 || b_x[k] > W)
            b_on[k] = 0;
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
        dx = (int)zx - fairy_x;
        dy = (int)zy + 12 - fairy_y;
        fairy_x += dx > 4 ? 4 : dx < -4 ? -4 : dx;
        fairy_y += dy > 4 ? 4 : dy < -4 ? -4 : dy;
        if (abs(dx) < 12 && abs(dy) < 12 && zam_solid()) {
            fairy = FAIRY_NONE;
            wrap = WRAP_FRAMES;
            wrap_alive = 1;
            memset(b_on, 0, sizeof b_on);
            telegraph = 0;
            shield_t = 0;
            cab_log("chest wrap %d", frame);
            sfx_note(W_SINE, 88, 0.4f, 0.3f);
            part_burst(zx, zy, 16, 2.5f, 30, 2.5f, GOLD, PART_GLOW);
            react_to("Gold fairy has him.");
        }
    } else if (fairy == FAIRY_BLUE || fairy == FAIRY_PURPLE) {
        dx = nx - fairy_x;
        dy = ny - fairy_y;
        fairy_x += dx > 3 ? 3 : dx < -3 ? -3 : dx;
        fairy_y += dy > 3 ? 3 : dy < -3 ? -3 : dy;
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
        int rdx = nx - ring_x, rdy = ny - ring_y;
        int inside = rdx * rdx + rdy * rdy < (ring_r + 6) * (ring_r + 6);
        if (!ring_safe && !inside) {
            ring_on = 0;
            tone(880, 0.08f, 0.25f);
            part_burst(ring_x, ring_y, 12, 2.f, 20, 2, PURPLE, PART_DOT);
        } else if (ring_safe && ring_r > 22) {
            int m[] = {76, 79};
            ring_on = 0;
            star_on = 1;
            star_x = nx < 60 ? nx + 28 : nx - 28;
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
        int sdx = nx - star_x, sdy = ny - star_y;
        if (sdx * sdx + sdy * sdy < 22 * 22) {
            star_on = 0;
            wrap = WRAP_FRAMES;
            wrap_alive = 1;
            memset(b_on, 0, sizeof b_on);
            telegraph = 0;
            shield_t = 0;
            tele_t = 0;
            cab_log("chest wrap %d", frame);
            sfx_note(W_SINE, 88, 0.4f, 0.3f);
            part_burst(star_x, star_y, 16, 2.5f, 30, 2.5f, GOLD, PART_STAR);
            react_to("The star wrapped him.");
        } else if (--star_life <= 0)
            star_on = 0;
    }
}

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
        if (tele_t > 0)
            return "Zam jumped! Find him.";
        if (telegraph > 0)
            return spray ? "Three bubbles! Step away." : "A bubble is coming.";
        if (wrap > 0)
            return "Gold fairy has him.";
        if (shield_t > 0)
            return "His shield is up. Wait.";
        if (ring_on && ring_safe)
            return "A blue bubble. Catch it.";
        if (star_on)
            return "Walk over the star.";
        if (ring_on && !ring_safe)
            return "Purple. Step out of it.";
        if (!shot_once)
            return "The sword can zap him.";
        return "Gold one. He's the boss.";
    }
    if (!has_key) {
        if (hop > 0)
            return "The lock wants the key.";
        if (cab_down(0, CAB_LEFT) || cab_down(0, CAB_RIGHT) || cab_down(0, CAB_UP) || cab_down(0, CAB_DOWN))
            return "He walks to the key.";
        return "The key is glowing.";
    }
    return "Now walk to the chest.";
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

static void draw_chest_box(int open)
{
    float lift = open ? 22.f : (float)hop;
    float glow = open ? 1 : 0;
    float pulse = 0.5f + 0.5f * sinf(frame * 0.12f);
    if (glow)
        gfx_glow(ZX, 160, 56, HEXA(0xffd060, 150));
    toon_t = 2.5f;
    for (toon_pass = 0; toon_pass < 2; toon_pass++) {
        toon_rrect(152, 164, 80, 36, 5, WOOD);
        if (!open)
            toon_rrect(146, 144 - lift, 92, 26, 12, HEX(0xd0904e));
        else
            toon_rrect(146, 132, 92, 34, 10, HEX(0xd0904e));
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
    } else {
        /* The lid stands open behind the box: its dark inside faces us. */
        gfx_rrect(152, 138, 80, 24, 7, HEX(0x6a3a18));
        gfx_rect(146, 132, 92, 4, GOLD);
        gfx_rect(152, 160, 80, 6, HEX(0x5a3010));
    }
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

/* ------------------------------------------------------------------ pictures */

/* The treasure: a different thing for each win, in this order, then round again. */
static void treasure(int kind, float x, float y, float s)
{
    static const gcol gemc[] = {0xffe86b9a, 0xff6eb5ff, 0, 0xff6fd38a, 0xffa98bff};
    toon_t = 1.5f;
    switch (kind) {
    case 2: /* a gold coin */
        gfx_circle_o(x, y, 7 * s, GOLD, INK, 1.5f);
        gfx_circle(x, y, 4.5f * s, HEX(0xffd86a));
        gfx_rect((int)(x - 1 * s), (int)(y - 3 * s), (int)(2 * s) + 1, (int)(6 * s), HEX(0xd89a2a));
        break;
    case 5: /* a ring */
        gfx_ring(x, y + 2 * s, 5.5f * s, 3 * s, INK);
        gfx_ring(x, y + 2 * s, 5.5f * s, 1.8f * s, GOLD);
        gfx_circle_o(x, y - 4 * s, 3 * s, CYAN, INK, 1.2f);
        break;
    case 6: { /* a crown */
        float p[] = {x - 8 * s, y + 5 * s, x - 8 * s, y - 4 * s, x - 4 * s, y, x, y - 7 * s, x + 4 * s, y, x + 8 * s, y - 4 * s, x + 8 * s, y + 5 * s};
        for (toon_pass = 0; toon_pass < 2; toon_pass++)
            toon_poly(p, 7, GOLD);
        gfx_circle(x, y + 1 * s, 1.6f * s, ROSE);
        break;
    }
    case 7: /* a golden spoon, like Zam's */
        gfx_line(x - 5 * s, y + 7 * s, x + 2 * s, y - 1 * s, 3.5f * s, INK);
        gfx_line(x - 5 * s, y + 7 * s, x + 2 * s, y - 1 * s, 2 * s, GOLD);
        gfx_ellipse_o(x + 4 * s, y - 4 * s, 4 * s, 5 * s, GOLD, INK, 1.2f);
        break;
    default: { /* a gem */
        gcol c = gemc[kind];
        float p[10] = {x - 7 * s, y - 2 * s, x - 4 * s, y - 7 * s, x + 4 * s, y - 7 * s, x + 7 * s, y - 2 * s, x, y + 8 * s};
        for (toon_pass = 0; toon_pass < 2; toon_pass++)
            toon_poly(p, 5, c);
        gfx_tri(x - 4 * s, y - 7 * s, x, y - 2 * s, x - 7 * s, y - 2 * s, col_scale(c, 1.25f));
        gfx_line(x - 7 * s, y - 2 * s, x + 7 * s, y - 2 * s, 1, col_scale(c, 0.7f));
        gfx_circle(x - 2 * s, y - 4 * s, 1.2f * s, HEXA(0xffffff, 220));
    }
    }
}

static void pile_slot(int i, float *x, float *y)
{
    /* A mound: five along the bottom, then four, three, two, one. */
    static const int rows[5] = {5, 4, 3, 2, 1};
    int r = 0, k = i;
    while (r < 4 && k >= rows[r]) {
        k -= rows[r];
        r++;
    }
    *x = 22 + r * 7 + k * 14;
    *y = 56 - r * 10;
}

static void draw_pile(void)
{
    int n = gems < PILE_SHOWN ? gems : PILE_SHOWN;
    float hopy = pile_hop > 0 ? -fabsf(sinf(pile_hop * 0.3f)) * 6 : 0;
    gfx_ellipse_o(50, 62, 42, 9, HEX(0xd8a850), INK, 2);
    for (int i = 0; i < n; i++) {
        float x, y;
        if (prize_t > 0 && i == n - 1)
            break;
        pile_slot(i, &x, &y);
        treasure(i % 8, x, y + (i == n - 1 ? hopy : 0), 1.f);
    }
    if (gems > PILE_SHOWN) {
        gfx_glow(50, 8, 20, HEXA(0xffe080, 150 + (int)(sinf(frame * 0.1f) * 60)));
        gfx_star(50, 8, 6, frame * 0.05f, GOLD);
    }
    if (gems > 0)
        gfx_text_o(96, 50, 1, CREAM, INK, "%d", gems);
}

/* Zam: tall and gold, with long pointed ears, a long mustache, brown armor, and a spoon
 * in each hand. He hovers. Drawn as a tribute to the psychic he is based on. */
static void draw_zam(float cx, float cy, int flash, int bow)
{
    float b = bow ? 12.f : 0.f;
    float bob = sinf(frame * 0.06f) * 4;
    float sway = sinf(frame * 0.05f) * 2;
    float tap = flash ? sinf(frame * 0.8f) * 4 : 0;
    float sq = 1, fl = flinch_t > 0 ? sinf(flinch_t * 1.4f) * 4 : 0;
    float bend = clampf(bend_t / 40.f, 0, 1);
    if (tele_t > 0) {
        /* Teleport: he narrows to a line and back. */
        int half = TELE_FRAMES / 2;
        float k = tele_t > half ? (TELE_FRAMES - tele_t) / (float)half : tele_t / (float)half;
        sq = 1 - clampf(k, 0, 1);
        if (sq < 0.08f) {
            gfx_glow(cx, cy, 40, HEXA(0xc8a8ff, 200));
            return;
        }
    }
    cy += bob;
    cx += fl;
    /* His shadow on the grass, and the psychic glow around him. */
    gfx_ellipse(cx, 212, 40 * sq, 6, HEXA(0x2a5a2a, 90));
    gfx_glow(cx, cy + 10, 66 * sq, HEXA(0xc8a0ff, 80));
#define X(v) (cx + ((v)-cx) * sq)
    toon_t = 2.5f;
    for (toon_pass = 0; toon_pass < 2; toon_pass++) {
        /* Thin legs dangling, knees a little bent, brown at the knee. */
        toon_line(X(cx - 10), cy + 40, X(cx - 14), cy + 56, 7, FUR);
        toon_line(X(cx - 14), cy + 56, X(cx - 9), cy + 72, 6, FUR);
        toon_line(X(cx + 10), cy + 40, X(cx + 14), cy + 56, 7, FUR);
        toon_line(X(cx + 14), cy + 56, X(cx + 9), cy + 72, 6, FUR);
        toon_ellipse(X(cx - 14), cy + 56, 5 * sq + 1, 4, BROWN);
        toon_ellipse(X(cx + 14), cy + 56, 5 * sq + 1, 4, BROWN);
        toon_ellipse(X(cx - 7), cy + 74, 6 * sq + 1, 3, FUR);
        toon_ellipse(X(cx + 7), cy + 74, 6 * sq + 1, 3, FUR);
        /* Thin arms out to the spoons. */
        toon_line(X(cx - 22), cy + 6 + b, X(cx - 36 + sway), cy + 14 + b, 6, FUR);
        toon_line(X(cx - 36 + sway), cy + 14 + b, X(cx - 44 + sway), cy - 10 + tap + b, 6, FUR);
        toon_line(X(cx + 22), cy + 6 + b, X(cx + 36 + sway), cy + 14 + b, 6, FUR);
        toon_line(X(cx + 36 + sway), cy + 14 + b, X(cx + 44 + sway), cy - 10 - tap + b, 6, FUR);
        toon_ellipse(X(cx - 36 + sway), cy + 14 + b, 5 * sq + 1, 4, BROWN);
        toon_ellipse(X(cx + 36 + sway), cy + 14 + b, 5 * sq + 1, 4, BROWN);
        /* A slim body with a brown chest plate and big brown shoulders. */
        toon_rrect(X(cx - 15), cy + b * 0.5f, 30 * sq, 44, 12, FUR);
        toon_rrect(X(cx - 13), cy + 6 + b * 0.5f, 26 * sq, 22, 7, BROWN);
        toon_ellipse(X(cx - 20), cy + 4 + b, 11 * sq + 1, 8, BROWN);
        toon_ellipse(X(cx + 20), cy + 4 + b, 11 * sq + 1, 8, BROWN);
        /* Long ears, swept up and out. */
        {
            float hy = cy - 24 + b;
            toon_tri(X(cx - 15), hy - 8, X(cx - 34), hy - 58, X(cx - 3), hy - 18, FUR);
            toon_tri(X(cx + 15), hy - 8, X(cx + 34), hy - 58, X(cx + 3), hy - 18, FUR);
            /* The head: wide at the brow, a fox's snout. */
            toon_ellipse(cx + sway * 0.3f, hy - 2, 23 * sq + 1, 20, FUR);
            toon_ellipse(cx + sway * 0.3f, hy + 10, 12 * sq + 1, 11, HEX(0xf6d27a));
        }
    }
    {
        float hy = cy - 24 + b, hx = cx + sway * 0.3f;
        float m1 = sinf(frame * 0.07f) * 3, m2 = sinf(frame * 0.07f + 1) * 3;
        gfx_tri(X(cx - 13), hy - 12, X(cx - 28), hy - 48, X(cx - 6), hy - 18, FUR_DARK);
        gfx_tri(X(cx + 13), hy - 12, X(cx + 28), hy - 48, X(cx + 6), hy - 18, FUR_DARK);
        if (sq > 0.5f) {
            /* Narrow eyes, mostly closed: he is concentrating. */
            if (bow || dizzy_t > 0) {
                if (dizzy_t > 0) {
                    for (int k = 0; k < 3; k++) {
                        float a = frame * 0.15f + k * 2.09f;
                        gfx_star(hx + cosf(a) * 22, hy - 26 + sinf(a) * 6, 4, a, GOLD);
                    }
                }
                gfx_line(hx - 14, hy - 4, hx - 5, hy - 2, 2.5f, INK);
                gfx_line(hx + 5, hy - 2, hx + 14, hy - 4, 2.5f, INK);
            } else {
                float look = clampf((nx - cx) * 0.02f, -2, 2);
                gfx_line(hx - 15, hy - 6, hx - 4, hy - 2, 4.5f, INK);
                gfx_line(hx + 4, hy - 2, hx + 15, hy - 6, 4.5f, INK);
                gfx_circle(hx - 9 + look, hy - 4, 1.6f, HEX(0xfff6d0));
                gfx_circle(hx + 9 + look, hy - 4, 1.6f, HEX(0xfff6d0));
            }
            gfx_ellipse(hx, hy + 5, 3.5f, 2.5f, INK);
            /* The mustache: two long strands from under the nose, hanging past his chest. */
            for (toon_pass = 0; toon_pass < 2; toon_pass++) {
                toon_t = 2;
                toon_line(hx - 3, hy + 9, hx - 14, hy + 16, 5, BROWN);
                toon_line(hx - 14, hy + 16, hx - 22 + m1, hy + 40, 4, BROWN);
                toon_line(hx - 22 + m1, hy + 40, hx - 24 + m1 * 1.5f, hy + 62, 3, BROWN);
                toon_line(hx + 3, hy + 9, hx + 14, hy + 16, 5, BROWN);
                toon_line(hx + 14, hy + 16, hx + 22 + m2, hy + 40, 4, BROWN);
                toon_line(hx + 22 + m2, hy + 40, hx + 24 + m2 * 1.5f, hy + 62, 3, BROWN);
            }
        }
    }
    /* Spoons: bent at the end of a win, the trick he is proud of. */
    {
        float lx = X(cx - 44 + sway), rx = X(cx + 44 + sway), ly = cy - 10 + tap + b, ry = cy - 10 - tap + b;
        gcol steel = flash ? WHITE : SPOON;
        for (int side = 0; side < 2; side++) {
            float x = side ? rx : lx, y = side ? ry : ly;
            float tip_x = x + (side ? 1 : -1) * 14 * bend, tip_y = y - 30 + 10 * bend;
            gfx_line(x, y + 6, x, y - 14, 6, INK);
            gfx_line(x, y + 6, x, y - 14, 3, steel);
            gfx_line(x, y - 14, tip_x, tip_y + 8, 6, INK);
            gfx_line(x, y - 14, tip_x, tip_y + 8, 3, steel);
            gfx_ellipse_o(tip_x, tip_y, 8, 10, steel, INK, 2);
            gfx_ellipse(tip_x - 2, tip_y - 3, 2.5f, 4.5f, HEXA(0xffffff, flash ? 255 : 170));
            if (flash || telegraph > 0)
                gfx_glow(tip_x, tip_y, 24, telegraph > 0 ? HEXA(0xb070ff, 200) : HEXA(0xffffff, 200));
        }
    }
    if (flinch_t > 0)
        gfx_glow(cx, cy, 60, HEXA(0xffffff, flinch_t * 10));
#undef X
    /* Marks so far: nine little lights over his head. */
    if (phase == FIGHT || phase == WINBOW) {
        for (int i = 0; i < marks_win; i++) {
            float x = cx - (marks_win - 1) * 6 + i * 12, y = 212;
            gfx_circle(x, y, 4.5f, INK);
            gfx_circle(x, y, 3.2f, i < marks ? GOLD : HEX(0x5a4a6a));
            if (i < marks)
                gfx_glow(x, y, 8, HEXA(0xffe080, 100));
        }
    }
}

/* Reflect: a wall of light panels in front of him. */
static void draw_shield(float cx, float cy)
{
    float k = clampf((SHIELD_FRAMES - shield_t) / 12.f, 0, 1) * clampf(shield_t / 12.f, 0, 1);
    for (int i = -3; i <= 3; i++) {
        float x = cx + i * 18, y = cy + 62 + fabsf((float)i) * 3;
        float sh = 0.6f + 0.4f * sinf(frame * 0.2f + i);
        gfx_rrect(x - 8, y - 12 * k, 16, 24 * k + 1, 3, col_alpha(CYAN, (int)(120 * sh)));
        gfx_rrect(x - 8, y - 12 * k, 16, 3, 1, col_alpha(WHITE, (int)(200 * k)));
    }
    gfx_glow(cx, cy + 62, 70 * k, HEXA(0x7fe8ff, 70));
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
    if (sword && !moving) {
        fx = 0;
        fy = -1;
    }
    gfx_ellipse(x, y + 34, 16, 5, HEXA(0x2a5a2a, 110));
    toon_t = 2.5f;
    for (toon_pass = 0; toon_pass < 2; toon_pass++) {
        {
            float p[] = {x - 13, y + 2, x + 13, y + 2, x + 17 - fx * 6, y + 30 + fabsf(step) * 2, x - 17 - fx * 6,
                         y + 30 + fabsf(step) * 2};
            toon_poly(p, 4, CAPE);
        }
        toon_rrect(x - 9 + step * 2, y + 20, 7, 14, 3, HEX(0x5a4a6a));
        toon_rrect(x + 2 - step * 2, y + 20, 7, 14, 3, HEX(0x5a4a6a));
        toon_rrect(x - 10, y + 2, 20, 22, 7, HEX(0x5a8ac8));
        toon_circle(x, y - 10, 15, SKIN);
        toon_ellipse(x, y - 18, 17, 11, HELM);
    }
    gfx_rect((int)x - 17, (int)y - 17, 34, 3, HEX(0x9aa4b8));
    gfx_ellipse(x - 6, y - 22, 5, 3, HEXA(0xffffff, 200));
    gfx_circle(x, y - 30, 3, ROSE);
    if (fy < 0 && fx == 0) {
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
    if (sword || (phase == POP && pop_t > 30)) {
        /* The sword points at Zam by itself. */
        float dx = zx - x, dy = zy - (y - 4), d = sqrtf(dx * dx + dy * dy);
        float ux = d > 1 ? dx / d : 0, uy = d > 1 ? dy / d : -1;
        float sx = x + ux * 16 + 10, sy = y - 4 + uy * 10;
        float tx = sx + ux * 28, ty = sy + uy * 28;
        gfx_line(sx, sy, tx, ty, 9, INK);
        gfx_line(sx, sy, tx, ty, 5, GOLD);
        gfx_line(sx - uy * 7, sy + ux * 7, sx + uy * 7, sy - ux * 7, 6, INK);
        gfx_line(sx - uy * 6, sy + ux * 6, sx + uy * 6, sy - ux * 6, 3.5f, BROWN);
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

static void draw(void)
{
    const char *line;
    int open = phase != PATH;
    int flash = spoon_flash > 0;
    draw_ground();
    draw_pile();
    draw_chest_box(open);
    if (!has_key)
        draw_key(key_x, key_y);
    if (phase == POP) {
        float k = ease_out_back(clampf((float)pop_t / 40, 0, 1));
        draw_zam(ZX, 150 - 32 * k, flash, 0);
        if (pop_t > 4 && pop_t < 34) {
            float t = (pop_t - 4) / 30.f;
            float sx = lerpf(ZX + 40, nx, t), sy = lerpf(ZY - 40, ny - 10, t) - sinf(t * 3.14159f) * 80;
            gfx_glow(sx, sy, 16, HEXA(0xffe080, 200));
            gfx_star(sx, sy, 8, frame * 0.4f, GOLD);
        }
    } else if (phase == FIGHT || phase == WINBOW || phase == RESTART)
        draw_zam(zx, zy, flash, phase == WINBOW || phase == RESTART);
    if (shield_t > 0 && phase == FIGHT)
        draw_shield(zx, zy);
    if (wrap > 0)
        bubble(zx, zy, 76 + sinf(frame * 0.15f) * 3, GOLD, 1);
    if (star_on) {
        gfx_glow(star_x, star_y, 22, HEXA(0xffe080, 160));
        gfx_star(star_x, star_y, 11, frame * 0.05f, INK);
        gfx_star(star_x, star_y, 9, frame * 0.05f, GOLD);
    }
    if (telegraph > 0) {
        /* Where the bubble will go: a faint purple ring under him. */
        gfx_ring(nx, ny + 20, 30 + (30 - telegraph), 2, HEXA(0x7a5af5, 60 + telegraph * 4));
    }
    draw_ned();
    if (ring_on) {
        bubble(ring_x, ring_y, ring_r + 14, ring_safe ? BLUE : PURPLE, 1);
        if (ring_safe)
            gfx_star(ring_x, ring_y - 4, 7, frame * 0.1f, GOLD);
        else {
            float k = clampf((ring_r - 8) / 18.f, 0, 1);
            gfx_ring(ring_x, ring_y, 40, 2, col_alpha(PURPLE, (int)(60 + k * 160)));
        }
    }
    if (fairy != FAIRY_NONE)
        draw_fairy(fairy_x, fairy_y, fairy == FAIRY_GOLD ? GOLD : fairy == FAIRY_BLUE ? BLUE : PURPLE, fairy == FAIRY_BLUE);
    for (int k = 0; k < MAXB; k++)
        if (b_on[k])
            bubble(b_x[k], b_y[k], 13, PURPLE, 1);
    if (beam_t > 0) {
        float k = beam_t / 10.f;
        int sw = has_sword;
        gcol core = beam_blocked ? CYAN : GOLD;
        gfx_line(beam_x0, beam_y0, beam_x1, beam_y1, (sw ? 10 : 6) * k + 2, col_alpha(core, (int)(160 * k)));
        gfx_line(beam_x0, beam_y0, beam_x1, beam_y1, (sw ? 4 : 2.5f) * k + 1, col_alpha(WHITE, (int)(255 * k)));
        gfx_glow(beam_x1, beam_y1, 18 * k + 4, beam_blocked ? HEXA(0x7fe8ff, 200) : HEXA(0xffe080, 200));
        beam_t--;
    }
    if (prize_t > 0) {
        /* The treasure arcs from Zam to the pile. */
        float px, py, t = clampf(prize_t / 60.f, 0, 1);
        pile_slot((gems - 1) < PILE_SHOWN ? gems - 1 : PILE_SHOWN - 1, &px, &py);
        gfx_glow(lerpf(zx, px, t), lerpf(zy, py, t) - sinf(t * 3.14159f) * 70, 20, HEXA(0xffe080, 200));
        treasure(prize_kind, lerpf(zx, px, t), lerpf(zy, py, t) - sinf(t * 3.14159f) * 70, 1.f + (1 - t) * 1.5f);
    }
    part_update();
    part_draw();
    line = react_left ? react : rest_line();
    if (cab_down(0, CAB_1P) && cab_down(0, CAB_2P))
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
        tx = has_key ? ZX : key_x;
        ty = has_key ? 240 : key_y;
    } else if (phase == FIGHT) {
        tx = (int)zx + (sinf(frame * 0.012f) > 0 ? -40 : 40);
        ty = 400;
        if (star_on) {
            tx = star_x;
            ty = star_y;
        }
        if (ring_on && !ring_safe) {
            tx = ring_x + (ring_x < ZX ? 80 : -80);
            ty = ring_y;
        }
        for (int k = 0; k < MAXB; k++)
            if (b_on[k] && fabsf(b_x[k] - nx) < 50 && b_y[k] < ny)
                tx = nx + (b_x[k] < nx ? 70 : -70);
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
    }
    /* With the sword, shoot whenever the shield is down. */
    if (phase == FIGHT && shield_t == 0 && frame % 2)
        cab_bot(CAB_LOW, 1);
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
        deco[i][1] = rng_range(80, H - BAND - 8);
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
        if (phase == POP) {
            /* He hops back to the fighting line while Zam unfolds. */
            nx += (int)((ZX - nx) * 0.08f);
            if (ny < 400)
                ny += 3;
        } else if (phase != WINBOW && phase != RESTART) {
            int top = phase == FIGHT ? FIGHT_TOP : 230;
            nx += mx * SPEED;
            ny += my * SPEED;
            if (nx < 24)
                nx = 24;
            if (nx > W - 24)
                nx = W - 24;
            if (ny < top)
                ny = top;
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
        /* A press fires at once (no faster than five a second); a held button repeats twice a second. */
        if (saw_release && phase != WINBOW && phase != RESTART && ((pressed && shot_cool <= HOLD_GAP - SHOT_GAP) || (held && !pressed && shot_cool == 0))) {
            fire();
            shot_cool = HOLD_GAP;
        }
        if (phase == POP) {
            if (++pop_t >= POP_FRAMES) {
                phase = FIGHT;
                has_sword = 1;
                clear_fight();
                cab_log("chest sword %d", frame);
                cab_log("chest level %d", level);
            }
        } else if (phase == FIGHT)
            fight_step();
        else if (phase == WINBOW) {
            bow_t++;
            if (bow_t > 20 && bend_t < 40)
                bend_t++;
            if (prize_t > 0 && ++prize_t > 60) {
                prize_t = 0;
                pile_hop = 30;
                sfx_note(W_SINE, 91, 0.2f, 0.2f);
            }
            if (bow_t >= WIN_FRAMES) {
                int k;
                phase = PATH;
                has_key = 0;
                has_sword = 0;
                bend_t = 0;
                clear_fight();
                k = rng_int(1, 4);
                key_x = key_spots[k][0];
                key_y = key_spots[k][1];
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
        if (flinch_t > 0)
            flinch_t--;
        if (dizzy_t > 0)
            dizzy_t--;
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
