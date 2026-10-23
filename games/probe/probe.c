/* Partycade probe: shows and logs what the cabinet's controls, screen and audio look like to a game.
 * Log: ./probe.log (on the cabinet /data/Games/probe.log). Quit: hold SELECT+START for 1 s, Escape,
 * or leave every control alone for IDLE_EXIT_MS (in case the deck has no SELECT/START).
 */
#include <dirent.h>
#include <fcntl.h>
#include <linux/input.h>
#include <math.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include "cab.h"

#define W 320
#define H 240
#define LINES 10
#define MAX_EV 8
#define IDLE_EXIT_MS 60000

static Uint32 last_input;

static char recent[LINES][48];
static int recent_n;
static volatile float tone_hz;
static volatile int tone_left;
static int evfd[MAX_EV], evcount;
static SDL_Joystick *joys[2];

static const SDL_Color WHITE = {255, 255, 255, 255}, GREY = {120, 120, 120, 255},
                       YELLOW = {255, 220, 0, 255}, CYAN = {0, 220, 255, 255};

static void remember(const char *fmt, ...)
{
    va_list ap;
    char *line = recent[recent_n++ % LINES];
    va_start(ap, fmt);
    vsnprintf(line, sizeof recent[0], fmt, ap);
    va_end(ap);
    cab_log("%s", line);
}

static void beep(float hz)
{
    tone_hz = hz;
    tone_left = 44100 / 8;
}

static void fill(void *ud, Sint16 *out, int frames)
{
    static double phase;
    (void)ud;
    for (int i = 0; i < frames; i++) {
        Sint16 v = 0;
        if (tone_left > 0) {
            v = (Sint16)(6000 * sin(phase));
            phase += 2 * M_PI * tone_hz / 44100;
            tone_left--;
        }
        out[2 * i] = out[2 * i + 1] = v;
    }
}

static void on_event(const SDL_Event *e)
{
    if (e->type >= SDL_KEYDOWN && e->type < SDL_CONTROLLERAXISMOTION)
        last_input = SDL_GetTicks();
    switch (e->type) {
    case SDL_JOYBUTTONDOWN:
    case SDL_JOYBUTTONUP:
        remember("joy%d button %d %s", e->jbutton.which, e->jbutton.button,
                 e->jbutton.state == SDL_PRESSED ? "down" : "up");
        if (e->jbutton.state == SDL_PRESSED)
            beep(220.0f * powf(2.0f, e->jbutton.button / 12.0f));
        break;
    case SDL_JOYAXISMOTION:
        remember("joy%d axis %d = %d", e->jaxis.which, e->jaxis.axis, e->jaxis.value);
        break;
    case SDL_JOYHATMOTION:
        remember("joy%d hat %d = %d", e->jhat.which, e->jhat.hat, e->jhat.value);
        break;
    case SDL_KEYDOWN:
    case SDL_KEYUP:
        if (!e->key.repeat)
            remember("key %s (scancode %d) %s", SDL_GetScancodeName(e->key.keysym.scancode),
                     e->key.keysym.scancode, e->type == SDL_KEYDOWN ? "down" : "up");
        if (e->type == SDL_KEYDOWN && !e->key.repeat)
            beep(880);
        break;
    case SDL_JOYDEVICEADDED:
        remember("joystick added: device %d", e->jdevice.which);
        break;
    }
}

static void open_evdev(void)
{
    DIR *d = opendir("/dev/input");
    struct dirent *de;
    if (!d)
        return;
    while ((de = readdir(d)) && evcount < MAX_EV) {
        char path[300], name[96] = "?";
        int fd;
        if (strncmp(de->d_name, "event", 5))
            continue;
        snprintf(path, sizeof path, "/dev/input/%s", de->d_name);
        if ((fd = open(path, O_RDONLY | O_NONBLOCK)) < 0) {
            cab_log("evdev %s: cannot open", path);
            continue;
        }
        ioctl(fd, EVIOCGNAME(sizeof name), name);
        cab_log("evdev %s: \"%s\"", path, name);
        evfd[evcount++] = fd;
    }
    closedir(d);
}

static void read_evdev(void)
{
    struct input_event ev;
    for (int i = 0; i < evcount; i++)
        while (read(evfd[i], &ev, sizeof ev) == sizeof ev)
            if (ev.type == EV_KEY || ev.type == EV_ABS) {
                cab_log("evdev%d type %d code 0x%03x value %d", i, ev.type, ev.code, ev.value);
                last_input = SDL_GetTicks();
            }
}

static void log_setup(void)
{
    SDL_RendererInfo ri;
    SDL_DisplayMode dm;
    int ow = 0, oh = 0;
    SDL_GetRendererInfo(cab_renderer, &ri);
    SDL_GetRendererOutputSize(cab_renderer, &ow, &oh);
    SDL_GetCurrentDisplayMode(0, &dm);
    SDL_version v;
    SDL_GetVersion(&v);
    cab_log("=== probe start: SDL runtime %d.%d.%d", v.major, v.minor, v.patch);
    cab_log("video %s, renderer %s (flags 0x%x), output %dx%d, display %dx%d@%d",
            SDL_GetCurrentVideoDriver(), ri.name, ri.flags, ow, oh, dm.w, dm.h, dm.refresh_rate);
    cab_log("audio %s", SDL_GetCurrentAudioDriver() ? SDL_GetCurrentAudioDriver() : "(none)");
    cab_log("joysticks: %d", SDL_NumJoysticks());
    for (int i = 0; i < SDL_NumJoysticks(); i++) {
        SDL_Joystick *j = SDL_JoystickOpen(i);
        char guid[40];
        if (i < 2)
            joys[i] = j;
        SDL_JoystickGetGUIDString(SDL_JoystickGetGUID(j), guid, sizeof guid);
        cab_log("joy%d \"%s\" axes %d buttons %d hats %d balls %d guid %s", i, SDL_JoystickName(j),
                SDL_JoystickNumAxes(j), SDL_JoystickNumButtons(j), SDL_JoystickNumHats(j),
                SDL_JoystickNumBalls(j), guid);
    }
}

static void draw(void)
{
    int y = 2, ow = 0, oh = 0;
    SDL_GetRendererOutputSize(cab_renderer, &ow, &oh);
    SDL_SetRenderDrawColor(cab_renderer, 0, 0, 40, 255);
    SDL_RenderClear(cab_renderer);
    SDL_SetRenderDrawColor(cab_renderer, 60, 60, 120, 255);
    SDL_RenderDrawRect(cab_renderer, &(SDL_Rect){0, 0, W, H});

    cab_text(4, y, 1, YELLOW, "PARTYCADE PROBE   SELECT+START=quit");
    cab_text(4, y += 10, 1, GREY, "%s %dx%d  joys %d  evdev %d", SDL_GetCurrentVideoDriver(), ow, oh,
             SDL_NumJoysticks(), evcount);
    for (int i = 0; i < 2; i++) {
        SDL_Joystick *j = joys[i];
        if (!j)
            continue;
        cab_text(4, y += 10, 1, CYAN, "joy%d %.30s", i, SDL_JoystickName(j) ? SDL_JoystickName(j) : "?");
        char line[48] = "";
        for (int b = 0; b < SDL_JoystickNumButtons(j) && b < 20; b++)
            if (SDL_JoystickGetButton(j, b))
                snprintf(line + strlen(line), sizeof line - strlen(line), "%d ", b);
        cab_text(4, y += 10, 1, WHITE, " ax0 %6d ax1 %6d btn %s", SDL_JoystickNumAxes(j) > 0 ? SDL_JoystickGetAxis(j, 0) : 0,
                 SDL_JoystickNumAxes(j) > 1 ? SDL_JoystickGetAxis(j, 1) : 0, line);
    }
    y += 14;
    for (int b = 0; b < CAB_NUM_BUTTONS; b++) {
        int col = b % 6, row = b / 6;
        cab_text(4 + col * 52, y + row * 12, 1, cab_down(0, b) ? YELLOW : GREY, "%s", cab_button_name(b));
    }
    y += 52;
    for (int i = 0; i < LINES; i++) {
        int idx = recent_n - LINES + i;
        if (idx >= 0)
            cab_text(4, y + i * 10, 1, i == LINES - 1 ? WHITE : GREY, "%s", recent[idx % LINES]);
    }
    cab_present();
}

static void push_key(SDL_Scancode sc, int down)
{
    SDL_Event e;
    SDL_zero(e);
    e.type = down ? SDL_KEYDOWN : SDL_KEYUP;
    e.key.state = down ? SDL_PRESSED : SDL_RELEASED;
    e.key.keysym.scancode = sc;
    SDL_PushEvent(&e);
}

/* PROBE_SELFTEST=1: press A, then hold SELECT+START; the probe must log "mapped P1 A" and quit by itself. */
static void selftest(int frame)
{
    if (frame == 5) push_key(SDL_SCANCODE_Z, 1);
    if (frame == 8) push_key(SDL_SCANCODE_Z, 0);
    if (frame == 10) { push_key(SDL_SCANCODE_BACKSPACE, 1); push_key(SDL_SCANCODE_RETURN, 1); }
}

int main(int argc, char **argv)
{
    int frames = 0, max_frames = getenv("PROBE_FRAMES") ? atoi(getenv("PROBE_FRAMES")) : 0;
    SDL_RendererInfo ri;
    (void)argc;
    (void)argv;
    cab_log_open("probe.log");
    if (cab_init("Partycade probe", W, H) != 0)
        return 1;
    cab_load_mapping("controls.cfg");
    cab_event_hook = on_event;
    log_setup();
    open_evdev();
    cab_audio_open(fill, NULL);
    beep(440);
    SDL_GetRendererInfo(cab_renderer, &ri);
    while (cab_poll()) {
        read_evdev();
        for (int b = 0; b < CAB_NUM_BUTTONS; b++)
            if (cab_pressed(0, b))
                cab_log("mapped P1 %s", cab_button_name(b));
        draw();
        if (getenv("PROBE_SELFTEST"))
            selftest(frames);
        if (++frames >= max_frames && max_frames)
            break;
        if (SDL_GetTicks() - last_input > IDLE_EXIT_MS) {
            cab_log("no input for %d s, exiting", IDLE_EXIT_MS / 1000);
            break;
        }
        if (!(ri.flags & SDL_RENDERER_PRESENTVSYNC))
            SDL_Delay(16);
    }
    cab_log("=== probe exit after %u ms", SDL_GetTicks());
    for (int i = 0; i < evcount; i++)
        close(evfd[i]);
    cab_shutdown();
    return 0;
}
