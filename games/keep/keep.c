/* Keep: catch the falling tile. An original sample for the cabinet and the PC simulator.
 * Upright view is 240x320, which scales evenly onto the 768x1024 panel.
 * PC keys: arrows move, Z is the lower button (start / restart), hold 1 and 2 to quit.
 * Cabinet: stick moves, the lower button right of the stick starts, hold 1-player and 2-player to quit.
 * High score is keep.sav ("best N") in the current directory. On the cabinet that is /data/Games.
 */
#include "cab.h"

#include <math.h>
#include <stdlib.h>

#define W 240
#define H 320
#define PW 36
#define PH 8

static const SDL_Color WHITE = {255, 255, 255, 255}, YELLOW = {255, 220, 0, 255},
                       GREY = {140, 140, 150, 255}, RED = {220, 60, 60, 255};

static int px, py, ix, iy, alive, score, best, over, wait, spark;
static volatile float tone_hz;
static volatile int tone_left;

static void beep(float hz)
{
    tone_hz = hz;
    tone_left = 44100 / 12;
}

static void fill(void *ud, Sint16 *out, int frames)
{
    static double phase;
    (void)ud;
    for (int i = 0; i < frames; i++) {
        Sint16 v = 0;
        if (tone_left > 0) {
            v = (Sint16)(5000 * sin(phase));
            phase += 2 * M_PI * tone_hz / 44100;
            tone_left--;
        }
        out[2 * i] = out[2 * i + 1] = v;
    }
}

static void drop(void)
{
    ix = 8 + rand() % (W - 16);
    iy = 28;
}

static void restart(void)
{
    px = (W - PW) / 2;
    py = H - 28;
    score = 0;
    over = 0;
    wait = 0;
    drop();
    alive = 1;
}

static void draw(void)
{
    SDL_SetRenderDrawColor(cab_renderer, 12, 12, 28, 255);
    SDL_RenderClear(cab_renderer);
    /* Markers the rotation check looks for: a bar across the top and the bottom. */
    SDL_SetRenderDrawColor(cab_renderer, 220, 40, 40, 255);
    SDL_RenderFillRect(cab_renderer, &(SDL_Rect){0, 0, W, 6});
    SDL_SetRenderDrawColor(cab_renderer, 40, 80, 220, 255);
    SDL_RenderFillRect(cab_renderer, &(SDL_Rect){0, H - 6, W, 6});

    for (int i = 0; i < 10; i++) {
        SDL_SetRenderDrawColor(cab_renderer, 180, 180, 200, 255);
        SDL_RenderDrawPoint(cab_renderer, 24 + (i * 53) % 190, 120 + (i * 19) % 90);
    }
    cab_text(8, 12, 2, YELLOW, "KEEP");
    cab_text(8, 32, 1, WHITE, "score %d", score);
    cab_text(8, 44, 1, GREY, "best %d", best);
    if (!alive)
        cab_text(8, 70, 1, WHITE, over ? "Z / LOW to go" : "Z / LOW to start");
    if (over)
        cab_text(8, 86, 1, RED, "missed");
    cab_text(8, H - 22, 1, GREY, "1+2 quit");

    SDL_SetRenderDrawColor(cab_renderer, 240, 220, 80, 255);
    SDL_RenderFillRect(cab_renderer, &(SDL_Rect){px, py, PW, PH});
    if (spark) {
        SDL_SetRenderDrawColor(cab_renderer, 255, 255, 255, 255);
        SDL_RenderFillRect(cab_renderer, &(SDL_Rect){px + PW / 2 - 2, py - 10, 4, 4});
        spark--;
    }
    if (alive && !over) {
        SDL_SetRenderDrawColor(cab_renderer, 80, 220, 140, 255);
        SDL_RenderFillRect(cab_renderer, &(SDL_Rect){ix, iy, 8, 8});
    }
    cab_present();
}

int main(int argc, char **argv)
{
    int self = getenv("KEEP_SELFTEST") != NULL;
    int fast = cab_fast(argc, argv);
    int frames = 0;
    if (cab_init("Keep", W, H) != 0)
        return 1;
    cab_audio_open(fill, NULL);
    best = cab_score_load("keep");
    px = (W - PW) / 2;
    py = H - 28;
    if (self) {
        alive = 1;
        ix = px + PW / 2 - 4;
        iy = py - 2;
    }
    while (cab_poll()) {
        int step = fast ? 6 : 3;
        /* The title screen ignores the stick. Movement there used to slide the
         * paddle and then snap it back to center when the round started. */
        if (alive) {
            if (cab_down(0, CAB_LEFT))
                px -= step;
            if (cab_down(0, CAB_RIGHT))
                px += step;
            if (px < 4)
                px = 4;
            if (px > W - PW - 4)
                px = W - PW - 4;
        }
        if (!alive && cab_pressed(0, CAB_LOW))
            restart();
        if (alive && !over) {
            iy += fast ? 4 : 2;
            if (iy + 8 >= py && iy <= py + PH && ix + 8 >= px && ix <= px + PW) {
                score++;
                beep(660);
                spark = 8;
                if (score > best && cab_score_save("keep", score) == 0)
                    best = score;
                else if (score > best)
                    cab_log("score save failed");
                drop();
            } else if (iy > H - 12) {
                over = 1;
                alive = 0;
                beep(140);
                if (score > best && cab_score_save("keep", score) == 0)
                    best = score;
                else if (score > best)
                    cab_log("score save failed");
            }
        }
        draw();
        if (self && score >= 1 && frames > 8) {
            int stored = score > best ? score : best;
            if (cab_score_save("keep", stored) != 0 || cab_score_load("keep") != stored)
                return 1;
            break;
        }
        if (self && ++frames > 90)
            return 1;
        {
            SDL_RendererInfo ri;
            SDL_GetRendererInfo(cab_renderer, &ri);
            if (!(ri.flags & SDL_RENDERER_PRESENTVSYNC))
                SDL_Delay(16);
        }
    }
    cab_shutdown();
    return 0;
}
