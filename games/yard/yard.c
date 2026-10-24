/* The Yard: the little menu that opens when Dig Dug II is chosen.
 * Stick up/down moves the lantern. The lower button opens that game.
 * Hold 1-player and 2-player to go back to the stock menu.
 * yard.sav stores the last highlighted row in the same "best N" file the games use.
 */
#include "cab.h"

#include <math.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#define W 240
#define H 320

static const SDL_Color INK = {236, 230, 210, 255}, DIM = {130, 132, 150, 255}, GOLD = {255, 210, 90, 255};

static const char *ids[] = {"keep", "lamp", "orb", "tea"};
static const char *titles[] = {"KEEP", "LAMP", "ORB", "TEA"};
static const char *blurbs[] = {"catch what falls", "wake the stars", "dive the well", "tea with the cats"};
#define N (int)(sizeof ids / sizeof ids[0])

static int row, pocket;
static volatile float tone_hz;
static volatile int tone_left;

static void beep(float hz)
{
    tone_hz = hz;
    tone_left = 44100 / 14;
}

static void fill(void *ud, Sint16 *out, int frames)
{
    static double phase;
    (void)ud;
    for (int i = 0; i < frames; i++) {
        Sint16 v = 0;
        if (tone_left > 0) {
            v = (Sint16)(3500 * sin(phase));
            phase += 2 * M_PI * tone_hz / 44100;
            tone_left--;
        }
        out[2 * i] = out[2 * i + 1] = v;
    }
}

static void draw_sky(int frame)
{
    SDL_SetRenderDrawColor(cab_renderer, 10, 14, 36, 255);
    SDL_RenderClear(cab_renderer);
    SDL_SetRenderDrawColor(cab_renderer, 210, 60, 50, 255);
    SDL_RenderFillRect(cab_renderer, &(SDL_Rect){0, 0, W, 4});
    SDL_SetRenderDrawColor(cab_renderer, 40, 70, 190, 255);
    SDL_RenderFillRect(cab_renderer, &(SDL_Rect){0, H - 4, W, 4});
    /* A handful of fixed stars, one of them winks. */
    for (int i = 0; i < 12; i++) {
        int x = 16 + (i * 47) % (W - 24);
        int y = 14 + (i * 29) % 36;
        int on = (i != (frame / 20) % 12);
        SDL_SetRenderDrawColor(cab_renderer, on ? 220 : 40, on ? 220 : 40, on ? 180 : 70, 255);
        SDL_RenderDrawPoint(cab_renderer, x, y);
    }
}

static void draw(int frame, const char *note)
{
    draw_sky(frame);
    cab_text(16, 58, 2, GOLD, "THE YARD");
    cab_text(16, 80, 1, DIM, "a side door off the menu");
    for (int i = 0; i < N; i++) {
        int y = 112 + i * 36;
        if (i == row) {
            SDL_SetRenderDrawColor(cab_renderer, 255, 196, 70, 255);
            SDL_RenderFillRect(cab_renderer, &(SDL_Rect){18, y + 2, 6, 6});
            cab_text(32, y, 2, INK, "%s", titles[i]);
            cab_text(32, y + 18, 1, GOLD, "%s", blurbs[i]);
        } else {
            cab_text(32, y, 2, DIM, "%s", titles[i]);
        }
    }
    if (pocket) {
        SDL_SetRenderDrawColor(cab_renderer, 40, 210, 220, 255);
        SDL_RenderFillRect(cab_renderer, &(SDL_Rect){220, 300, 8, 8});
        cab_text(150, 80, 1, (SDL_Color){40, 210, 220, 255}, "pocket");
    }
    cab_text(16, H - 28, 1, DIM, note ? note : "Z open   1+2 back");
    cab_present();
}

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
    memcpy(out, self, strlen(self));
    out[strlen(self)] = '/';
    memcpy(out + strlen(self) + 1, name, strlen(name) + 1);
    return 0;
}

/* Close the window, run the other game, then open the yard again. */
static int launch(const char *name, int fast)
{
    char path[512];
    pid_t pid;
    int st = 0;
    if (sibling(path, sizeof path, name) != 0)
        return -1;
    if (access(path, X_OK) != 0)
        return -1;
    beep(440);
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
    if (cab_init("The Yard", W, H) != 0)
        return -1;
    cab_audio_open(fill, NULL);
    return WIFEXITED(st) ? WEXITSTATUS(st) : -1;
}

int main(int argc, char **argv)
{
    int fast = cab_fast(argc, argv);
    int self = getenv("YARD_SELFTEST") != NULL;
    const char *once = getenv("YARD_ONCE");
    int frame = 0;
    const char *note = NULL;
    if (cab_init("The Yard", W, H) != 0)
        return 1;
    cab_audio_open(fill, NULL);
    row = cab_score_load("yard");
    if (row < 0 || row >= N)
        row = 0;
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
        if (cab_pressed(0, CAB_UP))
            row = (row + N - 1) % N;
        if (cab_pressed(0, CAB_DOWN))
            row = (row + 1) % N;
        if (cab_pressed(0, CAB_LOW) || cab_pressed(0, CAB_TL)) {
            cab_score_save("yard", row);
            if (launch(ids[row], fast) != 0) {
                note = "could not open that game";
                cab_log("could not open %s", ids[row]);
            } else
                note = NULL;
        }
        draw(frame++, note);
        if (self && frame > 8) {
            if (cab_score_save("yard", row) != 0 || cab_score_load("yard") != row)
                return 1;
            break;
        }
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
