/* Tea: a unicorn flies to a castle and takes care of the cats.
 * Little band (CONTROLS.md): any stick direction does the one useful thing,
 * every right-hand button does the care, and a turn cannot be lost.
 * Upright 384x512. A grown-up reads the cream band. She can play without it.
 * tea.sav remembers visits and gifts. Hearts start fresh every arrival.
 */
#include "cab.h"

#include <fcntl.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define W 384
#define H 512
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

static const SDL_Color SKY_C = {142, 198, 255, 255};
static const SDL_Color CREAM = {255, 246, 234, 255};
static const SDL_Color CASTLE = {244, 182, 208, 255};
static const SDL_Color ROOF = {232, 107, 154, 255};
static const SDL_Color GOLD = {242, 193, 78, 255};
static const SDL_Color MINT = {126, 200, 195, 255};
static const SDL_Color LILAC = {185, 160, 232, 255};
static const SDL_Color TEA_C = {201, 134, 90, 255};
static const SDL_Color ORANGE = {242, 154, 58, 255};
static const SDL_Color GREY = {138, 143, 156, 255};
static const SDL_Color INK = {58, 42, 68, 255};
static const SDL_Color WHITE = {255, 252, 248, 255};

static const char *const gift_word[] = {"none", "teacup", "ribbon", "flower"};
static const char *const cat_name[] = {"Pip", "Moth", "Pearl", "Nib"};

static int phase, frame, fly, door_t, focus, ncats, visits, nib_here;
static int hearts[CAT_MAX], gift[CAT_MAX], last_friend;
static int react_left, cheer_left, cheered, care_wait, care_from_party;
static int flap, hurry, lean_x, lean_y, cloud_squish, bump_cool, goodbye_played;
static char react_line[40];
static char shown[40];

static volatile int bed_on, bed_left, bed_step;
static volatile float bed_hz;
static volatile int seq_n, seq_i, seq_left;
static volatile float seq_hz[6];
static volatile float seq_amp;
static double seq_phase, bed_phase;

static int fast_mul(int step, int fast)
{
    return fast ? step * 8 / 5 : step;
}

static void disc(int cx, int cy, int r, SDL_Color c)
{
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

static void fill_audio(void *ud, Sint16 *out, int frames)
{
    static const float bed_notes[] = {523.25f, 659.25f, 783.99f};
    (void)ud;
    for (int i = 0; i < frames; i++) {
        float s = 0;
        if (bed_on) {
            if (bed_left <= 0) {
                bed_step = (bed_step + 1) % 3;
                bed_hz = bed_notes[bed_step];
                bed_left = 44100 / 2;
            }
            s += 700.f * sinf((float)bed_phase);
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

static void tune_for(int cat)
{
    int who = cat == NIB ? last_friend : cat;
    float hz[4];
    int n = 1;
    float amp = 1400.f;
    if (who == PIP) {
        hz[0] = 196.f;
        hz[1] = 659.25f;
        n = 2;
    } else if (who == MOTH) {
        hz[0] = 783.99f;
        hz[1] = 1046.5f;
        n = 2;
    } else {
        hz[0] = 1046.5f;
        hz[1] = 1318.5f;
        hz[2] = 1568.f;
        n = 3;
        amp = 1100.f;
    }
    if (cat == NIB) {
        for (int i = 0; i < n; i++)
            hz[i] *= 1.5f;
        if (n > 2)
            n = 2;
    }
    enqueue(hz, n, 44100 / 8, amp);
}

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
    if (who == MOTH)
        return "Moth is so happy.";
    if (who == PEARL)
        return "Pearl is so happy.";
    if (who == NIB)
        return "Nib is so happy.";
    return "Pip is so happy.";
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

static int seat_x(int i)
{
    if (ncats == 4)
        return 48 + i * 96;
    return 72 + i * 120;
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
    {
        float hz = 523.25f;
        enqueue(&hz, 1, 44100 / 6, 900.f);
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

static void care(int who)
{
    int filled = 0;
    if (who != NIB)
        last_friend = who;
    give_gift(who);
    if (hearts[who] < 3) {
        hearts[who]++;
        filled = hearts[who] == 3;
    }
    cab_log("tea heart %s %d", cat_name[who], hearts[who]);
    tune_for(who);
    if (all_full() && !cheered) {
        float hz[] = {523.25f, 659.25f, 783.99f, 1046.5f};
        cheered = 1;
        cheer_left = CHEER_FRAMES;
        snprintf(react_line, sizeof react_line, "%s", "The whole table glows.");
        react_left = CHEER_FRAMES;
        enqueue(hz, 4, 44100 / 7, 1200.f);
        save_tea();
        cab_log("tea cheer");
    } else {
        snprintf(react_line, sizeof react_line, "%s", filled ? happy_line(who) : care_line(who));
        react_left = REACT_FRAMES;
        save_tea();
    }
    care_wait = CARE_GAP;
}

static void draw_castle(int x, int y, int w, int h, int door_open)
{
    int tower = w / 5;
    if (tower < 8)
        tower = 8;
    box(x, y + h / 5, w, h, CASTLE);
    box(x, y, tower, h / 2, CASTLE);
    box(x + w - tower, y, tower, h / 2, CASTLE);
    box(x, y, tower, tower / 2, ROOF);
    box(x + w - tower, y, tower, tower / 2, ROOF);
    box(x + w / 2 - tower / 2, y + h / 3, tower, h / 2, GOLD);
    if (door_open)
        box(x + w / 2 - tower / 3, y + h / 2, tower * 2 / 3, h / 2, SKY_C);
    else
        box(x + w / 2 - tower / 3, y + h / 2, tower * 2 / 3, h / 2, INK);
    box(x + w / 3, y + h / 3, tower / 2, tower / 2, MINT);
}

static void draw_cat(int who, int cx, int cy, int r, int delighted)
{
    SDL_Color body = who == MOTH ? GREY : who == PEARL ? WHITE : who == NIB ? CREAM : ORANGE;
    int blink = (frame / 50) % 7 == who;
    if (who == NIB)
        disc(cx, cy + r, r + 10, LILAC);
    disc(cx, cy, r + 3, INK);
    disc(cx, cy, r, body);
    disc(cx - r / 2, cy - r + 2, r / 3 + 2, INK);
    disc(cx - r / 2, cy - r + 2, r / 3, body);
    disc(cx + r / 2, cy - r + 2, r / 3 + 2, INK);
    disc(cx + r / 2, cy - r + 2, r / 3, body);
    if (who == NIB)
        disc(cx + r / 3, cy + r / 5, r / 3, ORANGE);
    if (who == PEARL)
        box(cx - 4, cy - r / 2, 8, 6, GOLD);
    if (!blink) {
        disc(cx - r / 4, cy - r / 8, 3, INK);
        disc(cx + r / 4, cy - r / 8, 3, INK);
    } else {
        box(cx - r / 3, cy - 2, r / 2, 2, INK);
    }
    if (who == PIP)
        disc(cx, cy + r / 6, 4, ROOF);
    if (gift[who] == GIFT_FLOWER)
        disc(cx, cy - r - 4, 6, GOLD);
    if (gift[who] == GIFT_TEACUP)
        box(cx - 5, cy + r / 2, 10, 8, TEA_C);
    if (gift[who] == GIFT_RIBBON)
        box(cx + r / 2, cy, 8, 6, ROOF);
    if (delighted && who == PIP)
        box(cx - 8, cy + 2, 16, 4, WHITE);
    if (who == MOTH) {
        int roll = (int)(8 * sinf(frame * 0.1f));
        disc(cx + r + 10 + roll, cy + r / 2, 7, INK);
        disc(cx + r + 10 + roll, cy + r / 2, 5, GOLD);
    }
}

static void draw_unicorn(int x, int y, int big, int pose)
{
    int r = big ? 32 : 26;
    int wing = (flap & 1) ? -10 : 8;
    disc(x - r, y - 6, r / 2, wing > 0 ? LILAC : MINT);
    disc(x + r, y - 6, r / 2, wing > 0 ? MINT : LILAC);
    disc(x, y, r + 4, INK);
    disc(x, y, r, CREAM);
    box(x - 6, y - r - 28, 8, 30, GOLD);
    box(x - 12, y + r - 2, 7, 16, CREAM);
    box(x + 6, y + r - 2, 7, 16, CREAM);
    disc(x - r - 6, y + 4, 6, LILAC);
    box(x - 10, y - r + 4, 6, 10, GOLD);
    box(x - 2, y - r + 6, 6, 10, ROOF);
    box(x + 6, y - r + 4, 6, 10, MINT);
    box(x + 14, y - r + 8, 6, 10, LILAC);
    disc(x - r / 5, y - 4, 3, INK);
    if (pose == 1)
        box(x + r - 6, y + 4, 12, 8, TEA_C);
    if (hurry || pose == 2) {
        disc(x + 4, y - r - 22, 4, GOLD);
        disc(x + 16, y - r - 10, 3, CREAM);
    }
}

static void draw_hearts(int cx, int cy, int r, int n)
{
    int x0 = cx - 26;
    int y0 = cy - r - 28;
    for (int i = 0; i < 3; i++) {
        int x = x0 + i * 18;
        if (i < n)
            box(x, y0, 12, 12, ROOF);
        else {
            box(x, y0, 12, 12, INK);
            box(x + 2, y0 + 2, 8, 8, CREAM);
        }
    }
}

static void draw_icon(int cx, int cy, int r, int who)
{
    int ask = who == NIB ? last_friend : who;
    int x = cx - 16;
    int y = cy - r - 78;
    if (hearts[who] >= 3 || cheered) {
        disc(cx, y + 16, 14, GOLD);
        return;
    }
    if (ask == PIP)
        box(x, y, 32, 24, TEA_C);
    else if (ask == MOTH)
        disc(cx, y + 14, 14, GOLD);
    else
        disc(cx, y + 14, 14, ROOF);
}

static void draw_sky(void)
{
    int grown = 28 + fly * 80 / FLY_DONE;
    int cx = W / 2 + lean_x;
    int cy = 340 + lean_y;
    box(0, 0, W, H, SKY_C);
    for (int i = 0; i < 5; i++) {
        int lit = fly > FLY_DONE * (i + 1) / 6;
        disc(48 + i * 72, 200 - i * 18, 5, lit ? GOLD : WHITE);
    }
    for (int i = 0; i < 3; i++) {
        int squash = cloud_squish && i == 1 ? 8 : 0;
        disc(70 + i * 120 - lean_x, 100 + i * 24, 26 - squash, CREAM);
        disc(96 + i * 120 - lean_x, 108 + i * 24, 18 - squash, CREAM);
    }
    {
        int squash = cloud_squish ? 8 : 0;
        disc(260 - lean_x, 330, 22 - squash, CREAM);
        disc(56 - lean_x / 2, 250, 16, CREAM);
        disc(150 - lean_x / 2, 286, 12, CREAM);
    }
    draw_castle(W / 2 - grown / 2, 24, grown, grown + 10, 0);
    draw_unicorn(cx, cy, 1, hurry ? 2 : 0);
}

static void draw_door(void)
{
    int who = runner();
    box(0, 0, W, H, SKY_C);
    draw_castle(70, 40, 244, 220, 1);
    for (int i = 0; i < ncats; i++) {
        int run = who == i;
        draw_cat(i, 120 + i * 40, run ? 300 : 230, run ? 26 : 18, 0);
    }
    draw_unicorn(W / 2, 400, 0, 0);
}

static void draw_party(void)
{
    int hop = cheer_left ? (int)(6 * sinf(frame * 0.4f)) : 0;
    box(0, 0, W, H, SKY_C);
    draw_castle(40, 8, 300, 150, 1);
    box(24, 250, W - 48, 80, CREAM);
    box(24, 250, W - 48, 8, ROOF);
    box(150, 210 + hop, 28, 22, TEA_C);
    box(200, 220 + hop, 22, 16, GOLD);
    box(230, 226 + hop, 18, 12, ROOF);
    for (int i = 0; i < ncats; i++) {
        int on = i == focus;
        int cy = on ? 248 : 226;
        int r = on ? 32 : 22;
        int delight = cheer_left || (react_left && i == focus);
        draw_cat(i, seat_x(i), cy, r, delight);
    }
    draw_icon(seat_x(focus), 248, 32, focus);
    draw_hearts(seat_x(focus), 248, 32, hearts[focus]);
    draw_unicorn(seat_x(focus), 400, 0, react_left ? 1 : 0);
    if (cheer_left) {
        for (int i = 0; i < 8; i++) {
            float a = frame * 0.2f + i;
            disc(W / 2 + (int)(70 * cosf(a)), 180 + (int)(24 * sinf(a)), 4, GOLD);
        }
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
    if (react_left && phase == PARTY)
        line = react_line;
    else
        line = rest_line();
    caption(line);
    cab_present();
}

int main(int argc, char **argv)
{
    int fast = cab_fast(argc, argv);
    if (cab_init("Tea", W, H) != 0)
        return 1;
    cab_audio_open(fill_audio, NULL);
    load_save();
    bed_on = 1;
    bed_hz = 523.25f;
    last_friend = PIP;
    ncats = 3;
    while (cab_poll()) {
        int button = cab_pressed(0, CAB_LOW) || cab_pressed(0, CAB_TL) || cab_pressed(0, CAB_TR);
        int held = cab_down(0, CAB_LOW) || cab_down(0, CAB_TL) || cab_down(0, CAB_TR);
        hurry = held && phase == SKY;
        if (cab_down(0, CAB_1P) && cab_down(0, CAB_2P) && !goodbye_played) {
            float hz[] = {783.99f, 659.25f};
            enqueue(hz, 2, 44100 / 6, 900.f);
            goodbye_played = 1;
        }
        lean_x = 0;
        lean_y = 0;
        if (cab_down(0, CAB_LEFT))
            lean_x -= 12;
        if (cab_down(0, CAB_RIGHT))
            lean_x += 12;
        if (cab_down(0, CAB_UP))
            lean_y -= 18;
        if (cab_down(0, CAB_DOWN))
            lean_y += 18;
        if (phase == SKY) {
            int step = held ? fast_mul(HURRY_STEP, fast) : fast_mul(SKY_STEP, fast);
            fly += step;
            if (fly > FLY_DONE)
                fly = FLY_DONE;
            {
                int ux = W / 2 + lean_x;
                int uy = 340 + lean_y;
                int dx = ux - 260;
                int dy = uy - 330;
                if (dx * dx + dy * dy < 54 * 54 && bump_cool == 0) {
                    cloud_squish = 12;
                    bump_cool = 30;
                    {
                        float hz = 880.f;
                        enqueue(&hz, 1, 44100 / 12, 800.f);
                    }
                }
            }
            if (fly >= FLY_DONE || frame >= 1200)
                begin_door();
        } else if (phase == DOOR) {
            if (button) {
                float hz = 783.99f;
                enqueue(&hz, 1, 44100 / 14, 800.f);
            }
            if (++door_t >= (fast ? DOOR_FRAMES * 5 / 8 : DOOR_FRAMES)) {
                phase = PARTY;
                bed_on = 0;
                cab_log("tea party");
            }
        } else {
            int prev = cab_pressed(0, CAB_LEFT) || cab_pressed(0, CAB_UP);
            int next = cab_pressed(0, CAB_RIGHT) || cab_pressed(0, CAB_DOWN);
            if (prev && !next)
                focus = (focus + ncats - 1) % ncats;
            else if (next)
                focus = (focus + 1) % ncats;
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
        }
        if (cloud_squish > 0)
            cloud_squish--;
        if (bump_cool > 0)
            bump_cool--;
        flap = held ? frame / 4 : frame / 8;
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
