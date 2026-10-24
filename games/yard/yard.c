/* The Yard: the little menu that opens when Dig Dug II is chosen.
 *
 * A night yard. A lantern hangs beside the highlighted game. Each row shows what the
 * game is, who it is for, and what it remembers (the best score, the gems, the visits).
 * The stick moves the lantern (held, it repeats). The lower button, or either button
 * beside it, opens the game. Hold 1-player and 2-player to go back to the stock menu.
 * yard.sav stores the last highlighted row in the same "best N" file the games use.
 */
#include "gfx.h"
#include "sfx.h"

#include <math.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#define W 240
#define H 320

static const gcol INK = HEX(0x1a1230), CREAM = HEX(0xfff6ea), GOLD = HEX(0xffd257), DIM = HEX(0x8f8bb0);

enum { G_KEEP, G_LAMP, G_ORB, G_TEA, G_CHEST, N };
static const char *ids[N] = {"keep", "lamp", "orb", "tea", "chest"};
static const char *titles[N] = {"Keep", "Lamp", "Orb", "Tea", "Chest"};
static const char *blurbs[N] = {"catch the falling fruit", "wake the sleeping stars", "dive down the glowing well",
                                "tea with the cats", "the key, the chest, Zam"};
static const char *bands[N] = {"ALL", "ALL", "8+", "4+", "5+"};
static const gcol tints[N] = {HEX(0xff7a59), HEX(0xffc94a), HEX(0xa98bff), HEX(0xff9ccf), HEX(0x7fd6a0)};

static int row, pocket, frame;
static float shown_row, lantern_swing;
static char stat[N][24];
static const char *note;
static int note_left, hold_frames;
static float sel_anim[N];

typedef struct {
    float x, y, tw;
} star_t;
static star_t stars[70];
static float shoot_x, shoot_y, shoot_t;

static const sfx_song night = {
    76, 4, 4,
    {
        {"C5 . G4 . E5 . G4 . D5 . G4 . E5 . . . A4 . E4 . C5 . E4 . B4 . E4 . G4 . . .", W_TRI, 0.16f, 0.25f, 0.01f, 0, 0, -0.3f},
        {"C3 - - - - - - - - - - - - - - - A2 - - - - - - - - - - - - - - - ", W_SINE, 0.18f, 0.4f, 0.05f, 0, 0, 0},
        {"E4 - - - - - - - G4 - - - - - - - E4 - - - - - - - D4 - - - - - - - ", W_SINE, 0.07f, 0.5f, 0.3f, 0, 0, 0.3f},
        {". . . . H . . . . . . . . . H . . . . . . . . . . . H . . . . . . . . H", W_NOISE, 0.025f, 0.03f, 0, 0, 0, 0.5f},
    }};

/* Saves the other games keep, read only to show them here. */
static int read_word(const char *file, const char *word)
{
    FILE *f = fopen(file, "r");
    char line[80];
    int v = -1;
    if (!f)
        return -1;
    while (fgets(line, sizeof line, f)) {
        char key[32];
        int n;
        if (sscanf(line, "%31s %d", key, &n) == 2 && !strcmp(key, word) && n >= 0 && n <= 1000000)
            v = n;
    }
    fclose(f);
    return v;
}

static void load_stats(void)
{
    int v;
    v = read_word("keep.sav", "best");
    snprintf(stat[G_KEEP], sizeof stat[0], v > 0 ? "best %d" : "new", v);
    v = read_word("lamp.sav", "best");
    snprintf(stat[G_LAMP], sizeof stat[0], v > 0 ? "%d nights" : "new", v);
    if (v == 1)
        snprintf(stat[G_LAMP], sizeof stat[0], "1 night");
    v = read_word("orb.sav", "best");
    snprintf(stat[G_ORB], sizeof stat[0], v > 0 ? "best %d" : "new", v);
    v = read_word("tea.sav", "visits");
    snprintf(stat[G_TEA], sizeof stat[0], v > 0 ? "%d visits" : "new", v);
    if (v == 1)
        snprintf(stat[G_TEA], sizeof stat[0], "1 visit");
    v = read_word("chest.sav", "gems");
    snprintf(stat[G_CHEST], sizeof stat[0], v > 0 ? "%d gems" : "new", v);
    if (v == 1)
        snprintf(stat[G_CHEST], sizeof stat[0], "1 gem");
}

static void make_stars(void)
{
    Uint32 keep = rng_u32();
    rng_seed(77);
    for (int i = 0; i < 70; i++) {
        stars[i].x = rng_range(0, W);
        stars[i].y = rng_range(0, 230);
        stars[i].tw = rng_range(0, 6.28f);
    }
    rng_seed(keep);
}

/* ------------------------------------------------------------------ icons */

static void icon(int g, float cx, float cy, int lit)
{
    float t = frame / 60.f;
    gcol ink = INK;
    switch (g) {
    case G_KEEP: {
        float fy = lit ? fmodf(t * 30.f, 22.f) : 6;
        gfx_circle_o(cx + 1, cy - 12 + fy * 0.6f, 4.5f, HEX(0xff5a4a), ink, 1.2f);
        gfx_rect((int)cx + 1, (int)(cy - 18 + fy * 0.6f), 1, 3, HEX(0x5a3a20));
        gfx_ellipse(cx + 4, cy - 17 + fy * 0.6f, 2.5f, 1.4f, HEX(0x6fd36f));
        gfx_rrect_o(cx - 10, cy + 2, 20, 9, 3, HEX(0xc98a4b), ink, 1.2f);
        gfx_rect((int)cx - 9, (int)cy + 5, 18, 1, HEX(0x9a6430));
        break;
    }
    case G_LAMP: {
        float sw = lit ? sinf(t * 3) * 2 : 0;
        if (lit)
            gfx_glow(cx + sw, cy + 2, 22, HEXA(0xffb040, 150));
        gfx_line(cx, cy - 13, cx + sw, cy - 8, 1.2f, HEX(0x8a6a40));
        gfx_rrect_o(cx - 6 + sw, cy - 8, 12, 17, 3, HEX(0xffe08a), ink, 1.2f);
        gfx_rect((int)(cx - 4 + sw), (int)cy - 4, 8, 9, lit ? HEX(0xfff4c0) : HEX(0xd9b060));
        gfx_star(cx + 11, cy - 9, 3.5f, t, lit ? GOLD : DIM);
        break;
    }
    case G_ORB: {
        if (lit)
            gfx_glow(cx, cy, 20, HEXA(0x9a70ff, 170));
        gfx_circle_o(cx, cy, 9, HEX(0x7a54e8), ink, 1.2f);
        gfx_circle(cx - 3, cy - 3, 3.5f, HEX(0xc8b4ff));
        gfx_ellipse(cx, cy + 1, 14, 3, col_alpha(HEX(0x7fe0ff), lit ? 200 : 110));
        gfx_ellipse(cx, cy + 1, 11, 1.6f, col_alpha(HEX(0x2a1a50), 160));
        break;
    }
    case G_TEA: {
        if (lit)
            for (int i = 0; i < 2; i++) {
                float sy = fmodf(t * 14 + i * 7, 14);
                gfx_circle(cx - 2 + i * 5 + sinf(t * 4 + i) * 1.5f, cy - 6 - sy, 2.2f - sy * 0.12f,
                           col_alpha(CREAM, 200 - (int)(sy * 12)));
            }
        gfx_ellipse_o(cx, cy + 9, 13, 3, HEX(0xffd0e6), ink, 1.2f);
        gfx_rrect_o(cx - 9, cy - 3, 18, 12, 4, CREAM, ink, 1.2f);
        gfx_rect((int)cx - 9, (int)cy + 1, 18, 3, HEX(0xff7fb0));
        gfx_ring(cx + 11, cy + 3, 3.5f, 2, ink);
        break;
    }
    default: {
        float lid = lit ? fabsf(sinf(t * 2.5f)) * 3 : 0;
        if (lit)
            gfx_glow(cx, cy - 2, 18, HEXA(0xffd060, 120 + (int)(lid * 20)));
        gfx_rrect_o(cx - 11, cy - 2, 22, 13, 2, HEX(0xb06a34), ink, 1.2f);
        gfx_rrect_o(cx - 11, cy - 9 - lid, 22, 7, 3, HEX(0xc87c3e), ink, 1.2f);
        gfx_rect((int)cx - 2, (int)cy - 4, 4, 9, GOLD);
        gfx_rect((int)cx - 1, (int)cy + 1, 2, 2, ink);
        break;
    }
    }
}

/* ------------------------------------------------------------------ scene */

static void paint_backdrop(void)
{
    gfx_vgrad(0, 0, W, 250, HEX(0x070a22), HEX(0x3a2660));
    gfx_glow(214, 20, 34, HEXA(0x8090ff, 70));
    gfx_circle(214, 20, 10, HEX(0xfff3d4));
    gfx_circle(219, 16, 9, HEX(0x0c0f2a));
    {
        float hill[] = {0, 262, 40, 246, 90, 254, 140, 240, 190, 250, 240, 238, 240, 320, 0, 320};
        float near_[] = {0, 286, 50, 276, 110, 284, 170, 274, 240, 282, 240, 320, 0, 320};
        gfx_poly(hill, 8, HEX(0x1c1640));
        gfx_poly(near_, 7, HEX(0x13102c));
    }
    for (int x = 4; x < W; x += 16) {
        float tip[] = {(float)x, 292, (float)x + 3, 287, (float)x + 6, 292, (float)x + 6, 312, (float)x, 312};
        gfx_poly(tip, 5, HEX(0x2b2350));
    }
    gfx_rect(0, 297, W, 3, HEX(0x2b2350));
    gfx_rect(0, 306, W, 3, HEX(0x2b2350));
    gfx_rect(0, 312, W, 8, HEX(0x0f0c22));
}

static void draw_sky(void)
{
    static gsurf *bg;
    if (!bg && (bg = gfx_surf_new(W, H)) != NULL) {
        gfx_target(bg);
        paint_backdrop();
        gfx_target(NULL);
    }
    if (bg)
        gfx_blit(bg, 0, 0);
    else
        paint_backdrop();
    for (int i = 0; i < 70; i++) {
        float tw = 0.5f + 0.5f * sinf(frame * 0.05f + stars[i].tw);
        int a = 60 + (int)(tw * 180);
        if (i % 9 == 0)
            gfx_star(stars[i].x, stars[i].y, 2.2f, 0, col_alpha(HEX(0xfff2c0), a));
        else
            gfx_pixel((int)stars[i].x, (int)stars[i].y, col_alpha(HEX(0xdfe6ff), a));
    }
    /* A shooting star now and then. */
    if (shoot_t > 0) {
        float k = 1 - shoot_t / 40.f;
        float x = shoot_x - k * 90, y = shoot_y + k * 40;
        gfx_line(x, y, x + 16, y - 7, 1.5f, col_alpha(HEX(0xfff6d0), (int)(shoot_t * 6)));
        gfx_glow(x, y, 6, HEXA(0xffffff, 200));
        shoot_t--;
    } else if (rng_int(0, 400) == 0) {
        shoot_t = 40;
        shoot_x = rng_range(120, 240);
        shoot_y = rng_range(10, 60);
    }
}

static void draw_row(int i, float y)
{
    int sel = i == row;
    float k = sel ? 1.f : 0.f;
    float slide = 7.f * ease_out_back(sel_anim[i]);
    float x = 16 + slide, w = 210;
    gcol card = sel ? HEX(0x2e2458) : HEXA(0x1c1640, 200);
    if (sel) {
        gfx_glow(x + 17, y + 15, 34, col_alpha(tints[i], 90));
        gfx_rrect(x - 2, y - 2, w + 4, 34, 9, col_alpha(tints[i], 255));
    }
    gfx_rrect(x, y, w, 30, 8, card);
    gfx_circle(x + 17, y + 15, 12, sel ? col_alpha(tints[i], 60) : HEXA(0x000000, 60));
    icon(i, x + 17, y + 15, sel);
    gfx_text_o((int)x + 34, (int)y + 4, 2, sel ? CREAM : col_mix(DIM, CREAM, k * 0.5f), INK, "%s", titles[i]);
    gfx_text((int)x + 34, (int)y + 21, 1, sel ? col_mix(tints[i], CREAM, 0.35f) : HEXA(0x8f8bb0, 170), "%s",
             sel ? blurbs[i] : stat[i]);
    {
        int bw = gfx_text_w(1, "%s", bands[i]) + 8;
        gfx_rrect(x + w - bw - 6, y + 5, bw, 11, 4, sel ? tints[i] : HEXA(0x3a3266, 220));
        gfx_text((int)(x + w - bw - 2), (int)y + 7, 1, sel ? INK : DIM, "%s", bands[i]);
        if (sel && strcmp(stat[i], "new"))
            gfx_text((int)x + 40 + gfx_text_w(2, "%s", titles[i]), (int)y + 9, 1, GOLD, "%s", stat[i]);
    }
}

static void draw_lantern(float y)
{
    float sw = sinf(frame * 0.06f) * 3 + lantern_swing;
    float x = 8 + sw;
    gfx_glow(x, y + 15, 30, HEXA(0xffa030, 110));
    gfx_line(8, y - 6, x, y + 6, 1, HEX(0x8a7050));
    gfx_rrect_o(x - 4, y + 6, 8, 15, 2, HEX(0xffd27a), INK, 1);
    gfx_rect((int)x - 2, (int)y + 9, 4, 9, HEX(0xfff6c8));
    gfx_rect((int)x - 4, (int)y + 5, 8, 2, HEX(0x5a4030));
}

static void draw(float iris)
{
    float top = 92;
    draw_sky();
    {
        float bob = sinf(frame * 0.04f) * 1.5f;
        gfx_text_c(W / 2 - 6, (int)(22 + bob), 3, GOLD, INK, "The Yard");
        gfx_text_c(W / 2, (int)(56 + bob), 1, HEX(0xc0b8ff), HEXA(0, 0), "five little games by the fence");
    }
    for (int i = 0; i < N; i++)
        draw_row(i, top + i * 38);
    draw_lantern(top + shown_row * 38 + 4);
    if (pocket) {
        gfx_circle(W - 10, H - 30, 4, HEX(0x40d2dc));
        gfx_text(W - 52, H - 42, 1, HEX(0x40d2dc), "card in");
    }
    for (int i = 0; i < 5; i++) {
        float a = frame * 0.01f + i * 1.7f;
        float fx = fmodf(30 + i * 47 + sinf(a * 1.3f) * 18 + frame * 0.1f, W);
        float fy = 270 + sinf(a * 2.1f) * 14 + i * 3;
        float on = 0.5f + 0.5f * sinf(frame * 0.08f + i);
        gfx_glow(fx, fy, 7, col_alpha(HEX(0xd8ff70), (int)(on * 200)));
        gfx_pixel((int)fx, (int)fy, HEX(0xf4ffc0));
    }
    part_update();
    part_draw();
    if (note && note_left > 0) {
        gfx_rrect(20, 284, W - 40, 16, 6, HEXA(0x6a1e30, 230));
        gfx_text_c(W / 2, 288, 1, CREAM, HEXA(0, 0), "%s", note);
        note_left--;
    } else {
        gfx_text_c(W / 2, 286, 1, HEX(0xb0a8e0), HEXA(0, 0), "stick: choose     button: play");
        gfx_text_c(W / 2, 298, 1, HEXA(0x8f8bb0, 200), HEXA(0, 0), "hold 1P + 2P to go back");
    }
    if (iris < 1.f) {
        /* Close a circle on the chosen row, then black. */
        float cx = 40, cy = top + row * 38 + 15;
        float r = iris * 420;
        for (int y = 0; y < H; y++) {
            float dy = y - cy;
            if (dy * dy >= r * r)
                gfx_rect(0, y, W, 1, HEX(0x000000));
            else {
                float dx = sqrtf(r * r - dy * dy);
                gfx_rect(0, y, (int)(cx - dx), 1, HEX(0x000000));
                gfx_rect((int)(cx + dx), y, W, 1, HEX(0x000000));
            }
        }
    }
    gfx_present();
}

/* ------------------------------------------------------------------ launch */

static int sibling(char *out, size_t n, const char *name)
{
    char self[512];
    ssize_t len = readlink("/proc/self/exe", self, sizeof self - 1);
    char *slash;
    if (len < 0)
        return -1;
    self[len] = 0;
    slash = strrchr(self, '/');
    if (!slash)
        return -1;
    *slash = 0;
    if (strlen(self) + 1 + strlen(name) + 1 > n)
        return -1;
    snprintf(out, n, "%s/%s", self, name);
    return 0;
}

static int start(void)
{
    if (gfx_init("The Yard", W, H) != 0)
        return -1;
    sfx_init();
    sfx_master(0.32f);
    music_play(&night);
    return 0;
}

/* Close the window, run the other game, then open the yard again. */
static int launch(const char *name, int fast)
{
    char path[512];
    pid_t pid;
    int st = 0;
    if (sibling(path, sizeof path, name) != 0 || access(path, X_OK) != 0)
        return -1;
    cab_shutdown();
    pid = fork();
    if (pid < 0)
        return -1;
    if (pid == 0) {
        if (fast)
            execl(path, name, "-fast", (char *)NULL);
        else
            execl(path, name, (char *)NULL);
        _exit(127);
    }
    waitpid(pid, &st, 0);
    if (start() != 0)
        return -1;
    load_stats();
    return WIFEXITED(st) ? WEXITSTATUS(st) : -1;
}

int main(int argc, char **argv)
{
    int fast = cab_fast(argc, argv);
    int self = getenv("YARD_SELFTEST") != NULL;
    const char *once = getenv("YARD_ONCE");
    int opening = 0;
    float iris = 0;
    if (start() != 0)
        return 1;
    rng_seed_auto();
    make_stars();
    load_stats();
    row = cab_score_load("yard");
    if (row < 0 || row >= N)
        row = 0;
    shown_row = (float)row;
    {
        char label[64];
        if (cab_ext_read("label", label, sizeof label) > 0) {
            pocket = 1;
            cab_ext_write("visited", "yard\n", 5);
        }
    }
    if (once) {
        int rc = launch(once, fast);
        cab_shutdown();
        return rc == 0 ? 0 : 1;
    }
    while (cab_poll()) {
        int up = cab_down(0, CAB_UP) || cab_down(0, CAB_LEFT);
        int down = cab_down(0, CAB_DOWN) || cab_down(0, CAB_RIGHT);
        int go = cab_pressed(0, CAB_LOW) || cab_pressed(0, CAB_TL) || cab_pressed(0, CAB_TR);
        int step = 0;
        if (opening) {
            iris -= 0.07f;
            if (iris <= 0) {
                cab_score_save("yard", row);
                cab_log("yard open %s", ids[row]);
                if (launch(ids[row], fast) != 0) {
                    note = "that game is missing";
                    note_left = 180;
                    cab_log("could not open %s", ids[row]);
                    sfx_slide(W_SQUARE, 300, 120, 0.3f, 0.3f);
                }
                opening = 0;
                iris = 0;
            }
            draw(iris);
            frame++;
            continue;
        }
        if (iris < 1)
            iris = clampf(iris + 0.06f, 0, 1);
        if (up != down && (up || down)) {
            hold_frames++;
            if (hold_frames == 1 || (hold_frames > 18 && (hold_frames - 18) % 7 == 0))
                step = up ? -1 : 1;
        } else
            hold_frames = 0;
        if (step) {
            row = (row + N + step) % N;
            lantern_swing = step * 5.f;
            sfx_tone(W_SQUARE, 600 + row * 90, 0.06f, 0.18f);
            part_burst(30, 92 + row * 38 + 15, 6, 1.2f, 24, 1.5f, col_alpha(tints[row], 220), PART_GLOW);
        }
        lantern_swing *= 0.9f;
        shown_row = approach(shown_row, (float)row, 0.3f);
        for (int i = 0; i < N; i++)
            sel_anim[i] = approach(sel_anim[i], i == row ? 1.f : 0.f, 0.2f);
        if (go) {
            int arp[] = {67, 72, 76, 79};
            sfx_arp(W_TRI, arp, 4, 0.06f, 0.35f);
            part_burst(120, 92 + row * 38 + 15, 24, 2.5f, 40, 2.5f, col_alpha(tints[row], 255), PART_STAR);
            opening = 1;
            iris = 1;
        }
        draw(iris);
        frame++;
        if (self && frame > 8) {
            if (cab_score_save("yard", row) != 0 || cab_score_load("yard") != row)
                return 1;
            break;
        }
    }
    cab_shutdown();
    return 0;
}
