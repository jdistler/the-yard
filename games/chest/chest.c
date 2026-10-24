/* Chest: walk to the key, open the chest, take the sword, duel Zam.
 * Walk-up band (CONTROLS.md). The stick walks. LOW shoots. TL and TR shoot too.
 * Upright 384x512. A grown-up reads the cream band. chest.sav is "gems N".
 */
#include "cab.h"

#include <fcntl.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define W 384
#define H 512
#define SPEED 2
#define POP_FRAMES 40
#define WRAP_FRAMES 120
#define REACT_FRAMES 120
#define WIN_FRAMES 120
#define RESTART_FRAMES 50
#define SHOT_GAP 20
#define MARKS_WIN 9

enum { PATH, POP, FIGHT, WINBOW, RESTART };
enum { FAIRY_NONE, FAIRY_GOLD, FAIRY_BLUE, FAIRY_PURPLE };

static const SDL_Color GRASS = {125, 206, 122, 255};
static const SDL_Color CREAM = {255, 246, 234, 255};
static const SDL_Color INK = {58, 42, 68, 255};
static const SDL_Color CAPE = {58, 110, 165, 255};
static const SDL_Color SKIN = {244, 199, 161, 255};
static const SDL_Color GOLD = {242, 193, 78, 255};
static const SDL_Color WOOD = {196, 132, 74, 255};
static const SDL_Color BROWN = {160, 103, 58, 255};
static const SDL_Color SPOON = {186, 190, 204, 255};
static const SDL_Color BLUE = {110, 181, 255, 255};
static const SDL_Color PURPLE = {122, 90, 245, 255};
static const SDL_Color ROSE = {232, 107, 154, 255};
static const SDL_Color WHITE = {255, 252, 248, 255};

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

static volatile int bed_on, bed_left, bed_step, seq_n, seq_i, seq_left;
static volatile float bed_hz, seq_amp, seq_hz[6];
static double bed_phase, seq_phase;

static void disc(int cx, int cy, int r, SDL_Color c)
{
    if (r < 1)
        return;
    SDL_SetRenderDrawColor(cab_renderer, c.r, c.g, c.b, 255);
    for (int dy = -r; dy <= r; dy++) {
        int span = (int)sqrtf((float)(r * r - dy * dy));
        SDL_Rect row = {cx - span, cy + dy, span * 2 + 1, 1};
        SDL_RenderFillRect(cab_renderer, &row);
    }
}

static void box(int x, int y, int w, int h, SDL_Color c)
{
    SDL_Rect r = {x, y, w, h};
    SDL_SetRenderDrawColor(cab_renderer, c.r, c.g, c.b, 255);
    SDL_RenderFillRect(cab_renderer, &r);
}

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

static void enqueue(const float *hz, int n, int samples, float amp)
{
    if (n > 6)
        n = 6;
    seq_n = 0;
    for (int i = 0; i < n; i++)
        seq_hz[i] = hz[i];
    seq_amp = amp;
    seq_i = 0;
    seq_left = samples;
    seq_n = n;
}

static void tone(float hz, int samples, float amp)
{
    enqueue(&hz, 1, samples, amp);
}

static void fill_audio(void *ud, Sint16 *out, int frames)
{
    static const float bed_notes[] = {523.25f, 659.25f};
    (void)ud;
    for (int i = 0; i < frames; i++) {
        float s = 0;
        if (bed_on) {
            if (bed_left <= 0) {
                bed_step = (bed_step + 1) % 2;
                bed_hz = bed_notes[bed_step];
                bed_left = 44100 / 2;
            }
            s += 600.f * sinf((float)bed_phase);
            bed_phase += 2.0 * 3.1415926535 * bed_hz / 44100.0;
            bed_left--;
        }
        if (seq_n > 0 && seq_i < seq_n) {
            s += seq_amp * sinf((float)seq_phase);
            seq_phase += 2.0 * 3.1415926535 * seq_hz[seq_i] / 44100.0;
            if (--seq_left <= 0) {
                seq_i++;
                seq_left = 44100 / 8;
                seq_phase = 0;
            }
        }
        if (s > 3000.f)
            s = 3000.f;
        if (s < -3000.f)
            s = -3000.f;
        out[2 * i] = out[2 * i + 1] = (Sint16)s;
    }
}

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

static int near_chest(void)
{
    return ny < 268 && nx > 156 && nx < 236;
}

static int near_key(void)
{
    int dx = nx - 128;
    int dy = ny - 348;
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

static void begin_pop(void)
{
    if (phase != PATH || !has_key)
        return;
    phase = POP;
    pop_t = 0;
    cab_log("chest pop %d", frame);
    {
        float hz[] = {523.25f, 659.25f, 783.99f, 1046.5f};
        enqueue(hz, 4, 44100 / 7, 1100.f);
    }
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
        float hz[] = {523.25f, 659.25f, 783.99f, 1046.5f};
        enqueue(hz, 4, 44100 / 6, 1200.f);
    }
    react_to("Treasure for the pile.");
}

static void add_marks(int n, int big)
{
    marks += n;
    spoon_flash = 16;
    if (big) {
        cab_log("chest big");
        tone(1046.5f, 44100 / 8, 1200.f);
        react_to("The big bubble popped.");
    } else {
        cab_log("chest mark %d", marks);
        tone(783.99f, 44100 / 14, 900.f);
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
    tone(196.f, 44100 / 10, 1000.f);
    if (pips >= 3) {
        phase = RESTART;
        bow_t = 0;
        cab_log("chest restart %d", frame);
        {
            float hz[] = {783.99f, 659.25f};
            enqueue(hz, 2, 44100 / 7, 900.f);
        }
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
    tone(783.99f, 44100 / 18, 800.f);
    for (int i = 0; i < len; i++) {
        x += dx;
        y += dy;
        if (x < 4 || x > W - 4 || y < 8 || y > H - 36) {
            splash_on = 1;
            splash_x = x;
            splash_y = y;
            break;
        }
        if (!has_key && (x - 128) * (x - 128) + (y - 348) * (y - 348) < 30 * 30)
            has_key = 1, cab_log("chest key %d", frame), tone(1046.5f, 44100 / 10, 1000.f), react_to("The key is his.");
        if (has_key && phase == PATH && y < 268 && x > 156 && x < 236)
            begin_pop();
        if (has_sword && phase == FIGHT && y < 210 && x > 70 && x < 314) {
            hit = 1;
            break;
        }
    }
    bolt_x1 = x;
    bolt_y1 = y;
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
}

static void draw_spoon(int x, int y, int flash)
{
    SDL_Color edge = {78, 74, 96, 255};
    SDL_Color steel = flash ? CREAM : SPOON;
    SDL_Color shade = {120, 116, 140, 255};
    if (flash) {
        edge = CREAM;
        shade = WHITE;
    }
    box(x - 2, y - 2, 5, 36, edge);
    box(x - 1, y, 3, 32, steel);
    box(x - 14, y - 18, 28, 14, edge);
    box(x - 12, y - 16, 24, 10, steel);
    disc(x - 10, y - 11, 5, edge);
    disc(x + 10, y - 11, 5, edge);
    disc(x - 10, y - 12, 3, steel);
    disc(x + 10, y - 12, 3, steel);
    box(x - 8, y - 14, 16, 6, shade);
    box(x - 5, y - 17, 6, 2, flash ? WHITE : CREAM);
}

static void draw_zam(int cx, int cy, int flash, int bow)
{
    cy += bow ? 14 : 0;
    box(cx - 12, cy + 36, 8, 28, GOLD);
    box(cx + 4, cy + 36, 8, 28, GOLD);
    box(cx - 16, cy + 60, 14, 6, GOLD);
    box(cx + 2, cy + 60, 14, 6, GOLD);
    box(cx - 16, cy + 6, 32, 36, GOLD);
    box(cx - 36, cy + 4, 22, 14, BROWN);
    box(cx + 14, cy + 4, 22, 14, BROWN);
    box(cx - 14, cy + 14, 28, 20, BROWN);
    box(cx - 4, cy + 18, 8, 12, GOLD);
    box(cx - 40, cy - 28, 8, 36, GOLD);
    box(cx + 32, cy - 28, 8, 36, GOLD);
    disc(cx - 36, cy - 30, 6, GOLD);
    disc(cx + 36, cy - 30, 6, GOLD);
    draw_spoon(cx - 42, cy - 42, flash);
    draw_spoon(cx + 42, cy - 42, flash);
    disc(cx, cy - 22, 28, INK);
    disc(cx, cy - 24, 26, GOLD);
    box(cx - 16, cy - 30, 10, 4, WHITE);
    box(cx + 6, cy - 30, 10, 4, WHITE);
    box(cx - 13, cy - 29, 4, 3, INK);
    box(cx + 8, cy - 29, 4, 3, INK);
    box(cx - 14, cy - 14, 28, 6, BROWN);
    box(cx - 32, cy - 10, 20, 6, BROWN);
    box(cx + 12, cy - 10, 20, 6, BROWN);
    box(cx - 48, cy - 4, 18, 6, BROWN);
    box(cx + 30, cy - 4, 18, 6, BROWN);
    box(cx - 62, cy + 4, 16, 6, BROWN);
    box(cx + 46, cy + 4, 16, 6, BROWN);
    box(cx - 72, cy + 12, 14, 8, BROWN);
    box(cx + 58, cy + 12, 14, 8, BROWN);
    disc(cx - 74, cy + 26, 11, BROWN);
    disc(cx - 68, cy + 38, 8, BROWN);
    disc(cx + 74, cy + 26, 11, BROWN);
    disc(cx + 68, cy + 38, 8, BROWN);
}

static void draw_ned(void)
{
    int sword = has_sword && phase != PATH && phase != POP;
    box(nx - 16, ny + 4, 32, 30, CAPE);
    disc(nx, ny - 10, 18, INK);
    disc(nx, ny - 10, 15, SKIN);
    box(nx - 10, ny - 14, 6, 4, INK);
    box(nx + 4, ny - 14, 6, 4, INK);
    if (has_key && !sword)
        box(nx + 8, ny - 2, 6, 12, GOLD);
    if (sword || (phase == POP && pop_t > 20)) {
        int sx = nx + face_x * 18;
        int sy = ny - 16 + face_y * 14;
        box(sx - 3, sy - 26, 6, 34, GOLD);
        box(sx - 8, sy + 4, 16, 4, BROWN);
    }
}

static void draw_chest_box(int open)
{
    int lift = open ? 18 : hop;
    /* Short body, so Ned stands in front of the chest instead of inside it. */
    box(156, 168, 72, 30, WOOD);
    box(160, 176, 64, 16, GOLD);
    box(186, 184, 12, 8, INK);
    box(148, 150 - lift, 88, 22, WOOD);
    box(152, 146 - lift, 12, 10, GOLD);
}

static void draw_key(int x, int y)
{
    box(x - 4, y - 18, 8, 26, GOLD);
    disc(x, y - 24, 12, GOLD);
    disc(x, y - 24, 5, GRASS);
    box(x + 3, y + 2, 8, 4, GOLD);
}

static void draw_fairy(int x, int y, SDL_Color c)
{
    disc(x - 10, y, 6, CREAM);
    disc(x + 10, y, 6, CREAM);
    disc(x, y, 8, c);
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
        if (face_y >= 0 && face_x != 0)
            return "Aim up. He's the boss.";
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

static void caption(const char *s)
{
    int n = (int)strlen(s);
    int x = (W - n * 16) / 2;
    if (x < 2)
        x = 2;
    box(0, H - 32, W, 32, CREAM);
    cab_text(x, H - 24, 2, INK, "%s", s);
    say(s);
}

static void draw(void)
{
    const char *line;
    int open = phase != PATH;
    int flash = spoon_flash > 0 || telegraph > 0;
    box(0, 0, W, H - 32, GRASS);
    box(40, 70, 14, 6, (SDL_Color){78, 168, 72, 255});
    box(300, 96, 16, 6, (SDL_Color){78, 168, 72, 255});
    box(48, 230, 12, 6, (SDL_Color){78, 168, 72, 255});
    box(312, 250, 14, 6, (SDL_Color){78, 168, 72, 255});
    box(28, 400, 16, 6, (SDL_Color){78, 168, 72, 255});
    box(318, 410, 12, 6, (SDL_Color){78, 168, 72, 255});
    disc(70, 140, 5, GOLD);
    disc(320, 170, 4, (SDL_Color){232, 107, 154, 255});
    disc(36, 300, 4, GOLD);
    box(140, 188, 104, 292, CREAM);
    for (int i = 0; i < (gems < 8 ? gems : 8); i++)
        disc(24 + i * 22, 28, 8, ROSE);
    if (gems > 8)
        disc(24 + 7 * 22, 28, 11, GOLD);
    draw_chest_box(open);
    if (!has_key)
        draw_key(128, 348);
    if (phase == POP) {
        int grow = pop_t * 40 / POP_FRAMES;
        draw_zam(192, 150 - (40 - grow), flash, 0);
    } else if (phase == FIGHT || phase == WINBOW || phase == RESTART)
        draw_zam(192, 118, flash, phase == WINBOW || phase == RESTART);
    if (fairy != FAIRY_NONE) {
        SDL_Color c = fairy == FAIRY_GOLD ? GOLD : fairy == FAIRY_BLUE ? BLUE : PURPLE;
        draw_fairy(fairy_x, fairy_y, c);
    }
    if (wrap > 0) {
        for (int a = 0; a < 18; a++) {
            float t = a * 3.1415926f / 9.f;
            disc(192 + (int)(cosf(t) * 52), 118 + (int)(sinf(t) * 52), 5, GOLD);
        }
    }
    if (ring_on) {
        SDL_Color c = ring_safe ? BLUE : PURPLE;
        for (int a = 0; a < 16; a++) {
            float t = a * 3.1415926f / 8.f;
            disc(ring_x + (int)(cosf(t) * ring_r), ring_y + (int)(sinf(t) * ring_r), 4, c);
        }
    }
    if (star_on)
        disc(star_x, star_y, 8, GOLD);
    if (bubble_on)
        disc((int)bx, (int)by, 12, PURPLE);
    draw_ned();
    if (phase == FIGHT || phase == RESTART || phase == WINBOW) {
        for (int i = 0; i < 3; i++) {
            SDL_Color c = i < pips ? ROSE : CREAM;
            disc(nx - 16 + i * 16, ny - 36, 5, INK);
            disc(nx - 16 + i * 16, ny - 36, 3, c);
        }
    }
    if (bolt_on) {
        int steps = abs(bolt_x1 - bolt_x0) + abs(bolt_y1 - bolt_y0);
        if (steps < 1)
            steps = 1;
        for (int i = 0; i <= steps; i += 4) {
            int x = bolt_x0 + (bolt_x1 - bolt_x0) * i / steps;
            int y = bolt_y0 + (bolt_y1 - bolt_y0) * i / steps;
            disc(x, y, 3, GOLD);
        }
    }
    if (splash_on)
        disc(splash_x, splash_y, 6, CREAM);
    if (react_left && phase != PATH)
        line = react;
    else if (react_left && (phase == PATH))
        line = react;
    else
        line = rest_line();
    caption(line);
    cab_present();
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
        tone(659.25f, 44100 / 12, 700.f);
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
    }
    if (fairy == FAIRY_GOLD) {
        dx = 192 - fairy_x;
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
            tone(1318.5f, 44100 / 10, 900.f);
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
            tone(880.f, 44100 / 16, 600.f);
        } else if (ring_safe && ring_r > 22) {
            ring_on = 0;
            star_on = 1;
            star_x = nx - 28;
            star_y = ny;
            star_life = 180;
            cab_log("chest star %d", frame);
            {
                float hz[] = {659.25f, 783.99f};
                enqueue(hz, 2, 44100 / 10, 800.f);
            }
            react_to("Walk over the star.");
        } else if (!ring_safe && ring_r > 26 && inside) {
            ring_on = 0;
            hurt();
        } else
            ring_r += 1;
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
            react_to("The star wrapped him.");
        } else if (--star_life <= 0)
            star_on = 0;
    }
}

int main(int argc, char **argv)
{
    (void)argc;
    (void)argv;
    if (cab_init("Chest", W, H) != 0)
        return 1;
    cab_audio_open(fill_audio, NULL);
    load_gems();
    cab_log("chest gems %d", gems);
    bed_on = 1;
    bed_hz = 523.25f;
    nx = 200;
    ny = 420;
    face_x = 0;
    face_y = -1;
    while (cab_poll()) {
        int pressed = cab_pressed(0, CAB_LOW) || cab_pressed(0, CAB_TL) || cab_pressed(0, CAB_TR);
        int held = cab_down(0, CAB_LOW) || cab_down(0, CAB_TL) || cab_down(0, CAB_TR);
        int mx = 0, my = 0;
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
                face_x = mx;
                face_y = my;
                if (mx && my) {
                    face_x = 0;
                    face_y = my;
                }
            }
        }
        if (!has_key && near_key()) {
            has_key = 1;
            cab_log("chest key %d", frame);
            tone(1046.5f, 44100 / 10, 1000.f);
            react_to("The key is his.");
        }
        if (phase == PATH && near_chest()) {
            if (has_key)
                begin_pop();
            else if (hop == 0) {
                hop = 10;
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
        if (react_left > 0)
            react_left--;
        if (cab_down(0, CAB_1P) && cab_down(0, CAB_2P) && !goodbye_played) {
            float hz[] = {783.99f, 659.25f};
            enqueue(hz, 2, 44100 / 6, 900.f);
            goodbye_played = 1;
        }
        draw();
        frame++;
        {
            SDL_RendererInfo ri;
            SDL_GetRendererInfo(cab_renderer, &ri);
            if (!getenv("CAB_SCRIPT") && !(ri.flags & SDL_RENDERER_PRESENTVSYNC))
                SDL_Delay(16);
        }
    }
    cab_shutdown();
    return 0;
}
