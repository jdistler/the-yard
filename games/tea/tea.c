/* Tea: a unicorn flies to a castle and takes care of the cats.
 * Little band (CONTROLS.md): any stick direction does the one useful thing,
 * every right-hand button does the care, and a turn cannot be lost.
 * Upright 384x512. A grown-up reads the cream band. She can play without it.
 * tea.sav remembers visits and gifts. Hearts start fresh every arrival.
 * The spec is DESIGN.md beside this file; the lines below are its lines.
 */
#include "gfx.h"
#include "sfx.h"

#include <fcntl.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define W 384
#define H 512
#define BAND 32
#define SKY_STEP 480
#define HURRY_STEP 900
#define FLY_DONE (SKY_STEP * 900)
#define DOOR_FRAMES 90
#define REACT_FRAMES 120
#define CHEER_FRAMES 180
#define CARE_GAP 30

enum { SKY, DOOR, PARTY };
enum { PIP, MOTH, PEARL, NIB, CAT_MAX };
enum { GIFT_NONE, GIFT_TEACUP, GIFT_RIBBON, GIFT_FLOWER };

static const gcol SKY_C = HEX(0x8ec6ff), CREAM = HEX(0xfff6ea), CASTLE = HEX(0xf4b6d0), ROOF = HEX(0xe86b9a),
                  GOLD = HEX(0xf2c14e), MINT = HEX(0x7ec8c3), LILAC = HEX(0xb9a0e8), TEA_C = HEX(0xc9865a),
                  ORANGE = HEX(0xf29a3a), GREY = HEX(0x8a8f9c), INK = HEX(0x3a2a44), WHITE = HEX(0xfffcf8),
                  BLUSH = HEXA(0xff8fb0, 120);

static const char *const gift_word[] = {"none", "teacup", "ribbon", "flower"};
static const char *const cat_name[] = {"Pip", "Moth", "Pearl", "Nib"};

static int phase, frame, fly, door_t, focus, ncats, visits, nib_here;
static int hearts[CAT_MAX], gift[CAT_MAX], last_friend;
static int react_left, cheer_left, cheered, care_wait, care_from_party;
static int hurry, lean_x, lean_y, bump_cool, goodbye_played;
static int delight[CAT_MAX], heart_pop[CAT_MAX], toss_t, toss_who;
static float wing, uni_x, cat_lean[CAT_MAX];
static char react_line[40];
static char shown[40];
static int fast;

typedef struct {
    float a, z, squish;
} cloud_t;
static cloud_t clouds[12];

/* ------------------------------------------------------------------ sound */

static const sfx_song sky_bed = {120, 1, 1, {{"C5 E5 G5", W_SINE, 0.10f, 0.35f, 0.02f, 0, 0, 0}}};
static const sfx_song party_bed = {
    90, 2, 2,
    {
        {"C5 . E5 . G5 . E5 . F5 . A5 . G5 . E5 . ", W_TRI, 0.06f, 0.3f, 0.01f, 0, 0, -0.2f},
        {"C3 - - - - - - - F3 - - - G3 - - - ", W_SINE, 0.10f, 0.4f, 0.05f, 0, 0, 0.2f},
    }};

static void notes(const int *m, int n, float step, float vol)
{
    sfx_arp(W_TRI, m, n, step, vol);
}

static void tune_for(int cat)
{
    int who = cat == NIB ? last_friend : cat;
    int up = cat == NIB ? 7 : 0;
    if (who == PIP) {
        sfx_t purr = {W_TRI, 196.f * (up ? 1.5f : 1.f), 0, 0.45f, 0.25f, 0.05f, 0.3f, 0.5f, 18, 0.4f, 0};
        sfx_play(&purr);
        sfx_note(W_SINE, 76 + up, 0.4f, 0.3f);
    } else if (who == MOTH) {
        int m[] = {79 + up, 84 + up};
        notes(m, 2, 0.09f, 0.3f);
    } else {
        int m[] = {84 + up, 88 + up, 91 + up};
        sfx_arp(W_SINE, m, cat == NIB ? 2 : 3, 0.11f, 0.28f);
    }
}

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

static int gift_of(const char *s)
{
    for (int i = 0; i < 4; i++)
        if (!strcmp(s, gift_word[i]))
            return i;
    return GIFT_NONE;
}

static void load_save(void)
{
    FILE *f = fopen("tea.sav", "r");
    char line[80];
    visits = 0;
    for (int i = 0; i < CAT_MAX; i++)
        gift[i] = GIFT_NONE;
    if (!f)
        return;
    while (fgets(line, sizeof line, f)) {
        char key[32], val[32];
        int n;
        if (sscanf(line, "visits %d", &n) == 1) {
            if (n < 0)
                n = 0;
            if (n > 100000)
                n = 100000;
            visits = n;
        } else if (sscanf(line, "%31s %31s", key, val) == 2) {
            int g = gift_of(val);
            if (!strcmp(key, "pip"))
                gift[PIP] = g;
            else if (!strcmp(key, "moth"))
                gift[MOTH] = g;
            else if (!strcmp(key, "pearl"))
                gift[PEARL] = g;
            else if (!strcmp(key, "nib"))
                gift[NIB] = g;
        }
    }
    fclose(f);
}

static int save_tea(void)
{
    FILE *f = fopen("tea.sav.tmp", "w");
    if (!f)
        return -1;
    fprintf(f, "visits %d\n", visits);
    fprintf(f, "pip %s\n", gift_word[gift[PIP]]);
    fprintf(f, "moth %s\n", gift_word[gift[MOTH]]);
    fprintf(f, "pearl %s\n", gift_word[gift[PEARL]]);
    fprintf(f, "nib %s\n", gift_word[gift[NIB]]);
    if (fflush(f) != 0 || fsync(fileno(f)) != 0) {
        fclose(f);
        unlink("tea.sav.tmp");
        return -1;
    }
    if (fclose(f) != 0) {
        unlink("tea.sav.tmp");
        return -1;
    }
    if (rename("tea.sav.tmp", "tea.sav") != 0)
        return -1;
    fsync_parent("tea.sav");
    return 0;
}

/* ------------------------------------------------------------------ the lines */

static void say(const char *s)
{
    if (!strcmp(shown, s))
        return;
    snprintf(shown, sizeof shown, "%s", s);
    cab_log("tea say %s", shown);
}

static int runner(void)
{
    for (int i = 0; i < ncats; i++)
        if (gift[i] != GIFT_NONE)
            return i;
    return -1;
}

static const char *reunion_line(int who)
{
    if (who == MOTH)
        return "Moth kept a ribbon.";
    if (who == PEARL)
        return "Pearl kept her flower.";
    return "Pip kept a teacup.";
}

static const char *ask_line(int who)
{
    if (who == MOTH)
        return "Moth wants the yarn.";
    if (who == PEARL)
        return "Pearl wants a flower.";
    if (who == NIB)
        return "Nib copies a friend.";
    return "Pip would love some tea.";
}

static const char *care_line(int who)
{
    if (who == MOTH)
        return "The yarn rolled back.";
    if (who == PEARL)
        return "Pearl wears a flower.";
    if (who == NIB)
        return "Nib bumped her nose.";
    return "Pip sipped her tea.";
}

static const char *happy_line(int who)
{
    static char buf[40];
    snprintf(buf, sizeof buf, "%s is so happy.", cat_name[who]);
    return buf;
}

static const char *rest_line(void)
{
    int who;
    if (cab_down(0, CAB_1P) && cab_down(0, CAB_2P))
        return "They will keep the gifts.";
    if (phase == SKY) {
        if (hurry)
            return "The party is waiting.";
        if (lean_x || lean_y)
            return "She leans in the clouds.";
        return "She flies to the castle.";
    }
    if (phase == DOOR) {
        if (visits == 3)
            return "A kitten came to play.";
        who = runner();
        if (who >= 0)
            return reunion_line(who);
        return "They saved her a seat.";
    }
    if (cheered)
        return "Play on. They love it.";
    return ask_line(focus);
}

/* ------------------------------------------------------------------ the party's rules */

static float seat_x(int i)
{
    if (ncats == 4)
        return 60.f + i * 88.f;
    return 72.f + i * 120.f;
}

static void begin_door(void)
{
    phase = DOOR;
    door_t = 0;
    if (visits < 100000)
        visits++;
    nib_here = visits >= 3;
    ncats = nib_here ? 4 : 3;
    if (focus >= ncats)
        focus = 0;
    save_tea();
    cab_log("tea arrive %d", visits);
    music_stop();
    {
        int m[] = {72, 76, 79};
        notes(m, 3, 0.12f, 0.3f);
    }
    {
        int who = runner();
        if (who >= 0)
            tune_for(who);
    }
}

static int all_full(void)
{
    for (int i = 0; i < ncats; i++)
        if (hearts[i] < 3)
            return 0;
    return 1;
}

static void give_gift(int who)
{
    if (who == PIP)
        gift[PIP] = GIFT_TEACUP;
    else if (who == MOTH)
        gift[MOTH] = GIFT_RIBBON;
    else if (who == PEARL)
        gift[PEARL] = GIFT_FLOWER;
}

static float head_y(int i) { return i == focus ? 236.f : 226.f; }

static void care(int who)
{
    int filled = 0;
    if (who != NIB)
        last_friend = who;
    give_gift(who);
    if (hearts[who] < 3) {
        hearts[who]++;
        filled = hearts[who] == 3;
        heart_pop[who] = 16;
        if (hearts[who] == 1)
            sfx_note(W_SINE, 96, 0.15f, 0.12f);
    }
    delight[who] = 46;
    toss_t = 18;
    toss_who = who;
    cab_log("tea heart %s %d", cat_name[who], hearts[who]);
    tune_for(who);
    part_burst(seat_x(who), head_y(who) - 30, 8, 2.f, 30, 3.f, col_alpha(ROOF, 220), PART_HEART);
    if (all_full() && !cheered) {
        int m[] = {72, 76, 79, 84};
        cheered = 1;
        cheer_left = CHEER_FRAMES;
        snprintf(react_line, sizeof react_line, "%s", "The whole table glows.");
        react_left = CHEER_FRAMES;
        notes(m, 4, 0.14f, 0.32f);
        for (int i = 0; i < 40; i++) {
            gpart *p = part_spawn(rng_range(20, W - 20), rng_range(-20, 40), rng_range(-0.5f, 0.5f), rng_range(0.5f, 1.5f),
                                  140, rng_range(3, 5), col_hsv(rng_f(), 0.4f, 1.f), i % 2 ? PART_HEART : PART_STAR);
            p->drag = 1.f;
            p->spin = rng_range(-0.1f, 0.1f);
        }
        save_tea();
        cab_log("tea cheer");
    } else {
        snprintf(react_line, sizeof react_line, "%s", filled ? happy_line(who) : care_line(who));
        react_left = REACT_FRAMES;
        save_tea();
    }
    care_wait = CARE_GAP;
}

/* ------------------------------------------------------------------ pictures */

static void icon(int what, float cx, float cy, float s)
{
    /* 0 cup, 1 yarn, 2 flower, 3 sparkle. About 40 pixels across at s = 1. */
    toon_t = 2.f * s;
    for (toon_pass = 0; toon_pass < 2; toon_pass++) {
        if (what == 0) {
            toon_ellipse(cx, cy + 12 * s, 18 * s, 4 * s, HEX(0xffd0e6));
            toon_rrect(cx - 13 * s, cy - 8 * s, 26 * s, 20 * s, 7 * s, WHITE);
            toon_circle(cx + 15 * s, cy + 1 * s, 6 * s, WHITE);
            if (toon_pass) {
                gfx_circle(cx + 15 * s, cy + 1 * s, 3 * s, SKY_C);
                gfx_ellipse(cx, cy - 6 * s, 11 * s, 3 * s, TEA_C);
                gfx_rect((int)(cx - 12 * s), (int)(cy + 1 * s), (int)(24 * s), (int)(4 * s), ROOF);
            }
        } else if (what == 1) {
            toon_circle(cx, cy, 15 * s, GOLD);
            if (toon_pass) {
                gfx_line(cx - 12 * s, cy - 6 * s, cx + 8 * s, cy + 12 * s, 2 * s, HEX(0xd89a2a));
                gfx_line(cx - 6 * s, cy - 13 * s, cx + 13 * s, cy + 6 * s, 2 * s, HEX(0xd89a2a));
                gfx_line(cx - 14 * s, cy + 3 * s, cx + 2 * s, cy + 14 * s, 2 * s, HEX(0xd89a2a));
                gfx_line(cx + 12 * s, cy + 8 * s, cx + 22 * s, cy + 14 * s, 2 * s, GOLD);
            }
        } else if (what == 2) {
            toon_line(cx, cy + 4 * s, cx, cy + 20 * s, 3 * s, HEX(0x5ab05a));
            for (int k = 0; k < 5; k++) {
                float a = k * 1.2566f + frame * 0.01f;
                toon_circle(cx + cosf(a) * 8 * s, cy + sinf(a) * 8 * s, 7 * s, ROOF);
            }
            toon_circle(cx, cy, 6 * s, GOLD);
        } else {
            if (toon_pass)
                gfx_glow(cx, cy, 28 * s, HEXA(0xffe080, 140));
            if (toon_pass)
                gfx_star(cx, cy, 15 * s * (1 + 0.1f * sinf(frame * 0.2f)), frame * 0.03f, GOLD);
        }
    }
}

static void cloud(float x, float y, float s, float squish)
{
    float sq = 1 - squish * 0.3f;
    gfx_ellipse(x, y + 8 * s, 34 * s, 10 * s * sq, HEXA(0xc8d8f8, 160));
    gfx_circle(x - 18 * s, y, 15 * s * sq, CREAM);
    gfx_circle(x + 16 * s, y + 1 * s, 17 * s * sq, CREAM);
    gfx_circle(x, y - 8 * s * sq, 20 * s * sq, CREAM);
    gfx_ellipse(x, y + 6 * s, 30 * s, 9 * s * sq, CREAM);
    gfx_circle(x - 6 * s, y - 14 * s * sq, 7 * s, WHITE);
}

static void castle(float cx, float base, float s, float door)
{
    float ww = 200 * s, wh = 110 * s;
    float flag = sinf(frame * 0.12f) * 4 * s;
    toon_t = fmaxf(1.f, 2.5f * s);
    for (toon_pass = 0; toon_pass < 2; toon_pass++) {
        /* Side towers, the wall, the middle tower. */
        toon_rrect(cx - ww / 2 - 18 * s, base - wh - 40 * s, 44 * s, wh + 40 * s, 4 * s, CASTLE);
        toon_rrect(cx + ww / 2 - 26 * s, base - wh - 40 * s, 44 * s, wh + 40 * s, 4 * s, CASTLE);
        toon_rrect(cx - ww / 2, base - wh, ww, wh, 4 * s, CASTLE);
        toon_rrect(cx - 34 * s, base - wh - 70 * s, 68 * s, wh + 70 * s, 4 * s, CASTLE);
        toon_tri(cx - ww / 2 - 24 * s, base - wh - 40 * s, cx - ww / 2 + 4 * s, base - wh - 96 * s, cx - ww / 2 + 32 * s,
                 base - wh - 40 * s, ROOF);
        toon_tri(cx + ww / 2 - 32 * s, base - wh - 40 * s, cx + ww / 2 - 4 * s, base - wh - 96 * s, cx + ww / 2 + 24 * s,
                 base - wh - 40 * s, ROOF);
        toon_tri(cx - 42 * s, base - wh - 70 * s, cx, base - wh - 140 * s, cx + 42 * s, base - wh - 70 * s, ROOF);
        toon_line(cx, base - wh - 140 * s, cx, base - wh - 164 * s, 2 * s, INK);
        toon_tri(cx, base - wh - 164 * s, cx + 22 * s, base - wh - 158 * s + flag, cx, base - wh - 150 * s, GOLD);
        /* The door: an arch. Open, it is warm light. */
        toon_rrect(cx - 20 * s, base - 50 * s, 40 * s, 50 * s, 18 * s, door > 0 ? HEX(0xffe7a8) : GOLD);
    }
    if (s > 0.25f) {
        for (int k = 0; k < 6; k++)
            gfx_rect((int)(cx - ww / 2 + 6 * s + k * 34 * s), (int)(base - wh - 8 * s), (int)(16 * s), (int)(8 * s),
                     col_scale(CASTLE, 0.92f));
        gfx_rrect_o(cx - 12 * s, base - wh - 40 * s, 24 * s, 28 * s, 10 * s, MINT, INK, fmaxf(1, 2 * s));
        gfx_star(cx, base - wh - 26 * s, 7 * s, 0, GOLD);
        gfx_rrect_o(cx - ww / 2 - 6 * s, base - wh - 10 * s, 20 * s, 24 * s, 8 * s, MINT, INK, fmaxf(1, 2 * s));
        gfx_rrect_o(cx + ww / 2 - 14 * s, base - wh - 10 * s, 20 * s, 24 * s, 8 * s, MINT, INK, fmaxf(1, 2 * s));
    }
    if (door > 0) {
        /* Two leaves swing open, light spills out. */
        float lw = 20 * s * (1 - door);
        gfx_glow(cx, base - 22 * s, 70 * s * door, HEXA(0xffd070, 160));
        if (lw >= 2) {
            gfx_rrect_o(cx - 20 * s, base - 50 * s, lw, 50 * s, 4 * s, GOLD, INK, fmaxf(1, 2 * s));
            gfx_rrect_o(cx + 20 * s - lw, base - 50 * s, lw, 50 * s, 4 * s, GOLD, INK, fmaxf(1, 2 * s));
        }
    }
}

/* The unicorn, seen from behind: she is you, flying or standing in front of the table. */
static void unicorn(float x, float y, float s, int flying, float flap, int pose)
{
    float wa = flying ? flap : -0.3f;
    float head_t = pose == 2 ? 8 * s : 0;
    toon_t = 2.5f * s;
    for (toon_pass = 0; toon_pass < 2; toon_pass++) {
        /* Wings: puffs along an arm from each shoulder. */
        for (int side = -1; side <= 1; side += 2) {
            float ang = flying ? 0.45f + wa * 0.75f : -0.35f;
            float len = flying ? 1.f : 0.45f;
            for (int k = 3; k >= 0; k--) {
                float d = (14 + k * 13) * s * len;
                float fx = x + side * (20 * s + cosf(ang) * d), fy = y - 10 * s - sinf(ang) * d;
                toon_circle(fx, fy, (13 - k * 2) * s * (flying ? 1 : 0.7f), k == 3 ? LILAC : WHITE);
            }
        }
        /* Tail: four stripes. */
        {
            static const gcol tc[4] = {0xfff2c14e, 0xffe86b9a, 0xff7ec8c3, 0xffb9a0e8};
            for (int k = 0; k < 4; k++) {
                float sw = sinf(frame * 0.08f + k * 0.4f) * 5 * s;
                toon_line(x - 6 * s + k * 4 * s, y + 24 * s, x - 10 * s + k * 7 * s + sw, y + 52 * s, 6 * s, tc[k]);
            }
        }
        /* Legs. Tucked in the air, standing on the floor. */
        if (flying) {
            toon_rrect(x - 22 * s, y + 22 * s, 12 * s, 12 * s, 5 * s, WHITE);
            toon_rrect(x + 10 * s, y + 22 * s, 12 * s, 12 * s, 5 * s, WHITE);
        } else {
            toon_rrect(x - 24 * s, y + 18 * s, 13 * s, 34 * s, 5 * s, WHITE);
            toon_rrect(x + 11 * s, y + 18 * s, 13 * s, 34 * s, 5 * s, WHITE);
            toon_rrect(x - 25 * s, y + 46 * s, 15 * s, 8 * s, 3 * s, LILAC);
            toon_rrect(x + 10 * s, y + 46 * s, 15 * s, 8 * s, 3 * s, LILAC);
        }
        toon_ellipse(x, y + 8 * s, 32 * s, 27 * s, WHITE);
        /* Head from behind, the horn up, ears, the mane falling down the back. */
        toon_ellipse(x + head_t, y - 28 * s, 17 * s, 19 * s, WHITE);
        toon_tri(x - 14 * s + head_t, y - 38 * s, x - 9 * s + head_t, y - 56 * s, x - 3 * s + head_t, y - 42 * s, WHITE);
        toon_tri(x + 14 * s + head_t, y - 38 * s, x + 9 * s + head_t, y - 56 * s, x + 3 * s + head_t, y - 42 * s, WHITE);
        toon_tri(x - 4.5f * s + head_t, y - 44 * s, x + head_t, y - 76 * s, x + 4.5f * s + head_t, y - 44 * s, GOLD);
        {
            static const gcol mc[4] = {0xfff2c14e, 0xffe86b9a, 0xff7ec8c3, 0xffb9a0e8};
            for (int k = 0; k < 4; k++) {
                float sx = x + head_t + (-9 + k * 6) * s;
                toon_line(sx, y - 40 * s, sx - head_t * 0.5f + (k - 1.5f) * 2 * s, y - 2 * s, 6 * s, mc[k]);
            }
        }
    }
    gfx_line(x - 2 * s + head_t, y - 52 * s, x + 2 * s + head_t, y - 54 * s, 1.5f * s, HEX(0xd8a03a));
    gfx_line(x - 3 * s + head_t, y - 60 * s, x + 1.5f * s + head_t, y - 62 * s, 1.5f * s, HEX(0xd8a03a));
    gfx_ellipse(x - 8 * s + head_t, y - 48 * s, 2 * s, 4 * s, HEXA(0xffb0c8, 200));
    gfx_ellipse(x + 8 * s + head_t, y - 48 * s, 2 * s, 4 * s, HEXA(0xffb0c8, 200));
}

/* The unicorn is the most drawn thing in the game. Her wing beat and tail sway are cut
 * into eight steps and each step is painted once into a sprite, per pose. */
#define UNI_STEPS 8
static gsurf *uni_cache[2][4][UNI_STEPS];

static void unicorn_at(float x, float y, float s, int flying, float flap, int pose)
{
    int step = ((int)floorf((flap / 0.7f + 1.f) * 0.5f * (UNI_STEPS - 1) + 0.5f)) % UNI_STEPS;
    float hop = pose == 3 ? -fabsf(sinf(frame * 0.25f)) * 16 * s : 0;
    float head_t = pose == 2 ? 8 * s : 0;
    int cw = (int)(170 * s), ch = (int)(170 * s), ox = cw / 2, oy = (int)(90 * s);
    gsurf **slot;
    if (step < 0)
        step = 0;
    slot = &uni_cache[flying ? 1 : 0][pose & 3][step];
    if (!*slot && (*slot = gfx_surf_new(cw, ch)) != NULL) {
        int keep_frame = frame;
        gfx_surf_clear(*slot);
        gfx_target(*slot);
        /* The tail sways with the same step as the wings. */
        frame = step * 10;
        unicorn((float)ox, (float)oy, s, flying, -0.7f + 1.4f * step / (UNI_STEPS - 1), pose == 3 ? 0 : pose);
        frame = keep_frame;
        gfx_target(NULL);
    }
    if (flying)
        gfx_ellipse(x, y + 70 * s, 34 * s, 7 * s, HEXA(0x5a7ab0, 60));
    if (*slot)
        gfx_blit_key(*slot, (int)(x - ox), (int)(y + hop - oy));
    else
        unicorn(x, y + hop, s, flying, flap, pose);
    if (pose == 2 || pose == 3 || hurry) {
        gfx_glow(x + head_t, y + hop - 76 * s, 18 * s, HEXA(0xffe080, 200));
        if (frame % 3 == 0)
            part_spawn(x + head_t + rng_range(-6, 6), y + hop - 76 * s, rng_range(-1, 1), rng_range(-1.5f, -0.3f), 30,
                       rng_range(2, 4), col_hsv(rng_f(), 0.35f, 1), PART_STAR);
    }
}

static void cat(int who, float cx, float cy, float s, int happy)
{
    gcol body = who == MOTH ? GREY : who == PEARL ? WHITE : who == NIB ? CREAM : ORANGE;
    gcol dark = who == MOTH ? HEX(0x666a78) : who == PEARL ? HEX(0xe8dccc) : who == NIB ? ORANGE : HEX(0xd87a20);
    float r = (who == NIB ? 20 : 27) * s;
    int blink = ((frame + who * 47) % 200) < 7;
    float twirl = 1.f;
    float tail = sinf(frame * 0.07f + who) * 0.6f;
    if (happy && (who == PEARL || (who == NIB && last_friend == PEARL)))
        twirl = 0.75f + 0.25f * fabsf(cosf(delight[who] * 0.2f));
    toon_t = 2.5f;
    for (toon_pass = 0; toon_pass < 2; toon_pass++) {
        /* Tail: curls out from behind the hip. */
        toon_line(cx + r * 0.8f, cy + r * 1.8f, cx + r * 1.45f, cy + r * 1.5f, 8 * s, body);
        toon_line(cx + r * 1.45f, cy + r * 1.5f, cx + r * 1.55f + tail * r * 0.3f, cy + r * 1.05f, 8 * s, body);
        toon_circle(cx + r * 1.55f + tail * r * 0.3f, cy + r * 1.0f, 4.5f * s, who == PEARL ? WHITE : dark);
        toon_ellipse(cx, cy + r * 1.35f, r * 1.05f * twirl, r * 0.9f, body);
        toon_tri(cx - r * 0.95f * twirl, cy - r * 0.2f, cx - r * 0.75f * twirl, cy - r * (who == MOTH ? 1.45f : 1.25f),
                 cx - r * 0.2f * twirl, cy - r * 0.8f, body);
        toon_tri(cx + r * 0.95f * twirl, cy - r * 0.2f, cx + r * 0.75f * twirl, cy - r * (who == MOTH ? 1.45f : 1.25f),
                 cx + r * 0.2f * twirl, cy - r * 0.8f, body);
        toon_ellipse(cx, cy, r * twirl, r * 0.92f, body);
    }
    gfx_tri(cx - r * 0.78f * twirl, cy - r * 0.35f, cx - r * 0.7f * twirl, cy - r * 1.0f, cx - r * 0.38f * twirl, cy - r * 0.68f,
            HEX(0xffb8c8));
    gfx_tri(cx + r * 0.78f * twirl, cy - r * 0.35f, cx + r * 0.7f * twirl, cy - r * 1.0f, cx + r * 0.38f * twirl, cy - r * 0.68f,
            HEX(0xffb8c8));
    /* Markings. */
    if (who == MOTH)
        for (int k = -1; k <= 1; k++)
            gfx_line(cx + k * r * 0.25f, cy - r * 0.85f, cx + k * r * 0.2f, cy - r * 0.5f, 3 * s, dark);
    if (who == PIP)
        gfx_ellipse(cx, cy + r * 0.38f, r * 0.55f * twirl, r * 0.4f, CREAM);
    if (who == NIB) {
        gfx_ellipse(cx - r * 0.45f, cy - r * 0.35f, r * 0.3f, r * 0.35f, ORANGE);
        gfx_circle(cx + r * 0.3f, cy + r * 1.3f, r * 0.35f, ORANGE);
    }
    /* Eyes: open, blinking, or happy arcs. */
    {
        float ex = r * 0.38f * twirl, ey = cy - r * 0.08f;
        if (happy) {
            gfx_line(cx - ex - 5 * s, ey + 2, cx - ex, ey - 3 * s, 2.5f * s, INK);
            gfx_line(cx - ex, ey - 3 * s, cx - ex + 5 * s, ey + 2, 2.5f * s, INK);
            gfx_line(cx + ex - 5 * s, ey + 2, cx + ex, ey - 3 * s, 2.5f * s, INK);
            gfx_line(cx + ex, ey - 3 * s, cx + ex + 5 * s, ey + 2, 2.5f * s, INK);
        } else if (blink) {
            gfx_line(cx - ex - 5 * s, ey, cx - ex + 5 * s, ey, 2.5f * s, INK);
            gfx_line(cx + ex - 5 * s, ey, cx + ex + 5 * s, ey, 2.5f * s, INK);
        } else {
            float look = (uni_x - cx) * 0.01f;
            gfx_ellipse(cx - ex + look, ey, 5 * s, 6.5f * s, INK);
            gfx_ellipse(cx + ex + look, ey, 5 * s, 6.5f * s, INK);
            gfx_circle(cx - ex + look + 1.5f * s, ey - 2.5f * s, 1.8f * s, WHITE);
            gfx_circle(cx + ex + look + 1.5f * s, ey - 2.5f * s, 1.8f * s, WHITE);
        }
    }
    gfx_ellipse(cx - r * 0.6f * twirl, cy + r * 0.3f, 5 * s, 3 * s, BLUSH);
    gfx_ellipse(cx + r * 0.6f * twirl, cy + r * 0.3f, 5 * s, 3 * s, BLUSH);
    gfx_tri(cx - 3.5f * s, cy + r * 0.2f, cx + 3.5f * s, cy + r * 0.2f, cx, cy + r * 0.32f, ROOF);
    gfx_line(cx, cy + r * 0.32f, cx - 4 * s, cy + r * 0.45f, 1.5f * s, INK);
    gfx_line(cx, cy + r * 0.32f, cx + 4 * s, cy + r * 0.45f, 1.5f * s, INK);
    for (int k = -1; k <= 1; k += 2) {
        gfx_line(cx + k * r * 0.35f, cy + r * 0.3f, cx + k * r * 1.05f, cy + r * 0.2f, 1, HEXA(0x3a2a44, 160));
        gfx_line(cx + k * r * 0.35f, cy + r * 0.36f, cx + k * r * 1.05f, cy + r * 0.42f, 1, HEXA(0x3a2a44, 160));
    }
    if (who == PEARL) {
        gfx_tri(cx + r * 0.35f, cy - r * 0.75f, cx + r * 0.75f, cy - r * 0.95f, cx + r * 0.7f, cy - r * 0.5f, GOLD);
        gfx_tri(cx + r * 0.35f, cy - r * 0.75f, cx + r * 0.05f, cy - r * 1.0f, cx + r * 0.1f, cy - r * 0.55f, GOLD);
        gfx_circle_o(cx + r * 0.38f, cy - r * 0.75f, 3.5f * s, GOLD, INK, 1.5f);
    }
    /* Gifts she gave last time, worn from the first frame. */
    if (gift[who] == GIFT_FLOWER) {
        for (int k = 0; k < 5; k++) {
            float a = k * 1.2566f;
            gfx_circle(cx - r * 0.5f + cosf(a) * 5 * s, cy - r * 0.8f + sinf(a) * 5 * s, 4 * s, ROOF);
        }
        gfx_circle(cx - r * 0.5f, cy - r * 0.8f, 3 * s, GOLD);
    }
    if (gift[who] == GIFT_TEACUP) {
        gfx_rect((int)(cx - r * 0.6f), (int)(cy + r * 0.82f), (int)(r * 1.2f), (int)(4 * s), ROOF);
        gfx_rrect_o(cx - 6 * s, cy + r * 0.9f, 12 * s, 9 * s, 3 * s, WHITE, INK, 1.5f);
    }
    /* Pip sips: a cup at the mouth, then a milk mustache. */
    if (happy && (who == PIP || (who == NIB && last_friend == PIP))) {
        if (delight[who] > 22)
            icon(0, cx + 4 * s, cy + r * 0.5f, 0.5f * s);
        else
            gfx_ellipse(cx, cy + r * 0.42f, r * 0.4f, 3 * s, WHITE);
    }
}

static void hearts_row(int who, float cx, float y)
{
    for (int i = 0; i < 3; i++) {
        float x = cx - 30 + i * 30;
        float pop = (i == hearts[who] - 1 && heart_pop[who] > 0) ? 1 + 0.5f * sinf(heart_pop[who] * 0.2f) : 1;
        gfx_heart(x, y, 11 * pop, INK);
        gfx_heart(x, y, 8.5f * pop, i < hearts[who] ? ROOF : CREAM);
        if (i < hearts[who])
            gfx_circle(x - 4 * pop, y - 4 * pop, 2 * pop, HEXA(0xffffff, 180));
    }
}

/* Backgrounds that never move are painted once and copied each frame. */
static gsurf *bg[3];

static void cached(int i, void (*paint)(void))
{
    if (!bg[i]) {
        bg[i] = gfx_surf_new(W, H);
        if (!bg[i]) {
            paint();
            return;
        }
        gfx_target(bg[i]);
        paint();
        gfx_target(NULL);
    }
    gfx_blit(bg[i], 0, 0);
}

static void paint_sky(void)
{
    gfx_vgrad(0, 0, W, H - BAND, HEX(0x7ab8ff), HEX(0xd8ecff));
    gfx_glow(W / 2, 120, 160, HEXA(0xfff0d0, 90));
}

static void paint_door(void)
{
    gfx_vgrad(0, 0, W, H - BAND, HEX(0x7ab8ff), HEX(0xd8ecff));
    gfx_vgrad(0, 300, W, H - BAND - 300, HEX(0x9ae0a0), HEX(0x6ac080));
}

static void paint_party(void)
{
    gfx_vgrad(0, 0, W, 200, HEX(0x8ec6ff), HEX(0xd8ecff));
    castle(W / 2, 200, 1.15f, 1);
    for (int i = 0; i < 12; i++) {
        float x = 12 + i * 32, y = 168 + sinf(i * 0.9f) * 3;
        gfx_tri(x, y, x + 24, y, x + 12, y + 16, i % 3 == 0 ? ROOF : i % 3 == 1 ? MINT : GOLD);
    }
    gfx_line(0, 168, W, 168, 1.5f, INK);
    gfx_rect(0, 200, W, H - BAND - 200, HEX(0xf6d8e8));
    for (int y = 0; y < 6; y++)
        for (int x = 0; x < 8; x++)
            if ((x + y) % 2)
                gfx_rect(x * 48, 330 + y * 26, 48, 26, HEX(0xecc4dc));
    gfx_rect(0, 200, W, 4, HEXA(0x3a2a44, 50));
}

static void caption(const char *s)
{
    gfx_rect(0, H - BAND, W, BAND, CREAM);
    gfx_rect(0, H - BAND, W, 2, HEXA(0x3a2a44, 60));
    gfx_text_c(W / 2, H - BAND + 9, 2, INK, HEXA(0, 0), "%s", s);
    say(s);
}

static void draw_sky(void)
{
    float prog = (float)fly / FLY_DONE;
    float cs = 0.22f + prog * 0.55f;
    float ux = W / 2 + lean_x * 2.2f, uy = 330 + lean_y * 2.f;
    cached(0, paint_sky);
    /* The rainbow road from her to the castle. */
    {
        static const gcol rb[6] = {0xffff8a8a, 0xffffc070, 0xfffff08a, 0xff9ae6a0, 0xff8ac8ff, 0xffc0a0f0};
        float top = 150 + prog * 40, far_w = 4 + prog * 10;
        for (int k = 0; k < 6; k++) {
            float a0 = (k - 3) / 3.f, a1 = (k - 2) / 3.f;
            float p[8] = {W / 2 + a0 * far_w, top, W / 2 + a1 * far_w, top, W / 2 + a1 * 130, H - BAND,
                          W / 2 + a0 * 130, H - BAND};
            gfx_poly(p, 4, col_alpha(rb[k], 150));
        }
        for (int i = 0; i < 5; i++) {
            float t = (i + 1) / 6.f;
            float y = lerpf(H - BAND - 20, top + 10, t);
            int lit = prog > t;
            if (lit)
                gfx_glow(W / 2, y, 16, HEXA(0xffe080, 200));
            gfx_star(W / 2, y, 7 - t * 3, 0, lit ? GOLD : col_alpha(WHITE, 160));
        }
    }
    {
        /* The far castle grows a little at a time; repaint its sprite only when it has grown. */
        static gsurf *cs_cache;
        static int cs_key = -1;
        int key = (int)(cs * 100);
        float q = key / 100.f;
        int cw = (int)(300 * q) + 8, chh = (int)(300 * q) + 8;
        if (key != cs_key) {
            gfx_surf_free(cs_cache);
            cs_cache = gfx_surf_new(cw, chh);
            if (cs_cache) {
                gfx_surf_clear(cs_cache);
                gfx_target(cs_cache);
                castle(cw / 2.f, chh - 4.f, q, 0);
                gfx_target(NULL);
            }
            cs_key = key;
        }
        if (cs_cache)
            gfx_blit_key(cs_cache, (int)(W / 2 - cw / 2.f), (int)(150 + prog * 40 - chh + 4));
        else
            castle(W / 2, 150 + prog * 40, cs, 0);
    }
    /* Clouds fly past: small near the castle, big as they pass her. */
    for (int pass = 0; pass < 2; pass++)
        for (int i = 0; i < 12; i++) {
            cloud_t *c = &clouds[i];
            float z = c->z, d = z * z * 340;
            float x = W / 2 + cosf(c->a) * d * 1.2f - lean_x * z * 2;
            float y = 140 + sinf(c->a) * d * 0.7f + z * 60;
            if ((pass == 0) != (z < 0.6f))
                continue;
            cloud(x, y, 0.25f + z * 1.3f, c->squish);
        }
    unicorn_at(ux, uy, 1.15f, 1, wing, hurry ? 2 : 0);
}

static void draw_door(void)
{
    float k = clampf(door_t / 30.f, 0, 1);
    int who = runner();
    cached(1, paint_door);
    castle(W / 2, 300, 1.4f, ease_out_cubic(k));
    for (int i = 0; i < ncats; i++) {
        float peek = clampf((door_t - 24 - i * 6) / 14.f, 0, 1);
        float x = W / 2 + (i - (ncats - 1) / 2.f) * 26;
        if (peek <= 0)
            continue;
        if (i == who) {
            float run = clampf((door_t - 40) / 40.f, 0, 1);
            cat(i, lerpf(x, W / 2 - 60, run), lerpf(300 - 18 * peek, 360, run), lerpf(0.5f, 1.f, run), run > 0.6f);
        } else
            cat(i, x, 300 - 16 * peek, 0.5f, 0);
    }
    unicorn_at(W / 2 + 40, 400, 1.f, 0, sinf(frame * 0.05f) * 0.7f, who >= 0 && door_t > 60 ? 2 : 0);
}

static void draw_party(void)
{
    float hop = cheer_left ? fabsf(sinf(frame * 0.3f)) * 8 : 0;
    cached(2, paint_party);
    /* The focus ring sits behind the focused cat. */
    {
        float fx = seat_x(focus);
        float pulse = 1 + 0.06f * sinf(frame * 0.12f);
        gfx_glow(fx, head_y(focus) + 10, 70 * pulse, HEXA(0xfff0a0, 150));
        gfx_ring(fx, head_y(focus) + 6, 44 * pulse, 4, HEXA(0xffe070, 230));
    }
    for (int i = 0; i < ncats; i++) {
        float lean = cat_lean[i];
        int happy = cheer_left > 0 || delight[i] > 0;
        float nib_bump = (i == NIB && delight[i] > 20) ? 12 : 0;
        if (i == NIB) {
            gfx_ellipse_o(seat_x(i), 276, 30, 10, LILAC, INK, 2);
        }
        cat(i, seat_x(i), head_y(i) - lean * 6 - (cheer_left ? hop : 0) + nib_bump * 0.3f, 1.f + lean * 0.12f, happy);
    }
    /* The table, with paws on the cloth. */
    toon_t = 2.5f;
    for (toon_pass = 0; toon_pass < 2; toon_pass++) {
        toon_rrect(16, 280, W - 32, 22, 8, WHITE);
        toon_rrect(16, 296, W - 32, 50, 4, CREAM);
    }
    for (int i = 0; i < 16; i++)
        gfx_circle(26 + i * 22.2f, 346, 11, CREAM);
    for (int i = 0; i < 16; i++)
        gfx_circle(26 + i * 22.2f, 344, 4, HEXA(0xe86b9a, 120));
    gfx_rect(16, 316, W - 32, 6, HEXA(0xe86b9a, 90));
    for (int i = 0; i < ncats; i++) {
        float x = seat_x(i), y = 284 + (i == focus ? 2 : 0);
        gcol body = i == MOTH ? GREY : i == PEARL ? WHITE : i == NIB ? CREAM : ORANGE;
        gfx_ellipse_o(x - 14, y, 9, 6, body, INK, 2);
        gfx_ellipse_o(x + 14, y, 9, 6, body, INK, 2);
    }
    /* Teapot, cakes, flowers. */
    {
        float tx = ncats == 4 ? W / 2 + 0 : W / 2 - 60, ty = 268 - hop;
        float cx2 = ncats == 4 ? 104 : W / 2 + 60;
        toon_t = 2;
        for (toon_pass = 0; toon_pass < 2; toon_pass++) {
            toon_line(tx + 14, ty, tx + 26, ty - 10, 4, HEX(0xffd0e6));
            toon_ellipse(tx, ty, 16, 13, HEX(0xffd0e6));
            toon_circle(tx, ty - 14, 4, GOLD);
        }
        if (ncats == 3) {
            for (toon_pass = 0; toon_pass < 2; toon_pass++) {
                toon_rrect(cx2 - 12, 266 - hop, 24, 14, 4, HEX(0xffe8b0));
                toon_rrect(cx2 - 12, 262 - hop, 24, 6, 3, ROOF);
                toon_circle(cx2, 258 - hop, 4, HEX(0xff4060));
            }
        }
        for (int k = 0; k < 3; k++) {
            float sy = fmodf(frame * 0.6f + k * 12, 36);
            gfx_circle(tx + 24 + sinf(frame * 0.05f + k) * 3, ty - 14 - sy, 4 - sy * 0.08f, col_alpha(WHITE, 220 - (int)(sy * 6)));
        }
        if (cheer_left)
            for (int k = 0; k < 8; k++) {
                float a = frame * 0.15f + k * 0.785f;
                gfx_star(tx + 24 + cosf(a) * 22, ty - 40 + sinf(a) * 10, 4, a, GOLD);
            }
    }
    /* Moth's yarn ball, with the ribbon if she has it. It rolls away and comes back. */
    {
        float roll = delight[MOTH] > 0 ? sinf((46 - delight[MOTH]) / 46.f * 3.14159f) * 36 : sinf(frame * 0.05f) * 3;
        float yx = seat_x(MOTH) + 34 + roll;
        gfx_circle_o(yx, 290, 9, GOLD, INK, 2);
        gfx_line(yx - 6, 286, yx + 5, 295, 1.5f, HEX(0xd89a2a));
        if (gift[MOTH] == GIFT_RIBBON) {
            gfx_tri(yx, 282, yx - 9, 277, yx - 8, 287, ROOF);
            gfx_tri(yx, 282, yx + 9, 277, yx + 8, 287, ROOF);
        }
    }
    /* Ask picture and hearts over the focused cat. */
    {
        float fx = seat_x(focus), hy = head_y(focus);
        int ask = focus == NIB ? last_friend : focus;
        float bob = sinf(frame * 0.08f) * 3;
        gfx_circle_o(fx, hy - 116 + bob, 30, WHITE, INK, 2.5f);
        gfx_tri(fx - 8, hy - 90 + bob, fx + 8, hy - 90 + bob, fx, hy - 78 + bob, INK);
        gfx_tri(fx - 6, hy - 91 + bob, fx + 6, hy - 91 + bob, fx, hy - 82 + bob, WHITE);
        icon(hearts[focus] >= 3 || cheered ? 3 : ask == PIP ? 0 : ask == MOTH ? 1 : 2, fx, hy - 116 + bob, 1.f);
        hearts_row(focus, fx, hy - 56);
    }
    /* The unicorn in front, between you and the table. */
    unicorn_at(uni_x, 420, 0.95f, 0, sinf(frame * 0.05f) * 0.7f, cheer_left ? 3 : react_left > REACT_FRAMES - 30 ? 2 : 0);
    if (toss_t > 0) {
        float k = 1 - toss_t / 18.f;
        float sx = uni_x, sy = 350, ex = seat_x(toss_who), ey = head_y(toss_who) + 10;
        int ask = toss_who == NIB ? last_friend : toss_who;
        icon(ask == PIP ? 0 : ask == MOTH ? 1 : 2, lerpf(sx, ex, k), lerpf(sy, ey, k) - sinf(k * 3.14159f) * 60, 0.55f);
    }
}

static void draw(void)
{
    const char *line;
    if (phase == SKY)
        draw_sky();
    else if (phase == DOOR)
        draw_door();
    else
        draw_party();
    part_update();
    part_draw();
    if (react_left && phase == PARTY)
        line = react_line;
    else
        line = rest_line();
    caption(line);
    gfx_present();
}

/* ------------------------------------------------------------------ autoplay (tests, the reel) */

static void bot(void)
{
    cab_bot_clear();
    if (phase == SKY) {
        if ((frame / 50) % 3 == 1)
            cab_bot(CAB_LOW, 1);
        if ((frame / 70) % 4 == 2)
            cab_bot(CAB_LEFT, 1);
        return;
    }
    if (phase != PARTY)
        return;
    if (frame % 24 == 0)
        cab_bot(hearts[focus] < 3 ? CAB_LOW : CAB_RIGHT, 1);
}

int main(int argc, char **argv)
{
    int autoplay = getenv("CAB_AUTOPLAY") != NULL;
    fast = cab_fast(argc, argv);
    if (gfx_init("Tea", W, H) != 0)
        return 1;
    sfx_init();
    sfx_master(0.22f);
    sfx_limit(3000);
    rng_seed_auto();
    load_save();
    last_friend = PIP;
    ncats = 3;
    uni_x = W / 2;
    for (int i = 0; i < 12; i++) {
        clouds[i].a = rng_range(0, 6.28f);
        clouds[i].z = rng_f();
    }
    music_play(&sky_bed);
    while (cab_poll()) {
        int button, held;
        if (autoplay)
            bot();
        button = cab_pressed(0, CAB_LOW) || cab_pressed(0, CAB_TL) || cab_pressed(0, CAB_TR);
        held = cab_down(0, CAB_LOW) || cab_down(0, CAB_TL) || cab_down(0, CAB_TR);
        hurry = held && phase == SKY;
        if (cab_down(0, CAB_1P) && cab_down(0, CAB_2P) && !goodbye_played) {
            int m[] = {79, 76};
            notes(m, 2, 0.16f, 0.3f);
            goodbye_played = 1;
        }
        lean_x = lean_y = 0;
        if (cab_down(0, CAB_LEFT))
            lean_x -= 12;
        if (cab_down(0, CAB_RIGHT))
            lean_x += 12;
        if (cab_down(0, CAB_UP))
            lean_y -= 18;
        if (cab_down(0, CAB_DOWN))
            lean_y += 18;
        if ((cab_pressed(0, CAB_LEFT) || cab_pressed(0, CAB_RIGHT) || cab_pressed(0, CAB_UP) || cab_pressed(0, CAB_DOWN)) &&
            phase == SKY)
            sfx_note(W_SINE, 79, 0.15f, 0.12f);
        if (phase == SKY) {
            int step = held ? HURRY_STEP : SKY_STEP;
            float speed;
            if (fast)
                step = step * 8 / 5;
            fly += step;
            if (fly > FLY_DONE)
                fly = FLY_DONE;
            speed = held ? 0.012f : 0.007f;
            music_tempo(held ? 1.5f : 1.f);
            if (button) {
                sfx_slide(W_SINE, 900, 1500, 0.15f, 0.12f);
                part_burst(W / 2 + lean_x * 2.2f, 330 + lean_y * 2 - 80, 10, 2.f, 30, 3, GOLD, PART_STAR);
            }
            for (int i = 0; i < 12; i++) {
                cloud_t *c = &clouds[i];
                c->z += speed * (0.4f + c->z);
                if (c->squish > 0)
                    c->squish *= 0.9f;
                if (c->z > 1.25f) {
                    c->z = 0.02f;
                    c->a = rng_range(0, 6.28f);
                }
                /* Bump a big cloud and it squishes and giggles. */
                if (c->z > 0.75f && c->z < 0.95f && bump_cool == 0) {
                    float d = c->z * c->z * 340;
                    float x = W / 2 + cosf(c->a) * d * 1.2f - lean_x * c->z * 2;
                    float y = 140 + sinf(c->a) * d * 0.7f + c->z * 60;
                    float ux = W / 2 + lean_x * 2.2f, uy = 330 + lean_y * 2.f;
                    if ((x - ux) * (x - ux) + (y - uy) * (y - uy) < 60 * 60) {
                        c->squish = 1;
                        bump_cool = 30;
                        sfx_note(W_SINE, 81, 0.12f, 0.2f);
                        sfx_note(W_SINE, 88, 0.08f, 0.1f);
                    }
                }
            }
            if (fly >= FLY_DONE || frame >= 1200)
                begin_door();
        } else if (phase == DOOR) {
            if (button) {
                sfx_note(W_SINE, 79, 0.1f, 0.15f);
                part_burst(W / 2 + 40, 340, 8, 2.f, 26, 3, GOLD, PART_STAR);
            }
            if (++door_t >= (fast ? DOOR_FRAMES * 5 / 8 : DOOR_FRAMES)) {
                phase = PARTY;
                music_play(&party_bed);
                music_tempo(1.f);
                cab_log("tea party");
            }
        } else {
            int prev = cab_pressed(0, CAB_LEFT) || cab_pressed(0, CAB_UP);
            int next = cab_pressed(0, CAB_RIGHT) || cab_pressed(0, CAB_DOWN);
            if (prev && !next)
                focus = (focus + ncats - 1) % ncats;
            else if (next)
                focus = (focus + 1) % ncats;
            if (prev || next)
                sfx_note(W_SINE, 72 + focus * 4, 0.12f, 0.15f);
            if (button)
                care_from_party = 1;
            if (!held)
                care_from_party = 0;
            if (care_wait > 0)
                care_wait--;
            if (care_from_party && (button || (held && care_wait == 0)))
                care(focus);
            if (react_left > 0)
                react_left--;
            if (cheer_left > 0)
                cheer_left--;
            uni_x = approach(uni_x, seat_x(focus), 0.18f);
        }
        for (int i = 0; i < CAT_MAX; i++) {
            cat_lean[i] = approach(cat_lean[i], i == focus && phase == PARTY ? 1.f : 0.f, 0.2f);
            if (delight[i] > 0)
                delight[i]--;
            if (heart_pop[i] > 0)
                heart_pop[i]--;
        }
        if (toss_t > 0)
            toss_t--;
        if (bump_cool > 0)
            bump_cool--;
        wing = sinf(frame * (held ? 0.35f : 0.16f)) * 0.7f;
        draw();
        frame++;
    }
    cab_shutdown();
    return 0;
}
