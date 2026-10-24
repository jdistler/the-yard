/* Lamp: carry a small light around a dark yard and wake the stars.
 * Upright 240x320. Stick moves. Hold 1-player and 2-player to quit.
 * High score is lamp.sav ("best N"), the most stars woken in one trip.
 */
#include "cab.h"

#include <math.h>

#define W 240
#define H 320
#define NSTARS 7

static const SDL_Color INK = {232, 226, 204, 255}, DIM = {120, 120, 140, 255}, GOLD = {255, 214, 90, 255};

static const SDL_Point stars[NSTARS] = {
    {120, 160}, {48, 70}, {190, 64}, {36, 150}, {200, 168}, {70, 240}, {176, 250},
};

static int px = 116, py = 156, lit[NSTARS], score, best, done;
static volatile float tone_hz;
static volatile int tone_left;

static void beep(float hz)
{
    tone_hz = hz;
    tone_left = 44100 / 10;
}

static void fill(void *ud, Sint16 *out, int frames)
{
    static double phase;
    (void)ud;
    for (int i = 0; i < frames; i++) {
        Sint16 v = 0;
        if (tone_left > 0) {
            v = (Sint16)(4000 * sin(phase));
            phase += 2 * M_PI * tone_hz / 44100;
            tone_left--;
        }
        out[2 * i] = out[2 * i + 1] = v;
    }
}

static int near_star(int i)
{
    int dx = px + 4 - stars[i].x, dy = py + 4 - stars[i].y;
    return dx * dx + dy * dy < 18 * 18;
}

static void draw(void)
{
    SDL_SetRenderDrawColor(cab_renderer, 8, 10, 28, 255);
    SDL_RenderClear(cab_renderer);
    SDL_SetRenderDrawColor(cab_renderer, 180, 50, 40, 255);
    SDL_RenderFillRect(cab_renderer, &(SDL_Rect){0, 0, W, 4});
    SDL_SetRenderDrawColor(cab_renderer, 40, 70, 180, 255);
    SDL_RenderFillRect(cab_renderer, &(SDL_Rect){0, H - 4, W, 4});

    cab_text(8, 10, 2, GOLD, "LAMP");
    cab_text(8, 30, 1, INK, "stars %d/%d", score, NSTARS);
    cab_text(8, 42, 1, DIM, "best %d", best);
    if (done)
        cab_text(168, 14, 1, GOLD, "awake");

    for (int i = 0; i < NSTARS; i++) {
        if (lit[i])
            SDL_SetRenderDrawColor(cab_renderer, 120, 80, 30, 255);
        else
            SDL_SetRenderDrawColor(cab_renderer, 28, 32, 58, 255);
        SDL_RenderFillRect(cab_renderer, &(SDL_Rect){stars[i].x - 14, stars[i].y - 14, 28, 28});
        if (lit[i])
            SDL_SetRenderDrawColor(cab_renderer, 255, 190, 70, 255);
        else
            SDL_SetRenderDrawColor(cab_renderer, 48, 52, 88, 255);
        SDL_RenderFillRect(cab_renderer, &(SDL_Rect){stars[i].x - 6, stars[i].y - 6, 12, 12});
        if (lit[i])
            SDL_SetRenderDrawColor(cab_renderer, 255, 220, 120, 255);
        else
            SDL_SetRenderDrawColor(cab_renderer, 70, 74, 110, 255);
        SDL_RenderFillRect(cab_renderer, &(SDL_Rect){stars[i].x - 2, stars[i].y - 2, 5, 5});
    }
    /* A lantern, narrow enough that a woken star still shows around it. */
    SDL_SetRenderDrawColor(cab_renderer, 120, 70, 24, 255);
    SDL_RenderFillRect(cab_renderer, &(SDL_Rect){px - 6, py - 18, 20, 34});
    SDL_SetRenderDrawColor(cab_renderer, 255, 170, 50, 255);
    SDL_RenderFillRect(cab_renderer, &(SDL_Rect){px - 2, py - 12, 12, 20});
    SDL_SetRenderDrawColor(cab_renderer, 255, 230, 150, 255);
    SDL_RenderFillRect(cab_renderer, &(SDL_Rect){px, py, 8, 8});
    cab_text(8, H - 18, 1, DIM, done ? "Z again   1+2 quit" : "1+2 quit");
    cab_present();
}

int main(int argc, char **argv)
{
    int self = getenv("LAMP_SELFTEST") != NULL;
    int fast = cab_fast(argc, argv);
    int frames = 0;
    if (cab_init("Lamp", W, H) != 0)
        return 1;
    cab_audio_open(fill, NULL);
    best = cab_score_load("lamp");
    while (cab_poll()) {
        int step = fast ? 4 : 2;
        /* Z starts another trip. The record stays. You begin on the center star,
         * so that one wakes again on the same frame. */
        if (cab_pressed(0, CAB_LOW)) {
            for (int i = 0; i < NSTARS; i++)
                lit[i] = 0;
            score = 0;
            done = 0;
            px = 116;
            py = 156;
        }
        if (cab_down(0, CAB_LEFT))
            px -= step;
        if (cab_down(0, CAB_RIGHT))
            px += step;
        if (cab_down(0, CAB_UP))
            py -= step;
        if (cab_down(0, CAB_DOWN))
            py += step;
        if (px < 8)
            px = 8;
        if (px > W - 16)
            px = W - 16;
        if (py < 70)
            py = 70;
        if (py > H - 28)
            py = H - 28;
        if (!done) {
            for (int i = 0; i < NSTARS; i++)
                if (!lit[i] && near_star(i)) {
                    lit[i] = 1;
                    score++;
                    beep(520 + score * 40);
                    if (score > best && cab_score_save("lamp", score) == 0)
                        best = score;
                    else if (score > best)
                        cab_log("score save failed");
                }
            if (score == NSTARS)
                done = 1;
        }
        draw();
        if (self && score >= 1 && frames > 6) {
            int stored = score > best ? score : best;
            if (cab_score_save("lamp", stored) != 0 || cab_score_load("lamp") != stored)
                return 1;
            break;
        }
        if (self && ++frames > 40)
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
