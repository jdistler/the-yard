/* Tea: a unicorn flies to a castle and takes care of the cats.
 * Little band (CONTROLS.md): any stick direction does a useful thing, every right-hand
 * button does the care, and a turn cannot be lost. Spec: DESIGN.md beside this file.
 *
 * The flight: treats float toward her along the rainbow in three lanes. Left and right
 * change lane, up and down swoop to the next treat, a button sparkles (and the sparkle
 * reaches the side lanes too). What she catches decorates the party.
 * The party: the stick visits the next cat, a button gives the picture over its head.
 * Each of a cat's three hearts asks for something different: its own wish, a cupcake,
 * a hug. When every heart glows the table cheers, a photo goes on the castle wall, and
 * the buttons play a song.
 * Upright 384x512. tea.sav remembers visits, gifts, and photos. Hearts start fresh.
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
#define DOOR_FRAMES 100
#define REACT_FRAMES 120
#define CHEER_FRAMES 200
#define CARE_GAP 30
#define LANE_X 108.f
#define MAXT 10
#define BASKET_MAX 14

enum { SKY, DOOR, PARTY };
enum { PIP, MOTH, PEARL, NIB, CAT_MAX };
enum { GIFT_NONE, GIFT_TEACUP, GIFT_RIBBON, GIFT_FLOWER };
/* Pictures: the asks, the treats, and the song. */
enum { IC_CUP, IC_YARN, IC_FLOWER, IC_SPARKLE, IC_CAKE, IC_HUG, IC_NOTE, IC_BALLOON, IC_STAR };
enum { TR_BALLOON, TR_CAKE, TR_FLOWER, TR_STAR, TR_KINDS };

static const gcol SKY_C = HEX(0x8ec6ff), CREAM = HEX(0xfff6ea), CASTLE = HEX(0xf4b6d0), ROOF = HEX(0xe86b9a),
                  GOLD = HEX(0xf2c14e), MINT = HEX(0x7ec8c3), LILAC = HEX(0xb9a0e8), TEA_C = HEX(0xc9865a),
                  ORANGE = HEX(0xf29a3a), GREY = HEX(0x8a8f9c), INK = HEX(0x3a2a44), WHITE = HEX(0xfffcf8),
                  BLUSH = HEXA(0xff8fb0, 120);

static const char *const gift_word[] = {"none", "teacup", "ribbon", "flower"};
static const char *const cat_name[] = {"Pip", "Moth", "Pearl", "Nib"};

static int phase, frame, fly, door_t, focus, ncats, visits, nib_here, photos;
static int hearts[CAT_MAX], gift[CAT_MAX], last_friend;
static int react_left, cheer_left, cheered, care_wait, care_from_party, song_i, song_mode;
static int hurry, lane, swoop_t, bump_cool, goodbye_played, stick_hold;
static int delight[CAT_MAX], heart_pop[CAT_MAX], care_kind[CAT_MAX], toss_t, toss_who, toss_kind;
static int idle_who = -1, idle_t, photo_t, sparkle_t;
static float wing, uni_x, uni_lx, cat_lean[CAT_MAX], tilt;
static char react_line[48];
static char shown[48];
static int fast;
static int got[TR_KINDS], basket[BASKET_MAX], nbasket;

typedef struct {
    float a, z, squish;
} cloud_t;
static cloud_t clouds[12];

typedef struct {
    int on, kind, lane, color; /* on: 1 floating toward her, 2 flying into the basket */
    float z, fx, fy;
    int fly_t, slot;
} treat_t;
static treat_t treats[MAXT];
static int next_treat = 40;

/* ------------------------------------------------------------------ sound */

static const sfx_song sky_bed = {
    96, 2, 2,
    {
        {"C5 . E5 . G5 . E5 . A5 . G5 . E5 . D5 . ", W_SINE, 0.09f, 0.35f, 0.02f, 0, 0, -0.2f},
        {"C3 - - - - - - - F3 - - - G3 - - - ", W_SINE, 0.08f, 0.5f, 0.05f, 0, 0, 0.2f},
    }};
static const sfx_song party_bed = {
    90, 2, 2,
    {
        {"C5 . E5 . G5 . E5 . F5 . A5 . G5 . E5 . ", W_TRI, 0.05f, 0.3f, 0.01f, 0, 0, -0.2f},
        {"C3 - - - - - - - F3 - - - G3 - - - ", W_SINE, 0.09f, 0.4f, 0.05f, 0, 0, 0.2f},
    }};
/* The party song, one note per press after the cheer. Major, pentatonic, ours. */
static const int song[] = {72, 76, 79, 76, 81, 79, 76, 72, 74, 76, 79, 84, 81, 79, 76, 79};
#define SONG_N (int)(sizeof song / sizeof song[0])

static void notes(const int *m, int n, float step, float vol) { sfx_arp(W_TRI, m, n, step, vol); }

static int wish_of(int cat) { return cat == NIB ? (last_friend == MOTH ? IC_YARN : last_friend == PEARL ? IC_FLOWER : IC_CUP) : cat == MOTH ? IC_YARN : cat == PEARL ? IC_FLOWER : IC_CUP; }

static void tune_for(int cat, int kind)
{
    int up = cat == NIB ? 7 : 0;
    if (kind == IC_CAKE) {
        int m[] = {79 + up, 76 + up, 84 + up};
        sfx_arp(W_SINE, m, 3, 0.08f, 0.26f);
        return;
    }
    if (kind == IC_HUG) {
        sfx_t purr = {W_TRI, 196.f * (up ? 1.5f : 1.f), 0, 0.6f, 0.3f, 0.05f, 0.35f, 0.5f, 16, 0.4f, 0};
        int m[] = {72 + up, 79 + up, 84 + up};
        sfx_play(&purr);
        sfx_arp(W_SINE, m, 3, 0.12f, 0.22f);
        return;
    }
    if (kind == IC_CUP) {
        sfx_t purr = {W_TRI, 196.f * (up ? 1.5f : 1.f), 0, 0.45f, 0.25f, 0.05f, 0.3f, 0.5f, 18, 0.4f, 0};
        sfx_play(&purr);
        sfx_note(W_SINE, 76 + up, 0.4f, 0.3f);
    } else if (kind == IC_YARN) {
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
    photos = 0;
    for (int i = 0; i < CAT_MAX; i++)
        gift[i] = GIFT_NONE;
    if (!f)
        return;
    while (fgets(line, sizeof line, f)) {
        char key[32], val[32];
        int n;
        if (sscanf(line, "visits %d", &n) == 1) {
            visits = n < 0 ? 0 : n > 100000 ? 100000 : n;
        } else if (sscanf(line, "photos %d", &n) == 1) {
            photos = n < 0 ? 0 : n > 100000 ? 100000 : n;
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
    fprintf(f, "photos %d\n", photos);
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

static void react(const char *s, int frames)
{
    snprintf(react_line, sizeof react_line, "%s", s);
    react_left = frames;
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

/* What the focused cat would love now, as a picture. */
static int ask_of(int who)
{
    if (hearts[who] >= 3)
        return cheered ? IC_NOTE : IC_SPARKLE;
    if (hearts[who] == 1)
        return IC_CAKE;
    if (hearts[who] == 2)
        return IC_HUG;
    return wish_of(who);
}

static const char *ask_line(int who)
{
    static char buf[48];
    int k = ask_of(who);
    if (who == NIB && k != IC_CAKE && k != IC_HUG && hearts[who] < 3)
        return "Nib copies a friend.";
    switch (k) {
    case IC_CAKE: snprintf(buf, sizeof buf, "%s wants a cupcake.", cat_name[who]); break;
    case IC_HUG: snprintf(buf, sizeof buf, "%s wants a big hug.", cat_name[who]); break;
    case IC_YARN: return "Moth wants the yarn.";
    case IC_FLOWER: return "Pearl wants a flower.";
    case IC_CUP: return "Pip would love some tea.";
    case IC_NOTE: return "Play a song for them.";
    default: snprintf(buf, sizeof buf, "%s wants to play.", cat_name[who]);
    }
    return buf;
}

static const char *care_line(int who, int kind)
{
    static char buf[48];
    switch (kind) {
    case IC_CAKE: snprintf(buf, sizeof buf, "%s ate the cupcake.", cat_name[who]); return buf;
    case IC_HUG: return "A big unicorn hug!";
    case IC_SPARKLE: snprintf(buf, sizeof buf, "%s does a little dance.", cat_name[who]); return buf;
    default: break;
    }
    if (who == NIB)
        return "Nib bumped her nose.";
    if (kind == IC_YARN)
        return "The yarn rolled back.";
    if (kind == IC_FLOWER)
        return "Pearl wears a flower.";
    return "Pip sipped her tea.";
}

static const char *treat_line(int kind)
{
    static const char *l[] = {"A balloon for the party!", "A cupcake for the party!", "Flowers for the party!",
                              "A star for the party!"};
    return l[kind];
}

static const char *rest_line(void)
{
    int who;
    if (cab_down(0, CAB_1P) && cab_down(0, CAB_2P))
        return "They will keep the gifts.";
    if (phase == SKY) {
        if (hurry)
            return "The party is waiting.";
        if (swoop_t > 0)
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
    return ask_line(focus);
}

/* ------------------------------------------------------------------ the party's rules */

static float seat_x(int i)
{
    if (ncats == 4)
        return 60.f + i * 88.f;
    return 72.f + i * 120.f;
}

static float head_y(int i) { return i == focus ? 236.f : 226.f; }

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
    cab_log("tea treats %d", nbasket);
    music_stop();
    {
        int m[] = {72, 76, 79};
        notes(m, 3, 0.12f, 0.3f);
    }
    {
        int who = runner();
        if (who >= 0)
            tune_for(who, wish_of(who));
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

static void play_song_note(int who)
{
    int m = song[song_i % SONG_N];
    sfx_note(W_TRI, m, 0.45f, 0.4f);
    sfx_note(W_SINE, m - 12, 0.5f, 0.15f);
    song_i++;
    delight[who] = 30;
    care_kind[who] = IC_NOTE;
    {
        gpart *p = part_spawn(seat_x(who) + rng_range(-10, 10), head_y(who) - 40, rng_range(-0.6f, 0.6f), -1.2f, 70,
                              6, col_hsv(song_i * 0.13f, 0.5f, 1.f), PART_STAR);
        p->drag = 0.99f;
    }
    if (song_i % SONG_N == 0) {
        for (int i = 0; i < 24; i++) {
            gpart *p = part_spawn(rng_range(20, W - 20), rng_range(-20, 20), rng_range(-0.5f, 0.5f), rng_range(0.6f, 1.6f),
                                  140, rng_range(3, 5), col_hsv(rng_f(), 0.45f, 1.f), i % 2 ? PART_HEART : PART_STAR);
            p->drag = 1.f;
        }
        react("They loved the song!", REACT_FRAMES);
        cab_log("tea song");
    } else
        react("La la la!", 40);
}

static void care(int who)
{
    int filled = 0, kind = ask_of(who);
    if (who != NIB)
        last_friend = who;
    if (song_mode) {
        play_song_note(who);
        care_wait = CARE_GAP / 2;
        return;
    }
    if (kind == IC_CUP || kind == IC_YARN || kind == IC_FLOWER)
        give_gift(who);
    if (hearts[who] < 3) {
        hearts[who]++;
        filled = hearts[who] == 3;
        heart_pop[who] = 18;
        if (hearts[who] == 1)
            sfx_note(W_SINE, 96, 0.15f, 0.12f);
    }
    delight[who] = 50;
    care_kind[who] = kind;
    toss_t = 18;
    toss_who = who;
    toss_kind = kind;
    cab_log("tea heart %s %d", cat_name[who], hearts[who]);
    tune_for(who, kind);
    part_burst(seat_x(who), head_y(who) - 30, 10, 2.f, 34, 4.f, col_alpha(ROOF, 230), PART_HEART);
    if (kind == IC_FLOWER)
        part_burst(seat_x(who), head_y(who) - 24, 12, 2.5f, 30, 3.f, HEX(0xff9ac8), PART_DOT);
    if (kind == IC_CAKE)
        part_burst(seat_x(who), head_y(who) + 14, 8, 1.5f, 24, 2.f, HEX(0xffe0a0), PART_SQUARE);
    if (all_full() && !cheered) {
        int m[] = {72, 76, 79, 84};
        cheered = 1;
        cheer_left = CHEER_FRAMES;
        react("The whole table glows.", CHEER_FRAMES / 2);
        notes(m, 4, 0.14f, 0.32f);
        for (int i = 0; i < 40; i++) {
            gpart *p = part_spawn(rng_range(20, W - 20), rng_range(-20, 40), rng_range(-0.5f, 0.5f), rng_range(0.5f, 1.5f),
                                  140, rng_range(3, 5), col_hsv(rng_f(), 0.4f, 1.f), i % 2 ? PART_HEART : PART_STAR);
            p->drag = 1.f;
            p->spin = rng_range(-0.1f, 0.1f);
        }
        photo_t = 1;
        save_tea();
        cab_log("tea cheer");
    } else {
        react(filled ? "" : care_line(who, kind), REACT_FRAMES);
        if (filled) {
            snprintf(react_line, sizeof react_line, "%s is so happy.", cat_name[who]);
        }
        save_tea();
    }
    care_wait = CARE_GAP;
}

/* ------------------------------------------------------------------ pictures */

static void icon(int what, float cx, float cy, float s)
{
    /* About 40 pixels across at s = 1. */
    toon_t = 2.f * s;
    if (what == IC_SPARKLE) {
        gfx_glow(cx, cy, 28 * s, HEXA(0xffe080, 140));
        gfx_star(cx, cy, 15 * s * (1 + 0.1f * sinf(frame * 0.2f)), frame * 0.03f, GOLD);
        return;
    }
    if (what == IC_STAR) {
        gfx_star(cx, cy, 15 * s, 0, INK);
        gfx_star(cx, cy, 12 * s, 0, GOLD);
        gfx_circle(cx - 3 * s, cy - 3 * s, 2.5f * s, HEXA(0xffffff, 200));
        return;
    }
    if (what == IC_HUG) {
        gfx_heart(cx, cy, 15 * s, INK);
        gfx_heart(cx, cy, 12.5f * s, ROOF);
        gfx_circle(cx - 6 * s, cy - 6 * s, 3 * s, HEXA(0xffffff, 200));
        return;
    }
    for (toon_pass = 0; toon_pass < 2; toon_pass++) {
        if (what == IC_CUP) {
            toon_ellipse(cx, cy + 12 * s, 18 * s, 4 * s, HEX(0xffd0e6));
            toon_rrect(cx - 13 * s, cy - 8 * s, 26 * s, 20 * s, 7 * s, WHITE);
            toon_circle(cx + 15 * s, cy + 1 * s, 6 * s, WHITE);
            if (toon_pass) {
                gfx_circle(cx + 15 * s, cy + 1 * s, 3 * s, SKY_C);
                gfx_ellipse(cx, cy - 6 * s, 11 * s, 3 * s, TEA_C);
                gfx_rect((int)(cx - 12 * s), (int)(cy + 1 * s), (int)(24 * s), (int)(4 * s), ROOF);
            }
        } else if (what == IC_YARN) {
            toon_circle(cx, cy, 15 * s, GOLD);
            if (toon_pass) {
                gfx_line(cx - 12 * s, cy - 6 * s, cx + 8 * s, cy + 12 * s, 2 * s, HEX(0xd89a2a));
                gfx_line(cx - 6 * s, cy - 13 * s, cx + 13 * s, cy + 6 * s, 2 * s, HEX(0xd89a2a));
                gfx_line(cx - 14 * s, cy + 3 * s, cx + 2 * s, cy + 14 * s, 2 * s, HEX(0xd89a2a));
                gfx_line(cx + 12 * s, cy + 8 * s, cx + 22 * s, cy + 14 * s, 2 * s, GOLD);
            }
        } else if (what == IC_FLOWER) {
            toon_line(cx, cy + 4 * s, cx, cy + 20 * s, 3 * s, HEX(0x5ab05a));
            for (int k = 0; k < 5; k++) {
                float a = k * 1.2566f + frame * 0.01f;
                toon_circle(cx + cosf(a) * 8 * s, cy + sinf(a) * 8 * s, 7 * s, ROOF);
            }
            toon_circle(cx, cy, 6 * s, GOLD);
        } else if (what == IC_CAKE) {
            toon_rrect(cx - 12 * s, cy, 24 * s, 14 * s, 3 * s, HEX(0xf4b070));
            toon_ellipse(cx, cy - 1 * s, 15 * s, 9 * s, HEX(0xffd0e6));
            toon_circle(cx, cy - 11 * s, 4.5f * s, HEX(0xff4060));
            if (toon_pass) {
                for (int k = 0; k < 4; k++)
                    gfx_line(cx - 8 * s + k * 5.5f * s, cy + 2 * s, cx - 9 * s + k * 5.5f * s, cy + 12 * s, 1.5f * s,
                             HEX(0xd08a50));
                gfx_circle(cx - 6 * s, cy - 3 * s, 1.5f * s, MINT);
                gfx_circle(cx + 5 * s, cy - 4 * s, 1.5f * s, GOLD);
                gfx_circle(cx + 1 * s, cy + 1 * s, 1.5f * s, LILAC);
            }
        } else if (what == IC_NOTE) {
            toon_ellipse(cx - 6 * s, cy + 10 * s, 7 * s, 5.5f * s, LILAC);
            toon_line(cx, cy + 9 * s, cx, cy - 14 * s, 3 * s, LILAC);
            toon_line(cx, cy - 14 * s, cx + 10 * s, cy - 8 * s, 4 * s, LILAC);
        } else if (what == IC_BALLOON) {
            toon_ellipse(cx, cy - 4 * s, 12 * s, 15 * s, ROOF);
            toon_tri(cx - 3 * s, cy + 13 * s, cx + 3 * s, cy + 13 * s, cx, cy + 9 * s, ROOF);
            if (toon_pass)
                gfx_ellipse(cx - 4 * s, cy - 9 * s, 3 * s, 5 * s, HEXA(0xffffff, 170));
        }
    }
}

static gcol balloon_col(int i)
{
    static const gcol c[] = {0xffe86b9a, 0xff7ec8c3, 0xffb9a0e8, 0xfff2c14e, 0xff8ac8ff};
    return c[i % 5];
}

static void balloon(float x, float y, float s, gcol c)
{
    toon_t = 2.f * s;
    for (toon_pass = 0; toon_pass < 2; toon_pass++) {
        toon_ellipse(x, y, 13 * s, 16 * s, c);
        toon_tri(x - 3 * s, y + 18 * s, x + 3 * s, y + 18 * s, x, y + 14 * s, c);
    }
    gfx_ellipse(x - 4 * s, y - 6 * s, 3 * s, 5 * s, HEXA(0xffffff, 170));
}

static int treat_icon(int kind) { return kind == TR_BALLOON ? IC_BALLOON : kind == TR_CAKE ? IC_CAKE : kind == TR_FLOWER ? IC_FLOWER : IC_STAR; }

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
    if (happy && care_kind[who] == IC_FLOWER && delight[who] > 0)
        twirl = 0.75f + 0.25f * fabsf(cosf(delight[who] * 0.2f));
    toon_t = 2.5f;
    for (toon_pass = 0; toon_pass < 2; toon_pass++) {
        /* Tail: curls out from behind the hip. */
        toon_line(cx + r * 0.7f, cy + r * 1.95f, cx + r * 1.4f, cy + r * 1.95f, 8 * s, body);
        toon_line(cx + r * 1.4f, cy + r * 1.95f, cx + r * 1.62f + tail * r * 0.15f, cy + r * 1.62f, 8 * s, body);
        toon_circle(cx + r * 1.62f + tail * r * 0.15f, cy + r * 1.58f, 4.5f * s, who == PEARL ? WHITE : dark);
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
    {
        /* A cat smile: a small w under the nose, wider when happy. */
        float my = cy + r * 0.36f, mw = happy ? 5.5f * s : 4.5f * s, dip = happy ? 4.f * s : 3.f * s;
        gfx_line(cx, my, cx - mw * 0.5f, my + dip, 1.6f * s, INK);
        gfx_line(cx - mw * 0.5f, my + dip, cx - mw, my + dip * 0.2f, 1.6f * s, INK);
        gfx_line(cx, my, cx + mw * 0.5f, my + dip, 1.6f * s, INK);
        gfx_line(cx + mw * 0.5f, my + dip, cx + mw, my + dip * 0.2f, 1.6f * s, INK);
        if (happy)
            gfx_ellipse(cx, my + dip * 0.9f, 2.2f * s, 1.6f * s, HEX(0xff8fa8));
    }
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
    /* A sip, a bite: the cup or the cupcake at the mouth, then a milk mustache or crumbs. */
    if (delight[who] > 0 && (care_kind[who] == IC_CUP || care_kind[who] == IC_CAKE)) {
        if (delight[who] > 24)
            icon(care_kind[who], cx + 4 * s, cy + r * 0.55f, 0.5f * s);
        else if (care_kind[who] == IC_CUP)
            gfx_ellipse(cx, cy + r * 0.42f, r * 0.4f, 3 * s, WHITE);
        else
            for (int k = 0; k < 4; k++)
                gfx_circle(cx - 6 * s + k * 4 * s, cy + r * 0.5f + (k % 2) * 2 * s, 1.5f * s, HEX(0xe8b070));
    }
}

static void hearts_row(int who, float cx, float y)
{
    for (int i = 0; i < 3; i++) {
        float x = cx - 32 + i * 32;
        float pop = (i == hearts[who] - 1 && heart_pop[who] > 0) ? 1 + 0.6f * sinf(heart_pop[who] * 0.18f) : 1;
        gfx_heart(x, y, 12.5f * pop, INK);
        gfx_heart(x, y, 10 * pop, i < hearts[who] ? ROOF : CREAM);
        if (i < hearts[who])
            gfx_circle(x - 4.5f * pop, y - 4.5f * pop, 2.2f * pop, HEXA(0xffffff, 190));
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

/* A photo of an earlier party, in a gold frame on the castle wall. */
static void photo(float x, float y, int seed)
{
    gfx_rrect_o(x, y, 26, 22, 2, HEX(0xfff6ea), HEX(0xd8a03a), 2);
    gfx_rect((int)x + 3, (int)y + 3, 20, 13, HEX(0xbfe2ff));
    gfx_circle(x + 8, y + 12, 3.5f, seed % 2 ? ORANGE : GREY);
    gfx_circle(x + 14, y + 11, 3.5f, WHITE);
    gfx_circle(x + 20, y + 12, 3.5f, seed % 3 ? GREY : ORANGE);
    gfx_heart(x + 13, y + 5, 2.5f, ROOF);
}

static void photo_slot(int i, float *x, float *y)
{
    /* Two columns each side of the middle tower, three high. */
    int side = i % 2, row = (i / 2) % 3, col = (i / 6) % 2;
    *x = side ? 246.f + col * 30 : 110.f - col * 30;
    *y = 96.f + row * 26;
}

static void paint_party(void)
{
    gfx_vgrad(0, 0, W, 200, HEX(0x8ec6ff), HEX(0xd8ecff));
    castle(W / 2, 200, 1.15f, 1);
    for (int i = 0; i < photos && i < 12; i++) {
        float x, y;
        photo_slot(i, &x, &y);
        photo(x, y, i);
    }
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

/* ------------------------------------------------------------------ the flight */

/* Treats come from the castle and meet her at head height, as big as her head. */
static float treat_x(const treat_t *t)
{
    float k = t->z / 0.85f;
    return W / 2 + t->lane * LANE_X * k * k;
}
static float treat_y(const treat_t *t) { return 165 + 95 * powf(t->z / 0.85f, 1.4f); }
static float treat_s(const treat_t *t) { return 0.35f + t->z * 1.35f; }

static void spawn_treat(void)
{
    for (int i = 0; i < MAXT; i++)
        if (!treats[i].on) {
            int r = rng_int(0, 99);
            treats[i].on = 1;
            treats[i].z = 0.02f;
            treats[i].lane = r < 50 ? 0 : r < 75 ? -1 : 1;
            treats[i].kind = rng_int(0, TR_KINDS - 1);
            treats[i].color = rng_int(0, 4);
            return;
        }
}

/* The next treat coming, for the swoop and for the built-in player. */
static treat_t *next_coming(void)
{
    treat_t *best = NULL;
    for (int i = 0; i < MAXT; i++)
        if (treats[i].on == 1 && treats[i].z < 0.8f && (!best || treats[i].z > best->z))
            best = &treats[i];
    return best;
}

static void catch_treat(treat_t *t)
{
    static const int pent[] = {72, 74, 76, 79, 81, 84, 86, 88, 91, 93, 96};
    t->fx = treat_x(t);
    t->fy = treat_y(t);
    t->on = 2;
    t->fly_t = 0;
    t->slot = nbasket < BASKET_MAX ? nbasket : BASKET_MAX - 1;
    got[t->kind]++;
    if (nbasket < BASKET_MAX)
        basket[nbasket++] = t->kind;
    sfx_note(W_TRI, pent[(nbasket - 1) % 11], 0.3f, 0.35f);
    sfx_note(W_SINE, pent[(nbasket - 1) % 11] + 12, 0.2f, 0.12f);
    part_burst(treat_x(t), treat_y(t), 14, 2.5f, 30, 3.f, t->kind == TR_BALLOON ? balloon_col(t->color) : GOLD,
               PART_STAR);
    react(treat_line(t->kind), 70);
    cab_log("tea treat %d", t->kind);
}

static void sky_step(int held, int button)
{
    float speed;
    int prev = lane;
    if (cab_pressed(0, CAB_LEFT))
        lane = lane > -1 ? lane - 1 : -1;
    if (cab_pressed(0, CAB_RIGHT))
        lane = lane < 1 ? lane + 1 : 1;
    if (cab_pressed(0, CAB_UP) || cab_pressed(0, CAB_DOWN)) {
        /* Up and down swoop to wherever the next treat is coming. */
        treat_t *t = next_coming();
        lane = t ? t->lane : 0;
    }
    if (lane != prev || cab_pressed(0, CAB_UP) || cab_pressed(0, CAB_DOWN)) {
        swoop_t = 40;
        sfx_slide(W_SINE, 600, 900, 0.15f, 0.12f);
    }
    if (swoop_t > 0)
        swoop_t--;
    if (button) {
        sparkle_t = 50;
        sfx_slide(W_SINE, 900, 1500, 0.15f, 0.12f);
        part_burst(uni_x, 250, 10, 2.f, 30, 3, GOLD, PART_STAR);
    }
    if (sparkle_t > 0)
        sparkle_t--;
    uni_lx = approach(uni_lx, lane * LANE_X, 0.16f);
    tilt = approach(tilt, (lane * LANE_X - uni_lx) * 0.02f, 0.2f);
    uni_x = W / 2 + uni_lx;
    {
        int step = held ? HURRY_STEP : SKY_STEP;
        if (fast)
            step = step * 8 / 5;
        fly += step;
        if (fly > FLY_DONE)
            fly = FLY_DONE;
    }
    speed = held ? 0.012f : 0.007f;
    music_tempo(held ? 1.4f : 1.f);
    /* Clouds fly past. Bump a big one and it squishes and giggles. */
    for (int i = 0; i < 12; i++) {
        cloud_t *c = &clouds[i];
        c->z += speed * (0.4f + c->z);
        if (c->squish > 0)
            c->squish *= 0.9f;
        if (c->z > 1.25f) {
            c->z = 0.02f;
            c->a = rng_range(0, 6.28f);
        }
        if (c->z > 0.75f && c->z < 0.95f && bump_cool == 0) {
            float d = c->z * c->z * 340;
            float x = W / 2 + cosf(c->a) * d * 1.2f, y = 140 + sinf(c->a) * d * 0.7f + c->z * 60;
            if ((x - uni_x) * (x - uni_x) + (y - 330) * (y - 330) < 50 * 50) {
                c->squish = 1;
                bump_cool = 40;
                sfx_note(W_SINE, 81, 0.12f, 0.15f);
                sfx_note(W_SINE, 88, 0.08f, 0.08f);
            }
        }
    }
    /* Treats along the rainbow. The sparkle reaches the next lane too. */
    if (--next_treat <= 0 && fly < FLY_DONE * 92 / 100) {
        spawn_treat();
        next_treat = held ? 34 : 52;
    }
    for (int i = 0; i < MAXT; i++) {
        treat_t *t = &treats[i];
        if (t->on == 2) {
            if (++t->fly_t >= 26)
                t->on = 0;
            continue;
        }
        if (!t->on)
            continue;
        t->z += (held ? 0.0135f : 0.0085f) * (fast ? 1.4f : 1.f);
        if (t->z > 0.8f && t->z < 0.92f) {
            int reach = sparkle_t > 0 ? 1 : 0;
            float ux = uni_lx / LANE_X;
            if (fabsf(t->lane - ux) <= 0.5f + reach)
                catch_treat(t);
        }
        if (t->z > 1.15f)
            t->on = 0;
    }
    if (fly >= FLY_DONE || frame >= 1300)
        begin_door();
}

static void draw_treat(const treat_t *t)
{
    float s = treat_s(t), x = treat_x(t), y = treat_y(t) + sinf(frame * 0.1f + t->color) * 4 * t->z;
    if (t->on == 2) {
        /* Into the basket: an arc down to its slot, shrinking. */
        float k = ease_in_out(t->fly_t / 26.f);
        float bx = 22 + t->slot * 26, by = H - BAND - 18;
        s = lerpf(1.2f, 0.5f, k);
        x = lerpf(t->fx, bx, k);
        y = lerpf(t->fy, by, k) - sinf(k * 3.14159f) * 50;
    }
    if (t->z > 0.2f)
        gfx_glow(x, y, 26 * s, HEXA(0xfff0b0, 110));
    if (t->kind == TR_BALLOON)
        balloon(x, y, s, balloon_col(t->color));
    else
        icon(treat_icon(t->kind), x, y, s);
}

static void draw_basket(void)
{
    if (!nbasket)
        return;
    gfx_rrect(6, H - BAND - 36, 18 + nbasket * 26, 34, 12, HEXA(0xfff6ea, 210));
    for (int i = 0; i < nbasket; i++) {
        float x = 22 + i * 26, y = H - BAND - 18;
        if (phase == SKY)
            for (int k = 0; k < MAXT; k++)
                if (treats[k].on == 2 && treats[k].slot == i)
                    goto next; /* still flying in */
        if (basket[i] == TR_BALLOON)
            balloon(x, y - 1, 0.5f, balloon_col(i));
        else
            icon(treat_icon(basket[i]), x, y, 0.5f);
    next:;
    }
}

static void draw_sky(void)
{
    float prog = (float)fly / FLY_DONE;
    float cs = 0.22f + prog * 0.55f;
    cached(0, paint_sky);
    {
        static const gcol rb[6] = {0xffff8a8a, 0xffffc070, 0xfffff08a, 0xff9ae6a0, 0xff8ac8ff, 0xffc0a0f0};
        float top = 150 + prog * 40, far_w = 4 + prog * 10;
        for (int k = 0; k < 6; k++) {
            float a0 = (k - 3) / 3.f, a1 = (k - 2) / 3.f;
            float p[8] = {W / 2 + a0 * far_w, top, W / 2 + a1 * far_w, top, W / 2 + a1 * 150, H - BAND,
                          W / 2 + a0 * 150, H - BAND};
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
    }
    for (int pass = 0; pass < 2; pass++)
        for (int i = 0; i < 12; i++) {
            cloud_t *c = &clouds[i];
            float z = c->z, d = z * z * 340;
            float x = W / 2 + cosf(c->a) * d * 1.2f, y = 140 + sinf(c->a) * d * 0.7f + z * 60;
            if ((pass == 0) != (z < 0.6f))
                continue;
            cloud(x, y, 0.25f + z * 1.3f, c->squish);
        }
    /* Far treats behind her, near ones in front. */
    for (int i = 0; i < MAXT; i++)
        if (treats[i].on == 1 && treats[i].z <= 0.6f)
            draw_treat(&treats[i]);
    if (sparkle_t > 0)
        gfx_glow(uni_x, 320, 90, HEXA(0xffe8a0, (int)(sparkle_t * 2.5f)));
    unicorn_at(uni_x, 330 - fabsf(tilt) * 10, 1.15f, 1, wing, sparkle_t > 0 ? 2 : 0);
    draw_basket();
    for (int i = 0; i < MAXT; i++)
        if ((treats[i].on == 1 && treats[i].z > 0.6f) || treats[i].on == 2)
            draw_treat(&treats[i]);
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
            cat(i, lerpf(x, W / 2 - 60, run), lerpf(300 - 18 * peek, 360, run) - fabsf(sinf(door_t * 0.4f)) * 8 * run,
                lerpf(0.5f, 1.f, run), run > 0.6f);
        } else
            cat(i, x, 300 - 16 * peek, 0.5f, door_t > 70);
    }
    unicorn_at(W / 2 + 40, 400, 1.f, 0, sinf(frame * 0.05f) * 0.7f, who >= 0 && door_t > 60 ? 2 : 0);
    draw_basket();
}

static void draw_decor(float hop)
{
    /* What she caught on the way: balloons by the chairs, cupcakes on the cloth,
     * flowers in a vase, stars along the bunting. */
    static const float bx[] = {20, 364, 132, 252, 192, 46, 338};
    for (int i = 0; i < got[TR_BALLOON] && i < 7; i++) {
        float x = bx[i], y = 128 + (i % 3) * 10 + sinf(frame * 0.04f + i) * 4;
        gfx_line(x, y + 18, x + sinf(i) * 6, 284, 1, HEXA(0x3a2a44, 160));
        balloon(x, y, 0.95f, balloon_col(i));
    }
    for (int i = 0; i < got[TR_STAR] && i < 10; i++) {
        float x = 26 + i * 36, y = 182 + sinf(i * 0.9f) * 3;
        float tw = 0.7f + 0.3f * sinf(frame * 0.12f + i * 1.7f);
        gfx_line(x, 170, x, y - 6, 1, HEXA(0x3a2a44, 140));
        gfx_glow(x, y, 12, col_alpha(HEX(0xffe080), (int)(tw * 150)));
        gfx_star(x, y, 6, 0, GOLD);
    }
    if (got[TR_FLOWER]) {
        float vx = ncats == 4 ? W - 26 : 30, vy = 274;
        int n = got[TR_FLOWER] < 6 ? got[TR_FLOWER] : 6;
        for (int i = 0; i < n; i++) {
            float a = -1.9f + i * 0.35f;
            float fx = vx + cosf(a) * 18, fy = vy - 14 + sinf(a) * 18;
            gfx_line(vx, vy - 6, fx, fy, 2, HEX(0x5ab05a));
            gfx_circle_o(fx, fy, 5, i % 2 ? HEX(0xff9ac8) : HEX(0xfff09a), INK, 1.5f);
        }
        gfx_rrect_o(vx - 8, vy - 8, 16, 18, 5, MINT, INK, 2);
    }
    {
        int n = got[TR_CAKE] < 4 ? got[TR_CAKE] : 4;
        static const float cx3[] = {132, 252, 30, 354}, cx4[] = {104, 192, 280, 16};
        for (int i = 0; i < n; i++)
            icon(IC_CAKE, ncats == 4 ? cx4[i] : cx3[i], 286 - hop * (i % 2), 0.55f);
    }
}

static void draw_party(void)
{
    float hop = cheer_left ? fabsf(sinf(frame * 0.3f)) * 8 : 0;
    float beat = song_mode ? sinf(frame * 0.2f) : 0;
    int waving = cab_quit_progress() > 0;
    cached(2, paint_party);
    draw_decor(hop);
    {
        float fx = seat_x(focus), pulse = 1 + 0.06f * sinf(frame * 0.12f);
        gfx_glow(fx, head_y(focus) + 10, 70 * pulse, HEXA(0xfff0a0, 150));
        gfx_ring(fx, head_y(focus) + 6, 44 * pulse, 4, HEXA(0xffe070, 230));
    }
    for (int i = 0; i < ncats; i++) {
        float lean = cat_lean[i];
        int happy = cheer_left > 0 || delight[i] > 0 || waving;
        float bob = song_mode ? (i % 2 ? beat : -beat) * 5 : 0;
        float tiltx = (i == idle_who && idle_t > 0) ? sinf(idle_t * 0.25f) * 4 : 0;
        float nib_bump = (i == NIB && delight[i] > 25) ? 10 : 0;
        if (i == NIB)
            gfx_ellipse_o(seat_x(i), 276, 30, 10, LILAC, INK, 2);
        cat(i, seat_x(i) + tiltx + bob * 0.5f, head_y(i) - lean * 6 - (cheer_left ? hop : 0) + nib_bump * 0.3f + bob,
            1.f + lean * 0.12f, happy);
    }
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
        float wave = waving ? -fabsf(sinf(frame * 0.3f + i)) * 22 : 0;
        gfx_ellipse_o(x - 14, y, 9, 6, body, INK, 2);
        gfx_ellipse_o(x + 14, y + wave, 9, 6, body, INK, 2);
    }
    {
        float tx = ncats == 4 ? W / 2 : W / 2 - 60, ty = 268 - hop;
        float cx2 = ncats == 4 ? 104 : W / 2 + 60;
        toon_t = 2;
        for (toon_pass = 0; toon_pass < 2; toon_pass++) {
            toon_line(tx + 14, ty, tx + 26, ty - 10, 4, HEX(0xffd0e6));
            toon_ellipse(tx, ty, 16, 13, HEX(0xffd0e6));
            toon_circle(tx, ty - 14, 4, GOLD);
        }
        if (ncats == 3 && got[TR_CAKE] == 0)
            icon(IC_CAKE, cx2, 270 - hop, 0.6f);
        for (int k = 0; k < 3; k++) {
            float sy = fmodf(frame * 0.6f + k * 12, 36);
            gfx_circle(tx + 24 + sinf(frame * 0.05f + k) * 3, ty - 14 - sy, 4 - sy * 0.08f,
                       col_alpha(WHITE, 220 - (int)(sy * 6)));
        }
        if (cheer_left)
            for (int k = 0; k < 8; k++) {
                float a = frame * 0.15f + k * 0.785f;
                gfx_star(tx + 24 + cosf(a) * 22, ty - 40 + sinf(a) * 10, 4, a, GOLD);
            }
    }
    {
        /* Moth's yarn ball: it rolls away and comes back, and bounces when she plays. */
        int moth_yarn = care_kind[MOTH] == IC_YARN && delight[MOTH] > 0;
        float t = moth_yarn ? (50 - delight[MOTH]) / 50.f : 0;
        float roll = moth_yarn ? sinf(t * 3.14159f) * 46 : sinf(frame * 0.05f) * 3;
        float up = moth_yarn ? fabsf(sinf(t * 9.42f)) * 14 * (1 - t) : 0;
        float yx = seat_x(MOTH) + 34 + roll;
        gfx_circle_o(yx, 290 - up, 9, GOLD, INK, 2);
        gfx_line(yx - 6, 286 - up, yx + 5, 295 - up, 1.5f, HEX(0xd89a2a));
        if (gift[MOTH] == GIFT_RIBBON) {
            gfx_tri(yx, 282 - up, yx - 9, 277 - up, yx - 8, 287 - up, ROOF);
            gfx_tri(yx, 282 - up, yx + 9, 277 - up, yx + 8, 287 - up, ROOF);
        }
    }
    {
        /* The ask: a picture in a bubble over the focused cat, then her hearts. */
        float fx = seat_x(focus), hy = head_y(focus);
        float bob = sinf(frame * 0.08f) * 3;
        float grow = care_wait > CARE_GAP - 8 ? 0.85f + 0.15f * (CARE_GAP - care_wait) / 8.f : 1.f;
        gfx_circle_o(fx, hy - 118 + bob, 32 * grow, WHITE, INK, 2.5f);
        gfx_tri(fx - 8, hy - 90 + bob, fx + 8, hy - 90 + bob, fx, hy - 78 + bob, INK);
        gfx_tri(fx - 6, hy - 91 + bob, fx + 6, hy - 91 + bob, fx, hy - 82 + bob, WHITE);
        icon(ask_of(focus), fx, hy - 118 + bob, 1.1f * grow);
        hearts_row(focus, fx, hy - 58);
    }
    {
        /* The unicorn trots to the cat she is visiting; a hug brings her right up close. */
        float target = seat_x(focus);
        int moving = fabsf(target - uni_x) > 3;
        int hug = care_kind[focus] == IC_HUG && delight[focus] > 10;
        float trot = moving ? fabsf(sinf(frame * 0.45f)) * 8 : 0;
        int pose = cheer_left ? 3 : (react_left > REACT_FRAMES - 30 || hug) ? 2 : 0;
        unicorn_at(uni_x, 420 - trot - (hug ? 22 + 10 * sinf(delight[focus] * 0.3f) : 0), 0.95f, 0, sinf(frame * 0.05f) * 0.7f, pose);
        if (hug)
            for (int k = 0; k < 2; k++)
                if ((frame + k * 7) % 14 == 0)
                    part_spawn(uni_x + rng_range(-20, 20), 300, rng_range(-0.5f, 0.5f), -1.2f, 50, 6, ROOF, PART_HEART);
    }
    if (toss_t > 0 && toss_kind != IC_HUG) {
        float k = 1 - toss_t / 18.f;
        float sx = uni_x, sy = 350, ex = seat_x(toss_who), ey = head_y(toss_who) + 10;
        icon(toss_kind, lerpf(sx, ex, k), lerpf(sy, ey, k) - sinf(k * 3.14159f) * 60, 0.6f);
    }
    if (photo_t > 0) {
        /* The photo floats up to its place on the wall. */
        float x, y, k = clampf(photo_t / 80.f, 0, 1);
        photo_slot(photos, &x, &y);
        gfx_glow(lerpf(W / 2, x + 13, ease_in_out(k)), lerpf(260, y + 11, ease_in_out(k)), 30, HEXA(0xffffff, 160));
        photo(lerpf(W / 2 - 13, x, ease_in_out(k)), lerpf(250, y, ease_in_out(k)), photos);
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
    if (react_left && phase != DOOR && !(cab_down(0, CAB_1P) && cab_down(0, CAB_2P)))
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
        treat_t *t = next_coming();
        if (t && t->lane != lane && frame % 6 == 0)
            cab_bot(t->lane < lane ? CAB_LEFT : CAB_RIGHT, 1);
        if ((frame / 50) % 3 == 1)
            cab_bot(CAB_LOW, 1);
        return;
    }
    if (phase != PARTY)
        return;
    if (frame % 24 == 0)
        cab_bot(hearts[focus] < 3 || song_mode ? CAB_LOW : CAB_RIGHT, 1);
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
        if (phase == SKY) {
            sky_step(held, button);
        } else if (phase == DOOR) {
            if (button) {
                sfx_note(W_SINE, 79, 0.1f, 0.15f);
                part_burst(W / 2 + 40, 340, 8, 2.f, 26, 3, GOLD, PART_STAR);
            }
            if (++door_t >= (fast ? DOOR_FRAMES * 5 / 8 : DOOR_FRAMES)) {
                phase = PARTY;
                music_play(&party_bed);
                music_tempo(1.f);
                uni_x = seat_x(focus);
                cab_log("tea party");
            }
        } else {
            int l = cab_down(0, CAB_LEFT) || cab_down(0, CAB_UP), r = cab_down(0, CAB_RIGHT) || cab_down(0, CAB_DOWN);
            int prev = cab_pressed(0, CAB_LEFT) || cab_pressed(0, CAB_UP);
            int next = cab_pressed(0, CAB_RIGHT) || cab_pressed(0, CAB_DOWN);
            /* A held stick walks on to the next cat about twice a second. */
            if (l || r) {
                if (++stick_hold > 30 && stick_hold % 30 == 0) {
                    prev = l && !r;
                    next = r;
                }
            } else
                stick_hold = 0;
            if (prev && !next)
                focus = (focus + ncats - 1) % ncats;
            else if (next)
                focus = (focus + 1) % ncats;
            if (prev || next) {
                sfx_note(W_SINE, 72 + focus * 4, 0.12f, 0.15f);
                cab_log("tea focus %s", cat_name[focus]);
            }
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
            if (cheer_left > 0 && --cheer_left == 0) {
                song_mode = 1;
                react("Play a song for them.", REACT_FRAMES);
            }
            if (photo_t > 0 && ++photo_t > 80) {
                photo_t = 0;
                photos++;
                gfx_surf_free(bg[2]);
                bg[2] = NULL;
                save_tea();
                sfx_note(W_SINE, 91, 0.1f, 0.15f);
                cab_log("tea photo %d", photos);
            }
            if (idle_t > 0)
                idle_t--;
            else if (frame % 130 == 0) {
                idle_who = (idle_who + 1 + rng_int(0, ncats - 1)) % ncats;
                if (idle_who == focus)
                    idle_who = (idle_who + 1) % ncats;
                idle_t = 40;
            }
            uni_x = approach(uni_x, seat_x(focus), 0.16f);
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
